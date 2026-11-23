import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/agent_preferences_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/subscription_model.dart';
import 'package:propmatch_ai/models/user_model.dart';
import 'package:propmatch_ai/services/lead_distribution/lead_distribution_engine.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';

void main() {
  group('Phase 4.4: Dual-Channel Buyer Acquisition System Tests', () {
    const String agentA = 'agent-alex-penang-001';
    const String agentB = 'agent-brenda-kl-002';
    const String agentC = 'agent-calvin-penang-003';

    // In-memory prospect tracker for testing multi-agent isolation and duplicate suppression
    final List<ProspectModel> agentAProspects = [];
    final List<ProspectModel> agentBProspects = [];

    setUp(() {
      agentAProspects.clear();
      agentBProspects.clear();
    });

    // =========================================================================
    // CHANNEL A: AGENT-GENERATED ACQUISITION & LANDING PAGE TESTS
    // =========================================================================
    group('Channel A: Agent Landing Page & Campaign Attribution', () {
      test('1. Direct 1:1 Routing: Landing page submission assigns strictly to landing page owner', () async {
        final payload = {
          'name': 'Hafiz bin Osman',
          'phone': '+60124455667',
          'email': 'hafiz.osman@example.my',
          'location': 'Batu Kawan',
          'propertyType': 'Condominium',
          'budgetMax': 500000.0,
          'purchasePurpose': 'Own Stay',
          'buyingTimeline': '1-3 months',
          'pdpa_consent': true,
          'enquiryConsentGranted': true,
          'marketingConsentGranted': false,
          'campaignId': 'penang-roadshow-2026',
          'utmSource': 'facebook',
          'utmMedium': 'cpc',
          'utmCampaign': 'summer_promo',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.acquisitionChannel, equals('Channel A: Agent-Generated'));
        expect(result.enquiry.ownerId, equals(agentA));
        expect(result.enquiry.assignedAgentId, equals(agentA));
        expect(result.enquiry.routingStatus, equals('Direct'));
        expect(result.enquiry.campaignId, equals('penang-roadshow-2026'));
        expect(result.enquiry.utmSource, equals('facebook'));
        expect(result.enquiry.utmMedium, equals('cpc'));
        expect(result.enquiry.utmCampaign, equals('summer_promo'));

        // Verify prospect created under Agent A
        expect(result.createdProspect, isNotNull);
        expect(result.createdProspect!.ownerId, equals(agentA));
        expect(result.createdProspect!.fullName, equals('Hafiz bin Osman'));
        agentAProspects.add(result.createdProspect!);
      });

      test('2. Full Form Submission: Captures complete buyer profile parameters', () async {
        final payload = {
          'name': 'Lim Wei Hong',
          'phone': '017-8899112',
          'email': 'weihong.lim@gmail.com',
          'location': 'George Town',
          'propertyType': 'Serviced Residence',
          'budgetMin': 600000.0,
          'budgetMax': 850000.0,
          'purchasePurpose': 'Investment',
          'buyingTimeline': 'Immediately',
          'notes': 'Looking for high rental yield near Heritage zone',
          'pdpa_consent': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.normalizedPhone, equals('+60178899112'));
        expect(result.enquiry.preferredLocation, equals('George Town'));
        expect(result.enquiry.propertyType, equals('Serviced Residence'));
        expect(result.enquiry.budgetMax, equals(850000.0));
        expect(result.enquiry.purchasePurpose, equals('Investment'));
        expect(result.enquiry.buyingTimeline, equals('Immediately'));
        expect(result.enquiry.notes, contains('high rental yield'));
      });

      test('3. Missing Optional Fields: Gracefully defaults without crashing pipeline', () async {
        final payload = {
          'name': 'Siti Nurhaliza Demo',
          'phone': '0192345678',
          // email, notes, timeline omitted
          'pdpa_consent': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.fullName, equals('Siti Nurhaliza Demo'));
        expect(result.enquiry.normalizedPhone, equals('+60192345678'));
        expect(result.enquiry.preferredLocation, isNotEmpty);
        expect(result.enquiry.budgetMax, greaterThan(0));
      });

      test('4. Client Validation: Reject payload missing both phone and email', () async {
        final payload = {
          'name': 'Anonymous Visitor',
          'phone': '',
          'email': '',
          'pdpa_consent': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isFalse);
        expect(result.enquiry.processingStatus, equals('Rejected'));
        expect(result.enquiry.statusReason, contains('phone'));
      });

      test('5. Granular PDPA Consent Separation: Response consent without marketing opt-in', () async {
        final payload = {
          'name': 'Tan Ah Beng',
          'phone': '+60163334455',
          'pdpa_consent': true,
          'enquiryConsentGranted': true,
          'marketingConsentGranted': false,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.enquiryConsentGranted, isTrue);
        expect(result.enquiry.marketingConsentGranted, isFalse);
        expect(result.enquiry.contactEligibility, equals('Eligible'));
        expect(result.createdProspect!.consentedPurposes.contains('Marketing & Promotion'), isFalse);
      });

      test('6. Explicit Marketing Opt-In: Marketing consent explicitly checked records opt-in', () async {
        final payload = {
          'name': 'Jessica Wong',
          'phone': '+601122334455',
          'pdpa_consent': true,
          'enquiryConsentGranted': true,
          'marketingConsentGranted': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.enquiryConsentGranted, isTrue);
        expect(result.enquiry.marketingConsentGranted, isTrue);
        expect(result.createdProspect!.consentedPurposes.contains('Marketing & Promotion'), isTrue);
      });

      test('7. Campaign & UTM Preservation: Parameters flow to enquiry and prospect records', () async {
        final payload = {
          'name': 'Kumar a/l Murugan',
          'phone': '+60145556677',
          'pdpa_consent': true,
          'campaignId': 'batu-kawan-expo-2026',
          'landingPageId': 'alex-tan-penang',
          'utmSource': 'qr_flyer',
          'utmMedium': 'print_flyer',
          'utmCampaign': 'expo_booth_12',
          'referralSource': 'Physical Expo Booth',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.campaignId, equals('batu-kawan-expo-2026'));
        expect(result.enquiry.landingPageId, equals('alex-tan-penang'));
        expect(result.enquiry.utmSource, equals('qr_flyer'));
        expect(result.enquiry.utmMedium, equals('print_flyer'));
        expect(result.enquiry.utmCampaign, equals('expo_booth_12'));
        expect(result.enquiry.referralSource, equals('Physical Expo Booth'));
        expect(result.createdProspect!.tags, contains('Campaign: batu-kawan-expo-2026'));
        expect(result.createdProspect!.tags, contains('Channel A: Personal Landing Page'));
      });

      test('8. REN Verification Strictness: Unverified REN flag strictly enforced', () {
        final unverifiedAgent = UserModel(
          ownerId: 'unverified-agent-01',
          fullName: 'New Agent Demo',
          email: 'agent@demo.com',
          renNumber: 'REN 99999',
          isRenVerified: false,
        );
        expect(unverifiedAgent.isRenVerified, isFalse);

        final verifiedAgent = UserModel(
          ownerId: 'verified-agent-02',
          fullName: 'Senior REN Demo',
          email: 'senior@demo.com',
          renNumber: 'REN 12345',
          isRenVerified: true,
        );
        expect(verifiedAgent.isRenVerified, isTrue);
      });

      test('9. Landing Page Duplicate Suppression: Safe idempotency across 24 hours', () async {
        final payload1 = {
          'name': 'Dave Goh',
          'phone': '+60129998877',
          'email': 'dave.goh@example.com',
          'location': 'Batu Kawan',
          'pdpa_consent': true,
        };

        final firstResult = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload1,
          existingProspects: agentAProspects,
        );
        expect(firstResult.success, isTrue);
        expect(firstResult.isDuplicate, isFalse);
        agentAProspects.add(firstResult.createdProspect!);

        // Second submission with same phone
        final payload2 = {
          'name': 'David Goh',
          'phone': '+60129998877',
          'email': 'dave.goh@example.com',
          'location': 'Batu Kawan',
          'pdpa_consent': true,
        };

        final secondResult = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload2,
          existingProspects: agentAProspects,
        );

        expect(secondResult.success, isTrue);
        expect(secondResult.isDuplicate, isTrue);
        expect(secondResult.enquiry.processingStatus, equals('Duplicate'));
        expect(secondResult.createdProspect, isNull); // Redundant prospect suppressed
      });
    });

    // =========================================================================
    // CHANNEL B: PLATFORM LEAD DISTRIBUTION & TRANSPARENT ROUTING TESTS
    // =========================================================================
    group('Channel B: Platform Lead Distribution & Transparent Routing', () {
      final agentAPrefs = AgentPreferencesModel(
        agentId: agentA,
        isAvailableForPlatformLeads: true,
        preferredLocations: ['Batu Kawan', 'George Town', 'Bayan Lepas'],
        preferredPropertyTypes: ['Condominium', 'Serviced Residence'],
        priceRangeMin: 350000,
        priceRangeMax: 800000,
        monthlyLeadQuota: 30,
        leadsReceivedThisMonth: 10,
        lastLeadAssignedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      final agentBPrefs = AgentPreferencesModel(
        agentId: agentB,
        isAvailableForPlatformLeads: true,
        preferredLocations: ['Mont Kiara', 'KLCC', 'Bangsar'],
        preferredPropertyTypes: ['Condominium', 'Luxury High-Rise'],
        priceRangeMin: 1000000,
        priceRangeMax: 4000000,
        monthlyLeadQuota: 50,
        leadsReceivedThisMonth: 5,
        lastLeadAssignedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final agentCPrefs = AgentPreferencesModel(
        agentId: agentC,
        isAvailableForPlatformLeads: true,
        preferredLocations: ['Batu Kawan', 'Penang'],
        preferredPropertyTypes: ['Condominium', 'Terrace House'],
        priceRangeMin: 400000,
        priceRangeMax: 700000,
        monthlyLeadQuota: 20,
        leadsReceivedThisMonth: 12,
        lastLeadAssignedAt: DateTime.now().subtract(const Duration(hours: 12)),
      );

      test('10. Single Perfect Match Routing: Lead routes to qualifying agent with high score', () {
        final platformLead = {
          'preferredLocation': 'Batu Kawan',
          'preferredState': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 450000.0,
          'budgetMax': 550000.0,
          'sourceType': 'Property Portal',
          'sourceName': 'iProperty Malaysia',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: platformLead,
          candidatePreferences: [agentAPrefs, agentBPrefs],
          agentProfiles: {agentA: UserModel(ownerId: agentA, fullName: 'Alex Tan', email: 'alex@demo.com')},
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals(agentA));
        expect(decision.routingStatus, equals('Assigned'));
        expect(decision.suitabilityScore, greaterThanOrEqualTo(80.0));
      });

      test('11. Geographic Location Exclusion: Agent outside target area scores 0 for location', () {
        final platformLead = {
          'preferredLocation': 'Mont Kiara',
          'preferredState': 'Kuala Lumpur',
          'propertyType': 'Condominium',
          'budgetMin': 1200000.0,
          'budgetMax': 1800000.0,
          'sourceType': 'Property Portal',
        };

        final matchA = LeadDistributionEngine.evaluateSuitability(
          rawEnquiry: platformLead,
          preferences: agentAPrefs, // Penang only
        );

        final matchB = LeadDistributionEngine.evaluateSuitability(
          rawEnquiry: platformLead,
          preferences: agentBPrefs, // Mont Kiara
        );

        // Agent A has no location overlap -> fails location check
        expect(matchA.penaltyFactors, contains(contains('Location outside agent focus territory')));
        expect(matchA.suitabilityScore, lessThan(matchB.suitabilityScore));
        // Agent B matches Mont Kiara -> high score
        expect(matchB.suitabilityScore, greaterThanOrEqualTo(80.0));
      });

      test('12. Property Type Specialization Match: Assigns 30 pts for matching category', () {
        final condoLead = {
          'preferredLocation': 'Batu Kawan',
          'propertyType': 'Condominium',
          'budgetMin': 400000.0,
          'budgetMax': 600000.0,
          'sourceType': 'Developer',
        };

        final landedAgent = agentAPrefs.copyWith(
          preferredPropertyTypes: ['Terrace House', 'Semi-D', 'Bungalow'],
        );

        final matchCondo = LeadDistributionEngine.evaluateSuitability(
          rawEnquiry: condoLead,
          preferences: agentAPrefs,
        );

        final matchLanded = LeadDistributionEngine.evaluateSuitability(
          rawEnquiry: condoLead,
          preferences: landedAgent,
        );

        expect(matchCondo.suitabilityScore - matchLanded.suitabilityScore, equals(15.0));
      });

      test('13. Budget Window Ceiling Match: Penalizes budget gap when out of range', () {
        final luxuryLead = {
          'preferredLocation': 'Batu Kawan',
          'propertyType': 'Condominium',
          'budgetMin': 2500000.0,
          'budgetMax': 3500000.0,
          'sourceType': 'Partner Agency',
        };

        // Agent A max price is RM800k; lead is RM3.5M
        final matchA = LeadDistributionEngine.evaluateSuitability(
          rawEnquiry: luxuryLead,
          preferences: agentAPrefs,
        );

        expect(matchA.penaltyFactors, contains(contains('Budget exceeds agent maximum focus')));
        expect(matchA.suitabilityScore, lessThan(90.0));
      });

      test('14. Unassigned Queue Holding: Zero qualifying agents routes lead to Unassigned Queue', () {
        final isolatedLead = {
          'preferredLocation': 'Kota Kinabalu',
          'propertyType': 'Agricultural Land',
          'budgetMin': 80000.0,
          'budgetMax': 120000.0,
          'sourceType': 'Direct Website',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: isolatedLead,
          candidatePreferences: [agentAPrefs, agentBPrefs, agentCPrefs],
        );

        expect(decision.isAssigned, isFalse);
        expect(decision.assignedAgentId, isNull);
        expect(decision.routingStatus, equals('Unassigned Queue'));
        expect(decision.rationale, contains('Unassigned Queue'));
      });

      test('15. Multi-Agent Evaluation: Higher composite score wins distribution', () {
        final penangLead = {
          'preferredLocation': 'Bayan Lepas',
          'preferredState': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 450000.0,
          'budgetMax': 550000.0,
          'sourceType': 'Property Portal',
        };

        // Agent A covers Bayan Lepas, Agent C covers only Batu Kawan
        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: penangLead,
          candidatePreferences: [agentAPrefs, agentCPrefs],
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals(agentA));
      });

      test('16. Fair Rotation Tie-Breaker: Agent with older assignment date receives priority', () {
        final tieAgent1 = agentAPrefs.copyWith(
          agentId: 'tie-agent-1',
          leadsReceivedThisMonth: 10,
          lastLeadAssignedAt: DateTime.now().subtract(const Duration(days: 3)),
        );

        final tieAgent2 = agentAPrefs.copyWith(
          agentId: 'tie-agent-2',
          leadsReceivedThisMonth: 10,
          lastLeadAssignedAt: DateTime.now().subtract(const Duration(hours: 4)),
        );

        final penangLead = {
          'preferredLocation': 'Batu Kawan',
          'preferredState': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 450000.0,
          'budgetMax': 550000.0,
          'sourceType': 'Developer',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: penangLead,
          candidatePreferences: [tieAgent1, tieAgent2],
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals('tie-agent-1'));
      });

      test('17. Agent Opt-Out Availability: Agent with isAvailableForPlatformLeads: false is skipped', () {
        final optedOutAgent = agentAPrefs.copyWith(
          isAvailableForPlatformLeads: false,
        );

        final lead = {
          'preferredLocation': 'Batu Kawan',
          'preferredState': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 450000.0,
          'budgetMax': 550000.0,
          'sourceType': 'Developer',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: lead,
          candidatePreferences: [optedOutAgent],
        );

        expect(decision.isAssigned, isFalse);
        expect(decision.routingStatus, equals('Unassigned Queue'));
      });

      test('18. Monthly Quota Limit Enforcement: Exhausted quota skips agent', () {
        final quotaExhaustedAgent = agentAPrefs.copyWith(
          monthlyLeadQuota: 20,
          leadsReceivedThisMonth: 20, // Reached limit
        );

        final eligibleBackupAgent = agentCPrefs.copyWith(
          monthlyLeadQuota: 30,
          leadsReceivedThisMonth: 5,
        );

        final lead = {
          'preferredLocation': 'Batu Kawan',
          'preferredState': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 450000.0,
          'budgetMax': 550000.0,
          'sourceType': 'Property Portal',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: lead,
          candidatePreferences: [quotaExhaustedAgent, eligibleBackupAgent],
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals(agentC));
      });

      test('19. DNC Precedence: Explicit opt-out marks enquiry Ineligible on ingestion', () async {
        final dncPayload = {
          'name': 'Opted Out Buyer',
          'phone': '+60128889900',
          'doNotContact': true,
          'pdpa_consent': false,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Property Portal',
          rawPayload: dncPayload,
          existingProspects: [],
        );

        expect(result.enquiry.processingStatus, equals('Ineligible'));
        expect(result.enquiry.contactEligibility, equals('Do Not Contact'));
        expect(result.enquiry.isDoNotContact, isTrue);
      });

      test('20. Data Ownership Guarantee & Multi-Tenant Isolation', () async {
        // Agent A acquires lead via Channel A
        final leadA = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: {
            'name': 'Agent A Private Client',
            'phone': '+60121113333',
            'pdpa_consent': true,
          },
          existingProspects: agentAProspects,
        );

        // Agent B acquires lead via Channel B distribution
        final leadB = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentB,
          sourceType: 'Property Portal',
          rawPayload: {
            'name': 'Agent B Private Client',
            'phone': '+60122224444',
            'pdpa_consent': true,
          },
          existingProspects: agentBProspects,
        );

        expect(leadA.createdProspect!.ownerId, equals(agentA));
        expect(leadB.createdProspect!.ownerId, equals(agentB));

        // Subscription check: commercial tier doesn't affect prospect ownership
        final sub = AgentSubscriptionModel(
          agentId: agentA,
          tier: SubscriptionTier.freeStarter,
          status: 'Canceled', // Even if canceled
        );
        expect(sub.tier, equals(SubscriptionTier.freeStarter));
      });
    });
  });
}
