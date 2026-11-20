# PropMatch AI — Phase 4.2.1: CRM Import Security & Reliability Audit Report

**Audit Date:** November 20, 2026  
**Target Firebase Project:** `property-71665` (Local / Emulated Verification — No Production Deployments Executed)  
**Target Platform:** Flutter Web (`android/` and `ios/` preserved untouched)  
**Audit Scope:** Comprehensive security, reliability, parsing, consent scoping, multi-tenant isolation, and privacy audit of the Phase 4.2 CRM Import Engine.

---

## 1. Files Reviewed

| Layer | File Path | Purpose Reviewed |
| :--- | :--- | :--- |
| **Frontend Parsing** | `lib/services/crm_import/file_parser.dart` | XLSX OpenXML decoding, multi-worksheet handling, CSV/TSV state-machine parsing, BOM stripping, magic-byte & size validation |
| **Frontend Normalization** | `lib/services/crm_import/normalizer.dart` | Malaysian E.164 phone canonicalization, email validation, Ringgit budget range parsing, state inference, NRIC scrubbing |
| **Column Mapping** | `lib/services/crm_import/column_mapping.dart` | Two-pass heuristic header matching, required field validation |
| **Consent Engine** | `lib/services/crm_import/consent_mapper.dart` | Purpose and channel scoping, generic opt-in quarantine, opt-out handling, deterministic consent IDs |
| **Deduplication** | `lib/services/crm_import/duplicate_detector.dart` | Agent-scoped phone/email indexing across prospects and CRM buyers, intra-file duplicate detection |
| **Validation & Audit CSV** | `lib/services/crm_import/import_validator.dart` | Pre-import validation, deterministic prospect ID generation, verification separation, PII masking in error reports |
| **Batch Ingestion** | `lib/services/crm_import/batch_importer.dart` | Live re-deduplication, concurrency locking, idempotent job replay, consent precedence on merge |
| **Repositories** | `lib/repositories/prospect_repository.dart`<br>`lib/repositories/firestore_prospect_repository.dart` | Owner-scoped queries, idempotent upserts, Firestore 450-operation `WriteBatch` chunking |
| **Domain Models** | `lib/models/prospect_model.dart`<br>`lib/models/prospect_consent_event_model.dart`<br>`lib/models/prospect_import_job_model.dart` | Purpose/channel consent fields, `canContact` enforcement, job metadata sanitization |
| **State Management & UI** | `lib/providers/app_state_provider.dart`<br>`lib/screens/prospects/crm_import/crm_import_wizard_dialog.dart`<br>`lib/screens/prospects/buyer_intelligence_screen.dart` | Consent state transitions, volatile memory cleanup, data minimization in sample templates |
| **Cloud Functions Backend** | `functions/src/services/prospect_import_service.ts`<br>`functions/src/index.ts`<br>`functions/src/utils/logger.ts` | Server-side auth, 5MB limit, IDOR prevention on `jobId`, batch chunking, log PII redaction |
| **Security Rules** | `firestore.rules` | Collection-level ownership checks and append-only immutability on `prospect_consents` and `prospect_activities` |

---

## 2. Audit Findings, Severity & Fixes Implemented

### Summary of Findings

| ID | Category | Finding Title | Severity | Status |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | Backend Security | Cross-Tenant `jobId` Overwrite (IDOR) via Firebase Admin SDK in `importProspectsBatch` | **CRITICAL** | **Fixed** |
| **F-02** | Batch Reliability | Unchunked Firestore `WriteBatch` Exceeding 500-Operation Hard Limit on Large Imports | **CRITICAL** | **Fixed** |
| **F-03** | Privacy & PII | Unmasked Phone Numbers, Emails, and Names Leaked in `Issues` Column of Error Report CSV | **CRITICAL** | **Fixed** |
| **F-04** | Consent & Eligibility | Duplicate Merge Could Overwrite `Do Not Contact` (Withdrawn Consent) Status | **CRITICAL** | **Fixed** |
| **F-05** | Parsing Integrity | Blank Intermediate Header Columns (`Name,,Phone`) Shifted Positional Column Indices | **HIGH** | **Fixed** |
| **F-06** | Duplicate Detection | Invalid/Placeholder Contact Values (`N/A`, `-`) Indexed as Canonical Keys Causing False Intra-File Duplicates | **HIGH** | **Fixed** |
| **F-07** | Batch Reliability | Retrying or Re-executing an Import Created Duplicate Prospects & Duplicate Consent Events | **HIGH** | **Fixed** |
| **F-08** | Consent & Verification | Syntactically Valid Phone/Email Was Auto-Marked as `'Phone Verified'` and Broad Marketing Was Not Separated from Direct Inquiry Consent | **HIGH** | **Fixed** |
| **F-09** | Repository Security | `getConsentsForProspect` & `getActivitiesForProspect` Lacked `ownerId` Filter Constraint Required by Firestore Rules | **HIGH** | **Fixed** |
| **F-10** | Parsing & Normalizer | Character-Class Regex `[-–—TOto]` Split `"RM 1.2 Million"` on Letter `'O'`, and Excel Float Phones (`123456789.0`) Appended Trailing `'0'` | **MEDIUM** | **Fixed** |
| **F-11** | Backend Validation | 5MB File/Payload Size Limit Was Not Enforced Server-Side in `importProspectsBatch` | **MEDIUM** | **Fixed** |
| **F-12** | Data Minimization | Sample Demo CSV Contained `IC Number` Column and Free-Text Notes Were Not Scrubbed for Accidental NRIC Numbers | **MEDIUM** | **Fixed** |

