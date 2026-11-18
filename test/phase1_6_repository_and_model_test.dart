import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/campaign_model.dart';
import 'package:propmatch_ai/models/user_model.dart';
import 'package:propmatch_ai/models/consent_record_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/lead_model.dart';
import 'package:propmatch_ai/models/followup_model.dart';
import 'package:propmatch_ai/repositories/buyer_repository.dart';
import 'package:propmatch_ai/repositories/project_repository.dart';
import 'package:propmatch_ai/repositories/lead_repository.dart';
import 'package:propmatch_ai/repositories/followup_repository.dart';
import 'package:propmatch_ai/repositories/campaign_repository.dart';
import 'package:propmatch_ai/repositories/consent_repository.dart';
import 'package:propmatch_ai/repositories/auth_repository.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';

void main() {
  group('Phase 1.6 Data Models & Serialization', () {
    test('BuyerModel includes updatedAt with backwards-compatible deserialization', () {
      final now = DateTime.now();
      final buyer = BuyerModel(
        ownerId: 'agent-001',
        name: 'Tan Mei Ling',
        email: 'meiling@example.com',
        phone: '+6012-3456789',
        budgetMin: 500000,
        budgetMax: 700000,
        preferredLocation: 'Batu Kawan',
        preferredState: 'Penang',
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        leadSource: 'Agent Direct Registration',
        createdAt: now,
        updatedAt: now,
      );

      expect(buyer.updatedAt, equals(now));
      expect(buyer.email, equals('meiling@example.com'));

      final map = buyer.toMap();
      expect(map['updatedAt'], equals(now.toIso8601String()));
      expect(map['email'], equals('meiling@example.com'));

      // Test deserialization with updatedAt present
      final fromMap = BuyerModel.fromMap(map);
      expect(fromMap.updatedAt.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));

      // Test backwards-compatible deserialization when updatedAt is missing
      final legacyMap = Map<String, dynamic>.from(map)..remove('updatedAt');
      final fromLegacy = BuyerModel.fromMap(legacyMap);
      expect(fromLegacy.updatedAt, isNotNull);
      expect(fromLegacy.createdAt.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('CampaignModel includes updatedAt, copyWith, and serialization', () {
      final now = DateTime.now();
      final campaign = CampaignModel(
        ownerId: 'agent-001',
        name: 'Eco Horizon Q4 Launch',
        projectId: 'proj-001',
        projectName: 'Eco Horizon',
        platform: 'Facebook',
        contentHeadline: 'Exclusive Township Living',
        contentBody: 'Gated & guarded landed homes in Batu Kawan.',
        callToAction: 'Register for Showroom Viewing',
        createdAt: now,
        updatedAt: now,
      );

      expect(campaign.updatedAt, equals(now));
      final copied = campaign.copyWith(status: 'Active', reach: 500);
      expect(copied.status, equals('Active'));
      expect(copied.reach, equals(500));
      expect(copied.name, equals('Eco Horizon Q4 Launch'));

      final map = campaign.toMap();
      expect(map['updatedAt'], equals(now.toIso8601String()));

      // Backwards-compatible deserialization without updatedAt
      final legacyMap = Map<String, dynamic>.from(map)..remove('updatedAt');
      final fromLegacy = CampaignModel.fromMap(legacyMap);
      expect(fromLegacy.updatedAt, isNotNull);
    });

    test('UserModel has required REN fields and serializes correctly', () {
      final user = UserModel(
        id: 'usr-ren-101',
        ownerId: 'agent-001',
        fullName: 'Ahmad Faiz bin Razak',
        email: 'ahmad.faiz@propmatch.ai',
        phone: '+6019-8765432',
        agencyName: 'IQI Realty Penang',
        renNumber: 'REN 45892',
        region: 'Penang & Kedah',
      );

      expect(user.renNumber, equals('REN 45892'));
      expect(user.agencyName, equals('IQI Realty Penang'));
      expect(user.ownerId, equals('agent-001'));

      final map = user.toMap();
      expect(map['renNumber'], equals('REN 45892'));
      expect(map['agencyName'], equals('IQI Realty Penang'));

      final fromMap = UserModel.fromMap(map);
      expect(fromMap.fullName, equals('Ahmad Faiz bin Razak'));
      expect(fromMap.renNumber, equals('REN 45892'));
    });

    test('ConsentRecordModel captures consent type, status, and timestamp', () {
      final consent = ConsentRecordModel(
        ownerId: 'agent-001',
        buyerId: 'buyer-001',
        consentType: 'marketing_communication',
        consentStatus: 'granted',
        consentSource: 'Agent Direct Registration',
      );

      expect(consent.consentType, equals('marketing_communication'));
      expect(consent.consentStatus, equals('granted'));
      expect(consent.withdrawalTimestamp, isNull);

      final withdrawn = consent.copyWith(
        consentStatus: 'withdrawn',
        withdrawalTimestamp: DateTime.now(),
      );
      expect(withdrawn.consentStatus, equals('withdrawn'));
      expect(withdrawn.withdrawalTimestamp, isNotNull);

      final map = withdrawn.toMap();
      final fromMap = ConsentRecordModel.fromMap(map);
      expect(fromMap.consentStatus, equals('withdrawn'));
      expect(fromMap.withdrawalTimestamp, isNotNull);
    });
  });

  group('Phase 1.6 Repositories & AppStateProvider Integration', () {
    test('AppStateProvider injects repositories and routes CRUD operations', () async {
      final projectRepo = InMemoryProjectRepository();
      final buyerRepo = InMemoryBuyerRepository();
      final leadRepo = InMemoryLeadRepository();
      final followupRepo = InMemoryFollowupRepository();
      final campaignRepo = InMemoryCampaignRepository();
      final consentRepo = InMemoryConsentRepository();
      final authRepo = InMemoryAuthRepository();

      final provider = AppStateProvider(
        projectRepository: projectRepo,
        buyerRepository: buyerRepo,
        leadRepository: leadRepo,
        followupRepository: followupRepo,
        campaignRepository: campaignRepo,
        consentRepository: consentRepo,
        authRepository: authRepo,
      );

      // Verify repositories are injected
      expect(provider.projectRepository, equals(projectRepo));
      expect(provider.buyerRepository, equals(buyerRepo));
      expect(provider.leadRepository, equals(leadRepo));
      expect(provider.followupRepository, equals(followupRepo));
      expect(provider.consentRepository, equals(consentRepo));

      // Test Project CRUD delegation
      final project = ProjectModel(
        id: 'test-p1',
        ownerId: provider.currentOwnerId,
        name: 'Utropolis Sensasi',
        developer: 'Paramount Property',
        location: 'Batu Kawan',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 380000,
        maximumPrice: 550000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 800,
        description: 'Prime Batu Kawan condo',
        purpose: 'Own Stay',
      );
      provider.addProject(project);

      final projectsInRepo = await projectRepo.getProjects(ownerId: provider.currentOwnerId);
      expect(projectsInRepo.any((p) => p.id == 'test-p1'), isTrue);
      expect(provider.projects.any((p) => p.id == 'test-p1'), isTrue);

      // Test Buyer CRUD delegation
      final buyer = BuyerModel(
        id: 'test-b1',
        ownerId: provider.currentOwnerId,
        name: 'Kavitha Devi',
        email: 'kavitha@example.com',
        phone: '+6016-1234567',
        budgetMin: 400000,
        budgetMax: 600000,
        preferredLocation: 'Batu Kawan',
        preferredState: 'Penang',
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        leadSource: 'Agent Direct Registration',
      );
      provider.addBuyer(buyer);

      final buyersInRepo = await buyerRepo.getBuyers(ownerId: provider.currentOwnerId);
      expect(buyersInRepo.any((b) => b.id == 'test-b1'), isTrue);
      expect(provider.buyers.any((b) => b.id == 'test-b1'), isTrue);

      // Test Lead CRUD delegation
      final lead = LeadModel(
        id: 'test-l1',
        ownerId: provider.currentOwnerId,
        buyerId: 'test-b1',
        projectId: 'test-p1',
        buyerName: 'Kavitha Devi',
        projectName: 'Utropolis Sensasi',
        status: 'New',
        source: 'Direct Registration',
      );
      provider.addLead(lead);

      final leadsInRepo = await leadRepo.getLeads(ownerId: provider.currentOwnerId);
      expect(leadsInRepo.any((l) => l.id == 'test-l1'), isTrue);

      provider.updateLeadStatus('test-l1', 'Qualified');
      final updatedLead = await leadRepo.getLeadById('test-l1');
      expect(updatedLead?.status, equals('Qualified'));

      // Test Follow-up CRUD delegation
      final followup = FollowupModel(
        id: 'test-f1',
        ownerId: provider.currentOwnerId,
        buyerName: 'Kavitha Devi',
        buyerId: 'test-b1',
        projectName: 'Utropolis Sensasi',
        projectId: 'test-p1',
        task: 'Arrange site visit at Utropolis',
        dueDate: 'Friday 3:00 PM',
        type: 'Showroom Viewing',
      );
      provider.addFollowup(followup);

      final followupsInRepo = await followupRepo.getFollowups(ownerId: provider.currentOwnerId);
      expect(followupsInRepo.any((f) => f.id == 'test-f1'), isTrue);

      // Toggle follow-up
      provider.toggleFollowupCompletion('test-f1');
      final toggled = await followupRepo.getFollowupById('test-f1');
      expect(toggled?.isCompleted, isTrue);
      expect(provider.followups.firstWhere((f) => f.id == 'test-f1').isCompleted, isTrue);

      // Update follow-up
      final updatedFollowup = followup.copyWith(task: 'Revised site visit time to 4:00 PM');
      provider.updateFollowup(updatedFollowup);
      final fetchedUpdated = await followupRepo.getFollowupById('test-f1');
      expect(fetchedUpdated?.task, equals('Revised site visit time to 4:00 PM'));

      // Delete follow-up
      provider.deleteFollowup('test-f1');
      final remainingFollowups = await followupRepo.getFollowups(ownerId: provider.currentOwnerId);
      expect(remainingFollowups.any((f) => f.id == 'test-f1'), isFalse);
    });

    test('PDPA Consent Recording and Marketing Consent Withdrawal', () async {
      final consentRepo = InMemoryConsentRepository();
      final provider = AppStateProvider(consentRepository: consentRepo);

      const buyerId = 'buyer-pdpa-test-1';

      // 1. Record Enquiry Consent
      await provider.recordConsent(ConsentRecordModel(
        ownerId: provider.currentOwnerId,
        buyerId: buyerId,
        consentType: 'enquiry_response',
        consentStatus: 'granted',
        consentSource: 'Agent Direct Registration',
      ));

      // 2. Record Marketing Communication Consent
      await provider.recordConsent(ConsentRecordModel(
        ownerId: provider.currentOwnerId,
        buyerId: buyerId,
        consentType: 'marketing_communication',
        consentStatus: 'granted',
        consentSource: 'Agent Direct Registration',
      ));

      expect(provider.hasEnquiryConsent(buyerId), isTrue);
      expect(provider.hasActiveMarketingConsent(buyerId), isTrue);

      final consents = provider.getConsentsForBuyer(buyerId);
      expect(consents.length, equals(2));

      // 3. Withdraw Marketing Consent
      await provider.withdrawMarketingConsentForBuyer(buyerId);

      // Marketing consent is now false, while enquiry consent remains true
      expect(provider.hasActiveMarketingConsent(buyerId), isFalse);
      expect(provider.hasEnquiryConsent(buyerId), isTrue);

      // Verify in repository
      final repoConsents = await consentRepo.getConsentsForBuyer(buyerId);
      final marketingConsentInRepo = repoConsents.firstWhere((c) => c.consentType == 'marketing_communication');
      expect(marketingConsentInRepo.consentStatus, equals('withdrawn'));
      expect(marketingConsentInRepo.withdrawalTimestamp, isNotNull);
    });

    test('Follow-up model supports linked buyerId and projectId', () {
      final followup = FollowupModel(
        ownerId: 'agent-001',
        buyerName: 'Lee Wei Hong',
        buyerId: 'buyer-uuid-999',
        projectName: 'Eco Horizon Aster',
        projectId: 'project-uuid-888',
        task: 'Verify bank pre-approval letter for RM600k loan',
        dueDate: 'Next Monday, 11:00 AM',
        type: 'Loan Screening',
      );

      expect(followup.buyerId, equals('buyer-uuid-999'));
      expect(followup.projectId, equals('project-uuid-888'));
      expect(followup.isCompleted, isFalse);

      final map = followup.toMap();
      expect(map['buyerId'], equals('buyer-uuid-999'));
      expect(map['projectId'], equals('project-uuid-888'));

      final restored = FollowupModel.fromMap(map);
      expect(restored.buyerId, equals('buyer-uuid-999'));
      expect(restored.projectId, equals('project-uuid-888'));
      expect(restored.buyerName, equals('Lee Wei Hong'));
    });
  });
}
