import { HttpsError } from "firebase-functions/v2/https";
import { collections } from "../config/firebase.config";
import { Logger } from "../utils/logger";

export interface RawImportCandidate {
  fullName: string;
  phone?: string;
  email?: string;
  preferredLocations?: string[];
  preferredState?: string;
  propertyTypes?: string[];
  budgetMin?: number;
  budgetMax?: number;
  purchasePurpose?: string;
  buyingTimeline?: string;
  sourceReference?: string;
  consentStatus?: string;
  consentEvidence?: string;
  notes?: string;
  [key: string]: unknown;
}

export interface ValidatedProspectRecord {
  id: string;
  ownerId: string;
  fullName: string;
  phone: string;
  email: string;
  preferredLocations: string[];
  preferredState: string;
  propertyTypes: string[];
  budgetMin: number;
  budgetMax: number;
  purchasePurpose: string;
  buyingTimeline: string;
  status: string;
  verificationStatus: string;
  contactEligibility: string;
  consentedPurposes: string[];
  consentedChannels: string[];
  primarySource: string;
  confidenceScore: number;
  notes: string;
  isDemo: boolean;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  consentEvent?: {
    id: string;
    ownerId: string;
    prospectId: string;
    consentType: string;
    purpose: string;
    communicationChannels: string[];
    status: string;
    source: string;
    evidenceText: string;
    consentTimestamp: string;
    withdrawalTimestamp?: string;
  };
}

export interface ImportBatchResponse {
  jobId: string;
  totalRows: number;
  importedCount: number;
  mergedCount?: number;
  skippedDuplicatesCount: number;
  errorCount: number;
  errors: { rowIndex: number; error: string }[];
  importedIds: string[];
  batchesCommitted?: number;
}

const GENERIC_EVIDENCE_PLACEHOLDERS = new Set([
  "yes",
  "true",
  "ok",
  "consent",
  "consented",
  "agreed",
  "agree",
  "opt in",
  "opted in",
  "opt-in",
  "opt_in",
  "granted",
  "checked",
  "ticked",
  "verified",
  "approved",
  "default",
  "imported",
  "n/a",
  "na",
  "none",
  "nil",
  "1",
  "y"
]);

export class ProspectImportService {
  static readonly MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB limit
  static readonly MAX_CANDIDATES_PER_BATCH = 500;
  static readonly MAX_FIRESTORE_BATCH_OPS = 450; // Safely below Firestore's 500-op hard limit

  private static completedJobs = new Map<string, { ownerId: string; response: ImportBatchResponse }>();
  private static inFlightJobs = new Set<string>();

  /**
   * Clears in-memory job cache (used for isolated testing).
   */
  static resetJobCache(): void {
    this.completedJobs.clear();
    this.inFlightJobs.clear();
  }

  /**
   * Normalizes a Malaysian contact number into standard canonical E.164-compatible format: +601xxxxxxxx
   */
  static normalizePhone(raw?: string): { canonical: string; isValid: boolean } {
    if (!raw || typeof raw !== "string") return { canonical: "", isValid: false };
    let trimmed = raw.trim();
    if (/^\d+\.0+$/.test(trimmed)) {
      trimmed = trimmed.split(".")[0];
    }
    const digits = trimmed.replace(/\D/g, "");
    if (!digits) return { canonical: "", isValid: false };

    let canonical: string;
    if (digits.startsWith("00600") && digits.length >= 13) {
      canonical = `+60${digits.substring(5)}`;
    } else if (digits.startsWith("0060")) {
      canonical = `+60${digits.substring(4)}`;
    } else if (digits.startsWith("600") && digits.length >= 11) {
      canonical = `+60${digits.substring(3)}`;
    } else if (digits.startsWith("60") && digits.length >= 10) {
      canonical = `+${digits}`;
    } else if (digits.startsWith("0")) {
      canonical = `+60${digits.substring(1)}`;
    } else if (digits.length === 8 || digits.length === 9 || digits.length === 10) {
      canonical = `+60${digits}`;
    } else {
      canonical = `+${digits}`;
    }

    const afterPrefix = canonical.startsWith("+60") ? canonical.substring(3) : "";
    const isValid = canonical.startsWith("+60") && /^[1-9]\d{7,9}$/.test(afterPrefix);
    return { canonical, isValid };
  }

