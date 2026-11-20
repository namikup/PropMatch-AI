# PropMatch AI — Phase 3.3B: Intelligent Buyer Matching Report

**Date**: November 20, 2026  
**Target Environment**: Flutter Web | Firebase Project: `property-71665`  
**Execution Status**: Local Implementation & Full Verification Complete (Ready for Staging Audit)

---

## 1. Executive Summary

Phase 3.3B delivers the **Intelligent Buyer Matching System** for PropMatch AI, connecting an agent's registered prospective buyer database directly with selected property development projects. 

Rather than relying on ungrounded generative AI scores or a generic conversational chatbot, PropMatch AI enforces a **two-tier intelligence architecture**:
1. **Deterministic Matching Engine**: Strictly evaluates multi-dimensional compatibility using fixed, auditable weights totaling 100%. **Gemini is never permitted to invent, adjust, or override the deterministic compatibility score or factor weights.**
2. **AI Advisory & Qualitative Explanation Layer**: Powered by Google Gemini (`gemini-2.5-flash` with automatic fallback to `gemini-3.5-flash-lite`), synthesizing tailored agent narratives, real-world buyer objections, actionable next steps, and respectful conversation openers for WhatsApp and phone outreach.

---

## 2. Architecture & Scoring Methodology

### 2.1 Fixed 5-Dimensional Weighted Scoring Model

The compatibility score evaluates five distinct dimensions representing the Malaysian property purchasing process:

| Dimension | Weight | Scoring & Divergence Rules |
| :--- | :---: | :--- |
| **Budget Compatibility** | **25%** | **25.0**: Direct overlap (buyer ceiling $\ge$ project starting price and buyer minimum $\le$ project max tier).<br>**20.0**: High budget capacity (buyer minimum exceeds project maximum tier).<br>**18.0**: Budget stretch within 10% (buyer maximum $\ge 90\%$ of project starting price).<br>**10.0**: Missing/unspecified budget range (penalized).<br>**5.0**: Severe budget shortfall ($< 90\%$ of starting price). |
| **Location Preference** | **25%** | **25.0**: Exact locality match (e.g., Mont Kiara $\leftrightarrow$ Mont Kiara).<br>**18.0**: Same state match, different sub-locality (e.g., Bangsar vs Mont Kiara within Kuala Lumpur).<br>**8.0**: Missing/unspecified location preferences.<br>**6.0**: Inter-state mismatch (e.g., Selangor vs Kuala Lumpur). |
| **Property Type Alignment** | **20%** | **20.0**: Exact type match (e.g., Condominium $\leftrightarrow$ Condominium).<br>**16.0**: High-rise category match (Condominium, Apartment, Serviced Residence).<br>**7.0**: Unspecified property type.<br>**4.0**: Type divergence (e.g., Landed House vs High-rise Condominium). |
| **Purchase Purpose** | **15%** | **15.0**: Exact objective alignment (Own Stay vs Own Stay, Investment vs Investment, or Dual-Purpose).<br>**6.0**: Purpose gap (e.g., project optimized for family own stay while buyer seeks short-term rental investment).<br>**5.0**: Unspecified purchase purpose. |
| **Buying Timeline** | **15%** | **15.0**: Immediate buyer with Completed project.<br>**14.0**: Optimal 3–6 month purchasing window.<br>**11.0**: 1-year pipeline prospect for ongoing construction milestones.<br>**10.0**: Immediate buyer with Under Construction / New Launch status.<br>**6.0**: Unspecified procurement horizon / exploring. |
| **Total Compatibility** | **100%** | Clamped to $0.0 - 100.0\%$. |

### 2.2 Compatibility Classifications & Confidence Grading

- **Classifications**:
  - **Excellent Match (85–100%)**: High synergy across all core criteria. Primary candidate for private showroom tours and unit reservation.
  - **Good Match (70–84%)**: Strong baseline suitability with minor sub-locality or timeline adjustments. Worth engaging with unit layout and financing options.
  - **Moderate Match (50–69%)**: Moderate suitability with notable budget stretches or inter-state considerations. Requires criteria clarification.
  - **Low Match (< 50%)**: Fundamental divergence in budget, location, or property type. Retained in general nurture pipeline.
  - *Disclaimer*: Compatibility classifications evaluate feature alignment; they are **not** conversion probabilities.

- **Confidence Levels**:
  - **High**: Complete buyer profile documentation (0 missing fields).
  - **Medium**: 1 missing non-critical factor.
  - **Low**: 2 or more missing criteria (e.g., unspecified budget, missing state).

