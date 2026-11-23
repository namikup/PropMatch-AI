"use strict";
/**
 * PropMatch AI — Gemini Configuration & Model Registry
 *
 * Provider: Google AI Studio / Gemini Developer API (Endpoint: generativelanguage.googleapis.com)
 * SDK: @google/genai (Migrated from @google/generative-ai)
 * Documentation: https://ai.google.dev/gemini-api/docs/pricing
 * Migration Reference: https://ai.google.dev/gemini-api/docs/migrate
 * Verification Date: 2026-11-19
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.MODEL_PRICING_REGISTRY = exports.ACTIVE_SUPPORTED_MODELS = exports.RETIRED_MODELS = exports.OFFICIAL_PRICING_VERIFICATION_DATE = exports.OFFICIAL_PRICING_SOURCE_URL = void 0;
exports.getModelEffectivePricing = getModelEffectivePricing;
exports.validateModelIdentifier = validateModelIdentifier;
exports.validateFallbackCostPolicy = validateFallbackCostPolicy;
exports.getGeminiConfig = getGeminiConfig;
exports.OFFICIAL_PRICING_SOURCE_URL = "https://ai.google.dev/gemini-api/docs/pricing";
exports.OFFICIAL_PRICING_VERIFICATION_DATE = "2026-11-19";
/**
 * List of retired and shut-down Gemini models that must NOT be selected.
 * Attempting to configure any of these models triggers an immediate rejection.
 */
exports.RETIRED_MODELS = [
    "gemini-2.0-flash", // Shut down June 1, 2026
    "gemini-2.0-flash-lite", // Shut down
    "gemini-1.5-flash", // Retired
    "gemini-1.5-pro", // Retired
    "gemini-1.0-pro" // Retired
];
/**
 * Active supported models for the Gemini Developer API (verified November 2026).
 */
exports.ACTIVE_SUPPORTED_MODELS = [
    "gemini-3.5-flash-lite", // Primary: Fast, economical multimodal reasoning ($0.30 in / $2.50 out per 1M)
    "gemini-3.5-flash", // Fallback/Secondary: Balanced reasoning workhorse ($0.30 in / $2.50 out per 1M)
    "gemini-3.8-flash", // Advanced: Flagship enterprise agentic reasoning ($0.75 in / $3.75 out per 1M)
    "gemini-2.5-flash" // Legacy: Retained for backward compatibility (returns 404 for new keys)
];
/**
 * Official Google Gemini Developer API Pricing Registry (Per 1 Million Tokens).
 * Standard Tier (Synchronous, full base rate) — the only service tier implemented in PropMatch AI.
 * Source: https://ai.google.dev/gemini-api/docs/pricing (Verified: 2026-11-19)
 */
exports.MODEL_PRICING_REGISTRY = {
    "gemini-3.5-flash-lite": {
        inputPricePerMillion: 0.30,
        outputPricePerMillion: 2.50,
        thinkingTokenBilling: "billed_as_output",
        cachedInputPricePerMillion: 0.075,
        serviceTier: "standard",
        pricingEffectiveDate: "2026-11-19",
        freeTierAllowed: true,
        referenceFreeTierRpmLimit: 15,
        referenceFreeTierRpdLimit: 1500
    },
    "gemini-3.5-flash": {
        inputPricePerMillion: 0.30,
        outputPricePerMillion: 2.50,
        thinkingTokenBilling: "billed_as_output",
        cachedInputPricePerMillion: 0.075,
        serviceTier: "standard",
        pricingEffectiveDate: "2026-11-19",
        freeTierAllowed: true,
        referenceFreeTierRpmLimit: 15,
        referenceFreeTierRpdLimit: 1500
    },
    "gemini-2.5-flash": {
        inputPricePerMillion: 0.30,
        outputPricePerMillion: 2.50,
        thinkingTokenBilling: "billed_as_output",
        cachedInputPricePerMillion: 0.075,
        serviceTier: "standard",
        pricingEffectiveDate: "2026-11-19",
        freeTierAllowed: true,
        referenceFreeTierRpmLimit: 15,
        referenceFreeTierRpdLimit: 1500
    },
    "gemini-3.8-flash": {
        inputPricePerMillion: 0.75,
        outputPricePerMillion: 3.75,
        thinkingTokenBilling: "billed_as_output",
        cachedInputPricePerMillion: 0.1875,
        serviceTier: "standard",
        pricingEffectiveDate: "2026-11-19",
        // Model-specific pricing increase effective January 1, 2027 per Google Gemini API pricing schedule
        futurePricingEffective2027: {
            inputPricePerMillion: 1.50,
            outputPricePerMillion: 7.50,
            cachedInputPricePerMillion: 0.375,
            effectiveDate: "2027-01-01"
        },
        freeTierAllowed: true,
        referenceFreeTierRpmLimit: 10,
        referenceFreeTierRpdLimit: 1000
    }
};
/**
 * Resolves the effective pricing for a model based on execution date,
 * accounting for scheduled pricing adjustments (e.g. gemini-3.8-flash Jan 1, 2027).
 */
