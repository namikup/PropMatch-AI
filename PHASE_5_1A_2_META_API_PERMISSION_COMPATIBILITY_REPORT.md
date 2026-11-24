# PropMatch AI — Phase 5.1A.2: Meta API Version & Permission Compatibility Report

**Date of Audit & Implementation:** November 24, 2026  
**Firebase Project:** `property-71665` (Region: `asia-southeast1`)  
**Designated Pilot Agent:** Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd)  
**Designated Listing:** Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  

---

## 1. Executive Summary

Phase 5.1A.2 resolves critical discrepancies in **API lifecycle compatibility** and **Lead Ads permission scoping**:

1. **API Version Deprecation Resolution:**
   - Meta's official version schedule confirms that **Marketing API v21.0 expired on September 9, 2025**. While Graph API v21.0 remains active until January 21, 2027, calls to Marketing API endpoints (`/{ad_account_id}/campaigns` and `/{ad_account_id}/insights`) targeting `v21.0` would fail or be rejected.
   - Both **Graph API** and **Marketing API** have been upgraded to **`v26.0`**, an active stable release launched on **July 29, 2026** and supported through mid-2028.
   - Version constants and base URLs remain independently declared (`META_GRAPH_API_VERSION = "v26.0"`, `META_MARKETING_API_VERSION = "v26.0"`).

2. **Permission Scoping Correction:**
   - Identified that calling `POST /{page_id}/subscribed_apps?subscribed_fields=leadgen` requires **`pages_manage_metadata`** in addition to `pages_manage_ads` and `pages_show_list`. Without `pages_manage_metadata`, Meta throws an HTTP 403 `(#200) Requires pages_manage_metadata permission to manage the object` error.
   - Added `pages_manage_metadata` to backend connection models and frontend permission sets.
   - Documented the exact security boundary for **excluding `ads_management`**: `ads_management` is a write permission allowing the creation, pausing, and deletion of campaigns and budgets. PropMatch AI strictly preserves a **read-only advertising boundary** by requesting `ads_read` and excluding `ads_management`.

3. **Credential Isolation Verified:**
   - Confirmed Cloud Firestore security rules default-deny client access to `_private_meta_credentials/{ownerId}`.
   - Verified that zero tokens are leaked in callable Cloud Function responses, frontend DTOs, or browser console output.

4. **Full Verification Passed:**
   - Backend build: **PASS (0 errors)**.
   - Backend Jest tests: **PASS (145/145 across 15 suites)**.
   - Flutter static analysis: **PASS (0 issues)**.
   - Flutter test suite: **PASS (7/7 passed)**.
   - Flutter Web release build: **PASS (`✓ Built build/web` in 23.7s)**.
   - Diagnostic script: **PASS ([scripts/test_meta_live_connection.js](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/scripts/test_meta_live_connection.js))**.

---

## 2. API Version Lifecycle & Endpoint Compatibility

### 2.1 Official Version Lifecycles (As of November 24, 2026)

| API Type | Version | Release Date | Sunset / Deprecation Date | Operational Status in PropMatch AI |
| :--- | :---: | :---: | :---: | :--- |
| **Marketing API (Old)** | `v21.0` | October 2, 2024 | **September 9, 2025** | **EXPIRED / DEPRECATED** (Calls fail) |
| **Graph API (Old)** | `v21.0` | October 2, 2024 | January 21, 2027 | Supported but superseded |
| **Marketing API (Target)**| **`v26.0`** | July 29, 2026 | Mid-2028 (TBD) | **ACTIVE STABLE (Adopted)** |
| **Graph API (Target)** | **`v26.0`** | July 29, 2026 | Mid-2028 (TBD) | **ACTIVE STABLE (Adopted)** |
| Marketing / Graph API | `v27.0` | November 4, 2026 | Late-2028 (TBD) | Latest release (under 90-day stabilization window) |

### 2.2 Endpoint Compatibility Audit

All endpoints in [meta_ads_service.ts](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/functions/src/services/meta_ads_service.ts) have been audited against Meta API `v26.0`:

