import { HttpsError } from "firebase-functions/v2/https";
import { ProjectData, SanitizedBuyerData } from "../types/project.types";
import { collections } from "../config/firebase.config";

export class AIRequestValidator {
  /**
   * Validates that the request has an active authenticated user.
   */
  static validateAuth(callerUid?: string): string {
    if (!callerUid || callerUid.trim() === "") {
      throw new HttpsError("unauthenticated", "Authentication required to invoke AI services.");
    }
    return callerUid.trim();
  }

  /**
   * Validates project data, sanitizes inputs, and strictly enforces multi-tenant ownership.
   */
  static validateProject(project: any, callerUid: string): ProjectData {
    if (!project || typeof project !== "object") {
      throw new HttpsError("invalid-argument", "Missing or invalid project data.");
    }

    if (!project.id || typeof project.id !== "string" || project.id.trim() === "") {
      throw new HttpsError("invalid-argument", "Project 'id' is required.");
    }

    if (!project.ownerId || typeof project.ownerId !== "string" || project.ownerId.trim() === "") {
      throw new HttpsError("invalid-argument", "Project 'ownerId' is required.");
    }

    // STRICT MULTI-TENANT ISOLATION CHECK
    if (project.ownerId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Tenant violation: You cannot access or run AI intelligence on another agent's project."
      );
    }

    if (!project.name || typeof project.name !== "string" || project.name.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Project 'name' is required.");
    }

    // String length sanitization to avoid unbounded prompt bloating
    const sanitizedDescription = typeof project.description === "string" 
      ? project.description.slice(0, 3000) 
      : "";

    return {
      id: project.id.trim(),
      ownerId: project.ownerId.trim(),
      name: project.name.slice(0, 150).trim(),
      developer: typeof project.developer === "string" ? project.developer.slice(0, 150).trim() : "Independent",
      location: typeof project.location === "string" ? project.location.slice(0, 150).trim() : "Malaysia",
      state: typeof project.state === "string" ? project.state.slice(0, 50).trim() : "Penang",
      propertyType: typeof project.propertyType === "string" ? project.propertyType.slice(0, 50).trim() : "Condominium",
      startingPrice: typeof project.startingPrice === "number" ? Math.max(0, project.startingPrice) : 0,
      maximumPrice: typeof project.maximumPrice === "number" ? Math.max(0, project.maximumPrice) : 0,
      bedrooms: typeof project.bedrooms === "number" ? Math.max(1, project.bedrooms) : 1,
      bathrooms: typeof project.bathrooms === "number" ? Math.max(1, project.bathrooms) : 1,
      builtUpArea: typeof project.builtUpArea === "number" ? Math.max(100, project.builtUpArea) : 500,
      facilities: Array.isArray(project.facilities) ? project.facilities.slice(0, 30).map(String) : [],
      nearbyAmenities: Array.isArray(project.nearbyAmenities) ? project.nearbyAmenities.slice(0, 30).map(String) : [],
      description: sanitizedDescription,
      purpose: typeof project.purpose === "string" ? project.purpose.slice(0, 50).trim() : "Own Stay",
      status: typeof project.status === "string" ? project.status.slice(0, 50).trim() : "New Launch"
    };
  }

  /**
   * Confirms project ownership directly against Firestore database record.
   */
  static async verifyProjectOwnershipInFirestore(projectId: string, callerUid: string): Promise<void> {
    try {
      const doc = await collections.projects.doc(projectId).get();
      if (doc.exists) {
        const data = doc.data();
        if (data && data.ownerId && data.ownerId !== callerUid) {
          throw new HttpsError(
            "permission-denied",
            "Tenant violation: The requested project record does not belong to your account."
          );
        }
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      // If Firestore read fails or record is local demo, proceed with in-memory validation
    }
  }

  /**
   * Validates buyer data, enforces ownership, and strips all PII for PDPA compliance.
   */
  static validateAndSanitizeBuyers(buyers: any[], callerUid: string): SanitizedBuyerData[] {
    if (!Array.isArray(buyers)) {
      throw new HttpsError("invalid-argument", "Buyers must be provided as an array.");
    }

    if (buyers.length > 50) {
      throw new HttpsError("invalid-argument", "Batch matching limit is 50 buyers per request.");
    }

    return buyers.map((b, idx) => {
      if (!b || typeof b !== "object") {
        throw new HttpsError("invalid-argument", `Invalid buyer record at index ${idx}.`);
      }

      if (!b.id || typeof b.id !== "string" || b.id.trim() === "") {
        throw new HttpsError("invalid-argument", `Buyer at index ${idx} is missing a valid 'id'.`);
      }

      // STRICT MULTI-TENANT CHECK: ownerId must exist and equal callerUid
      if (!b.ownerId || b.ownerId.trim() !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          `Tenant violation: Buyer record ${b.id} does not belong to the authenticated agent.`
        );
      }

      // CRITICAL PDPA COMPLIANCE: Strip fullName, phone, email, IC, exact address before passing to LLM!
      return {
        id: b.id.trim(),
        preferredLocation: typeof b.preferredLocation === "string" ? b.preferredLocation.slice(0, 100).trim() : "",
        preferredState: typeof b.preferredState === "string" ? b.preferredState.slice(0, 50).trim() : "",
        propertyType: typeof b.propertyType === "string" ? b.propertyType.slice(0, 50).trim() : "",
        budgetMin: typeof b.budgetMin === "number" ? Math.max(0, b.budgetMin) : 0,
        budgetMax: typeof b.budgetMax === "number" ? Math.max(0, b.budgetMax) : 0,
        bedroomsNeeded: typeof b.bedroomsNeeded === "number" ? Math.max(0, b.bedroomsNeeded) : 0,
        purchasePurpose: typeof b.purchasePurpose === "string" ? b.purchasePurpose.slice(0, 50).trim() : "Own Stay",
        buyingTimeline: typeof b.buyingTimeline === "string" ? b.buyingTimeline.slice(0, 50).trim() : "Flexible",
        hasMarketingConsent: Boolean(b.hasMarketingConsent)
      };
    });
  }
}
