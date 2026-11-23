jest.mock("../src/config/firebase.config", () => {
  const mockStores: Record<string, Record<string, any>> = {
    incoming_enquiries: {},
    prospects: {},
    buyers: {},
    projects: {},
    prospect_consents: {}
  };

  const createMockCollection = (name: string) => {
    const store = mockStores[name];
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
      where: jest.fn((field: string, op: string, val: any) => {
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn(() => {
            const matchingDocs = Object.keys(store)
              .filter((k) => store[k][field] === val)
              .map((k) => ({
                id: k,
                data: () => store[k]
              }));
            return Promise.resolve({
              empty: matchingDocs.length === 0,
              docs: matchingDocs
            });
          })
        };
      }),
      get: jest.fn(() => {
        const docs = Object.keys(store).map((k) => ({
          id: k,
          data: () => store[k]
        }));
        return Promise.resolve({
          empty: docs.length === 0,
          docs
        });
      })
    };
  };

  return {
    mockStores,
    collections: {
      incomingEnquiries: createMockCollection("incoming_enquiries"),
      prospects: createMockCollection("prospects"),
      buyers: createMockCollection("buyers"),
      projects: createMockCollection("projects"),
      prospectConsents: createMockCollection("prospect_consents")
    }
  };
});

import { LeadIngestionService } from "../src/services/lead_ingestion_service";
const { mockStores } = jest.requireMock("../src/config/firebase.config");
const mockIncomingEnquiriesStore = mockStores.incoming_enquiries;
const mockProspectsStore = mockStores.prospects;
const mockBuyersStore = mockStores.buyers;
const mockProjectsStore = mockStores.projects;
const mockConsentsStore = mockStores.prospect_consents;

