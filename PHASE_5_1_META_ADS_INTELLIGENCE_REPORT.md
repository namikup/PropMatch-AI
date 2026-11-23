# PropMatch AI — Phase 5.1: Meta Ads Intelligence Integration Report

**Execution Date:** November 24, 2026  
**Module:** Meta Ads Intelligence (Marketing API, Ads Insights API & Lead Ads Webhooks)  
**Target Environment:** Flutter Web (Local Emulators & Firebase Functions in `asia-southeast1`)  
**Designated Pilot Agent:** Malik Tan, IQI Realty Sdn Bhd (`pilot-agent-malik-001`)  
**Designated Property:** Eco Horizon Astonia Townhome, Batu Kawan, Penang (RM680,000 – RM850,000)  
**Integration Status Classification:** **Locally Implemented & Verified with Comprehensive Automated Test Suites (Mocks & Emulators)**

---

## Executive Summary

Phase 5.1 implemented **Meta Ads Intelligence** for PropMatch AI, connecting individual Malaysian property agents to their Meta advertising assets (Facebook Pages, Ad Accounts, and Lead Generation Instant Forms).

Rather than creating a superficial vanity-metrics dashboard, Phase 5.1 built an end-to-end intelligence engine that:
1. Captures advertising expenditure, impressions, reach, link clicks, CTR, CPC, CPM, leads, and Cost Per Lead (CPL) directly from Meta's Marketing API and Ads Insights API.
2. Ingests submitted Facebook & Instagram Instant Form leads via real-time webhooks or API synchronization into PropMatch AI's existing 6-stage Lead Ingestion Pipeline.
3. Correlates advertising spend directly with **buyer quality metrics** (valid contactable leads under PDPA, qualified prospects, listing matches, viewing appointments, converted buyers, and Cost per Qualified Buyer).
4. Employs Google Gemini to interpret campaign trends and deliver strategic, grounded recommendations citing exact sample sizes and data observation periods without ever altering advertising budgets directly.
5. Strictly enforces **read-only governance** with respect to live ad campaigns (no automated ad creation, pausing, deleting, or budget modification).

---

## 1. System Architecture

The integration follows a zero-trust, backend-centric architecture. No Meta app secrets, access tokens, or refresh credentials are ever exposed to Flutter Web.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Meta Advertising Platform                             │
│   ┌────────────────────┐   ┌────────────────────┐   ┌──────────────────────┐    │
│   │ Facebook Page / Ad │   │ Marketing API /    │   │ Lead Ads Webhook /   │    │
│   │ Account (OAuth)    │   │ Insights API       │   │ Instant Forms        │    │
│   └─────────┬──────────┘   └─────────▲──────────┘   └──────────┬───────────┘    │
└─────────────┼────────────────────────┼─────────────────────────┼────────────────┘
              │                        │                         │
              │ 1. OAuth Code          │ 3. Pull Metrics         │ 4. Push Real-Time
              │    Exchange            │    & Ad Creatives       │    Leadgen Event
              ▼                        │                         ▼
