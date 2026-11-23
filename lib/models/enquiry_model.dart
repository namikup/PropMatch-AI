import 'package:uuid/uuid.dart';

/// Entity representing an incoming buyer enquiry across various acquisition sources
/// (Property Portals, Partner Agencies, Developers, Direct Website, CRM Imports).
class EnquiryModel {
  final String id;
  final String ownerId; // Immutable agent UID (or 'unassigned' if waiting in Channel B queue)
  final String acquisitionChannel; // 'Channel A: Agent-Generated' vs 'Channel B: Platform-Generated'
  final String sourceType; // 'Property Portal', 'Partner Agency', 'Developer', 'Direct Website', 'CRM Import'
  final String sourceName; // e.g. 'iProperty Malaysia', 'PropertyGuru', 'EcoWorld Gallery', 'Personal Website'
  final String? sourceReferenceId; // External lead reference / inquiry ID
  final DateTime enquiryTimestamp; // When the prospective buyer submitted the inquiry
  final DateTime receivedAt; // When PropMatch AI received the lead
  final String fullName;
  final String phone;
  final String normalizedPhone;
  final String email;
  final String normalizedEmail;
  final String preferredLocation;
  final String preferredState;
  final String propertyType;
  final double budgetMin;
  final double budgetMax;
  final String purchasePurpose; // 'Own Stay', 'Investment', 'Both'
  final String buyingTimeline; // 'Immediately', '1-3 months', '3-6 months', 'Exploring'
  final String notes;

  // Channel A: Campaign & Attribution Tracking
  final String? campaignId;
  final String? landingPageId;
  final String? referralSource;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmTerm;
  final String? utmContent;

  // Channel B: Platform Lead Distribution & Transparent Routing
  final String? assignedAgentId;
  final String routingStatus; // 'Direct', 'Assigned', 'Unassigned Queue'
  final String? routingReason;
  final double? agentSuitabilityScore;
  final DateTime? routingTimestamp;

  // Pipeline Execution State
  final String stage; // 'Source Validation', 'Data Normalisation', 'Duplicate Detection', 'Consent Validation', 'Agent Assignment', 'Database Persisted', 'AI Matching Ready'
  final String processingStatus; // 'Received', 'Pending', 'Qualified', 'Duplicate', 'Ineligible', 'Rejected', 'Failed'
  final String? statusReason;
  final String? prospectId; // Linked prospect record ID once saved

  // Consent & Contact Eligibility
  final String consentStatus; // 'Consent Granted', 'Pending Consent', 'Consent Withdrawn', 'No Consent'
  final String consentEvidence;
  final String contactEligibility; // 'Eligible', 'Pending Consent', 'Ineligible', 'Do Not Contact'
  final bool enquiryConsentGranted; // Specific consent to be contacted regarding this enquiry
  final bool marketingConsentGranted; // Distinct opt-in for future promotional/marketing updates

  // Duplicate Tracking
  final bool isDuplicate;
  final String? duplicateTargetId;

  // AI Matching Recommendation
  final String? matchedProjectId;
  final String? matchedProjectName;
  final double? matchScore; // Deterministic 0 - 100 compatibility score
  final String? aiMatchExplanation;
  final String? suggestedNextAction;

  final bool isDemo;
  final Map<String, dynamic> rawMetadata;

  EnquiryModel({
    String? id,
    required this.ownerId,
    String? acquisitionChannel,
    required this.sourceType,
    required this.sourceName,
    this.sourceReferenceId,
    DateTime? enquiryTimestamp,
    DateTime? receivedAt,
    required this.fullName,
    this.phone = '',
    this.normalizedPhone = '',
    this.email = '',
    this.normalizedEmail = '',
    this.preferredLocation = 'Kuala Lumpur',
    this.preferredState = 'Kuala Lumpur',
    this.propertyType = 'Condominium',
    this.budgetMin = 400000.0,
    this.budgetMax = 700000.0,
    this.purchasePurpose = 'Own Stay',
    this.buyingTimeline = '1-3 months',
    this.notes = '',
    this.campaignId,
    this.landingPageId,
    this.referralSource,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.assignedAgentId,
    this.routingStatus = 'Direct',
    this.routingReason,
    this.agentSuitabilityScore,
    this.routingTimestamp,
    this.stage = 'Source Validation',
    this.processingStatus = 'Received',
    this.statusReason,
    this.prospectId,
    this.consentStatus = 'Pending Consent',
    this.consentEvidence = '',
    this.contactEligibility = 'Pending Consent',
    this.enquiryConsentGranted = true,
    this.marketingConsentGranted = false,
    this.isDuplicate = false,
    this.duplicateTargetId,
    this.matchedProjectId,
    this.matchedProjectName,
    this.matchScore,
    this.aiMatchExplanation,
    this.suggestedNextAction,
    this.isDemo = false,
    this.rawMetadata = const {},
  })  : id = id ?? const Uuid().v4(),
        acquisitionChannel = acquisitionChannel ??
            (sourceType == 'Direct Website' || sourceType == 'CRM Import'
                ? 'Channel A: Agent-Generated'
                : 'Channel B: Platform-Generated'),
        enquiryTimestamp = enquiryTimestamp ?? DateTime.now(),
        receivedAt = receivedAt ?? DateTime.now();

