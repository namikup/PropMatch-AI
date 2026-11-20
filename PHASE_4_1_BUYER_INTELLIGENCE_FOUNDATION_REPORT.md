# PropMatch AI — Phase 4.1: Buyer Intelligence Foundation Report

**Target Firebase Project**: `property-71665`  
**Execution Environment**: Flutter Web (Desktop/Laptop/Tablet/Mobile Responsive)  
**Status**: Completed, Hardened & Fully Verified (100% Tests Passing, Web Release Built)  
**Date**: November 20, 2026  

---

## 1. Executive Summary

Phase 4.1 marks the architectural transition of **PropMatch AI** from a property project intelligence tool into an enterprise-grade **AI-Powered Buyer Intelligence and Prospect Acquisition Platform** tailored specifically for the Malaysian real estate market.

In this foundational phase, we established the **Prospect Intelligence Database Foundation**:
- Completely decoupled from the proprietary CRM `buyers` collection to guarantee data provenance and prevent CRM bloat.
- Built-in compliance with the **Malaysian Personal Data Protection Act 2010 (PDPA)**, strictly separating **Verification Status** from **Contact Eligibility**.
- Guaranteed default compliance: all external leads and imported records default strictly to `Pending Consent` and are **never** automatically treated as eligible for outbound marketing or calling.
- Full multi-agent isolation across 8 dedicated Firestore collections with local immutable security rules.

---

## 2. Core Architecture & Data Models

Seven foundational data models were engineered in `lib/models/`, designed for high performance, immutable auditability, and data provenance:

| Model | File | Description & Purpose |
|---|---|---|
| **`ProspectModel`** | [`lib/models/prospect_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_model.dart) | Core prospect entity with multi-location preferences, budget tiers, purchase timeline, masked NRIC/passport, lifecycle status, verification status, and contact eligibility. |
| **`ProspectSourceModel`** | [`lib/models/prospect_source_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_source_model.dart) | Metadata configuration for ingestion channels (Portals, Co-broke agency alliances, developer visitor desks, CRM imports). |
| **`ProspectSourceRecordModel`** | [`lib/models/prospect_source_record_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_source_record_model.dart) | Provenance tracking linking every prospect to an immutable external lead ID, campaign reference, and payload capture. |
| **`ProspectConsentEventModel`** | [`lib/models/prospect_consent_event_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_consent_event_model.dart) | Granular PDPA consent event log capturing consent scope (`Marketing`, `Direct Inquiry`), status (`Granted`, `Withdrawn`), timestamp, source, and evidence text. |
| **`ProspectActivityModel`** | [`lib/models/prospect_activity_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_activity_model.dart) | Chronological append-only timeline documenting all agent touches, status updates, verification upgrades, and CRM conversions. |
| **`ProspectImportJobModel`** | [`lib/models/prospect_import_job_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_import_job_model.dart) | Audit records for batch CSV/CRM imports documenting imported rows, duplicates, and failures. |
| **`ProspectMatchModel`** | [`lib/models/prospect_match_model.dart`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/lib/models/prospect_match_model.dart) | Compatibility pairing record linking prospects against development projects without mutating core buyer profiles. |

---

## 3. Separation of CRM Buyers vs. Acquisition Prospects

A strict boundary is maintained between active CRM clients and prospective top-of-funnel intake:

```
┌─────────────────────────────────────────────────────────────┐
│                 PropMatch AI Acquisition Hub                │
│  [Property Portals] [Developer Desks] [Co-Broke] [CSV / CRM]│
└──────────────────────────────┬──────────────────────────────┘
                               │ Ingestion & Profiling
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Prospect Intelligence Pool                  │
│               Collection: `prospects`                       │
│  - Lifecycle: Discovered / Imported / Verified / Qualified   │
│  - Eligibility: Pending Consent / Ineligible / DNC          │
│  - Multi-source provenance & PDPA consent event log        │
└──────────────────────────────┬──────────────────────────────┘
                               │ Verified Consent & Qualification
                               │ (Agent Action: "Convert to Buyer CRM")
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Active Agent CRM Database                  │
│                Collection: `buyers`                         │
│  - Fully owned, active buyers with established relationship │
│  - Target for active AI Buyer Matching and Direct Pitching  │
└─────────────────────────────────────────────────────────────┘
```

The `convertProspectToBuyer(prospect)` method seamlessly creates a full `BuyerModel` in the CRM while retaining the origin prospect with an updated `Qualified` status and logging an activity event in the provenance history.

---

## 4. Malaysian PDPA 2010 Compliance Architecture

### Contact Eligibility vs. Verification Status
Data quality and legal contact rights are decoupled to prevent compliance violations:

- **`verificationStatus`** (`Unverified`, `Phone Verified`, `Email Verified`, `Identity Verified`): Measures data authenticity and contactability.
- **`contactEligibility`** (`Ineligible`, `Pending Consent`, `Eligible`, `Do Not Contact`): Governs legal authorization under Malaysian PDPA 2010.

### Mandatory Compliance Rules
1. **Never Default to Eligible**: All newly imported records, portal inquiries, and discovered leads strictly default to `contactEligibility = 'Pending Consent'`.
2. **Immutable Append-Only Trail**: Once created, records in `prospect_consents` and `prospect_activities` cannot be edited or deleted (`allow update: if false; allow delete: if false;`).
3. **Automatic Reclassification**:
   - Recording a `Granted` consent event automatically moves eligibility to `Eligible`.
   - Recording a `Withdrawn` consent event immediately moves eligibility to `Do Not Contact (DNC)`.