┌──────────────────────────────────────┴──────────────────────────────────────────┐
│                   Firebase Cloud Functions v2 (asia-southeast1)                 │
│                                                                                 │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │ MetaAdsService (functions/src/services/meta_ads_service.ts)            │    │
│   │  • CSRF & OAuth State Verification (HMAC-SHA256)                       │    │
│   │  • Webhook Signature Verification (x-hub-signature-256)               │    │
│   │  • Idempotency Check (_meta_ingested_leads)                            │    │
│   │  • Secret Storage (_private_meta_credentials — Server-Only)            │    │
│   │  • Deterministic Performance Math (CTR, CPC, CPM, CPL)                 │    │
│   │  • Buyer Quality Funnel Correlation (Firestore queries)                │    │
│   │  • Grounded Gemini AI Campaign Intelligence                            │    │
│   └──────────────────────────────────┬─────────────────────────────────────┘    │
│                                      │                                          │
│                                      ▼ 5. Forward Payload                       │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │ LeadIngestionService (functions/src/services/lead_ingestion_service.ts)│    │
│   │  • Stage 1: Source Validation ("Facebook Lead Ads")                    │    │
│   │  • Stage 2: Normalization (E.164 +601X phone & email lowercase)        │    │
│   │  • Stage 3: Duplicate Suppression (Same phone in agent database)       │    │
│   │  • Stage 4: PDPA Consent Verification (Eligible / Non-broad marketing) │    │
│   │  • Stage 5: Ownership Locking (Forced to pilot-agent-malik-001)        │    │
│   │  • Stage 6: Deterministic 5-Factor Matching against Real Property      │    │
│   └──────────────────────────────────┬─────────────────────────────────────┘    │
└──────────────────────────────────────┼──────────────────────────────────────────┘
                                       │
                                       │ 6. Real-Time Reactive State
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     Flutter Web Client (Single-Agent Pilot)                     │
│                                                                                 │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │ CampaignsScreen (lib/screens/campaigns/campaigns_screen.dart)          │    │
│   │  ├─► Tab 0: Meta Ads Intelligence (MetaAdsIntelligenceScreen)          │    │
│   │  │    • Connection Overview Card (Page, Ad Account, Scopes, Sync)      │    │
│   │  │    • Advertising Performance KPIs (Spend, Reach, CTR, CPC, CPL)     │    │
│   │  │    • Buyer Quality Conversion Funnel & Unit Economics               │    │
│   │  │    • Campaign Comparison Table                                      │    │
│   │  │    • Gemini AI Strategic Intelligence (Sample-grounded)             │    │
│   │  │    • Read-Only Governance & PDPA Notice                             │    │
│   │  └─► Tab 1: Multi-Channel Creatives (Ad Copy / Headlines)              │    │
│   └────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Files Created and Modified

### Backend (Firebase Cloud Functions v2)
1. `functions/src/types/meta_ads.types.ts` (*Created*): Type definitions for connections, campaigns, ad sets, ads, buyer quality metrics, lead payloads, and Gemini insights.
2. `functions/src/services/meta_ads_service.ts` (*Created*): Core Meta Marketing, Insights, Webhook, and Buyer Quality service.
3. `functions/src/config/firebase.config.ts` (*Modified*): Added collections `metaConnections`, `metaCampaigns`, `metaIngestedLeads`, `metaSyncLogs`, and server-private collection `_private_meta_credentials`.
4. `functions/src/services/lead_ingestion_service.ts` (*Modified*): Added `"Facebook Lead Ads"` to authorized ingestion sources.
5. `functions/src/index.ts` (*Modified*): Exported onCall endpoints (`getMetaConnectionStatus`, `connectMetaAccount`, `disconnectMetaAccount`, `syncMetaCampaigns`, `getMetaCampaigns`, `generateMetaCampaignAIIntelligence`) and HTTP webhook handler (`metaWebhookHandler`).
6. `functions/tests/meta_ads_service.test.ts` (*Created*): 13 backend unit tests covering OAuth CSRF, token security, webhook signatures, idempotency, deterministic calculations, and multi-tenant isolation.

### Frontend (Flutter Web)
7. `lib/models/meta_ads/meta_connection_model.dart` (*Created*): Data model for public connection state, accounts, and permissions.
8. `lib/models/meta_ads/meta_buyer_quality_model.dart` (*Created*): Data model for funnel metrics (leads, contactable, qualified, viewings, conversions, cost per qualified buyer).
9. `lib/models/meta_ads/meta_campaign_model.dart` (*Created*): Data model for campaigns, ad sets, ads, and performance statistics.
10. `lib/models/meta_ads/meta_ai_insight_model.dart` (*Created*): Data model for Gemini recommendations, sample size, and confidence rating.
11. `lib/services/meta_ads_service.dart` (*Created*): Client-side service connecting to backend functions with graceful fallback for pilot/local development.
12. `lib/services/prospect_sources/meta_lead_ads_adapter.dart` (*Created*): Adapter implementing `ProspectSourceAdapter` for Meta Lead Ads.
13. `lib/services/prospect_sources/source_registry.dart` (*Modified*): Registered `MetaLeadAdsAdapter` in the central source registry.
14. `lib/screens/campaigns/meta_ads_intelligence_screen.dart` (*Created*): Full interactive dashboard rendering connection status, KPI grid, quality funnel, comparison table, and AI intelligence.
15. `lib/screens/campaigns/campaigns_screen.dart` (*Modified*): Added tab selector ("Meta Ads Intelligence" as default tab, "Multi-Channel Creatives" as secondary tab).
16. `test/phase5_1_meta_ads_intelligence_test.dart` (*Created*): 7 Flutter unit and widget tests covering models, adapter validation, pipeline ingestion, tab navigation, and UI rendering.

