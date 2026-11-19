"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AIUsageService = void 0;
const firebase_config_1 = require("../config/firebase.config");
const gemini_config_1 = require("../config/gemini.config");
const logger_1 = require("../utils/logger");
const https_1 = require("firebase-functions/v2/https");
const DEFAULT_MONTHLY_QUOTA = 500;
class AIUsageService {
    /**
     * Helper to get current billing cycle string (e.g. "2026-11")
     */
    static getCurrentBillingCycle() {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        return `${year}-${month}`;
    }
    /**
     * Calculates estimated cost in USD based on official Google Gemini Developer API pricing registry.
     * Source: https://ai.google.dev/gemini-api/docs/pricing (Verified: 2026-11-19)
     * Accounts for future pricing changes (e.g. 2027 rates for gemini-3.8-flash).
     */
    static calculateEstimatedCostUsd(model, promptTokens, candidateTokens, asOfDate = new Date()) {
        const pricingKey = (model in gemini_config_1.MODEL_PRICING_REGISTRY)
            ? model
            : (model.includes("3.8") ? "gemini-3.8-flash" : "gemini-2.5-flash");
        const pricing = (0, gemini_config_1.getModelEffectivePricing)(pricingKey, asOfDate);
        const promptRate = pricing.inputPricePerMillion / 1000000;
        const candidateRate = pricing.outputPricePerMillion / 1000000;
        const cost = (promptTokens * promptRate) + (candidateTokens * candidateRate);
        return Math.round(cost * 1000000) / 1000000; // 6 decimal precision
    }
    /**
     * Atomically reserves 1 request from agent quota in Firestore to prevent race conditions.
     * Uses a Firestore transaction so concurrent requests cannot bypass monthly quota.
     */
    static async reserveQuotaAtomic(ownerId) {
        const quotaRef = firebase_config_1.collections.agentQuotas.doc(ownerId);
        const currentCycle = this.getCurrentBillingCycle();
        try {
            return await firebase_config_1.db.runTransaction(async (transaction) => {
                const doc = await transaction.get(quotaRef);
                let monthlyQuota = DEFAULT_MONTHLY_QUOTA;
                let reservedCount = 0;
                let successCount = 0;
                let failureCount = 0;
                if (doc.exists) {
                    const data = doc.data() || {};
                    monthlyQuota = typeof data.monthlyQuota === "number" ? data.monthlyQuota : DEFAULT_MONTHLY_QUOTA;
                    // Check if document belongs to current billing cycle
                    if (data.billingCycle === currentCycle) {
                        reservedCount = typeof data.reservedRequests === "number" ? data.reservedRequests : 0;
                        successCount = typeof data.successRequests === "number" ? data.successRequests : 0;
                        failureCount = typeof data.failureRequests === "number" ? data.failureRequests : 0;
                    }
                }
                // Check quota availability
                if (reservedCount >= monthlyQuota) {
                    throw new https_1.HttpsError("resource-exhausted", `Monthly AI quota exceeded (${reservedCount}/${monthlyQuota} requests) for billing cycle ${currentCycle}.`);
                }
                const newReserved = reservedCount + 1;
                transaction.set(quotaRef, {
                    ownerId,
                    billingCycle: currentCycle,
                    monthlyQuota,
                    reservedRequests: newReserved,
                    successRequests: successCount,
                    failureRequests: failureCount,
                    updatedAt: new Date().toISOString()
                }, { merge: true });
                return {
                    ownerId,
                    currentMonthRequests: newReserved,
                    monthlyQuota,
                    remainingRequests: Math.max(0, monthlyQuota - newReserved),
                    isAllowed: true,
                    billingCycle: currentCycle,
                    reservedRequests: newReserved,
                    successRequests: successCount,
                    failureRequests: failureCount
                };
            });
        }
        catch (err) {
            if (err instanceof https_1.HttpsError)
                throw err;
            logger_1.Logger.warn("Error in atomic quota reservation, checking non-blocking status", { ownerId, error: String(err) });
            return this.checkQuota(ownerId);
        }
    }
    /**
     * Atomically releases reservation if request failed, ensuring failed calls do not exhaust quota.
     */
    static async rollbackQuotaReservation(ownerId) {
        const quotaRef = firebase_config_1.collections.agentQuotas.doc(ownerId);
        const currentCycle = this.getCurrentBillingCycle();
        try {
            await firebase_config_1.db.runTransaction(async (transaction) => {
                const doc = await transaction.get(quotaRef);
                if (!doc.exists)
                    return;
                const data = doc.data() || {};
                if (data.billingCycle !== currentCycle)
                    return;
                const reserved = typeof data.reservedRequests === "number" ? data.reservedRequests : 1;
                const failures = typeof data.failureRequests === "number" ? data.failureRequests : 0;
                transaction.set(quotaRef, {
                    reservedRequests: Math.max(0, reserved - 1),
                    failureRequests: failures + 1,
                    updatedAt: new Date().toISOString()
                }, { merge: true });
            });
        }
        catch (err) {
            logger_1.Logger.warn("Failed to rollback quota reservation", { ownerId, error: String(err) });
        }
    }
    /**
     * Atomically records successful request completion in agent quota.
     */
    static async recordQuotaSuccess(ownerId) {
        const quotaRef = firebase_config_1.collections.agentQuotas.doc(ownerId);
        const currentCycle = this.getCurrentBillingCycle();
        try {
            await firebase_config_1.db.runTransaction(async (transaction) => {
                const doc = await transaction.get(quotaRef);
                if (!doc.exists)
                    return;
                const data = doc.data() || {};
                if (data.billingCycle !== currentCycle)
                    return;
                const successes = typeof data.successRequests === "number" ? data.successRequests : 0;
                transaction.set(quotaRef, {
                    successRequests: successes + 1,
                    updatedAt: new Date().toISOString()
                }, { merge: true });
            });
        }
        catch (err) {
            logger_1.Logger.warn("Failed to increment quota success count", { ownerId, error: String(err) });
        }
    }
    /**
     * Logs an AI execution event with verified token sources and cost estimation.
     */
    static async logUsage(log) {
        try {
            const docRef = firebase_config_1.collections.aiUsageLogs.doc();
            const promptTokens = log.promptTokens || 0;
            const candidateTokens = log.candidateTokens || 0;
            const totalTokens = log.totalTokens || (promptTokens + candidateTokens);
            const estimatedCostUsd = this.calculateEstimatedCostUsd(log.model, promptTokens, candidateTokens);
            const usageEntry = {
                id: docRef.id,
                ...log,
                promptTokens,
                candidateTokens,
                totalTokens,
                tokenSource: log.tokenSource || "provider_metadata",
                isEstimated: log.isEstimated ?? false,
                estimatedCostUsd: log.estimatedCostUsd ?? estimatedCostUsd
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
     * Non-blocking quota check for UI and pre-flight inspection.
     */
    static async checkQuota(ownerId) {
        try {
            const currentCycle = this.getCurrentBillingCycle();
            const quotaDoc = await firebase_config_1.collections.agentQuotas.doc(ownerId).get();
            let monthlyQuota = DEFAULT_MONTHLY_QUOTA;
            let currentMonthRequests = 0;
            let reservedRequests = 0;
            let successRequests = 0;
            let failureRequests = 0;
            if (quotaDoc.exists) {
                const data = quotaDoc.data() || {};
                if (typeof data.monthlyQuota === "number") {
                    monthlyQuota = data.monthlyQuota;
                }
                if (data.billingCycle === currentCycle) {
                    reservedRequests = typeof data.reservedRequests === "number" ? data.reservedRequests : 0;
                    successRequests = typeof data.successRequests === "number" ? data.successRequests : 0;
                    failureRequests = typeof data.failureRequests === "number" ? data.failureRequests : 0;
                    currentMonthRequests = reservedRequests;
                }
            }
            // If no reservation record yet in current month, fallback to count successful logs
            if (currentMonthRequests === 0) {
                const now = new Date();
                const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
                const usageSnapshot = await firebase_config_1.collections.aiUsageLogs
                    .where("ownerId", "==", ownerId)
                    .where("status", "==", "success")
                    .where("timestamp", ">=", startOfMonth)
                    .get();
                currentMonthRequests = usageSnapshot.size;
                successRequests = usageSnapshot.size;
            }
            const remainingRequests = Math.max(0, monthlyQuota - currentMonthRequests);
            const isAllowed = currentMonthRequests < monthlyQuota;
            return {
                ownerId,
                currentMonthRequests,
                monthlyQuota,
                remainingRequests,
                isAllowed,
                billingCycle: currentCycle,
                reservedRequests,
                successRequests,
                failureRequests
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
     * Retrieves usage summary, recent logs, and breakdown for authenticated agent.
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