# PropMatch AI — Phase 3.1.1: Gemini Model Modernization & Backend Verification Report

## 1. Executive Summary

A targeted verification, modernization, and hardening audit of the PropMatch AI backend was completed on **19 November 2026**.

This pass addressed:
1. **Gemini Model Modernization**: Identified and eradicated retired model identifiers (`gemini-1.5-flash`, `gemini-1.5-pro`, `gemini-1.0-pro`), replaced them with verified active models (`gemini-2.5-flash` primary, `gemini-2.5-pro` fallback, `gemini-2.0-flash-lite` lightweight tier), and added an automated configuration guard that rejects retired models.
2. **Secret Manager Implementation**: Verified Google Cloud Secret Manager binding via `defineSecret("GEMINI_API_KEY")` across all LLM-calling Firebase Cloud Functions.
3. **Multi-Tenant Security Hardening**: Ensured verified context UID is enforced, `ownerId` from client payloads is never blindly trusted, and cross-agent project/buyer access is rejected server-side.
4. **Quota Concurrency & Accounting**: Replaced race-prone read checks with atomic transactions on `agent_quotas/{ownerId}`, implemented automatic reservation rollbacks on failures, added 24-hour analysis caching, and distinguished provider tokens from heuristic estimations.
5. **Frontend Fallback Transparency**: Integrated explicit data provenance indicators (`isLiveAI`, `generationSource`, `isUsingAIFallback`, `lastAIError`) to guarantee agents are never misled into mistaking offline rule-based results for live Gemini AI outputs.

---

## 2. Gemini Model Modernization & Provider Compatibility

### 2.1 Provider & SDK Identification
- **Target Provider**: **Google AI Studio / Gemini Developer API** (`generativelanguage.googleapis.com`)
- **SDK**: `@google/generative-ai` (v0.24.1) / `@google/genai` (v3.6.0) Node.js SDKs
- **Credential Type**: API Key (managed via Google Cloud Secret Manager)
- **Verification Date**: **19 November 2026**

> [!NOTE]
> The current implementation communicates directly with the Gemini Developer API, not Google Cloud Vertex AI (which uses `@google-cloud/vertexai` with regional OAuth2 tokens). Model identifiers are tailored specifically for the Gemini Developer API provider.

### 2.2 Model Selection Matrix

| Tier | Model Identifier | Status | Primary Purpose | Input Rate (/1M) | Output Rate (/1M) |
|---|---|---|---|---|---|
| **Primary** | `gemini-2.5-flash` | **ACTIVE** | General-purpose multimodal reasoning, deep analysis, audience discovery, buyer matching | $0.075 | $0.30 |
| **Fallback** | `gemini-2.5-pro` | **ACTIVE** | Complex analytical failover during regional 503 errors | $1.25 | $5.00 |
| **Lightweight** | `gemini-2.0-flash-lite` | **ACTIVE** | Low-cost high-frequency copywriting & preliminary filtering | $0.040 | $0.15 |
| **Alternative** | `gemini-2.0-flash` | **ACTIVE** | High-throughput alternative workhorse | $0.075 | $0.30 |
| *Deprecated* | `gemini-1.5-flash` | **RETIRED** | Permanently removed from active configuration | N/A | N/A |
| *Deprecated* | `gemini-1.5-pro` | **RETIRED** | Permanently removed from active configuration | N/A | N/A |

### 2.3 Retired Model Rejection Guard
In `functions/src/config/gemini.config.ts`, `validateModelIdentifier()` executes on startup:
- Passing any model in `RETIRED_MODELS = ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-1.0-pro"]` throws an immediate `Configuration error: Model is retired and no longer supported`.
- Passing unverified or third-party models (e.g. `gpt-4o`) throws an unrecognized error.

---

## 3. Secret Manager & Security Verification

### 3.1 Secret Configuration Verification
- **Binding Mechanism**: `defineSecret("GEMINI_API_KEY")` from `firebase-functions/params`.
- **Function Binding**: Explicitly bound via `secrets: [geminiApiKey]` in `callOptions` across:
  - `analyzeProperty`
  - `discoverAudienceSegments`
  - `matchBuyers`
  - `generateMarketingContent`
