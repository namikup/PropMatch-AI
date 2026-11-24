import * as crypto from "crypto";

jest.mock("../src/config/firebase.config", () => {
  const mockStores: Record<string, Record<string, any>> = {
    meta_connections: {},
    meta_campaigns: {},
    meta_ingested_leads: {},
    meta_sync_logs: {},
    _private_meta_credentials: {},
    prospects: {},
    buyers: {},
    projects: {},
    incoming_enquiries: {},
    prospect_consents: {}
  };

  const createMockCollection = (name: string) => {
    const store = mockStores[name] || {};
    mockStores[name] = store;
    return {
      name,
      _store: store,
      doc: jest.fn((id: string) => ({
        id,
        set: jest.fn((data: any) => {
          store[id] = { ...data };
          return Promise.resolve();
        }),
        get: jest.fn(() =>
          Promise.resolve({
            exists: !!store[id],
            id,
            data: () => store[id]
          })
        ),
        update: jest.fn((data: any) => {
          if (store[id]) {
            store[id] = { ...store[id], ...data };
          }
          return Promise.resolve();
        }),
        delete: jest.fn(() => {
          delete store[id];
          return Promise.resolve();
        })
      })),
      add: jest.fn((data: any) => {
        const id = `auto_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
        store[id] = { id, ...data };
        return Promise.resolve({ id });
      }),
      where: jest.fn((field: string, op: string, val: any) => {
        const createQuery = (filters: Array<{ field: string; op: string; val: any }>): any => ({
          where: jest.fn((f: string, o: string, v: any): any => createQuery([...filters, { field: f, op: o, val: v }])),
          limit: jest.fn().mockReturnThis(),
          get: jest.fn(() => {
            const matchingDocs = Object.keys(store)
              .filter((k) => filters.every((filt) => store[k] && store[k][filt.field] === filt.val))
              .map((k) => ({
                id: k,
                data: () => store[k]
              }));
            return Promise.resolve({
              empty: matchingDocs.length === 0,
              size: matchingDocs.length,
              docs: matchingDocs,
              forEach: (cb: (doc: any) => void) => matchingDocs.forEach(cb)
            });
          })
        });
        return createQuery([{ field, op, val }]);
      }),
      get: jest.fn(() => {
        const docs = Object.keys(store).map((k) => ({
          id: k,
          data: () => store[k]
        }));
        return Promise.resolve({
          empty: docs.length === 0,
          size: docs.length,
          docs,
          forEach: (cb: (doc: any) => void) => docs.forEach(cb)
        });
      })
    };
  };

  return {
    mockStores,
    collections: {
      metaConnections: createMockCollection("meta_connections"),
      metaCampaigns: createMockCollection("meta_campaigns"),
      metaIngestedLeads: createMockCollection("meta_ingested_leads"),
      metaSyncLogs: createMockCollection("meta_sync_logs"),
      privateMetaCredentials: createMockCollection("_private_meta_credentials"),
      prospects: createMockCollection("prospects"),
      buyers: createMockCollection("buyers"),
      projects: createMockCollection("projects"),
      incomingEnquiries: createMockCollection("incoming_enquiries"),
      prospectConsents: createMockCollection("prospect_consents")
    }
  };
});

import { MetaAdsService } from "../src/services/meta_ads_service";
const { mockStores, collections } = jest.requireMock("../src/config/firebase.config");

describe("Phase 5.1 — Meta Ads Intelligence Service (Backend)", () => {
  const pilotOwnerId = "pilot-agent-malik-001";
  const agentBOwnerId = "agent-sarah-002";
  const testSecret = "test_meta_app_secret_123456";

  beforeEach(() => {
    jest.clearAllMocks();
    for (const key of Object.keys(mockStores)) {
      for (const docId of Object.keys(mockStores[key])) {
        delete mockStores[key][docId];
      }
    }
  });

  // =========================================================================
  // 1. OAUTH SECURITY & CSRF PROTECTION
  // =========================================================================
  describe("OAuth Security & CSRF State Validation", () => {
    it("generates and verifies valid HMAC-signed OAuth state", () => {
      const state = MetaAdsService.generateOAuthState(pilotOwnerId, testSecret);
      expect(typeof state).toBe("string");

      const isValid = MetaAdsService.verifyOAuthState(state, pilotOwnerId, testSecret);
      expect(isValid).toBe(true);
    });

    it("rejects OAuth state with mismatched ownerId (CSRF prevention)", () => {
      const state = MetaAdsService.generateOAuthState(pilotOwnerId, testSecret);
      const isValid = MetaAdsService.verifyOAuthState(state, agentBOwnerId, testSecret);
      expect(isValid).toBe(false);
    });

    it("rejects tampered OAuth state payload", () => {
      const state = MetaAdsService.generateOAuthState(pilotOwnerId, testSecret);
      const tampered = state.substring(0, state.length - 4) + "AAAA";
      const isValid = MetaAdsService.verifyOAuthState(tampered, pilotOwnerId, testSecret);
      expect(isValid).toBe(false);
    });
  });

  // =========================================================================
  // 2. TOKEN STORAGE SECURITY & PERMISSION AUDITING
  // =========================================================================
  describe("Token Storage Security & Permission Auditing", () => {
    it("saves tokens only to private collection and never exposes raw tokens in public config", async () => {
      await MetaAdsService.connectAccount(pilotOwnerId, {
        facebookPageId: "page-123",
        facebookPageName: "Malik Tan Real Estate",
        adAccountId: "act_492019482910",
        adAccountName: "Penang Landed Campaigns",
        currency: "MYR",
        accessToken: "EAAB_SECRET_ACCESS_TOKEN_NOT_FOR_CLIENT",
        grantedPermissions: [
          "ads_read",
          "ads_management",
          "leads_retrieval",
          "pages_manage_metadata",
          "pages_manage_ads",
          "pages_read_engagement",
          "pages_show_list"
        ]
      });

      // Check public connection document
      const publicDoc = await collections.metaConnections.doc(pilotOwnerId).get();
      expect(publicDoc.exists).toBe(true);
      const publicData = publicDoc.data()!;
      expect(publicData.isConnected).toBe(true);
      expect(publicData.adAccountId).toBe("act_492019482910");
      expect((publicData as any).accessToken).toBeUndefined(); // Zero token leakage!

      // Check private credentials document
      const privateDoc = await collections.privateMetaCredentials.doc(pilotOwnerId).get();
      expect(privateDoc.exists).toBe(true);
      expect(privateDoc.data()!.accessToken).toBe("EAAB_SECRET_ACCESS_TOKEN_NOT_FOR_CLIENT");
    });

    it("flags missing permissions when not all scopes are granted", async () => {
      const connection = await MetaAdsService.connectAccount(pilotOwnerId, {
        facebookPageId: "page-123",
        facebookPageName: "Malik Tan Real Estate",
        adAccountId: "492019482910",
        adAccountName: "Penang Landed Campaigns",
        accessToken: "test_token",
        grantedPermissions: ["ads_read"] // Missing leads_retrieval, pages_read_engagement, pages_manage_ads
      });

      expect(connection.connectionStatus).toBe("Reauthorization Required");
      expect(connection.missingPermissions).toContain("ads_management");
      expect(connection.missingPermissions).toContain("leads_retrieval");
      expect(connection.missingPermissions).toContain("pages_read_engagement");
    });

    it("purges private credentials completely upon disconnection", async () => {
      await MetaAdsService.connectAccount(pilotOwnerId, {
        facebookPageId: "page-123",
        facebookPageName: "Malik Tan Real Estate",
        adAccountId: "act_492019482910",
        adAccountName: "Penang Landed Campaigns",
        accessToken: "secret_token"
      });

      await MetaAdsService.disconnectAccount(pilotOwnerId);

      const privateDoc = await collections.privateMetaCredentials.doc(pilotOwnerId).get();
      expect(privateDoc.exists).toBe(false);

      const publicDoc = await collections.metaConnections.doc(pilotOwnerId).get();
      expect(publicDoc.data()!.isConnected).toBe(false);
      expect(publicDoc.data()!.connectionStatus).toBe("Disconnected");
    });
  });

  // =========================================================================
  // 3. WEBHOOK SIGNATURE VERIFICATION & IDEMPOTENCY
  // =========================================================================
  describe("Webhook Signature & Idempotency", () => {
    it("validates legitimate Meta Webhook x-hub-signature-256 header", () => {
      const payload = JSON.stringify({ object: "page", entry: [] });
      const hash = crypto.createHmac("sha256", testSecret).update(payload).digest("hex");
      const signatureHeader = `sha256=${hash}`;

      const isValid = MetaAdsService.verifyWebhookSignature(payload, signatureHeader, testSecret);
      expect(isValid).toBe(true);
    });

    it("rejects invalid or tampered webhook signatures", () => {
      const payload = JSON.stringify({ object: "page", entry: [] });
      const signatureHeader = "sha256=invalid_hash_value_1234567890abcdef1234567890abcdef";

      const isValid = MetaAdsService.verifyWebhookSignature(payload, signatureHeader, testSecret);
      expect(isValid).toBe(false);
    });

    it("suppresses duplicate lead webhook delivery idempotently", async () => {
      const leadPayload = {
        leadgenId: "leadgen-test-001",
        formId: "form-001",
        pageId: "page-123",
        campaignId: "meta-camp-aston-001",
        createdTime: Math.floor(Date.now() / 1000),
        fieldData: [
          { name: "full_name", values: ["Tan Ah Kow"] },
          { name: "phone_number", values: ["012-3456789"] },
          { name: "email", values: ["ahkow@gmail.com"] },
          { name: "preferred_location", values: ["Batu Kawan"] }
        ]
      };

      // First ingestion
      const res1 = await MetaAdsService.ingestMetaLead(pilotOwnerId, leadPayload);
      expect(res1.success).toBe(true);
      expect(res1.isDuplicate).toBe(false);

      // Duplicate delivery attempt with identical leadgenId
      const res2 = await MetaAdsService.ingestMetaLead(pilotOwnerId, leadPayload);
      expect(res2.success).toBe(true);
      expect(res2.isDuplicate).toBe(true); // Suppressed as duplicate!
    });
  });

  // =========================================================================
  // 3B. BULK LEAD RETRIEVAL & PAGINATION (GET /{form_id}/leads)
  // =========================================================================
  describe("Bulk Lead Retrieval & Cursor-Based Pagination", () => {
    it("fetches form leads with date filtering and cursor pagination", async () => {
      const originalFetch = global.fetch;
      const mockFetch = jest.fn().mockImplementation((url: string) => {
        expect(url).toContain("https://graph.facebook.com/v26.0/form-bulk-123/leads");
        expect(url).toContain("fields=id%2Ccreated_time");
        expect(url).toContain("time_created");
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              data: [
                {
                  id: "leadgen-bulk-001",
                  created_time: "2026-11-20T10:00:00+0000",
                  ad_id: "ad-101",
                  ad_name: "Astonia 4-Bed",
                  form_id: "form-bulk-123",
                  field_data: [
                    { name: "full_name", values: ["Bulk Buyer 1"] },
                    { name: "phone_number", values: ["012-9988776"] }
                  ]
                }
              ],
              paging: {
                cursors: { after: "cursor_page_2" },
                next: "https://graph.facebook.com/v26.0/form-bulk-123/leads?after=cursor_page_2"
              }
            })
        });
      });
      global.fetch = mockFetch as any;

      try {
        const result = await MetaAdsService.fetchFormLeads("form-bulk-123", "EAAB_test_page_token", {
          sinceTimestamp: 1732000000,
          limit: 10
        });

        expect(result.leads.length).toBe(1);
        expect(result.leads[0].leadgenId).toBe("leadgen-bulk-001");
        expect(result.hasNextPage).toBe(true);
        expect(result.nextCursor).toBe("cursor_page_2");
      } finally {
        global.fetch = originalFetch;
      }
    });

    it("syncFormLeads iterates pages and suppresses duplicates idempotently", async () => {
      const originalFetch = global.fetch;
      let callCount = 0;
      const mockFetch = jest.fn().mockImplementation(() => {
        callCount++;
        if (callCount === 1) {
          return Promise.resolve({
            ok: true,
            json: () =>
              Promise.resolve({
                data: [
                  {
                    id: "leadgen-page1-001",
                    form_id: "form-bulk-456",
                    field_data: [
                      { name: "full_name", values: ["Page 1 Buyer"] },
                      { name: "phone_number", values: ["019-1122334"] }
                    ]
                  }
                ],
                paging: {
                  cursors: { after: "cursor_page_2" },
                  next: "https://next-page"
                }
              })
          });
        }
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              data: [
                {
                  id: "leadgen-page2-002",
                  form_id: "form-bulk-456",
                  field_data: [
                    { name: "full_name", values: ["Page 2 Buyer"] },
                    { name: "phone_number", values: ["019-5566778"] }
                  ]
                }
              ],
              paging: { cursors: {} }
            })
        });
      });
      global.fetch = mockFetch as any;

      try {
        const syncResult = await MetaAdsService.syncFormLeads(pilotOwnerId, "form-bulk-456", "token", { maxPages: 2 });
        expect(syncResult.totalFetched).toBe(2);
        expect(syncResult.newIngested).toBe(2);
        expect(syncResult.duplicatesSuppressed).toBe(0);

        // Run sync again with same leads returned to test idempotency
        callCount = 0;
        const reSyncResult = await MetaAdsService.syncFormLeads(pilotOwnerId, "form-bulk-456", "token", { maxPages: 2 });
        expect(reSyncResult.totalFetched).toBe(2);
        expect(reSyncResult.newIngested).toBe(0);
        expect(reSyncResult.duplicatesSuppressed).toBe(2); // Suppressed as duplicates!
      } finally {
        global.fetch = originalFetch;
      }
    });

    it("falls back gracefully to core fields when ad fields query fails (no ads_management)", async () => {
      const originalFetch = global.fetch;
      let queryAttempt = 0;
      const mockFetch = jest.fn().mockImplementation((url: string) => {
        queryAttempt++;
        if (queryAttempt === 1) {
          // First attempt with full ad fields fails because token lacks ads_management
          expect(url).toContain("ad_id%2Cad_name");
          return Promise.resolve({
            ok: false,
            status: 400,
            text: () => Promise.resolve("(#200) Requires ads_management permission")
          });
        }
        // Second attempt with core fields succeeds
        expect(url).toContain("fields=id%2Ccreated_time%2Cform_id%2Cfield_data");
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              id: "leadgen-fallback-001",
              created_time: "2026-11-20T10:00:00+0000",
              form_id: "form-001",
              field_data: [
                { name: "full_name", values: ["Core Lead Buyer"] },
                { name: "phone_number", values: ["012-7766554"] }
              ]
            })
        });
      });
      global.fetch = mockFetch as any;

      try {
        const lead = await MetaAdsService.fetchLeadDetailsFromGraphApi("leadgen-fallback-001", "page_token");
        expect(lead.leadgenId).toBe("leadgen-fallback-001");
        expect(lead.fieldData.length).toBe(2);
        expect(lead.fieldData[0].values[0]).toBe("Core Lead Buyer");
        expect(lead.dataSource).toBe("PARTIAL_META_API");
        expect(queryAttempt).toBe(2); // Verified fallback execution!
      } finally {
        global.fetch = originalFetch;
      }
    });

    it("rejects lead ingestion when fieldData is empty due to failed Meta authorization (does NOT create fake lead)", async () => {
      const emptyPayload = {
        leadgenId: "leadgen-empty-auth-failed",
        formId: "form-001",
        pageId: "page-123",
        createdTime: Math.floor(Date.now() / 1000),
        fieldData: [], // Empty because Meta API authorization failed or was missing
        dataSource: "NOT_CONNECTED" as const
      };

      const result = await MetaAdsService.ingestMetaLead(pilotOwnerId, emptyPayload);
      expect(result.success).toBe(false);
      expect(result.error).toContain("Missing lead field_data");

      // Verify no prospect was fabricated in Firestore
      const prospectDoc = await collections.prospects.doc("prospect_leadgen-empty-auth-failed").get();
      expect(prospectDoc.exists).toBe(false);
    });

    it("throws an error when Graph API returns HTTP 401/403 and does not invent fake data", async () => {
      const originalFetch = global.fetch;
      const mockFetch = jest.fn().mockImplementation(() => {
        return Promise.resolve({
          ok: false,
          status: 403,
          text: () => Promise.resolve("(#10) Application does not have permission for this action")
        });
      });
      global.fetch = mockFetch as any;

      try {
        await expect(
          MetaAdsService.fetchLeadDetailsFromGraphApi("leadgen-forbidden-001", "bad_token")
        ).rejects.toThrow("Meta Graph API error fetching leadgen_id leadgen-forbidden-001");
      } finally {
        global.fetch = originalFetch;
      }
    });

    it("preserves source attribution metadata and marks unverified placement as UNKNOWN", async () => {
      const unverifiedPayload = {
        leadgenId: "leadgen-unverified-001",
        formId: "form-001",
        pageId: "page-123",
        createdTime: Math.floor(Date.now() / 1000),
        fieldData: [
          { name: "full_name", values: ["Unknown Placement Buyer"] },
          { name: "phone_number", values: ["012-3344556"] }
        ]
      };

      const result = await MetaAdsService.ingestMetaLead(pilotOwnerId, unverifiedPayload);
      expect(result.success).toBe(true);

      const storedIngested = await collections.metaIngestedLeads.doc("leadgen-unverified-001").get();
      expect(storedIngested.exists).toBe(true);
      expect(storedIngested.data()!.placement).toBe("UNKNOWN");
      expect(storedIngested.data()!.acquisitionSourceConfidence).toBe("Unverified");

      const storedProspect = await collections.prospects.doc(result.prospectId!).get();
      expect(storedProspect.data()!.placement).toBe("UNKNOWN");
      expect(storedProspect.data()!.acquisitionSourceConfidence).toBe("Unverified");
    });
  });

  // =========================================================================
  // 4. CAMPAIGN METRICS & DETERMINISTIC FORMULAS
  // =========================================================================
  describe("Deterministic Campaign Metrics & Buyer Quality", () => {
    it("computes exact CTR, CPC, CPM and Cost Per Lead deterministically", () => {
      const pilotCampaigns = MetaAdsService.getPilotCampaignData(pilotOwnerId);
      const c1 = pilotCampaigns[0];

      // c1: spend: 780.0, impressions: 24500, reach: 18200, clicks: 520, leads: 32
      const expectedCtr = parseFloat(((520 / 24500) * 100).toFixed(2)); // 2.12%
      const expectedCpc = parseFloat((780.0 / 520).toFixed(2)); // RM1.50
      const expectedCpm = parseFloat(((780.0 / 24500) * 1000).toFixed(2)); // RM31.84
      const expectedCpl = parseFloat((780.0 / 32).toFixed(2)); // RM24.38

      expect(c1.ctr).toBe(expectedCtr);
      expect(c1.cpc).toBe(expectedCpc);
      expect(c1.cpm).toBe(expectedCpm);
      expect(c1.costPerLead).toBe(expectedCpl);
    });

    it("preserves null for cost per viewing when viewings are 0 without fabricating fake metrics", async () => {
      const quality = await MetaAdsService.calculateBuyerQualityMetrics(pilotOwnerId, "non-existent-campaign", 500.0);
      expect(quality.viewingAppointments).toBe(0);
      expect(quality.costPerViewingAppointment).toBeNull(); // Explicitly null, NOT 0 or fabricated!
      expect(quality.costPerQualifiedBuyer).toBeNull();
    });
  });

  // =========================================================================
  // 5. AI CAMPAIGN INTELLIGENCE GROUNDING
  // =========================================================================
  describe("AI Campaign Intelligence Grounding", () => {
    it("generates grounded AI insights citing exact sample size and data period", async () => {
      // Connect pilot account so campaigns can sync
      await MetaAdsService.connectAccount(pilotOwnerId, {
        facebookPageId: "page-123",
        facebookPageName: "Malik Tan Real Estate",
        adAccountId: "act_492019482910",
        adAccountName: "Penang Landed Campaigns",
        accessToken: "test_token"
      });

      const insight = await MetaAdsService.generateAIIntelligence(pilotOwnerId);

      expect(insight.sampleSizeLeads).toBeGreaterThan(0);
      expect(insight.dataPeriod).toContain("Last 30 Days");
      expect(["High", "Moderate", "Low", "Insufficient Data"]).toContain(insight.statisticalConfidence);
      expect(insight.topPerformingCampaigns.length).toBeGreaterThan(0);
      expect(insight.budgetAdvisory).toBeDefined();
      expect(insight.budgetAdvisory).not.toContain("auto-execute"); // Strictly advisory!
    });
  });

  // =========================================================================
  // 6. MULTI-TENANT ISOLATION
  // =========================================================================
  describe("Multi-Tenant Data Isolation", () => {
    it("ensures Agent B cannot view or access Agent A's Meta campaigns", async () => {
      await MetaAdsService.connectAccount(pilotOwnerId, {
        facebookPageId: "page-malik",
        facebookPageName: "Malik Tan",
        adAccountId: "act_malik_123",
        adAccountName: "Malik Ads",
        accessToken: "malik_token"
      });

      // Synchronize campaigns for Malik
      await MetaAdsService.syncCampaigns(pilotOwnerId);

      // Agent B queries their own campaigns
      const agentBCampaigns = await MetaAdsService.getCampaigns(agentBOwnerId);
      expect(agentBCampaigns.length).toBe(0); // Zero cross-agent leakage!
    });
  });
});
