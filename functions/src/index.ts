import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { AIRequestValidator } from "./validators/ai_request_validator";
import { GeminiService } from "./services/gemini_service";
import { DeterministicMatchingEngine } from "./services/deterministic_matching";
import { AIUsageService } from "./services/ai_usage_service";
import { ErrorHandler } from "./utils/error_handler";
import { Logger } from "./utils/logger";
import { collections } from "./config/firebase.config";
import { getGeminiConfig } from "./config/gemini.config";
import { ProspectImportService } from "./services/prospect_import_service";
import { LeadIngestionService } from "./services/lead_ingestion_service";
import { MetaAdsService } from "./services/meta_ads_service";

/**
 * Secret Manager binding for Gemini Developer API and Meta Advertising Integration.
 * Securely injected by Google Cloud Secret Manager at function execution time.
 */
export const geminiApiKey = defineSecret("GEMINI_API_KEY");
export const metaAppSecret = defineSecret("META_APP_SECRET");
export const metaWebhookVerifyToken = defineSecret("META_WEBHOOK_VERIFY_TOKEN");

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
  secrets: [geminiApiKey],
  enforceAppCheck: false // Configured for future production rollout
};

function getRuntimeApiKey(): string {
  try {
    const key = geminiApiKey.value() || process.env.GEMINI_API_KEY || "";
    if (key && !process.env.GEMINI_API_KEY) {
      process.env.GEMINI_API_KEY = key;
    }
    return key;
  } catch (_) {
    return process.env.GEMINI_API_KEY || "";
  }
}

/**
 * Callable Function: Analyze Property (Module A)
 */
