# PropMatch AI — Phase 5.1A.3.3: Endpoint Compatibility & Meta Permission Matrix

> **Document Version:** 1.0.0  
> **Audit Date:** 24 November 2026  
> **Author:** Antigravity Senior Full-Stack AI Engineer  
> **Environment:** Single-Agent Private Pilot Mode (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
> **Firebase Target:** `property-71665` (Cloud Functions v2: `asia-southeast1`)  
> **Official Documentation Source:** Meta for Developers (Graph API & Marketing API Documentation)  

---

## 1. Comprehensive Independent Endpoint Matrix

The table below provides a forensic, operation-by-operation breakdown of each Meta API endpoint utilized in PropMatch AI. Each operation is governed by distinct permission rules, token types, and asset-level roles under Meta's authorization model.

| Operation # | Operation Name & Endpoint | Required Permissions | Required Token Type | Required Page & Ad Account Roles | App Review & Business Verification | Dev Mode Execution Feasible? | Documentation URL & Date Checked |
|---|---|---|---|---|---|---|---|
| **1** | **Page Webhook Subscription**<br>`POST /{page-id}/subscribed_apps` | `pages_manage_metadata`<br>`pages_manage_ads`<br>`pages_show_list` | **Page Access Token** | • Page: Admin or task `MANAGE` / `CREATE_CONTENT`<br>• Ad Account: None required | • App Review: Required for Live Mode<br>• Business Verification: Required for live webhook events | ✅ **YES**<br>(App role members: Admin/Dev/Tester) | [Page Subscribed Apps Reference](https://developers.facebook.com/docs/graph-api/reference/page/subscribed_apps/)<br>*Checked: 24 Nov 2026* |
| **2** | **Single Lead Retrieval**<br>`GET /{leadgen_id}` | `leads_retrieval`<br>`ads_management`<br>`pages_manage_ads`<br>`pages_read_engagement` | **Page Access Token** (or User Token with Page Admin tasks) | • Page: Admin or Advertiser role (with Leads Access Manager permissions)<br>• Ad Account: Admin or Advertiser | • App Review: Required for `leads_retrieval` & `ads_management`<br>• Business Verification: Mandatory | ✅ **YES**<br>(Test leads via Lead Ads Testing Tool only) | [Marketing API: Retrieving Leads](https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving/)<br>*Checked: 24 Nov 2026* |
| **3** | **Bulk Form Lead Retrieval**<br>`GET /{form_id}/leads` | `leads_retrieval`<br>`ads_management`<br>`pages_manage_ads`<br>`pages_read_engagement` | **Page Access Token** | • Page: Admin or Advertiser role<br>• Leads Access: Explicit permission in Meta Business Suite | • App Review: Required for Live Mode<br>• Business Verification: Mandatory | ✅ **YES**<br>(Returns test leads or tester submissions) | [Instant Forms Leads Edge](https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving/#form-leads)<br>*Checked: 24 Nov 2026* |
| **4** | **Ad & Campaign Metadata**<br>`GET /{ad_account_id}/campaigns`<br>`GET /{campaign_id}` | `ads_read`<br>(or `ads_management`) | **User Access Token** (or System User Token) | • Ad Account: Administrator, Advertiser, or Analyst on `act_<ad_account_id>` | • App Review: Required for external accounts<br>• Business Verification: Required for Advanced Access | ✅ **YES**<br>(For accounts owned by App role members) | [Ad Campaign Group Reference](https://developers.facebook.com/docs/marketing-api/reference/ad-campaign-group/)<br>*Checked: 24 Nov 2026* |
| **5** | **Ad Spend & Insights Retrieval**<br>`GET /{ad_account_id}/insights`<br>`GET /{campaign_id}/insights` | `ads_read`<br>(or `ads_management`) | **User Access Token** (or System User Token) | • Ad Account: Administrator, Advertiser, or Analyst on `act_<ad_account_id>` | • App Review: Required for external accounts<br>• Business Verification: Required for Advanced Access | ✅ **YES**<br>(For accounts owned by App role members) | [Marketing API Insights Reference](https://developers.facebook.com/docs/marketing-api/insights/)<br>*Checked: 24 Nov 2026* |

---

## 2. In-Depth Operational Analysis

### 2.1 Operation 1: Page Webhook Subscription (`POST /{page-id}/subscribed_apps`)
- **Official Documentation Reference:**
  - URL: `https://developers.facebook.com/docs/graph-api/reference/page/subscribed_apps/`
  - URL: `https://developers.facebook.com/docs/marketing-api/guides/lead-ads/quickstart/webhooks-setup/`
  - Date Checked: 24 November 2026
- **Technical Behavior:**
  Instructs Meta to route real-time changes on the Facebook Page to the App's configured webhook endpoint. When subscribing to `subscribed_fields=leadgen`, Meta validates that the Page token carries `pages_manage_metadata` and that the app has configured the Webhook product.
- **Instagram Notice:**
  Instant Forms running as lead ads on Instagram are technically owned by the associated Facebook Page. Meta dispatches all Instagram Lead Ad events under `object: "page"` with `field: "leadgen"`. Subscribing the Page captures both Facebook and Instagram lead submissions.

### 2.2 Operation 2: Lead Retrieval (`GET /{leadgen_id}`)
- **Official Documentation Reference:**
  - URL: `https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving/`
  - URL: `https://developers.facebook.com/docs/graph-api/reference/lead/`
  - Date Checked: 24 November 2026
- **Technical Behavior:**
  Queries the specific lead submission node. Meta checks whether the caller has permission to view the lead's PII (`field_data`).
- **Permission Dynamics:**
  - `leads_retrieval` is the primary access control for reading the respondent's form answers.
  - `ads_management` is required by Meta's Marketing API infrastructure if querying ad-specific node fields (`ad_id`, `campaign_id`).
  - If `ads_management` is omitted, querying ad fields returns `HTTP 400 (#200)`. PropMatch AI's fallback requests core fields (`id,created_time,form_id,field_data`), which succeed under `leads_retrieval` alone, tagging the data provenance as `PARTIAL_META_API`.
  - With `ads_management` included in the onboarding scope, the full query succeeds, tagging the data provenance as `REAL_META_API`.

### 2.3 Operation 3: Bulk Lead Retrieval (`GET /{form_id}/leads`)
- **Official Documentation Reference:**
  - URL: `https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving/#form-leads`
  - Date Checked: 24 November 2026
- **Technical Behavior:**
  Enables bulk backfilling and missed-lead reconciliation. Supports cursor-based pagination (`limit=25`, `after=cursor`) and time-based filtering (`time_created > sinceTimestamp`).
- **90-Day Retention Notice:**
  Meta permanently purges lead PII from the API **90 days** post-submission. Bulk sync operations must only query leads within this 90-day window.

### 2.4 Operation 4: Ad & Campaign Metadata Retrieval (`GET /{ad_account_id}/campaigns`)
- **Official Documentation Reference:**
  - URL: `https://developers.facebook.com/docs/marketing-api/reference/ad-campaign-group/`
  - Date Checked: 24 November 2026
- **Technical Behavior:**
  Queries campaign structures (`name`, `objective`, `daily_budget`, `lifetime_budget`, `status`, `start_time`, `stop_time`).
- **Permission Mechanics:**
  Requires only `ads_read`. No write permission is needed. User Access Token must have an Analyst, Advertiser, or Admin role on the Ad Account.

### 2.5 Operation 5: Ad Spend & Insights Retrieval (`GET /{ad_account_id}/insights`)
- **Official Documentation Reference:**
  - URL: `https://developers.facebook.com/docs/marketing-api/insights/`
  - Date Checked: 24 November 2026
- **Technical Behavior:**
  Aggregates spend, impressions, clicks, CTR, CPC, CPM, and lead conversions.
- **Permission Mechanics:**
  Requires only `ads_read`. PropMatch AI computes buyer quality metrics downstream by joining `campaign_id` against Firestore `prospects` and `buyers` collections.

---

## 3. Development Mode vs. Live Mode Rules

Because PropMatch AI is operating in **Single-Agent Private Pilot Mode** with agent Malik Tan, understanding Meta's Development Mode boundaries is essential:

| Feature / Behavior | In Development Mode (Pilot Status) | In Live Mode (Post-App Review) |
|---|---|---|
| **User Eligibility** | Only users with a defined Role on the App (Administrators, Developers, Testers) can authenticate or be queried. | Any public Facebook user with an active ad account / Page can authenticate. |
| **Lead Ads Testing Tool** | ✅ **Fully Operational**: App role users can generate test leads for any Instant Form on Pages they manage. | ✅ **Fully Operational**. |
| **Public Lead Generation** | ❌ **Blocked**: Enquiries submitted by real public Facebook users will NOT trigger webhook delivery or API retrieval. | ✅ **Fully Operational**: Public ad clicks and Instant Form submissions trigger webhooks in real time. |
| **App Review Requirement** | 🟢 **None**: `leads_retrieval`, `ads_management`, and `ads_read` work without App Review for App role members. | 🔴 **Mandatory**: Must submit screen recordings, business justification, and privacy policy for App Review. |
| **Business Verification** | 🟢 **Not Required** for local testing with Developer/Tester roles. | 🔴 **Mandatory** before app can go live with public users. |

---

## 4. Architectural Summary for Pilot Readiness

1. **Malik Tan Pilot Setup:**  
   To conduct live end-to-end tests during the pilot, Malik Tan's personal Facebook account (`pilot-agent-malik-001`) must simply be added as an **App Tester** or **Developer** under the Meta App Dashboard (`Roles > Roles > Add Testers`).
2. **Zero App Review Friction for Pilot:**  
   In Development Mode with Malik Tan assigned as a tester, all 5 endpoints can be tested with real Meta API tokens and real Instant Forms **without waiting for Meta App Review or Business Verification**.
3. **100% Read-Only Safety:**  
   Although `ads_management` is included in the OAuth scope to satisfy Meta's Marketing API Lead Retrieval requirements, PropMatch AI's backend maintains an ironclad read-only code architecture that completely prevents ad mutation, campaign creation, or budget tampering.
