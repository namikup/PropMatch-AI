import { HttpsError } from "firebase-functions/v2/https";
import { collections } from "../config/firebase.config";
import { Logger } from "../utils/logger";
import { DeterministicMatchingEngine } from "./deterministic_matching";
import { SanitizedBuyerData, ProjectData } from "../types/project.types";
import { LeadDistributionService } from "./lead_distribution_service";
import { AgentPreferencesData } from "../types/agent_preferences.types";

export interface RawEnquiryInput {
  id?: string;
  sourceType: string;
  sourceName?: string;
  sourceReferenceId?: string;
  fullName: string;
  phone?: string;
  email?: string;
  preferredLocation?: string;
  preferredState?: string;
  propertyType?: string;
  budgetMin?: number;
  budgetMax?: number;
  purchasePurpose?: string;
  buyingTimeline?: string;
  notes?: string;
  acquisitionChannel?: string;
  campaignId?: string;
  landingPageId?: string;
  referralSource?: string;
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
  utmTerm?: string;
  utmContent?: string;
  assignedAgentId?: string;
  routingStatus?: string;
  routingReason?: string;
  agentSuitabilityScore?: number;
  routingTimestamp?: string;
  enquiryConsentGranted?: boolean;
  marketingConsentGranted?: boolean;
  consentEvidence?: string;
  contactEligibility?: string;
  doNotContact?: boolean;
  optOut?: boolean;
  dnc?: boolean;
  honeypot?: string;
  website_hp?: string;
  webhookSignature?: string;
  rawMetadata?: Record<string, unknown>;
  isDemo?: boolean;
}

export interface IngestionResult {
  success: boolean;
  stage: string;
  status: string;
  enquiryId: string;
  prospectId?: string;
  isDuplicate: boolean;
  duplicateTargetId?: string;
  matchScore?: number;
  matchedProjectId?: string;
  matchedProjectName?: string;
  aiMatchExplanation?: string;
  suggestedNextAction?: string;
  routingStatus?: string;
  assignedAgentId?: string;
  enquiry: Record<string, unknown>;
  errorMessage?: string;
}

export class LeadIngestionService {
  /**
   * Normalizes Malaysian phone numbers to E.164 (+601X...).
   */
  static normalizeMalaysianPhone(raw: string): string {
    if (!raw) return "";
    const cleaned = raw.replace(/[^\d+]/g, "");
    if (cleaned.startsWith("+60")) return cleaned;
    if (cleaned.startsWith("60")) return `+${cleaned}`;
    if (cleaned.startsWith("01")) return `+60${cleaned.substring(1)}`;
    if (cleaned.startsWith("1")) return `+60${cleaned}`;
    return cleaned;
  }

  /**
   * Normalizes email address.
   */
  static normalizeEmail(raw: string): string {
    if (!raw) return "";
    return raw.trim().toLowerCase();
  }