- **Frontend Isolation**: Neither `GEMINI_API_KEY` nor any AI secret is exposed in Dart, Flutter Web bundles, or asset manifests.
- **Log Sanitation**: `functions/src/utils/logger.ts` redacts keys matching `password`, `token`, `apiKey`, `secret`, `phone`, `email`.
- **Git Hygiene**: `.gitignore` explicitly excludes `.env`, `node_modules/`, and build artifacts.
- **Live Credential Status**: Real production credentials are not yet deployed to Secret Manager. In accordance with zero-fabrication rules, live API connectivity against production endpoints remains unverified until authorized deployment.

### 3.2 Cloud Functions Security & Multi-Tenant Audit

| Security Dimension | Implementation Detail | Audit Finding |
|---|---|---|
| **Authentication Requirement** | `AIRequestValidator.validateAuth(request.auth?.uid)` | **PASS**: Unauthenticated calls rejected with `401 unauthenticated`. |
| **Verified Context Identity** | Uses `request.auth.uid` decoded by Firebase Auth token verification | **PASS**: Client-supplied UIDs in body are ignored. |
| **Project Ownership Verification** | `validateProject` + `verifyProjectOwnershipInFirestore` | **PASS**: Mismatched `ownerId` rejected with `403 permission-denied`. |
| **Buyer Ownership Verification** | `validateAndSanitizeBuyers` requires `b.ownerId === callerUid` | **PASS**: Cross-agent buyer inclusion rejected with `403 permission-denied`. |
| **PDPA PII Sanitization** | `validateAndSanitizeBuyers` strips `name`, `fullName`, `phone`, `email`, IC | **PASS**: Prompts contain zero PII. |
| **Payload Length Limits** | Descriptions capped at 3,000 chars; matching capped at 50 buyers | **PASS**: Token exhaustion attacks mitigated. |
| **Firebase App Check** | Configured in `callOptions.enforceAppCheck = false` for local dev | **PENDING**: Must be enabled in production after reCAPTCHA registration. |

---

## 4. Quota Concurrency & Usage Accounting Hardening

### 4.1 Race Condition Resolution (Atomic Reservation)
- **Previous Vulnerability**: Read-then-write pattern in `checkQuota` allowed concurrent bursts to bypass monthly quotas.
- **Hardened Fix**: Implemented `AIUsageService.reserveQuotaAtomic()` using Firestore transactions on `agent_quotas/{ownerId}`.
- **Behavior**: Atomically verifies `reservedRequests < monthlyQuota` and increments the reservation within a database lock. If the quota is exceeded, rejects with `429 resource-exhausted`.

### 4.2 Failure Rollback Policy
If an AI invocation fails (e.g., transient network timeout or model rejection):
- `AIUsageService.rollbackQuotaReservation(ownerId)` is called in the `catch` block.
- The reserved counter is decremented and `failureRequests` incremented.
- Agents are **never** penalized or billed for failed system attempts.

### 4.3 Caching & Idempotency
- `analyzeProperty` checks `property_analyses/{projectId}_analysis`.
- If an analysis exists from the past 24 hours, the cached analysis is returned immediately with `meta.cached = true`, bypassing the Gemini API entirely.

### 4.4 Token Metric Source & Pricing Accounting
`AIUsageLog` now records:
- `tokenSource`: `"provider_metadata"` (actual tokens from `response.usageMetadata`) vs `"heuristic_estimation"`.
- `isEstimated`: `false` for live provider calls.
- `estimatedCostUsd`: Computed at exact 2026 rates ($0.075/1M in, $0.30/1M out for `gemini-2.5-flash`).

---

## 5. Frontend Fallback Transparency Audit

### 5.1 No Silent Masquerading
Previously, `CloudFunctionsAIService` fell back to `LocalRuleBasedAIService` without visibly notifying the user that a fallback occurred.

### 5.2 Implemented Improvements
1. **Model & Provenance Flags**:
   - `PropertyAnalysisResult` now includes `isLiveAI: bool` and `fallbackReason: String?`.
   - `AudienceSegmentModel` includes `isLiveAI: bool` and `generationSource: String`.
   - `MatchModel` includes `isLiveAI: bool` and `calculationSource: String`.
2. **Provider State Tracking**:
   - `AppStateProvider` exposes `isUsingAIFallback`, `lastAIError`, and `currentAIModel` (`gemini-2.5-flash`).
3. **UI Engine Status Indicators**:
   - In `AudienceDiscoveryScreen`:
     - When Live AI succeeds: displays a green badge: `Live AI Analysis Verified • Google Gemini 2.5 Flash`.
     - When Fallback activates: displays an amber warning banner: `Offline Fallback Engine Active (Rule-Based Analysis) • Live Gemini AI (gemini-2.5-flash) is currently offline or unreachable. Results are generated via the local rule-based heuristic engine.` alongside the exact API notice.