---

### Detailed Breakdown of Bugs Discovered & Fixes

#### F-01 (CRITICAL): Cross-Tenant `jobId` Overwrite (IDOR) via Admin SDK
- **Discovery:** In `functions/src/services/prospect_import_service.ts`, the backend used the Firebase Admin SDK (which bypasses `firestore.rules`) and wrote directly to `collections.prospectImportJobs.doc(effectiveJobId)` without first reading the document to verify whether `effectiveJobId` already existed under another agent's `ownerId`.
- **Fix:** Added pre-execution authorization and format validation on `jobId`. Before processing, `ProspectImportService.validateAndProcessBatch` queries `jobRef.get()` (and checks the in-memory job cache). If the job belongs to a different `ownerId`, it throws `HttpsError("permission-denied", "Unauthorized access to an import job belonging to another agent.")`.

#### F-02 (CRITICAL): Firestore 500-Write Batch Limit Exceeded on Large Imports
- **Discovery:** Both `ProspectImportService.validateAndProcessBatch` (backend) and `FirestoreProspectRepository.saveBulkProspects` (frontend) placed all write operations into a single `firestore.batch()`. Because each imported prospect on the backend generates up to 3 writes (prospect + activity + consent event) plus 1 job write, importing 500 candidates queued up to 1,501 operations in a single batch — exceeding Firestore's hard limit of 500 operations per `WriteBatch`.
- **Fix:** Implemented batch chunking (`MAX_FIRESTORE_BATCH_OPS = 450`) in both `ProspectImportService` and `FirestoreProspectRepository` (`saveBulkProspects`, `recordBulkConsentEvents`, `recordBulkActivities`, `deleteDemoProspects`). Large imports are now committed across multiple safe chunks of at most 450 operations per batch.

#### F-03 (CRITICAL): Unmasked PII Leaked in Downloadable Error Report CSV
- **Discovery:** In `ImportPreviewReport.generateErrorReportCsv()`, while columns 4 and 5 masked the candidate's phone and email:
  1. When a row was `invalid` (`r.candidate == null`), `r.candidate?.phone` evaluated to `null` instead of masking `r.rawValues['phone']`.
  2. `r.duplicateInfo.matchedField` previously formatted strings as `'Phone (+60123456789)'` and `'Email (user@example.com)'`, which were appended directly into the `Issues` column of the CSV in plain text.
  3. `Candidate Name` was exported unmasked.
- **Fix:** Updated `CRMDuplicateDetector` to omit raw PII from `matchedField`, updated `generateErrorReportCsv()` to mask `Candidate Name` (`A***d F***z`), fallback to and mask `r.rawValues['phone']` and `r.rawValues['email']` when `r.candidate == null`, and added `_scrubPiiFromIssues()` to redact any embedded phone, email, or NRIC patterns from the `Issues` text.

#### F-04 (CRITICAL): Duplicate Merge Could Overwrite `Do Not Contact` Status
- **Discovery:** `CRMBatchImporter._mergeProspect` previously merged demographic and budget fields without enforcing consent withdrawal precedence. If an existing prospect had `contactEligibility == 'Do Not Contact'`, or if an incoming duplicate row carried an opt-out signal (`'Do Not Contact'`), merging did not enforce that `'Do Not Contact'` takes strict precedence.
- **Fix:** Updated `_mergeProspect` in both `CRMBatchImporter` (frontend) and `ProspectImportService` (backend) so that if either the existing record or incoming record is `'Do Not Contact'`, the merged record strictly remains `'Do Not Contact'` with cleared `consentedPurposes` and `consentedChannels`, and any incoming `Withdrawn` consent event is recorded in the audit log.

