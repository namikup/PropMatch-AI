import { HttpsError } from "firebase-functions/v2/https";
import { Logger } from "./logger";

export class ErrorHandler {
  /**
   * Translates any caught exception into a sanitized, secure HttpsError.
   */
  static handle(err: unknown, contextName: string, metadata?: Record<string, unknown>): HttpsError {
    Logger.error(`Error in ${contextName}`, err, metadata);

    // If already an HttpsError, return it directly
    if (err instanceof HttpsError) {
      return err;
    }

    const message = err instanceof Error ? err.message : String(err);

    // Rate limiting / Quota errors
    if (message.includes("429") || message.includes("RESOURCE_EXHAUSTED") || message.includes("quota")) {
      return new HttpsError(
        "resource-exhausted",
        "Monthly AI usage quota or rate limit exceeded. Please try again later or contact support."
      );
    }

    // Timeout / Deadline errors
    if (message.includes("timeout") || message.includes("DEADLINE_EXCEEDED") || message.includes("AbortError")) {
      return new HttpsError(
        "deadline-exceeded",
        "The AI model request timed out after 30 seconds. Please try again with smaller inputs."
      );
    }

    // Validation / Invalid Argument
    if (message.includes("Invalid") || message.includes("validation") || message.includes("required")) {
      return new HttpsError(
        "invalid-argument",
        `Input validation error: ${message.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, "[REDACTED]")}`
      );
    }

    // Permission / Ownership
    if (message.includes("permission") || message.includes("unauthorized") || message.includes("ownership")) {
      return new HttpsError(
        "permission-denied",
        "You do not have permission to access or analyze this resource."
      );
    }

    // Authentication
    if (message.includes("unauthenticated") || message.includes("auth")) {
      return new HttpsError(
        "unauthenticated",
        "Authentication is required to perform this action."
      );
    }

    // Fallback safe internal error
    return new HttpsError(
      "internal",
      "An unexpected error occurred while communicating with the AI intelligence service."
    );
  }
}
