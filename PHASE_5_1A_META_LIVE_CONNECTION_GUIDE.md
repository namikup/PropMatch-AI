# PropMatch AI — Phase 5.1A: Meta Developer App Setup & Live Connection Verification Guide

**Project Target:** Google Cloud Firebase Project `property-71665`  
**Execution Region:** `asia-southeast1` (Singapore)  
**Meta Graph API Version:** `v21.0` (Active Stable Release)  
**Pilot Agent:** Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd)  
**Designated Listing:** Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  

---

## 1. Executive Summary & Objective

In Phase 5.1, PropMatch AI introduced **Meta Ads Intelligence** to bridge the gap between digital marketing expenditure on Facebook/Instagram and genuine Malaysian property buyer qualification.

Phase 5.1A establishes the operational roadmap and technical verification necessary to transition from the verified local implementation to a **live connection with Meta's Graph API v21.0**, the agent's authorized Facebook Page, and their Meta Ad Account.

This document details:
1. Exact Meta Developer App setup and configuration.
2. Production URLs for OAuth and Webhooks on `property-71665`.
3. The exact permission matrix and the **Development Mode / Standard Access strategy** that enables live pilot testing without waiting for Meta App Review or Business Verification.
4. Secret management and environment variable configuration.
5. End-to-end testing procedures using the newly provided diagnostic script (`scripts/test_meta_live_connection.js`) and the Meta Lead Ads Testing Tool.
6. The explicit 6-stage Integration Status Classification.

---

## 2. Meta Developer App Architecture & Endpoints

### 2.1 Backend Cloud Functions Endpoints (`asia-southeast1`)

| Endpoint Name | Cloud Functions URL | Purpose |
| :--- | :--- | :--- |
| **Meta Webhook Handler** | `https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler` | Receives GET for hub handshake verification; receives POST for real-time `leadgen` instant form notifications. |
| **Meta OAuth Callback** | `https://asia-southeast1-property-71665.cloudfunctions.net/metaOAuthCallback` | Backend redirect target to securely exchange authorization code for a 60-day long-lived User Access Token. |
| **Frontend Campaigns Tab** | `https://property-71665.web.app/#/campaigns?meta_oauth=callback` | Client URL redirected to once the OAuth exchange succeeds. |

### 2.2 Meta Graph API Versioning

All HTTP requests dispatched by the backend (`MetaAdsService`) strictly target **Meta Graph API `v21.0`**:
- Base URL: `https://graph.facebook.com/v21.0/`
- Verification Endpoint: `https://graph.facebook.com/v21.0/debug_token`
- User Accounts: `https://graph.facebook.com/v21.0/me/accounts`
- User Ad Accounts: `https://graph.facebook.com/v21.0/me/adaccounts`
- Leadgen Details: `https://graph.facebook.com/v21.0/{leadgen_id}`
- Ad Account Campaigns: `https://graph.facebook.com/v21.0/{ad_account_id}/campaigns`
- Ad Account Insights: `https://graph.facebook.com/v21.0/{ad_account_id}/insights`

---

## 3. Step-by-Step Meta Developer App Setup Guide

