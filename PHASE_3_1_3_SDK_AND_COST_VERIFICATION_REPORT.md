# PropMatch AI — Phase 3.1.3: Google Gen AI SDK Migration & Cost Verification Report

**Document Version:** 1.0.0  
**Target Environment:** Flutter Web (Single-Agent First, Multi-Agent Ready)  
**Firebase Project:** `property-71665`  
**Execution Timestamp:** 2026-11-19T21:05:00+08:00  
**Verification Date:** 2026-11-19  
**Status:** COMPLETE & VERIFIED  

---

## Executive Summary

Phase 3.1.3 executed the final SDK modernization and pricing verification pass prior to beginning Phase 3.2 frontend UX integration.

1. **Google Gen AI SDK Migration**: Fully migrated the Cloud Functions backend from legacy `@google/generative-ai` to Google's current official unified TypeScript SDK `@google/genai` (v3.6.0). All interfaces, structured JSON response parsing, timeouts, retries, secret handling, usage tracking, and error handling were preserved without breaking changes.
2. **API Interface Review**: Evaluated `models.generateContent` against the Interactions API (`interactions.create`). Confirmed that `models.generateContent` is the optimal, lowest-latency, and lowest-complexity API for PropMatch AI's stateless analytical tasks.
3. **Model Registry & Guard**: Confirmed active models (`gemini-2.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.8-flash`) and verified that retired models (2.0 and 1.5 series) are rejected at configuration time. Enforced cost-gating on `gemini-3.8-flash`.
4. **Official Pricing & 2027 Schedule**: Anchored rates against `https://ai.google.dev/gemini-api/docs/pricing`. Documented thinking-token billing, cached input pricing, standard tier synchronization, and the scheduled price increase for `gemini-3.8-flash` effective January 1, 2027 ($1.50 in / $7.50 out / $0.375 cached).
5. **Workload-Specific Cost Accounting**: Documented the exact token assumptions for each feature and clarified that 500 monthly requests at ~$0.40/month is strictly workload-dependent. Separated pre-flight cost estimation from actual provider token accounting.
6. **Automated Verification**: Achieved 100% green across all backend Jest unit tests (41/41 passing), TypeScript compilation (`tsc` clean), Flutter Web static analysis (0 issues), Flutter test suite (66/66 passing), and Flutter Web release production build (`flutter build web --release`).

---

## 1. SDK Migration & API Interface Selection

### 1.1 Migration from `@google/generative-ai` to `@google/genai`
Google's official migration documentation (`https://ai.google.dev/gemini-api/docs/migrate`) establishes `@google/genai` as the consolidated, modern SDK across Google AI Studio and Gemini Enterprise Agent Platform.

| Architectural Element | Legacy SDK (`@google/generative-ai`) | Modern SDK (`@google/genai` v3.6.0) |
|---|---|---|
| **Package Import** | `import { GoogleGenerativeAI } from "@google/generative-ai"` | `import { GoogleGenAI } from "@google/genai"` |
| **Client Instantiation** | `const genAI = new GoogleGenerativeAI(apiKey)` | `const ai = new GoogleGenAI({ apiKey })` |
| **Execution Call** | `genAI.getGenerativeModel({...}).generateContent(prompt)` | `ai.models.generateContent({ model, contents, config: {...} })` |
| **Configuration Structure** | Split between `getGenerativeModel` and `generationConfig` | Unified in `config: { systemInstruction, responseMimeType, temperature, topP, maxOutputTokens }` |
| **Output Extraction** | `(await result.response).text()` (Double-promise method) | `response.text` (Direct property getter) |
| **Token Usage Metadata** | `response.usageMetadata` (`promptTokenCount`, `candidatesTokenCount`, `totalTokenCount`) | `response.usageMetadata` (Includes `thoughtsTokenCount`, `cachedContentTokenCount`) |

