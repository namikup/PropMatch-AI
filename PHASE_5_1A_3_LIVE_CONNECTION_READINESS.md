# PropMatch AI — Phase 5.1A.3: Live Connection Readiness Gate & Pre-Flight Checklist (Corrected)

**Target Pilot Agent**: Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
**Designated Listing**: Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  
**Cloud Functions Region**: `asia-southeast1` (Google Cloud Singapore)  
**Target Firebase Project**: `property-71665`  
**Execution Environment**: Single-Agent Private Pilot Mode  
**Audit Date**: November 2026 (Phase 5.1A.3.1 Technical Corrections)  

---

## 1. Executive Summary & Verification Purpose

This document serves as the formal **Pre-Flight Readiness Gate** before establishing a live connection to a Meta Developer App and agent Malik Tan's advertising account.

Following the Phase 5.1A.3.1 technical review, this document enforces a strict distinction between **offline synthetic pipeline testing** (which verifies code algorithms and data models locally) and **live Meta API connection testing** (which requires live Meta credentials and network requests to Meta servers).

---

## 2. Distinction Between Diagnostic Layers

To prevent misleading claims of live connectivity when operating in local development:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                  PROPMATCH AI DIAGNOSTIC LAYER CLASSIFICATION              │
├──────────────────────────────────────┬─────────────────────────────────────┤
│ OFFLINE SYNTHETIC SIMULATION         │ LIVE META API CONNECTION            │
│ (Local In-Memory / No Network)       │ (Network Requests to Meta Servers)  │
├──────────────────────────────────────┼─────────────────────────────────────┤
│ 1. Static Configuration Schema       │ 4. Actual Graph API HTTP Requests   │
│ 2. Synthetic Webhook Simulation      │ 5. Meta Developer App Auth          │
│ 3. Mock API Model Ingestion          │ 6. Facebook Page Asset Enumeration  │
│    (Regexes, E.164, Idempotency)     │ 7. Genuine Lead Ads Testing Tool    │
│    Status: ✅ VERIFIED LOCALLY        │    Status: ⚠️ NOT TESTED (No creds) │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

> [!CAUTION]
> A successful local synthetic test is **NOT** proof of a live Meta API connection.
> In the absence of live Meta credentials (`META_APP_ID`, `META_APP_SECRET`, and a valid live user/page access token), live network calls to Meta's servers cannot execute.
> PropMatch AI explicitly reports: **`LIVE CONNECTION NOT TESTED`**.

---

## 3. 7-Stage Pre-Flight Checklist & Current Classification

| Stage | Verification Dimension | Current Status | Operational Reality & Next Steps |
| :---: | :--- | :---: | :--- |
| **1** | **Static Configuration Validation** | ❌ **INCOMPLETE** | `META_APP_ID`, `META_APP_SECRET`, and `META_WEBHOOK_VERIFY_TOKEN` must be provisioned in `functions/.secret.local`. |
| **2** | **Synthetic Webhook Simulation** | ✅ **VERIFIED LOCALLY** | Verified offline via unit tests and diagnostic script. Idempotency and E.164 normalization confirmed. |
| **3** | **Mock API Responses** | ✅ **VERIFIED LOCALLY** | Verified offline. Campaign calculations (CTR, CPC, CPM, CPL) and AI quality metrics confirmed. |
| **4** | **Actual Meta Graph API Requests** | ⚠️ **NOT TESTED** | Blocked until a real User Access Token or Page Access Token is provided. |
| **5** | **Meta Developer App Auth** | ⚠️ **NOT TESTED** | Blocked until a Meta Developer App (Type: Business) is created in `developers.facebook.com`. |
| **6** | **Facebook Page Asset Access** | ⚠️ **NOT TESTED** | Blocked until agent Malik Tan logs in via Facebook Login for Business and enumerates Page assets. |
| **7** | **Genuine Test Lead Retrieval** | ⚠️ **NOT TESTED** | Blocked until Malik Tan's account is added as App Tester and generates a lead via the Lead Ads Testing Tool. |

---

## 4. Test Leads vs. Genuine Customer Leads Boundary

A clear operational boundary governs Meta's App Modes:

