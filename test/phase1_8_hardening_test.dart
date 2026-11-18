import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/consent_record_model.dart';
import 'package:propmatch_ai/models/followup_model.dart';
import 'package:propmatch_ai/models/lead_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/repositories/auth_repository.dart';
import 'package:propmatch_ai/repositories/buyer_repository.dart';
import 'package:propmatch_ai/repositories/campaign_repository.dart';
import 'package:propmatch_ai/repositories/consent_repository.dart';
import 'package:propmatch_ai/repositories/followup_repository.dart';
import 'package:propmatch_ai/repositories/lead_repository.dart';
import 'package:propmatch_ai/repositories/project_repository.dart';

// Test repository that simulates failure for error resilience testing
class FailingLeadRepository implements LeadRepository {
  @override
  Future<void> createLead(LeadModel lead) async {
    throw Exception('Firestore network write timeout');
  }

  @override
  Future<void> deleteLead(String id) async => throw Exception('Delete error');

  @override
  Future<LeadModel?> getLeadById(String id) async => null;

  @override
  Future<List<LeadModel>> getLeads({String? ownerId}) async => [];

  @override
  Future<void> updateLead(LeadModel lead) async => throw Exception('Update error');

  @override
  Future<void> updateLeadStatus(String id, String status) async =>
      throw Exception('Update status error');

  @override
  Future<bool> hasLead(String buyerId, String projectId) async => false;
}

// Test repository that simulates delayed async responses for race-condition testing
class DelayedProjectRepository implements ProjectRepository {
  final Duration delay;
  final List<ProjectModel> projectsToReturn;

  DelayedProjectRepository({
    required this.delay,
    required this.projectsToReturn,
  });

  @override
  Future<List<ProjectModel>> getProjects({String? ownerId}) async {
    await Future.delayed(delay);
    if (ownerId == 'agent-slow') {
      return projectsToReturn;
    }
    return [];
  }

  @override
  Future<void> createProject(ProjectModel project) async {}

  @override
  Future<void> updateProject(ProjectModel project) async {}

  @override
  Future<void> deleteProject(String id) async {}

  @override
  Future<ProjectModel?> getProjectById(String id) async => null;
}