export const analyzeProperty = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();
  const config = getGeminiConfig(getRuntimeApiKey());

  // 1. Atomic Quota Reservation (Prevents concurrent race condition)
  await AIUsageService.reserveQuotaAtomic(callerUid);

  try {
    // 2. Validate input and verify multi-tenant project ownership
    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    await AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);

    Logger.info("Executing analyzeProperty", { ownerId: callerUid, projectId: project.id });

    // Deterministic project fingerprint for cache validation and automatic invalidation
    const projectFingerprint = `${project.name}|${project.startingPrice}|${project.maximumPrice}|${project.propertyType}|${project.builtUpArea}|${project.bedrooms}|${project.bathrooms}|${project.facilities.join(",")}|${project.purpose}|${project.description}`.trim();

    // 3. Duplicate Suppression & Firestore Analysis Cache Check (24-hour cache)
    const analysisDocRef = collections.propertyAnalyses.doc(`${project.id}_analysis`);
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
            Logger.info("Returning cached property analysis", { projectId: project.id });
            await AIUsageService.recordQuotaSuccess(callerUid);
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
    } catch (cacheErr) {
      Logger.warn("Cache check bypassed", { error: String(cacheErr) });
    }

    // 4. Execute Gemini LLM call
    const result = await GeminiService.analyzeProperty(project);

    // 5. Record quota success
    await AIUsageService.recordQuotaSuccess(callerUid);

    // 6. Record usage in Firestore
    await AIUsageService.logUsage({
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
    } catch (saveErr) {
      Logger.warn("Failed to cache property analysis in Firestore", { error: String(saveErr) });
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
  } catch (err: unknown) {
    // Atomic rollback ensures failed calls do NOT consume user quota
    await AIUsageService.rollbackQuotaReservation(callerUid);

    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "property_analysis",
      model: config.primaryModel,
      latencyMs,
      status: "failed",
      errorMessage: err instanceof Error ? err.message : String(err),
      timestamp: new Date().toISOString(),
      projectId: request.data?.project?.id
    });

    throw ErrorHandler.handle(err, "analyzeProperty", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Discover Audience Segments (Module B - Phase 3.3A)
 */
export const discoverAudienceSegments = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();
  const config = getGeminiConfig(getRuntimeApiKey());

  try {
    // 1. Validate project and multi-tenant ownership
    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    await AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);

    const forceRefresh = request.data?.forceRefresh === true;
    const existingAnalysis = request.data?.existingAnalysis;
    const agentObservations = typeof request.data?.agentObservations === "string"
      ? request.data.agentObservations.trim()
      : "";

    // 2. Deterministic fingerprint for audience discovery
    const audienceFingerprint = `${project.name}|${project.startingPrice}|${project.maximumPrice}|${project.propertyType}|${project.builtUpArea}|${project.bedrooms}|${project.bathrooms}|${project.facilities.join(",")}|${project.purpose}|${project.description}|${agentObservations}`;

    const audienceDocRef = collections.audienceSegments.doc(`${project.id}_audience`);

    // 3. Check Firestore Cache
    try {
      if (!forceRefresh) {
        const cachedDoc = await audienceDocRef.get();
        if (cachedDoc.exists) {
          const cached = cachedDoc.data();
          if (cached && cached.ownerId !== callerUid) {
            throw new HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
          }

          const isFingerprintMatch = cached?.sourceVersion === audienceFingerprint;
          const isFresh = cached?.generatedAt && (Date.now() - new Date(cached.generatedAt).getTime() < 24 * 3600 * 1000);

          if (isFingerprintMatch && isFresh) {
            Logger.info("Serving audience discovery from Firestore cache", {
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
    } catch (cacheErr) {
      Logger.warn("Audience cache check bypassed", { error: String(cacheErr) });
    }

    // 4. Atomic Quota Reservation
    await AIUsageService.reserveQuotaAtomic(callerUid);

    Logger.info("Executing discoverAudienceSegments", {
      ownerId: callerUid,
      projectId: project.id,
      hasObservations: agentObservations.length > 0
    });

    // 5. Execute Gemini AI
    const result = await GeminiService.discoverAudienceSegments(
      project,
      existingAnalysis,
      agentObservations
    );

    // 6. Record quota success & usage logs
    await AIUsageService.recordQuotaSuccess(callerUid);

    await AIUsageService.logUsage({
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
    } catch (saveErr) {
      Logger.warn("Failed to cache audience segments in Firestore", { error: String(saveErr) });
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
  } catch (err: unknown) {
    await AIUsageService.rollbackQuotaReservation(callerUid);

    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "audience_discovery",
      model: config.primaryModel,
      latencyMs,
      status: "failed",
      errorMessage: err instanceof Error ? err.message : String(err),
      timestamp: new Date().toISOString(),
      projectId: request.data?.project?.id
    });

    throw ErrorHandler.handle(err, "discoverAudienceSegments", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Match Buyers (Module D - Phase 3.3B)
 */
export const matchBuyers = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();
  const config = getGeminiConfig(getRuntimeApiKey());

  try {
    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    await AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);

    const forceRefresh = request.data?.forceRefresh === true;

    // Retrieve or sanitize buyers
    let rawBuyers = request.data?.buyers;
    if (!Array.isArray(rawBuyers) || rawBuyers.length === 0) {
      const buyersSnap = await collections.buyers.where("ownerId", "==", callerUid).get();
      rawBuyers = buyersSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }

    // Strict multi-tenant verification & PDPA sanitization
    const sanitizedBuyers = AIRequestValidator.validateAndSanitizeBuyers(rawBuyers, callerUid);

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
    const deterministicOutput = DeterministicMatchingEngine.calculateMatches(sanitizedBuyers, project);

    // 2. Deterministic fingerprint for cache validation
    const buyersSignature = sanitizedBuyers
      .map(
        (b) =>
          `${b.id}:${b.budgetMin}-${b.budgetMax}:${b.preferredLocation}:${b.preferredState}:${b.propertyType}:${b.purchasePurpose}:${b.buyingTimeline}`
      )
      .sort()
      .join(";");
    const matchFingerprint = `${project.id}|${project.startingPrice}|${project.maximumPrice}|${project.location}|${project.state}|${project.propertyType}|${buyersSignature}`;

    const matchDocRef = collections.matches.doc(`${project.id}_matches`);

    // 3. Cache lookup
    try {
      if (!forceRefresh) {
        const cachedDoc = await matchDocRef.get();
        if (cachedDoc.exists) {
          const cached = cachedDoc.data();
          if (cached && cached.ownerId !== callerUid) {
            throw new HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
          }

          const isFingerprintMatch = cached?.sourceVersion === matchFingerprint;
          const isFresh =
            cached?.generatedAt && Date.now() - new Date(cached.generatedAt).getTime() < 24 * 3600 * 1000;

          if (isFingerprintMatch && isFresh) {
            Logger.info("Serving buyer matches from Firestore cache", {
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
    } catch (cacheErr) {
      Logger.warn("Buyer matching cache check bypassed", { error: String(cacheErr) });
    }

    // 4. Reserve Quota for AI explanation layer
    await AIUsageService.reserveQuotaAtomic(callerUid);

    let finalOutput = deterministicOutput;
    let modelUsed: string = config.primaryModel;
    let tokensUsed = 0;
    let isLiveAI = false;

    try {
      Logger.info("Executing Gemini advisory layer for matchBuyers", {
        ownerId: callerUid,
        projectId: project.id,
        buyerCount: sanitizedBuyers.length
      });

      const aiResult = await GeminiService.matchBuyers(project, sanitizedBuyers, deterministicOutput);
      finalOutput = aiResult.data;
      modelUsed = aiResult.model;
      tokensUsed = aiResult.totalTokens;
      isLiveAI = true;

      await AIUsageService.recordQuotaSuccess(callerUid);

      await AIUsageService.logUsage({
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
    } catch (aiErr: unknown) {
      // Graceful fallback to deterministic engine on AI failure
      Logger.warn("Gemini explanation layer failed; falling back to deterministic matches", {
        error: String(aiErr)
      });
      await AIUsageService.rollbackQuotaReservation(callerUid);

      await AIUsageService.logUsage({
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
    } catch (saveErr) {
      Logger.warn("Failed to cache buyer matches in Firestore", { error: String(saveErr) });
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
  } catch (err: unknown) {
    throw ErrorHandler.handle(err, "matchBuyers", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Get Matches (Fast Firestore Cached Retrieval)
 */
export const getMatches = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const projectId = request.data?.projectId;

  if (typeof projectId !== "string" || projectId.trim() === "") {
    throw new HttpsError("invalid-argument", "Missing or invalid 'projectId'.");
  }

  await AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);

  try {
    const docRef = collections.matches.doc(`${projectId}_matches`);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return { success: true, data: null };
    }

    const data = docSnap.data();
    if (data && data.ownerId !== callerUid) {
      throw new HttpsError("permission-denied", "Unauthorized cross-agent cache access detected.");
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
  } catch (err: unknown) {
    throw ErrorHandler.handle(err, "getMatches", { ownerId: callerUid, projectId });
  }
});

/**
 * Callable Function: Generate Marketing Content (Module E)
 */
export const generateMarketingContent = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();
  const config = getGeminiConfig(getRuntimeApiKey());

  await AIUsageService.reserveQuotaAtomic(callerUid);

  try {
    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    await AIRequestValidator.verifyProjectOwnershipInFirestore(project.id, callerUid);

    const segmentName = typeof request.data?.segmentName === "string" ? request.data.segmentName : "General Buyers";
    const channel = typeof request.data?.channel === "string" ? request.data.channel : "Facebook Ad";
    const language = ["en", "bm", "zh"].includes(request.data?.language) ? request.data.language : "en";

    Logger.info("Executing generateMarketingContent", {
      ownerId: callerUid,
      projectId: project.id,
      segmentName,
      channel,
      language
    });

    const result = await GeminiService.generateMarketingContent(project, segmentName, channel, language);

    await AIUsageService.recordQuotaSuccess(callerUid);

    await AIUsageService.logUsage({
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
  } catch (err: unknown) {
    await AIUsageService.rollbackQuotaReservation(callerUid);

    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "marketing_content",
      model: config.primaryModel,
      latencyMs,
      status: "failed",
      errorMessage: err instanceof Error ? err.message : String(err),
      timestamp: new Date().toISOString(),
      projectId: request.data?.project?.id
    });

    throw ErrorHandler.handle(err, "generateMarketingContent", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Get AI Usage Stats
 */
export const getAIUsageStats = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);

  try {
    const stats = await AIUsageService.getAgentStats(callerUid);
    return {
      success: true,
      data: stats
    };
  } catch (err: unknown) {
    throw ErrorHandler.handle(err, "getAIUsageStats", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Get Existing Property Analysis (Module A Retrieval)
 * Allows retrieving previously persisted analysis from Firestore without re-invoking AI.
 */
export const getPropertyAnalysis = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const projectId = request.data?.projectId;
  if (!projectId || typeof projectId !== "string") {
    throw new HttpsError("invalid-argument", "Missing required projectId.");
  }
  await AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);

  const analysisDocRef = collections.propertyAnalyses.doc(`${projectId}_analysis`);
  const doc = await analysisDocRef.get();
  if (!doc.exists) {
    return { success: true, data: null };
  }
  const data = doc.data();
  if (!data || data.ownerId !== callerUid) {
    throw new HttpsError("permission-denied", "Unauthorized access to property analysis.");
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
export const getAudienceSegments = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const projectId = request.data?.projectId;
  if (!projectId || typeof projectId !== "string") {
    throw new HttpsError("invalid-argument", "Missing required projectId.");
  }
  await AIRequestValidator.verifyProjectOwnershipInFirestore(projectId, callerUid);

  const audienceDocRef = collections.audienceSegments.doc(`${projectId}_audience`);
  const doc = await audienceDocRef.get();
  if (!doc.exists) {
    return { success: true, data: null };
  }
  const data = doc.data();
  if (!data || data.ownerId !== callerUid) {
    throw new HttpsError("permission-denied", "Unauthorized access to audience segments.");
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
export const importProspectsBatch = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const candidates = request.data?.candidates;
  const duplicateStrategy = request.data?.duplicateStrategy || "skip";
  const sourceFileName = request.data?.sourceFileName || "CRM_Import.csv";
  const jobId = request.data?.jobId;
  const fileSizeBytes = typeof request.data?.fileSizeBytes === "number"
    ? request.data.fileSizeBytes
    : undefined;

  try {
    const result = await ProspectImportService.validateAndProcessBatch(
      callerUid,
      candidates,
      duplicateStrategy,
      sourceFileName,
      jobId,
      fileSizeBytes
    );
    return { success: true, data: result };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "importProspectsBatch", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Ingest Lead Enquiry (Phase 4.3 Lead Ingestion Pipeline)
 */
export const ingestLeadEnquiry = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const input = request.data;
  if (!input || typeof input !== "object") {
    throw new HttpsError("invalid-argument", "Missing enquiry data payload.");
  }

  try {
    const result = await LeadIngestionService.processEnquiry(callerUid, input);
    return { success: result.success, data: result };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "ingestLeadEnquiry", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Get Incoming Enquiries (Phase 4.3 Lead Ingestion Pipeline)
 */
export const getIncomingEnquiries = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const sourceType = request.data?.sourceType;
  const status = request.data?.status;

  try {
    const data = await LeadIngestionService.getEnquiries(callerUid, { sourceType, status });
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "getIncomingEnquiries", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Update Incoming Enquiry Status (Phase 4.3.1 Security Hardened)
 */
export const updateIncomingEnquiryStatus = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const enquiryId = request.data?.enquiryId;
  const newStatus = request.data?.status;

  if (!enquiryId || typeof enquiryId !== "string") {
    throw new HttpsError("invalid-argument", "Missing required enquiryId.");
  }
  if (!newStatus || typeof newStatus !== "string") {
    throw new HttpsError("invalid-argument", "Missing required status.");
  }

  try {
    await LeadIngestionService.updateEnquiryStatus(callerUid, enquiryId, newStatus);
    return { success: true };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "updateIncomingEnquiryStatus", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Distribute Platform Lead (Phase 4.4 Channel B Routing Engine)
 */
export const distributePlatformLead = onCall(callOptions, async (request) => {
  const input = request.data;
  if (!input || typeof input !== "object") {
    throw new HttpsError("invalid-argument", "Missing enquiry data payload.");
  }

  try {
    const result = await LeadIngestionService.distributePlatformEnquiry(input);
    return { success: result.success, data: result };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "distributePlatformLead");
  }
});

function getMetaAppSecret(): string {
  try {
    return metaAppSecret.value() || process.env.META_APP_SECRET || "propmatch_meta_secret_2026";
  } catch (_) {
    return process.env.META_APP_SECRET || "propmatch_meta_secret_2026";
  }
}

function getMetaVerifyToken(): string {
  try {
    return metaWebhookVerifyToken.value() || process.env.META_WEBHOOK_VERIFY_TOKEN || "propmatch_verify_token_2026";
  } catch (_) {
    return process.env.META_WEBHOOK_VERIFY_TOKEN || "propmatch_verify_token_2026";
  }
}

/**
 * Callable Function: Get Meta Connection Status (Phase 5.1 Meta Ads Intelligence)
 */
export const getMetaConnectionStatus = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  try {
    const data = await MetaAdsService.getConnectionStatus(callerUid);
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "getMetaConnectionStatus", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Connect Meta Account (Phase 5.1 Meta Ads Intelligence)
 */
export const connectMetaAccount = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const params = request.data;
  if (!params || typeof params !== "object") {
    throw new HttpsError("invalid-argument", "Missing connection parameters.");
  }

  try {
    const data = await MetaAdsService.connectAccount(callerUid, params);
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "connectMetaAccount", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Disconnect Meta Account (Phase 5.1 Meta Ads Intelligence)
 */
export const disconnectMetaAccount = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  try {
    await MetaAdsService.disconnectAccount(callerUid);
    return { success: true };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "disconnectMetaAccount", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Sync Meta Campaigns (Phase 5.1 Meta Ads Intelligence)
 */
export const syncMetaCampaigns = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  try {
    const data = await MetaAdsService.syncCampaigns(callerUid, request.data?.mockCampaigns);
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "syncMetaCampaigns", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Get Meta Campaigns & Buyer Quality (Phase 5.1 Meta Ads Intelligence)
 */
export const getMetaCampaigns = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  try {
    const data = await MetaAdsService.getCampaigns(callerUid);
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "getMetaCampaigns", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Generate Meta Campaign AI Intelligence (Phase 5.1 Meta Ads Intelligence)
 */
export const generateMetaCampaignAIIntelligence = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  try {
    const data = await MetaAdsService.generateAIIntelligence(callerUid);
    return { success: true, data };
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    throw ErrorHandler.handle(err, "generateMetaCampaignAIIntelligence", { ownerId: callerUid });
  }
});

/**
 * HTTP Webhook Handler: Meta Webhook for Lead Ads (Phase 5.1 Meta Ads Intelligence)
 * Supports GET subscription verification and POST leadgen event reception with HMAC verification.
 */
export const metaWebhookHandler = onRequest(
  { region: "asia-southeast1", cors: true },
  async (req, res) => {
    // 1. Subscription Verification Handshake (GET)
    if (req.method === "GET") {
      const mode = req.query["hub.mode"];
      const token = req.query["hub.verify_token"];
      const challenge = req.query["hub.challenge"];

      const expectedToken = getMetaVerifyToken();
      if (mode === "subscribe" && token === expectedToken) {
        Logger.info("Meta Webhook verification handshake successful");
        res.status(200).send(challenge);
        return;
      } else {
        Logger.warn("Meta Webhook verification failed: invalid token", { receivedToken: token });
        res.status(403).send("Forbidden: Invalid verification token");
        return;
      }
    }

    // 2. Real-Time Event Notification (POST)
    if (req.method === "POST") {
      const signature = req.headers["x-hub-signature-256"] as string | undefined;
      const appSecret = getMetaAppSecret();

      const rawBody = typeof req.rawBody === "object" ? req.rawBody : Buffer.from(JSON.stringify(req.body));
      const isValidSignature = MetaAdsService.verifyWebhookSignature(rawBody, signature, appSecret);

      if (!isValidSignature && process.env.NODE_ENV !== "test") {
        Logger.warn("Meta Webhook signature verification failed");
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
                const pageOwnerSnap = await collections.metaConnections
                  .where("facebookPageId", "==", pageId)
                  .limit(1)
                  .get();

                const ownerId = pageOwnerSnap.empty
                  ? "pilot-agent-malik-001" // Default to designated pilot agent in pilot mode
                  : pageOwnerSnap.docs[0].id;

                await MetaAdsService.ingestMetaLead(ownerId, {
                  leadgenId,
                  formId,
                  pageId,
                  adId,
                  campaignId,
                  createdTime,
                  fieldData: leadData.field_data || []
                });
              }
            }
          }
        }
        res.status(200).send("EVENT_RECEIVED");
      } catch (err) {
        Logger.error("Error processing Meta webhook event", err);
        res.status(500).send("Internal Server Error");
      }
    }
  }
);
