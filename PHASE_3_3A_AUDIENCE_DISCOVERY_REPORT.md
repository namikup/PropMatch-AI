# PropMatch AI — Phase 3.3A Implementation & Verification Report
## AI Audience Discovery & Market Demand Intelligence

**Report Generated:** November 20, 2026  
**Target Environment:** Firebase Project `property-71665` (Single-Agent First, Multi-Agent Ready)  
**Platform Policy:** Flutter Web ONLY (`android/` and `ios/` strictly preserved untouched)  
**Execution Status:** Complete & Verified  

---

## 1. Executive Summary

Phase 3.3A delivers **AI Audience Discovery & Market Demand Intelligence** for PropMatch AI. Moving beyond generic chatbots or static persona descriptions, this release equips Malaysian real estate negotiators (REN/PEA) with evidence-aware, actionable buyer discovery intelligence directly synthesized from property specifications, pricing structures, location amenities, deep-dive property analysis, and agent field observations.

### Core Deliverables Achieved
1. **Audience Discovery Workflow (`discoverAudienceSegments`)**:
   - Analyzes project specifications, pricing tiers, location, target purpose, existing AI property intelligence, and agent market observations.
   - Discovers **3 to 6 actionable potential buyer segments** tailored specifically to the project.
   - Differentiates verified facts from AI demographic hypotheses.
2. **Strict Evidence-Aware Demand Intelligence & Anti-Hallucination Boundaries**:
   - Categorizes every output element into **Verified Project Facts** (price, location, layout, facilities, agent notes) and **AI Demographic Hypotheses** (assumptions, purchasing motivations).
   - Enforces the mandatory disclaimer: *"AI-generated audience hypothesis — not verified market demand."*
   - Strictly prohibits hallucinating headcount numbers of searching people, actual buyer counts, demand statistics, or contact details of real persons.
   - Explicitly defines relevance scores as demographic/specification alignment indicators (0–100%), not actual conversion probabilities.
3. **Cloud Functions AI Backend & Multi-Tenant Firestore Persistence**:
   - `discoverAudienceSegments` callable with deterministic fingerprint hashing (`audienceFingerprint`, 24h TTL caching) preventing redundant LLM expenditure.
   - Exported `getAudienceSegments` callable for instantaneous sub-10ms cache retrieval.
   - Multi-agent isolation enforcing `isResourceOwner()` and quota reservation.
   - Server-side response validator clamping relevance scores (0–100) and normalizing required arrays.
4. **Interactive Audience Discovery Dashboard (Flutter Web)**:
   - High-level metric overview: Discovered Segments, Top Persona Fit, Average Fit Score, Confidence & Cache status.
   - Rich Segment Cards displaying fit score badge, confidence chip (High/Medium/Low), buying motivations, appealing project features, expected objections, recommended platforms, and recommended content formats (e.g. *15s Video Reel*, *Carousel Ad*, *WhatsApp Flyer*).
   - One-click copy buttons for tailored marketing hooks and complete audience segment briefs.
   - Side-by-side Segment Comparison Modal (comparing 2–4 segments simultaneously).
   - Local Market Observations modal dialog allowing agents to inject live field intelligence into the discovery engine.
   - Seamless navigation hook: **"Discover Potential Buyers"** integrated directly in `PropertyAnalysisScreen` (AppBar, Section C Buyer Personas, and Section G Strategic Summary).

---

## 2. Technical Architecture & Data Flow