### 4.1 Development Mode (Unblocked for Internal Pilot Testing)
- **Who can submit forms**: Only Facebook users who have been explicitly assigned an **App Role** (Admin, Developer, Tester) in `developers.facebook.com > App Roles > Roles`.
- **How to submit leads**: Using Meta's official [Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing).
- **Access Level**: Meta grants **Standard Access** automatically for App Roles.
- **App Review Required**: **NO**.
- **Business Verification Required**: **NO**.
- **Public Traffic**: Any submission from an external Facebook user who is NOT an App Role is blocked by Meta with:
  `OAuthException: (#10) Application does not have permission for this action`.

### 4.2 Live Mode (Required for Public Customer Leads)
- **Who can submit forms**: Any member of the Malaysian public clicking active Facebook or Instagram ads.
- **Access Level**: Requires **Advanced Access** for `leads_retrieval`, `ads_read`, and `pages_manage_ads`.
- **App Review Required**: **YES** (Must submit screencasts, data privacy policy, and user deletion callback).
- **Business Verification Required**: **YES** (Agency legal SSM registration documents must be verified in Meta Business Manager).

---

## 5. Local Testing & Verification Evidence

All local test suites across backend, frontend, build pipelines, and diagnostics pass cleanly:

### 5.1 Backend Unit & Integration Tests (Firebase Cloud Functions)
- **Command**: `npm test --prefix functions -- --runInBand`
- **Result**: **15 / 15 Test Suites Passed**, **147 / 147 Tests Passed** (100% pass rate).
- **Key Modules Tested**:
  - `meta_ads_service.test.ts`: OAuth state timingSafeEqual, token isolation, idempotency, bulk retrieval, pagination, deterministic formulas, multi-tenant isolation.
  - `lead_ingestion_service.ts`: E.164 normalization, source validation (accepts `Facebook Lead Ads`, `Instagram Lead Ads`, `Meta Lead Ads`), honeypot spam trap, PDPA consent.
  - `response_parser.test.ts`: Markdown code fence stripping, JSON normalization.
  - `buyer_matching_cache.test.ts`: Deterministic matching across 5 dimensions.

### 5.2 TypeScript Build
- **Command**: `npm run build --prefix functions` (`tsc`)
- **Result**: **0 Errors**, clean compilation into `functions/lib/`.

### 5.3 Flutter Web Analysis
- **Command**: `flutter analyze`
- **Result**: **No issues found!** (ran in 2.8s across all Dart packages).

### 5.4 Flutter Tests
- **Command**: `flutter test test/phase5_1_meta_ads_intelligence_test.dart`
- **Result**: **7 / 7 Tests Passed**.

### 5.5 Diagnostic Script
- **Command**: `node scripts/test_meta_live_connection.js`
- **Result**:
  - Offline synthetic simulation passed.
  - Live connection accurately reported as: `LIVE CONNECTION NOT TESTED (Missing live credentials)`.
  - Zero fake API responses generated.

---

## 6. Final Readiness Verdict

```
================================================================================
  FINAL READINESS VERDICT:
  ⚠️  READY WITH BLOCKERS
================================================================================
```

### Technical Justification:

1. **Code & Architecture Readiness**:
   - Central version configuration (`meta.config.ts`) implemented and decoupled.
   - Core field fallback implemented for `GET /{leadgen_id}` when `ads_management` is absent.
   - Instagram Lead Ads attribution and Page webhook mechanics corrected and verified.
   - Server-side token storage in `_private_meta_credentials` with default-deny rules verified.
   - All 147 backend tests and 7 Flutter tests pass cleanly.

2. **Operational Blockers Before Real Meta Test Connection**:
   - **Blocker 1 (App Creation)**: The Meta Developer App has not yet been registered in `developers.facebook.com`.
   - **Blocker 2 (Secrets Provisioning)**: `META_APP_ID`, `META_APP_SECRET`, and `META_WEBHOOK_VERIFY_TOKEN` are not yet populated in `functions/.secret.local`.
   - **Blocker 3 (App Tester Role)**: Pilot agent Malik Tan's personal Facebook account must be assigned as an **App Tester** in the Developer App dashboard.
   - **Blocker 4 (Webhook Setup)**: The `Page` object webhook callback URL (`https://asia-southeast1-property-71665.cloudfunctions.net/metaWebhookHandler`) and `leadgen` subscription must be verified in the Meta App Dashboard.

Once Blockers 1 through 4 are executed by the project administrator in `developers.facebook.com`, PropMatch AI will immediately be able to perform live test lead ingestion without any code changes.