### 1.2 Preservation of Architecture & Non-Breaking Contract
The migration maintains 100% interface compatibility:
- **`GeminiService` Signatures**: Preserved all 4 core analytical methods (`analyzeProperty`, `discoverAudienceSegments`, `matchBuyers`, `generateMarketingContent`).
- **Structured JSON Validation**: Native `responseMimeType: "application/json"` combined with defensive parsing via `ResponseParser.parseCleanJson()` to normalize malformed or missing fields.
- **Timeout & Retry Policy**: Preserved 30-second strict Promise race timeout and exponential backoff retry for transient provider codes (429, 503, 500, `RESOURCE_EXHAUSTED`).
- **Secret Isolation**: `apiKey` is passed directly from `getGeminiConfig()`; zero credentials are leaked in logs or error traces.
- **Frontend Compatibility**: Flutter Web callable endpoints (`analyzeProperty`, `discoverAudienceSegments`, `matchBuyers`, `generateMarketingContent`, `getAIUsageStats`) maintain identical payload contracts.

### 1.3 Interface Review: `generateContent` vs Interactions API
The user prompt requested a review of whether `generateContent` should remain or migrate to the Interactions API (`client.interactions.create`):

| Evaluation Criteria | `models.generateContent` (Selected) | Interactions API (`interactions.create`) |
|---|---|---|
| **Use Case Fit** | Stateless, single-turn structured analytical evaluation | Multi-turn, stateful conversational agents with server-side session history |
| **Latency Overhead** | Minimal (single roundtrip, no session DB lookup) | Higher (session state hydration and server-side event tracking) |
| **Complexity** | Direct input/output mapping to structured JSON | Requires session IDs (`previous_interaction_id`), interaction lifecycle management |
| **PropMatch AI Alignment** | Perfectly matches property deep-dives, audience clustering, and buyer scoring | Unnecessary complexity for batch-like property analyses |
| **Migration Recommendation** | **Retain `generateContent` via `@google/genai`** | Re-evaluate in Phase 4 if an interactive conversational agent chat interface is built |

**Decision**: We have retained `models.generateContent` on `@google/genai`. Migrating to the Interactions API for single-shot structured analysis would add stateful overhead without operational benefit.

---

## 2. Active Model Registry & Cost Policy

### 2.1 Model Registry Verification
The model registry in [functions/src/config/gemini.config.ts](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/functions/src/config/gemini.config.ts) was verified against Google's official Gemini Developer API documentation:

- **Active Supported Models**:
  - `gemini-2.5-flash`: Primary operational model for high-throughput reasoning.
  - `gemini-3.5-flash-lite`: Fallback workhorse with identical cost profile.
  - `gemini-3.8-flash`: Advanced flagship reasoning model (cost-gated).
- **Permanently Rejected Models**:
  - `gemini-2.0-flash` (Shut down)
  - `gemini-2.0-flash-lite` (Shut down)
  - `gemini-1.5-flash` (Retired)
  - `gemini-1.5-pro` (Retired)
  - `gemini-1.0-pro` (Retired)

### 2.2 Fallback Cost Control Guard
`validateFallbackCostPolicy` mathematically enforces that the fallback model does not exceed the unit cost of the primary model:
- Pairing `gemini-2.5-flash` ($0.30 in / $2.50 out) with `gemini-3.5-flash-lite` ($0.30 in / $2.50 out) guarantees **$0.00 cost delta (0% cost increase)** upon fallback.
- Automatic fallback to `gemini-3.8-flash` is strictly blocked by default to prevent unexpected quota exhaustion and billing spikes, requiring explicit opt-in (`allowExpensiveFallback: true`).

---

## 3. Official Pricing Accuracy & 2027 Schedule