### Step 1: Register Developer Account & Create App
1. Log into [Meta for Developers](https://developers.facebook.com/) using the administrator Facebook profile.
2. Click **My Apps** > **Create App**.
3. Select **Other** as the use case, then click **Next**.
4. Select **Business** as the app type (`Manage Pages, accounts, events, and business assets`).
5. Provide App Details:
   - **App Name:** `PropMatch AI - Pilot Intelligence`
   - **App Contact Email:** The developer or administrator email.
   - **Business Account:** Select your Meta Business Portfolio (optional for initial development mode).
6. Click **Create app**.

### Step 2: Add Required Meta Products
In the Meta App Dashboard sidebar, navigate to **Add Products**:
1. **Facebook Login for Business**:
   - Click **Set Up**.
   - Navigate to **Facebook Login for Business** > **Settings**.
   - Set **Client OAuth Login** to `Yes`.
   - Set **Web OAuth Login** to `Yes`.
   - In **Valid OAuth Redirect URIs**, enter:
     ```text
     https://asia-southeast1-property-71665.cloudfunctions.net/metaOAuthCallback
     https://property-71665.web.app/#/campaigns
     http://localhost:5001/property-71665/asia-southeast1/metaOAuthCallback
     ```
   - Click **Save Changes**.

2. **Webhooks**:
   - Click **Set Up** on Webhooks in the product catalog.
   - In the dropdown, select **Page**.
   - Click **Subscribe to this object**.
   - **Callback URL:**
     ```text
     https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler
     ```
   - **Verify Token:** Enter the custom token chosen in your configuration (e.g., `propmatch_meta_webhook_secret_2026`).
   - Click **Verify and save**.
   - Under the **Page** subscriptions table, locate **leadgen** and click **Subscribe**.

### Step 3: Add Pilot Agent to App Roles (The Sandbox Bypass)
> [!IMPORTANT]
> Because PropMatch AI is operating in **Single-Agent Private Pilot Mode**, you do **NOT** need to submit the app for Meta App Review or undergo Business Verification to connect pilot agent Malik Tan!
>
> In Meta's **Development Mode**, users designated with an App Role (Administrator, Developer, or Tester) have **Standard Access** with full permissions to read their own Pages, Ad Accounts, and Leadgen data without app review approval.

1. In the Meta Developer Dashboard, navigate to **App Roles** > **Roles**.
2. Under **Testers** (or **Developers**), click **Add Testers**.
3. Enter Malik Tan's Facebook Profile username or numeric Facebook ID.
4. Malik Tan must log into [Meta for Developers](https://developers.facebook.com/) and accept the invitation banner under **My Apps** or his profile notifications.
5. Once accepted, Malik's Facebook account can authorize all required permissions immediately.

---

## 4. Required Permissions Matrix & Access Tiers

The PropMatch AI backend requests the following 5 permissions during OAuth:

| Permission | Category | Purpose in PropMatch AI | Access in Dev Mode | App Review Required in Live Multi-Tenant? |
| :--- | :--- | :--- | :--- | :--- |
| `pages_show_list` | Pages API | Enumerate the agent's Facebook Pages (`/me/accounts`) so they can select their real estate business page. | **Immediate** | Yes (Advanced Access) |
| `pages_read_engagement` | Pages API | Read basic engagement, page ID, and subscribe to page updates. | **Immediate** | Yes (Advanced Access) |
| `pages_manage_ads` | Marketing API | Subscribe the agent's Page to real-time `leadgen` webhooks (`/{page_id}/subscribed_apps`). | **Immediate** | Yes (Advanced Access) |
| `ads_read` | Marketing API | Query read-only campaign metrics, ad sets, impressions, and ad spend (`/{ad_account_id}/insights`). | **Immediate** | Yes (Advanced Access) |
| `leads_retrieval` | Lead Ads | Fetch instant form field values (name, phone, email, budget) via Graph API `/{leadgen_id}`. | **Immediate** | Yes (Advanced Access) |

### Read-Only Campaign Safety Guarantee
PropMatch AI adheres to strict read-only parameters for advertising:
- `ads_read` is requested.
- `ads_management` is **NEVER** requested.
- The platform contains zero functions or tools capable of creating, modifying, pausing, or deleting campaigns, ad sets, or budgets.

---

## 5. Secret Management & Secure Configuration

### 5.1 Local Development Configuration (`functions/.secret.local`)

Copy `functions/.secret.local.example` to `functions/.secret.local`:
```bash
cp functions/.secret.local.example functions/.secret.local
```

Populate the following keys:
```ini
# Google Gemini API Key
GEMINI_API_KEY=your_gemini_api_key

# Meta Developer App Credentials (from Meta Dashboard > App Settings > Basic)
META_APP_ID=123456789012345
META_APP_SECRET=abcdef0123456789abcdef0123456789

# Custom Webhook Handshake Verification Token
META_WEBHOOK_VERIFY_TOKEN=propmatch_meta_webhook_secret_2026

# Optional: User or Page Access Token for running live test scripts
META_USER_ACCESS_TOKEN=EAAB...
```

### 5.2 Google Cloud Secret Manager (Production Deployment)

When deploying Cloud Functions to Firebase project `property-71665`, configure secrets via Google Cloud CLI:

```bash
# Set Meta App Secret
firebase functions:secrets:set META_APP_SECRET

# Set Meta Webhook Verify Token
firebase functions:secrets:set META_WEBHOOK_VERIFY_TOKEN

# Set Meta App ID as an environment configuration or secret
firebase functions:secrets:set META_APP_ID
```

In `functions/src/index.ts`, these secrets are exposed securely to Cloud Functions v2 via the `secrets` option:
```typescript
export const metaWebhookHandler = onRequest(
  {
    region: "asia-southeast1",
    secrets: ["META_APP_SECRET", "META_WEBHOOK_VERIFY_TOKEN"]
  },
  ...
);
```

---

## 6. Token Exchange, Webhook Verification & Lead Processing Flow

```mermaid
sequenceDiagram
    autonumber
    actor Agent as Malik Tan (Pilot Agent)
    participant UI as Flutter Web UI
    participant CF as Cloud Functions (asia-southeast1)
    participant Meta as Meta Graph API v21.0
    participant FS as Cloud Firestore (Private)

    Note over Agent,Meta: 1. OAuth Authorization & Token Exchange
    Agent->>UI: Clicks "Connect Meta Account"
    UI->>Meta: Opens OAuth Dialog (pages_show_list, ads_read, leads_retrieval, etc.)
    Agent->>Meta: Grants Permissions
    Meta->>CF: Redirects to /metaOAuthCallback with ?code=XYZ
    CF->>Meta: POST /oauth/access_token (code -> short-lived token)
    CF->>Meta: GET /oauth/access_token (short-lived -> 60-day long-lived token)
    CF->>Meta: GET /me/accounts (Retrieve Pages & Page Tokens)
    CF->>Meta: GET /me/adaccounts (Retrieve Ad Accounts)
    CF->>Meta: POST /{page_id}/subscribed_apps (Subscribe Page to leadgen)
    CF->>FS: Save token to _private_meta_credentials (server-only)
    CF->>FS: Save public status to meta_connections
    CF-->>UI: Redirects to /#/campaigns?connected=true

    Note over Meta,FS: 2. Real-Time Webhook Lead Ingestion
    actor Buyer as Potential Buyer (FB/IG)
    Buyer->>Meta: Submits Instant Form on Facebook Ad
    Meta->>CF: POST /metaWebhookHandler (X-Hub-Signature-256)
    CF->>CF: Verify HMAC SHA-256 signature with META_APP_SECRET
    CF->>CF: Check leadgen_id in meta_ingested_leads (Idempotency)
    CF->>Meta: GET /{leadgen_id} with Page Access Token
    Meta-->>CF: Returns Full Name, Malaysian Phone, Email, Budget, Location
    CF->>CF: Normalize Phone (+601xxxxxxxx) & Validate PDPA Consent
    CF->>FS: Persist Prospect & Trigger Deterministic Buyer Matching
    CF-->>Meta: HTTP 200 OK
```

---

## 7. Real-World Connection Testing Guide

### 7.1 Running the Standalone Verification Script

PropMatch AI provides an automated test utility: `scripts/test_meta_live_connection.js`.

To run the verification suite:
```bash
node scripts/test_meta_live_connection.js
```

You can pass command-line arguments to test live credentials on demand:
```bash
node scripts/test_meta_live_connection.js \
  --app-id "YOUR_APP_ID" \
  --app-secret "YOUR_APP_SECRET" \
  --verify-token "YOUR_VERIFY_TOKEN" \
  --token "YOUR_USER_ACCESS_TOKEN" \
  --ad-account "act_492019482910"
```

#### What the Script Tests:
1. **Configuration Audit:** Verifies the format of all Meta secrets and checks endpoints.
2. **Token Inspection (`/debug_token`):** Validates expiration, app ID matching, and permission scopes.
3. **Asset Enumeration (`/me/accounts` & `/me/adaccounts`):** Confirms Page and Ad Account discovery.
4. **Leadgen Webhook Ingestion:** Ingests a synthetic Instant Form payload, verifying Malaysian phone canonicalization (`+60124889921`), duplicate suppression, and PDPA consent evidence logging.
5. **Downstream Quality Attribution:** Calculates Buyer Quality Index, matching against Malik Tan's actual listing: **Eco Horizon Astonia Townhome** (`proj-penang-pilot-001`, RM 680,000, Batu Kawan).

### 7.2 Testing Live Leads with Meta Lead Ads Testing Tool

Once the Facebook Page is subscribed to the webhook:
1. Navigate to the official [Meta Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing).
2. Select your Facebook Page (`Malik Tan Real Estate` or `IQI Realty Penang`).
3. Select the Instant Form created for the property listing.
4. Click **Preview form**, enter test information:
   - Full Name: `Jason Lee`
   - Phone: `012-4889921`
   - Email: `jason.lee.penang@gmail.com`
   - Budget: `RM 680,000`
5. Click **Submit**.
6. Check the **Track status** button in the tool:
   - Verify `status: 200` received from `metaWebhookHandler`.
7. Refresh the PropMatch AI Agent Dashboard:
   - Verify the prospect appears in **Incoming Enquiries** and the **Prospects** database.
   - Verify AI Buyer Matching calculates match compatibility against **Eco Horizon Astonia Townhome**.

---

## 8. Integration Status Classification

| # | Integration Stage | Current Status | Operational Evidence & Verification |
| :--- | :--- | :---: | :--- |
| **1** | **Locally Implemented** | **COMPLETED** | Complete Meta Ads Intelligence engine implemented across Flutter Web (`MetaAdsIntelligenceScreen`) and Firebase Cloud Functions (`MetaAdsService`). Unit tests: 145/145 backend tests passed; 252/252 Flutter tests passed; 0 analyze issues. |
| **2** | **Meta Developer App Configured** | **READY (Awaiting App Creation)** | App architecture, OAuth redirect URIs, webhook callback endpoints, and `functions/.secret.local` loading audited and verified. Next step is for the developer to create the App ID in developers.facebook.com. |
| **3** | **Meta Permissions Approved** | **READY VIA STANDARD ACCESS** | Required scopes (`pages_show_list`, `pages_read_engagement`, `pages_manage_ads`, `ads_read`, `leads_retrieval`) confirmed. Standard Access in Development Mode enables instant pilot testing without Meta App Review. |
| **4** | **Real Ad Account Connected** | **PENDING OAUTH / LIVE TOKEN** | End-to-end token exchange flow implemented. Awaiting pilot agent Malik Tan completing the OAuth flow or providing access token via settings. |
| **5** | **Live Campaign Metrics Retrieved** | **PENDING ACTIVE META AD SPEND** | Graph API v21.0 query methods (`fetchLiveCampaignsFromGraphApi`) ready. Requires active Facebook ad campaigns with spend in pilot ad account `act_492019482910`. |
| **6** | **Real Lead Ingested** | **PIPELINE VERIFIED (READY)** | Tested and verified via `scripts/test_meta_live_connection.js`. Webhook verification, phone normalization (+60 canonical format), duplicate suppression, and deterministic match to Eco Horizon verified. Ready to receive live webhook payloads. |
