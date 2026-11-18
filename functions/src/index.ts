import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AIRequestValidator } from "./validators/ai_request_validator";
import { GeminiService } from "./services/gemini_service";
import { AIUsageService } from "./services/ai_usage_service";
import { ErrorHandler } from "./utils/error_handler";
import { Logger } from "./utils/logger";
import { collections } from "./config/firebase.config";

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
export const analyzeProperty = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();

  try {
    // 1. Quota Check
    const quota = await AIUsageService.checkQuota(callerUid);
    if (!quota.isAllowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`
      );
    }

    // 2. Validate input and verify multi-tenant project ownership
    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);

    Logger.info("Executing analyzeProperty", { ownerId: callerUid, projectId: project.id });

    // 3. Execute Gemini LLM call
    const result = await GeminiService.analyzeProperty(project);

    // 4. Record usage in Firestore
    await AIUsageService.logUsage({
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
      const analysisDocRef = collections.propertyAnalyses.doc(`${project.id}_analysis`);
      await analysisDocRef.set({
        id: analysisDocRef.id,
        projectId: project.id,
        ownerId: callerUid,
        analysis: result.data,
        model: result.model,
        updatedAt: new Date().toISOString()
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
        tokens: result.totalTokens
      }
    };
  } catch (err: unknown) {
    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "property_analysis",
      model: "gemini-1.5-flash",
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
 * Callable Function: Discover Audience Segments (Module B)
 */
export const discoverAudienceSegments = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();

  try {
    const quota = await AIUsageService.checkQuota(callerUid);
    if (!quota.isAllowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`
      );
    }

    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    Logger.info("Executing discoverAudienceSegments", { ownerId: callerUid, projectId: project.id });

    const result = await GeminiService.discoverAudienceSegments(project);

    await AIUsageService.logUsage({
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
  } catch (err: unknown) {
    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "audience_discovery",
      model: "gemini-1.5-flash",
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
 * Callable Function: Match Buyers (Module D)
 */
export const matchBuyers = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();

  try {
    const quota = await AIUsageService.checkQuota(callerUid);
    if (!quota.isAllowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`
      );
    }

    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
    const sanitizedBuyers = AIRequestValidator.validateAndSanitizeBuyers(request.data?.buyers, callerUid);

    Logger.info("Executing matchBuyers", {
      ownerId: callerUid,
      projectId: project.id,
      buyerCount: sanitizedBuyers.length
    });

    const result = await GeminiService.matchBuyers(project, sanitizedBuyers);

    await AIUsageService.logUsage({
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
  } catch (err: unknown) {
    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "buyer_matching",
      model: "gemini-1.5-flash",
      latencyMs,
      status: "failed",
      errorMessage: err instanceof Error ? err.message : String(err),
      timestamp: new Date().toISOString(),
      projectId: request.data?.project?.id
    });

    throw ErrorHandler.handle(err, "matchBuyers", { ownerId: callerUid });
  }
});

/**
 * Callable Function: Generate Marketing Content (Module E)
 */
export const generateMarketingContent = onCall(callOptions, async (request) => {
  const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);
  const startTime = Date.now();

  try {
    const quota = await AIUsageService.checkQuota(callerUid);
    if (!quota.isAllowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI quota exceeded (${quota.currentMonthRequests}/${quota.monthlyQuota}).`
      );
    }

    const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
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

    await AIUsageService.logUsage({
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
  } catch (err: unknown) {
    const latencyMs = Date.now() - startTime;
    await AIUsageService.logUsage({
      ownerId: callerUid,
      feature: "marketing_content",
      model: "gemini-1.5-flash",
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
