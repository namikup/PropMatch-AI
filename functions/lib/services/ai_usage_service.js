"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AIUsageService = void 0;
const firebase_config_1 = require("../config/firebase.config");
const logger_1 = require("../utils/logger");
const DEFAULT_MONTHLY_QUOTA = 500;
class AIUsageService {
    /**
     * Logs an AI execution event to the ai_usage_logs collection.
     */
    static async logUsage(log) {
        try {
            const docRef = firebase_config_1.collections.aiUsageLogs.doc();
            const usageEntry = {
                id: docRef.id,
                ...log
            };
            await docRef.set(usageEntry);
            return docRef.id;
        }
        catch (err) {
            logger_1.Logger.error("Failed to persist AI usage log", err, { ownerId: log.ownerId, feature: log.feature });
            return "";
        }
    }
    /**
     * Checks whether the agent has remaining quota for the current billing cycle (calendar month).
     */
    static async checkQuota(ownerId) {
        try {
            const now = new Date();
            const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
            // Check if custom quota exists for agent
            const quotaDoc = await firebase_config_1.collections.agentQuotas.doc(ownerId).get();
            let monthlyQuota = DEFAULT_MONTHLY_QUOTA;
            if (quotaDoc.exists) {
                const data = quotaDoc.data();
                if (data && typeof data.monthlyQuota === "number") {
                    monthlyQuota = data.monthlyQuota;
                }
            }
            // Query usage in current month
            const usageSnapshot = await firebase_config_1.collections.aiUsageLogs
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
        }
        catch (err) {
            logger_1.Logger.warn("Error checking agent quota, falling back to permissive allow", { ownerId });
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
    static async getAgentStats(ownerId) {
        const quota = await this.checkQuota(ownerId);
        const snapshot = await firebase_config_1.collections.aiUsageLogs
            .where("ownerId", "==", ownerId)
            .orderBy("timestamp", "desc")
            .limit(20)
            .get();
        const recentLogs = [];
        const usageByFeature = {};
        snapshot.forEach((doc) => {
            const data = doc.data();
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
exports.AIUsageService = AIUsageService;
//# sourceMappingURL=ai_usage_service.js.map