| Endpoint Method | Endpoint URL in PropMatch AI | API Family | Status in `v26.0` | Parameters / Fields Audited |
| :--- | :--- | :--- | :---: | :--- |
| **OAuth Token Exchange** | `GET https://graph.facebook.com/v26.0/oauth/access_token` | Graph API | **Supported** | `grant_type=fb_exchange_token`, `client_id`, `client_secret` |
| **Token Inspection** | `GET https://graph.facebook.com/v26.0/debug_token` | Graph API | **Supported** | `input_token`, `access_token` (`app_id\|app_secret`) |
| **User Pages** | `GET https://graph.facebook.com/v26.0/me/accounts` | Graph API | **Supported** | `fields=id,name,access_token,category,tasks` |
| **Page Webhook Subscription** | `POST https://graph.facebook.com/v26.0/{page_id}/subscribed_apps` | Graph API | **Supported** | `subscribed_fields=leadgen` |
| **Leadgen Details** | `GET https://graph.facebook.com/v26.0/{leadgen_id}` | Graph API | **Supported** | `fields=id,created_time,ad_id,ad_name,adset_id,campaign_id,field_data` |
| **User Ad Accounts** | `GET https://graph.facebook.com/v26.0/me/adaccounts` | Marketing API | **Supported** | `fields=id,name,account_id,currency,timezone_name,account_status` |
| **Campaign Retrieval** | `GET https://graph.facebook.com/v26.0/{ad_account_id}/campaigns` | Marketing API | **Supported** | `fields=id,name,status,objective,daily_budget,lifetime_budget,start_time,stop_time` |
| **Campaign Insights** | `GET https://graph.facebook.com/v26.0/{ad_account_id}/insights` | Marketing API | **Supported** | `fields=campaign_id,campaign_name,spend,impressions,reach,clicks,ctr,cpc,cpm,actions,date_start,date_stop`, `date_preset=maximum` |

---

## 3. Permission-to-Endpoint Matrix & Scoping Analysis

### 3.1 Permission Scope Matrix

| Permission | Category | Target Endpoints | Capability Granted | Required in Dev Mode? |
| :--- | :--- | :--- | :--- | :---: |
| **`pages_show_list`** | Pages API | `GET /me/accounts` | Enumerate Facebook Pages managed by the agent. | Yes (Standard Access) |
| **`pages_read_engagement`** | Pages API | `GET /{page_id}` | Verify Page category, verification, and engagement. | Yes (Standard Access) |
| **`pages_manage_metadata`** | Pages API | `POST /{page_id}/subscribed_apps` | **Mandatory:** Register webhook subscriptions on the Page. | Yes (Standard Access) |
| **`pages_manage_ads`** | Marketing API | `GET /{page_id}/leadgen_forms` | Associate lead forms on the Page with advertising assets. | Yes (Standard Access) |
| **`ads_read`** | Marketing API | `GET /{ad_account_id}/campaigns`<br>`GET /{ad_account_id}/insights` | Read-only campaign performance, impressions, and ad spend. | Yes (Standard Access) |
| **`leads_retrieval`** | Lead Ads | `GET /{leadgen_id}` | Retrieve raw buyer contact information from Instant Forms. | **Test Leads Only** (Requires App Review for public leads) |

---

## 4. Read-Only Advertising Capability Assessment

### 4.1 Evaluation of `ads_management`
During the audit, we evaluated whether `ads_management` should be requested.

| Permission | Access Type | Capabilities | Security Impact on Agent Accounts | PropMatch AI Recommendation |
| :--- | :---: | :--- | :--- | :---: |
| **`ads_read`** | **Read-Only** | Reads campaigns, ad sets, ads, impressions, spend, clicks, conversion actions. | **ZERO RISK:** Cannot modify, spend, pause, or alter ads or budgets. | **REQUESTED** |
| **`ads_management`** | **Read/Write** | Creates new campaigns, alters daily/lifetime budgets, pauses ads, deletes ad sets. | **HIGH RISK:** Grants write access to agent's financial advertising assets. | **EXCLUDED** |

### 4.2 Technical Justification for Excluding `ads_management`
1. **Endpoint Requirements**: Meta's Graph API `/{leadgen_id}` endpoint requires `leads_retrieval` combined with a Page Access Token that holds `pages_manage_metadata` and `pages_manage_ads`. It does **not** require `ads_management` when querying leads submitted to a Page.
2. **Security Principle of Least Privilege**: PropMatch AI is designed exclusively as an **intelligence and buyer matching platform**, not an automated media buyer. Requesting `ads_management` would create unnecessary security liability and require higher App Review scrutiny without operational benefit.
3. **Verdict**: `ads_management` is **deliberately excluded** from the requested OAuth scopes.

---

## 5. Credential Isolation Findings

### 5.1 Verification of `_private_meta_credentials/{ownerId}`

