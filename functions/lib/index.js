"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPropertyAnalysis = exports.getAIUsageStats = exports.generateMarketingContent = exports.matchBuyers = exports.discoverAudienceSegments = exports.analyzeProperty = exports.geminiApiKey = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const ai_request_validator_1 = require("./validators/ai_request_validator");
const gemini_service_1 = require("./services/gemini_service");
const ai_usage_service_1 = require("./services/ai_usage_service");
const error_handler_1 = require("./utils/error_handler");
const logger_1 = require("./utils/logger");
const firebase_config_1 = require("./config/firebase.config");
const gemini_config_1 = require("./config/gemini.config");
/**
 * Secret Manager binding for Gemini Developer API.
 * Securely injected by Google Cloud Secret Manager at function execution time.
 */
exports.geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
/**
 * Deployment options for Firebase Cloud Functions v2.
 * Region: asia-southeast1 (Singapore — optimized for Malaysian latency).
 *
 * App Check Notice:
 * App Check enforcement is pre-configured and ready. To prevent local web emulator
 * lockouts before the web reCAPTCHA key is provisioned, enforceAppCheck remains
 * false until explicitly authorized by DevOps.
 */
const callOptions = {
    cors: true,
    region: "asia-southeast1",
    timeoutSeconds: 60,
    maxInstances: 10,
    secrets: [exports.geminiApiKey],
    enforceAppCheck: false // Configured for future production rollout
};
function getRuntimeApiKey() {
    try {
        return exports.geminiApiKey.value() || process.env.GEMINI_API_KEY || "";
    }
    catch (_) {
        return process.env.GEMINI_API_KEY || "";
    }
}
/**
 * Callable Function: Analyze Property (Module A)
 */
