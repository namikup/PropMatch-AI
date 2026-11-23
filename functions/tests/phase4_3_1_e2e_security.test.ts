import { HttpsError } from "firebase-functions/v2/https";

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
        ),
        update: jest.fn((data: any) => {
          if (!store[id]) {
            return Promise.reject(new Error("Document not found"));
          }
          store[id] = { ...store[id], ...data };
          return Promise.resolve();
        })
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
import { Logger } from "../src/utils/logger";

const { mockStores } = jest.requireMock("../src/config/firebase.config");
const mockIncomingEnquiriesStore = mockStores.incoming_enquiries;
const mockProspectsStore = mockStores.prospects;
const mockBuyersStore = mockStores.buyers;
const mockProjectsStore = mockStores.projects;
const mockConsentsStore = mockStores.prospect_consents;

describe("Phase 4.3.1: End-to-End Enquiry Simulation & Security Audit (Backend)", () => {
  const agentA = "agent-uid-audit-001";
  const agentB = "agent-uid-audit-002";

  beforeEach(() => {
    jest.clearAllMocks();
    for (const key of Object.keys(mockIncomingEnquiriesStore)) delete mockIncomingEnquiriesStore[key];
    for (const key of Object.keys(mockProspectsStore)) delete mockProspectsStore[key];
    for (const key of Object.keys(mockBuyersStore)) delete mockBuyersStore[key];
    for (const key of Object.keys(mockProjectsStore)) delete mockProjectsStore[key];
    for (const key of Object.keys(mockConsentsStore)) delete mockConsentsStore[key];

    // Seed active projects for Agent A
    mockProjectsStore["proj-bk-01"] = {
      id: "proj-bk-01",
      ownerId: agentA,
      name: "EXSIM Batu Kawan Hub",
      location: "Batu Kawan",
      state: "Penang",
      propertyType: "Condominium",
      startingPrice: 450000,
      maximumPrice: 580000,
      purpose: "Own Stay & Investment"
    };

    mockProjectsStore["proj-gurney-02"] = {
      id: "proj-gurney-02",
      ownerId: agentA,
      name: "Gurney Premier Suites",
      location: "Gurney Drive, George Town",
      state: "Penang",
      propertyType: "Serviced Residence",
      startingPrice: 880000,
      maximumPrice: 1450000,
      purpose: "Investment"
    };
  });

  // =========================================================================
  // 1. SYNTHETIC BUYER JOURNEYS ACROSS ALL 5 SIMULATED SOURCES (12 SCENARIOS)
  // =========================================================================
  describe("1. Synthetic Buyer Journey Ingestion Simulation (12 Scenarios)", () => {
    test("Journey 1: Low-budget first homebuyer via Direct Website with PDPA consent", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Direct Website",
        sourceName: "Personal Agent Website Contact Form",
        fullName: "Ahmad Farhan bin Osman",
        phone: "012-3456789",
        email: "farhan.osman@gmail.com",
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 400000,
        budgetMax: 520000,
        purchasePurpose: "Own Stay",
        buyingTimeline: "1-3 months",
        consentEvidence: "Personal Website Form Checkbox (IP: 175.143.20.10)"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry.normalizedPhone).toBe("+60123456789");
      expect(result.enquiry.contactEligibility).toBe("Eligible");
      expect(result.prospectId).toBeDefined();
      expect(mockProspectsStore[result.prospectId!].ownerId).toBe(agentA);
      expect(result.matchedProjectId).toBe("proj-bk-01");
      expect(result.matchScore).toBeGreaterThanOrEqual(85);
    });

    test("Journey 2: Automated spam bot with populated honeypot via Direct Website", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Direct Website",
        sourceName: "Personal Agent Website Contact Form",
        fullName: "Crypto SEO Spam Bot",
        phone: "019-9999999",
        email: "spam@crypto-marketing-links.ru",
        honeypot: "http://buy-crypto-backlinks.ru" // Bot filled hidden honeypot
      });

      expect(result.success).toBe(false);
      expect(result.status).toBe("Rejected");
      expect(result.stage).toBe("Source Validation");
      expect(result.isDuplicate).toBe(false);
      expect(result.prospectId).toBeUndefined();
      expect(Object.keys(mockProspectsStore).length).toBe(0);
    });

    test("Journey 3: Luxury investor via Partner Agency (MIEA Co-Broke Network)", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Partner Agency",
        sourceName: "Klang Valley Premier Realty (REN 23819)",
        sourceReferenceId: "COBROKE-MIEA-KV-8891",
        fullName: "Datin Sophia Tan",
        phone: "012-8877665",
        email: "sophia.tan@heritage-holdings.my",
        preferredLocation: "Gurney Drive, George Town",
        preferredState: "Penang",
        propertyType: "Serviced Residence",
        budgetMin: 900000,
        budgetMax: 1500000,
        purchasePurpose: "Investment",
        buyingTimeline: "1-3 months",
        consentEvidence: "MIEA Standard Sub-Sale / Co-Broke Agreement Ref #COBROKE-MIEA-KV-8891"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry.normalizedPhone).toBe("+60128877665");
      expect(result.enquiry.contactEligibility).toBe("Eligible");
      expect(result.matchedProjectId).toBe("proj-gurney-02");
      expect(result.matchScore).toBeGreaterThanOrEqual(85);
    });

    test("Journey 4: Partner Agency referral with explicit Do Not Contact / Opt-out flag", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Partner Agency",
        sourceName: "Northern Region Realty (REN 11029)",
        fullName: "Chong Wei Lun",
        phone: "014-9988112",
        email: "chong.wl@finance.com.my",
        doNotContact: true // Withdrawn consent / opt-out
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Ineligible");
      expect(result.enquiry.contactEligibility).toBe("Do Not Contact");
      expect(result.enquiry.consentStatus).toBe("Consent Withdrawn");
      expect(mockProspectsStore[result.prospectId!].contactEligibility).toBe("Do Not Contact");
    });

    test("Journey 5: Mid-budget family condo inquiry via iProperty Malaysia portal", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Property Portal",
        sourceName: "iProperty Malaysia (Listing Ref #iP-BK-9912)",
        sourceReferenceId: "IP-LEAD-2026-991234",
        fullName: "Nurul Hidayah binti Razak",
        phone: "012-4883391",
        email: "hidayah.razak@telecom.my",
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 450000,
        budgetMax: 550000,
        purchasePurpose: "Own Stay",
        buyingTimeline: "1-3 months",
        consentEvidence: "iProperty Portal PDPA Checkbox Verified at 2026-11-22T14:32:00Z"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry.normalizedPhone).toBe("+60124883391");
      expect(result.matchedProjectId).toBe("proj-bk-01");
    });

    test("Journey 6: Re-enquiry arriving via PropertyGuru matching existing prospect (Idempotency)", async () => {
      // First seed an existing prospect for Agent A
      mockProspectsStore["prospect-farah-01"] = {
        id: "prospect-farah-01",
        ownerId: agentA,
        fullName: "Farah Lee",
        phone: "+6016-5544332",
        email: "farah.lee@petronas.com.my",
        primarySource: "Property Portal",
        primarySourceId: "PG-REF-ORIGINAL-001"
      };

      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Property Portal",
        sourceName: "PropertyGuru Malaysia (Secondary Listing #PG-5501)",
        sourceReferenceId: "PG-LEAD-REPEAT-0099",
        fullName: "Farah Lee",
        phone: "016-5544332", // Same phone
        email: "farah.lee@petronas.com.my",
        consentEvidence: "PropertyGuru form"
      });

      expect(result.success).toBe(true);
      expect(result.isDuplicate).toBe(true);
      expect(result.status).toBe("Duplicate");
      expect(result.enquiry.isDuplicate).toBe(true);
      expect(result.enquiry.duplicateTargetId).toBe("prospect-farah-01");
      expect(result.prospectId).toBe("prospect-farah-01");
      // Zero duplicate prospect created
      expect(Object.keys(mockProspectsStore).length).toBe(1);
    });

    test("Journey 7: Incomplete enquiry missing both phone and email is safely rejected at Data Normalisation", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Direct Website",
        sourceName: "Personal Agent Website Contact Form",
        fullName: "Anonymous Inquirer",
        // Phone and email omitted
        preferredLocation: "George Town"
      });

      expect(result.success).toBe(false);
      expect(result.status).toBe("Rejected");
      expect(result.stage).toBe("Data Normalisation");
      expect(result.errorMessage).toContain("contact identifier");
      expect(Object.keys(mockProspectsStore).length).toBe(0);
    });

    test("Journey 8: Developer showroom walk-in with signed physical registration slip", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Developer",
        sourceName: "BDB Land Sdn Bhd — Kulim Hi-Tech Green Residences",
        sourceReferenceId: "BDB-KULIM-SLIP-401",
        fullName: "Subramaniam a/l Murugan",
        phone: "017-5023819",
        email: "subra.murugan@engg.my",
        preferredLocation: "Kulim Hi-Tech Park",
        preferredState: "Kedah",
        propertyType: "Terrace House",
        budgetMin: 380000,
        budgetMax: 480000,
        purchasePurpose: "Own Stay",
        buyingTimeline: "Immediately",
        consentEvidence: "Developer Showroom Physical Registration Slip Serial #BDB-KULIM-SLIP-401"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry.normalizedPhone).toBe("+60175023819");
      expect(result.prospectId).toBeDefined();
    });

    test("Journey 9: VIP gallery investor via EcoWorld tablet registration", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Developer",
        sourceName: "Eco World Development Group Berhad — Eco Horizon Gallery",
        sourceReferenceId: "ECO-TABLET-2026-VIP-102",
        fullName: "David Tan Kok Meng",
        phone: "012-7711223",
        email: "david.tan@tan-capital.com",
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 450000,
        budgetMax: 650000,
        purchasePurpose: "Investment",
        buyingTimeline: "1-3 months",
        consentEvidence: "Eco Horizon Gallery Tablet Form with Biometric Signature Hash (Tablet #ECO-TAB-04)"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry.normalizedPhone).toBe("+60127711223");
      expect(result.matchedProjectId).toBe("proj-bk-01");
    });

    test("Journey 10: Historical agency CRM import defaults safely to Pending Consent", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "CRM Import",
        sourceName: "Legacy Excel Export 2024.xlsx",
        sourceReferenceId: "ROW-502",
        fullName: "Lim Swee Huat",
        phone: "019-2233445",
        email: "sweehuat.lim@outlook.com",
        // No explicit consent evidence provided in legacy import
        preferredLocation: "Batu Kawan",
        preferredState: "Penang"
      });

      expect(result.success).toBe(true);
      expect(result.enquiry.contactEligibility).toBe("Pending Consent");
      expect(result.enquiry.consentStatus).toBe("Pending Consent");
      expect(mockProspectsStore[result.prospectId!].contactEligibility).toBe("Pending Consent");
    });

    test("Journey 11: Webhook cryptographic signature verification rejects tampered requests", async () => {
      const result = await LeadIngestionService.processEnquiry(agentA, {
        sourceType: "Property Portal",
        sourceName: "PropertyGuru Malaysia",
        fullName: "Tampered Lead Candidate",
        phone: "012-8889999",
        webhookSignature: "tampered_signature" // Cryptographic HMAC mismatch
      });

      expect(result.success).toBe(false);
      expect(result.status).toBe("Rejected");
      expect(result.stage).toBe("Source Validation");
      expect(result.errorMessage).toContain("cryptographic signature");
      expect(Object.keys(mockProspectsStore).length).toBe(0);
    });

    test("Journey 12: Unauthenticated ingestion request without callerUid is strictly rejected", async () => {
      await expect(
        LeadIngestionService.processEnquiry("", {
          sourceType: "Direct Website",
          fullName: "Unauthenticated Caller",
          phone: "012-3456789"
        })
      ).rejects.toThrow(HttpsError);

      try {
        await LeadIngestionService.processEnquiry("", {
          sourceType: "Direct Website",
          fullName: "Unauthenticated Caller",
          phone: "012-3456789"
        });
      } catch (err: any) {
        expect(err.code).toBe("unauthenticated");
      }
    });
  });

  // =========================================================================
  // 2. MULTI-TENANT ISOLATION, ANTI-OVERWRITE & IDOR PROTECTION
  // =========================================================================
  describe("2. Multi-Tenant IDOR Protection & Anti-Overwrite Defense", () => {
    test("Agent A cannot query or read enquiries belonging to Agent B", async () => {
      // Seed enquiry for Agent A
      mockIncomingEnquiriesStore["enq-agent-a"] = {
        id: "enq-agent-a",
        ownerId: agentA,
        fullName: "Lead for Agent A",
        sourceType: "Direct Website",
        stage: "Qualified"
      };

      // Seed enquiry for Agent B
      mockIncomingEnquiriesStore["enq-agent-b"] = {
        id: "enq-agent-b",
        ownerId: agentB,
        fullName: "Lead for Agent B",
        sourceType: "Property Portal",
        stage: "Qualified"
      };

      // Agent A calls getEnquiries
      const resultAgentA = await LeadIngestionService.getEnquiries(agentA);
      expect(resultAgentA.length).toBe(1);
      expect(resultAgentA[0].id).toBe("enq-agent-a");
      expect(resultAgentA.some((e: any) => e.ownerId === agentB)).toBe(false);

      // Agent B calls getEnquiries
      const resultAgentB = await LeadIngestionService.getEnquiries(agentB);
      expect(resultAgentB.length).toBe(1);
      expect(resultAgentB[0].id).toBe("enq-agent-b");
      expect(resultAgentB.some((e: any) => e.ownerId === agentA)).toBe(false);
    });

    test("Agent A cannot overwrite an existing enquiry owned by Agent B via processEnquiry", async () => {
      mockIncomingEnquiriesStore["enq-agent-b-001"] = {
        id: "enq-agent-b-001",
        ownerId: agentB,
        fullName: "Confidential Lead of Agent B",
        sourceType: "Developer"
      };

      // Agent A attempts to process/overwrite Agent B's enquiry ID
      await expect(
        LeadIngestionService.processEnquiry(agentA, {
          id: "enq-agent-b-001",
          sourceType: "Direct Website",
          fullName: "Attacker Malicious Overwrite",
          phone: "012-9999999"
        })
      ).rejects.toThrow("Tenant violation");
    });

    test("Agent A cannot mutate status of an enquiry owned by Agent B via updateEnquiryStatus", async () => {
      mockIncomingEnquiriesStore["enq-agent-b-002"] = {
        id: "enq-agent-b-002",
        ownerId: agentB,
        fullName: "High Value Lead of Agent B",
        processingStatus: "Pending"
      };

      // Agent A attempts to update Agent B's enquiry status to Rejected
      await expect(
        LeadIngestionService.updateEnquiryStatus(agentA, "enq-agent-b-002", "Rejected")
      ).rejects.toThrow("Tenant violation");

      // Verify status was NOT modified
      expect(mockIncomingEnquiriesStore["enq-agent-b-002"].processingStatus).toBe("Pending");
    });
  });

  // =========================================================================
  // 3. ZERO PII & ZERO API KEY LEAKAGE IN LOGS
  // =========================================================================
  describe("3. Zero PII & Zero API Key Leakage Defense", () => {
    let logSpy: jest.SpyInstance;
    let warnSpy: jest.SpyInstance;
    let errorSpy: jest.SpyInstance;

    beforeEach(() => {
      logSpy = jest.spyOn(console, "log").mockImplementation(() => {});
      warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
      errorSpy = jest.spyOn(console, "error").mockImplementation(() => {});
    });

    afterEach(() => {
      logSpy.mockRestore();
      warnSpy.mockRestore();
      errorSpy.mockRestore();
    });

    test("redacts Malaysian phone numbers, emails, NRICs and Gemini API keys in log output", () => {
      const sensitiveMeta = {
        phone: "012-3456789",
        email: "hidayah.razak@telecom.my",
        apiKey: "AIzaSyD-fakeKey1234567890abcdefghijklm",
        nric: "920101-07-5555",
        textLog: "Customer with phone +60124883391 and key AIzaSyD-anotherSecretKey1234567890abc visited"
      };

      Logger.info("Testing PII sanitization in log event", sensitiveMeta);

      expect(logSpy).toHaveBeenCalled();
      const emittedLog = logSpy.mock.calls[0][0];

      // Sensitive values must NOT appear in raw format
      expect(emittedLog).not.toContain("012-3456789");
      expect(emittedLog).not.toContain("hidayah.razak@telecom.my");
      expect(emittedLog).not.toContain("AIzaSyD-fakeKey1234567890abcdefghijklm");
      expect(emittedLog).not.toContain("920101-07-5555");
      expect(emittedLog).not.toContain("+60124883391");
      expect(emittedLog).not.toContain("AIzaSyD-anotherSecretKey1234567890abc");

      // Redacted tokens must appear
      expect(emittedLog).toContain("[REDACTED]");
      expect(emittedLog).toContain("[REDACTED_PHONE]");
      expect(emittedLog).toContain("[REDACTED_API_KEY]");
    });
  });
});
