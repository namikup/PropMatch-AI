import { LeadIngestionService } from "../src/services/lead_ingestion_service";
import { LeadDistributionService } from "../src/services/lead_distribution_service";
import { AgentPreferencesData } from "../src/types/agent_preferences.types";

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
    getDb: jest.fn(() => ({
      collection: jest.fn((colName: string) => createMockCollection(colName))
    })),
    getCollectionName: jest.fn((key: string) => key),
    collections: {
      incomingEnquiries: createMockCollection("incoming_enquiries"),
      prospects: createMockCollection("prospects"),
      buyers: createMockCollection("buyers"),
      projects: createMockCollection("projects"),
      prospectConsents: createMockCollection("prospect_consents")
    }
  };
});

describe("Phase 4.4.1: Real-World Agent Experience & Landing Page Validation (Backend)", () => {
  const agentAId = "agent-alex-penang-001";
  const agentBId = "agent-brenda-kl-002";

  beforeEach(() => {
    // Clear mock in-memory database
    const { mockStores } = require("../src/config/firebase.config");
    Object.keys(mockStores).forEach((k) => {
      const store = mockStores[k];
      Object.keys(store).forEach((key) => delete store[key]);
    });
  });

  // =========================================================================
  // 1. CHANNEL A DIRECT LANDING PAGE INGESTION & TWO-AGENT ISOLATION
  // =========================================================================
  describe("1. Channel A Direct Landing Page Ingestion & Multi-Tenant Isolation", () => {
    test("1.1 Agent A landing page submission assigns strictly to Agent A", async () => {
      const result = await LeadIngestionService.processEnquiry(agentAId, {
        sourceType: "Direct Website",
        sourceName: "Alex Tan Personal Landing Page",
        fullName: "Tan Wei Loon",
        phone: "+60124455667",
        email: "weilloon.tan@gmail.com",
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 400000,
        budgetMax: 550000,
        enquiryConsentGranted: true,
        marketingConsentGranted: false,
        campaignId: "penang-expo-2026",
        utmSource: "facebook",
        utmMedium: "paid_social",
        utmCampaign: "spring_launch"
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe("Qualified");
      expect(result.enquiry).toBeDefined();
      expect(result.enquiry?.ownerId).toBe(agentAId);
      expect(result.enquiry?.assignedAgentId).toBe(agentAId);
      expect(result.enquiry?.routingStatus).toBe("Direct");
      expect(result.enquiry?.acquisitionChannel).toBe("Channel A: Agent-Generated");

      const { mockStores } = require("../src/config/firebase.config");
      const prospect = mockStores.prospects[result.prospectId!];
      expect(prospect).toBeDefined();
      expect(prospect.ownerId).toBe(agentAId);
      expect(prospect.fullName).toBe("Tan Wei Loon");
    });

    test("1.2 Agent B landing page submission assigns strictly to Agent B", async () => {
      const result = await LeadIngestionService.processEnquiry(agentBId, {
        sourceType: "Direct Website",
        sourceName: "Brenda Lim Personal Landing Page",
        fullName: "Siti Nurhaliza",
        phone: "+60162233445",
        email: "siti.nur@yahoo.com",
        preferredLocation: "Mont Kiara",
        preferredState: "Kuala Lumpur",
        propertyType: "Condominium",
        budgetMin: 1000000,
        budgetMax: 1800000,
        enquiryConsentGranted: true,
        marketingConsentGranted: true,
        campaignId: "kl-luxury-living",
        utmSource: "instagram",
        utmMedium: "story_ad",
        utmCampaign: "mont_kiara_vip"
      });

      expect(result.success).toBe(true);
      expect(result.enquiry?.ownerId).toBe(agentBId);
      expect(result.enquiry?.assignedAgentId).toBe(agentBId);
      const { mockStores } = require("../src/config/firebase.config");
      const prospect = mockStores.prospects[result.prospectId!];
      expect(prospect.ownerId).toBe(agentBId);
    });

    test("1.3 Multi-tenant isolation: Agent A and Agent B records remain strictly segregated", async () => {
      // Ingest 1 lead for Agent A and 1 lead for Agent B
      await LeadIngestionService.processEnquiry(agentAId, {
        sourceType: "Direct Website",
        fullName: "Agent A Buyer",
        phone: "+60121111111",
        preferredLocation: "Batu Kawan"
      });

      await LeadIngestionService.processEnquiry(agentBId, {
        sourceType: "Direct Website",
        fullName: "Agent B Buyer",
        phone: "+60162222222",
        preferredLocation: "Mont Kiara"
      });

      const { mockStores } = require("../src/config/firebase.config");
      const prospectsStore = mockStores.prospects;

      const agentAProspects = Object.values(prospectsStore).filter((p: any) => p.ownerId === agentAId);
      const agentBProspects = Object.values(prospectsStore).filter((p: any) => p.ownerId === agentBId);

      expect(agentAProspects.length).toBe(1);
      expect(agentBProspects.length).toBe(1);
      expect((agentAProspects[0] as any).fullName).toBe("Agent A Buyer");
      expect((agentBProspects[0] as any).fullName).toBe("Agent B Buyer");
    });
  });

  // =========================================================================
  // 2. ANTI-TAMPERING & SECURITY HARDENING
  // =========================================================================
  describe("2. Client-Side Anti-Tampering & Spam Protection", () => {
    test("2.1 Malicious assignedAgentId in Direct Website payload is overridden by callerUid", async () => {
      // Attacker submits payload to Agent A's endpoint but attempts to inject Agent B's ID
      const tamperedPayload = {
        sourceType: "Direct Website",
        fullName: "Malicious Tamperer",
        phone: "+60129990011",
        assignedAgentId: agentBId, // Injected malicious assignedAgentId
        ownerId: agentBId // Injected malicious ownerId
      };

      const result = await LeadIngestionService.processEnquiry(agentAId, tamperedPayload);

      expect(result.success).toBe(true);
      // Backend security rule overrides injection:
      expect(result.enquiry?.ownerId).toBe(agentAId);
      expect(result.enquiry?.assignedAgentId).toBe(agentAId);
      const { mockStores } = require("../src/config/firebase.config");
      const prospect = mockStores.prospects[result.prospectId!];
      expect(prospect.ownerId).toBe(agentAId);
    });

    test("2.2 Honeypot spam trap rejects automated bot submissions", async () => {
      const botPayload = {
        sourceType: "Direct Website",
        fullName: "Automated Spambot",
        phone: "+60112233445",
        honeypot: "https://spam-link.ru/payload", // Honeypot trap triggered
        preferredLocation: "Batu Kawan"
      };

      const result = await LeadIngestionService.processEnquiry(agentAId, botPayload);

      expect(result.success).toBe(false);
      expect(result.status).toBe("Rejected");
      expect(result.prospectId).toBeUndefined();
      expect(result.enquiry?.statusReason).toContain("Spam honeypot trap");
    });
  });

  // =========================================================================
  // 3. CAMPAIGN ATTRIBUTION SURVIVAL ACROSS 5 PLATFORMS
  // =========================================================================
  describe("3. UTM Campaign Attribution Across Platforms", () => {
    const platforms = [
      { name: "Facebook", utmSource: "facebook", utmMedium: "cpc", utmCampaign: "penang_spring" },
      { name: "Instagram", utmSource: "instagram", utmMedium: "story_ad", utmCampaign: "batu_kawan_story" },
      { name: "WhatsApp", utmSource: "whatsapp", utmMedium: "broadcast", utmCampaign: "vip_investors" },
      { name: "TikTok", utmSource: "tiktok", utmMedium: "video_ad", utmCampaign: "first_home_owners" },
      { name: "Google Ads", utmSource: "google", utmMedium: "search_cpc", utmCampaign: "luxury_condo_kw" }
    ];

    platforms.forEach((p, idx) => {
      test(`3.${idx + 1} Preserves UTM attribution for ${p.name}`, async () => {
        const result = await LeadIngestionService.processEnquiry(agentAId, {
          sourceType: "Direct Website",
          fullName: `Buyer from ${p.name}`,
          phone: `+6012440000${idx}`,
          utmSource: p.utmSource,
          utmMedium: p.utmMedium,
          utmCampaign: p.utmCampaign,
          campaignId: `camp-${p.utmSource}`
        });

        expect(result.success).toBe(true);
        expect(result.enquiry?.utmSource).toBe(p.utmSource);
        expect(result.enquiry?.utmMedium).toBe(p.utmMedium);
        expect(result.enquiry?.utmCampaign).toBe(p.utmCampaign);
        expect(result.enquiry?.campaignId).toBe(`camp-${p.utmSource}`);
        const { mockStores } = require("../src/config/firebase.config");
        const prospect = mockStores.prospects[result.prospectId!];
        expect(prospect.tags).toContain(`Campaign: camp-${p.utmSource}`);
      });
    });
  });

  // =========================================================================
  // 4. CHANNEL B ROUTING & QUOTA ENFORCEMENT
  // =========================================================================
  describe("4. Channel B Routing & Monthly Quota Enforcement", () => {
    const agentPenangPrefs: AgentPreferencesData = {
      agentId: agentAId,
      isAvailableForPlatformLeads: true,
      preferredLocations: ["Batu Kawan", "Penang"],
      preferredPropertyTypes: ["Condominium"],
      priceRangeMin: 350000,
      priceRangeMax: 800000,
      specializations: ["First-time Homebuyer"],
      acceptedEnquiryTypes: ["Property Portal", "Developer", "Partner Agency"],
      monthlyLeadQuota: 30,
      leadsReceivedThisMonth: 10,
      lastLeadAssignedAt: new Date(Date.now() - 3600000 * 48).toISOString(),
      updatedAt: new Date().toISOString()
    };

    const agentKLPrefs: AgentPreferencesData = {
      agentId: agentBId,
      isAvailableForPlatformLeads: true,
      preferredLocations: ["Mont Kiara", "Kuala Lumpur"],
      preferredPropertyTypes: ["Condominium", "Luxury Residence"],
      priceRangeMin: 900000,
      priceRangeMax: 2500000,
      specializations: ["Luxury Investment"],
      acceptedEnquiryTypes: ["Property Portal", "Developer", "Partner Agency"],
      monthlyLeadQuota: 50,
      leadsReceivedThisMonth: 5,
      lastLeadAssignedAt: new Date(Date.now() - 3600000 * 24).toISOString(),
      updatedAt: new Date().toISOString()
    };

    test("4.1 Deterministic routing routes Penang lead to Agent Penang", () => {
      const enquiry = {
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 400000,
        budgetMax: 600000,
        sourceType: "Property Portal"
      };

      const decision = LeadDistributionService.routeEnquiry(
        enquiry,
        [agentPenangPrefs, agentKLPrefs],
        { [agentAId]: { fullName: "Alex Tan Chee Keong" }, [agentBId]: { fullName: "Brenda Lim Shu Wei" } }
      );

      expect(decision.isAssigned).toBe(true);
      expect(decision.assignedAgentId).toBe(agentAId);
      expect(decision.assignedAgentName).toBe("Alex Tan Chee Keong");
      expect(decision.suitabilityScore).toBeGreaterThanOrEqual(80);
    });

    test("4.2 Quota exhaustion prevents agent from receiving platform leads", () => {
      const exhaustedAgent: AgentPreferencesData = {
        ...agentPenangPrefs,
        leadsReceivedThisMonth: 30, // 30/30 quota reached
        monthlyLeadQuota: 30
      };

      const enquiry = {
        preferredLocation: "Batu Kawan",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 400000,
        budgetMax: 600000,
        sourceType: "Property Portal"
      };

      const decision = LeadDistributionService.routeEnquiry(enquiry, [exhaustedAgent]);

      expect(decision.isAssigned).toBe(false);
      expect(decision.routingStatus).toBe("Unassigned Queue");
      expect(decision.rationale).toContain("Unassigned Queue");
    });

    test("4.3 Unassigned Queue when no agent specializes in the territory", () => {
      const enquiry = {
        preferredLocation: "Kuantan",
        preferredState: "Pahang",
        propertyType: "Commercial Shoplot",
        budgetMin: 1200000,
        budgetMax: 2000000,
        sourceType: "Developer"
      };

      const decision = LeadDistributionService.routeEnquiry(enquiry, [agentPenangPrefs, agentKLPrefs]);

      expect(decision.isAssigned).toBe(false);
      expect(decision.routingStatus).toBe("Unassigned Queue");
    });
  });
});
