"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAIUsageStats = exports.generateMarketingContent = exports.matchBuyers = exports.discoverAudienceSegments = exports.analyzeProperty = void 0;
const https_1 = require("firebase-functions/v2/https");
const ai_request_validator_1 = require("./validators/ai_request_validator");
const gemini_service_1 = require("./services/gemini_service");
const ai_usage_service_1 = require("./services/ai_usage_service");
const error_handler_1 = require("./utils/error_handler");
const logger_1 = require("./utils/logger");
const firebase_config_1 = require("./config/firebase.config");
// Default deployment options for asia-southeast1 (Singapore - lowest latency for Malaysia)
const callOptions = {
    cors: true,
    region: "asia-southeast1",
    timeoutSeconds: 60,
    maxInstances: 10
};
/**
 * Callable Function: Analyze Property (Module A)
 */
exports.analyzeProperty = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    try {
        // 1. Quota Check
        const quota = await ai_usage_service_1.AIUsageService.checkQuota(callerUid);
        if (!quota.isAllowed) {
            throw new https_1.HttpsError("resource-exhausted", `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`);
        }
        // 2. Validate input and verify multi-tenant project ownership
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        logger_1.Logger.info("Executing analyzeProperty", { ownerId: callerUid, projectId: project.id });
        // 3. Execute Gemini LLM call
        const result = await gemini_service_1.GeminiService.analyzeProperty(project);
        // 4. Record usage in Firestore
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "property_analysis",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            latencyMs: result.latencyMs,
            status: "success",
            timestamp: new Date().toISOString(),
            projectId: project.id
        });
        // 5. Persist property analysis record into Firestore
        try {
            const analysisDocRef = firebase_config_1.collections.propertyAnalyses.doc(`${project.id}_analysis`);
            await analysisDocRef.set({
                id: analysisDocRef.id,
                projectId: project.id,
                ownerId: callerUid,
                analysis: result.data,
                model: result.model,
                updatedAt: new Date().toISOString()
            });
        }
        catch (saveErr) {
            logger_1.Logger.warn("Failed to cache property analysis in Firestore", { error: String(saveErr) });
        }
        return {
            success: true,
            data: result.data,
            meta: {
                model: result.model,
                latencyMs: result.latencyMs,
                tokens: result.totalTokens
            }
        };
    }
    catch (err) {
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "property_analysis",
            model: "gemini-1.5-flash",
            latencyMs,
            status: "failed",
            errorMessage: err instanceof Error ? err.message : String(err),
            timestamp: new Date().toISOString(),
            projectId: request.data?.project?.id
        });
        throw error_handler_1.ErrorHandler.handle(err, "analyzeProperty", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Discover Audience Segments (Module B)
 */
exports.discoverAudienceSegments = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    try {
        const quota = await ai_usage_service_1.AIUsageService.checkQuota(callerUid);
        if (!quota.isAllowed) {
            throw new https_1.HttpsError("resource-exhausted", `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`);
        }
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        logger_1.Logger.info("Executing discoverAudienceSegments", { ownerId: callerUid, projectId: project.id });
        const result = await gemini_service_1.GeminiService.discoverAudienceSegments(project);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "audience_discovery",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            latencyMs: result.latencyMs,
            status: "success",
            timestamp: new Date().toISOString(),
            projectId: project.id
        });
        return {
            success: true,
            data: result.data,
            meta: {
                model: result.model,
                latencyMs: result.latencyMs,
                tokens: result.totalTokens
            }
        };
    }
    catch (err) {
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "audience_discovery",
            model: "gemini-1.5-flash",
            latencyMs,
            status: "failed",
            errorMessage: err instanceof Error ? err.message : String(err),
            timestamp: new Date().toISOString(),
            projectId: request.data?.project?.id
        });
        throw error_handler_1.ErrorHandler.handle(err, "discoverAudienceSegments", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Match Buyers (Module D)
 */
exports.matchBuyers = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    try {
        const quota = await ai_usage_service_1.AIUsageService.checkQuota(callerUid);
        if (!quota.isAllowed) {
            throw new https_1.HttpsError("resource-exhausted", `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`);
        }
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        const sanitizedBuyers = ai_request_validator_1.AIRequestValidator.validateAndSanitizeBuyers(request.data?.buyers, callerUid);
        logger_1.Logger.info("Executing matchBuyers", {
            ownerId: callerUid,
            projectId: project.id,
            buyerCount: sanitizedBuyers.length
        });
        const result = await gemini_service_1.GeminiService.matchBuyers(project, sanitizedBuyers);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "buyer_matching",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            latencyMs: result.latencyMs,
            status: "success",
            timestamp: new Date().toISOString(),
            projectId: project.id
        });
        return {
            success: true,
            data: result.data,
            meta: {
                model: result.model,
                latencyMs: result.latencyMs,
                tokens: result.totalTokens
            }
        };
    }
    catch (err) {
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "buyer_matching",
            model: "gemini-1.5-flash",
            latencyMs,
            status: "failed",
            errorMessage: err instanceof Error ? err.message : String(err),
            timestamp: new Date().toISOString(),
            projectId: request.data?.project?.id
        });
        throw error_handler_1.ErrorHandler.handle(err, "matchBuyers", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Generate Marketing Content (Module E)
 */
exports.generateMarketingContent = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    try {
        const quota = await ai_usage_service_1.AIUsageService.checkQuota(callerUid);
        if (!quota.isAllowed) {
            throw new https_1.HttpsError("resource-exhausted", `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`);
        }
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        const segmentName = typeof request.data?.segmentName === "string" ? request.data.segmentName : "General Buyers";
        const channel = typeof request.data?.channel === "string" ? request.data.channel : "Facebook Ad";
        const language = ["en", "bm", "zh"].includes(request.data?.language) ? request.data.language : "en";
        logger_1.Logger.info("Executing generateMarketingContent", {
            ownerId: callerUid,
            projectId: project.id,
            segmentName,
            channel,
            language
        });
        const result = await gemini_service_1.GeminiService.generateMarketingContent(project, segmentName, channel, language);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "marketing_content",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            latencyMs: result.latencyMs,
            status: "success",
            timestamp: new Date().toISOString(),
            projectId: project.id
        });
        return {
            success: true,
            data: result.data,
            meta: {
                model: result.model,
                latencyMs: result.latencyMs,
                tokens: result.totalTokens
            }
        };
    }
    catch (err) {
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "marketing_content",
            model: "gemini-1.5-flash",
            latencyMs,
            status: "failed",
            errorMessage: err instanceof Error ? err.message : String(err),
            timestamp: new Date().toISOString(),
            projectId: request.data?.project?.id
        });
        throw error_handler_1.ErrorHandler.handle(err, "generateMarketingContent", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Get AI Usage Stats
 */
exports.getAIUsageStats = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const stats = await ai_usage_service_1.AIUsageService.getAgentStats(callerUid);
        return {
            success: true,
            data: stats
        };
    }
    catch (err) {
        throw error_handler_1.ErrorHandler.handle(err, "getAIUsageStats", { ownerId: callerUid });
    }
});
//# sourceMappingURL=index.js.map