  bool get isQualified => processingStatus == 'Qualified';
  bool get isPending => processingStatus == 'Pending';
  bool get isRejected => processingStatus == 'Rejected' || processingStatus == 'Failed';
  bool get isContactEligible => contactEligibility == 'Eligible';
  bool get isDoNotContact => contactEligibility == 'Do Not Contact';
  bool get isChannelA => acquisitionChannel.contains('Channel A');
  bool get isChannelB => acquisitionChannel.contains('Channel B');
  bool get isUnassigned => routingStatus == 'Unassigned Queue' || ownerId == 'unassigned';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'acquisitionChannel': acquisitionChannel,
      'sourceType': sourceType,
      'sourceName': sourceName,
      'sourceReferenceId': sourceReferenceId,
      'enquiryTimestamp': enquiryTimestamp.toIso8601String(),
      'receivedAt': receivedAt.toIso8601String(),
      'fullName': fullName,
      'phone': phone,
      'normalizedPhone': normalizedPhone,
      'email': email,
      'normalizedEmail': normalizedEmail,
      'preferredLocation': preferredLocation,
      'preferredState': preferredState,
      'propertyType': propertyType,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'purchasePurpose': purchasePurpose,
      'buyingTimeline': buyingTimeline,
      'notes': notes,
      'campaignId': campaignId,
      'landingPageId': landingPageId,
      'referralSource': referralSource,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'utmTerm': utmTerm,
      'utmContent': utmContent,
      'assignedAgentId': assignedAgentId,
      'routingStatus': routingStatus,
      'routingReason': routingReason,
      'agentSuitabilityScore': agentSuitabilityScore,
      'routingTimestamp': routingTimestamp?.toIso8601String(),
      'stage': stage,
      'processingStatus': processingStatus,
      'statusReason': statusReason,
      'prospectId': prospectId,
      'consentStatus': consentStatus,
      'consentEvidence': consentEvidence,
      'contactEligibility': contactEligibility,
      'enquiryConsentGranted': enquiryConsentGranted,
      'marketingConsentGranted': marketingConsentGranted,
      'isDuplicate': isDuplicate,
      'duplicateTargetId': duplicateTargetId,
      'matchedProjectId': matchedProjectId,
      'matchedProjectName': matchedProjectName,
      'matchScore': matchScore,
      'aiMatchExplanation': aiMatchExplanation,
      'suggestedNextAction': suggestedNextAction,
      'isDemo': isDemo,
      'rawMetadata': rawMetadata,
    };
  }

  factory EnquiryModel.fromMap(Map<String, dynamic> map) {
    return EnquiryModel(
      id: map['id']?.toString() ?? const Uuid().v4(),
      ownerId: map['ownerId']?.toString() ?? '',
      acquisitionChannel: map['acquisitionChannel']?.toString(),
      sourceType: map['sourceType']?.toString() ?? 'Direct Website',
      sourceName: map['sourceName']?.toString() ?? 'Website Lead Form',
      sourceReferenceId: map['sourceReferenceId']?.toString(),
      enquiryTimestamp: map['enquiryTimestamp'] != null
          ? DateTime.tryParse(map['enquiryTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      receivedAt: map['receivedAt'] != null
          ? DateTime.tryParse(map['receivedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fullName: map['fullName']?.toString() ?? 'Anonymous Prospect',
      phone: map['phone']?.toString() ?? '',
      normalizedPhone: map['normalizedPhone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      normalizedEmail: map['normalizedEmail']?.toString() ?? '',
      preferredLocation: map['preferredLocation']?.toString() ?? 'Kuala Lumpur',
      preferredState: map['preferredState']?.toString() ?? 'Kuala Lumpur',
      propertyType: map['propertyType']?.toString() ?? 'Condominium',
      budgetMin: (map['budgetMin'] as num?)?.toDouble() ?? 400000.0,
      budgetMax: (map['budgetMax'] as num?)?.toDouble() ?? 700000.0,
      purchasePurpose: map['purchasePurpose']?.toString() ?? 'Own Stay',
      buyingTimeline: map['buyingTimeline']?.toString() ?? '1-3 months',
      notes: map['notes']?.toString() ?? '',
      campaignId: map['campaignId']?.toString(),
      landingPageId: map['landingPageId']?.toString(),
      referralSource: map['referralSource']?.toString(),
      utmSource: map['utmSource']?.toString(),
      utmMedium: map['utmMedium']?.toString(),
      utmCampaign: map['utmCampaign']?.toString(),
      utmTerm: map['utmTerm']?.toString(),
      utmContent: map['utmContent']?.toString(),
      assignedAgentId: map['assignedAgentId']?.toString(),
      routingStatus: map['routingStatus']?.toString() ?? 'Direct',
      routingReason: map['routingReason']?.toString(),
      agentSuitabilityScore: (map['agentSuitabilityScore'] as num?)?.toDouble(),
      routingTimestamp: map['routingTimestamp'] != null
          ? DateTime.tryParse(map['routingTimestamp'].toString())
          : null,
      stage: map['stage']?.toString() ?? 'Source Validation',
      processingStatus: map['processingStatus']?.toString() ?? 'Received',
      statusReason: map['statusReason']?.toString(),
      prospectId: map['prospectId']?.toString(),
      consentStatus: map['consentStatus']?.toString() ?? 'Pending Consent',
      consentEvidence: map['consentEvidence']?.toString() ?? '',
      contactEligibility: map['contactEligibility']?.toString() ?? 'Pending Consent',
      enquiryConsentGranted: map['enquiryConsentGranted'] as bool? ?? true,
      marketingConsentGranted: map['marketingConsentGranted'] as bool? ?? false,
      isDuplicate: map['isDuplicate'] as bool? ?? false,
      duplicateTargetId: map['duplicateTargetId']?.toString(),
      matchedProjectId: map['matchedProjectId']?.toString(),
      matchedProjectName: map['matchedProjectName']?.toString(),
      matchScore: (map['matchScore'] as num?)?.toDouble(),
      aiMatchExplanation: map['aiMatchExplanation']?.toString(),
      suggestedNextAction: map['suggestedNextAction']?.toString(),
      isDemo: map['isDemo'] as bool? ?? false,
      rawMetadata: map['rawMetadata'] != null
          ? Map<String, dynamic>.from(map['rawMetadata'] as Map)
          : const {},
    );
  }

  EnquiryModel copyWith({
    String? ownerId,
    String? acquisitionChannel,
    String? stage,
    String? processingStatus,
    String? statusReason,
    String? prospectId,
    String? normalizedPhone,
    String? normalizedEmail,
    String? campaignId,
    String? landingPageId,
    String? referralSource,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? utmTerm,
    String? utmContent,
    String? assignedAgentId,
    String? routingStatus,
    String? routingReason,
    double? agentSuitabilityScore,
    DateTime? routingTimestamp,
    String? consentStatus,
    String? consentEvidence,
    String? contactEligibility,
    bool? enquiryConsentGranted,
    bool? marketingConsentGranted,
    bool? isDuplicate,
    String? duplicateTargetId,
    String? matchedProjectId,
    String? matchedProjectName,
    double? matchScore,
    String? aiMatchExplanation,
    String? suggestedNextAction,
  }) {
    return EnquiryModel(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      acquisitionChannel: acquisitionChannel ?? this.acquisitionChannel,
      sourceType: sourceType,
      sourceName: sourceName,
      sourceReferenceId: sourceReferenceId,
      enquiryTimestamp: enquiryTimestamp,
      receivedAt: receivedAt,
      fullName: fullName,
      phone: phone,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      email: email,
      normalizedEmail: normalizedEmail ?? this.normalizedEmail,
      preferredLocation: preferredLocation,
      preferredState: preferredState,
      propertyType: propertyType,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      purchasePurpose: purchasePurpose,
      buyingTimeline: buyingTimeline,
      notes: notes,
      campaignId: campaignId ?? this.campaignId,
      landingPageId: landingPageId ?? this.landingPageId,
      referralSource: referralSource ?? this.referralSource,
      utmSource: utmSource ?? this.utmSource,
      utmMedium: utmMedium ?? this.utmMedium,
      utmCampaign: utmCampaign ?? this.utmCampaign,
      utmTerm: utmTerm ?? this.utmTerm,
      utmContent: utmContent ?? this.utmContent,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      routingStatus: routingStatus ?? this.routingStatus,
      routingReason: routingReason ?? this.routingReason,
      agentSuitabilityScore: agentSuitabilityScore ?? this.agentSuitabilityScore,
      routingTimestamp: routingTimestamp ?? this.routingTimestamp,
      stage: stage ?? this.stage,
      processingStatus: processingStatus ?? this.processingStatus,
      statusReason: statusReason ?? this.statusReason,
      prospectId: prospectId ?? this.prospectId,
      consentStatus: consentStatus ?? this.consentStatus,
      consentEvidence: consentEvidence ?? this.consentEvidence,
      contactEligibility: contactEligibility ?? this.contactEligibility,
      enquiryConsentGranted: enquiryConsentGranted ?? this.enquiryConsentGranted,
      marketingConsentGranted: marketingConsentGranted ?? this.marketingConsentGranted,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateTargetId: duplicateTargetId ?? this.duplicateTargetId,
      matchedProjectId: matchedProjectId ?? this.matchedProjectId,
      matchedProjectName: matchedProjectName ?? this.matchedProjectName,
      matchScore: matchScore ?? this.matchScore,
      aiMatchExplanation: aiMatchExplanation ?? this.aiMatchExplanation,
      suggestedNextAction: suggestedNextAction ?? this.suggestedNextAction,
      isDemo: isDemo,
      rawMetadata: rawMetadata,
    );
  }
}
