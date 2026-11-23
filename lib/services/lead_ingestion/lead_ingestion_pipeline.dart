import '../../models/enquiry_model.dart';
import '../../models/prospect_model.dart';
import '../../models/prospect_source_record_model.dart';
import '../../models/project_model.dart';
import '../../models/buyer_model.dart';
import '../prospect_sources/source_registry.dart';
import '../matching_service.dart';

/// Result emitted by the Lead Ingestion Pipeline upon processing an incoming enquiry.
class IngestionPipelineResult {
  final bool success;
  final EnquiryModel enquiry;
  final ProspectModel? createdProspect;
  final ProspectSourceRecordModel? sourceRecord;
  final String currentStage;
  final String status;
  final String? errorMessage;
  final bool isDuplicate;
  final String? matchedProjectId;
  final double? matchScore;

  IngestionPipelineResult({
    required this.success,
    required this.enquiry,
    this.createdProspect,
    this.sourceRecord,
    required this.currentStage,
    required this.status,
    this.errorMessage,
    this.isDuplicate = false,
    this.matchedProjectId,
    this.matchScore,
  });
}

/// Orchestrates the 6-stage lead ingestion pipeline for Malaysian property agents.
///
/// Pipeline Stages:
/// 1. Source Validation & Authentication
/// 2. Data Normalisation & PII Sanitization
/// 3. Duplicate Detection & Idempotency
/// 4. Consent and Contact Eligibility Verification
/// 5. Agent Ownership Assignment & Persistence
/// 6. AI Buyer Matching & Advisory Layer
class LeadIngestionPipeline {
  /// Normalizes Malaysian phone numbers to standard E.164 (+601X-XXXXXXX).
  static String normalizeMalaysianPhone(String rawPhone) {
    if (rawPhone.trim().isEmpty) return '';
    // Strip all non-digits except leading +
    String cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+60')) {
      return cleaned;
    } else if (cleaned.startsWith('60')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('01')) {
      return '+60${cleaned.substring(1)}';
    } else if (cleaned.startsWith('1')) {
      return '+60$cleaned';
    }
    return cleaned;
  }

  /// Normalizes email address.
  static String normalizeEmail(String rawEmail) {
    return rawEmail.trim().toLowerCase();
  }

  /// Ingests and processes an incoming enquiry through the full multi-stage pipeline.
  static Future<IngestionPipelineResult> processEnquiry({
    required String ownerId,
    required String sourceType,
    required Map<String, dynamic> rawPayload,
    required List<ProspectModel> existingProspects,
    List<BuyerModel> existingBuyers = const [],
    List<ProjectModel> availableProjects = const [],
  }) async {
    // --------------------------------------------------------------------------
    // STAGE 1: Source Validation & Authentication (with Honeypot Spam Protection)
    // --------------------------------------------------------------------------
    final honeypotVal = rawPayload['honeypot']?.toString() ?? rawPayload['website_hp']?.toString();
    if (honeypotVal != null && honeypotVal.trim().isNotEmpty) {
      final spamEnquiry = EnquiryModel(
        ownerId: ownerId,
        sourceType: sourceType,
        sourceName: rawPayload['sourceName']?.toString() ?? 'Direct Website Form',
        fullName: rawPayload['name']?.toString() ?? 'Automated Bot',
        stage: 'Source Validation',
        processingStatus: 'Rejected',
        statusReason: 'Spam honeypot trap triggered (honeypot field was populated).',
        consentStatus: 'No Consent',
        contactEligibility: 'Ineligible',
        rawMetadata: rawPayload,
      );
      return IngestionPipelineResult(
        success: false,
        enquiry: spamEnquiry,
        currentStage: 'Source Validation',
        status: 'Rejected',
        errorMessage: 'Spam bot submission rejected.',
      );
    }

    final adapter = ProspectSourceRegistry.getAdapter(sourceType);
    if (adapter == null) {
      final rejectedEnquiry = EnquiryModel(
        ownerId: ownerId,
        sourceType: sourceType,
        sourceName: 'Unknown Source Adapter',
        fullName: rawPayload['name']?.toString() ?? 'Unregistered Inquirer',
        stage: 'Source Validation',
        processingStatus: 'Rejected',
        statusReason: 'Unsupported or unregistered source adapter type: $sourceType',
        rawMetadata: rawPayload,
      );
      return IngestionPipelineResult(
        success: false,
        enquiry: rejectedEnquiry,
        currentStage: 'Source Validation',
        status: 'Rejected',
        errorMessage: 'Unsupported source adapter type.',
      );
    }

    // Check adapter-specific structural validity
    final isSourceValid = adapter.validateProspectData(rawPayload);
    final initialEnquiry = adapter.parseEnquiry(ownerId: ownerId, rawPayload: rawPayload);

    if (!isSourceValid) {
      final rejected = initialEnquiry.copyWith(
        stage: 'Source Validation',
        processingStatus: 'Rejected',
        statusReason: 'Incoming payload failed source-specific schema validation.',
      );
      return IngestionPipelineResult(
        success: false,
        enquiry: rejected,
        currentStage: 'Source Validation',
        status: 'Rejected',
        errorMessage: 'Source schema validation failed.',
      );
    }

    // --------------------------------------------------------------------------
    // STAGE 2: Data Normalisation
    // --------------------------------------------------------------------------
    final normPhone = normalizeMalaysianPhone(initialEnquiry.phone);
    final normEmail = normalizeEmail(initialEnquiry.email);

    if (initialEnquiry.fullName.trim().isEmpty) {
      final rejected = initialEnquiry.copyWith(
        stage: 'Data Normalisation',
        processingStatus: 'Rejected',
        statusReason: 'Candidate missing lawful name.',
      );
      return IngestionPipelineResult(
        success: false,
        enquiry: rejected,
        currentStage: 'Data Normalisation',
        status: 'Rejected',
        errorMessage: 'Full name is mandatory.',
      );
    }

    if (normPhone.isEmpty && normEmail.isEmpty) {
      final rejected = initialEnquiry.copyWith(
        stage: 'Data Normalisation',
        processingStatus: 'Rejected',
        statusReason: 'No valid phone or email contact identifier provided.',
      );
      return IngestionPipelineResult(
        success: false,
        enquiry: rejected,
        currentStage: 'Data Normalisation',
        status: 'Rejected',
        errorMessage: 'At least one valid contact identifier (phone or email) is required.',
      );
    }

    final normalizedEnquiry = initialEnquiry.copyWith(
      stage: 'Data Normalisation',
      processingStatus: 'Pending',
      normalizedPhone: normPhone,
      normalizedEmail: normEmail,
      campaignId: rawPayload['campaignId']?.toString() ?? initialEnquiry.campaignId,
      landingPageId: rawPayload['landingPageId']?.toString() ?? initialEnquiry.landingPageId,
      referralSource: rawPayload['referralSource']?.toString() ?? initialEnquiry.referralSource,
      utmSource: rawPayload['utmSource']?.toString() ?? initialEnquiry.utmSource,
      utmMedium: rawPayload['utmMedium']?.toString() ?? initialEnquiry.utmMedium,
      utmCampaign: rawPayload['utmCampaign']?.toString() ?? initialEnquiry.utmCampaign,
      utmTerm: rawPayload['utmTerm']?.toString() ?? initialEnquiry.utmTerm,
      utmContent: rawPayload['utmContent']?.toString() ?? initialEnquiry.utmContent,
      assignedAgentId: (sourceType == 'Direct Website' || sourceType == 'Agent Registration')
          ? ownerId
          : (rawPayload['assignedAgentId']?.toString() ?? initialEnquiry.assignedAgentId),
      routingStatus: (sourceType == 'Direct Website' || sourceType == 'Agent Registration')
          ? 'Direct'
          : (rawPayload['routingStatus']?.toString() ?? initialEnquiry.routingStatus),
      routingReason: rawPayload['routingReason']?.toString() ?? initialEnquiry.routingReason,
      agentSuitabilityScore: (rawPayload['agentSuitabilityScore'] as num?)?.toDouble() ?? initialEnquiry.agentSuitabilityScore,
      routingTimestamp: rawPayload['routingTimestamp'] != null
          ? DateTime.tryParse(rawPayload['routingTimestamp'].toString())
          : initialEnquiry.routingTimestamp,
      enquiryConsentGranted: rawPayload['enquiryConsentGranted'] as bool? ?? true,
      marketingConsentGranted: rawPayload['marketingConsentGranted'] as bool? ?? false,
      acquisitionChannel: (sourceType == 'Direct Website' || sourceType == 'Agent Registration')
          ? 'Channel A: Agent-Generated'
          : (rawPayload['acquisitionChannel']?.toString() ?? initialEnquiry.acquisitionChannel),
    );

    // --------------------------------------------------------------------------
    // STAGE 3: Duplicate Detection & Idempotency
    // --------------------------------------------------------------------------
    // Scope strictly to current agent
    final agentProspects = existingProspects.where((p) => p.ownerId == ownerId).toList();
    final agentBuyers = existingBuyers.where((b) => b.ownerId == ownerId).toList();

    // Check idempotency: If identical source reference ID already exists for this source
    ProspectModel? existingMatch;
    if (normalizedEnquiry.sourceReferenceId != null && normalizedEnquiry.sourceReferenceId!.isNotEmpty) {
      for (final p in agentProspects) {
        if (p.primarySource == sourceType && p.primarySourceId == normalizedEnquiry.sourceReferenceId) {
          existingMatch = p;
          break;
        }
      }
    }

    // Check phone match
    if (existingMatch == null && normPhone.isNotEmpty) {
      for (final p in agentProspects) {
        if (normalizeMalaysianPhone(p.phone) == normPhone) {
          existingMatch = p;
          break;
        }
      }
      if (existingMatch == null) {
        for (final b in agentBuyers) {
          if (normalizeMalaysianPhone(b.phone) == normPhone) {
            existingMatch = ProspectModel(
              id: b.id,
              ownerId: ownerId,
              fullName: b.name,
              phone: b.phone,
              email: b.email,
              preferredState: b.preferredState,
              budgetMin: b.budgetMin,
              budgetMax: b.budgetMax,
              primarySource: 'CRM Buyer Database',
            );
            break;
          }
        }
      }
    }

    // Check email match
    if (existingMatch == null && normEmail.isNotEmpty) {
      for (final p in agentProspects) {
        if (normalizeEmail(p.email) == normEmail) {
          existingMatch = p;
          break;
        }
      }
    }

    if (existingMatch != null) {
      // DUPLICATE DETECTED: Preserve source history, flag duplicate, do NOT duplicate prospect
      final duplicateEnquiry = normalizedEnquiry.copyWith(
        stage: 'Duplicate Detection',
        processingStatus: 'Duplicate',
        statusReason: 'Prospect already exists in agent database (Matched record: ${existingMatch.id}).',
        isDuplicate: true,
        duplicateTargetId: existingMatch.id,
        prospectId: existingMatch.id,
      );

      final sourceRecord = ProspectSourceRecordModel(
        ownerId: ownerId,
        prospectId: existingMatch.id,
        sourceId: 'src-${sourceType.toLowerCase().replaceAll(' ', '-')}',
        sourceName: normalizedEnquiry.sourceName,
        sourceType: sourceType,
        externalReference: normalizedEnquiry.sourceReferenceId,
        rawMetadata: rawPayload,
      );

      return IngestionPipelineResult(
        success: true,
        enquiry: duplicateEnquiry,
        createdProspect: null, // Zero duplicate records created
        sourceRecord: sourceRecord,
        currentStage: 'Duplicate Detection',
        status: 'Duplicate',
        isDuplicate: true,
      );
    }

    // --------------------------------------------------------------------------
    // STAGE 4: Consent & Contact Eligibility Validation
    // --------------------------------------------------------------------------
    String contactEligibility = 'Pending Consent';
    String consentStatus = 'Pending Consent';
    final rawConsent = rawPayload['consentEvidence']?.toString() ??
        rawPayload['consent']?.toString() ??
        rawPayload['pdpa_agreed']?.toString() ??
        rawPayload['pdpa_consent']?.toString();
    final hasConsentEvidence = (rawConsent != null &&
            rawConsent.trim().isNotEmpty &&
            rawConsent.toLowerCase() != 'false' &&
            rawConsent != 'Pending documentation upload') ||
        (normalizedEnquiry.consentEvidence.isNotEmpty &&
            normalizedEnquiry.consentEvidence != 'Pending documentation upload');

    // Check Do Not Contact / Opt Out
    final isDnc = rawPayload['doNotContact'] == true ||
        rawPayload['optOut'] == true ||
        rawPayload['dnc'] == true;

    if (isDnc) {
      contactEligibility = 'Do Not Contact';
      consentStatus = 'Consent Withdrawn';
    } else if (hasConsentEvidence && normalizedEnquiry.contactEligibility != 'Do Not Contact') {
      contactEligibility = 'Eligible';
      consentStatus = 'Consent Granted';
    }

    final consentValidatedEnquiry = normalizedEnquiry.copyWith(
      stage: 'Consent Validation',
      processingStatus: contactEligibility == 'Do Not Contact' ? 'Ineligible' : 'Pending',
      consentStatus: consentStatus,
      contactEligibility: contactEligibility,
      statusReason: contactEligibility == 'Do Not Contact' ? 'Recipient has opted out or requested Do Not Contact.' : null,
    );

    // --------------------------------------------------------------------------
    // STAGE 5: Agent Ownership Assignment & Database Persistence
    // --------------------------------------------------------------------------
    final newProspect = ProspectModel(
      ownerId: ownerId,
      fullName: consentValidatedEnquiry.fullName,
      phone: normPhone,
      email: normEmail,
      preferredLocations: [consentValidatedEnquiry.preferredLocation],
      preferredState: consentValidatedEnquiry.preferredState,
      propertyTypes: [consentValidatedEnquiry.propertyType],
      budgetMin: consentValidatedEnquiry.budgetMin,
      budgetMax: consentValidatedEnquiry.budgetMax,
      purchasePurpose: consentValidatedEnquiry.purchasePurpose,
      buyingTimeline: consentValidatedEnquiry.buyingTimeline,
      status: contactEligibility == 'Eligible' ? 'Qualified' : 'Imported',
      verificationStatus: normPhone.isNotEmpty ? 'Phone Verified' : 'Unverified',
      contactEligibility: contactEligibility,
      consentedPurposes: contactEligibility == 'Eligible'
          ? [
              'Direct Inquiry Response',
              'Property Recommendations',
              if (consentValidatedEnquiry.marketingConsentGranted) 'Marketing & Promotion',
            ]
          : [],
      consentedChannels: normPhone.isNotEmpty ? ['WhatsApp', 'Phone'] : ['Email'],
      primarySource: sourceType,
      primarySourceId: consentValidatedEnquiry.sourceReferenceId,
      confidenceScore: contactEligibility == 'Eligible' ? 85.0 : 70.0,
      notes: consentValidatedEnquiry.notes,
      isDemo: consentValidatedEnquiry.isDemo,
      tags: [
        'Incoming Lead',
        sourceType,
        if (consentValidatedEnquiry.campaignId != null) 'Campaign: ${consentValidatedEnquiry.campaignId}',
        if (consentValidatedEnquiry.isChannelA) 'Channel A: Personal Landing Page',
        if (consentValidatedEnquiry.isChannelB) 'Channel B: Platform Distributed',
      ],
    );

    final sourceRecord = ProspectSourceRecordModel(
      ownerId: ownerId,
      prospectId: newProspect.id,
      sourceId: 'src-${sourceType.toLowerCase().replaceAll(' ', '-')}',
      sourceName: consentValidatedEnquiry.sourceName,
      sourceType: sourceType,
      externalReference: consentValidatedEnquiry.sourceReferenceId,
      rawMetadata: rawPayload,
    );

    // --------------------------------------------------------------------------
    // STAGE 6: AI Buyer Matching & Strategic Advisory Layer
    // --------------------------------------------------------------------------
    String? matchedProjectId;
    String? matchedProjectName;
    double? bestMatchScore;
    String? aiExplanation;
    String? suggestedNextAction;

    if (availableProjects.isNotEmpty) {
      final buyerFormat = BuyerModel(
        id: newProspect.id,
        ownerId: ownerId,
        name: newProspect.fullName,
        phone: newProspect.phone,
        email: newProspect.email,
        budgetMin: newProspect.budgetMin,
        budgetMax: newProspect.budgetMax,
        preferredLocation: consentValidatedEnquiry.preferredLocation,
        preferredState: consentValidatedEnquiry.preferredState,
        propertyType: consentValidatedEnquiry.propertyType,
        purchasePurpose: consentValidatedEnquiry.purchasePurpose,
        buyingTimeline: consentValidatedEnquiry.buyingTimeline,
        leadSource: sourceType,
        createdAt: DateTime.now(),
      );

      // Evaluate compatibility against active projects
      for (final project in availableProjects) {
        final matchResult = MatchingService.calculateMatch(
          buyer: buyerFormat,
          project: project,
        );
        if (bestMatchScore == null || matchResult.overallMatchPercentage > bestMatchScore) {
          bestMatchScore = matchResult.overallMatchPercentage;
          matchedProjectId = project.id;
          matchedProjectName = project.name;

          if (bestMatchScore >= 80) {
            aiExplanation = 'High compatibility (${bestMatchScore.toInt()}%) based on budget (RM${project.startingPrice.toInt()}k) and ${consentValidatedEnquiry.preferredLocation} location match.';
            suggestedNextAction = 'Arrange virtual showroom walkthrough or share digital floorplan brochure.';
          } else if (bestMatchScore >= 50) {
            aiExplanation = 'Moderate compatibility (${bestMatchScore.toInt()}%). Minor layout or price ceiling adjustment required.';
            suggestedNextAction = 'Perform initial financing eligibility check and explore sub-type preferences.';
          } else {
            aiExplanation = 'Low alignment (${bestMatchScore.toInt()}%). Major budget or inter-state location divergence.';
            suggestedNextAction = 'Inquire about secondary location preferences or alternative project tiers.';
          }
        }
      }
    }

    final finalEnquiry = consentValidatedEnquiry.copyWith(
      stage: 'AI Matching Ready',
      processingStatus: contactEligibility == 'Do Not Contact' ? 'Ineligible' : 'Qualified',
      prospectId: newProspect.id,
      matchedProjectId: matchedProjectId,
      matchedProjectName: matchedProjectName,
      matchScore: bestMatchScore,
      aiMatchExplanation: aiExplanation,
      suggestedNextAction: suggestedNextAction,
    );

    return IngestionPipelineResult(
      success: true,
      enquiry: finalEnquiry,
      createdProspect: newProspect,
      sourceRecord: sourceRecord,
      currentStage: 'AI Matching Ready',
      status: finalEnquiry.processingStatus,
      matchedProjectId: matchedProjectId,
      matchScore: bestMatchScore,
    );
  }
}
