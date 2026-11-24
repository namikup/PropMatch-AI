# PropMatch AI — Phase 5.1A.3: Meta Permission Matrix & Access Boundary (Corrected)

**Target Pilot Agent**: Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
**Designated Listing**: Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  
**Execution Environment**: Single-Agent Private Pilot Mode  
**Audit Date**: November 2026 (Phase 5.1A.3.1 Technical Corrections)  

---

## 1. Overview & Regulatory Context

This document provides the definitive permission matrix for PropMatch AI's Meta Ads Intelligence integration, specifically addressing the permission requirements for Lead Ads retrieval, advertising telemetry, and webhook subscriptions under official Meta Developer policies and Malaysian Personal Data Protection Act (PDPA) compliance guidelines.

---

## 2. Operation-by-Operation Technical Audit

The table below provides the audited technical breakdown for each core operation requested in the Phase 5.1A.3.1 audit:

### Detailed Operations Matrix

| Operation ID & Target | Exact Meta Endpoint | Token Type Required | Required Permissions | Is `ads_management` Required? | Is `ads_read` Sufficient? | App Review Required? | Dev Mode Testing Possible? |
| :--- | :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| **A. Retrieve Individual Lead Details** | `GET /v26.0/{leadgen_id}?fields=id,created_time,form_id,field_data` | **Page Access Token** | `leads_retrieval`, `pages_manage_ads`, `pages_show_list`, `pages_read_engagement` | **NO** (Not required for form questions & customer contact details) | **NO** (`leads_retrieval` is the mandatory scope) | **YES** (For live public leads) | **YES** (Using Lead Ads Testing Tool for App Roles) |
| **B. Retrieve Bulk Form Leads** | `GET /v26.0/{form_id}/leads?fields=id,created_time,form_id,field_data` | **Page Access Token** | `leads_retrieval`, `pages_manage_ads`, `pages_show_list`, `pages_read_engagement` | **NO** (Not required for form questions & customer contact details) | **NO** (`leads_retrieval` is the mandatory scope) | **YES** (For live public leads) | **YES** (For test leads generated on form) |
| **C. Retrieve Ad-Specific Fields on Lead** | `GET /v26.0/{leadgen_id}?fields=ad_id,ad_name,adset_id,campaign_id` | **Page Access Token** (or User Token with ad rights) | `leads_retrieval`, `pages_manage_ads`, **`ads_management`** | **YES** (To query ad fields directly on Graph API node) | **NO** (Meta docs specify `ads_management` for ad fields on leadgen) | **YES** (For live public leads) | **YES** (For App Roles with ad account role) |
| **D. Subscribe to Page Leadgen Webhook** | `POST /v26.0/{page_id}/subscribed_apps?subscribed_fields=leadgen` | **Page Access Token** | `pages_manage_metadata`, `pages_manage_ads`, `pages_show_list` | **NO** (Not required) | **NO** (`pages_manage_metadata` is mandatory) | **YES** (For Advanced Access) | **YES** (For Pages owned by App Roles) |
| **E. Retrieve Campaign & Ad Insights** | `GET /v26.0/act_{id}/insights?fields=spend,impressions,clicks,cpc,ctr` | **User Access Token** | `ads_read` | **NO** (Not required) | **YES** (`ads_read` is 100% sufficient) | **YES** (For Advanced Access) | **YES** (For ad accounts accessible to App Roles) |

---

## 3. Deep Analysis: Can Lead Data Be Retrieved Without `ads_management`?

### 3.1 The Technical Answer: YES

Meta's Marketing API documentation states that to retrieve *both* customer answers (`field_data`) and ad-level identifiers (`ad_id`, `campaign_id`) via direct Graph API calls on the `/{leadgen_id}` node, `ads_management` is required.

However, **customer contact details can be 100% retrieved without `ads_management`**:
1. When calling `GET /{leadgen_id}?fields=id,created_time,form_id,field_data`, Meta requires only **`leads_retrieval`** and **`pages_manage_ads`**.
2. The user's submitted responses (`full_name`, `phone_number`, `email`, `budget`, `preferred_location`, `purchase_purpose`) reside in `field_data`. None of these fields require `ads_management`.
3. **The Webhook Pathway Supplies Ad Identifiers**: In real-time webhook events, Meta dispatches:
   ```json
   {
     "ad_id": "238519482910123",
     "form_id": "948201948201948",
     "leadgen_id": "492019482910482",
     "campaign_id": "238519482910001"
   }
   ```
   The webhook notification itself provides the `ad_id` and `campaign_id` to PropMatch AI without requiring `ads_management`!