  /**
   * Normalizes an email address.
   */
  static normalizeEmail(raw?: string): { canonical: string; isValid: boolean } {
    if (!raw || typeof raw !== "string") return { canonical: "", isValid: false };
    const canonical = raw.trim().toLowerCase();
    const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(canonical);
    return { canonical, isValid };
  }

  /**
   * Scrubs accidental Malaysian NRIC patterns from free-text notes (Data Minimization).
   */
  static scrubSensitiveIdentifiers(text: string): string {
    if (!text) return "";
    return text.replace(/\b\d{6}-\d{2}-\d{4}\b/g, "[NRIC-REDACTED]");
  }

  /**
   * Validates raw candidate rows, checks for agent-scoped duplicates, and enforces consent & security rules.
   */
  static async validateAndProcessBatch(
    callerUid: string,
    candidates: RawImportCandidate[],
    duplicateStrategy: "skip" | "merge" | "importAnyway" = "skip",
    sourceFileName: string = "CRM_Import.csv",
    jobId?: string,
    fileSizeBytes?: number
  ): Promise<ImportBatchResponse> {
    // 1. Mandatory Authentication Check
    if (!callerUid || typeof callerUid !== "string" || callerUid.trim() === "") {
      throw new HttpsError("unauthenticated", "Authentication is required to import prospects.");
    }
    const authenticatedOwnerId = callerUid.trim();

    // 2. Validate Strategy & Source File Metadata
    if (!["skip", "merge", "importAnyway"].includes(duplicateStrategy)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid duplicateStrategy "${duplicateStrategy}". Must be "skip", "merge", or "importAnyway".`
      );
    }

    if (typeof fileSizeBytes === "number" && fileSizeBytes > this.MAX_FILE_SIZE_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Uploaded file size exceeds the maximum allowed limit of 5.0 MB."
      );
    }

    if (!Array.isArray(candidates) || candidates.length === 0) {
      throw new HttpsError("invalid-argument", "Candidates array cannot be empty.");
    }

    if (candidates.length > this.MAX_CANDIDATES_PER_BATCH) {
      throw new HttpsError(
        "invalid-argument",
        `Batch import exceeds limit of ${this.MAX_CANDIDATES_PER_BATCH} records per operation.`
      );
    }

    // 3. Enforce 5MB Server-Side Payload Limit
    const payloadByteLength = Buffer.byteLength(JSON.stringify(candidates), "utf8");
    if (payloadByteLength > this.MAX_FILE_SIZE_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Import payload size exceeds the maximum allowed limit of 5.0 MB."
      );
    }

    const sanitizedFileName = this.sanitizeFileName(sourceFileName);

    // 4. Validate & Authorize Job ID (Prevent IDOR / Cross-Tenant Job Overwrite & Concurrency Races)
    if (jobId !== undefined && jobId !== null) {
      if (typeof jobId !== "string" || jobId.trim() === "" || /[\/\\]/.test(jobId) || jobId.length > 100) {
        throw new HttpsError("invalid-argument", "Invalid jobId format.");
      }
    }
    const effectiveJobId = jobId ? jobId.trim() : `job-${Date.now()}`;

    if (this.inFlightJobs.has(effectiveJobId)) {
      throw new HttpsError("aborted", `Import job "${effectiveJobId}" is already currently executing.`);
    }

    // Check in-process completed cache
    const cachedJob = this.completedJobs.get(effectiveJobId);
    if (cachedJob) {
      if (cachedJob.ownerId !== authenticatedOwnerId) {
        throw new HttpsError(
          "permission-denied",
          "Unauthorized access to an import job belonging to another agent."
        );
      }
      return cachedJob.response;
    }

    // Check Firestore import job document via Admin SDK with explicit ownership check
    const jobRef = collections.prospectImportJobs.doc(effectiveJobId);
    const existingJobSnap = await jobRef.get();
    if (existingJobSnap && existingJobSnap.exists) {
      const existingJobData = existingJobSnap.data();
      if (existingJobData && existingJobData.ownerId && existingJobData.ownerId !== authenticatedOwnerId) {
        throw new HttpsError(
          "permission-denied",
          "Unauthorized access to an import job belonging to another agent."
        );
      }
      if (existingJobData && existingJobData.status === "Completed") {
        const idempotentResponse: ImportBatchResponse = {
          jobId: effectiveJobId,
          totalRows: existingJobData.totalRecords ?? candidates.length,
          importedCount: existingJobData.importedCount ?? 0,
          mergedCount: existingJobData.mergedCount ?? 0,
          skippedDuplicatesCount: existingJobData.duplicateCount ?? 0,
          errorCount: existingJobData.errorCount ?? 0,
          errors: [],
          importedIds: []
        };
        this.completedJobs.set(effectiveJobId, {
          ownerId: authenticatedOwnerId,
          response: idempotentResponse
        });
        return idempotentResponse;
      }
    }

    this.inFlightJobs.add(effectiveJobId);

    try {
      const nowIso = new Date().toISOString();

      // 5. Fetch agent's existing prospects and buyers for strictly owner-scoped duplicate detection
      const existingPhones = new Set<string>();
      const existingEmails = new Set<string>();
      const existingProspectsByPhone = new Map<string, { id: string; data: Record<string, any> }>();
      const existingProspectsByEmail = new Map<string, { id: string; data: Record<string, any> }>();

      const prospectDocs = await collections.prospects
        .where("ownerId", "==", authenticatedOwnerId)
        .select(
          "ownerId",
          "fullName",
          "phone",
          "email",
          "budgetMin",
          "budgetMax",
          "preferredLocations",
          "propertyTypes",
          "verificationStatus",
          "contactEligibility",
          "consentedPurposes",
          "consentedChannels",
          "notes"
        )
        .get();

      prospectDocs.forEach((doc: any) => {
        const data = doc.data ? doc.data() : {};
        // Defense-in-depth: verify ownerId matches authenticatedOwnerId
        if (data.ownerId && data.ownerId !== authenticatedOwnerId) return;

        if (data.phone) {
          const norm = this.normalizePhone(data.phone);
          if (norm.isValid && norm.canonical) {
            existingPhones.add(norm.canonical);
            existingProspectsByPhone.set(norm.canonical, { id: doc.id, data });
          }
        }
        if (data.email) {
          const norm = this.normalizeEmail(data.email);
          if (norm.isValid && norm.canonical) {
            existingEmails.add(norm.canonical);
            existingProspectsByEmail.set(norm.canonical, { id: doc.id, data });
          }
        }
      });

      const buyerDocs = await collections.buyers
        .where("ownerId", "==", authenticatedOwnerId)
        .select("ownerId", "phone", "email")
        .get();

      buyerDocs.forEach((doc: any) => {
        const data = doc.data ? doc.data() : {};
        if (data.ownerId && data.ownerId !== authenticatedOwnerId) return;

        if (data.phone) {
          const norm = this.normalizePhone(data.phone);
          if (norm.isValid && norm.canonical) existingPhones.add(norm.canonical);
        }
        if (data.email) {
          const norm = this.normalizeEmail(data.email);
          if (norm.isValid && norm.canonical) existingEmails.add(norm.canonical);
        }
      });

      const intraBatchPhones = new Set<string>();
      const intraBatchEmails = new Set<string>();

      const validRecords: ValidatedProspectRecord[] = [];
      const mergeOperations: { ref: any; data: Record<string, any> }[] = [];
      const errors: { rowIndex: number; error: string }[] = [];
      let skippedDuplicatesCount = 0;
      let mergedCount = 0;

      for (let i = 0; i < candidates.length; i++) {
        const rowIndex = i + 1;
        const raw = candidates[i];

        if (!raw || typeof raw !== "object") {
          errors.push({ rowIndex, error: "Invalid candidate record structure." });
          continue;
        }

        // Validate name
        const fullName = typeof raw.fullName === "string" ? raw.fullName.trim() : "";
        if (fullName.length < 2) {
          errors.push({ rowIndex, error: "Prospect full name is missing or less than 2 characters." });
          continue;
        }

        // Validate contact identifiers (require at least one VALID phone or email)
        const phoneNorm = this.normalizePhone(typeof raw.phone === "string" ? raw.phone : undefined);
        const emailNorm = this.normalizeEmail(typeof raw.email === "string" ? raw.email : undefined);

        const hasAnyRawContact = Boolean(
          (typeof raw.phone === "string" && raw.phone.trim() !== "") ||
          (typeof raw.email === "string" && raw.email.trim() !== "")
        );

        if (!hasAnyRawContact) {
          errors.push({ rowIndex, error: "At least one contact identifier (Phone or Email) must be provided." });
          continue;
        }

        if (!phoneNorm.isValid && !emailNorm.isValid) {
          errors.push({
            rowIndex,
            error: "At least one valid contact identifier (Malaysian Phone or Email) must be provided."
          });
          continue;
        }

        const validPhone = phoneNorm.isValid ? phoneNorm.canonical : "";
        const validEmail = emailNorm.isValid ? emailNorm.canonical : "";

        // Check duplicates using ONLY valid canonical contact keys
        const isExistingPhone = Boolean(validPhone && existingPhones.has(validPhone));
        const isExistingEmail = Boolean(validEmail && existingEmails.has(validEmail));
        const isIntraPhone = Boolean(validPhone && intraBatchPhones.has(validPhone));
        const isIntraEmail = Boolean(validEmail && intraBatchEmails.has(validEmail));

        const isDuplicate = isExistingPhone || isExistingEmail || isIntraPhone || isIntraEmail;

        // Evaluate Consent: strictly defaults to Pending Consent unless documented proof exists
        const consentEval = this.evaluateConsent(
          authenticatedOwnerId,
          `pros-srv-${effectiveJobId}-${i}`,
          typeof raw.consentStatus === "string" ? raw.consentStatus : "",
          typeof raw.consentEvidence === "string" ? raw.consentEvidence : "",
          sanitizedFileName,
          nowIso
        );

        if (isDuplicate) {
          if (duplicateStrategy === "skip" || isIntraPhone || isIntraEmail) {
            skippedDuplicatesCount++;
            if (validPhone) intraBatchPhones.add(validPhone);
            if (validEmail) intraBatchEmails.add(validEmail);
            continue;
          } else if (duplicateStrategy === "merge") {
            const matchedExisting =
              (validPhone ? existingProspectsByPhone.get(validPhone) : undefined) ||
              (validEmail ? existingProspectsByEmail.get(validEmail) : undefined);

            if (matchedExisting && (!matchedExisting.data.ownerId || matchedExisting.data.ownerId === authenticatedOwnerId)) {
              const existingData = matchedExisting.data;
              const existingDnc = existingData.contactEligibility === "Do Not Contact";
              const incomingDnc = consentEval.eligibility === "Do Not Contact";

              let mergedEligibility = existingData.contactEligibility || "Pending Consent";
              let mergedPurposes: string[] = Array.isArray(existingData.consentedPurposes)
                ? existingData.consentedPurposes
                : [];
              let mergedChannels: string[] = Array.isArray(existingData.consentedChannels)
                ? existingData.consentedChannels
                : [];

              if (existingDnc || incomingDnc) {
                mergedEligibility = "Do Not Contact";
                mergedPurposes = [];
                mergedChannels = [];
              } else if (existingData.contactEligibility === "Eligible" || consentEval.eligibility === "Eligible") {
                mergedEligibility = "Eligible";
                mergedPurposes = Array.from(new Set([...mergedPurposes, ...consentEval.consentedPurposes]));
                mergedChannels = Array.from(new Set([...mergedChannels, ...consentEval.consentedChannels]));
              }

              const sanitizedNotes = this.scrubSensitiveIdentifiers(
                typeof raw.notes === "string" ? raw.notes.slice(0, 500) : ""
              );

              const prospectRef = collections.prospects.doc(matchedExisting.id);
              mergeOperations.push({
                ref: prospectRef,
                data: {
                  ...existingData,
                  id: matchedExisting.id,
                  ownerId: authenticatedOwnerId,
                  fullName: fullName.slice(0, 100),
                  phone: validPhone || existingData.phone || "",
                  email: validEmail || existingData.email || "",
                  contactEligibility: mergedEligibility,
                  consentedPurposes: mergedPurposes,
                  consentedChannels: mergedChannels,
                  notes: `${existingData.notes || ""}\n[Merged]: ${sanitizedNotes}`.trim().slice(0, 500),
                  updatedAt: nowIso
                }
              });

              if (consentEval.consentEvent) {
                const mergedConsentId = `cst-${matchedExisting.id}-${effectiveJobId}-${i}`;
                const consentRef = collections.prospectConsents.doc(mergedConsentId);
                mergeOperations.push({
                  ref: consentRef,
                  data: {
                    ...consentEval.consentEvent,
                    id: mergedConsentId,
                    ownerId: authenticatedOwnerId,
                    prospectId: matchedExisting.id
                  }
                });
              }

              const mergeActId = `act-merge-${matchedExisting.id}-${effectiveJobId}-${i}`;
              const activityRef = collections.prospectActivities.doc(mergeActId);
              mergeOperations.push({
                ref: activityRef,
                data: {
                  id: mergeActId,
                  ownerId: authenticatedOwnerId,
                  prospectId: matchedExisting.id,
                  activityType: "Record Merged",
                  title: `Merged updates via CRM Batch Engine (${sanitizedFileName})`,
                  description: `Merged duplicate row ${rowIndex} with ${mergedEligibility} status.`,
                  actor: "CRM Batch Service",
                  timestamp: nowIso
                }
              });

              mergedCount++;
              if (validPhone) intraBatchPhones.add(validPhone);
              if (validEmail) intraBatchEmails.add(validEmail);
              continue;
            } else {
              // Matched an existing CRM buyer rather than a prospect; skip safely
              skippedDuplicatesCount++;
              if (validPhone) intraBatchPhones.add(validPhone);
              if (validEmail) intraBatchEmails.add(validEmail);
              continue;
            }
          }
          // duplicateStrategy === "importAnyway" falls through to create
        }

        if (validPhone) intraBatchPhones.add(validPhone);
        if (validEmail) intraBatchEmails.add(validEmail);

        const prospectId = `pros-srv-${effectiveJobId}-${i}`;
        const rawBudgetMin = typeof raw.budgetMin === "number" && raw.budgetMin > 0 ? raw.budgetMin : 400000;
        const rawBudgetMax = typeof raw.budgetMax === "number" && raw.budgetMax > 0 ? raw.budgetMax : 750000;
        const rawNotesStr = typeof raw.notes === "string" && raw.notes.trim() !== ""
          ? raw.notes.trim()
          : `Imported via ${sanitizedFileName}`;
        const sanitizedNotes = this.scrubSensitiveIdentifiers(rawNotesStr).slice(0, 500);

        validRecords.push({
          id: prospectId,
          ownerId: authenticatedOwnerId, // STRICT MULTI-TENANCY: Derived strictly from request.auth.uid
          fullName: fullName.slice(0, 100),
          phone: validPhone,
          email: validEmail,
          preferredLocations: Array.isArray(raw.preferredLocations) && raw.preferredLocations.length > 0
            ? raw.preferredLocations.map((l) => String(l).trim()).filter(Boolean).slice(0, 5)
            : ["Penang"],
          preferredState: typeof raw.preferredState === "string" && raw.preferredState.trim() !== ""
            ? raw.preferredState.trim()
            : "Penang",
          propertyTypes: Array.isArray(raw.propertyTypes) && raw.propertyTypes.length > 0
            ? raw.propertyTypes.map((t) => String(t).trim()).filter(Boolean).slice(0, 5)
            : ["Condominium"],
          budgetMin: Math.min(rawBudgetMin, rawBudgetMax),
          budgetMax: Math.max(rawBudgetMin, rawBudgetMax),
          purchasePurpose: typeof raw.purchasePurpose === "string" && raw.purchasePurpose.trim() !== ""
            ? raw.purchasePurpose.trim()
            : "Own Stay",
          buyingTimeline: typeof raw.buyingTimeline === "string" && raw.buyingTimeline.trim() !== ""
            ? raw.buyingTimeline.trim()
            : "Within 3 months",
          status: "Imported",
          // Verification must remain separate from contact eligibility and syntax checks
          verificationStatus: "Unverified",
          contactEligibility: consentEval.eligibility,
          consentedPurposes: consentEval.consentedPurposes,
          consentedChannels: consentEval.consentedChannels,
          primarySource: "CRM Import",
          confidenceScore: phoneNorm.isValid && emailNorm.isValid ? 85 : 70,
          notes: sanitizedNotes,
          isDemo: false,
          tags: [
            ...(isDuplicate ? ["Duplicate Reference"] : []),
            ...(consentEval.requiresReview ? ["Consent Verification Needed"] : [])
          ],
          createdAt: nowIso,
          updatedAt: nowIso,
          consentEvent: consentEval.consentEvent
        });
      }

      // 6. Queue all Firestore write operations and commit in safe chunks (<= 450 ops per WriteBatch)
      const importedIds: string[] = [];
      const writeOperations: { ref: any; data: Record<string, any> }[] = [...mergeOperations];

      for (const rec of validRecords) {
        const prospectRef = collections.prospects.doc(rec.id);
        const { consentEvent, ...prospectData } = rec;
        writeOperations.push({ ref: prospectRef, data: prospectData });
        importedIds.push(rec.id);

        // Deterministic activity ID
        const actId = `act-${rec.id}`;
        const activityRef = collections.prospectActivities.doc(actId);
        writeOperations.push({
          ref: activityRef,
          data: {
            id: actId,
            ownerId: authenticatedOwnerId,
            prospectId: rec.id,
            activityType: "Imported",
            title: `Imported via CRM Batch Engine (${sanitizedFileName})`,
            description: `Ingested prospect record with ${rec.contactEligibility} status.`,
            actor: "CRM Batch Service",
            timestamp: nowIso
          }
        });

        // Deterministic consent event ID if present
        if (consentEvent) {
          const consentRef = collections.prospectConsents.doc(consentEvent.id);
          writeOperations.push({ ref: consentRef, data: consentEvent });
        }
      }

      let batchesCommitted = 0;
      if (writeOperations.length > 0) {
        // Append Import Job record (sanitized aggregate metadata only, no PII)
        writeOperations.push({
          ref: jobRef,
          data: {
            id: effectiveJobId,
            ownerId: authenticatedOwnerId,
            sourceId: "src-crm-batch",
            sourceName: sanitizedFileName,
            status: "Completed",
            totalRecords: candidates.length,
            importedCount: validRecords.length,
            mergedCount,
            duplicateCount: skippedDuplicatesCount + mergedCount,
            errorCount: errors.length,
            errorSummary: errors.length > 0 ? `${errors.length} row(s) failed validation.` : null,
            startedAt: nowIso,
            completedAt: new Date().toISOString()
          }
        });

        for (let start = 0; start < writeOperations.length; start += this.MAX_FIRESTORE_BATCH_OPS) {
          const chunk = writeOperations.slice(start, start + this.MAX_FIRESTORE_BATCH_OPS);
          const batch = collections.prospects.firestore.batch();
          for (const op of chunk) {
            batch.set(op.ref, op.data);
          }
          await batch.commit();
          batchesCommitted++;
        }

        Logger.info("Batch prospects committed to Firestore", {
          ownerId: authenticatedOwnerId,
          jobId: effectiveJobId,
          importedCount: validRecords.length,
          mergedCount,
          skippedCount: skippedDuplicatesCount,
          batchesCommitted
        });
      }

      const response: ImportBatchResponse = {
        jobId: effectiveJobId,
        totalRows: candidates.length,
        importedCount: validRecords.length,
        mergedCount,
        skippedDuplicatesCount,
        errorCount: errors.length,
        errors,
        importedIds,
        batchesCommitted
      };

      if (writeOperations.length > 0) {
        this.completedJobs.set(effectiveJobId, {
          ownerId: authenticatedOwnerId,
          response
        });
      }

      return response;
    } finally {
      this.inFlightJobs.delete(effectiveJobId);
    }
  }

  private static evaluateConsent(
    ownerId: string,
    prospectId: string,
    rawConsentStatus: string,
    rawConsentEvidence: string,
    sourceFileName: string,
    nowIso: string
  ): {
    eligibility: string;
    consentedPurposes: string[];
    consentedChannels: string[];
    requiresReview: boolean;
    consentEvent?: ValidatedProspectRecord["consentEvent"];
  } {
    const consentRaw = rawConsentStatus.toLowerCase().trim();
    const evidence = rawConsentEvidence.trim();
    const lowerEvidence = evidence.toLowerCase();

    const isOptIn =
      ["granted", "yes", "true", "opt_in", "optin", "opt-in", "opted in", "opted_in", "opted-in", "agree", "agreed", "subscribed", "setuju", "1"].includes(
        consentRaw
      ) || consentRaw.startsWith("opted in") || consentRaw.startsWith("granted");

    const isOptOut =
      ["withdrawn", "no", "false", "opt_out", "optout", "opt-out", "opted out", "opted_out", "opted-out", "dnc", "do not contact", "unsubscribed", "unsubscribe", "batal", "0", "reject", "revoked", "stop"].includes(
        consentRaw
      ) ||
      consentRaw.includes("opt out") ||
      consentRaw.includes("opted out") ||
      consentRaw.includes("do not contact") ||
      lowerEvidence.includes("do not contact") ||
      lowerEvidence.includes("requested removal");

    const deterministicConsentId = `cst-${prospectId}`;

    if (isOptOut) {
      return {
        eligibility: "Do Not Contact",
        consentedPurposes: [],
        consentedChannels: [],
        requiresReview: false,
        consentEvent: {
          id: deterministicConsentId,
          ownerId,
          prospectId,
          consentType: "Marketing & Promotion",
          purpose: "Marketing & Promotion",
          communicationChannels: ["All"],
          status: "Withdrawn",
          source: sourceFileName,
          evidenceText: evidence || "Opt-out recorded in imported dataset.",
          consentTimestamp: nowIso,
          withdrawalTimestamp: nowIso
        }
      };
    }

    if (isOptIn) {
      const hasVerifiableEvidence =
        evidence.length >= 8 && !GENERIC_EVIDENCE_PLACEHOLDERS.has(lowerEvidence);

      const purpose = this.inferConsentPurpose(`${consentRaw} ${evidence}`);
      const channels = this.inferConsentChannels(`${sourceFileName} ${evidence}`);

      if (hasVerifiableEvidence) {
        const establishesContactEligibility =
          purpose === "Direct Inquiry Response" ||
          purpose === "Property Recommendations" ||
          purpose === "Marketing & Promotion";

        return {
          eligibility: establishesContactEligibility ? "Eligible" : "Pending Consent",
          consentedPurposes: [purpose],
          consentedChannels: establishesContactEligibility ? channels : [],
          requiresReview: !establishesContactEligibility,
          consentEvent: {
            id: deterministicConsentId,
            ownerId,
            prospectId,
            consentType: purpose,
            purpose,
            communicationChannels: channels,
            status: "Granted",
            source: sourceFileName,
            evidenceText: evidence,
            consentTimestamp: nowIso
          }
        };
      } else {
        return {
          eligibility: "Pending Consent",
          consentedPurposes: [],
          consentedChannels: [],
          requiresReview: true,
          consentEvent: {
            id: deterministicConsentId,
            ownerId,
            prospectId,
            consentType: purpose,
            purpose,
            communicationChannels: channels,
            status: "Pending Verification",
            source: sourceFileName,
            evidenceText: evidence || "Generic consent marker present in source without verifiable audit trail.",
            consentTimestamp: nowIso
          }
        };
      }
    }

    return {
      eligibility: "Pending Consent",
      consentedPurposes: [],
      consentedChannels: [],
      requiresReview: false
    };
  }

  private static inferConsentPurpose(text: string): string {
    const lower = text.toLowerCase();
    if (lower.includes("third-party") || lower.includes("third party") || lower.includes("partner sharing")) {
      return "Third-Party Sharing";
    }
    if (
      lower.includes("marketing") ||
      lower.includes("promotion") ||
      lower.includes("promotional") ||
      lower.includes("newsletter") ||
      lower.includes("broadcast")
    ) {
      return "Marketing & Promotion";
    }
    if (lower.includes("recommendation")) {
      return "Property Recommendations";
    }
    return "Direct Inquiry Response";
  }

  private static inferConsentChannels(text: string): string[] {
    const lower = text.toLowerCase();
    const channels: string[] = [];
    if (lower.includes("whatsapp")) channels.push("WhatsApp");
    if (lower.includes("email") || lower.includes("e-mail")) channels.push("Email");
    if (lower.includes("sms")) channels.push("SMS");
    if (lower.includes("call") || lower.includes("phone") || lower.includes("tel")) channels.push("Phone");
    if (channels.length === 0) channels.push("Direct Inquiry Channel");
    return channels;
  }

  private static sanitizeFileName(raw: unknown): string {
    if (typeof raw !== "string" || raw.trim() === "") return "CRM_Import.csv";
    const base = raw.trim().split(/[/\\]/).pop() || "CRM_Import.csv";
    return base.replace(/[\x00-\x1F\x7F]/g, "").slice(0, 120);
  }
}
