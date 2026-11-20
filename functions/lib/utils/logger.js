"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Logger = void 0;
const REDACTED_KEYS = [
    "password",
    "token",
    "apiKey",
    "secret",
    "phone",
    "email",
    "fullName",
    "icNumber",
    "nric",
    "passport",
    "candidates",
    "rawPayload",
    "evidenceText"
];
function sanitizeValue(value) {
    if (value === null || value === undefined)
        return value;
    if (typeof value === "string") {
        // Redact email patterns and Malaysian NRIC patterns
        return value
            .replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, "[REDACTED_EMAIL]")
            .replace(/\b\d{6}-\d{2}-\d{4}\b/g, "[REDACTED_NRIC]");
    }
    if (Array.isArray(value)) {
        return value.map(sanitizeValue);
    }
    if (typeof value === "object") {
        const cleaned = {};
        for (const [k, v] of Object.entries(value)) {
            if (REDACTED_KEYS.some((rk) => k.toLowerCase().includes(rk.toLowerCase()))) {
                cleaned[k] = "[REDACTED]";
            }
            else {
                cleaned[k] = sanitizeValue(v);
            }
        }
        return cleaned;
    }
    return value;
}
class Logger {
    static info(message, meta) {
        const logEntry = {
            level: "INFO",
            timestamp: new Date().toISOString(),
            message,
            ...(meta ? sanitizeValue(meta) : {})
        };
        console.log(JSON.stringify(logEntry));
    }
    static warn(message, meta) {
        const logEntry = {
            level: "WARN",
            timestamp: new Date().toISOString(),
            message,
            ...(meta ? sanitizeValue(meta) : {})
        };
        console.warn(JSON.stringify(logEntry));
    }
    static error(message, error, meta) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const errorStack = error instanceof Error ? error.stack : undefined;
        const logEntry = {
            level: "ERROR",
            timestamp: new Date().toISOString(),
            message,
            errorMessage,
            errorStack,
            ...(meta ? sanitizeValue(meta) : {})
        };
        console.error(JSON.stringify(logEntry));
    }
}
exports.Logger = Logger;
//# sourceMappingURL=logger.js.map