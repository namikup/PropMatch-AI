export interface LogMetadata {
  requestId?: string;
  ownerId?: string;
  feature?: string;
  latencyMs?: number;
  model?: string;
  [key: string]: unknown;
}

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

function sanitizeValue(value: unknown): unknown {
  if (value === null || value === undefined) return value;
  if (typeof value === "string") {
    // Redact email patterns, Malaysian NRIC patterns, phone numbers and API keys
    return value
      .replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, "[REDACTED_EMAIL]")
      .replace(/\b\d{6}-\d{2}-\d{4}\b/g, "[REDACTED_NRIC]")
      .replace(/AIza[0-9A-Za-z-_]{20,}/g, "[REDACTED_API_KEY]")
      .replace(/(\+?6?01[0-9]-?[0-9]{7,8})/g, "[REDACTED_PHONE]");
  }
  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }
  if (typeof value === "object") {
    const cleaned: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (REDACTED_KEYS.some((rk) => k.toLowerCase().includes(rk.toLowerCase()))) {
        cleaned[k] = "[REDACTED]";
      } else {
        cleaned[k] = sanitizeValue(v);
      }
    }
    return cleaned;
  }
  return value;
}

export class Logger {
  static info(message: string, meta?: LogMetadata): void {
    const logEntry = {
      level: "INFO",
      timestamp: new Date().toISOString(),
      message,
      ...(meta ? (sanitizeValue(meta) as object) : {})
    };
    console.log(JSON.stringify(logEntry));
  }

  static warn(message: string, meta?: LogMetadata): void {
    const logEntry = {
      level: "WARN",
      timestamp: new Date().toISOString(),
      message,
      ...(meta ? (sanitizeValue(meta) as object) : {})
    };
    console.warn(JSON.stringify(logEntry));
  }

  static error(message: string, error?: unknown, meta?: LogMetadata): void {
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    const logEntry = {
      level: "ERROR",
      timestamp: new Date().toISOString(),
      message,
      errorMessage,
      errorStack,
      ...(meta ? (sanitizeValue(meta) as object) : {})
    };
    console.error(JSON.stringify(logEntry));
  }
}
