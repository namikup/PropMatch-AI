# PropMatch AI — Phase 4.2: CRM Import Engine Implementation Report

**Date:** November 20, 2026  
**Target Environment:** Firebase Project `property-71665` (Local / Emulated Verification)  
**Target Platform:** Flutter Web (Single-Page Application)  
**Status:** Completed & Fully Verified  

---

## 1. Executive Summary

Phase 4.2 delivers a production-grade, multi-format **CRM Import Engine** for PropMatch AI, empowering Malaysian real estate negotiators (RENs) and agents to ingest their existing buyer enquiry records from diverse external CRM exports into their private, agent-scoped **Prospect Database**.

The engine adheres strictly to the **Personal Data Protection Act (PDPA) 2010 of Malaysia**:
- **Strict Opt-In Default:** All newly imported records default to `Pending Consent` and are marked **Contact Ineligible**.
- **Evidence-Based Verification:** Generic boolean markers (e.g. `opt_in = true`) without documented evidence remain quarantined under `Pending Consent` with a compliance warning.
- **Opt-Out Protection:** Explicit opt-out signals automatically map to `Do Not Contact` and log immutable `Withdrawn` consent events.
- **Agent Data Isolation:** All duplicate checks and record merges are strictly scoped to `ownerId == currentAgentUid`. Cross-tenant data leakage is structurally impossible.
- **Privacy-Compliant Audit Reporting:** Ingestion error logs mask phone numbers and email addresses (`+6012****89`, `a***z@gmail.com`) to protect personal identifiable information (PII).

---

## 2. Audit of Previous CSV Implementation vs. Phase 4.2 Engine

| Feature / Capability | Previous `CRMImportAdapter` | Phase 4.2 CRM Import Engine |
| :--- | :--- | :--- |
| **Input Ingestion** | Simple text-field copy/paste only | Real file picker (`.csv`, `.tsv`, `.xlsx`) up to 5MB + Raw text paste tab |
| **File Verification** | None; string splitting only | Byte-level inspection, OpenXML zip magic byte validation (`PK\x03\x04`), binary null-byte rejection |
| **Excel (.xlsx) Support** | Not supported | Full OpenXML workbook decoding via `excel` and `archive` |
| **Column Mapping** | Hardcoded positional comma splitting | Heuristic auto-mapping matching Malaysian CRM aliases + interactive visual mapping UI |
| **Data Normalization** | Raw string passthrough | Malaysian phone canonicalization to E.164 (`+601xxxxxxxx`), RFC email validation, Ringgit currency parsing (`RM`, `k`, `M`), location-to-state inferencing |
| **Duplicate Detection** | None | Agent-scoped phone/email indexing against existing prospects and CRM buyers, intra-batch duplicate detection |
| **Deduplication Strategy** | Not available | Configurable strategies: `Skip Duplicates (Default)`, `Merge with Existing Record`, `Import Anyway` |
| **PDPA Consent Handling** | Text disclaimer banner only | Multi-tier consent mapper, evidence requirement, audit trail creation via `ProspectConsentEventModel` |
| **Pre-Import Preview** | None; immediate blind save | Filterable preview table (`All`, `Valid`, `Duplicates`, `Warnings`, `Errors`) with real-time KPI metrics |
| **Batch Job Audit History**| Unrecorded; direct loop creation | Immutable `ProspectImportJobModel` tracking row counts, errors, duration, and audit references |
| **Error / Audit Export** | None | Downloadable privacy-masked CSV audit report + Clipboard copy option |
| **Cloud Functions Backend** | None | Callable Cloud Function `importProspectsBatch` with TypeScript schema validation and atomic writes |

---

## 3. Architecture & Key Deliverables

### 3.1 Frontend Services (`lib/services/crm_import/`)

1. **`file_parser.dart` (`CRMFileParser`)**:
   - Enforces a 5 MB file size limit to preserve web browser memory stability.
   - Inspects binary magic bytes for `.xlsx` (`0x50, 0x4B, 0x03, 0x04`) to prevent corrupted or malicious binary uploads.
   - Rejects text files containing illegal binary null characters.
   - Quote-aware CSV/TSV parser supporting multiline cells, escaped double quotes (`""`), and custom delimiters.
   - Decodes OpenXML sheets into normalized `ParsedTable` models.

