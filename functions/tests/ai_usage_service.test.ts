import { AIUsageService } from "../src/services/ai_usage_service";

jest.mock("../src/config/firebase.config", () => {
  const mockSet = jest.fn().mockResolvedValue(undefined);
  const mockDoc = jest.fn(() => ({
    id: "mock_doc_id_123",
    set: mockSet,
    get: jest.fn().mockResolvedValue({
      exists: true,
      data: () => ({ monthlyQuota: 100 })
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
          model: "gemini-1.5-flash",
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

describe("AIUsageService", () => {
  const ownerId = "agent_123";

  it("should log usage and return generated doc ID", async () => {
    const id = await AIUsageService.logUsage({
      ownerId,
      feature: "property_analysis",
      model: "gemini-1.5-flash",
      latencyMs: 1200,
      totalTokens: 450,
      status: "success",
      timestamp: new Date().toISOString()
    });

    expect(id).toBe("mock_doc_id_123");
  });

  it("should check quota correctly against Firestore limits", async () => {
    const quota = await AIUsageService.checkQuota(ownerId);
    expect(quota.ownerId).toBe(ownerId);
    expect(quota.monthlyQuota).toBe(100);
    expect(quota.currentMonthRequests).toBe(25);
    expect(quota.remainingRequests).toBe(75);
    expect(quota.isAllowed).toBe(true);
  });

  it("should return agent usage statistics", async () => {
    const stats = await AIUsageService.getAgentStats(ownerId);
    expect(stats.quota.isAllowed).toBe(true);
    expect(stats.recentLogs.length).toBe(1);
    expect(stats.usageByFeature["property_analysis"]).toBe(1);
  });
});