---

## 3. Privacy, Multi-Tenancy & PDPA Compliance

1. **Multi-Tenant Ownership Verification**:
   - `AIRequestValidator.validateAuth(callerUid)` verifies caller authentication.
   - `AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid)` confirms project ownership.
   - `AIRequestValidator.validateAndSanitizeBuyers(buyers, callerUid)` verifies `buyer.ownerId === callerUid`. Cross-agent data access is rejected with `HttpsError('permission-denied')`.
2. **PII Sanitization**:
   - Strips full name, IC number, phone number, email address, and street address before passing data to Gemini.
   - Only anonymized numerical and categorical attributes (`budgetMin`, `budgetMax`, `preferredLocation`, `preferredState`, `propertyType`, `purchasePurpose`, `buyingTimeline`) are submitted to the LLM.
   - Buyer names are re-attached locally on the frontend or post-processed on the server.
3. **Agent Action Guardrails**:
   - PropMatch AI enforces **Human-in-the-Loop** control.
   - No automated WhatsApp messages or background auto-dispatching are performed. Agents must review conversation starters and explicitly copy or trigger actions.

---

## 4. Caching & Offline Resilience

1. **Deterministic Signature Fingerprinting**:
   - Computed from: `projectId + startingPrice + maximumPrice + location + state + propertyType + sorted(sanitizedBuyersSignature)`.
   - Any change in project pricing or buyer budget immediately invalidates the cache.
2. **Firestore Audit & Cache Persistence**:
   - Cached documents are stored in `/matches/${projectId}_matches` with `ownerId: callerUid`, `sourceVersion: fingerprint`, and 24-hour TTL.
   - Cached queries return within $<5\text{ ms}$ with $0\text{ tokens}$ consumed.
3. **Atomic Quota Reservation & Rollback**:
   - Atomic reservation prevents quota overrun.
   - If Gemini encounters transient errors or provider outages, the reservation is atomically rolled back, and the system seamlessly falls back to the deterministic engine with rule-based explanations (`isLiveAI: false`).

---

## 5. Implementation Summary

### 5.1 Cloud Functions Backend
- `functions/src/types/ai.types.ts`: Enriched `BuyerMatchingItem` and `BuyerMatchingOutput` with Phase 3.3B fields (`confidence_level`, `matching_classification`, `mismatched_criteria`, `potential_objections`, `recommended_next_action`, `ai_explanation`, `suggested_conversation_opener`, `overview`).
- `functions/src/services/deterministic_matching.ts`: Created standalone deterministic engine implementing the 5 weighted dimensions and overview metrics calculation.
- `functions/src/utils/response_parser.ts`: Enhanced `validateBuyerMatching(data, baseline)` to strictly enforce deterministic scores and prevent LLM score hallucinations.
- `functions/src/services/gemini_service.ts`: Updated `matchBuyers` with prompt engineering instructing Gemini to act solely as an explanation, objection-handling, and advisory layer for the pre-calculated matches.
- `functions/src/index.ts`: Updated `matchBuyers` callable function with multi-tenant validation, deterministic scoring, fingerprint caching, Gemini advisory generation, and fallback handling. Exported `getMatches` for rapid cached retrieval.
- `functions/src/config/firebase.config.ts`: Added `matches` collection reference.

### 5.2 Flutter Web Application
- `lib/models/match_model.dart`: Enriched with Phase 3.3B fields (`confidenceLevel`, `matchClassification`, `mismatchedCriteria`, `potentialObjections`, `recommendedNextAction`, `aiExplanation`, `suggestedConversationOpener`, `isCached`, `sourceVersion`) and classification helper getters (`isExcellentMatch`, `isGoodMatch`, `isModerateMatch`, `isLowMatch`, `formattedScore`, `effectiveExplanation`).
- `lib/services/matching_service.dart`: Updated `calculateMatch` to generate Phase 3.3B classifications, confidence ratings, objection items, and default conversation starters.
- `lib/services/ai_backend_service.dart`: Updated `AIBackendService` interface, `LocalRuleBasedAIService` (with `_localMatchCache`), and `CloudFunctionsAIService` (with `getCachedMatches` and `matchBuyers` supporting `forceRefresh`).
- `lib/providers/app_state_provider.dart`: Added caching map `_cachedProjectMatches`, filter cohorts (`setMatchFilter`), sort orders (`setMatchSortOrder`), dynamic stats (`totalEvaluatedMatches`, `excellentMatchesCount`, `goodMatchesCount`, `moderateMatchesCount`, `lowMatchesCount`, `averageMatchScore`), and project cache restoration in `selectProject`.
- `lib/screens/matching/matching_screen.dart`: Built executive UI with:
  - Project Selector Bar displaying active development specifications.
  - Overview Statistics Cards (Total Evaluated, Excellent, Good, Moderate, Low, Average Score).
  - Cohort Filter Chips and Sorting Dropdown.
  - Candidate Cards with score badges, confidence indicators, and action chips.
  - Detailed Match Inspector with weighted dimension breakdown bars, positive factors, hesitations, information gap checklist, recommended agent action, and 1-click clipboard WhatsApp opener.
  - "Add Follow-up" task dialog and "Convert to Lead" pipeline integration.