#### F-05 (HIGH): Blank Intermediate Header Columns Shifted Column Indices
- **Discovery:** `CRMFileParser._parseCsv` and `_parseXlsx` previously filtered headers using `.where((h) => h.isNotEmpty).toList()`. If a file had an empty intermediate header (e.g. `Full Name,,Phone Number`), `'Phone Number'` shifted to index `1` in `headers` while remaining at index `2` in `dataRows`, misaligning all subsequent columns. Additionally, UTF-8 BOM (`\uFEFF`) at the start of Excel CSV exports remained attached to the first header.
- **Fix:** Added UTF-8 BOM stripping and `_normalizeHeadersPreservingPositions()`, which assigns placeholder names (`Column_2`, etc.) to blank intermediate header columns while trimming trailing empty columns, and pads short data rows via `_normalizeRowLength()`. Also improved `_parseXlsx` to scan multiple worksheets and select the first sheet containing valid headers and data rows, while wrapping `Excel.decodeBytes` in a `try/catch` to cleanly reject malformed zip files.

#### F-06 (HIGH): Invalid/Placeholder Contact Values Indexed as Duplicate Keys
- **Discovery:** When two rows contained invalid or placeholder emails/phones (such as `'N/A'` or `'invalid'`), `normalizeEmail` / `normalizePhone` returned `isValid: false` with a non-empty `canonical` string. `checkDuplicate` checked `canonicalEmail.isNotEmpty` without verifying `isValid`, causing subsequent rows with `'N/A'` to be falsely flagged as intra-file duplicates.
- **Fix:** Updated `CRMDataNormalizer`, `CRMDuplicateDetector`, `CRMImportValidator`, and backend `ProspectImportService` so that only valid canonical phone numbers (`normPhone.isValid`) and valid canonical emails (`normEmail.isValid`) are indexed or compared for duplicate detection. Also required every imported row to have at least one *valid* contact identifier (phone or email).

#### F-07 (HIGH): Idempotency on Retry / Repeated Import Execution & Concurrency Locking
- **Discovery:** Candidate IDs (`pros-imp-${DateTime.now().millisecondsSinceEpoch}-$i`) were non-deterministic across retries, and `CRMBatchImporter.executeImport` relied only on preview-time duplicate flags without re-checking the live repository or locking concurrent executions.
- **Fix:**
  - Implemented deterministic prospect IDs (`_generateDeterministicProspectId`), deterministic consent event IDs (`cst-$prospectId`), and deterministic activity IDs (`act-imp-$prospectId`).
  - Added concurrency locks (`_inFlightOwnerLocks` on frontend, `inFlightJobs` on backend) and completed job replay detection (`completedJobs` / `getImportJobs`).
  - Added live repository re-deduplication inside `CRMBatchImporter.executeImport` and idempotent upserts in `InMemoryProspectRepository` (`saveBulkProspects`, `recordConsentEvent`, `recordActivity`).

#### F-08 (HIGH): Separation of Verification from Contact Eligibility & Purpose/Channel Scoping
- **Discovery:**
  1. `CRMImportValidator` and `ProspectImportService` previously set `verificationStatus: normPhone.isValid ? 'Phone Verified' : ...`, conflating regex syntax validation with actual phone/identity verification.
  2. `_isOptIn` and `_isOptOut` missed space/hyphen variants (`'opted in'`, `'opted out'`).
  3. Every `'Granted'` consent event was treated identically without distinguishing `'Direct Inquiry Response'` from `'Marketing & Promotion'` or `'Third-Party Sharing'`, or tracking communication channels.
- **Fix:**
  - All imported prospects now strictly initialize with `verificationStatus: 'Unverified'`.
  - Added `purpose` and `communicationChannels` to `ProspectConsentEventModel` and `consentedPurposes` / `consentedChannels` / `canContact({purpose, channel})` / `isEligibleForMarketing` to `ProspectModel`.
  - `'Direct Inquiry Response'` consent authorizes inquiry follow-up on the consented channel (`isEligibleForInquiryResponse == true`), while `isEligibleForMarketing` and `canContact(purpose: 'Marketing & Promotion')` remain `false` unless explicit `'Marketing & Promotion'` consent is granted.
  - `'Third-Party Sharing'` consent alone does not promote `contactEligibility` to `'Eligible'`.

#### F-09 (HIGH): Owner-Scoping on Consent and Activity Queries
- **Discovery:** `FirestoreProspectRepository.getConsentsForProspect` and `getActivitiesForProspect` queried by `prospectId` without `.where('ownerId', isEqualTo: ownerId)`. Under `firestore.rules` (`allow read: if isResourceOwner()`), Firestore rejects collection queries that omit the `ownerId` equality filter.
- **Fix:** Added `{String? ownerId}` parameter to `getConsentsForProspect`, `getActivitiesForProspect`, `getProspectById`, and `deleteProspect`, chaining `.where('ownerId', isEqualTo: ownerId)` and passing `ownerId: currentOwnerId` from `AppStateProvider`.