2. **`normalizer.dart` (`CRMDataNormalizer`)**:
   - Canonicalizes Malaysian mobile prefixes (`010`, `011`, `012`, `013`, `014`, `015`, `016`, `017`, `018`, `019`, `601...`, `+601...`) into standard E.164 (`+601xxxxxxxx`).
   - Distinguishes Malaysian mobile numbers from fixed landlines (`03`, `04`, `05`, `06`, `07`, `08`, `09`).
   - Normalizes email addresses (lowercasing, trimming, RFC-compliant syntax verification).
   - Parses Ringgit budget strings (e.g., `'RM 650,000'`, `'RM 1.2M'`, `'850k'`, range expressions `'600k - 800k'`).
   - Automatically infers Malaysian states from prominent townships (Mont Kiara -> Kuala Lumpur, Petaling Jaya -> Selangor, Bayan Lepas -> Penang, Johor Bahru -> Johor, Kuching -> Sarawak, Kota Kinabalu -> Sabah).

3. **`column_mapping.dart` (`ColumnMappingConfig` & `CRMColumnMappingRegistry`)**:
   - Manages target fields: `fullName` (mandatory), `phone`, `email`, `budgetMin`, `budgetMax`, `preferredLocation`, `preferredState`, `propertyType`, `purchasePurpose`, `buyingTimeline`, `sourceReference`, `consentStatus`, `consentEvidence`, `notes`.
   - Employs a **Two-Pass Heuristic Matching Algorithm**:
     - *Pass 1:* Exact match against extensive aliases (e.g. `Client Name`, `Mobile Phone`, `Consent Notes`).
     - *Pass 2:* Prefix/suffix matching for remaining unmapped headers.

4. **`consent_mapper.dart` (`CRMConsentMapper`)**:
   - Enforces Malaysian PDPA 2010 consent rules:
     - Missing consent -> Defaults to `Pending Consent` (Contact Ineligible).
     - Generic boolean (`true`, `yes`, `1`) without verifiable evidence -> Quarantined under `Pending Consent` with a compliance warning flag.
     - Documented consent (e.g., showroom register number, signed enquiry form, timestamped WhatsApp inquiry) -> Promotes to `Eligible` and generates a `ProspectConsentEventModel` (`status: 'Granted'`).
     - Opt-out signal (`opt_out`, `withdrawn`, `dnc`) -> Sets `Do Not Contact` and generates a `ProspectConsentEventModel` (`status: 'Withdrawn'`).

5. **`duplicate_detector.dart` (`CRMDuplicateDetector`)**:
   - Strictly scopes in-memory indexing to `record.ownerId == currentOwnerId`.
   - Evaluates incoming candidates against existing prospects and active CRM buyers using canonical phone numbers and emails.
   - Detects intra-batch duplicates occurring within the uploaded file itself.
   - Supports resolution strategies: `Skip`, `Merge`, and `ImportAnyway`.

6. **`import_validator.dart` (`CRMImportValidator`)**:
   - Performs row-by-row pre-import validation.
   - Categorizes rows into `RowValidationStatus`: `valid`, `warning`, `duplicate`, `invalid`.
   - Generates summary KPI metrics (`totalRows`, `validCount`, `warningCount`, `duplicateCount`, `invalidCount`).
   - Produces a privacy-masked CSV error report (`+6012****89`, `a***z@gmail.com`).

7. **`batch_importer.dart` (`CRMBatchImporter`)**:
   - Executes persistent batch ingestion into `ProspectRepository`.
   - Implements field-level merge logic to enrich existing prospect profiles while preserving their immutable IDs and creation timestamps.
   - Records audit activities in `ProspectActivityModel` and creates an audit job in `ProspectImportJobModel`.
   - Emits real-time progress updates (`BatchImportProgress`).

8. **`report_downloader.dart` (`CRMReportDownloader`)**:
   - Platform-safe file downloader utilizing conditional imports (`report_downloader_web.dart` for browser downloads, `report_downloader_stub.dart` for headless VM tests).

---

### 3.2 UI Modal Wizard (`lib/screens/prospects/crm_import/crm_import_wizard_dialog.dart`)

The wizard provides a 4-step workflow:
1. **Step 1: File Upload & Input**:
   - Mode switcher: *Upload File (.csv, .tsv, .xlsx)* vs. *Paste Raw Text / Demo Data*.
   - Drag-and-drop or click-to-browse file picker.
   - "Load Malaysian Demo Leads" one-click button populated with representative Malaysian property leads.
   - File summary badge displaying format, size, column count, and row count.
