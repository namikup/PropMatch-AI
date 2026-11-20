import { ProspectImportService } from "../src/services/prospect_import_service";

const mockBatchSet = jest.fn();
const mockBatchCommit = jest.fn().mockResolvedValue(undefined);

jest.mock("../src/config/firebase.config", () => {
  const createMockCollection = (name: string) => {
    const store: Record<string, any> = {};
    return {
      name,
      _store: store,
      doc: jest.fn((id: string) => ({
        id,
        set: jest.fn((data: any) => {
          store[id] = data;
          return Promise.resolve();
        }),
        get: jest.fn(() =>
          Promise.resolve({
            exists: !!store[id],
            data: () => store[id]
          })
        )
      })),
      where: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({
        forEach: jest.fn(),
        docs: []
      }),
      firestore: {
        batch: jest.fn(() => ({
          set: mockBatchSet,
          commit: mockBatchCommit
        }))
      }
    };
  };

  return {
    collections: {
      prospects: createMockCollection("prospects"),
      buyers: createMockCollection("buyers"),
      prospectActivities: createMockCollection("prospect_activities"),
      prospectConsents: createMockCollection("prospect_consents"),
      prospectImportJobs: createMockCollection("prospect_import_jobs")
    }
  };
});

describe("Phase 4.2 & 4.2.1: CRM Import Engine Security & Reliability Audit (Backend)", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    ProspectImportService.resetJobCache();
  });

  describe("Phone & Email Normalization", () => {
    test("normalizes diverse Malaysian mobile formats into +601xxxxxxxx canonical format", () => {
      expect(ProspectImportService.normalizePhone("012-3456789")).toEqual({
        canonical: "+60123456789",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("011 1234 5678")).toEqual({
        canonical: "+601112345678",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("6012-4458921")).toEqual({
        canonical: "+60124458921",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("+6016-8874123")).toEqual({
        canonical: "+60168874123",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("+60 (0)12-345 6789")).toEqual({
        canonical: "+60123456789",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("00600123456789")).toEqual({
        canonical: "+60123456789",
        isValid: true
      });
      expect(ProspectImportService.normalizePhone("123456789.0")).toEqual({
        canonical: "+60123456789",
        isValid: true
      });
    });

    test("flags invalid phone numbers", () => {
      expect(ProspectImportService.normalizePhone("")).toEqual({
        canonical: "",
        isValid: false
      });
      expect(ProspectImportService.normalizePhone("123")).toEqual({
        canonical: "+123",
        isValid: false
      });
    });

    test("normalizes email addresses to lowercase and validates syntax", () => {
      expect(ProspectImportService.normalizeEmail("  Agent.Penang@PropMatch.MY  ")).toEqual({
        canonical: "agent.penang@propmatch.my",
        isValid: true
      });
      expect(ProspectImportService.normalizeEmail("invalid-email-format")).toEqual({
        canonical: "invalid-email-format",
        isValid: false
      });
    });
  });

  describe("Backend Security, Authentication & Multi-Agent Isolation", () => {
    test("rejects unauthenticated requests with empty callerUid", async () => {
      await expect(
        ProspectImportService.validateAndProcessBatch("", [{ fullName: "Test Buyer", phone: "012-3456789" }])
      ).rejects.toThrow("Authentication is required");
    });

    test("enforces 5MB fileSizeBytes and payload size limit server-side", async () => {
      await expect(
        ProspectImportService.validateAndProcessBatch(
          "agent-001",
          [{ fullName: "Test Buyer", phone: "012-3456789" }],
          "skip",
          "oversized.xlsx",
          "job-oversized",
          5 * 1024 * 1024 + 1
        )
      ).rejects.toThrow("exceeds the maximum allowed limit of 5.0 MB");
    });

    test("processes valid candidates, strips spoofed ownerId, and enforces ownerId === callerUid", async () => {
      const candidates = [
        {
          fullName: "Lim Guan Eng",
          ownerId: "spoofed-other-agent-uid",
          phone: "012-4458921",
          email: "ge.lim@penang.gov.my",
          preferredLocations: ["Batu Kawan"],
          preferredState: "Penang",
          budgetMin: 500000,
          budgetMax: 700000,
          notes: "NRIC 880412-14-5567 provided in remarks"
        }
      ];

      const result = await ProspectImportService.validateAndProcessBatch("agent-owner-001", candidates);
      expect(result.totalRows).toBe(1);
      expect(result.importedCount).toBe(1);
      expect(result.errorCount).toBe(0);
      expect(result.skippedDuplicatesCount).toBe(0);
      expect(result.importedIds.length).toBe(1);

      // Verify persisted prospect has callerUid and scrubbed NRIC
      const prospectSetCall = mockBatchSet.mock.calls.find(
        (call) => call[1] && call[1].fullName === "Lim Guan Eng"
      );
      expect(prospectSetCall).toBeDefined();
      expect(prospectSetCall[1].ownerId).toBe("agent-owner-001");
      expect(prospectSetCall[1].verificationStatus).toBe("Unverified");
      expect(prospectSetCall[1].notes).toContain("[NRIC-REDACTED]");
      expect(prospectSetCall[1].notes).not.toContain("880412-14-5567");
    });

    test("prevents cross-tenant jobId overwrite (IDOR protection)", async () => {
      const candidates = [{ fullName: "Buyer A", phone: "012-3456789" }];
      await ProspectImportService.validateAndProcessBatch(
        "agent-A",
        candidates,
        "skip",
        "leads.csv",
        "shared-job-100"
      );

      // Agent B attempts to reuse/overwrite Agent A's jobId
      await expect(
        ProspectImportService.validateAndProcessBatch(
          "agent-B",
          candidates,
          "skip",
          "leads.csv",
          "shared-job-100"
        )
      ).rejects.toThrow("Unauthorized access to an import job belonging to another agent");
    });
  });

  describe("Consent Scoping, Verification Separation & PDPA Controls", () => {
    test("strictly defaults to Pending Consent unless documented evidence is provided and scopes purpose/channel", async () => {
      const candidates = [
        {
          fullName: "Ahmad Albab",
          phone: "019-3321908",
          consentStatus: "yes", // generic consent with no evidence
          consentEvidence: ""
        },
        {
          fullName: "Chong Wei",
          phone: "017-8899001",
          consentStatus: "Opted In",
          consentEvidence: "WhatsApp inquiry for showroom unit on 14/11/2026"
        },
        {
          fullName: "Siti Sarah",
          phone: "016-7788990",
          consentStatus: "Opted Out",
          consentEvidence: "Requested removal on 05/11/2026"
        }
      ];

      const result = await ProspectImportService.validateAndProcessBatch("agent-owner-001", candidates);
      expect(result.importedCount).toBe(3);

      const ahmadCall = mockBatchSet.mock.calls.find((c) => c[1]?.fullName === "Ahmad Albab")?.[1];
      expect(ahmadCall.contactEligibility).toBe("Pending Consent");
      expect(ahmadCall.consentedPurposes).toEqual([]);
      expect(ahmadCall.verificationStatus).toBe("Unverified");

      const chongCall = mockBatchSet.mock.calls.find((c) => c[1]?.fullName === "Chong Wei")?.[1];
      expect(chongCall.contactEligibility).toBe("Eligible");
      expect(chongCall.consentedPurposes).toEqual(["Direct Inquiry Response"]);
      expect(chongCall.consentedChannels).toEqual(["WhatsApp"]);
      expect(chongCall.verificationStatus).toBe("Unverified");

      const sitiCall = mockBatchSet.mock.calls.find((c) => c[1]?.fullName === "Siti Sarah")?.[1];
      expect(sitiCall.contactEligibility).toBe("Do Not Contact");
      expect(sitiCall.consentedPurposes).toEqual([]);
    });

    test("rejects candidates with empty names or no valid contact identifiers", async () => {
      const candidates = [
        {
          fullName: "",
          phone: "012-3456789"
        },
        {
          fullName: "A",
          phone: "012-3456789"
        },
        {
          fullName: "Invalid Contact Person",
          phone: "123",
          email: "not-an-email"
        }
      ];

      const result = await ProspectImportService.validateAndProcessBatch("agent-owner-001", candidates);
      expect(result.importedCount).toBe(0);
      expect(result.errorCount).toBe(3);
      expect(result.errors[0].error).toContain("name is missing");
      expect(result.errors[2].error).toContain("valid contact identifier");
    });
  });

  describe("Batch Reliability, Idempotency & Firestore Write Chunking", () => {
    test("repeated execution of the same jobId is idempotent and does not re-commit duplicates", async () => {
      const candidates = [
        {
          fullName: "Idempotent Lead",
          phone: "012-9988776"
        }
      ];

      const firstRun = await ProspectImportService.validateAndProcessBatch(
        "agent-owner-001",
        candidates,
        "skip",
        "retry.csv",
        "job-idempotent-001"
      );
      expect(firstRun.importedCount).toBe(1);
      expect(mockBatchCommit).toHaveBeenCalledTimes(1);

      // Re-run with the exact same jobId
      const secondRun = await ProspectImportService.validateAndProcessBatch(
        "agent-owner-001",
        candidates,
        "skip",
        "retry.csv",
        "job-idempotent-001"
      );
      expect(secondRun.jobId).toBe("job-idempotent-001");
      expect(secondRun.importedCount).toBe(1);
      // Should NOT have committed another batch!
      expect(mockBatchCommit).toHaveBeenCalledTimes(1);
    });

    test("chunks large imports (>450 write operations) across multiple Firestore batches safely", async () => {
      // 250 valid candidates with consent events = 250 * 3 (prospect + activity + consent) + 1 job = 751 ops
      // At 450 max ops per batch, 751 ops must be split into 2 batch commits!
      const largeCandidates = Array.from({ length: 250 }, (_, idx) => ({
        fullName: `Prospect Lead ${idx + 1}`,
        phone: `012-${String(3000000 + idx).padStart(7, "0")}`,
        consentStatus: "Granted",
        consentEvidence: "Signed property exhibition registration form 2026"
      }));

      const result = await ProspectImportService.validateAndProcessBatch(
        "agent-owner-001",
        largeCandidates,
        "skip",
        "large_import.csv",
        "job-large-250"
      );

      expect(result.importedCount).toBe(250);
      expect(result.batchesCommitted).toBe(2);
      expect(mockBatchCommit).toHaveBeenCalledTimes(2);
    });
  });
});