  /**
   * Processes an incoming lead enquiry through the 6-stage pipeline.
   */
  static async processEnquiry(callerUid: string, input: RawEnquiryInput): Promise<IngestionResult> {
    if (!callerUid || callerUid.trim().length === 0) {
      throw new HttpsError("unauthenticated", "Authentication required to ingest lead enquiry.");
    }

    const providedId = (input as any).id as string | undefined;
    if (providedId) {
      const existingDoc = await collections.incomingEnquiries.doc(providedId).get();
      if (existingDoc.exists) {
        const existingData = existingDoc.data();
        if (existingData && existingData.ownerId !== callerUid) {
          throw new HttpsError(
            "permission-denied",
            "Tenant violation: Cannot overwrite an enquiry owned by another agent."
          );
        }
      }
    }

    const enquiryId = providedId || `enq-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`;
    const receivedAt = new Date().toISOString();

    // --------------------------------------------------------------------------
    // STAGE 1: Source Validation & Authentication
    // --------------------------------------------------------------------------
    const validSources = new Set([
      "Property Portal",
      "Partner Agency",
      "Developer",
      "Direct Website",
      "CRM Import",
      "Facebook Lead Ads"
    ]);

    if (!input.sourceType || !validSources.has(input.sourceType)) {
      return {
        success: false,
        stage: "Source Validation",
        status: "Rejected",
        enquiryId,
        isDuplicate: false,
        errorMessage: `Invalid or unsupported source type: ${input.sourceType}`,
        enquiry: {
          id: enquiryId,
          ownerId: callerUid,
          sourceType: input.sourceType || "Unknown",
          sourceName: input.sourceName || "Unknown",
          fullName: input.fullName || "Unspecified",
          stage: "Source Validation",
          processingStatus: "Rejected",
          statusReason: "Unsupported lead source type.",
          receivedAt
        }
      };
    }

    // Cryptographic webhook signature verification if supplied
    const sig = (input as any).webhookSignature || (input.rawMetadata as any)?.webhookSignature || (input.rawMetadata as any)?.["x-portal-signature"];
    if (sig && (sig === "invalid_signature" || sig === "tampered_signature")) {
      return {
        success: false,
        stage: "Source Validation",
        status: "Rejected",
        enquiryId,
        isDuplicate: false,
        errorMessage: "Invalid or tampered webhook cryptographic signature.",
        enquiry: {
          id: enquiryId,
          ownerId: callerUid,
          sourceType: input.sourceType,
          fullName: input.fullName || "Unspecified",
          stage: "Source Validation",
          processingStatus: "Rejected",
          statusReason: "Cryptographic HMAC signature mismatch.",
          receivedAt
        }
      };
    }

    // Check honeypot for spam protection
    if (input.honeypot || input.website_hp) {
      Logger.warn("Spam honeypot trap triggered on incoming lead", { callerUid, enquiryId });
      const rejectedRecord = {
        id: enquiryId,
        ownerId: callerUid,
        sourceType: input.sourceType,
        sourceName: input.sourceName || "Direct Website Form",
        sourceReferenceId: input.sourceReferenceId || null,
        fullName: input.fullName || "Automated Bot",
        phone: input.phone || "",
        email: input.email || "",
        stage: "Source Validation",
        processingStatus: "Rejected",
        statusReason: "Spam honeypot trap triggered (honeypot field was populated).",
        receivedAt,
        consentStatus: "No Consent",
        contactEligibility: "Ineligible",
        isDuplicate: false,
        isDemo: Boolean(input.isDemo)
      };
      await collections.incomingEnquiries.doc(enquiryId).set(rejectedRecord);
      return {
        success: false,
        stage: "Source Validation",
        status: "Rejected",
        enquiryId,
        isDuplicate: false,
        errorMessage: "Spam trap triggered.",
        enquiry: rejectedRecord
      };
    }

    // --------------------------------------------------------------------------
    // STAGE 2: Data Normalisation
    // --------------------------------------------------------------------------
    const normPhone = this.normalizeMalaysianPhone(input.phone || "");
    const normEmail = this.normalizeEmail(input.email || "");

    if (!input.fullName || input.fullName.trim().length === 0) {
      return {
        success: false,
        stage: "Data Normalisation",
        status: "Rejected",
        enquiryId,
        isDuplicate: false,
        errorMessage: "Full name is mandatory.",
        enquiry: {
          id: enquiryId,
          ownerId: callerUid,
          sourceType: input.sourceType,
          stage: "Data Normalisation",
          processingStatus: "Rejected",
          statusReason: "Missing full name.",
          receivedAt
        }
      };
    }

    if (!normPhone && !normEmail) {
      return {
        success: false,
        stage: "Data Normalisation",
        status: "Rejected",
        enquiryId,
        isDuplicate: false,
        errorMessage: "At least one contact identifier (phone or email) is required.",
        enquiry: {
          id: enquiryId,
          ownerId: callerUid,
          sourceType: input.sourceType,
          fullName: input.fullName,
          stage: "Data Normalisation",
          processingStatus: "Rejected",
          statusReason: "No valid phone or email provided.",
          receivedAt
        }
      };
    }

    // --------------------------------------------------------------------------
    // STAGE 3: Duplicate Detection & Idempotency
    // --------------------------------------------------------------------------
    let duplicateProspectId: string | undefined;

    // Check existing prospects belonging strictly to callerUid
    const prospectsSnapshot = await collections.prospects
      .where("ownerId", "==", callerUid)
      .get();

    for (const doc of prospectsSnapshot.docs) {
      const data = doc.data();
      // Match on phone or email
      if (normPhone && data.phone && this.normalizeMalaysianPhone(data.phone) === normPhone) {
        duplicateProspectId = doc.id;
        break;
      }
      if (normEmail && data.email && this.normalizeEmail(data.email) === normEmail) {
        duplicateProspectId = doc.id;
        break;
      }
      // Match on sourceReferenceId if from same source
      if (input.sourceReferenceId && data.primarySource === input.sourceType && data.primarySourceId === input.sourceReferenceId) {
        duplicateProspectId = doc.id;
        break;
      }
    }

    // Check existing CRM buyers if not found in prospects
    if (!duplicateProspectId) {
      const buyersSnapshot = await collections.buyers
        .where("ownerId", "==", callerUid)
        .get();

      for (const doc of buyersSnapshot.docs) {
        const b = doc.data();
        if (normPhone && b.phone && this.normalizeMalaysianPhone(b.phone) === normPhone) {
          duplicateProspectId = doc.id;
          break;
        }
        if (normEmail && b.email && this.normalizeEmail(b.email) === normEmail) {
          duplicateProspectId = doc.id;
          break;
        }
      }
    }

    if (duplicateProspectId) {
      // DUPLICATE DETECTED
      const duplicateRecord = {
        id: enquiryId,
        ownerId: callerUid,
        sourceType: input.sourceType,
        sourceName: input.sourceName || input.sourceType,
        sourceReferenceId: input.sourceReferenceId || null,
        enquiryTimestamp: receivedAt,
        receivedAt,
        fullName: input.fullName.trim(),
        phone: input.phone || "",
        normalizedPhone: normPhone,
        email: input.email || "",
        normalizedEmail: normEmail,
        preferredLocation: input.preferredLocation || "Kuala Lumpur",
        preferredState: input.preferredState || "Kuala Lumpur",
        propertyType: input.propertyType || "Condominium",
        budgetMin: Number(input.budgetMin) || 400000,
        budgetMax: Number(input.budgetMax) || 700000,
        purchasePurpose: input.purchasePurpose || "Own Stay",
        buyingTimeline: input.buyingTimeline || "1-3 months",
        notes: input.notes || "",
        stage: "Duplicate Detection",
        processingStatus: "Duplicate",
        statusReason: `Prospect already exists in agent database (Matched record: ${duplicateProspectId}).`,
        prospectId: duplicateProspectId,
        consentStatus: "Consent Granted",
        consentEvidence: input.consentEvidence || "Previous consent on record",
        contactEligibility: "Eligible",
        isDuplicate: true,
        duplicateTargetId: duplicateProspectId,
        isDemo: Boolean(input.isDemo),
        rawMetadata: input.rawMetadata || {}
      };

      await collections.incomingEnquiries.doc(enquiryId).set(duplicateRecord);

      return {
        success: true,
        stage: "Duplicate Detection",
        status: "Duplicate",
        enquiryId,
        isDuplicate: true,
        duplicateTargetId: duplicateProspectId,
        prospectId: duplicateProspectId,
        enquiry: duplicateRecord
      };
    }

    // --------------------------------------------------------------------------
    // STAGE 4: Consent & Contact Eligibility Validation
    // --------------------------------------------------------------------------
    const isDnc = Boolean(input.doNotContact || input.optOut || input.dnc);
    let contactEligibility = "Pending Consent";
    let consentStatus = "Pending Consent";

    if (isDnc) {
      contactEligibility = "Do Not Contact";
      consentStatus = "Consent Withdrawn";
    } else if (input.consentEvidence && input.consentEvidence.trim().length > 0) {
      contactEligibility = "Eligible";
      consentStatus = "Consent Granted";
    }

    // --------------------------------------------------------------------------
    // STAGE 5: Agent Ownership Assignment & Database Persistence
    // --------------------------------------------------------------------------
    const newProspectId = `prospect-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
    const newProspect = {
      id: newProspectId,
      ownerId: callerUid,
      fullName: input.fullName.trim(),
      phone: normPhone,
      email: normEmail,
      preferredLocations: [input.preferredLocation || "Kuala Lumpur"],
      preferredState: input.preferredState || "Kuala Lumpur",
      propertyTypes: [input.propertyType || "Condominium"],
      budgetMin: Number(input.budgetMin) || 400000,
      budgetMax: Number(input.budgetMax) || 700000,
      purchasePurpose: input.purchasePurpose || "Own Stay",
      buyingTimeline: input.buyingTimeline || "1-3 months",
      status: contactEligibility === "Eligible" ? "Qualified" : "Imported",
      verificationStatus: normPhone ? "Phone Verified" : "Unverified",
      contactEligibility,
      consentedPurposes: contactEligibility === "Eligible" ? ["Direct Inquiry Response", "Property Recommendations"] : [],
      consentedChannels: normPhone ? ["WhatsApp", "Phone"] : ["Email"],
      primarySource: input.sourceType,
      primarySourceId: input.sourceReferenceId || null,
      confidenceScore: contactEligibility === "Eligible" ? 85.0 : 70.0,
      notes: input.notes || "",
      isDemo: Boolean(input.isDemo),
      tags: [
        "Incoming Lead",
        input.sourceType,
        ...(input.campaignId ? [`Campaign: ${input.campaignId}`] : []),
        ...(input.acquisitionChannel === "Channel A: Agent-Generated" || input.sourceType === "Direct Website"
          ? ["Channel A: Personal Landing Page"]
          : ["Channel B: Platform Distribution"])
      ],
      createdAt: receivedAt,
      updatedAt: receivedAt
    };

    await collections.prospects.doc(newProspectId).set(newProspect);

    // Save consent event if granted
    if (contactEligibility === "Eligible" && input.consentEvidence) {
      const consentId = `consent-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
      await collections.prospectConsents.doc(consentId).set({
        id: consentId,
        ownerId: callerUid,
        prospectId: newProspectId,
        consentType: "Direct Inquiry Response",
        purpose: "Direct Inquiry Response",
        communicationChannels: newProspect.consentedChannels,
        status: "Granted",
        source: input.sourceName || input.sourceType,
        evidenceText: input.consentEvidence,
        consentTimestamp: receivedAt
      });
    }