#### F-10, F-11, F-12 (MEDIUM): Budget Range Regex, Excel Float Phones, Server 5MB Limit & Data Minimization
- **Fixes:**
  - Replaced character-class regex `RegExp(r'[-–—TOto]')` (which split `"1.2 MILLION"` on the letter `'O'`) with `RegExp(r'\s*(?:[-–—~]|\bTO\b)\s*', caseSensitive: false)`.
  - Stripped trailing `.0` from Excel floating-point phone cell strings (`123456789.0` -> `+60123456789`) and handled redundant trunk `0` after country code (`+60 (0)12-3456789` -> `+60123456789`).
  - Added server-side 5MB enforcement (`MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024`) in `ProspectImportService.validateAndProcessBatch`.
  - Removed `IC Number` from `_malaysianSampleCsv`, set `icNumber: null` on all CRM imports, added `scrubSensitiveIdentifiers()` to redact NRIC patterns (`\b\d{6}-\d{2}-\d{4}\b`) from free-text notes and backend logs, and cleared volatile file memory (`_parsedTable = null; _pasteTextController.clear()`) after import completion and dialog disposal.

---

## 3. Security and Privacy Limitations

1. **Technical Controls vs. Legal Compliance:**
   - The consent classification, purpose/channel scoping, audit logging, and PII masking implemented in PropMatch AI are **technical enforcement controls** designed to assist property agents in managing prospect data responsibly. They do **not** constitute formal legal certification under the Malaysian Personal Data Protection Act (PDPA) 2010. Individual property agents and agencies remain legally responsible for verifying the authenticity of physical/digital consent records before initiating outreach.
2. **Client-Side vs. Server-Side Deduplication Window:**
   - In the Flutter Web client flow, duplicate detection indexes the agent's loaded prospects and buyers in memory and re-verifies against the repository at batch execution time. If an agent has tens of thousands of historical prospects, client-side full-collection loading should eventually transition to server-side hashed contact-key lookups via `importProspectsBatch`.
3. **Chunked Multi-Batch Atomicity in Firestore:**
   - Because Cloud Firestore limits a single `WriteBatch` or transaction to 500 document operations, imports exceeding 450 operations are committed across sequential chunks of 450 operations. If a network interruption occurs between chunk 1 and chunk 2, chunk 1 remains committed. However, because candidate IDs, consent event IDs, and activity IDs are now deterministic, re-running the import safely resumes and converges idempotently without duplicating records from chunk 1.

---

## 4. Automated Verification & Test Results

All five mandatory verification suites were executed and passed with zero errors:

1. **Flutter Static Analysis (`flutter analyze`)**:
   - **Result:** `No issues found! (ran in 2.0s)`
2. **Flutter Automated Test Suite (`flutter test`)**:
   - **Phase 4.2 & 4.2.1 CRM Import Suite (`test/phase4_2_crm_import_test.dart`):** `27 passed, 0 failed`
   - **Full Application Regression Suite (15 test files):** `127 passed, 0 failed`
3. **Cloud Functions TypeScript Compilation (`npm run build --prefix functions`)**:
   - **Result:** `tsc` exited with code `0` (0 errors).
4. **Cloud Functions Jest Unit & Security Test Suite (`npm test --prefix functions -- --runInBand`)**:
   - **Result:** `8 passed, 8 total test suites` | `67 passed, 67 total tests` (including 11 backend CRM import security, normalization, consent scoping, IDOR protection, idempotency, and batch chunking tests).
5. **Flutter Web Production Release Build (`flutter build web --release`)**:
   - **Result:** Succeeded cleanly (`✓ Built build/web`).

---

## 5. Remaining Production Blockers (Pre-Go-Live Checklist)

Before deploying to live production in a future release phase:
1. **Firebase App Check Enforcement:** `enforceAppCheck` in `functions/src/index.ts` is currently `false` for local emulator compatibility and must be enabled (`true`) once the production reCAPTCHA Enterprise site key is provisioned.
2. **Firestore Composite Indexes:** Production deployment of `prospect_consents` and `prospect_activities` queries filtering by `ownerId` + `prospectId` will require composite indexes in `firestore.indexes.json` when deployed to live Firebase.
3. **Production Rules & Functions Deployment:** In accordance with project constraints, `firestore.rules` and `functions` have been verified locally and have **not** been deployed to `property-71665`.