describe("Phase 4.3 Lead Ingestion Pipeline (Backend)", () => {
  const callerUid = "agent-uid-test-001";
  const otherAgentUid = "agent-uid-test-002";

  beforeEach(() => {
    jest.clearAllMocks();
    for (const key of Object.keys(mockIncomingEnquiriesStore)) delete mockIncomingEnquiriesStore[key];
    for (const key of Object.keys(mockProspectsStore)) delete mockProspectsStore[key];
    for (const key of Object.keys(mockBuyersStore)) delete mockBuyersStore[key];
    for (const key of Object.keys(mockProjectsStore)) delete mockProjectsStore[key];
    for (const key of Object.keys(mockConsentsStore)) delete mockConsentsStore[key];

    // Seed test project for callerUid
    mockProjectsStore["proj-001"] = {
      id: "proj-001",
      ownerId: callerUid,
      name: "EXSIM Batu Kawan Demo",
      startingPrice: 450000,
      maximumPrice: 580000,
      location: "Batu Kawan",
      state: "Penang",
      propertyType: "Condominium",
      purpose: "Own Stay"
    };
  });

  describe("Malaysian Phone & Email Normalization", () => {
    test("normalizes local mobile formats (012, 016, 6017, +6019) to E.164", () => {
      expect(LeadIngestionService.normalizeMalaysianPhone("012-3456789")).toBe("+60123456789");
      expect(LeadIngestionService.normalizeMalaysianPhone("016 411 9928")).toBe("+60164119928");
      expect(LeadIngestionService.normalizeMalaysianPhone("60175023819")).toBe("+60175023819");
      expect(LeadIngestionService.normalizeMalaysianPhone("+6019-2837465")).toBe("+60192837465");
      expect(LeadIngestionService.normalizeMalaysianPhone("")).toBe("");
    });

    test("normalizes email addresses to trimmed lowercase", () => {
      expect(LeadIngestionService.normalizeEmail("  Farah.Razali@Hospital.Gov.MY  ")).toBe("farah.razali@hospital.gov.my");
      expect(LeadIngestionService.normalizeEmail("")).toBe("");
    });
  });

  describe("Source Validation & Honeypot Protection", () => {
    test("rejects unsupported source types", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Random Unknown Scraper",
        fullName: "Test Lead"
      });

      expect(result.success).toBe(false);
      expect(result.stage).toBe("Source Validation");
      expect(result.status).toBe("Rejected");
    });

    test("silently catches spam bots when honeypot field is filled", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Direct Website",
        fullName: "Bot Submitter",
        phone: "010-0000000",
        email: "bot@spam-network.ru",
        website_hp: "http://buy-crypto-links.com" // Bot trapped!
      });

      expect(result.success).toBe(false);
      expect(result.stage).toBe("Source Validation");
      expect(result.status).toBe("Rejected");
      expect(mockIncomingEnquiriesStore[result.enquiryId]).toBeDefined();
      expect(mockIncomingEnquiriesStore[result.enquiryId].contactEligibility).toBe("Ineligible");
      // Zero prospect created
      expect(Object.keys(mockProspectsStore).length).toBe(0);
    });

    test("rejects submissions without mandatory full name", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Property Portal",
        fullName: "   ",
        phone: "012-3456789"
      });

      expect(result.success).toBe(false);
      expect(result.stage).toBe("Data Normalisation");
      expect(result.errorMessage).toContain("Full name is mandatory");
    });
  });

  describe("Duplicate Detection & Multi-Tenant Isolation", () => {
    test("detects duplicate by phone number within agent's prospect base", async () => {
      // Seed existing prospect for callerUid
      mockProspectsStore["prospect-existing-1"] = {
        id: "prospect-existing-1",
        ownerId: callerUid,
        fullName: "Dr. Farah Hanim",
        phone: "+60124883391",
        email: "farah@hospital.my",
        primarySource: "Property Portal"
      };

      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Property Portal",
        sourceName: "PropertyGuru Malaysia",
        fullName: "Dr. Farah Hanim",
        phone: "012-4883391", // Same number unformatted
        email: "farah@hospital.my",
        consentEvidence: "Portal submission"
      });

      expect(result.success).toBe(true);
      expect(result.isDuplicate).toBe(true);
      expect(result.status).toBe("Duplicate");
      expect(result.prospectId).toBe("prospect-existing-1");
      expect(result.duplicateTargetId).toBe("prospect-existing-1");
      // Prospect count remains 1 (no duplicate row created)
      expect(Object.keys(mockProspectsStore).length).toBe(1);
    });

    test("enforces multi-tenant isolation: other agent's prospect is NOT treated as duplicate", async () => {
      // Existing prospect belongs to otherAgentUid
      mockProspectsStore["prospect-agent-b"] = {
        id: "prospect-agent-b",
        ownerId: otherAgentUid,
        fullName: "Subramaniam Murugan",
        phone: "+60175023819",
        email: "subra@engg.my",
        primarySource: "Partner Agency"
      };

      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Direct Website",
        fullName: "Subramaniam Murugan",
        phone: "017-5023819",
        email: "subra@engg.my",
        consentEvidence: "Website form"
      });

      expect(result.isDuplicate).toBe(false);
      expect(result.status).toBe("Qualified");
      expect(result.prospectId).not.toBe("prospect-agent-b");
      // Newly created prospect belongs strictly to callerUid
      expect(mockProspectsStore[result.prospectId!].ownerId).toBe(callerUid);
    });
  });

  describe("Consent & Do Not Contact Precedence", () => {
    test("marks lead Ineligible and suppresses outreach when opt-out / DNC is flagged", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Partner Agency",
        fullName: "Kavitha Devi",
        phone: "011-2345678",
        doNotContact: true // Opt out requested
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Ineligible");
      expect(result.enquiry.contactEligibility).toBe("Do Not Contact");
      expect(result.enquiry.consentStatus).toBe("Consent Withdrawn");
      expect(mockProspectsStore[result.prospectId!].contactEligibility).toBe("Do Not Contact");
    });

    test("records valid consent event in prospect_consents collection", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Property Portal",
        fullName: "Marcus Lim",
        phone: "012-4773829",
        consentEvidence: "PropertyGuru online lead form PDPA checkbox checked"
      });

      expect(result.success).toBe(true);
      expect(result.enquiry.contactEligibility).toBe("Eligible");
      expect(result.enquiry.consentStatus).toBe("Consent Granted");
      expect(Object.keys(mockConsentsStore).length).toBe(1);
    });
  });

  describe("Deterministic AI Compatibility Matching", () => {
    test("calculates deterministic match score based on 5 weighted dimensions", async () => {
      const result = await LeadIngestionService.processEnquiry(callerUid, {
        sourceType: "Property Portal",
        fullName: "High Match Candidate",
        phone: "012-9988776",
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 450000,
        budgetMax: 550000,
        purchasePurpose: "Own Stay",
        buyingTimeline: "1-3 months",
        consentEvidence: "Portal form"
      });

      expect(result.success).toBe(true);
      expect(result.matchedProjectId).toBe("proj-001");
      expect(result.matchedProjectName).toBe("EXSIM Batu Kawan Demo");
      expect(result.matchScore).toBeGreaterThanOrEqual(80);
      expect(result.aiMatchExplanation).toContain("High compatibility");
      expect(result.suggestedNextAction).toBeDefined();
    });
  });
});