exports.analyzeProperty = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    // 1. Atomic Quota Reservation (Prevents concurrent race condition)
    await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
    try {
        // 2. Validate input and verify multi-tenant project ownership
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
        logger_1.Logger.info("Executing analyzeProperty", { ownerId: callerUid, projectId: project.id });
        // Deterministic project fingerprint for cache validation and automatic invalidation
        const projectFingerprint = `${project.name}|${project.startingPrice}|${project.maximumPrice}|${project.propertyType}|${project.builtUpArea}|${project.bedrooms}|${project.bathrooms}|${project.facilities.join(",")}|${project.purpose}|${project.description}`.trim();
        // 3. Duplicate Suppression & Firestore Analysis Cache Check (24-hour cache)
        const analysisDocRef = firebase_config_1.collections.propertyAnalyses.doc(`${project.id}_analysis`);
        try {
            const cachedDoc = await analysisDocRef.get();
            if (cachedDoc.exists) {
                const cached = cachedDoc.data();
                // Prevent cross-agent cache leakage
                if (cached && cached.ownerId === callerUid && cached.updatedAt) {
                    const cacheAgeMs = Date.now() - new Date(cached.updatedAt).getTime();
                    const oneDayMs = 24 * 60 * 60 * 1000;
                    const isSameVersion = cached.sourceVersion === projectFingerprint;
                    // Return cached analysis if within TTL, project fingerprint matches, and forceRefresh is false
                    if (cacheAgeMs < oneDayMs && isSameVersion && !request.data?.forceRefresh) {
                        logger_1.Logger.info("Returning cached property analysis", { projectId: project.id });
                        await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
                        return {
                            success: true,
                            data: cached.analysisResult || cached.analysis,
                            meta: {
                                model: cached.model || config.primaryModel,
                                latencyMs: 5,
                                tokens: 0,
                                cached: true
                            }
                        };
                    }
                }
            }
        }
        catch (cacheErr) {
            logger_1.Logger.warn("Cache check bypassed", { error: String(cacheErr) });
        }
        // 4. Execute Gemini LLM call
        const result = await gemini_service_1.GeminiService.analyzeProperty(project);
        // 5. Record quota success
        await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
        // 6. Record usage in Firestore
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "property_analysis",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            tokenSource: "provider_metadata",
            isEstimated: false,
            latencyMs: result.latencyMs,
            status: "success",
            timestamp: new Date().toISOString(),
            projectId: project.id
        });
        // 7. Persist property analysis record into Firestore with required audit & cache schema
        try {
            await analysisDocRef.set({
                id: analysisDocRef.id,
                ownerId: callerUid,
                projectId: project.id,
                projectSnapshot: {
                    name: project.name,
                    developer: project.developer,
                    location: project.location,
                    state: project.state,
                    propertyType: project.propertyType,
                    startingPrice: project.startingPrice,
                    maximumPrice: project.maximumPrice,
                    bedrooms: project.bedrooms,
                    bathrooms: project.bathrooms,
                    builtUpArea: project.builtUpArea,
                    facilities: project.facilities,
                    purpose: project.purpose,
                    description: project.description
                },
                analysisResult: result.data,
                analysis: result.data, // backward compatibility
                model: result.model,
                generatedAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                sourceVersion: projectFingerprint,
                isLiveAI: true,
                generationStatus: "completed"
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
                tokens: result.totalTokens,
                cached: false
            }
        };
    }
    catch (err) {
        // Atomic rollback ensures failed calls do NOT consume user quota
        await ai_usage_service_1.AIUsageService.rollbackQuotaReservation(callerUid);
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "property_analysis",
            model: config.primaryModel,
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
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
    try {
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
        logger_1.Logger.info("Executing discoverAudienceSegments", { ownerId: callerUid, projectId: project.id });
        const result = await gemini_service_1.GeminiService.discoverAudienceSegments(project);
        await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "audience_discovery",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            tokenSource: "provider_metadata",
            isEstimated: false,
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
        await ai_usage_service_1.AIUsageService.rollbackQuotaReservation(callerUid);
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "audience_discovery",
            model: config.primaryModel,
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
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
    try {
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
        // Strict multi-tenant verification: validates that all buyers belong to caller & strips PII
        const sanitizedBuyers = ai_request_validator_1.AIRequestValidator.validateAndSanitizeBuyers(request.data?.buyers, callerUid);
        logger_1.Logger.info("Executing matchBuyers", {
            ownerId: callerUid,
            projectId: project.id,
            buyerCount: sanitizedBuyers.length
        });
        const result = await gemini_service_1.GeminiService.matchBuyers(project, sanitizedBuyers);
        await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "buyer_matching",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            tokenSource: "provider_metadata",
            isEstimated: false,
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
        await ai_usage_service_1.AIUsageService.rollbackQuotaReservation(callerUid);
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "buyer_matching",
            model: config.primaryModel,
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
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
    try {
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
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
        await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "marketing_content",
            model: result.model,
            promptTokens: result.promptTokens,
            candidateTokens: result.candidateTokens,
            totalTokens: result.totalTokens,
            tokenSource: "provider_metadata",
            isEstimated: false,
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
        await ai_usage_service_1.AIUsageService.rollbackQuotaReservation(callerUid);
        const latencyMs = Date.now() - startTime;
        await ai_usage_service_1.AIUsageService.logUsage({
            ownerId: callerUid,
            feature: "marketing_content",
            model: config.primaryModel,
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
/**
 * Callable Function: Get Existing Property Analysis (Module A Retrieval)
 * Allows retrieving previously persisted analysis from Firestore without re-invoking AI.
 */
exports.getPropertyAnalysis = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const projectId = request.data?.projectId;
    if (!projectId || typeof projectId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing required projectId.");
    }
    await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);
    const analysisDocRef = firebase_config_1.collections.propertyAnalyses.doc(`${projectId}_analysis`);
    const doc = await analysisDocRef.get();
    if (!doc.exists) {
        return { success: true, data: null };
    }
    const data = doc.data();
    if (!data || data.ownerId !== callerUid) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized access to property analysis.");
    }
    return {
        success: true,
        data: data.analysisResult || data.analysis,
        meta: {
            cached: true,
            model: data.model,
            generatedAt: data.generatedAt,
            sourceVersion: data.sourceVersion
        }
    };
});
//# sourceMappingURL=index.js.map