```mermaid
graph TD
    Client[Flutter Web Client / Browser] -.->|Denied: Default Deny Rules| PrivateDoc[_private_meta_credentials/{ownerId}]
    CloudFn[Cloud Functions v2 (Server-Side)] -->|Authorized: Admin SDK| PrivateDoc
    PrivateDoc -->|Server-to-Server HTTPS| MetaApi[Meta Graph API v26.0]
    CloudFn -->|Public DTO Only (No Tokens)| Client
```

1. **Client SDK Denied**:
   In [firestore.rules](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/firestore.rules#L316-L322), the collection `_private_meta_credentials` has no client-facing rules and terminates in:
   ```text
   match /{document=**} {
     allow read, write: if false;
   }
   ```
   No web client or unauthorized user can read or query access tokens via the client Firestore SDK.

2. **Server-Side Authorization**:
   Only authenticated Firebase Admin SDK calls in Cloud Functions ([meta_ads_service.ts](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/functions/src/services/meta_ads_service.ts)) read from `collections.privateMetaCredentials`.

3. **Callable Function Responses**:
   The callable function `getMetaConnectionStatus` returns `MetaConnectionConfig`, which contains only:
   - `ownerId`, `facebookPageId`, `facebookPageName`, `adAccountId`, `adAccountName`, `currency`, `timezone`, `isConnected`, `connectionStatus`, `grantedPermissions`, `missingPermissions`, `dataSource`.
   - Access tokens, refresh tokens, and App Secrets are **never serialized** into client responses.

4. **Multi-Agent & Agency Scaling**:
   Credentials are keyed strictly by `ownerId` (e.g. `pilot-agent-malik-001`). If PropMatch AI supports agency-level advertising accounts in the future, agency credentials can be held in a distinct system user record without overlapping with individual agent tokens.

---

## 6. Tests Executed & Results

| Test Target | Verification Command | Outcome | Details |
| :--- | :--- | :---: | :--- |
| **Backend Compilation** | `npm run build --prefix functions` | **PASS** | TypeScript `tsc` completed with 0 errors. |
| **Backend Unit Tests** | `npm test --prefix functions -- --runInBand` | **PASS** | 15 test suites passed (145/145 tests). Validated CSRF timing-safe comparison, webhook deduplication, token purge on disconnect. |
| **Flutter Analysis** | `flutter analyze` | **PASS** | 0 warnings, 0 lint issues. |
| **Flutter Test Suite** | `flutter test test/phase5_1_meta_ads_intelligence_test.dart` | **PASS** | 7/7 tests passed. Validated 6 granted permissions (`pages_manage_metadata` included) and model serialization. |
| **Flutter Web Release Build** | `flutter build web` | **PASS** | Release compilation succeeded in 23.7s (`build/web` generated). |
| **Live Connection Audit Script** | `node scripts/test_meta_live_connection.js` | **PASS** | Validated v26.0 constants, phone canonicalization (`+60124889921`), duplicate suppression, and deterministic match against Eco Horizon. |

---

## 7. Remaining Blockers Before Live Account Connection

The codebase is fully compatible and verified. The remaining steps are manual configurations on the Meta Developer platform:

1. **Meta Developer App Creation**:
   - Create App on [developers.facebook.com](https://developers.facebook.com/) (Type: *Business*).
   - Ensure App API version targets **v26.0**.
2. **Product Configuration**:
   - Add **Facebook Login for Business**.
   - Add **Webhooks** (Subscribe `Page` > `leadgen` field to callback `https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler`).
3. **Tester Role Assignment**:
   - Add Malik Tan's personal Facebook account under **App Roles > Roles > Testers**.
   - Malik Tan accepts the invitation.
4. **Local Secret File**:
   - Populate `META_APP_ID`, `META_APP_SECRET`, and `META_WEBHOOK_VERIFY_TOKEN` in `functions/.secret.local`.

---

## 8. Final Verdict

### **READY FOR TEST APP CREATION**

**Summary of Technical Readiness:**
- **API Versions:** Both Graph API and Marketing API are aligned to **`v26.0`**, eliminating the expired `v21.0` Marketing API vulnerability.
- **Permissions:** `pages_manage_metadata` is integrated, preventing `(#200)` webhook subscription failures.
- **Security:** Read-only advertising boundaries are preserved by excluding `ads_management`.
- **Build Quality:** Backend, Flutter tests, and Flutter Web release build are verified and 100% passing.