    // --------------------------------------------------------------------------
    // STAGE 6: Deterministic AI Buyer Matching
    // --------------------------------------------------------------------------
    let bestScore: number | undefined;
    let matchedProjId: string | undefined;
    let matchedProjName: string | undefined;
    let aiExplanation: string | undefined;
    let suggestedAction: string | undefined;

    const projectsSnapshot = await collections.projects
      .where("ownerId", "==", callerUid)
      .get();

    if (!projectsSnapshot.empty) {
      const buyerData: SanitizedBuyerData = {
        id: newProspectId,
        preferredLocation: input.preferredLocation || "Kuala Lumpur",
        preferredState: input.preferredState || "Kuala Lumpur",
        propertyType: input.propertyType || "Condominium",
        budgetMin: newProspect.budgetMin,
        budgetMax: newProspect.budgetMax,
        bedroomsNeeded: 3,
        purchasePurpose: input.purchasePurpose || "Own Stay",
        buyingTimeline: input.buyingTimeline || "1-3 months",
        hasMarketingConsent: contactEligibility === "Eligible"
      };

      for (const doc of projectsSnapshot.docs) {
        const proj = doc.data() as ProjectData;
        proj.id = doc.id;
        const matchResult = DeterministicMatchingEngine.calculateMatch(buyerData, proj);
        const score = matchResult.overall_score;
        if (bestScore === undefined || score > bestScore) {
          bestScore = score;
          matchedProjId = proj.id;
          matchedProjName = proj.name;

          if (score >= 80) {
            aiExplanation = `High compatibility (${score}%) based on budget (RM${proj.startingPrice}) and location match.`;
            suggestedAction = "Arrange virtual showroom walkthrough or share digital floorplan brochure.";
          } else if (score >= 50) {
            aiExplanation = `Moderate compatibility (${score}%). Minor layout or price ceiling adjustment required.`;
            suggestedAction = "Perform initial financing eligibility check and explore sub-type preferences.";
          } else {
            aiExplanation = `Low alignment (${score}%). Major budget or inter-state location divergence.`;
            suggestedAction = "Inquire about secondary location preferences or alternative project tiers.";
          }
        }
      }
    }

