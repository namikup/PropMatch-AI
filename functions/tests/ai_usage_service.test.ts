import { AIUsageService } from "../src/services/ai_usage_service";

let mockReservedRequests = 20;
let mockMonthlyQuota = 100;

jest.mock("../src/config/firebase.config", () => {
  const mockSet = jest.fn().mockResolvedValue(undefined);
  const mockDoc = jest.fn(() => ({
    id: "mock_doc_id_123",
    set: mockSet,
    get: jest.fn().mockResolvedValue({
      exists: true,
      data: () => ({
        monthlyQuota: mockMonthlyQuota,
        billingCycle: "2026-11",
        reservedRequests: mockReservedRequests,
        successRequests: 15,
        failureRequests: 1
      })
    })
  }));

  const mockGet = jest.fn().mockResolvedValue({
    size: 25,
    forEach: (cb: any) => {
      cb({
        data: () => ({
          id: "log_1",
          ownerId: "agent_123",
          feature: "property_analysis",
          model: "gemini-2.5-flash",
          latencyMs: 1200,
          totalTokens: 450,
          status: "success",
          timestamp: new Date().toISOString()
        })
      });
    }
  });

  const mockQuery = {
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: mockGet
  };

  return {
    db: {
      runTransaction: jest.fn().mockImplementation(async (cb) => {
        const transaction = {
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              monthlyQuota: mockMonthlyQuota,
              billingCycle: "2026-11",
              reservedRequests: mockReservedRequests,
              successRequests: 15,
              failureRequests: 1
            })
          }),
          set: jest.fn().mockResolvedValue(undefined)
        };
        return cb(transaction);
      })
    },
    collections: {
      aiUsageLogs: {
        doc: mockDoc,
        ...mockQuery
      },
      agentQuotas: {
        doc: mockDoc
      }
    }
  };
});

describe("AIUsageService Quota & Cost Accuracy (Phase 3.1.3)", () => {
  const ownerId = "agent_123";

  beforeEach(() => {
    mockReservedRequests = 20;
    mockMonthlyQuota = 100;
  });

  it("should calculate exact official costs using verified 2026 Google pricing registry", () => {
    // gemini-2.5-flash: $0.30/1M input, $2.50/1M output
    // 1000 input = 0.00030, 1000 output = 0.00250 -> Total = $0.00280
    const flashCost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 1000, 1000);
    expect(flashCost).toBeCloseTo(0.00280, 5);

    // gemini-3.5-flash-lite: $0.30/1M input, $2.50/1M output
    // 1000 input = 0.00030, 1000 output = 0.00250 -> Total = $0.00280
    const liteCost = AIUsageService.calculateEstimatedCostUsd("gemini-3.5-flash-lite", 1000, 1000);
    expect(liteCost).toBeCloseTo(0.00280, 5);

    // gemini-3.8-flash (2026 rate): $0.75/1M input, $3.75/1M output
    // 1000 input = 0.00075, 1000 output = 0.00375 -> Total = $0.00450
    const advCost2026 = AIUsageService.calculateEstimatedCostUsd(
      "gemini-3.8-flash",
      1000,
      1000,
      new Date("2026-11-19")
    );
    expect(advCost2026).toBeCloseTo(0.00450, 5);

    // gemini-3.8-flash (2027 standard rate): $1.50/1M input, $7.50/1M output
    // 1000 input = 0.00150, 1000 output = 0.00750 -> Total = $0.00900
    const advCost2027 = AIUsageService.calculateEstimatedCostUsd(
      "gemini-3.8-flash",
      1000,
      1000,
      new Date("2027-01-05")
    );
    expect(advCost2027).toBeCloseTo(0.00900, 5);
  });

  it("should calculate exact costs for assumed operation workloads", () => {
    // Module A: Property Analysis (220 in, 200 out)
    const modACost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 220, 200);
    expect(modACost).toBeCloseTo(0.000566, 6);

    // Module B: Audience Discovery (250 in, 280 out)
    const modBCost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 250, 280);
    expect(modBCost).toBeCloseTo(0.000775, 6);

    // Module D: Buyer Matching (300 in, 250 out)
    const modDCost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 300, 250);
    expect(modDCost).toBeCloseTo(0.000715, 6);

    // Module E: Marketing Content (200 in, 220 out)
    const modECost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 200, 220);
    expect(modECost).toBeCloseTo(0.000610, 6);

    // Complete Campaign Flow (970 in, 950 out)
    const totalFlowCost = AIUsageService.calculateEstimatedCostUsd("gemini-2.5-flash", 970, 950);
    expect(totalFlowCost).toBeCloseTo(0.002666, 6);
  });

  it("should atomically reserve quota when below limit", async () => {
    mockReservedRequests = 50;
    mockMonthlyQuota = 100;

    const status = await AIUsageService.reserveQuotaAtomic(ownerId);
    expect(status.isAllowed).toBe(true);
    expect(status.reservedRequests).toBe(51);
    expect(status.remainingRequests).toBe(49);
  });

  it("should reject reservation when monthly quota is exhausted", async () => {
    mockReservedRequests = 100;
    mockMonthlyQuota = 100;

    await expect(AIUsageService.reserveQuotaAtomic(ownerId)).rejects.toThrow(
      /Monthly AI quota exceeded/
    );
  });

  it("should log usage with tokenSource and cost estimation", async () => {
    const id = await AIUsageService.logUsage({
      ownerId,
      feature: "property_analysis",
      model: "gemini-2.5-flash",
      promptTokens: 500,
      candidateTokens: 500,
      totalTokens: 1000,
      latencyMs: 1200,
      status: "success",
      timestamp: new Date().toISOString()
    });

    expect(id).toBe("mock_doc_id_123");
  });

  it("should return agent usage statistics", async () => {
    const stats = await AIUsageService.getAgentStats(ownerId);
    expect(stats.quota.isAllowed).toBe(true);
    expect(stats.recentLogs.length).toBe(1);
    expect(stats.usageByFeature["property_analysis"]).toBe(1);
  });
});