---

## 3. Required Meta Permissions

Meta enforces strict permission tiers. For a production deployment, the Meta Developer App requires the following permissions:

| Permission | Scope Type | Purpose in PropMatch AI | Approval Level Required |
|---|---|---|---|
| `ads_read` | Read-only | Retrieve ad accounts, campaigns, ad sets, ads, and performance insights (spend, reach, clicks, CTR, CPC, CPM, leads). | **App Review Required** for live accounts. |
| `leads_retrieval` | Read-only | Retrieve submitted buyer Instant Form data (name, phone, email, budget, location) via Graph API `/{leadgen_id}`. | **App Review & Business Verification Required**. |
| `pages_read_engagement` | Read-only | Enumerate Facebook Pages managed by the agent and read engagement statistics. | **App Review Required** for live accounts. |
| `pages_manage_ads` | Read-only / Hook | Manage ad associations and subscribe Facebook Pages to webhooks for real-time `leadgen` events. | **App Review Required**. |
| `public_profile` | User identity | Basic agent profile identification during OAuth handshake. | Default granted. |

---

## 4. OAuth Setup Instructions

To configure live Meta OAuth for PropMatch AI:

1. **Create Meta Developer App:**
   - Log into [Meta for Developers](https://developers.facebook.com/).
   - Click **Create App** → Select App Type: **Business**.
   - App Name: `PropMatch AI — Advertising Intelligence`.
2. **Add Products:**
   - Add **Facebook Login for Business** and **Webhooks**.
3. **Configure OAuth Redirect URI:**
   - Add the authorized redirect URI: `https://<domain>/api/meta/oauth/callback` or `https://asia-southeast1-property-71665.cloudfunctions.net/metaOAuthCallback`.
4. **Configure Webhook Subscription:**
   - Under Webhooks → Select **Page** → Subscribe to field `leadgen`.
   - Callback URL: `https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler`.
   - Verify Token: Configure a random high-entropy token stored in `META_WEBHOOK_VERIFY_TOKEN`.
5. **App Secret & ID Configuration:**
   - Note down `App ID` and `App Secret` from App Settings → Basic.

---

## 5. Firebase Configuration Requirements

All sensitive credentials reside exclusively in the backend runtime.

### Secret Manager / Environment Configuration
```bash
# In production with Blaze plan:
firebase functions:secrets:set META_APP_SECRET
firebase functions:secrets:set META_WEBHOOK_VERIFY_TOKEN
firebase functions:secrets:set GEMINI_API_KEY

# In local emulator (.secret.local or functions/.env):
META_APP_SECRET=propmatch_meta_secret_2026
META_WEBHOOK_VERIFY_TOKEN=propmatch_verify_token_2026
GEMINI_API_KEY=AIzaSy...
```

### Firestore Security Rules Guard
The private credentials collection `_private_meta_credentials` must be blocked from all client reads:
```javascript
match /_private_meta_credentials/{ownerId} {
  allow read, write: if false; // Strictly server-only via Cloud Functions Admin SDK
}

match /meta_connections/{ownerId} {
  allow read: if request.auth != null && request.auth.uid == ownerId;
  allow write: if false; // Only Cloud Functions can update connection state
}
```

---

## 6. Security and Privacy Implementation

1. **CSRF Protection:** OAuth initiation generates an HMAC-SHA256 signed state parameter incorporating the agent's `ownerId`, a random nonce, and a 15-minute expiration timestamp.
2. **Timing-Safe Webhook Verification:** The incoming `x-hub-signature-256` header is validated against the raw request buffer using `crypto.timingSafeEqual` to prevent timing attacks.
3. **Idempotency & Duplicate Suppression:** Every incoming `leadgen_id` is tracked in the `meta_ingested_leads` collection. Duplicate delivery events from Meta's webhook retry system are acknowledged with HTTP 200 while duplicate prospect creation is suppressed.
4. **Malaysian PDPA 2010 Compliance:**
   - Enquiries captured via Instant Forms are mapped to `enquiryConsentGranted: true` and `contactEligibility: 'Eligible'`.
   - However, `marketingConsentGranted` remains `false` — an ad enquiry on a specific property does NOT grant unrestricted marketing consent across unrelated offerings.
   - Complete consent evidence (`Meta Instant Form Submission (ID: ...) with Privacy Policy Checkbox`) is preserved.
5. **Single-Agent Pilot Isolation:** Webhook ingestion queries the Page-to-Agent mapping in `meta_connections`. In the private pilot mode, all incoming leads are forcefully assigned to `pilot-agent-malik-001`. Cross-tenant queries are blocked.
6. **PII Redaction in Logs:** Raw phone numbers and emails are never logged in plain text in production Cloud Logging.

---

## 7. Lead Ingestion Workflow

```
[Buyer submits Facebook Instant Form]
  │   Leadgen ID: 894029104829102
  │   Ad: Eco Horizon Astonia — 4-Bed Spacious Gated Living
  │   Form fields: Full Name, Phone, Email, Location, Budget
  │
  ▼
[Meta Webhook Triggered -> metaWebhookHandler]
  │   Verifies HMAC-SHA256 header (x-hub-signature-256)
  │   Idempotency check: Confirms leadgenId has not been processed
  │
  ▼
[MetaAdsService.ingestMetaLead]
  │   Extracts standard & custom question fields
  │   Normalizes phone (+6012...) and email
  │   Constructs RawEnquiryInput with sourceType: "Facebook Lead Ads"
  │
  ▼
[LeadIngestionService.processEnquiry]
  │   Stage 1: Source Validation -> Accepted
  │   Stage 2: Sanitization & Normalization -> Sanitized
  │   Stage 3: Duplicate Check against Malik Tan's database -> Unique
  │   Stage 4: Consent Check -> Explicit Instant Form Consent -> Eligible
  │   Stage 5: Single-Agent Boundary -> ownerId: pilot-agent-malik-001
  │   Stage 6: Deterministic Matching -> Evaluated against Eco Horizon Astonia
  │            (Budget: 25/25, Location: 25/25, Type: 20/20, Purpose: 15/15)
  │            Match Score: 95.0% (High Compatibility)
  │
  ▼
[Firestore Persistence & Notification]
  │   ProspectModel created under pilot-agent-malik-001
  │   Added to Buyer Intelligence & Meta Ads Quality Funnel
```

---

## 8. Dashboard Functionality

The Meta Ads Intelligence module is accessed under the **Campaigns** section via the primary tab:

### 1. Connection Overview Card
- Displays Facebook Page name (`IQI Northern Region — Malik Tan Real Estate`) and Ad Account ID (`act_492019482910`).
- Displays live connection status pill (`Connected` / `Disconnected` / `Reauthorization Required`).
- Displays granted permission chips (`ads_read`, `leads_retrieval`, `pages_read_engagement`, `pages_manage_ads`).
- "Sync Now" button with reactive spinner to trigger incremental synchronization.
- Disconnect button with confirmation dialog.

### 2. Advertising Performance KPI Grid
- **Total Ad Spend**: Aggregated expenditure in Ringgit Malaysia (e.g. `RM 1,120.00`).
- **Impressions & Reach**: Total reach and ad impressions (e.g. `41,300 / 30,600`).
- **Link Clicks & CTR**: Click volume and click-through percentage (e.g. `810 (1.96%)`).
- **Average CPC & CPM**: Cost per click and cost per thousand impressions (e.g. `RM 1.38 / RM 27.12`).
- **Instant Form Leads**: Total leads captured (e.g. `36 leads`).
- **Cost Per Lead (CPL)**: Average cost per raw enquiry (e.g. `RM 31.11`).

### 3. Buyer Quality & Conversion Funnel
- Displays the full 5-stage conversion progression:
  `Total Leads (36)` → `Contactable (31)` → `Qualified (19)` → `Viewings (5)` → `Converted (1)`.
- **Cost per Qualified Buyer**: Total spend divided by qualified leads (e.g. `RM 58.95`).
- **Cost per Viewing Appointment**: Total spend divided by booked site viewings (e.g. `RM 224.00`).
- Displays explicit `"Unavailable"` for campaigns with zero viewings/conversions rather than fabricating misleading numbers.

### 4. Campaign Comparison Table
- Compares individual campaigns (e.g. *Eco Horizon Astonia Launch* vs *Agent Branding*).
- Directly contrasts click-efficiency against buyer-quality (highlighting that branding ads generated cheap clicks but zero qualified viewings, while targeted landed ads achieved a 56.3% qualification rate).

### 5. Gemini AI Campaign Intelligence
- Displays data observation window (`Active Campaign Window (Last 30 Days)`).
- Displays sample size badge (`Sample Size: 36 leads`) and statistical confidence level (`Moderate`).
- Provides grounded executive summaries, top-performing angles, budget leak warnings, and creative recommendations for Malaysian property seekers.
- Displays prominent **Read-Only Advisory Notice**: confirms that AI recommendations are informational only and never alter live Meta budgets automatically.

---

## 9. AI Analysis Methodology

1. **Deterministic Foundations:** All calculations for spend, CTR, CPC, CPM, CPL, qualification rate, and cost-per-qualified-buyer are computed mathematically in code. Gemini is never used for arithmetic.
2. **Grounding & Sample Size Requirements:**
   - Sample < 10 leads: Confidence rated as `"Insufficient Data"`.
   - Sample 10 – 29 leads: Confidence rated as `"Low"`.
   - Sample 30 – 99 leads: Confidence rated as `"Moderate"`.
   - Sample 100+ leads: Confidence rated as `"High"`.
3. **Prompt Constraints:**
   - The system prompt forbids claims of statistical significance from small samples.
   - The model must cite the observed date window and lead count in all observations.
   - The model is instructed to focus on property-specific nuances (e.g. Batu Kawan Industrial Park engineers, dual-generation families, gated compound security).
4. **Strictly Advisory:** System instructions mandate that all recommendations are strictly informational. The platform provides no automated budget modification tooling.

---

## 10. Test Results & Verification Evidence

### 1. Backend Jest Test Suite (`functions/tests/meta_ads_service.test.ts`)
Command: `npm test --prefix functions -- tests/meta_ads_service.test.ts`  
Result: **13 passed, 0 failed**

```text
PASS tests/meta_ads_service.test.ts
  Phase 5.1 — Meta Ads Intelligence Service (Backend)
    OAuth Security & CSRF State Validation
      ✓ generates and verifies valid HMAC-signed OAuth state (2 ms)
      ✓ rejects OAuth state with mismatched ownerId (CSRF prevention)
      ✓ rejects tampered OAuth state payload (1 ms)
    Token Storage Security & Permission Auditing
      ✓ saves tokens only to private collection and never exposes raw tokens in public config (17 ms)
      ✓ flags missing permissions when not all scopes are granted (2 ms)
      ✓ purges private credentials completely upon disconnection (1 ms)
    Webhook Signature & Idempotency
      ✓ validates legitimate Meta Webhook x-hub-signature-256 header (1 ms)
      ✓ rejects invalid or tampered webhook signatures
      ✓ suppresses duplicate lead webhook delivery idempotently (1 ms)
    Deterministic Campaign Metrics & Buyer Quality
      ✓ computes exact CTR, CPC, CPM and Cost Per Lead deterministically (1 ms)
      ✓ preserves null for cost per viewing when viewings are 0 without fabricating fake metrics
    AI Campaign Intelligence Grounding
      ✓ generates grounded AI insights citing exact sample size and data period (1 ms)
    Multi-Tenant Data Isolation
      ✓ ensures Agent B cannot view or access Agent A's Meta campaigns (1 ms)

Test Suites: 1 passed, 1 total
Tests:       13 passed, 13 total
```

### 2. Full Backend Regression Test Suite
Command: `npm test --prefix functions -- --runInBand`  
Result: **15 passed, 15 total (145 tests passed, 0 failed)**

### 3. Frontend Flutter Test Suite (`test/phase5_1_meta_ads_intelligence_test.dart`)
Command: `flutter test test/phase5_1_meta_ads_intelligence_test.dart`  
Result: **7 passed, 0 failed**

```text
00:02 +0: Phase 5.1 1.1 MetaConnectionModel serializes and tracks missing permissions accurately
00:02 +1: Phase 5.1 1.2 MetaBuyerQualityModel preserves null when viewings are zero without fabricating values
00:02 +2: Phase 5.1 2.1 MetaLeadAdsAdapter is registered in ProspectSourceRegistry
00:02 +3: Phase 5.1 2.2 MetaLeadAdsAdapter validates and parses Instant Form lead payload
00:02 +4: Phase 5.1 3.1 Ingesting Facebook Lead Ads through LeadIngestionPipeline matches real property
00:03 +5: Phase 5.1 4.1 CampaignsScreen renders tab selector and defaults to Meta Ads Intelligence
00:03 +6: Phase 5.1 4.2 MetaAdsIntelligenceScreen renders KPIs, Funnel, and Gemini AI sections
00:03 +7: All tests passed!
```

### 4. Full Flutter Regression Test Suite
Command: `flutter test`  
Result: **252 passed, 0 failed across all 25 test files** (100% pass rate)

### 5. Flutter Static Code Analysis
Command: `flutter analyze`  
Result: **0 issues found**

---

## 11. Features Requiring External Meta Approval

In accordance with Meta Developer Platform policies, the following items require external actions before live production access:

1. **Meta Business Verification:**
   - The legal entity (e.g. agency or business registered in Malaysia with SSM) must complete Business Verification in Meta Business Suite.
2. **Meta App Review Submission:**
   - Required for `ads_read`, `leads_retrieval`, and `pages_manage_ads`.
   - Requires screen recording demonstrations showing how permissions are utilized in PropMatch AI.
3. **Data Protection & Privacy Policy URL:**
   - A publicly accessible Privacy Policy conforming to Meta's developer terms and Malaysian PDPA must be linked in the app settings.

---

## 12. Steps for a Real-World Pilot Connection

To connect pilot agent Malik Tan to real live Meta Ads:

1. **In Meta for Developers:**
   - Add Malik Tan's Facebook User Account as a **Tester** or **Developer** under App Roles (bypasses the need for App Review during initial testing).
2. **In Meta Business Suite:**
   - Grant Malik Tan's Facebook user `Admin` or `Advertiser` access to the target Facebook Page and Ad Account (`act_492019482910`).
3. **Perform Authorization Handshake:**
   - Navigate to PropMatch AI → Campaigns → Meta Ads Intelligence.
   - Click "Connect Meta Account" to trigger the Meta OAuth dialog.
   - Malik Tan approves the requested permissions (`ads_read`, `leads_retrieval`, `pages_read_engagement`, `pages_manage_ads`).
4. **Configure Real-Time Webhook:**
   - In Meta App Dashboard → Webhooks → Subscribe Page to `leadgen` events pointing to the deployed Cloud Function endpoint.
5. **Run Test Lead Submission:**
   - Use the official [Meta Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing) to fire a test submission on Malik Tan's Instant Form.
   - Verify that the lead appears in PropMatch AI within 3 seconds with deterministic match scoring against the Eco Horizon Astonia listing.

---

## 13. Integration Status Classification

As required by product governance standards, the integration status is formally classified below:

| Status Milestone | Verified State | Supporting Evidence |
|---|---|---|
| **Locally Implemented** | **YES (Complete)** | Backend services, Cloud Functions endpoints, frontend screens, data models, and adapters are fully authored and compiling cleanly (`tsc` 0 errors, `flutter analyze` 0 issues). |
| **Tested with Mocks** | **YES (Complete)** | Comprehensive Jest (13 tests) and Flutter (7 tests) test suites verified all OAuth, webhook, HMAC, idempotency, calculation, and UI scenarios with 100% pass rate. |
| **Connected to a Real Meta Developer App** | **Pending Credentials** | Architecture is 100% ready for App ID & App Secret insertion; waiting for user/agent Developer App registration. |
| **Real Advertising Account Authorised** | **Pending Pilot Credentials** | Ready for pilot agent Malik Tan OAuth login via Facebook Login for Business dialog. |
| **Live Campaign Metrics Retrieved** | **Pending Live API Call** | Mock and local fallback verified; live call triggers automatically upon access token receipt. |
| **Real Lead Successfully Ingested** | **Pending Live Form Submission** | End-to-end ingestion pipeline from webhook to deterministic buyer matching verified via automated test payloads. |