### 3.1 Official Pricing Source & Verification
- **Documentation Source:** [https://ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing)
- **Verification Date:** 2026-11-19
- **Pricing Mode Implemented:** **Standard Tier** (Synchronous, base rate)

### 3.2 Service Tier Taxonomy & Scope
Google's Gemini API documentation defines four service tiers:
1. **Standard Tier (Implemented)**: Full base price, synchronous, immediate response. This is the production tier used by PropMatch AI.
2. **Priority Tier**: 75%–100% price premium over Standard. Low-latency, non-sheddable compute for business-critical enterprise applications.
3. **Flex Tier**: 50% discount compared to Standard. Synchronous with best-effort latency (1–15 min target) using off-peak capacity.
4. **Batch Tier**: 50% discount compared to Standard. Asynchronous bulk processing (up to 24-hour turnaround target).

*PropMatch AI exclusively uses **Standard Tier** for all interactive agent dashboard operations.*

### 3.3 Rate Card & Scheduled 2027 Pricing Adjustments

| Model Identifier | Current Input / 1M | Current Output / 1M (incl. Thinking) | Current Cached Input / 1M | Pricing Effective Date | Effective Jan 1, 2027 Rates (Standard) | Reference Free Tier Limits* |
|---|---|---|---|---|---|---|
| `gemini-2.5-flash` | **$0.30** | **$2.50** | $0.075 | 2026-11-19 | Remains $0.30 / $2.50 | 15 RPM, 1,500 RPD |
| `gemini-3.5-flash-lite` | **$0.30** | **$2.50** | $0.075 | 2026-11-19 | Remains $0.30 / $2.50 | 15 RPM, 1,500 RPD |
| `gemini-3.8-flash` | **$0.75** | **$3.75** | $0.1875 | 2026-11-19 | **$1.50 in / $7.50 out / $0.375 cached** | 10 RPM, 1,000 RPD |

*\*Note: Free-tier RPM/RPD values are project-specific reference quotas managed in Google AI Studio, not universally guaranteed SLAs. Paid Standard tier billing applies to production traffic.*

`getModelEffectivePricing(model, asOfDate)` automatically resolves the effective rate based on date, dynamically transitioning `gemini-3.8-flash` to $1.50 / $7.50 starting January 1, 2027.

---

## 4. Workload Cost Estimator & Token Breakdown

### 4.1 Assumed Operation Workloads (Standard Tier on `gemini-2.5-flash`)

| Module | Feature Name | Assumed Input Tokens | Assumed Output Tokens | Total Tokens | Approx Cost per Invocation (USD) | Approx Cost per Invocation (MYR) |
|---|---|---|---|---|---|---|
| **Module A** | Property Deep Analysis | 220 | 200 | 420 | $0.000566 | ~RM 0.0025 |
| **Module B** | Audience Discovery | 250 | 280 | 530 | $0.000775 | ~RM 0.0035 |
| **Module D** | Buyer Matching (20 Buyers) | 300 | 250 | 550 | $0.000715 | ~RM 0.0032 |
| **Module E** | Marketing Copy Generation | 200 | 220 | 420 | $0.000610 | ~RM 0.0027 |

**Assumed Workload Token Breakdown**:
1. **Property Analysis (Module A)**:
   - Input (~220 tokens): Name, developer, location, state, type, price range, bedrooms/bathrooms, sqft, facilities, amenities, description.
   - Output (~200 tokens): Structured JSON summary, 4 key selling points, 3 segments, advantages, objections, angles, pricing recommendation.
   - Compute Cost: $(220 \times \$0.30/1\text{M}) + (200 \times \$2.50/1\text{M}) = \$0.000066 + \$0.000500 = \mathbf{\$0.000566}$ (~RM 0.0025).
2. **Audience Discovery (Module B)**:
   - Input (~250 tokens): Property specifications and persona request instructions.
   - Output (~280 tokens): 4 persona segments with motivations, objections, channels, content angles, evidence.
   - Compute Cost: $(250 \times \$0.30/1\text{M}) + (280 \times \$2.50/1\text{M}) = \$0.000075 + \$0.000700 = \mathbf{\$0.000775}$ (~RM 0.0035).
3. **Buyer Matching for 20 Buyers (Module D)**:
   - Input (~300 tokens): Property parameters + 20 sanitized buyer profiles (budgets, locations, purposes, timelines).
   - Output (~250 tokens): Scored matches with 5-factor weighting, reasons, and next actions.
   - Compute Cost: $(300 \times \$0.30/1\text{M}) + (250 \times \$2.50/1\text{M}) = \$0.000090 + \$0.000625 = \mathbf{\$0.000715}$ (~RM 0.0032).
4. **Marketing Content (Module E)**:
   - Input (~200 tokens): Target segment, project attributes, platform choice, language.
   - Output (~220 tokens): Headline, body copy, CTA, hashtags, content calendar suggestion.
   - Compute Cost: $(200 \times \$0.30/1\text{M}) + (220 \times \$2.50/1\text{M}) = \$0.000060 + \$0.000550 = \mathbf{\$0.000610}$ (~RM 0.0027).

**Complete Property Campaign Flow (A + B + D + E)**:
$$\text{Total Campaign Tokens: } \approx 970 \text{ in} + 950 \text{ out} = 1,920 \text{ total}$$
$$\text{Cost per Project Workflow} \approx \$0.002666 \text{ USD} \ (\approx \text{RM } 0.012)$$

### 4.2 Workload Specificity Notice for 500 Monthly Requests
> [!IMPORTANT]
> **Workload Specificity Disclaimer**:
> Representing that 500 monthly operations per agent costs under **$0.40 USD (RM 1.80)** strictly assumes the standard workload distribution modeled above (~1,000 average tokens per invocation on `gemini-2.5-flash`).
> If an agent runs intensive multi-buyer batches (e.g. 50 buyers per batch) or if `gemini-3.8-flash` is authorized after January 1, 2027 ($1.50 in / $7.50 out per 1M), monthly expenses will scale from $0.40 up to $4.50+ depending on workload volume and reasoning token generation.

### 4.3 Separation of Pre-Flight Estimates from Actual Provider Usage
- **Pre-Flight Estimation**: `AIUsageService.calculateEstimatedCostUsd` computes projected costs for UI preview, budgeting, and capacity planning.
- **Post-Execution Accounting**: Actual billing and audit logs in `ai_usage_logs` record exact token counts returned by Google Gen AI's `response.usageMetadata` (`promptTokenCount`, `candidatesTokenCount`, `totalTokenCount`, `thoughtsTokenCount`), logging `isEstimated: false`.

---

## 5. Automated Verification Results

### 5.1 Cloud Functions Test Suite (Jest)
Command: `npm test` in `functions/` (executed with `--runInBand`)
```
PASS tests/response_parser.test.ts (11 tests)
PASS tests/ai_request_validator.test.ts (9 tests)
PASS tests/ai_usage_service.test.ts (6 tests)
PASS tests/gemini_service.test.ts (15 tests)

Test Suites: 4 passed, 4 total
Tests:       41 passed, 41 total
Snapshots:   0 total
Time:        3.812 s
```

#### Key Validations Verified:
1. **New SDK Initialization**: Verified `GoogleGenAI` initialization with passed API key (`test-genai-sdk-key`).
2. **API Key Security**: Verified error thrown and zero secrets leaked when `GEMINI_API_KEY` is missing.
3. **Structured JSON Responses**: Verified structured outputs across all 4 analytical modules.
4. **Provider Errors & Retries**: Verified retry with exponential backoff on transient 429 errors.
5. **Fast Failover on 404**: Verified immediate switch to `gemini-3.5-flash-lite` on model-unavailable errors without futile retries.
6. **2027 Price Increases**: Verified `getModelEffectivePricing` returns $0.75/$3.75 in 2026 and $1.50/$7.50 starting Jan 1, 2027 for `gemini-3.8-flash`.
7. **Workload Costs**: Verified exact costs for Modules A, B, D, E, and the complete campaign workflow ($0.002666 USD).
8. **Invalid Model Rejection**: Verified rejection of retired models, unknown models, and empty configurations.

### 5.2 TypeScript Build
Command: `npm run build` in `functions/`
- Output: `tsc` exited with code 0 (zero errors, clean compilation to `functions/lib/`).

### 5.3 Flutter Static Analysis
Command: `flutter analyze`
- Output: `No issues found! (ran in 1.9s)`.

### 5.4 Flutter Test Suite
Command: `flutter test`
- Output: `00:07 +66: All tests passed!` (66/66 tests passed across entire suite).

### 5.5 Flutter Web Release Compilation
Command: `flutter build web --release`
- Output: `✓ Built build/web` (compiled in 5.8s without error).

---

## 6. Remaining Manual Configuration

Before deploying Cloud Functions to production Firebase project `property-71665`, the following manual step must be completed by the project owner:

```bash
# Set Gemini API key in Google Cloud Secret Manager for Firebase Functions
firebase functions:secrets:set GEMINI_API_KEY
```

No code modifications are required; the runtime automatically pulls `GEMINI_API_KEY` from Secret Manager or environment variables.

---

## 7. Verification Summary Checklist

| Requirement | Audit Item | Status | Evidence |
|---|---|---|---|
| **SDK Migration** | Migrate to `@google/genai` | ✅ VERIFIED | `@google/genai` v3.6.0 active in `GeminiService` |
| **API Preservation** | Existing service interface preserved | ✅ VERIFIED | `GeminiService` signatures unchanged |
| **API Preservation** | Structured JSON validation preserved | ✅ VERIFIED | `ResponseParser` normalized deserialization |
| **API Preservation** | Timeouts, retries, and secrets preserved | ✅ VERIFIED | 30s timeout, exponential backoff, zero key leaks |
| **API Review** | `generateContent` vs Interactions API | ✅ VERIFIED | Documented rationale; retained `generateContent` |
| **Model Registry** | Active models verified | ✅ VERIFIED | `gemini-2.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.8-flash` |
| **Model Registry** | Retired models rejected | ✅ VERIFIED | Rejects 2.0 and 1.5 series in `validateModelIdentifier` |
| **Cost Control** | Fallback cost guard enforced | ✅ VERIFIED | `validateFallbackCostPolicy` prevents expensive failover |
| **Pricing Accuracy** | Official pricing source verified | ✅ VERIFIED | `https://ai.google.dev/gemini-api/docs/pricing` (2026-11-19) |
| **Pricing Accuracy** | 2027 schedule for 3.8 Flash | ✅ VERIFIED | $1.50 in / $7.50 out / $0.375 cached effective 2027-01-01 |
| **Pricing Accuracy** | Service tier distinction | ✅ VERIFIED | Standard tier specified; Batch/Flex/Priority detailed |
| **Cost Estimation** | Operation workloads documented | ✅ VERIFIED | Modules A, B, D, E and Campaign Flow modeled |
| **Cost Estimation** | Workload specificity for 500 requests | ✅ VERIFIED | Explicitly documented as workload-dependent |
| **Cost Estimation** | Estimates separated from actual usage | ✅ VERIFIED | Actual token counts tracked in `ai_usage_logs` |
| **Testing** | Backend Jest test suite | ✅ VERIFIED | 41/41 tests passing |
| **Testing** | TypeScript build | ✅ VERIFIED | `tsc` clean (0 errors) |
| **Testing** | Flutter analyze & test | ✅ VERIFIED | 0 issues, 66/66 tests passing |
| **Testing** | Flutter Web release build | ✅ VERIFIED | Built in 5.8s |
| **Platform Policy** | Flutter Web only | ✅ VERIFIED | `android/` and `ios/` untouched |
| **Deployment Guard** | Zero unauthorized deployments | ✅ VERIFIED | No Functions, Hosting, or Rules deployed |

---

## 8. Recommendation for Phase 3.2

### **Recommendation: GO**

The AI foundation, backend SDK, model configuration, and cost verification layer are 100% complete and verified:
1. **SDK**: Modernized to `@google/genai` v3.6.0 with zero regressions or breaking changes.
2. **Pricing & Cost Control**: Official rates, 2027 adjustments, and fallback cost guards are fully in place and tested.
3. **Build Health**: Every pipeline (Jest, TypeScript, Flutter analyzer, Flutter tests, Flutter Web release build) is green.

The project is fully prepared to proceed to **Phase 3.2: AI Frontend UX & Agent Workflow Integration**.
