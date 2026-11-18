"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SUPPORTED_MODELS = void 0;
exports.getGeminiConfig = getGeminiConfig;
function getGeminiConfig() {
    const apiKey = process.env.GEMINI_API_KEY || "";
    return {
        apiKey,
        // Configurable model identifier with stable fallback
        primaryModel: process.env.GEMINI_MODEL || "gemini-1.5-flash",
        fallbackModel: process.env.GEMINI_FALLBACK_MODEL || "gemini-1.5-pro",
        temperature: parseFloat(process.env.GEMINI_TEMPERATURE || "0.2"),
        topP: 0.8,
        maxOutputTokens: 2048,
        timeoutMs: parseInt(process.env.GEMINI_TIMEOUT_MS || "30000", 10), // 30s timeout
        maxRetries: parseInt(process.env.GEMINI_MAX_RETRIES || "2", 10)
    };
}
exports.SUPPORTED_MODELS = [
    "gemini-1.5-flash",
    "gemini-1.5-pro",
    "gemini-2.0-flash",
    "gemini-2.5-flash"
];
//# sourceMappingURL=gemini.config.js.map