void main() {
  group('Phase 1.8: Firebase Pre-Flight Hardening Test Suite', () {
    late InMemoryAuthRepository authRepo;
    late InMemoryProjectRepository projectRepo;
    late InMemoryBuyerRepository buyerRepo;
    late InMemoryLeadRepository leadRepo;
    late InMemoryFollowupRepository followupRepo;
    late InMemoryCampaignRepository campaignRepo;
    late InMemoryConsentRepository consentRepo;
    late AppStateProvider provider;

    setUp(() {
      authRepo = InMemoryAuthRepository();
      projectRepo = InMemoryProjectRepository();
      buyerRepo = InMemoryBuyerRepository();
      leadRepo = InMemoryLeadRepository();
      followupRepo = InMemoryFollowupRepository();
      campaignRepo = InMemoryCampaignRepository();
      consentRepo = InMemoryConsentRepository();

      provider = AppStateProvider(
        authRepository: authRepo,
        projectRepository: projectRepo,
        buyerRepository: buyerRepo,
        leadRepository: leadRepo,
        followupRepository: followupRepo,
        campaignRepository: campaignRepo,
        consentRepository: consentRepo,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Empty repository results clear demo data when logging into real agent account', () async {
      // Initially, in demo mode with default owner, demo data is present
      expect(provider.projects.isNotEmpty, isTrue);
      expect(provider.leads.isNotEmpty, isTrue);

      // Authenticate as a brand-new real agent whose repository is completely empty
      authRepo.switchUser(const SimpleAuthUser(
        uid: 'agent-new-001',
        email: 'newagent@realty.my',
        displayName: 'Ahmad Faiz (REN 99887)',
      ));

      // Allow async load to complete
      await Future.delayed(const Duration(milliseconds: 20));

      // Provider collections must be completely empty: no demo leakage!
      expect(provider.currentOwnerId, equals('agent-new-001'));
      expect(provider.projects, isEmpty);
      expect(provider.selectedProject, isNull);
      expect(provider.leads, isEmpty);
      expect(provider.followups, isEmpty);
      expect(provider.buyers, isEmpty);
      expect(provider.campaigns, isEmpty);
      expect(provider.activeProjectCount, equals(0));
    });

    test('2. Switching between two agent accounts ensures total collection isolation', () async {
      // 1. Set up Agent A records
      const agentAUid = 'agent-A';
      await projectRepo.createProject(ProjectModel(
        id: 'proj-A-1',
        ownerId: agentAUid,
        name: 'Agent A Exclusive Suites',
        developer: 'Developer A',
        location: 'Georgetown',
        state: 'Penang',
        startingPrice: 500000,
        maximumPrice: 700000,
        propertyType: 'Condominium',
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1100,
        description: 'Exclusive luxury suites in Georgetown.',
        purpose: 'Own Stay',
      ));
      await leadRepo.createLead(LeadModel(
        id: 'lead-A-1',
        ownerId: agentAUid,
        buyerId: 'b-A-1',
        projectId: 'proj-A-1',
        buyerName: 'Agent A Lead',
        projectName: 'Agent A Exclusive Suites',
        source: 'WhatsApp Enquiry',
      ));

      // 2. Set up Agent B records
      const agentBUid = 'agent-B';
      await projectRepo.createProject(ProjectModel(
        id: 'proj-B-1',
        ownerId: agentBUid,
        name: 'Agent B Waterfront Haven',
        developer: 'Developer B',
        location: 'Batu Kawan',
        state: 'Penang',
        startingPrice: 600000,
        maximumPrice: 900000,
        propertyType: 'Landed',
        bedrooms: 4,
        bathrooms: 3,
        builtUpArea: 1800,
        description: 'Waterfront living in Batu Kawan.',
        purpose: 'Own Stay',
      ));

      // Login as Agent A
      authRepo.switchUser(const SimpleAuthUser(
        uid: agentAUid,
        email: 'agentA@propmatch.ai',
        displayName: 'Agent A',
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(provider.currentOwnerId, equals(agentAUid));
      expect(provider.projects.length, equals(1));
      expect(provider.projects.first.name, equals('Agent A Exclusive Suites'));
      expect(provider.leads.length, equals(1));
      expect(provider.leads.first.buyerName, equals('Agent A Lead'));

      // Switch to Agent B
      authRepo.switchUser(const SimpleAuthUser(
        uid: agentBUid,
        email: 'agentB@propmatch.ai',
        displayName: 'Agent B',
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      // Agent A data must be completely flushed, only Agent B data present
      expect(provider.currentOwnerId, equals(agentBUid));
      expect(provider.projects.length, equals(1));
      expect(provider.projects.first.name, equals('Agent B Waterfront Haven'));
      expect(provider.leads, isEmpty); // Agent B has no leads
    });

    test('3. SignOut completely purges all in-memory records and resets selection', () async {
      // User logs out
      await authRepo.signOut();
      await Future.delayed(const Duration(milliseconds: 20));

      expect(provider.projects, isEmpty);
      expect(provider.selectedProject, isNull);
      expect(provider.buyers, isEmpty);
      expect(provider.leads, isEmpty);
      expect(provider.followups, isEmpty);
      expect(provider.campaigns, isEmpty);
      expect(provider.consentRecords, isEmpty);
      expect(provider.audienceSegments, isEmpty);
      expect(provider.matches, isEmpty);
    });

    test('4. Stale asynchronous loads are ignored when auth session ID transitions', () async {
      // Create a provider with a delayed project repository that takes 80ms
      final slowRepo = DelayedProjectRepository(
        delay: const Duration(milliseconds: 80),
        projectsToReturn: [
          ProjectModel(
            id: 'proj-slow',
            ownerId: 'agent-slow',
            name: 'Stale Project That Should Not Render',
            developer: 'Late Dev',
            location: 'Penang',
            state: 'Penang',
            startingPrice: 300000,
            maximumPrice: 400000,
            propertyType: 'Apartment',
            bedrooms: 2,
            bathrooms: 1,
            builtUpArea: 750,
            description: 'Stale description',
            purpose: 'Investment',
          ),
        ],
      );

      final raceProvider = AppStateProvider(
        authRepository: authRepo,
        projectRepository: slowRepo,
      );

      // Trigger session 1 (agent-slow)
      authRepo.switchUser(const SimpleAuthUser(
        uid: 'agent-slow',
        email: 'slow@agent.my',
        displayName: 'Slow Agent',
      ));

      // Immediately switch to session 2 before the 80ms delay finishes
      await Future.delayed(const Duration(milliseconds: 10));
      authRepo.switchUser(const SimpleAuthUser(
        uid: 'agent-fast',
        email: 'fast@agent.my',
        displayName: 'Fast Agent',
      ));

      // Wait until after the 80ms delay has elapsed
      await Future.delayed(const Duration(milliseconds: 120));

      // The stale response from session 1 must have been ignored!
      expect(raceProvider.projects.any((p) => p.id == 'proj-slow'), isFalse);

      raceProvider.dispose();
    });

    test('5. Repository failure resilience rolls back local collection on error', () async {
      final failingProvider = AppStateProvider(
        authRepository: authRepo,
        leadRepository: FailingLeadRepository(),
      );

      final testLead = LeadModel(
        ownerId: failingProvider.currentOwnerId,
        buyerId: 'b-error-1',
        projectId: 'p-error-1',
        buyerName: 'Test Buyer For Rollback',
        projectName: 'Test Project',
        source: 'Walk-in',
      );

      // Attempt to add lead - repository will throw
      try {
        await failingProvider.addLead(testLead);
        fail('addLead should have thrown on repository failure');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      // Verify that local in-memory collection was rolled back and is not corrupted
      expect(failingProvider.leads.any((l) => l.buyerName == 'Test Buyer For Rollback'), isFalse);

      failingProvider.dispose();
    });

    test('6. Buyer and Campaign CRUD provider methods operate correctly', () async {
      // 1. Buyer CRUD
      final newBuyer = BuyerModel(
        id: 'buyer-crud-1',
        ownerId: provider.currentOwnerId,
        name: 'Kavitha Devi',
        phone: '+6017-5556677',
        preferredLocation: 'Bayan Lepas',
        preferredState: 'Penang',
        budgetMin: 500000,
        budgetMax: 650000,
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        leadSource: 'Walk-in',
      );

      await provider.addBuyer(newBuyer);
      expect(provider.allBuyers.any((b) => b.id == 'buyer-crud-1'), isTrue);

      final updatedBuyer = newBuyer.copyWith(budgetMax: 700000);
      await provider.updateBuyer(updatedBuyer);
      expect(provider.allBuyers.firstWhere((b) => b.id == 'buyer-crud-1').budgetMax, equals(700000));

      await provider.deleteBuyer('buyer-crud-1');
      expect(provider.allBuyers.any((b) => b.id == 'buyer-crud-1'), isFalse);

      // 2. Campaign CRUD
      await provider.createCampaign(
        name: 'Penang Tech Hub Campaign',
        platform: 'Facebook Ads',
        headline: 'Modern Smart Living Near Bayan Lepas',
        body: '3-bedroom executive condo with sea view.',
        callToAction: 'Book VIP Viewing',
      );
      expect(provider.campaigns.isNotEmpty, isTrue);
      final campaign = provider.campaigns.first;
      expect(campaign.name, equals('Penang Tech Hub Campaign'));

      final updatedCampaign = campaign.copyWith(status: 'Paused');
      await provider.updateCampaign(updatedCampaign);
      expect(provider.campaigns.first.status, equals('Paused'));

      await provider.deleteCampaign(campaign.id);
      expect(provider.campaigns.any((c) => c.id == campaign.id), isFalse);
    });

    test('7. Consent append-only history preserves initial grant when withdrawal is logged', () async {
      const buyerId = 'buyer-pdpa-101';

      // 1. Initial consent granted
      final grantRecord = ConsentRecordModel(
        id: 'consent-grant-1',
        ownerId: provider.currentOwnerId,
        buyerId: buyerId,
        consentType: 'marketing_communication',
        consentStatus: 'granted',
        consentSource: 'Agent Registration Form',
        consentTimestamp: DateTime.now().subtract(const Duration(days: 30)),
      );
      await provider.recordConsent(grantRecord);

      expect(provider.hasActiveMarketingConsent(buyerId), isTrue);
      expect(provider.getConsentsForBuyer(buyerId).length, equals(1));

      // 2. Buyer requests withdrawal of marketing consent
      await provider.withdrawMarketingConsentForBuyer(buyerId, source: 'Customer WhatsApp Request');

      // Active marketing consent must now be false
      expect(provider.hasActiveMarketingConsent(buyerId), isFalse);

      // Audit trail must contain TWO records (grant preserved + withdrawal recorded)
      final history = provider.getConsentsForBuyer(buyerId);
      expect(history.length, equals(2));
      expect(history.any((c) => c.consentStatus == 'granted'), isTrue);
      expect(history.any((c) => c.consentStatus == 'withdrawn'), isTrue);
      expect(history.first.consentStatus, equals('withdrawn')); // newest first
    });

    test('8. Data Relationship Safety helpers and Cascading Name Updates', () async {
      const projId = 'proj-cascade-test';
      const buyerId = 'buyer-cascade-test';

      final testProject = ProjectModel(
        id: projId,
        ownerId: provider.currentOwnerId,
        name: 'Original Sky Tower',
        developer: 'Developer X',
        location: 'Penang',
        state: 'Penang',
        startingPrice: 400000,
        maximumPrice: 600000,
        propertyType: 'Condo',
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 950,
        description: 'Test condo',
        purpose: 'Own Stay',
      );
      await provider.addProject(testProject);

      final testBuyer = BuyerModel(
        id: buyerId,
        ownerId: provider.currentOwnerId,
        name: 'Original Buyer Name',
        phone: '+6011-22334455',
        preferredLocation: 'Penang',
        preferredState: 'Penang',
        budgetMin: 400000,
        budgetMax: 600000,
        propertyType: 'Condo',
        purchasePurpose: 'Investment',
        buyingTimeline: 'Immediate',
        leadSource: 'Referral',
      );
      await provider.addBuyer(testBuyer);

      final activeLead = LeadModel(
        id: 'lead-cascade-1',
        ownerId: provider.currentOwnerId,
        buyerId: buyerId,
        projectId: projId,
        buyerName: 'Original Buyer Name',
        projectName: 'Original Sky Tower',
        source: 'Walk-in',
        status: 'Contacted',
      );
      await provider.addLead(activeLead);

      final activeFollowup = FollowupModel(
        id: 'follow-cascade-1',
        ownerId: provider.currentOwnerId,
        buyerId: buyerId,
        projectId: projId,
        buyerName: 'Original Buyer Name',
        projectName: 'Original Sky Tower',
        task: 'Showroom visit',
        dueDate: 'Tomorrow',
        type: 'Viewing',
      );
      await provider.addFollowup(activeFollowup);

      // Test relationship safety helpers
      expect(provider.hasActiveLeadsForProject(projId), isTrue);
      expect(provider.hasFollowupsForProject(projId), isTrue);
      expect(provider.hasActiveLeadsOrFollowupsForBuyer(buyerId), isTrue);

      // Test Project Name Cascade Update
      final renamedProject = testProject.copyWith(name: 'Renamed Sky Horizon');
      await provider.updateProject(renamedProject);

      expect(provider.leads.firstWhere((l) => l.projectId == projId).projectName, equals('Renamed Sky Horizon'));
      expect(provider.followups.firstWhere((f) => f.projectId == projId).projectName, equals('Renamed Sky Horizon'));

      // Test Buyer Name Cascade Update
      final renamedBuyer = testBuyer.copyWith(name: 'Renamed Buyer VIP');
      await provider.updateBuyer(renamedBuyer);

      expect(provider.leads.firstWhere((l) => l.buyerId == buyerId).buyerName, equals('Renamed Buyer VIP'));
      expect(provider.followups.firstWhere((f) => f.buyerId == buyerId).buyerName, equals('Renamed Buyer VIP'));
    });

    test('9. Consent default values adhere strictly to PDPA opt-in rules', () {
      const unconsentedBuyerId = 'buyer-unconsented-1';

      // When a buyer is registered without checking consent boxes, no consent is granted
      expect(provider.hasEnquiryConsent(unconsentedBuyerId), isFalse);
      expect(provider.hasActiveMarketingConsent(unconsentedBuyerId), isFalse);
      expect(provider.getConsentsForBuyer(unconsentedBuyerId), isEmpty);
    });

    test('10. Multi-agent data isolation: Repositories strictly scope queries by ownerId', () async {
      const agent1 = 'agent-north-001';
      const agent2 = 'agent-central-002';

      final buyer1 = BuyerModel(
        ownerId: agent1,
        name: 'Penang Investor',
        preferredLocation: 'Georgetown',
        preferredState: 'Penang',
        budgetMin: 800000,
        budgetMax: 1200000,
        propertyType: 'Condominium',
        purchasePurpose: 'Investment',
        buyingTimeline: '1 month',
        leadSource: 'Exhibition',
      );

      final buyer2 = BuyerModel(
        ownerId: agent2,
        name: 'KL Family Homebuyer',
        preferredLocation: 'Mont Kiara',
        preferredState: 'Kuala Lumpur',
        budgetMin: 1500000,
        budgetMax: 2000000,
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: '3 months',
        leadSource: 'Referral',
      );

      await buyerRepo.createBuyer(buyer1);
      await buyerRepo.createBuyer(buyer2);

      // Query for Agent 1 must only return Agent 1's buyer
      final agent1Buyers = await buyerRepo.getBuyers(ownerId: agent1);
      expect(agent1Buyers.length, equals(1));
      expect(agent1Buyers.first.name, equals('Penang Investor'));

      // Query for Agent 2 must only return Agent 2's buyer
      final agent2Buyers = await buyerRepo.getBuyers(ownerId: agent2);
      expect(agent2Buyers.length, equals(1));
      expect(agent2Buyers.first.name, equals('KL Family Homebuyer'));

      // Clean up
      await buyerRepo.deleteBuyer(buyer1.id);
      await buyerRepo.deleteBuyer(buyer2.id);
    });
  });
}
