import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/enquiry_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/repositories/prospect_repository.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';
import 'package:propmatch_ai/services/prospect_sources/source_registry.dart';
import 'package:propmatch_ai/services/demo_data_service.dart';

void main() {
  group('Phase 4.3 Lead Ingestion Pipeline Tests', () {
    const agentA = 'agent-uuid-001';
    const agentB = 'agent-uuid-002';

    late List<ProjectModel> projects;

    setUp(() {
      projects = [
        ProjectModel(
          id: 'proj-penang-01',
          ownerId: agentA,
          name: 'EXSIM Batu Kawan Hub',
          developer: 'EXSIM Development',
          location: 'Batu Kawan',
          state: 'Penang',
          propertyType: 'Condominium',
          startingPrice: 450000,
          maximumPrice: 600000,
          bedrooms: 3,
          bathrooms: 2,
          builtUpArea: 950,
          purpose: 'Own Stay',
          status: 'New Launch',
          description: 'Modern transit-oriented development.',
        ),
      ];
    });

    // -------------------------------------------------------------------------
    // TEST 1: Source Adapters Registration & Parsing
    // -------------------------------------------------------------------------
    test('1. PropertyPortalAdapter parses valid iProperty/PropertyGuru payload', () {
      final adapter = ProspectSourceRegistry.getAdapter('Property Portal');
      expect(adapter, isNotNull);

      final payload = {
        'portal': 'iProperty Malaysia',
        'enquiry_id': 'IP-2026-999',
        'full_name': 'Norazlan bin Ibrahim',
        'phone': '019-2233445',
        'email': 'norazlan@gmail.com',
        'preferred_location': 'Batu Kawan',
        'preferred_state': 'Penang',
        'property_type': 'Condominium',
        'budget_min': 400000,
        'budget_max': 550000,
        'consent_declaration': 'Checked PDPA Consent on iProperty Form',
      };

      expect(adapter!.validateProspectData(payload), isTrue);
      final enquiry = adapter.parseEnquiry(ownerId: agentA, rawPayload: payload);
      expect(enquiry.fullName, equals('Norazlan bin Ibrahim'));
      expect(enquiry.sourceReferenceId, equals('IP-2026-999'));
      expect(enquiry.sourceName, equals('iProperty Malaysia'));
      expect(enquiry.contactEligibility, equals('Eligible'));
    });

    test('2. PartnerAgencyAdapter parses MIEA co-broke referral payload', () {
      final adapter = ProspectSourceRegistry.getAdapter('Partner Agency');
      expect(adapter, isNotNull);

      final payload = {
        'agency_name': 'Reapfield Properties',
        'referring_ren_no': 'REN 12345',
        'client_name': 'Jessica Wong',
        'client_phone': '+60123344556',
        'client_email': 'jessica@corporate.my',
        'location': 'George Town',
        'state': 'Penang',
        'property_type': 'Condominium',
        'budget_min': 700000,
        'budget_max': 1000000,
        'co_broke_agreement_ref': 'CB-REF-2026-01',
      };

      expect(adapter!.validateProspectData(payload), isTrue);
      final enquiry = adapter.parseEnquiry(ownerId: agentA, rawPayload: payload);
      expect(enquiry.fullName, equals('Jessica Wong'));
      expect(enquiry.sourceName, contains('Reapfield Properties'));
      expect(enquiry.contactEligibility, equals('Eligible'));
    });

    test('3. DeveloperAdapter parses sales gallery digital registration slip', () {
      final adapter = ProspectSourceRegistry.getAdapter('Developer');
      expect(adapter, isNotNull);

      final payload = {
        'developer_name': 'EcoWorld Gallery',
        'slip_serial_no': 'SLIP-9012',
        'visitor_name': 'Tan Sri Vincent Tan',
        'visitor_phone': '012-4455667',
        'visitor_email': 'vincent@holding.com',
        'interest_location': 'Batu Kawan',
        'interest_type': 'Condominium',
        'budget_min': 500000,
        'budget_max': 800000,
        'signed_pdpa': true,
      };

      expect(adapter!.validateProspectData(payload), isTrue);
      final enquiry = adapter.parseEnquiry(ownerId: agentA, rawPayload: payload);
      expect(enquiry.fullName, equals('Tan Sri Vincent Tan'));
      expect(enquiry.sourceName, contains('EcoWorld Gallery'));
      expect(enquiry.contactEligibility, equals('Eligible'));
    });

    test('4. DirectWebsiteAdapter catches spam bot via honeypot trap', () {
      final adapter = ProspectSourceRegistry.getAdapter('Direct Website');
      expect(adapter, isNotNull);

      // Bot fills honeypot
      final botPayload = {
        'name': 'Spam Bot Lead',
        'phone': '0101234567',
        'email': 'bot@seo-leads.com',
        'website_hp': 'http://automated-spam-url.com', // Honeypot populated!
      };

      expect(adapter!.validateProspectData(botPayload), isFalse);

      // Clean user submission
      final cleanPayload = {
        'name': 'Datin Halimah',
        'phone': '012-9988776',
        'email': 'halimah@penang.gov.my',
        'location': 'Batu Kawan',
        'pdpa_consent': true,
      };
      expect(adapter.validateProspectData(cleanPayload), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Malaysian Phone Normalization
    // -------------------------------------------------------------------------
    test('5. Malaysian phone numbers are normalized to E.164 (+601X...)', () {
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('012-3456789'), equals('+60123456789'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('016 411 9928'), equals('+60164119928'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('60175023819'), equals('+60175023819'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone('+6019-2837465'), equals('+60192837465'));
      expect(LeadIngestionPipeline.normalizeMalaysianPhone(''), equals(''));
    });

    // -------------------------------------------------------------------------
    // TEST 3: Duplicate Detection across Agent Prospects
    // -------------------------------------------------------------------------
    test('6. Detects duplicate against agent existing prospects and prevents duplicate creation', () async {
      final List<ProspectModel> existingProspects = [
        ProspectModel(
          id: 'prospect-001',
          ownerId: agentA,
          fullName: 'Dr. Farah Razali',
          phone: '+60124883391',
          email: 'farah@hospital.my',
          preferredState: 'Penang',
          budgetMin: 450000,
          budgetMax: 600000,
          primarySource: 'Property Portal',
        ),
      ];

      final incomingPayload = {
        'name': 'Dr. Farah Razali',
        'phone': '012-4883391', // Same number, unnormalized format
        'email': 'farah@hospital.my',
        'location': 'Batu Kawan',
        'budgetMin': 450000,
        'budgetMax': 600000,
        'consentEvidence': 'Portal inquiry',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: agentA,
        sourceType: 'Property Portal',
        rawPayload: incomingPayload,
        existingProspects: existingProspects,
      );

      expect(result.success, isTrue);
      expect(result.isDuplicate, isTrue);
      expect(result.status, equals('Duplicate'));
      expect(result.createdProspect, isNull); // ZERO duplicate prospect created!
      expect(result.enquiry.duplicateTargetId, equals('prospect-001'));
      expect(result.sourceRecord, isNotNull);
      expect(result.sourceRecord!.prospectId, equals('prospect-001'));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Duplicate Detection across CRM Buyers
    // -------------------------------------------------------------------------
    test('7. Detects duplicate against existing CRM Buyers', () async {
      final existingBuyers = [
        BuyerModel(
          id: 'buyer-001',
          ownerId: agentA,
          name: 'Chong Wei Kiat',
          phone: '+60164119928',
          email: 'wkchong@techcorp.my',
          budgetMin: 800000,
          budgetMax: 1200000,
          preferredLocation: 'Gurney Drive',
          preferredState: 'Penang',
          propertyType: 'Serviced Residence',
          purchasePurpose: 'Investment',
          buyingTimeline: 'Immediately',
          leadSource: 'Historical Walk-in',
          createdAt: DateTime.now(),
        ),
      ];

      final incomingPayload = {
        'name': 'Chong Wei Kiat',
        'phone': '016-4119928',
        'email': 'wkchong@techcorp.my',
        'location': 'Gurney Drive',
        'consentEvidence': 'Showroom registration',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: agentA,
        sourceType: 'Developer',
        rawPayload: incomingPayload,
        existingProspects: [],
        existingBuyers: existingBuyers,
      );

      expect(result.success, isTrue);
      expect(result.isDuplicate, isTrue);
      expect(result.createdProspect, isNull);
      expect(result.enquiry.duplicateTargetId, equals('buyer-001'));
    });

    // -------------------------------------------------------------------------
    // TEST 5: Multi-Tenant Agent Ownership Isolation
    // -------------------------------------------------------------------------
    test('8. Multi-tenant isolation: Agent A records are never matched to Agent B', () async {
      // Prospect belongs to Agent B
      final List<ProspectModel> agentBProspects = [
        ProspectModel(
          id: 'prospect-agent-b',
          ownerId: agentB,
          fullName: 'Subramaniam Murugan',
          phone: '+60175023819',
          email: 'subra@engg.my',
          preferredState: 'Kedah',
          budgetMin: 380000,
          budgetMax: 480000,
          primarySource: 'Partner Agency',
        ),
      ];

      // Agent A receives inquiry with identical phone
      final incomingPayload = {
        'name': 'Subramaniam Murugan',
        'phone': '017-5023819',
        'email': 'subra@engg.my',
        'location': 'Kulim Hi-Tech Park',
        'consentEvidence': 'Direct Webform',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: agentA,
        sourceType: 'Direct Website',
        rawPayload: incomingPayload,
        existingProspects: agentBProspects, // Passed in mixed list
      );

      // Must NOT match Agent B's record!
      expect(result.isDuplicate, isFalse);
      expect(result.createdProspect, isNotNull);
      expect(result.createdProspect!.ownerId, equals(agentA));
      expect(result.createdProspect!.id, isNot(equals('prospect-agent-b')));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Consent & Do Not Contact Precedence
    // -------------------------------------------------------------------------
    test('9. Do Not Contact (opt-out) overrides all and marks inquiry Ineligible', () async {
      final optOutPayload = {
        'name': 'Kavitha Devi',
        'phone': '011-2345678',
        'email': 'kavitha@yahoo.com',
        'location': 'George Town',
        'doNotContact': true, // Formally requested opt-out
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: agentA,
        sourceType: 'Partner Agency',
        rawPayload: optOutPayload,
        existingProspects: [],
      );

      expect(result.success, isTrue);
      expect(result.enquiry.contactEligibility, equals('Do Not Contact'));
      expect(result.enquiry.processingStatus, equals('Ineligible'));
      expect(result.enquiry.consentStatus, equals('Consent Withdrawn'));
      expect(result.createdProspect?.contactEligibility, equals('Do Not Contact'));
    });

    // -------------------------------------------------------------------------
    // TEST 7: Deterministic AI Buyer Matching (25/25/20/15/15)
    // -------------------------------------------------------------------------
    test('10. Calculates deterministic compatibility score and recommends project', () async {
      final highMatchPayload = {
        'name': 'Ahmad Albab',
        'phone': '012-5556677',
        'email': 'ahmad@gmail.com',
        'location': 'Batu Kawan',
        'propertyType': 'Condominium',
        'budgetMin': 450000,
        'budgetMax': 600000,
        'purchasePurpose': 'Own Stay',
        'buyingTimeline': '1-3 months',
        'consentEvidence': 'Portal inquiry verified',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: agentA,
        sourceType: 'Property Portal',
        rawPayload: highMatchPayload,
        existingProspects: [],
        availableProjects: projects,
      );

      expect(result.success, isTrue);
      expect(result.matchedProjectId, equals('proj-penang-01'));
      expect(result.matchScore, isNotNull);
      expect(result.matchScore!, greaterThanOrEqualTo(80.0));
      expect(result.enquiry.aiMatchExplanation, contains('High compatibility'));
      expect(result.enquiry.suggestedNextAction, isNotNull);
    });

    // -------------------------------------------------------------------------
    // TEST 8: InMemoryProspectRepository Ingestion Persistence
    // -------------------------------------------------------------------------
    test('11. InMemoryProspectRepository saves and retrieves incoming enquiries with owner isolation', () async {
      final repo = InMemoryProspectRepository();

      final enqA = EnquiryModel(
        id: 'enq-a',
        ownerId: agentA,
        sourceType: 'Property Portal',
        sourceName: 'iProperty Malaysia',
        fullName: 'Client A',
        processingStatus: 'Qualified',
      );

      final enqB = EnquiryModel(
        id: 'enq-b',
        ownerId: agentB,
        sourceType: 'Developer',
        sourceName: 'EcoWorld',
        fullName: 'Client B',
        processingStatus: 'Qualified',
      );

      await repo.saveIncomingEnquiry(enqA);
      await repo.saveIncomingEnquiry(enqB);

      final agentAEnquiries = await repo.getIncomingEnquiries(ownerId: agentA);
      expect(agentAEnquiries.length, equals(1));
      expect(agentAEnquiries.first.id, equals('enq-a'));

      final agentBEnquiries = await repo.getIncomingEnquiries(ownerId: agentB);
      expect(agentBEnquiries.length, equals(1));
      expect(agentBEnquiries.first.id, equals('enq-b'));
    });

    // -------------------------------------------------------------------------
    // TEST 9: Demo Data Service Seed Verification
    // -------------------------------------------------------------------------
    test('12. DemoDataService seeds 10 realistic multi-channel enquiries', () {
      final demoList = DemoDataService.getInitialDemoEnquiries('demo-agent-001');
      expect(demoList.length, equals(10));

      final sources = demoList.map((e) => e.sourceType).toSet();
      expect(sources, containsAll([
        'Property Portal',
        'Partner Agency',
        'Developer',
        'Direct Website',
        'CRM Import',
      ]));

      final hasDuplicate = demoList.any((e) => e.isDuplicate);
      expect(hasDuplicate, isTrue);

      final hasDnc = demoList.any((e) => e.contactEligibility == 'Do Not Contact');
      expect(hasDnc, isTrue);
    });
  });
}
