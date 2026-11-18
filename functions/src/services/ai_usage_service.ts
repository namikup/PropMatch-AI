import { collections } from "../config/firebase.config";
import { AIUsageLog, AgentQuotaStatus } from "../types/ai.types";
import { Logger } from "../utils/logger";

const DEFAULT_MONTHLY_QUOTA = 500;

export class AIUsageService {
  /**
   * Logs an AI execution event to the ai_usage_logs collection.
   */
  static async logUsage(log: Omit<AIUsageLog, "id">): Promise<string> {
    try {
      const docRef = collections.aiUsageLogs.doc();
      const usageEntry: AIUsageLog = {
        id: docRef.id,
        ...log
      };
      await docRef.set(usageEntry);
      return docRef.id;
    } catch (err) {
      Logger.error("Failed to persist AI usage log", err, { ownerId: log.ownerId, feature: log.feature });
      return "";
    }
  }

  /**
   * Checks whether the agent has remaining quota for the current billing cycle (calendar month).
   */
  static async checkQuota(ownerId: string): Promise<AgentQuotaStatus> {
    try {
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

      // Check if custom quota exists for agent
      const quotaDoc = await collections.agentQuotas.doc(ownerId).get();
      let monthlyQuota = DEFAULT_MONTHLY_QUOTA;

      if (quotaDoc.exists) {
        const data = quotaDoc.data();
        if (data && typeof data.monthlyQuota === "number") {
          monthlyQuota = data.monthlyQuota;
        }
      }

      // Query usage in current month
      const usageSnapshot = await collections.aiUsageLogs
        .where("ownerId", "==", ownerId)
        .where("timestamp", ">=", startOfMonth)
        .get();

      const currentMonthRequests = usageSnapshot.size;
      const remainingRequests = Math.max(0, monthlyQuota - currentMonthRequests);
      const isAllowed = currentMonthRequests < monthlyQuota;

      return {
        ownerId,
        currentMonthRequests,
        monthlyQuota,
        remainingRequests,
        isAllowed
      };
    } catch (err) {
      Logger.warn("Error checking agent quota, falling back to permissive allow", { ownerId });
      return {
        ownerId,
        currentMonthRequests: 0,
        monthlyQuota: DEFAULT_MONTHLY_QUOTA,
        remainingRequests: DEFAULT_MONTHLY_QUOTA,
        isAllowed: true
      };
    }
  }

  /**
   * Retrieves usage summary and recent logs for the authenticated agent.
   */
  static async getAgentStats(ownerId: string): Promise<{
    quota: AgentQuotaStatus;
    recentLogs: AIUsageLog[];
    usageByFeature: Record<string, number>;
  }> {
    const quota = await this.checkQuota(ownerId);

    const snapshot = await collections.aiUsageLogs
      .where("ownerId", "==", ownerId)
      .orderBy("timestamp", "desc")
      .limit(20)
      .get();

    const recentLogs: AIUsageLog[] = [];
    const usageByFeature: Record<string, number> = {};

    snapshot.forEach((doc) => {
      const data = doc.data() as AIUsageLog;
      recentLogs.push(data);
      usageByFeature[data.feature] = (usageByFeature[data.feature] || 0) + 1;
    });

    return {
      quota,
      recentLogs,
      usageByFeature
    };
  }
}
