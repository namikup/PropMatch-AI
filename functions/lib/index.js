"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.metaWebhookHandler = exports.syncMetaFormLeads = exports.listMetaAssets = exports.generateMetaCampaignAIIntelligence = exports.getMetaCampaigns = exports.syncMetaCampaigns = exports.disconnectMetaAccount = exports.connectMetaAccount = exports.getMetaConnectionStatus = exports.distributePlatformLead = exports.updateIncomingEnquiryStatus = exports.getIncomingEnquiries = exports.ingestLeadEnquiry = exports.importProspectsBatch = exports.getAudienceSegments = exports.getPropertyAnalysis = exports.getAIUsageStats = exports.generateMarketingContent = exports.getMatches = exports.matchBuyers = exports.discoverAudienceSegments = exports.analyzeProperty = exports.metaWebhookVerifyToken = exports.metaAppSecret = exports.geminiApiKey = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const ai_request_validator_1 = require("./validators/ai_request_validator");
const gemini_service_1 = require("./services/gemini_service");
const deterministic_matching_1 = require("./services/deterministic_matching");
const ai_usage_service_1 = require("./services/ai_usage_service");
const error_handler_1 = require("./utils/error_handler");
const logger_1 = require("./utils/logger");
const firebase_config_1 = require("./config/firebase.config");
const gemini_config_1 = require("./config/gemini.config");
const prospect_import_service_1 = require("./services/prospect_import_service");
const lead_ingestion_service_1 = require("./services/lead_ingestion_service");
const meta_ads_service_1 = require("./services/meta_ads_service");
/**
 * Secret Manager binding for Gemini Developer API and Meta Advertising Integration.
 * Securely injected by Google Cloud Secret Manager at function execution time.
 */
exports.geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
exports.metaAppSecret = (0, params_1.defineSecret)("META_APP_SECRET");
exports.metaWebhookVerifyToken = (0, params_1.defineSecret)("META_WEBHOOK_VERIFY_TOKEN");
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
        const key = exports.geminiApiKey.value() || process.env.GEMINI_API_KEY || "";
        if (key && !process.env.GEMINI_API_KEY) {
            process.env.GEMINI_API_KEY = key;
        }
        return key;
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
 * Callable Function: Discover Audience Segments (Module B - Phase 3.3A)
 */
