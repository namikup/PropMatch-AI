import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/enquiry_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/repositories/prospect_repository.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';
import 'package:propmatch_ai/services/matching_service.dart';
import 'package:propmatch_ai/services/demo_data_service.dart';

void main() {
  group('Phase 4.3.1: End-to-End Enquiry Simulation & Security Audit (Flutter)', () {
    const agentA = 'agent-uuid-audit-001';
    const agentB = 'agent-uuid-audit-002';

    late List<ProjectModel> projects;

    setUp(() {
      projects = [
        ProjectModel(
          id: 'proj-bk-01',
          ownerId: agentA,
          name: 'EXSIM Batu Kawan Hub',
          developer: 'EXSIM Development',
          location: 'Batu Kawan',
          state: 'Penang',
          propertyType: 'Condominium',
          startingPrice: 450000,
          maximumPrice: 580000,
          bedrooms: 3,
          bathrooms: 2,
          builtUpArea: 950,
          description: 'Modern transit-oriented condo near IKEA and Design Village.',
          purpose: 'Own Stay & Investment',
          status: 'New Launch',
        ),
        ProjectModel(
          id: 'proj-gurney-02',
          ownerId: agentA,
          name: 'Gurney Premier Suites',
          developer: 'Eastern & Oriental Berhad',
          location: 'Gurney Drive, George Town',
          state: 'Penang',
          propertyType: 'Serviced Residence',
          startingPrice: 880000,
          maximumPrice: 1450000,
          bedrooms: 2,
          bathrooms: 2,
          builtUpArea: 1100,
          description: 'Luxury beachfront serviced residence along Gurney promenade.',
          purpose: 'Investment',
          status: 'Under Construction',
        ),
        ProjectModel(
          id: 'proj-kulim-03',
          ownerId: agentA,
          name: 'Kulim Hi-Tech Green Residences',
          developer: 'BDB Land Sdn Bhd',
          location: 'Kulim Hi-Tech Park',
          state: 'Kedah',
          propertyType: 'Terrace House',
          startingPrice: 380000,
          maximumPrice: 460000,
          bedrooms: 4,
          bathrooms: 3,
          builtUpArea: 1800,
          description: 'Spacious double-storey terrace for industrial park professionals.',
          purpose: 'Own Stay',
          status: 'Ready to Move In',
        ),
      ];
    });

    // =========================================================================
    // SECTION 1: 10+ DIVERSE SYNTHETIC BUYER JOURNEYS ACROSS 5 SOURCES
    // =========================================================================
    group('1. Synthetic Buyer Journey Ingestion Simulation (10+ Scenarios)', () {
      test('Journey 1: Low-budget first homebuyer via Direct Website with PDPA consent', () async {
        final payload = {
          'name': 'Muhammad Hafiz bin Saiful',
          'phone': '012-3456789',
          'email': 'hafiz.saiful@gmail.com',
          'location': 'Batu Kawan',
          'state': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 400000,
          'budgetMax': 520000,
          'purpose': 'Own Stay',
          'timeline': '1-3 months',
          'pdpa_consent': true,
          'consentEvidence': 'Personal Website Form Checkbox (IP: 175.143.20.10)',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Qualified'));
        expect(result.enquiry.normalizedPhone, equals('+60123456789'));
        expect(result.enquiry.contactEligibility, equals('Eligible'));
        expect(result.createdProspect, isNotNull);
        expect(result.createdProspect!.ownerId, equals(agentA));
        expect(result.matchedProjectId, equals('proj-bk-01'));
        expect(result.matchScore, greaterThanOrEqualTo(85.0));
      });

      test('Journey 2: Automated spam bot with populated honeypot via Direct Website', () async {
        final payload = {
          'name': 'SEO Link Spammer Bot',
          'phone': '010-0000000',
          'email': 'bot@traffic-exchange.ru',
          'website_hp': 'http://automated-spam-link.biz', // HONEYPOT FILLED
          'pdpa_consent': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isFalse);
        expect(result.status, equals('Rejected'));
        expect(result.currentStage, equals('Source Validation'));
        expect(result.createdProspect, isNull); // ZERO prospect record created!
      });

      test('Journey 3: Luxury investor via Partner Agency (MIEA Co-Broke Network)', () async {
        final payload = {
          'agency_name': 'Reapfield Properties KL',
          'referring_ren': 'REN 09812 (Steven Yap)',
          'client_name': 'Dato Sri William Chen',
          'client_phone': '+6012-8877665',
          'client_email': 'william.chen@conglomerate.com.my',
          'location': 'Gurney Drive, George Town',
          'state': 'Penang',
          'propertyType': 'Serviced Residence',
          'budgetMin': 900000,
          'budgetMax': 1600000,
          'purpose': 'Investment',
          'timeline': 'Exploring',
          'co_broke_agreement_ref': 'MIEA-PEN-2026-88',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Partner Agency',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Qualified'));
        expect(result.enquiry.normalizedPhone, equals('+60128877665'));
        expect(result.enquiry.contactEligibility, equals('Eligible'));
        expect(result.matchedProjectId, equals('proj-gurney-02'));
        expect(result.matchScore, greaterThanOrEqualTo(90.0));
      });

      test('Journey 4: Partner Agency referral with explicit Do Not Contact / Opt-out flag', () async {
        final payload = {
          'agency_name': 'Hartamas Real Estate',
          'referring_ren': 'REN 19482',
          'client_name': 'Kavitha Raman',
          'client_phone': '011-2345678',
          'client_email': 'kavitha@yahoo.com',
          'location': 'George Town',
          'state': 'Penang',
          'doNotContact': true, // EXPLICIT DNC OPT-OUT
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Partner Agency',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Ineligible'));
        expect(result.enquiry.contactEligibility, equals('Do Not Contact'));
        expect(result.enquiry.consentStatus, equals('Consent Withdrawn'));
        expect(result.createdProspect?.contactEligibility, equals('Do Not Contact'));
      });

      test('Journey 5: Mid-budget family condo inquiry via iProperty Malaysia portal', () async {
        final payload = {
          'portal': 'iProperty Malaysia',
          'enquiry_id': 'IP-MY-2026-10294',
          'full_name': 'Dr. Farah Hanim binti Razali',
          'phone': '012-4883391',
          'email': 'dr.farah.razali@hospital.gov.my',
          'preferred_location': 'Batu Kawan',
          'preferred_state': 'Penang',
          'property_type': 'Condominium',
          'budget_min': 450000,
          'budget_max': 600000,
          'purpose': 'Own Stay',
          'timeline': 'Immediately',
          'listing_id': 'prop-bk-882',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Property Portal',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Qualified'));
        expect(result.enquiry.sourceReferenceId, equals('IP-MY-2026-10294'));
        expect(result.enquiry.normalizedPhone, equals('+60124883391'));
        expect(result.matchedProjectId, equals('proj-bk-01'));
      });

      test('Journey 6: Duplicate enquiry arriving via PropertyGuru matching existing prospect', () async {
        final existingProspects = [
          ProspectModel(
            id: 'prospect-farah-01',
            ownerId: agentA,
            fullName: 'Dr. Farah Hanim binti Razali',
            phone: '+60124883391',
            email: 'dr.farah.razali@hospital.gov.my',
            preferredState: 'Penang',
            budgetMin: 450000,
            budgetMax: 600000,
            primarySource: 'Property Portal',
            primarySourceId: 'IP-MY-2026-10294',
          ),
        ];

        // Inquiry arrives on PropertyGuru 2 days later with same phone number
        final duplicatePayload = {
          'portal': 'PropertyGuru Malaysia',
          'enquiry_id': 'PG-MY-2026-99120',
          'full_name': 'Dr. Farah Hanim',
          'phone': '012-488 3391', // Whitespace formatting
          'email': 'dr.farah.razali@hospital.gov.my',
          'preferred_location': 'Batu Kawan',
          'budget_min': 450000,
          'budget_max': 600000,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Property Portal',
          rawPayload: duplicatePayload,
          existingProspects: existingProspects,
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.isDuplicate, isTrue);
        expect(result.status, equals('Duplicate'));
        expect(result.createdProspect, isNull); // PROSPECT ROW SUPPRESSED!
        expect(result.enquiry.duplicateTargetId, equals('prospect-farah-01'));
        expect(result.sourceRecord, isNotNull);
        expect(result.sourceRecord!.prospectId, equals('prospect-farah-01'));
      });

      test('Journey 7: Incomplete enquiry missing both phone and email is safely rejected', () async {
        final payload = {
          'name': 'Anonymous Inquirer',
          'location': 'George Town',
          'budgetMin': 500000,
          'budgetMax': 800000,
          // Missing phone AND missing email
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: [],
        );

        expect(result.success, isFalse);
        expect(result.status, equals('Rejected'));
        expect(result.currentStage, equals('Data Normalisation'));
        expect(result.errorMessage, contains('contact identifier'));
      });

      test('Journey 8: Developer showroom walk-in with signed physical registration slip', () async {
        final payload = {
          'developer_name': 'BDB Land Sdn Bhd',
          'project_name': 'Kulim Hi-Tech Green Residences',
          'slip_serial_no': 'BDB-KULIM-SLIP-401',
          'visitor_name': 'Subramaniam a/l Murugan',
          'visitor_phone': '017-5023819',
          'visitor_email': 'subra.murugan@engg.my',
          'interest_location': 'Kulim Hi-Tech Park',
          'state': 'Kedah',
          'interest_type': 'Terrace House',
          'budget_max': 450000,
          'purpose': 'Own Stay',
          'timeline': 'Immediately',
          'signed_pdpa': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Developer',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Qualified'));
        expect(result.enquiry.normalizedPhone, equals('+60175023819'));
        expect(result.enquiry.contactEligibility, equals('Eligible'));
        expect(result.matchedProjectId, equals('proj-kulim-03'));
        expect(result.matchScore, greaterThanOrEqualTo(90.0));
      });

      test('Journey 9: High-net-worth VIP gallery investor via EcoWorld tablet registration', () async {
        final payload = {
          'developer_name': 'EcoWorld Gallery Penang',
          'project_name': 'Eco Horizon Gallery',
          'slip_serial_no': 'ECO-VIP-2026-90',
          'visitor_name': 'Tan Sri Richard Lee',
          'visitor_phone': '+6019-2837465',
          'visitor_email': 'richard.lee@holdinggroup.com.my',
          'interest_location': 'Gurney Drive, George Town',
          'state': 'Penang',
          'interest_type': 'Serviced Residence',
          'budget_max': 1800000,
          'purpose': 'Investment',
          'timeline': '1-3 months',
          'signed_pdpa': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'Developer',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.processingStatus, equals('Qualified'));
        expect(result.matchedProjectId, equals('proj-gurney-02'));
        expect(result.matchScore, greaterThanOrEqualTo(85.0));
      });

      test('Journey 10: Historical agency CRM import defaults safely to Pending Consent', () async {
        final payload = {
          'fullName': 'Ahmad Zaki bin Othman',
          'phone': '018-3344556',
          'email': 'ahmad.zaki.othman@gmail.com',
          'location': 'Kulim Hi-Tech Park',
          'state': 'Kedah',
          'propertyType': 'Terrace House',
          'budgetMin': 350000,
          'budgetMax': 440000,
          // No explicit direct marketing consent in historical record
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentA,
          sourceType: 'CRM Import',
          rawPayload: payload,
          existingProspects: [],
          availableProjects: projects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.contactEligibility, equals('Pending Consent')); // NEVER automatically Eligible
        expect(result.createdProspect?.contactEligibility, equals('Pending Consent'));
      });

      test('Journey 11: Inquirer with unspecified budget calculates safe partial budget score', () async {
        final buyer = BuyerModel(
          id: 'buyer-no-budget',
          ownerId: agentA,
          name: 'Lim Siew Ling',
          phone: '+60124445555',
          email: 'siewling@gmail.com',
          budgetMin: 0,
          budgetMax: 0, // UNSPECIFIED BUDGET
          preferredLocation: 'Batu Kawan',
          preferredState: 'Penang',
          propertyType: 'Condominium',
          purchasePurpose: 'Own Stay',
          buyingTimeline: '1-3 months',
          leadSource: 'Direct Website',
          createdAt: DateTime.now(),
        );

        final match = MatchingService.calculateMatch(
          buyer: buyer,
          project: projects.first,
        );

        // Budget dimension weight: 25%. Partial fallback score for unknown budget = 10.0
        expect(match.budgetScore, equals(10.0));
        expect(match.missingInformation, anyElement(contains('budget range')));
      });

      test('Journey 12: Inquirer with unspecified location calculates safe partial location score', () async {
        final buyer = BuyerModel(
          id: 'buyer-no-loc',
          ownerId: agentA,
          name: 'Tan Mei Ling',
          phone: '+60127778888',
          email: 'meiling@gmail.com',
          budgetMin: 450000,
          budgetMax: 550000,
          preferredLocation: '', // UNSPECIFIED
          preferredState: '', // UNSPECIFIED
          propertyType: 'Condominium',
          purchasePurpose: 'Own Stay',
          buyingTimeline: '1-3 months',
          leadSource: 'Direct Website',
          createdAt: DateTime.now(),
        );

        final match = MatchingService.calculateMatch(
          buyer: buyer,
          project: projects.first,
        );

        // Location dimension weight: 25%. Partial fallback score for unknown location = 8.0
        expect(match.locationScore, equals(8.0));
        expect(match.missingInformation, anyElement(contains('location preferences')));
      });
    });

    // =========================================================================
    // SECTION 2: DETERMINISTIC MATCHING WEIGHTS & IMMUTABILITY AUDIT
    // =========================================================================
    group('2. Deterministic AI Buyer Matching (25/25/20/15/15 Weights)', () {
      test('verifies mathematical precision across all 5 dimensions', () {
        final buyer = BuyerModel(
          id: 'buyer-perfect-match',
          ownerId: agentA,
          name: 'Perfect Match Candidate',
          phone: '+60121112222',
          email: 'perfect@propmatch.ai',
          budgetMin: 450000,
          budgetMax: 580000,
          preferredLocation: 'Batu Kawan',
          preferredState: 'Penang',
          propertyType: 'Condominium',
          purchasePurpose: 'Own Stay & Investment',
          buyingTimeline: 'Immediately',
          leadSource: 'Direct Website',
          createdAt: DateTime.now(),
        );

        final completedProject = ProjectModel(
          id: 'proj-bk-completed',
          ownerId: agentA,
          name: 'EXSIM Batu Kawan Hub (Completed Phase)',
          developer: 'EXSIM Development',
          location: 'Batu Kawan',
          state: 'Penang',
          propertyType: 'Condominium',
          startingPrice: 450000,
          maximumPrice: 580000,
          bedrooms: 3,
          bathrooms: 2,
          builtUpArea: 950,
          description: 'Completed transit-oriented condo.',
          purpose: 'Own Stay & Investment',
          status: 'Completed',
        );

        final match = MatchingService.calculateMatch(
          buyer: buyer,
          project: completedProject,
        );

        // Check each weight
        expect(match.budgetScore, equals(25.0)); // 25% max
        expect(match.locationScore, equals(25.0)); // 25% max
        expect(match.propertyTypeScore, equals(20.0)); // 20% max
        expect(match.purposeScore, equals(15.0)); // 15% max
        expect(match.timelineScore, equals(15.0)); // 15% max

        // Total = 100%
        expect(match.overallMatchPercentage, equals(100.0));
      });
    });

    // =========================================================================
    // SECTION 3: SECURITY, MULTI-TENANT ISOLATION & PDPA COMPLIANCE
    // =========================================================================
    group('3. Security, Multi-Tenant Isolation & IDOR Protection', () {
      test('Agent A cannot access or match Agent B prospects', () async {
        final repo = InMemoryProspectRepository();

        final enqA = EnquiryModel(
          id: 'enq-agent-a',
          ownerId: agentA,
          sourceType: 'Property Portal',
          sourceName: 'iProperty Malaysia',
          fullName: 'Client Agent A',
        );

        final enqB = EnquiryModel(
          id: 'enq-agent-b',
          ownerId: agentB,
          sourceType: 'Property Portal',
          sourceName: 'iProperty Malaysia',
          fullName: 'Client Agent B',
        );

        await repo.saveIncomingEnquiry(enqA);
        await repo.saveIncomingEnquiry(enqB);

        // Querying as Agent A yields ONLY Agent A records
        final agentAResults = await repo.getIncomingEnquiries(ownerId: agentA);
        expect(agentAResults.length, equals(1));
        expect(agentAResults.first.ownerId, equals(agentA));
        expect(agentAResults.first.id, equals('enq-a-never' != 'enq-agent-a' ? 'enq-agent-a' : ''));

        // Direct lookup with ownerId scoping protects from IDOR
        final bLookedUpByA = await repo.getEnquiryById('enq-agent-b', ownerId: agentA);
        expect(bLookedUpByA, isNull);
      });

      test('Agent A cannot overwrite an enquiry owned by Agent B (IDOR mutation defense)', () async {
        final repo = InMemoryProspectRepository();

        // Agent B's original inquiry
        final enqB = EnquiryModel(
          id: 'enquiry-locked-001',
          ownerId: agentB,
          sourceType: 'Developer',
          sourceName: 'EcoWorld',
          fullName: 'Original Buyer of Agent B',
        );
        await repo.saveIncomingEnquiry(enqB);

        // Agent A attempts to overwrite with own ownerId or mutate Agent B's record
        final maliciousEnq = EnquiryModel(
          id: 'enquiry-locked-001',
          ownerId: agentA, // Spoofed agent owner
          sourceType: 'Developer',
          sourceName: 'EcoWorld',
          fullName: 'Hijacked by Agent A',
        );

        expect(
          () async => await repo.saveIncomingEnquiry(maliciousEnq),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Tenant violation'))),
        );
      });
    });

    // =========================================================================
    // SECTION 4: DASHBOARD METRICS, FILTERING & AUDIT TRAILS
    // =========================================================================
    group('4. Dashboard State & Enquiry Filtering Verification', () {
      test('DemoDataService seeds accurately across 5 channels with duplicate & DNC indicators', () {
        final demoList = DemoDataService.getInitialDemoEnquiries(agentA);
        expect(demoList.length, greaterThanOrEqualTo(10));

        final sources = demoList.map((e) => e.sourceType).toSet();
        expect(sources, containsAll([
          'Property Portal',
          'Partner Agency',
          'Developer',
          'Direct Website',
          'CRM Import',
        ]));

        final qualified = demoList.where((e) => e.processingStatus == 'Qualified').length;
        final duplicate = demoList.where((e) => e.isDuplicate).length;
        final ineligible = demoList.where((e) => e.contactEligibility == 'Do Not Contact').length;

        expect(qualified, greaterThan(0));
        expect(duplicate, equals(1));
        expect(ineligible, equals(1));
      });
    });
  });
}