2. **Step 2: Column Mapping**:
   - Target field metadata cards with "REQUIRED" badges.
   - Auto-detected column dropdown selectors with responsive layout (`isExpanded: true`).
   - Sample value preview extracted from row 1 of the uploaded dataset.
   - Reset button to re-run auto-detection heuristics.
3. **Step 3: Preview & Deduplication**:
   - Real-time KPI summary banner: Total, Valid, Duplicates, Warnings, Errors.
   - Duplicate Resolution Strategy selector: `Skip`, `Merge`, `Import Anyway`.
   - Filterable preview tabs: `All`, `Valid`, `Duplicates`, `Warnings`, `Errors`.
   - Scrollable row preview with Contact Eligibility badges (`Consent Verified`, `Pending Consent`, `Do Not Contact`).
4. **Step 4: Batch Ingestion & Results**:
   - Animated progress bar during batch processing.
   - Completion card detailing: Imported count, Merged count, Skipped duplicates, Failed rows.
   - Audit job reference ID badge.
   - Malaysian PDPA compliance legal notice.
   - Downloadable Privacy-Masked Audit Report (CSV) + Copy to Clipboard actions.
   - "View Prospect Database" exit action.

---

### 3.3 Backend Cloud Function (`functions/src/services/prospect_import_service.ts`)

- Implemented `ProspectImportService` with:
  - Phone normalization to `+601xxxxxxxx`.
  - Email normalization and syntax validation.
  - Multi-tenant verification (`candidate.ownerId === callerUid`).
  - PDPA consent mapping.
  - Chunked atomic Firestore batch writes (500 operations per batch).
  - Job audit history persistence in `prospect_import_jobs`.
- Exported callable Cloud Function: `importProspectsBatch`.

---

## 4. Verification & Testing

### 4.1 Cloud Functions TypeScript Build & Jest Suite
- **TypeScript Compiler (`tsc`):** Clean compilation, 0 errors.
- **Jest Test Suite:**
  ```text
  Test Suites: 8 passed, 8 total
  Tests:       62 passed, 62 total
  Snapshots:   0 total
  Time:        3.007 s
  ```

### 4.2 Flutter Code Analysis
- **Command:** `flutter analyze`
- **Result:**
  ```text
  Analyzing PropMatch AI...
  No issues found! (ran in 2.5s)
  ```

### 4.3 Phase 4.2 Test Suite (`test/phase4_2_crm_import_test.dart`)
- **Command:** `flutter test test/phase4_2_crm_import_test.dart`
- **Test Results:** **24 passed, 0 failed (100% pass rate)**.
  - CRM File Parser (rejection of empty files, 5MB limit, unsupported extensions, corrupted XLSX magic bytes; parsing of CSV quotes/newlines and TSV).
  - Malaysian Data Normalizer (phone canonicalization to E.164, email syntax, Ringgit budget expressions, state inferencing).
  - Column Mapping & Auto-detection (heuristic alias matching, required field enforcement).
  - Duplicate Detection & Multi-Tenant Isolation (cross-agent isolation, phone/email matching, intra-batch duplicate detection).
  - Malaysian PDPA 2010 Consent Mapping (strict default, generic marker quarantine, documented evidence verification, opt-out handling).
  - CRM Import Validator & Privacy-Masked Error Reporting.
  - Batch Importer & Ingestion Execution (merge/skip strategies, job persistence).
  - CRM Import Wizard UI Flow Widget Tests (step 1 through step 4 end-to-end user journey).

### 4.4 Full Application Regression Test Suite
- **Command:** `flutter test`
- **Test Results:** **124 passed, 0 failed across all 15 test files**.

### 4.5 Flutter Web Production Release Build
- **Command:** `flutter build web --release`
- **Result:**
  ```text
  Compiling lib/main.dart for the Web...                             20.6s
  ✓ Built build/web
  ```

---

## 5. Security & Compliance Checklist

- [x] **Malaysian PDPA 2010 Compliance:** Default contact eligibility is strictly `Pending Consent`. No automated outreach can occur without verified consent evidence.
- [x] **Tenant Isolation:** Agents cannot detect, view, match, or merge prospects belonging to other agents.
- [x] **File Upload Security:** 5 MB ceiling prevents browser OOM; OpenXML binary magic bytes prevent disguised executables; binary null bytes in CSVs are rejected.
- [x] **Privacy-Masked Error Reports:** Exported logs mask phone numbers and email usernames.
- [x] **Zero Production Deployments:** Cloud Functions and Firestore rules were built and tested in emulated/local verification suites only. No production deployments were executed.