---

## 5. Security Rules & Multi-Agent Isolation

The local [`firestore.rules`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/firestore.rules) file was updated with dedicated rules for all 8 Phase 4.1 collections:

```javascript
// 10. PROSPECTS
match /prospects/{prospectId} {
  allow read: if isResourceOwner();
  allow create: if isAssigningSelfAsOwner() && isNonEmptyString(request.resource.data.fullName, 2, 100);
  allow update: if isResourceOwner() && isOwnerImmutable();
  allow delete: if isResourceOwner();
}

// 13. PROSPECT PDPA CONSENTS (Append-Only)
match /prospect_consents/{consentId} {
  allow read: if isResourceOwner();
  allow create: if isAssigningSelfAsOwner() && isNonEmptyString(request.resource.data.prospectId, 1, 100);
  allow update: if false; // Strict PDPA immutability
  allow delete: if false;
}

// 14. PROSPECT ACTIVITY TIMELINE (Append-Only)
match /prospect_activities/{activityId} {
  allow read: if isResourceOwner();
  allow create: if isAssigningSelfAsOwner() && isNonEmptyString(request.resource.data.prospectId, 1, 100);
  allow update: if false;
  allow delete: if false;
}
```

Cloud Functions server-side verification:
- Added collection bindings in [`functions/src/config/firebase.config.ts`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/functions/src/config/firebase.config.ts).
- Added `AIRequestValidator.verifyProspectOwnershipInFirestore(prospectId, callerUid)` in [`functions/src/validators/ai_request_validator.ts`](file:///Users/jiaxianlim/Downloads/PropMatch%20AI/functions/src/validators/ai_request_validator.ts).

---

## 6. Data Source Adapters & Malaysian Registry

Built modular adapters in `lib/services/prospect_sources/`:
- **`PropertyPortalAdapter`**: Standardized ingestion interface for Malaysian portals (iProperty, PropertyGuru, EdgeProp).
- **`PartnerAgencyAdapter`**: Agency network co-broke alliance feeds adhering to MIEA guidelines.
- **`DeveloperAdapter`**: Direct showroom registration desk integrations with physical slip verification flags.
- **`CRMImportAdapter`**: CSV & JSON parsing engine with automatic column mapping, validation, and sample Malaysian real estate templates.
- **`ProspectSourceRegistry`**: Central channel manager providing default feeds for Malaysian property agents.

---

## 7. Web Dashboard UI (`BuyerIntelligenceScreen`)

Added a dedicated SaaS workspace screen accessible via the sidebar navigation item **Buyer Intelligence** (`NavItem.buyerIntelligence`):

1. **Header Row**:
   - Title, real-time filtered counts, and clear `DEMO` badges.
   - Action buttons: `Import CSV`, `Generate Demo Data` (15 Malaysian profiles with realistic budgets, Penang/KL/Selangor locations, masked ICs), and `Purge Demo`.
2. **5 KPI Metrics Cards**:
   - `Total Prospects`: Entire top-of-funnel pipeline.
   - `Newly Discovered`: Recent entries awaiting review.
   - `Verified Profiles`: Authenticated phone/email/NRIC.
   - `Contact Eligible`: Highlighted in green with PDPA compliance check.
   - `Qualified Prospects`: Ready for CRM conversion.
3. **Multi-Dimensional Filter Bar**:
   - Live search (Name, Phone, Email, Location).
   - Dropdown filters for Status, Contact Eligibility, Verification Status, and Primary Source.
   - One-click `Clear Filters`.
4. **Prospect Data Table**:
   - High-density responsive web table with status chips, verification badges, masked ICs, and confidence meters.
5. **Prospect Inspector Dialog**:
   - Unmaskable IC toggle (with authorization check).
   - Prominent PDPA Legal Notice Banner.
   - Interactive **Record PDPA Consent** dialog (Scope, Source, Evidence input).
   - Immutable Consent Audit Trail.
   - Reverse-chronological Activity History timeline.
   - Direct action: **Convert to Active Buyer CRM**.
6. **CSV Import Modal**:
   - Pre-populated Malaysian CSV template with live validation counter.

---

## 8. Verification & Test Results

### 1. Flutter Code Analysis
```bash
flutter analyze
```
**Result**: `No issues found! (ran in 1.9s)`

### 2. Phase 4.1 Focused Test Suite
```bash
flutter test test/phase4_1_buyer_intelligence_test.dart
```
**Result**: `00:02 +15: All tests passed!`  
Covering models, serialization, CSV parsing, strict `Pending Consent` defaults, repository agent isolation, consent promotion/withdrawal, CRM promotion isolation, and widget rendering.

### 3. Full Project Test Suite
```bash
flutter test
```
**Result**: `00:11 +100: All tests passed!`  
All 100 automated unit, repository, provider, and widget tests across the entire application passed with zero regressions.

### 4. Cloud Functions Backend Tests
```bash
npm test --prefix functions -- --runInBand
```
**Result**: `7 passed, 7 total (56 passed, 56 total)`

### 5. Flutter Web Release Build
```bash
flutter build web --release
```
**Result**: `✓ Built build/web in 20.7s`

---

## 9. Conclusion & Next Steps

Phase 4.1 establishes a clean, legally sound, and scalable data foundation for PropMatch AI. The system is now primed for Phase 4.2 (External Portal Integrations & Automated Ingestion Pipelines) and Phase 4.3 (AI Prospect Profiling & Predictive Intent Scoring).
