# PropMatch AI — Phase 5.1A.3.2: Local Meta Webhook & Test Lead Architecture Guide

> **Document Version:** 1.0.0  
> **Date:** 24 November 2026  
> **Author:** Antigravity Senior Full-Stack AI Engineer  
> **Target Audience:** DevOps / Developer Setup for Single-Agent Pilot Verification  
> **Pilot Agent:** Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
> **Designated Listing:** Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  
> **Firebase Target:** `property-71665` (Functions Region: `asia-southeast1`)  
> **Meta API Baseline:** Graph API `v26.0`  

---

## Executive Summary

This guide provides the complete, production-grade local test architecture that enables receiving and testing real Meta Lead Ads webhooks directly on a developer workstation. 

Crucially, **this architecture operates 100% on the Firebase Spark (Free) tier**. By combining the **Firebase Local Emulator Suite** (Functions, Firestore, Auth) with an ephemeral **HTTPS reverse tunnel** (Cloudflare Tunnel or ngrok), Meta's servers can deliver genuine test webhooks directly to local Cloud Functions without deploying code to Google Cloud, without incurring cloud costs, and without requiring a Firebase Blaze plan upgrade.

---

## 1. System Architecture Overview

```
┌─────────────────────────────────┐
│     Meta Developer Platform     │
│   (Lead Ads Testing Tool UI)    │
└────────────────┬────────────────┘
                 │ 1. Submits Test Lead
                 ▼
┌─────────────────────────────────┐
│     Meta Webhook Dispatcher     │
│  (X-Hub-Signature-256 HMAC)     │
└────────────────┬────────────────┘
                 │ 2. HTTPS POST Webhook
                 ▼
┌─────────────────────────────────┐
│     Ephemeral HTTPS Tunnel      │
│  (Cloudflare Tunnel or ngrok)   │
└────────────────┬────────────────┘
                 │ 3. Forward to Port 5001
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│               Local Workstation (Developer Machine)             │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Firebase Cloud Functions v2 Emulator                      │  │
│  │ Handler: metaWebhookHandler (Port 5001)                   │  │
│  │ 1. Verifies timingSafeEqual HMAC SHA-256 Signature        │  │
│  │ 2. Extracts leadgen_id, form_id, ad_id                    │  │
│  │ 3. Queries Graph API with fallback mechanism              │  │
│  │ 4. Calls LeadIngestionService (6-stage validation)        │  │
│  └─────────────────────────────┬─────────────────────────────┘  │
│                                │                                │
│                                ▼                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Cloud Firestore Emulator (Port 8080 / UI: 4000)            │  │
│  │ Collections:                                              │  │
│  │  - meta_ingested_leads (Idempotency Record)               │  │
│  │  - prospects (Tan Wei Lun, placement: UNKNOWN)            │  │
│  │  - projects (Eco Horizon Astonia Townhome)                │  │
│  └─────────────────────────────┬─────────────────────────────┘  │
│                                │                                │
│                                ▼                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Flutter Web Application (Port 5500 / Chrome)              │  │
│  │ Agent Dashboard (Malik Tan, pilot-agent-malik-001)        │  │
│  │ Displays: Qualified Lead, 100/100 Match, Zero Outreach    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Why Firebase Spark (Free Tier) is Sufficient

A frequent misconception is that cloud functions must be deployed to Google Cloud or upgraded to the Blaze (Pay-as-you-go) plan to test third-party webhooks like Meta Lead Ads.

In reality:
1. **Local Emulator Independence:** The Firebase Emulator Suite runs on the local Node.js runtime and has zero billing dependencies. It emulates Google Cloud Secret Manager, Cloud Functions v2, and Cloud Firestore locally.
2. **Tunnel Ingress:** Services such as Cloudflare Tunnel (`cloudflared`) and `ngrok` expose the local port `5001` via a publicly signed, valid SSL/TLS HTTPS endpoint (`https://<subdomain>.trycloudflare.com`).
3. **Meta Verification Compliance:** Meta requires an HTTPS URL that returns HTTP 200 with the `hub.challenge` string upon verification. Cloudflare Tunnel and ngrok provide enterprise-grade TLS that satisfies Meta's strict certificate verification rules.

---

## 3. Step-by-Step Implementation Guide

### Step 1: Start Firebase Local Emulator Suite
From the project root:

```bash
# Terminal 1: Start Firestore, Auth, and Functions emulators
firebase emulators:start --only functions,firestore,auth
```

You will see:
```text
✔  functions[asia-southeast1-metaWebhookHandler]: http function initialized
   (http://127.0.0.1:5001/property-71665/asia-southeast1/metaWebhookHandler)
✔  firestore: Firestore Emulator logging to firestore-debug.log
✔  Emulator Hub running at 127.0.0.1:4000
✔  View Emulator UI at http://127.0.0.1:4000
```

### Step 2: Establish the HTTPS Reverse Tunnel

#### Option A: Cloudflare Tunnel (Recommended — No Account or Sign-in Required)
```bash
# Terminal 2: Start Cloudflare Tunnel pointing to Functions port 5001
cloudflared tunnel --url http://localhost:5001
```