exports.discoverAudienceSegments = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    try {
        // 1. Validate project and multi-tenant ownership
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
        const forceRefresh = request.data?.forceRefresh === true;
        const existingAnalysis = request.data?.existingAnalysis;
        const agentObservations = typeof request.data?.agentObservations === "string"
            ? request.data.agentObservations.trim()
            : "";
        // 2. Deterministic fingerprint for audience discovery
        const audienceFingerprint = `${project.name}|${project.startingPrice}|${project.maximumPrice}|${project.propertyType}|${project.builtUpArea}|${project.bedrooms}|${project.bathrooms}|${project.facilities.join(",")}|${project.purpose}|${project.description}|${agentObservations}`;
        const audienceDocRef = firebase_config_1.collections.audienceSegments.doc(`${project.id}_audience`);
        // 3. Check Firestore Cache
        try {
            if (!forceRefresh) {
                const cachedDoc = await audienceDocRef.get();
                if (cachedDoc.exists) {
                    const cached = cachedDoc.data();
                    if (cached && cached.ownerId !== callerUid) {
                        throw new https_1.HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
                    }
                    const isFingerprintMatch = cached?.sourceVersion === audienceFingerprint;
                    const isFresh = cached?.generatedAt && (Date.now() - new Date(cached.generatedAt).getTime() < 24 * 3600 * 1000);
                    if (isFingerprintMatch && isFresh) {
                        logger_1.Logger.info("Serving audience discovery from Firestore cache", {
                            ownerId: callerUid,
                            projectId: project.id
                        });
                        return {
                            success: true,
                            data: cached.data || { audience_segments: cached.segments, overview: cached.overview },
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
            logger_1.Logger.warn("Audience cache check bypassed", { error: String(cacheErr) });
        }
        // 4. Atomic Quota Reservation
        await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
        logger_1.Logger.info("Executing discoverAudienceSegments", {
            ownerId: callerUid,
            projectId: project.id,
            hasObservations: agentObservations.length > 0
        });
        // 5. Execute Gemini AI
        const result = await gemini_service_1.GeminiService.discoverAudienceSegments(project, existingAnalysis, agentObservations);
        // 6. Record quota success & usage logs
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
        // 7. Persist complete audience discovery audit document to Firestore
        try {
            await audienceDocRef.set({
                id: audienceDocRef.id,
                ownerId: callerUid,
                projectId: project.id,
                name: `Audience Discovery - ${project.name}`,
                data: result.data,
                segments: result.data.audience_segments,
                overview: result.data.overview,
                model: result.model,
                generatedAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                sourceVersion: audienceFingerprint,
                agentObservations,
                isLiveAI: true,
                disclaimer: "AI-generated audience hypothesis — not verified market demand."
            });
        }
        catch (saveErr) {
            logger_1.Logger.warn("Failed to cache audience segments in Firestore", { error: String(saveErr) });
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
 * Callable Function: Match Buyers (Module D - Phase 3.3B)
 */
exports.matchBuyers = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const startTime = Date.now();
    const config = (0, gemini_config_1.getGeminiConfig)(getRuntimeApiKey());
    try {
        const project = ai_request_validator_1.AIRequestValidator.validateProject(request.data?.project, callerUid);
        await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);
        const forceRefresh = request.data?.forceRefresh === true;
        // Retrieve or sanitize buyers
        let rawBuyers = request.data?.buyers;
        if (!Array.isArray(rawBuyers) || rawBuyers.length === 0) {
            const buyersSnap = await firebase_config_1.collections.buyers.where("ownerId", "==", callerUid).get();
            rawBuyers = buyersSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
        }
        // Strict multi-tenant verification & PDPA sanitization
        const sanitizedBuyers = ai_request_validator_1.AIRequestValidator.validateAndSanitizeBuyers(rawBuyers, callerUid);
        if (sanitizedBuyers.length === 0) {
            return {
                success: true,
                data: {
                    matches: [],
                    overview: {
                        total_evaluated: 0,
                        excellent_matches: 0,
                        good_matches: 0,
                        moderate_matches: 0,
                        low_matches: 0,
                        average_score: 0
                    }
                },
                meta: {
                    model: "deterministic",
                    latencyMs: Date.now() - startTime,
                    tokens: 0,
                    cached: false
                }
            };
        }
        // 1. Calculate deterministic matches strictly adhering to 5 weighted dimensions
        const deterministicOutput = deterministic_matching_1.DeterministicMatchingEngine.calculateMatches(sanitizedBuyers, project);
        // 2. Deterministic fingerprint for cache validation
        const buyersSignature = sanitizedBuyers
            .map((b) => `${b.id}:${b.budgetMin}-${b.budgetMax}:${b.preferredLocation}:${b.preferredState}:${b.propertyType}:${b.purchasePurpose}:${b.buyingTimeline}`)
            .sort()
            .join(";");
        const matchFingerprint = `${project.id}|${project.startingPrice}|${project.maximumPrice}|${project.location}|${project.state}|${project.propertyType}|${buyersSignature}`;
        const matchDocRef = firebase_config_1.collections.matches.doc(`${project.id}_matches`);
        // 3. Cache lookup
        try {
            if (!forceRefresh) {
                const cachedDoc = await matchDocRef.get();
                if (cachedDoc.exists) {
                    const cached = cachedDoc.data();
                    if (cached && cached.ownerId !== callerUid) {
                        throw new https_1.HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
                    }
                    const isFingerprintMatch = cached?.sourceVersion === matchFingerprint;
                    const isFresh = cached?.generatedAt && Date.now() - new Date(cached.generatedAt).getTime() < 24 * 3600 * 1000;
                    if (isFingerprintMatch && isFresh) {
                        logger_1.Logger.info("Serving buyer matches from Firestore cache", {
                            ownerId: callerUid,
                            projectId: project.id
                        });
                        return {
                            success: true,
                            data: cached.data || { matches: cached.matches, overview: cached.overview },
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
            logger_1.Logger.warn("Buyer matching cache check bypassed", { error: String(cacheErr) });
        }
        // 4. Reserve Quota for AI explanation layer
        await ai_usage_service_1.AIUsageService.reserveQuotaAtomic(callerUid);
        let finalOutput = deterministicOutput;
        let modelUsed = config.primaryModel;
        let tokensUsed = 0;
        let isLiveAI = false;
        try {
            logger_1.Logger.info("Executing Gemini advisory layer for matchBuyers", {
                ownerId: callerUid,
                projectId: project.id,
                buyerCount: sanitizedBuyers.length
            });
            const aiResult = await gemini_service_1.GeminiService.matchBuyers(project, sanitizedBuyers, deterministicOutput);
            finalOutput = aiResult.data;
            modelUsed = aiResult.model;
            tokensUsed = aiResult.totalTokens;
            isLiveAI = true;
            await ai_usage_service_1.AIUsageService.recordQuotaSuccess(callerUid);
            await ai_usage_service_1.AIUsageService.logUsage({
                ownerId: callerUid,
                feature: "buyer_matching",
                model: modelUsed,
                promptTokens: aiResult.promptTokens,
                candidateTokens: aiResult.candidateTokens,
                totalTokens: aiResult.totalTokens,
                tokenSource: "provider_metadata",
                isEstimated: false,
                latencyMs: aiResult.latencyMs,
                status: "success",
                timestamp: new Date().toISOString(),
                projectId: project.id
            });
        }
        catch (aiErr) {
            // Graceful fallback to deterministic engine on AI failure
            logger_1.Logger.warn("Gemini explanation layer failed; falling back to deterministic matches", {
                error: String(aiErr)
            });
            await ai_usage_service_1.AIUsageService.rollbackQuotaReservation(callerUid);
            await ai_usage_service_1.AIUsageService.logUsage({
                ownerId: callerUid,
                feature: "buyer_matching",
                model: config.primaryModel,
                latencyMs: Date.now() - startTime,
                status: "failed",
                errorMessage: aiErr instanceof Error ? aiErr.message : String(aiErr),
                timestamp: new Date().toISOString(),
                projectId: project.id
            });
            finalOutput = deterministicOutput;
            isLiveAI = false;
        }
        // 5. Persist audit & cache document to Firestore
        try {
            await matchDocRef.set({
                id: matchDocRef.id,
                ownerId: callerUid,
                projectId: project.id,
                name: `Buyer Matches - ${project.name}`,
                data: finalOutput,
                matches: finalOutput.matches,
                overview: finalOutput.overview,
                model: modelUsed,
                generatedAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                sourceVersion: matchFingerprint,
                isLiveAI,
                calculationSource: isLiveAI
                    ? "Deterministic Scoring + Gemini Advisory Layer"
                    : "Rule-based Deterministic Engine (Fallback)"
            });
        }
        catch (saveErr) {
            logger_1.Logger.warn("Failed to cache buyer matches in Firestore", { error: String(saveErr) });
        }
        return {
            success: true,
            data: finalOutput,
            meta: {
                model: modelUsed,
                latencyMs: Date.now() - startTime,
                tokens: tokensUsed,
                cached: false,
                isLiveAI
            }
        };
    }
    catch (err) {
        throw error_handler_1.ErrorHandler.handle(err, "matchBuyers", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Get Matches (Fast Firestore Cached Retrieval)
 */
exports.getMatches = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const projectId = request.data?.projectId;
    if (typeof projectId !== "string" || projectId.trim() === "") {
        throw new https_1.HttpsError("invalid-argument", "Missing or invalid 'projectId'.");
    }
    await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);
    try {
        const docRef = firebase_config_1.collections.matches.doc(`${projectId}_matches`);
        const docSnap = await docRef.get();
        if (!docSnap.exists) {
            return { success: true, data: null };
        }
        const data = docSnap.data();
        if (data && data.ownerId !== callerUid) {
            throw new https_1.HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
        }
        return {
            success: true,
            data: data?.data || { matches: data?.matches, overview: data?.overview },
            meta: {
                generatedAt: data?.generatedAt,
                isLiveAI: data?.isLiveAI,
                calculationSource: data?.calculationSource
            }
        };
    }
    catch (err) {
        throw error_handler_1.ErrorHandler.handle(err, "getMatches", { ownerId: callerUid, projectId });
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
/**
 * Callable Function: Get Existing Audience Discovery Segments (Module B Retrieval)
 * Allows retrieving previously persisted audience segments from Firestore without re-invoking AI.
 */
exports.getAudienceSegments = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const projectId = request.data?.projectId;
    if (!projectId || typeof projectId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing required projectId.");
    }
    await ai_request_validator_1.AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);
    const audienceDocRef = firebase_config_1.collections.audienceSegments.doc(`${projectId}_audience`);
    const doc = await audienceDocRef.get();
    if (!doc.exists) {
        return { success: true, data: null };
    }
    const data = doc.data();
    if (!data || data.ownerId !== callerUid) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized access to audience segments.");
    }
    return {
        success: true,
        data: data.data || { audience_segments: data.segments, overview: data.overview },
        meta: {
            cached: true,
            model: data.model,
            generatedAt: data.generatedAt,
            sourceVersion: data.sourceVersion
        }
    };
});
/**
 * Callable Function: Batch Import Prospects (Phase 4.2 CRM Import Engine)
 */
exports.importProspectsBatch = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const candidates = request.data?.candidates;
    const duplicateStrategy = request.data?.duplicateStrategy || "skip";
    const sourceFileName = request.data?.sourceFileName || "CRM_Import.csv";
    const jobId = request.data?.jobId;
    const fileSizeBytes = typeof request.data?.fileSizeBytes === "number"
        ? request.data.fileSizeBytes
        : undefined;
    try {
        const result = await prospect_import_service_1.ProspectImportService.validateAndProcessBatch(callerUid, candidates, duplicateStrategy, sourceFileName, jobId, fileSizeBytes);
        return { success: true, data: result };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "importProspectsBatch", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Ingest Lead Enquiry (Phase 4.3 Lead Ingestion Pipeline)
 */
exports.ingestLeadEnquiry = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const input = request.data;
    if (!input || typeof input !== "object") {
        throw new https_1.HttpsError("invalid-argument", "Missing enquiry data payload.");
    }
    try {
        const result = await lead_ingestion_service_1.LeadIngestionService.processEnquiry(callerUid, input);
        return { success: result.success, data: result };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "ingestLeadEnquiry", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Get Incoming Enquiries (Phase 4.3 Lead Ingestion Pipeline)
 */
exports.getIncomingEnquiries = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const sourceType = request.data?.sourceType;
    const status = request.data?.status;
    try {
        const data = await lead_ingestion_service_1.LeadIngestionService.getEnquiries(callerUid, { sourceType, status });
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "getIncomingEnquiries", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Update Incoming Enquiry Status (Phase 4.3.1 Security Hardened)
 */
exports.updateIncomingEnquiryStatus = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const enquiryId = request.data?.enquiryId;
    const newStatus = request.data?.status;
    if (!enquiryId || typeof enquiryId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing required enquiryId.");
    }
    if (!newStatus || typeof newStatus !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing required status.");
    }
    try {
        await lead_ingestion_service_1.LeadIngestionService.updateEnquiryStatus(callerUid, enquiryId, newStatus);
        return { success: true };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "updateIncomingEnquiryStatus", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Distribute Platform Lead (Phase 4.4 Channel B Routing Engine)
 */
exports.distributePlatformLead = (0, https_1.onCall)(callOptions, async (request) => {
    const input = request.data;
    if (!input || typeof input !== "object") {
        throw new https_1.HttpsError("invalid-argument", "Missing enquiry data payload.");
    }
    try {
        const result = await lead_ingestion_service_1.LeadIngestionService.distributePlatformEnquiry(input);
        return { success: result.success, data: result };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "distributePlatformLead");
    }
});
function getMetaAppSecret() {
    try {
        return exports.metaAppSecret.value() || process.env.META_APP_SECRET || "propmatch_meta_secret_2026";
    }
    catch (_) {
        return process.env.META_APP_SECRET || "propmatch_meta_secret_2026";
    }
}
function getMetaVerifyToken() {
    try {
        return exports.metaWebhookVerifyToken.value() || process.env.META_WEBHOOK_VERIFY_TOKEN || "propmatch_verify_token_2026";
    }
    catch (_) {
        return process.env.META_WEBHOOK_VERIFY_TOKEN || "propmatch_verify_token_2026";
    }
}
/**
 * Callable Function: Get Meta Connection Status (Phase 5.1 Meta Ads Intelligence)
 */
exports.getMetaConnectionStatus = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const data = await meta_ads_service_1.MetaAdsService.getConnectionStatus(callerUid);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "getMetaConnectionStatus", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Connect Meta Account (Phase 5.1 Meta Ads Intelligence)
 */
exports.connectMetaAccount = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const params = request.data;
    if (!params || typeof params !== "object") {
        throw new https_1.HttpsError("invalid-argument", "Missing connection parameters.");
    }
    try {
        const data = await meta_ads_service_1.MetaAdsService.connectAccount(callerUid, params);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "connectMetaAccount", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Disconnect Meta Account (Phase 5.1 Meta Ads Intelligence)
 */
exports.disconnectMetaAccount = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        await meta_ads_service_1.MetaAdsService.disconnectAccount(callerUid);
        return { success: true };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "disconnectMetaAccount", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Sync Meta Campaigns (Phase 5.1 Meta Ads Intelligence)
 */
exports.syncMetaCampaigns = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const data = await meta_ads_service_1.MetaAdsService.syncCampaigns(callerUid, request.data?.mockCampaigns);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "syncMetaCampaigns", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Get Meta Campaigns & Buyer Quality (Phase 5.1 Meta Ads Intelligence)
 */
exports.getMetaCampaigns = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const data = await meta_ads_service_1.MetaAdsService.getCampaigns(callerUid);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "getMetaCampaigns", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Generate Meta Campaign AI Intelligence (Phase 5.1 Meta Ads Intelligence)
 */
exports.generateMetaCampaignAIIntelligence = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const data = await meta_ads_service_1.MetaAdsService.generateAIIntelligence(callerUid);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "generateMetaCampaignAIIntelligence", { ownerId: callerUid });
    }
});
/**
 * Callable Function: List Meta Managed Assets (Phase 5.1A Meta Live Assets)
 */
exports.listMetaAssets = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    try {
        const data = await meta_ads_service_1.MetaAdsService.listAssets(callerUid);
        return { success: true, data };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "listMetaAssets", { ownerId: callerUid });
    }
});
/**
 * Callable Function: Bulk Sync Meta Form Leads (Phase 5.1A.3 Bulk Retrieval)
 * Queries /{form_id}/leads with pagination and date filtering, backfilling missed leads.
 */
exports.syncMetaFormLeads = (0, https_1.onCall)(callOptions, async (request) => {
    const callerUid = ai_request_validator_1.AIRequestValidator.validateAuth(request.auth?.uid);
    const formId = request.data?.formId;
    const pageId = request.data?.pageId;
    const sinceTimestamp = typeof request.data?.sinceTimestamp === "number" ? request.data.sinceTimestamp : undefined;
    if (!formId || typeof formId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing required formId.");
    }
    try {
        const credDoc = await firebase_config_1.collections.privateMetaCredentials.doc(callerUid).get();
        if (!credDoc.exists) {
            throw new https_1.HttpsError("failed-precondition", "Meta account is not connected.");
        }
        const creds = credDoc.data();
        const pageToken = (pageId && creds?.pageAccessTokens?.[pageId]) || creds?.accessToken;
        if (!pageToken) {
            throw new https_1.HttpsError("failed-precondition", "No valid access token available for Page.");
        }
        const result = await meta_ads_service_1.MetaAdsService.syncFormLeads(callerUid, formId, pageToken, { sinceTimestamp });
        return { success: true, data: result };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        throw error_handler_1.ErrorHandler.handle(err, "syncMetaFormLeads", { ownerId: callerUid });
    }
});
/**
 * HTTP Webhook Handler: Meta Webhook for Lead Ads (Phase 5.1 Meta Ads Intelligence)
 * Supports GET subscription verification and POST leadgen event reception with HMAC verification.
 */
exports.metaWebhookHandler = (0, https_1.onRequest)({ region: "asia-southeast1", cors: true }, async (req, res) => {
    // 1. Subscription Verification Handshake (GET)
    if (req.method === "GET") {
        const mode = req.query["hub.mode"];
        const token = req.query["hub.verify_token"];
        const challenge = req.query["hub.challenge"];
        const expectedToken = getMetaVerifyToken();
        if (mode === "subscribe" && token === expectedToken) {
            logger_1.Logger.info("Meta Webhook verification handshake successful");
            res.status(200).send(challenge);
            return;
        }
        else {
            logger_1.Logger.warn("Meta Webhook verification failed: invalid token", {
                receivedLength: typeof token === "string" ? token.length : 0
            });
            res.status(403).send("Forbidden: Invalid verification token");
            return;
        }
    }
    // 2. Real-Time Event Notification (POST)
    if (req.method === "POST") {
        const signature = req.headers["x-hub-signature-256"];
        const appSecret = getMetaAppSecret();
        const rawBody = typeof req.rawBody === "object" ? req.rawBody : Buffer.from(JSON.stringify(req.body));
        const isValidSignature = meta_ads_service_1.MetaAdsService.verifyWebhookSignature(rawBody, signature, appSecret);
        if (!isValidSignature && process.env.NODE_ENV !== "test") {
            logger_1.Logger.warn("Meta Webhook signature verification failed");
            res.status(401).send("Unauthorized: Invalid signature");
            return;
        }
        try {
            const body = req.body;
            if (body.object === "page") {
                for (const entry of body.entry || []) {
                    const pageId = entry.id;
                    for (const change of entry.changes || []) {
                        if (change.field === "leadgen") {
                            const leadData = change.value;
                            const leadgenId = leadData.leadgen_id;
                            const formId = leadData.form_id;
                            const adId = leadData.ad_id;
                            const campaignId = leadData.campaign_id;
                            const createdTime = leadData.created_time || Math.floor(Date.now() / 1000);
                            // Look up which agent owns this Facebook Page
                            const pageOwnerSnap = await firebase_config_1.collections.metaConnections
                                .where("facebookPageId", "==", pageId)
                                .limit(1)
                                .get();
                            let ownerId = "";
                            if (!pageOwnerSnap.empty) {
                                ownerId = pageOwnerSnap.docs[0].id;
                            }
                            else if (process.env.TEST_AGENT_ID) {
                                // Fall back to explicitly configured local test agent in emulator testing
                                ownerId = process.env.TEST_AGENT_ID;
                            }
                            else {
                                logger_1.Logger.warn("Meta Webhook: Unmapped Facebook Page ID; no matching agent connection found in meta_connections", {
                                    pageId,
                                    leadgenId
                                });
                                continue; // Reject unmapped Pages to prevent accidental cross-agent attribution
                            }
                            let fieldData = leadData.field_data || [];
                            let leadDataSource = 'REAL_META_API';
                            let fetchFailed = false;
                            let fetchErrorMessage = "";
                            if (fieldData.length === 0) {
                                try {
                                    const credDoc = await firebase_config_1.collections.privateMetaCredentials.doc(ownerId).get();
                                    if (credDoc.exists) {
                                        const creds = credDoc.data();
                                        const pageToken = creds?.pageAccessTokens?.[pageId] || creds?.accessToken;
                                        if (pageToken && !pageToken.includes("SECRET_ACCESS_TOKEN")) {
                                            const liveLead = await meta_ads_service_1.MetaAdsService.fetchLeadDetailsFromGraphApi(leadgenId, pageToken);
                                            fieldData = liveLead.fieldData;
                                            leadDataSource = liveLead.dataSource || 'REAL_META_API';
                                        }
                                        else {
                                            leadDataSource = pageToken?.includes("SECRET_ACCESS_TOKEN") ? 'MOCK_SIMULATED' : 'NOT_CONNECTED';
                                        }
                                    }
                                    else {
                                        leadDataSource = 'NOT_CONNECTED';
                                    }
                                }
                                catch (fetchErr) {
                                    fetchFailed = true;
                                    fetchErrorMessage = fetchErr instanceof Error ? fetchErr.message : String(fetchErr);
                                    logger_1.Logger.error("Graph API lead fetch failed due to permission or authorization error", fetchErr, { leadgenId, ownerId });
                                }
                            }
                            // If lead retrieval failed or no answers could be retrieved, do NOT create fake successful leads
                            if (fetchFailed || (fieldData.length === 0 && leadDataSource === 'NOT_CONNECTED')) {
                                logger_1.Logger.warn("Suppressing lead prospect creation due to failed Meta authorization or missing credentials", {
                                    leadgenId,
                                    ownerId,
                                    error: fetchErrorMessage
                                });
                                await firebase_config_1.collections.metaSyncLogs.add({
                                    ownerId,
                                    leadgenId,
                                    status: "Authorization Failed",
                                    error: fetchErrorMessage || "Meta access token invalid, expired, or missing required permissions",
                                    timestamp: new Date().toISOString()
                                });
                                await firebase_config_1.collections.metaConnections.doc(ownerId).update({
                                    lastSyncError: fetchErrorMessage || "Failed to retrieve lead questionnaire data from Meta Graph API",
                                    connectionStatus: "Reauthorization Required"
                                });
                                continue;
                            }
                            await meta_ads_service_1.MetaAdsService.ingestMetaLead(ownerId, {
                                leadgenId,
                                formId,
                                pageId,
                                adId,
                                campaignId,
                                createdTime,
                                fieldData,
                                dataSource: leadDataSource,
                                rawMetadata: {
                                    webhookEntryId: entry.id,
                                    webhookTime: entry.time,
                                    webhookField: change.field,
                                    rawLeadData: leadData
                                }
                            });
                        }
                    }
                }
            }
            res.status(200).send("EVENT_RECEIVED");
        }
        catch (err) {
            logger_1.Logger.error("Error processing Meta webhook event", err);
            res.status(500).send("Internal Server Error");
        }
    }
});
//# sourceMappingURL=index.js.map