### 3.2 Security Implications of Granting `ads_management`

`ads_management` is a broad, high-privilege write permission:
- **Write Scope**: Grants the ability to create, edit, pause, and delete ad campaigns, ad sets, and individual ad creatives.
- **Financial Liability**: Grants the ability to alter daily and lifetime budgets, create ad sets with high spend limits, and charge the agent's linked credit card.
- **Attack Surface**: If an access token with `ads_management` were ever intercepted or compromised, an attacker could deplete the agent's advertising budget.
- **App Review Overhead**: Requesting `ads_management` triggers comprehensive App Review scrutiny where Meta requires video demonstrations justifying why automated campaign management or budget modification is needed.

### 3.3 Restricted Integration Architecture (PropMatch AI Proposed Solution)

PropMatch AI enforces a **Restricted Integration Architecture**:

```mermaid
flowchart TD
    subgraph "External Meta Platform"
        WH[Webhook Notification: ad_id, campaign_id, leadgen_id]
        GAPI[Graph API: GET /{leadgen_id}]
        MAPI[Marketing API: GET /act_{id}/insights]
    end

    subgraph "PropMatch AI OAuth Scope Boundary"
        READ[ads_read: Campaign spend & metrics]
        LEAD[leads_retrieval: Form field answers]
        PAGE[pages_manage_metadata: Webhook subscription]
        LOCK[ads_management: EXCLUDED / BLOCKED]
    end

    subgraph "PropMatch AI Internal Service Boundary"
        FALLBACK[Automated Field Fallback Engine]
        ZERO_WRITE[Strict Zero-Write Policy: No campaign mutation endpoints]
    end

    WH --> LEAD
    LEAD --> GAPI
    GAPI --> FALLBACK
    MAPI --> READ
    LOCK -.-> ZERO_WRITE
```

1. **Mandatory Least-Privilege Scope**: The standard OAuth flow requests only `leads_retrieval`, `ads_read`, `pages_manage_metadata`, `pages_manage_ads`, `pages_show_list`, and `pages_read_engagement`.
2. **Core Field Fallback**: `MetaAdsService.fetchLeadDetailsFromGraphApi` attempts full fields first. If the call fails with a permissions error on ad fields, it automatically falls back to core fields (`id,created_time,form_id,field_data`), ensuring uninterrupted lead ingestion.
3. **Immutable Zero-Write Code Boundary**: The PropMatch AI codebase contains zero write methods targeting Meta's Marketing API. There are no endpoints for `POST /campaigns`, `POST /adsets`, `POST /ads`, or budget modification.
4. **Optional Elevated Scope**: If an agent explicitly authorizes `ads_management` during OAuth, the backend uses it solely to enrich bulk backfill queries (`GET /{form_id}/leads`) with ad metadata, while internal application barriers guarantee that ad budgets and campaigns are never modified.

---

## 4. Development Mode vs. Live Mode Boundary

| Feature / Behavior | Development Mode | Live Mode |
| :--- | :--- | :--- |
| **Who can log in?** | Only registered App Roles (Admin, Developer, Tester) | Any Facebook user |
| **Who can submit test leads?** | App Roles using Lead Ads Testing Tool | Any Facebook user via live ads |
| **What happens to public leads?** | Blocked with `OAuthException: (#10)` | Ingested successfully |
| **Permissions Availability** | Standard Access automatically active for App Roles | Advanced Access required after App Review |
| **App Review Required?** | **NO** | **YES** for `leads_retrieval`, `ads_read`, `pages_manage_ads` |
| **Business Verification?** | **NO** | **YES** (Must verify agency legal entity) |

---

## 5. Summary & Recommendation

1. **Do not automatically require `ads_management`**: The platform can acquire full lead contact data, receive ad identifiers via webhooks, and read ad spend insights via `ads_read` without write access to the agent's ad account.
2. **Maintain the Restricted Architecture**: Keep `ads_management` excluded from mandatory setup, and utilize the automated core field fallback in `MetaAdsService`.
3. **Proceed with Development Mode Testing**: Assign Malik Tan as App Tester to conduct complete end-to-end testing with the Lead Ads Testing Tool without requiring immediate App Review or Business Verification.