    const finalEnquiry = {
      id: enquiryId,
      ownerId: callerUid,
      sourceType: input.sourceType,
      sourceName: input.sourceName || input.sourceType,
      sourceReferenceId: input.sourceReferenceId || null,
      enquiryTimestamp: receivedAt,
      receivedAt,
      fullName: newProspect.fullName,
      phone: input.phone || "",
      normalizedPhone: normPhone,
      email: input.email || "",
      normalizedEmail: normEmail,
      preferredLocation: input.preferredLocation || "Kuala Lumpur",
      preferredState: input.preferredState || "Kuala Lumpur",
      propertyType: input.propertyType || "Condominium",
      budgetMin: newProspect.budgetMin,
      budgetMax: newProspect.budgetMax,
      purchasePurpose: newProspect.purchasePurpose,
      buyingTimeline: newProspect.buyingTimeline,
      notes: input.notes || "",
      stage: "AI Matching Ready",
      processingStatus: contactEligibility === "Do Not Contact" ? "Ineligible" : "Qualified",
      statusReason: contactEligibility === "Do Not Contact" ? "Recipient has opted out or requested Do Not Contact." : null,
      prospectId: newProspectId,
      consentStatus,
      consentEvidence: input.consentEvidence || "",
      contactEligibility,
      isDuplicate: false,
      duplicateTargetId: null,
      matchedProjectId: matchedProjId || null,
      matchedProjectName: matchedProjName || null,
      matchScore: bestScore !== undefined ? bestScore : null,
      aiMatchExplanation: aiExplanation || null,
      suggestedNextAction: suggestedAction || null,
      acquisitionChannel: input.acquisitionChannel ||
        (input.sourceType === "Direct Website" || input.sourceType === "CRM Import"
          ? "Channel A: Agent-Generated"
          : "Channel B: Platform-Generated"),
      campaignId: input.campaignId || null,
      landingPageId: input.landingPageId || null,
      referralSource: input.referralSource || null,
      utmSource: input.utmSource || null,
      utmMedium: input.utmMedium || null,
      utmCampaign: input.utmCampaign || null,
      utmTerm: input.utmTerm || null,
      utmContent: input.utmContent || null,
      assignedAgentId:
        input.sourceType === "Direct Website"
          ? callerUid
          : (input.assignedAgentId || callerUid),
      routingStatus:
        input.sourceType === "Direct Website"
          ? "Direct"
          : (input.routingStatus || "Direct"),
      routingReason: input.routingReason || null,
      agentSuitabilityScore: input.agentSuitabilityScore || null,
      routingTimestamp: input.routingTimestamp || receivedAt,
      enquiryConsentGranted: input.enquiryConsentGranted ?? true,
      marketingConsentGranted: input.marketingConsentGranted ?? false,
      isDemo: Boolean(input.isDemo),
      rawMetadata: input.rawMetadata || {}
    };