---

## 6. Verification & Test Evidence

### 6.1 Backend Test Suite (Jest)
- Executed: `npm test --prefix functions -- --runInBand`
- **Result: 7 of 7 test suites passed (56 tests passed, 0 failures)**
  - `tests/buyer_matching_cache.test.ts`:
    - Verified exact scoring across all 5 dimensions.
    - Verified missing information penalty and Low confidence grading.
    - Verified classifications (Excellent, Good, Moderate, Low).
    - Verified deterministic score preservation when merging hallucinated LLM responses.
    - Verified accurate overview calculations across buyer batches.
  - `tests/gemini_service.test.ts`: Passed (14 tests).
  - `tests/ai_usage_service.test.ts`: Passed (6 tests).
  - `tests/response_parser.test.ts`: Passed (10 tests).
  - `tests/audience_discovery_cache.test.ts`: Passed (4 tests).
  - `tests/property_analysis_cache.test.ts`: Passed (4 tests).
  - `tests/ai_request_validator.test.ts`: Passed (9 tests).

### 6.2 TypeScript Compilation
- Executed: `npm run build --prefix functions`
- **Result: Clean compilation (0 errors, exit code 0)**

### 6.3 Flutter Static Analysis
- Executed: `/Users/jiaxianlim/flutter/bin/flutter analyze`
- **Result: No issues found! (0 errors, 0 warnings, 0 lints)**

### 6.4 Flutter Test Suite
- Executed: `/Users/jiaxianlim/flutter/bin/flutter test`
- **Result: All 85 tests passed! (0 failures)**
  - `test/phase3_3b_buyer_matching_test.dart`:
    - MatchingService deterministic scoring and factor breakdown.
    - Classifications and confidence grading.
    - AppStateProvider caching, filtering, sorting, and project switching.
    - MatchingScreen widget tests (header, overview cards, dimension bars, action buttons).
  - `test/full_verification_test.dart`: Passed all 9 end-to-end user workflows.
  - `test/phase3_3a_audience_discovery_test.dart`: Passed.
  - `test/phase3_2_property_analysis_test.dart`: Passed.
  - `test/phase3_1_ai_foundation_test.dart`: Passed.
  - `test/phase2_4_production_readiness_test.dart`: Passed.
  - `test/phase2_1_auth_and_persistence_test.dart`: Passed.
  - `test/phase1_8_hardening_test.dart`: Passed.
  - `test/phase1_stabilisation_test.dart`: Passed.

### 6.5 Flutter Web Release Build
- Executed: `/Users/jiaxianlim/flutter/bin/flutter build web --release`
- **Result: Built `build/web` successfully in 20.3s (exit code 0)**

---

## 7. Compliance Verification Table

| Rule / Constraint | Compliance Status | Details |
| :--- | :---: | :--- |
| **Flutter Web Only** | **COMPLIANT** | Only `lib/` and `functions/` modified. `android/` and `ios/` remain 100% untouched. |
| **Deterministic Engine Precedes AI** | **COMPLIANT** | Scores calculated strictly via `DeterministicMatchingEngine` / `MatchingService`. Gemini only provides qualitative explanation. |
| **5 Weighted Criteria Adherence** | **COMPLIANT** | Budget 25%, Location 25%, Property Type 20%, Purpose 15%, Timeline 15%. Total = 100%. |
| **PDPA & Multi-Tenant Data Isolation** | **COMPLIANT** | `ownerId == callerUid` strictly verified; PII (names, emails, phones, ICs) stripped before LLM prompt. |
| **No Production Deployment** | **COMPLIANT** | Zero Firebase CLI deployment commands executed; no production secrets or billing altered. |
| **Git Safety** | **COMPLIANT** | No commits or pushes created. |
| **Human-in-the-Loop** | **COMPLIANT** | Strictly agent-triggered copy and action buttons. No automated message dispatching. |