```
                                    ┌────────────────────────────────────────────────────────┐
                                    │               Flutter Web Client (Agent UI)           │
                                    └───────────────────────────┬────────────────────────────┘
                                                                │
                            1. Select Project / Open Property Intelligence Screen
                                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PropertyAnalysisScreen: "Discover Potential Buyers"                                                                │
│  ├── AppBar Action: Direct trigger with optional field observation dialog                                          │
│  ├── Section C (Personas): Actionable demand intelligence banner                                                   │
│  └── Section G (Summary): Recommended next step button                                                             │
└───────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────┘
                                                │
                                    2. Invoke runAudienceDiscovery()
                                                │
                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ AppStateProvider (Provider State Management)                                                                       │
│  ├── In-Memory Session Cache: _cachedAudienceSegments[projectId]                                                   │
│  ├── Cloud Remote Cache: _aiService.getCachedAudienceSegments(projectId)                                           │
│  └── Remote Dispatch: _aiService.discoverAudienceSegments(project, existingAnalysis, agentObservations)           │
└───────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────┘
                                                │
                               3. HTTPS Callable (Cloud Functions)
                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Cloud Functions Backend (Node.js 20 / TypeScript / @google/genai)                                                  │
│  ├── AIRequestValidator: Authenticate callerUid, verify project.ownerId == callerUid                               │
│  ├── Deterministic Fingerprint: hash(name + price + location + specs + facilities + observations)                  │
│  ├── Firestore Cache Check: audience_segments where projectId == target && sourceVersion == fingerprint            │
│  ├── Quota Reservation: AIUsageService.reserveQuota(callerUid, 'audience_discovery')                               │
│  ├── Gemini API 2.5: gemini-2.5-flash with structured JSON response schema & evidence prompt                       │
│  ├── Response Parser: validateAudienceDiscovery (clamping 0-100, safe array defaults, disclaimer)                  │
│  └── Firestore Audit Persistence: Store segment models in collection 'audience_segments'                           │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Evidence-Aware Intelligence & Compliance Implementation

### 3.1 Strict Grounding & Anti-Hallucination Boundaries
To ensure strict regulatory compliance with Malaysian property advertising standards (BOVAEP/MIEA) and avoid misleading agents:
- **No Invented Headcounts**: The prompt, response parser, and UI strictly forbid generating statements like *"1,250 buyers currently looking in Batu Kawan"* or *"78% conversion probability"*.
- **Score Semantics**: Relevance scores are explicitly rendered as **"Fit Score" / "Demographic Alignment"** rather than likelihood of closing.
- **Evidence vs. Hypotheses Bifurcation**:
  - `evidence`: Direct project attributes provided by the agent (e.g., *RM480k entry price, 1,050 sqft layout, Batu Kawan location, nearby IKEA/hospital*).
  - `assumptions`: Algorithmic hypotheses regarding target buyer income tiers, commuting preferences, or debt service ratios.
- **Mandatory Disclaimers**: Rendered in a high-visibility disclaimer banner across the dashboard:
  > *"AI-generated audience hypothesis — not verified market demand. Relevance scores reflect demographic & feature alignment based on agent-supplied specifications, NOT actual lead conversion probabilities or verified buyer headcounts. Verified property characteristics are strictly distinguished from AI demographic hypotheses. Never treat audience hypotheses as guaranteed buyers."*

---

## 4. Modified & Created Files

### 4.1 Backend (Cloud Functions)
| File | Action | Purpose |
|------|--------|---------|
| `functions/src/types/ai.types.ts` | Modified | Added Phase 3.3A fields (`appealing_features`, `recommended_marketing_messages`, `recommended_content_formats`, `evidence`, `assumptions`, `confidence_level`, `market_demand_disclaimer`), and updated `AudienceDiscoveryOutput`. |
| `functions/src/utils/response_parser.ts` | Modified | Updated `validateAudienceDiscovery` to clamp relevance (0–100), validate array fields, supply default fallbacks, and attach mandatory disclaimer. |
| `functions/src/services/gemini_service.ts` | Modified | Updated `discoverAudienceSegments` with evidence-aware prompt rules and JSON schema incorporating Phase 3.3A requirements. |
| `functions/src/index.ts` | Modified | Added deterministic fingerprint cache checking (24h validity), tenant isolation check, quota reservation, and exported `getAudienceSegments` callable. |
| `functions/tests/audience_discovery_cache.test.ts` | Created | 4 Jest tests verifying schema validation, clamping, cache fingerprint invalidation on price/observation change, and multi-tenant security. |

### 4.2 Frontend (Flutter Web)
| File | Action | Purpose |
|------|--------|---------|
| `lib/models/audience_segment_model.dart` | Modified | Added Phase 3.3A fields (`appealingFeatures`, `recommendedContentFormats`, `evidence`, `assumptions`, `confidenceLevel`, `marketDemandDisclaimer`, `isCached`, `sourceVersion`), backward-compatible getters, and full serialization. |
| `lib/services/ai_backend_service.dart` | Modified | Added `getCachedAudienceSegments` to interface and both implementations; enhanced `LocalRuleBasedAIService` with local in-memory cache and 3.3A fields; updated `CloudFunctionsAIService` to pass analysis, observations, and forceRefresh. |
| `lib/providers/app_state_provider.dart` | Modified | Added `cachedAudienceSegments`, `audienceDiscoveryError`, `lastAgentObservations`; updated `runAudienceDiscovery` with caching lifecycle; added `saveAudienceSegmentsToFirestore` and `clearAudienceDiscovery`. |
| `lib/screens/projects/property_analysis_screen.dart` | Modified | Integrated **"Discover Potential Buyers"** action into AppBar, Section C Buyer Personas callout banner, and Section G Strategic Summary recommended action. |
| `lib/screens/audience/audience_discovery_screen.dart` | Modified | Enhanced dashboard with 4 overview metric cards, responsive control header, mandatory disclaimer banner, evidence vs assumptions cards, content formats, copyable hooks, segment comparison modal, and observation dialog. |
| `test/phase3_3a_audience_discovery_test.dart` | Created | Comprehensive test suite covering model serialization, fallback rule engine, provider caching, and widget testing for discovery dashboard and property analysis actions. |

---

## 5. Verification & Test Execution Results

### 5.1 Backend Test Verification
Command executed:
```bash
cd functions && npm run build && npm test -- --runInBand
```
Result:
- **Build**: `tsc` compiled cleanly with 0 errors.
- **Test Suites**: 6 passed, 6 total.
- **Tests**: 49 passed, 0 failed, 49 total.
- **Suites Passed**:
  1. `tests/audience_discovery_cache.test.ts` (Phase 3.3A cache & schema validation)
  2. `tests/gemini_service.test.ts` (Google Gen AI SDK & Gemini 2.5 Flash execution)
  3. `tests/property_analysis_cache.test.ts` (Phase 3.2 property analysis cache)
  4. `tests/ai_usage_service.test.ts` (Quota and pricing accuracy)
  5. `tests/ai_request_validator.test.ts` (Multi-tenant security & PDPA validation)
  6. `tests/response_parser.test.ts` (JSON cleaning and response normalization)

### 5.2 Flutter Static Analysis
Command executed:
```bash
flutter analyze
```
Result:
```
Analyzing PropMatch AI...
No issues found! (ran in 1.9s)
```

### 5.3 Flutter Unit & Widget Test Suite
Command executed:
```bash
flutter test
```
Result:
- **Total Test Suites**: 8 test files.
- **Total Tests Passed**: **77 tests passed**, 0 failed!
- **Phase 3.3A Specific Tests** (`test/phase3_3a_audience_discovery_test.dart`):
  1. `AudienceSegmentModel serializes and deserializes all Phase 3.3A fields correctly` — PASSED
  2. `LocalRuleBasedAIService generates complete 3.3A audience segments with caching & observations` — PASSED
  3. `AppStateProvider manages audience discovery, caching, and forceRefresh lifecycle` — PASSED
  4. `AudienceDiscoveryScreen renders mandatory disclaimer, overview stats, and segment cards` — PASSED
  5. `PropertyAnalysisScreen includes "Discover Potential Buyers" actions` — PASSED

### 5.4 Flutter Web Production Release Build
Command executed:
```bash
flutter build web --release
```
Result:
```
Compiling lib/main.dart for the Web...                             18.1s
✓ Built build/web
```

---

## 6. Multi-Tenant Firestore Schema Compliance

Firestore documents persisted to `/audience_segments/{segmentId}` strictly conform to the security rules deployed in Phase 2.3:
```javascript
match /audience_segments/{segmentId} {
  allow read: if isAuthenticated() && isResourceOwner();
  allow create: if isAuthenticated()
    && isAssigningSelfAsOwner()
    && request.resource.data.name is string
    && request.resource.data.name.size() >= 2
    && request.resource.data.name.size() <= 150;
  allow update: if isAuthenticated()
    && isResourceOwner()
    && isImmutableOwner();
  allow delete: if isAuthenticated() && isResourceOwner();
}
```
Client batch writes and Cloud Functions writes attach:
- `ownerId: request.auth.uid`
- `name: segment.name` (2 to 150 chars)
- `projectId: project.id`
- `sourceVersion: fingerprint`
- `appealingFeatures`, `recommendedContentFormats`, `evidence`, `assumptions`, `confidenceLevel`, `marketDemandDisclaimer`

---

## 7. Next Steps for Phase 3.3B (Intelligent Buyer Matching)

With Phase 3.3A verified and operational, the foundation is primed for **Phase 3.3B: Intelligent Buyer Matching**:
1. Implement AI Buyer Matching algorithm evaluating real buyer profiles against project parameters and discovered audience segments.
2. Calculate multi-factor compatibility scores (budget fit, location affinity, property type alignment, timeline urgency).
3. Generate detailed match reasoning and transparent mismatch warnings.
4. Maintain multi-agent privacy boundaries and PDPA compliance.