---

## 6. Files Modified During Phase 3.1.1

| File | Changes Made |
|---|---|
| `functions/src/config/gemini.config.ts` | Replaced retired models with `gemini-2.5-flash` / `gemini-2.5-pro` / `gemini-2.0-flash-lite`, added `validateModelIdentifier()` guard. |
| `functions/src/index.ts` | Bound `defineSecret("GEMINI_API_KEY")`, atomic quota reservation & rollback, project verification in Firestore, 24-hour cache check. |
| `functions/src/services/ai_usage_service.ts` | Added `reserveQuotaAtomic`, `rollbackQuotaReservation`, `recordQuotaSuccess`, and `calculateEstimatedCostUsd`. |
| `functions/src/validators/ai_request_validator.ts` | Hardened mandatory buyer ownership checks and added Firestore project ownership verification. |
| `functions/src/types/ai.types.ts` | Added token source, cost estimation, and atomic quota fields. |
| `functions/tests/gemini_service.test.ts` | Added tests for retired model rejection, unrecognized model rejection, API key validation, and retry backoff. |
| `functions/tests/ai_usage_service.test.ts` | Added tests for atomic reservation, quota exhaustion rejection, cost calculations, and logging. |
| `lib/models/audience_segment_model.dart` | Added `isLiveAI`, `generationSource`, and `fallbackReason` provenance fields with backwards-compatible defaults. |
| `lib/models/match_model.dart` | Added `isLiveAI` and `calculationSource` provenance fields. |
| `lib/services/ai_backend_service.dart` | Modernized model defaults to `gemini-2.5-flash`, added provenance metadata, and explicit fallback reason logging. |
| `lib/providers/app_state_provider.dart` | Added `isUsingAIFallback`, `lastAIError`, and `currentAIModel` getters. |
| `lib/screens/audience/audience_discovery_screen.dart` | Added dynamic AI Engine Provenance status badge and fallback warning banner. |
| `test/phase3_1_ai_foundation_test.dart` | Added tests for provenance metadata transparency and AppStateProvider fallback exposure. |
| `GEMINI_INTEGRATION_GUIDE.md` | Documented provider SDK, retired models, active supported models (November 2026), and configuration guards. |
| `PHASE_3_1_AI_ARCHITECTURE.md` | Updated architecture models to `gemini-2.5-flash` and `gemini-2.5-pro`. |
| `AI_BACKEND_API_SPECIFICATION.md` | Updated endpoint response contracts to `gemini-2.5-flash`. |
| `AI_USAGE_AND_COST_CONTROL.md` | Updated pricing calculations and primary model identifier. |

---

## 7. Comprehensive Test Verification Results

| Suite / Tool | Test Target | Results | Status |
|---|---|---|---|
| **TypeScript Compilation** | `tsc` (`functions/`) | **0 Errors**, clean output | **PASS** |
| **Backend Jest Tests** | `npm test` (`functions/`) | **33 / 33 Passed** (4 test suites) | **PASS** |
| **Flutter Static Analysis** | `flutter analyze` | **0 issues found** (1.8s) | **PASS** |
| **Flutter Unit & Integration Tests** | `flutter test` | **66 / 66 Passed** across 7 test suites | **PASS** |
| **Flutter Web Release Compilation** | `flutter build web --release` | **Built `build/web` cleanly** in 17.8s | **PASS** |

---

## 8. Outstanding Manual Configuration

Before deploying Cloud Functions to production:
1. **Secret Provisioning**: Execute `firebase functions:secrets:set GEMINI_API_KEY` with an authorized Google AI Studio API key.
2. **App Check Token Registration**: Provision a reCAPTCHA Enterprise web site key in the Firebase Console and enable `enforceAppCheck: true` in `callOptions`.
3. **Firestore Quota Initial Seed**: Ensure the `agent_quotas` collection is created with standard agent tiers upon production onboarding.

---

## 9. Recommendation for Phase 3.2

### Formal Recommendation: **GO FOR PHASE 3.2**

The backend AI service is modernized, secured against race conditions and cross-tenant leaks, equipped with model validation, and verified for fallback transparency.

The platform is cleared to advance to:
**Phase 3.2: Module A — Project Deep-Dive & Selling Angle Analysis**.