Look for the public URL in the output:
```text
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at:                                          |
|  https://quick-tunnel-sample-domain.trycloudflare.com                                      |
+--------------------------------------------------------------------------------------------+
```

#### Option B: ngrok (Alternative)
```bash
# Terminal 2: Start ngrok
ngrok http 5001
```
Note the HTTPS forwarding address: `https://xxxx-xx-xx.ngrok-free.app`.

### Step 3: Configure the Webhook in Meta App Dashboard
1. Open [Meta for Developers](https://developers.facebook.com/apps/).
2. Select your Developer App (e.g., `PropMatch AI Pilot`).
3. Navigate to **Webhooks** in the left sidebar.
4. In the dropdown, select **Page**.
5. Click **Edit Subscription** or **Subscribe to this object**.
6. Enter the parameters:
   - **Callback URL:**
     `https://<your-tunnel-domain>/property-71665/asia-southeast1/metaWebhookHandler`
   - **Verify Token:**
     Use the value defined in `META_WEBHOOK_VERIFY_TOKEN` (e.g., `propmatch_webhook_verify_token_2026_penang`).
7. Click **Verify and Save**.
   - Meta will send a `GET` request with `hub.challenge`.
   - Your local terminal will log:
     ```text
     i  functions: [asia-southeast1-metaWebhookHandler] Meta Webhook verification handshake successful
     ```
8. In the Page Subscription Fields table, find **`leadgen`** and click **Subscribe** (or test).

### Step 4: Subscribe the Facebook Page to the App
Before Meta will dispatch webhook events for a specific Page, the Page must subscribe to the App's notifications:

Using the **Graph API Explorer** (`https://developers.facebook.com/tools/explorer/`):
1. Select your Developer App.
2. Select the Facebook Page (e.g., Malik Tan's Page: `Malik Tan — Penang Property Advisory`).
3. Set Method to `POST`.
4. Set Endpoint to `/{page-id}/subscribed_apps?subscribed_fields=leadgen`.
5. Click **Submit**.
6. Response must be:
   ```json
   {
     "success": true
   }
   ```

### Step 5: Submit a Real Test Lead via Meta Lead Ads Testing Tool
Meta provides a dedicated interactive tool to dispatch genuine lead payloads to your webhook:

1. Navigate to [Meta Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing).
2. In the **Page** dropdown, select Malik Tan's Page.
3. In the **Form** dropdown, select your Instant Form (e.g., *Eco Horizon Astonia Townhome Enquiry Form*).
4. *(Optional)* Click **Preview Form** to view the form questionnaire or customize answers (e.g., Name: *Tan Wei Lun*, Budget: *RM 700,000*, Phone: *+60124889123*).
5. Click **Create Lead**.
6. Click **Track Status**.
   - You will see:
     ```text
     Status: Success
     HTTP Status Code: 200
     Response: EVENT_RECEIVED
     ```

### Step 6: Verify Ingestion in Firebase Emulator & Flutter Web
1. **Cloud Functions Log:**
   ```text
   i  functions: [asia-southeast1-metaWebhookHandler] Meta lead ingested successfully { leadgenId: "123456789", ownerId: "pilot-agent-malik-001" }
   ```
2. **Firestore Emulator UI (`http://127.0.0.1:4000/firestore`):**
   - Check `meta_ingested_leads`: Verifies idempotency record created with `leadgenId`, `placement: UNKNOWN`, and `acquisitionSourceConfidence: Unverified`.
   - Check `prospects`: Verifies prospect created with `fullName: "Tan Wei Lun"`, `phone: "+60124889123"`, and deterministic match score `100/100` against project `proj-penang-pilot-001`.
3. **Flutter Web Dashboard:**
   - Launch Flutter Web: `flutter run -d chrome`
   - Log in as pilot agent Malik Tan (`pilot-agent-malik-001`).
   - Navigate to **Buyer Intelligence Dashboard**.
   - The test lead is immediately visible with status **New Lead**, matched to **Eco Horizon Astonia Townhome**.

---

## 4. Deleting Test Leads for Repeat Testing

Meta permits only **one active test lead per user per form**. To run repeated tests:
1. In the [Meta Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing), click **Delete Lead**.
2. Refresh the tool and click **Create Lead** again.
3. In the Firestore Emulator, you can either clear `meta_ingested_leads` or let the idempotency engine demonstrate duplicate suppression.

---

## 5. Security & Isolation Best Practices

1. **Ephemeral Tunnels:** Kill the tunnel process (`Ctrl+C`) immediately after testing. Ephemeral URLs are automatically decommissioned.
2. **Agent Namespace Isolation:** All created prospects are stamped with `ownerId: "pilot-agent-malik-001"`. Cross-agent queries remain impossible.
3. **Zero Automated Outreach:** As verified in Stage 11, the ingestion engine sets `autoContacted: false`. No automated WhatsApp or email message is ever dispatched to the buyer without explicit manual action by the agent.
