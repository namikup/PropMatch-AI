# PropMatch AI — Phase 5.1A.3.1: Technical Correction & Pre-Connection Verification Report

**Target Pilot Agent**: Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
**Designated Listing**: Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  
**Execution Environment**: Single-Agent Private Pilot Mode  
**Audit Date**: November 2026  

---

## 1. Executive Summary

Following a rigorous review of the Phase 5.1A.3 pre-connection audit report, several technical assumptions regarding Meta API versions, permission boundaries (`ads_management`), Instagram webhook mechanics, and diagnostic script reporting required technical correction and verification against official Meta Developer documentation.

This report documents:
1. The original unverified assumptions.
2. The corrected technical realities backed by official Meta documentation.
3. Code files modified to implement the corrections.
4. Comprehensive testing and verification results.
5. The remaining operational blockers and the final verdict: **`READY WITH BLOCKERS`**.

---

## 2. Table of Corrections

| Area of Audit | Original Assumption (Phase 5.1A.3) | Corrected Technical Reality (Phase 5.1A.3.1) | Official Meta Reference |
| :--- | :--- | :--- | :--- |
| **1. API Version Schedule** | Claimed `v26.0` was the latest stable release across both APIs. | `v27.0` is the latest major release (Nov 4, 2026). `v26.0` (July 29, 2026) is an active stable baseline supported through mid-2028. Version definitions are now centralized in `meta.config.ts`. | [Meta Version Changelog](https://developers.facebook.com/docs/graph-api/changelog/versions/) |
| **2. Permission Scope: `ads_management`** | Claimed `ads_management` is universally unnecessary for lead retrieval and was excluded without qualification. | Meta requires `ads_management` if querying ad-specific fields (`ad_id`, `campaign_id`) directly on `GET /{leadgen_id}`. However, form field answers (`field_data`) require only `leads_retrieval` + Page access, and webhooks provide `ad_id` directly. Core field fallback was implemented to preserve the read-only boundary. | [Lead Ads Retrieving Guide](https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving/) |
| **3. Instagram Webhooks** | Assumed Facebook and Instagram webhook subscriptions operate identically via `POST /{page_id}/subscribed_apps`. | Meta's documentation explicitly notes that Page `subscribed_apps` cannot configure Instagram-specific webhooks. However, Lead Ads Instant Forms are Facebook Page assets that flow through the **Page** `leadgen` webhook subscription (not Instagram webhooks). Source attribution logic was enhanced. | [Page Subscribed Apps Reference](https://developers.facebook.com/docs/graph-api/reference/page/subscribed_apps/) |
| **4. Diagnostic Script Truthfulness** | Labelled offline synthetic test stages as "PASSED", implying live Meta connection succeeded without credentials. | Script refactored into two distinct sections: local synthetic simulation vs. live network testing. When live credentials are absent, the script explicitly reports `LIVE CONNECTION NOT TESTED`. | `scripts/test_meta_live_connection.js` |
| **5. Final Readiness Verdict** | Claimed `READY FOR REAL META TEST CONNECTION` without acknowledging missing Developer App. | Corrected to **`READY WITH BLOCKERS`** because live testing cannot commence until the administrator registers the Meta Developer App and provisions live secrets. | Pre-flight Checklist |

---

## 3. Detailed Technical Analysis of Corrections

### 3.1 Central Meta Version Configuration
- **Problem**: Version constants (`v26.0`) were previously hardcoded inside service files.
- **Solution**: Created `functions/src/config/meta.config.ts`.
- **Implementation**:
  - Defines `META_GRAPH_API_VERSION`, `META_MARKETING_API_VERSION`, and base URLs.
  - Embeds the official version schedule table (from `v21.0` through `v27.0`) including exact release dates, expiration dates, and deprecation policies.
  - Allows version overrides via environment variables (`META_GRAPH_API_VERSION`, `META_MARKETING_API_VERSION`) for seamless upgrades without modifying service code.

### 3.2 The `ads_management` Permission Boundary & Fallback Engine
- **Problem**: Meta's Lead Ads documentation states that querying ad-specific fields (`ad_id`, `ad_name`, `adset_id`, `campaign_id`) on the `leadgen` Graph API node requires `ads_management`.
- **Security Implication**: Granting `ads_management` gives write access to ad campaigns, daily budgets, and billing, introducing unacceptable financial liability.
- **Solution — Restricted Integration Architecture**:
  1. PropMatch AI does **not** make `ads_management` a mandatory scope.
  2. In `functions/src/services/meta_ads_service.ts`, `fetchLeadDetailsFromGraphApi` and `fetchFormLeads` implement an automated field fallback:
     - The service requests full fields first.
     - If Meta returns an HTTP error (because `ads_management` is absent), the service retries with core fields (`id,created_time,form_id,field_data`), which require only `leads_retrieval` and Page access.
  3. The real-time webhook payload already provides `ad_id` and `campaign_id` directly in `change.value` without needing `ads_management`.
  4. Campaign spend and analytics are retrieved using strictly read-only **`ads_read`**.
  5. The codebase enforces an immutable internal code boundary containing zero write endpoints targeting Meta advertising campaigns.

### 3.3 Instagram Lead Ads Webhook Mechanics & Source Attribution
- **Problem**: The Page `subscribed_apps` reference states that Instagram webhooks cannot be subscribed via the Page `subscribed_fields` parameter.
- **Technical Clarification**:
  - The restriction applies to Instagram Graph API fields (such as `comments`, `mentions`, `messages`).
  - Instant Forms are assets owned by the **Facebook Page**. When Lead Ads run on Instagram, the lead notification dispatches through the **Page** `leadgen` webhook subscription.
  - In Meta App Dashboard, developers subscribe to `leadgen` under the **Page** object, not the Instagram object.
  - Retrieval requires a **Page Access Token** from `GET /v26.0/me/accounts`.
- **Source Attribution**:
  - Enhanced `ingestMetaLead` in `meta_ads_service.ts` to inspect ad names, campaign names, and referral tags to automatically classify incoming leads as `Instagram Lead Ads` (`utm_source: "instagram"`) vs `Facebook Lead Ads` (`utm_source: "facebook"`).
  - Updated `LeadIngestionService.processEnquiry` to accept `Instagram Lead Ads` and `Meta Lead Ads` in its Stage 1 Source Validation whitelist.

### 3.4 Diagnostic Script Rigor (`scripts/test_meta_live_connection.js`)
- **Problem**: Previous script output mixed synthetic test passes with live connection statuses.
- **Solution**: Completely refactored `scripts/test_meta_live_connection.js`:
  - **Section 2 (Local Simulation)**: Explicitly tests offline regexes, E.164 phone normalization, idempotency, and project matching in local memory.
  - **Section 3 (Live Connection Audit)**: Explicitly tests credentials. When `META_APP_ID`, `META_APP_SECRET`, or access tokens are missing, it outputs:
    ```
    ================================================================================
      LIVE META CONNECTION STATUS:
      ⚠️  LIVE CONNECTION NOT TESTED
      Reason: Live Meta credentials are not provisioned.
    ================================================================================
    ```
  - Eliminates fake success checkmarks for untested network operations.

---

## 4. Code Files Changed

| File Modified / Created | Nature of Changes |
| :--- | :--- |
| `functions/src/config/meta.config.ts` | **NEW FILE**: Centralized Meta API version configuration, lifecycle metadata schedule (v21.0 to v27.0), and URL helpers. |
| `functions/src/services/meta_ads_service.ts` | **MODIFIED**: Imported central version config, implemented core field fallback in `fetchLeadDetailsFromGraphApi` and `fetchFormLeads`, added Instagram source attribution detection in `ingestMetaLead`. |
| `functions/src/services/lead_ingestion_service.ts` | **MODIFIED**: Added `"Instagram Lead Ads"` and `"Meta Lead Ads"` to `validSources` whitelist in Stage 1 Source Validation. |
| `functions/src/types/meta_ads.types.ts` | **MODIFIED**: Added `referralSource?: string` and `platform?: string` to `MetaLeadPayload`. |
| `scripts/test_meta_live_connection.js` | **REFACTORED**: Enforced strict separation between local synthetic tests and live network calls; reports `LIVE CONNECTION NOT TESTED` when credentials are absent. |
| `PHASE_5_1A_3_META_COMPATIBILITY_AUDIT.md` | **UPDATED**: Corrected version schedules, `ads_management` fallback analysis, and Instagram webhook details. |
| `PHASE_5_1A_3_META_PERMISSION_MATRIX.md` | **UPDATED**: Added granular operation-by-operation table across all 5 requested operations; documented Restricted Architecture. |
| `PHASE_5_1A_3_OAUTH_SECURITY_AUDIT.md` | **UPDATED**: Verified preservation of HMAC-SHA256, timingSafeEqual, token isolation, and evaluated impact of updated scopes. |
| `PHASE_5_1A_3_LIVE_CONNECTION_READINESS.md` | **UPDATED**: Updated 7-stage checklist, separated diagnostic layers, set verdict to `READY WITH BLOCKERS`. |

---

## 5. Tests Performed & Verification Results

All local test suites and builds were executed and verified:

```
┌──────────────────────────────────────────────┬─────────────┬────────────────────────────────────┐
│ Test Suite / Tool                            │ Result      │ Execution Time / Metrics           │
├──────────────────────────────────────────────┼─────────────┼────────────────────────────────────┤
│ TypeScript Build (`tsc`)                     │ ✅ 0 Errors │ Clean compilation to lib/          │
│ Backend Jest Tests (15 test suites)          │ ✅ PASSED   │ 147 / 147 Tests Passed (11.0s)     │
│ Flutter Analyze (`flutter analyze`)          │ ✅ 0 Issues │ No issues found (2.8s)             │
│ Flutter Tests (`flutter test`)               │ ✅ PASSED   │ 7 / 7 Tests Passed (3.0s)          │
│ Flutter Web Release Build (`build web`)      │ ✅ PASSED   │ ✓ Built build/web (26.6s)          │
│ Diagnostic Script (`test_meta_live...`)      │ ✅ PASSED   │ Local simulation verified;         │
│                                              │             │ Live connection: NOT TESTED        │
└──────────────────────────────────────────────┴─────────────┴────────────────────────────────────┘
```

---

## 6. Remaining Blockers & Final Verdict

### 6.1 Operational Blockers (Actions for Developer/DevOps)
Before a live test connection can be established:
1. **Blocker 1 (App Creation)**: Register a Meta Developer App (Type: `Business`) at `https://developers.facebook.com`.
2. **Blocker 2 (Secrets Provisioning)**: Add `META_APP_ID`, `META_APP_SECRET`, and `META_WEBHOOK_VERIFY_TOKEN` into `functions/.secret.local`.
3. **Blocker 3 (App Role Assignment)**: Add agent Malik Tan's personal Facebook account under **App Roles > Roles > Testers** in the Developer App dashboard.
4. **Blocker 4 (Webhook Subscription in Dashboard)**: In the Developer App dashboard under **Webhooks > Page**, register the callback URL (`https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler`) and subscribe to the `leadgen` field.

### 6.2 Final Verdict

```
================================================================================
  FINAL READINESS VERDICT:
  ⚠️  READY WITH BLOCKERS
================================================================================
```

The application code, cryptographic security, permission handling, and database schemas are completely ready. As soon as the project administrator provisions the Meta Developer App and live credentials (Blockers 1–4), live test lead acquisition can begin immediately.
