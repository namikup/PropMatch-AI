import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/config/pilot_config.dart';
import 'package:propmatch_ai/models/user_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/services/matching_service.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';

void main() {
  group('Phase 5.0A — Buyer Acquisition Pipeline Activation', () {
    const pilotOwnerId = 'pilot-agent-malik-001';

    final pilotAgent = UserModel(
      id: 'usr-pilot-001',
      ownerId: pilotOwnerId,
      landingPageSlug: 'malik-penang',
      fullName: 'Malik Tan',
      email: 'malik@iqirealty.com',
      agencyName: 'IQI Realty Sdn Bhd',
      renNumber: 'REN 52891',
      region: 'Penang & Northern Region',
    );

    final realListing = ProjectModel(
      id: 'proj-penang-pilot-001',
      name: 'Eco Horizon Astonia Townhome',
      developer: 'EcoWorld Development',
      state: 'Penang',
      location: 'Batu Kawan',
      propertyType: 'Terrace House',
      startingPrice: 680000,
      maximumPrice: 850000,
      bedrooms: 4,
      bathrooms: 3,
      builtUpArea: 1850,
      purpose: 'Own Stay & Investment',
      status: 'Under Construction',
      description: 'Gated & guarded landed strata home near Design Village.',
      ownerId: pilotOwnerId,
    );

    // =========================================================================
    // 1. SOURCE VALIDATION & ANTI-TAMPERING
    // =========================================================================
    test('1.1 Ingestion accepts valid direct website enquiry with complete provenance', () async {
      final payload = {
        'name': 'Tan Wei Ming',
        'phone': '012-4455888',
        'email': 'WeiMing.Tan@Hotmail.Com',
        'propertyType': 'Terrace House',
        'location': 'Batu Kawan',
        'budgetMax': 750000.0,
        'buyingPurpose': 'Own Stay',
        'timeline': 'Within 3 months',
        'enquiryConsentGranted': true,
        'marketingConsentGranted': true,
        'campaignId': 'batu-kawan-roadshow-2026',
        'utmSource': 'facebook',
        'utmMedium': 'cpc',
        'utmCampaign': 'penang_property_expo',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: payload,
        existingProspects: const [],
        availableProjects: [realListing],
      );

      expect(result.success, isTrue);
      expect(result.enquiry.ownerId, equals(pilotOwnerId));
      expect(result.enquiry.assignedAgentId, equals(pilotOwnerId));
      expect(result.enquiry.sourceType, equals('Direct Website'));
      expect(result.enquiry.utmSource, equals('facebook'));
      expect(result.enquiry.utmCampaign, equals('penang_property_expo'));
    });

    test('1.2 Ingestion rejects bot submissions populating hidden honeypot field', () async {
      final botPayload = {
        'name': 'Spam Bot Crawler',
        'phone': '0129999999',
        'honeypot': 'http://malicious-spam-url.ru',
        'location': 'Batu Kawan',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: botPayload,
        existingProspects: const [],
      );

      expect(result.success, isFalse);
      expect(result.status, equals('Rejected'));
      expect(result.enquiry.statusReason, contains('Spam honeypot trap'));
      expect(result.createdProspect, isNull);
    });

    test('1.3 Ingestion enforces single-agent isolation against payload tampering', () async {
      final tamperedPayload = {
        'name': 'Unsuspecting Buyer',
        'phone': '0165554433',
        'location': 'Batu Kawan',
        'assignedAgentId': 'malicious-agent-hijacker',
        'ownerId': 'malicious-agent-hijacker',
        'enquiryConsentGranted': true,
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId, // Authoritative pilot agent
        sourceType: 'Direct Website',
        rawPayload: tamperedPayload,
        existingProspects: const [],
      );

      expect(result.success, isTrue);
      // Anti-tampering check: assignedAgentId and ownerId must be forcefully bounded to pilotOwnerId
      expect(result.enquiry.ownerId, equals(pilotOwnerId));
      expect(result.enquiry.assignedAgentId, equals(pilotOwnerId));
      expect(result.createdProspect!.ownerId, equals(pilotOwnerId));
    });

    // =========================================================================
    // 2. NORMALIZATION & CONSENT VERIFICATION
    // =========================================================================
    test('2.1 Malaysian phone and email are correctly sanitized and normalized', () async {
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('012-4455888'), equals('+60124455888'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('6016 223 4455'), equals('+60162234455'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('+6019-8877665'), equals('+60198877665'));
      expect(LeadIngestionPipeline.normalizeEmail('  Tan.WeiMing@Gmail.COM  '), equals('tan.weiming@gmail.com'));
    });

    test('2.2 Explicit PDPA opt-in grants Eligible status; DNC flag suppresses contact', () async {
      // Eligible scenario
      final eligiblePayload = {
        'name': 'Consenting Buyer',
        'phone': '0123344556',
        'location': 'Batu Kawan',
        'enquiryConsentGranted': true,
        'consentEvidence': 'Personal Landing Page Form Checkbox at 2026-11-24',
      };
      final eligibleResult = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: eligiblePayload,
        existingProspects: const [],
      );
      expect(eligibleResult.enquiry.contactEligibility, equals('Eligible'));
      expect(eligibleResult.enquiry.consentStatus, equals('Consent Granted'));
      expect(eligibleResult.createdProspect!.contactEligibility, equals('Eligible'));

      // Do Not Contact scenario
      final dncPayload = {
        'name': 'Opted Out Buyer',
        'phone': '0127788990',
        'location': 'Batu Kawan',
        'doNotContact': true,
      };
      final dncResult = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: dncPayload,
        existingProspects: const [],
      );
      expect(dncResult.enquiry.contactEligibility, equals('Do Not Contact'));
      expect(dncResult.enquiry.processingStatus, equals('Ineligible'));
      expect(dncResult.createdProspect!.contactEligibility, equals('Do Not Contact'));
    });

    // =========================================================================
    // 3. DUPLICATE DETECTION & IDEMPOTENCY
    // =========================================================================
    test('3.1 Re-submission with identical phone within agent database flags duplicate', () async {
      final existingProspect = ProspectModel(
        id: 'prosp-existing-001',
        ownerId: pilotOwnerId,
        fullName: 'Original Inquirer',
        phone: '+60124455888',
        email: 'original@gmail.com',
        preferredState: 'Penang',
        budgetMin: 500000,
        budgetMax: 700000,
        primarySource: 'Direct Website',
      );

      final secondPayload = {
        'name': 'Original Inquirer (Second Enquiry)',
        'phone': '012-4455888', // Normalized to +60124455888
        'location': 'Batu Kawan',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: secondPayload,
        existingProspects: [existingProspect],
      );

      expect(result.isDuplicate, isTrue);
      expect(result.status, equals('Duplicate'));
      expect(result.createdProspect, isNull); // Zero duplicate prospect created
      expect(result.enquiry.duplicateTargetId, equals('prosp-existing-001'));
    });

    // =========================================================================
    // 4. CONNECT INGESTION TO DETERMINISTIC AI BUYER MATCHING
    // =========================================================================
    test('4.1 Eligible enquiry is deterministically matched against agent real property', () async {
      final highMatchPayload = {
        'name': 'Kelvin Chong',
        'phone': '012-4567890',
        'email': 'kelvin@techcorp.my',
        'propertyType': 'Terrace House',
        'location': 'Batu Kawan',
        'budgetMax': 800000.0,
        'buyingPurpose': 'Own Stay & Investment',
        'timeline': 'Within 3 months',
        'enquiryConsentGranted': true,
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: highMatchPayload,
        existingProspects: const [],
        availableProjects: [realListing],
      );

      expect(result.success, isTrue);
      expect(result.matchedProjectId, equals('proj-penang-pilot-001'));
      expect(result.matchScore, isNotNull);
      // High score (> 80%) because Budget, Location, Type, Purpose, and Timeline align
      expect(result.matchScore!, greaterThanOrEqualTo(85.0));
      expect(result.enquiry.aiMatchExplanation, contains('High compatibility'));
      expect(result.enquiry.suggestedNextAction, contains('Arrange virtual showroom walkthrough'));
    });

    test('4.2 Mismatched enquiry receives realistic lower score without hallucinated alignment', () async {
      final mismatchPayload = {
        'name': 'Siti Nurhaliza',
        'phone': '019-3322110',
        'email': 'siti@firm.com.my',
        'propertyType': 'Bungalow', // Mismatched type
        'location': 'Johor Bahru', // Mismatched location
        'budgetMax': 400000.0, // Major budget shortfall (< RM680k)
        'buyingPurpose': 'Investment',
        'timeline': 'Just exploring',
        'enquiryConsentGranted': true,
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: mismatchPayload,
        existingProspects: const [],
        availableProjects: [realListing],
      );

      expect(result.success, isTrue);
      expect(result.matchScore, isNotNull);
      // Score must be Low (< 50%) reflecting the genuine mismatch
      expect(result.matchScore!, lessThan(50.0));
      expect(result.enquiry.aiMatchExplanation, contains('Low alignment'));
      expect(result.enquiry.suggestedNextAction, contains('secondary location preferences'));
    });

    test('4.3 Missing buyer information is not fabricated with 100% false score', () {
      final partialBuyer = BuyerModel(
        ownerId: pilotOwnerId,
        name: 'Anonymous Exploratory Lead',
        phone: '+60124440000',
        preferredLocation: '',
        preferredState: '',
        budgetMin: 0,
        budgetMax: 0, // Unspecified budget
        propertyType: '', // Unspecified type
        purchasePurpose: '', // Unspecified purpose
        buyingTimeline: '', // Unspecified timeline
        leadSource: 'Direct Website',
      );

      final match = MatchingService.calculateMatch(
        buyer: partialBuyer,
        project: realListing,
      );

      // Must heavily penalize missing info and never fabricate 100%
      expect(match.overallMatchPercentage, lessThan(60.0));
      expect(match.confidenceLevel, equals('Low'));
      expect(match.missingInformation.length, greaterThanOrEqualTo(3));
    });

    // =========================================================================
    // 5. SINGLE-AGENT RESTRICTION VERIFICATION
    // =========================================================================
    test('5.1 Single-Agent Pilot configuration restricts access exclusively to pilot agent', () {
      expect(PilotConfig.isSingleAgentPilotMode, isTrue);
      expect(PilotConfig.enablePublicAgentDirectory, isFalse);
      expect(PilotConfig.enablePlatformLeadDistribution, isFalse);
      expect(PilotConfig.enableSubscriptionTiersUI, isFalse);
      expect(PilotConfig.isUserAuthorized(pilotAgent.email, pilotAgent.ownerId), isTrue);
      expect(PilotConfig.isUserAuthorized('stranger@gmail.com', 'unauthorized-user'), isFalse);
    });

    test('5.2 Converting Ingested Prospect to CRM Buyer persists under pilotOwnerId', () async {
      final appState = AppStateProvider();

      final prospect = ProspectModel(
        id: 'prosp-convert-001',
        ownerId: appState.currentOwnerId,
        fullName: 'Lee Chong Wei',
        phone: '+60128889999',
        email: 'chongwei@badminton.org.my',
        budgetMin: 700000,
        budgetMax: 900000,
        preferredLocations: const ['Batu Kawan'],
        preferredState: 'Penang',
        propertyTypes: const ['Terrace House'],
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        primarySource: 'Direct Website',
      );

      final createdBuyer = await appState.convertProspectToBuyer(prospect);

      expect(createdBuyer.ownerId, equals(appState.currentOwnerId));
      expect(createdBuyer.name, equals('Lee Chong Wei'));
      expect(createdBuyer.leadSource, equals('Direct Website'));
      expect(appState.buyers.any((b) => b.id == createdBuyer.id), isTrue);
    });
  });
}