function getModelEffectivePricing(model, asOfDate = new Date()) {
    const pricing = exports.MODEL_PRICING_REGISTRY[model];
    if (pricing.futurePricingEffective2027) {
        const effectiveDate = new Date(pricing.futurePricingEffective2027.effectiveDate);
        if (asOfDate >= effectiveDate) {
            return {
                inputPricePerMillion: pricing.futurePricingEffective2027.inputPricePerMillion,
                outputPricePerMillion: pricing.futurePricingEffective2027.outputPricePerMillion,
                cachedInputPricePerMillion: pricing.futurePricingEffective2027.cachedInputPricePerMillion
            };
        }
    }
    return {
        inputPricePerMillion: pricing.inputPricePerMillion,
        outputPricePerMillion: pricing.outputPricePerMillion,
        cachedInputPricePerMillion: pricing.cachedInputPricePerMillion
    };
}
/**
 * Validates that a requested model identifier is active and not retired.
 */
function validateModelIdentifier(model, label = "Model") {
    if (!model || typeof model !== "string" || model.trim() === "") {
        throw new Error(`Configuration error: ${label} identifier cannot be empty or undefined.`);
    }
    const normalized = model.trim().toLowerCase();
    if (exports.RETIRED_MODELS.includes(normalized)) {
        throw new Error(`Configuration error: ${label} '${model}' is retired or shut down and no longer supported. Please migrate to one of: ${exports.ACTIVE_SUPPORTED_MODELS.join(", ")}.`);
    }
    if (!exports.ACTIVE_SUPPORTED_MODELS.includes(normalized)) {
        throw new Error(`Configuration error: ${label} '${model}' is unrecognized or unverified for Gemini Developer API. Supported active models: ${exports.ACTIVE_SUPPORTED_MODELS.join(", ")}.`);
    }
    return normalized;
}
/**
 * Validates that fallback model does NOT exceed the cost profile of primary model
 * without explicit configuration override.
 */
function validateFallbackCostPolicy(primaryModel, fallbackModel, allowExpensiveFallback = false, asOfDate = new Date()) {
    const primaryPricing = getModelEffectivePricing(primaryModel, asOfDate);
    const fallbackPricing = getModelEffectivePricing(fallbackModel, asOfDate);
    if (!allowExpensiveFallback) {
        if (fallbackPricing.inputPricePerMillion > primaryPricing.inputPricePerMillion ||
            fallbackPricing.outputPricePerMillion > primaryPricing.outputPricePerMillion) {
            throw new Error(`Cost Control Violation: Fallback model '${fallbackModel}' ($${fallbackPricing.inputPricePerMillion}/$${fallbackPricing.outputPricePerMillion} per 1M) is more expensive than primary model '${primaryModel}' ($${primaryPricing.inputPricePerMillion}/$${primaryPricing.outputPricePerMillion} per 1M). Automatic fallback blocked to prevent quota exhaustion.`);
        }
    }
}
function getGeminiConfig(injectedKey) {
    const apiKey = injectedKey || process.env.GEMINI_API_KEY || "";
    // Dynamic model configuration with validation
    const rawPrimary = process.env.GEMINI_MODEL || "gemini-3.5-flash-lite";
    const rawFallback = process.env.GEMINI_FALLBACK_MODEL || "gemini-3.5-flash";
    const allowExpensiveFallback = process.env.GEMINI_ALLOW_EXPENSIVE_FALLBACK === "true";
    const primaryModel = validateModelIdentifier(rawPrimary, "Primary model");
    const fallbackModel = validateModelIdentifier(rawFallback, "Fallback model");
    // Enforce cost control guard between primary and fallback
    validateFallbackCostPolicy(primaryModel, fallbackModel, allowExpensiveFallback);
    return {
        apiKey,
        primaryModel,
        fallbackModel,
        allowExpensiveFallback,
        temperature: parseFloat(process.env.GEMINI_TEMPERATURE || "0.2"),
        topP: 0.8,
        maxOutputTokens: parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || "8192", 10),
        timeoutMs: parseInt(process.env.GEMINI_TIMEOUT_MS || "60000", 10), // 60s timeout matching Cloud Function callOptions
        maxRetries: parseInt(process.env.GEMINI_MAX_RETRIES || "2", 10)
    };
}
//# sourceMappingURL=gemini.config.js.map