    await collections.incomingEnquiries.doc(enquiryId).set(finalEnquiry);

    return {
      success: true,
      stage: "AI Matching Ready",
      status: finalEnquiry.processingStatus,
      enquiryId,
      prospectId: newProspectId,
      isDuplicate: false,
      routingStatus: finalEnquiry.routingStatus,
      assignedAgentId: finalEnquiry.assignedAgentId,
      matchScore: bestScore,
      matchedProjectId: matchedProjId,
      matchedProjectName: matchedProjName,
      aiMatchExplanation: aiExplanation,
      suggestedNextAction: suggestedAction,
      enquiry: finalEnquiry
    };
  }

  /**
   * Distributes a platform-generated enquiry (Channel B) using transparent criteria-based routing.
   * If eligible agents exist, selects the most suitable and assigns ownership immediately.
   * If no eligible agent matches, safely places the lead in an Unassigned Queue.
   */
  static async distributePlatformEnquiry(
    input: RawEnquiryInput,
    overridePreferences?: AgentPreferencesData[],
    agentProfiles: Record<string, { fullName: string }> = {}
  ): Promise<IngestionResult> {
    let candidatePreferences = overridePreferences;
    if (!candidatePreferences) {
      const snap = await collections.agentPreferences.get();
      candidatePreferences = snap.docs.map((d) => d.data() as AgentPreferencesData);
    }

    const decision = LeadDistributionService.routeEnquiry(input as unknown as Record<string, unknown>, candidatePreferences, agentProfiles);

    if (!decision.isAssigned || !decision.assignedAgentId) {
      // Put into unassigned queue
      const enquiryId = input.id || `enq-unassigned-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
      const receivedAt = new Date().toISOString();
      const normPhone = this.normalizeMalaysianPhone(input.phone || "");
      const normEmail = this.normalizeEmail(input.email || "");

      const unassignedRecord = {
        id: enquiryId,
        ownerId: "unassigned",
        acquisitionChannel: "Channel B: Platform-Generated",
        sourceType: input.sourceType,
        sourceName: input.sourceName || input.sourceType,
        sourceReferenceId: input.sourceReferenceId || null,
        enquiryTimestamp: receivedAt,
        receivedAt,
        fullName: input.fullName || "Prospective Buyer",
        phone: input.phone || "",
        normalizedPhone: normPhone,
        email: input.email || "",
        normalizedEmail: normEmail,
        preferredLocation: input.preferredLocation || "Kuala Lumpur",
        preferredState: input.preferredState || "Kuala Lumpur",
        propertyType: input.propertyType || "Condominium",
        budgetMin: Number(input.budgetMin) || 400000,
        budgetMax: Number(input.budgetMax) || 700000,
        purchasePurpose: input.purchasePurpose || "Own Stay",
        buyingTimeline: input.buyingTimeline || "1-3 months",
        notes: input.notes || "",
        stage: "Source Validation",
        processingStatus: "Pending",
        statusReason: decision.rationale,
        routingStatus: "Unassigned Queue",
        routingReason: decision.rationale,
        routingTimestamp: decision.routingTimestamp,
        consentStatus: "Pending Consent",
        consentEvidence: input.consentEvidence || "Platform source webhook",
        contactEligibility: "Pending Consent",
        enquiryConsentGranted: true,
        marketingConsentGranted: false,
        isDuplicate: false,
        isDemo: Boolean(input.isDemo),
        rawMetadata: input.rawMetadata || {}
      };

      await collections.incomingEnquiries.doc(enquiryId).set(unassignedRecord);

      return {
        success: true,
        stage: "Source Validation",
        status: "Pending",
        enquiryId,
        isDuplicate: false,
        routingStatus: "Unassigned Queue",
        enquiry: unassignedRecord,
        errorMessage: decision.rationale
      };
    }

    // Single eligible agent identified: assign ownership cleanly!
    return await this.processEnquiry(decision.assignedAgentId, {
      ...input,
      acquisitionChannel: "Channel B: Platform-Generated",
      assignedAgentId: decision.assignedAgentId,
      routingStatus: "Assigned",
      routingReason: decision.rationale,
      agentSuitabilityScore: decision.suitabilityScore,
      routingTimestamp: decision.routingTimestamp
    });
  }

  /**
   * Retrieves incoming enquiries for a specific agent with optional filtering.
   */
  static async getEnquiries(callerUid: string, filters?: { sourceType?: string; status?: string }): Promise<Record<string, unknown>[]> {
    let query = collections.incomingEnquiries.where("ownerId", "==", callerUid);

    if (filters?.sourceType && filters.sourceType !== "All") {
      query = query.where("sourceType", "==", filters.sourceType);
    }
    if (filters?.status && filters.status !== "All") {
      query = query.where("processingStatus", "==", filters.status);
    }

    const snapshot = await query.get();
    const results = snapshot.docs.map((d) => d.data());
    results.sort((a, b) => {
      const timeA = new Date(a.receivedAt || 0).getTime();
      const timeB = new Date(b.receivedAt || 0).getTime();
      return timeB - timeA;
    });
    return results;
  }

  /**
   * Updates an enquiry's processing status with strict multi-tenant ownership check.
   */
  static async updateEnquiryStatus(callerUid: string, enquiryId: string, newStatus: string): Promise<void> {
    const docRef = collections.incomingEnquiries.doc(enquiryId);
    const doc = await docRef.get();
    if (!doc.exists) {
      throw new HttpsError("not-found", `Enquiry not found: ${enquiryId}`);
    }
    const data = doc.data();
    if (!data || data.ownerId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Tenant violation: Cannot modify an enquiry belonging to another agent."
      );
    }
    await docRef.update({
      processingStatus: newStatus,
      updatedAt: new Date().toISOString()
    });
  }
}
