import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/lead_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/followup_model.dart';
import 'package:propmatch_ai/models/consent_record_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/repositories/auth_repository.dart';
import 'package:propmatch_ai/repositories/project_repository.dart';
import 'package:propmatch_ai/repositories/buyer_repository.dart';
import 'package:propmatch_ai/repositories/lead_repository.dart';
import 'package:propmatch_ai/repositories/followup_repository.dart';
import 'package:propmatch_ai/repositories/campaign_repository.dart';
import 'package:propmatch_ai/repositories/consent_repository.dart';
import 'package:propmatch_ai/screens/auth/login_screen.dart';

/// Throwing repository to test optimistic update rollbacks
class FailingProjectRepository implements ProjectRepository {
  @override
  Future<void> createProject(ProjectModel project) async => throw Exception('Simulated Firestore Write Failure');
  @override
  Future<void> deleteProject(String id) async => throw Exception('Simulated Firestore Delete Failure');
  @override
  Future<ProjectModel?> getProjectById(String id) async => null;
  @override
  Future<List<ProjectModel>> getProjects({required String ownerId}) async => [];
  @override
  Future<void> updateProject(ProjectModel project) async => throw Exception('Simulated Firestore Update Failure');
}

class FailingBuyerRepository implements BuyerRepository {
  @override
  Future<void> createBuyer(BuyerModel buyer) async => throw Exception('Simulated Firestore Create Failure');
  @override
  Future<void> deleteBuyer(String id) async => throw Exception('Simulated Firestore Delete Failure');
  @override
  Future<void> deleteDemoBuyers({required String ownerId}) async {}
  @override
  Future<BuyerModel?> getBuyerById(String id) async => null;
  @override
  Future<List<BuyerModel>> getBuyers({required String ownerId}) async => [];
  @override
  Future<void> saveBulkBuyers(List<BuyerModel> buyers) async {}
  @override
  Future<void> updateBuyer(BuyerModel buyer) async => throw Exception('Simulated Firestore Update Failure');
}

void main() {
  group('Phase 2.4: Production Readiness & Hardening Test Suite', () {
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
      projectRepo = InMemoryProjectRepository([]);
      buyerRepo = InMemoryBuyerRepository([]);
      leadRepo = InMemoryLeadRepository([]);
      followupRepo = InMemoryFollowupRepository([]);
      campaignRepo = InMemoryCampaignRepository([]);
      consentRepo = InMemoryConsentRepository([]);

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

    test('1. AuthRepository sendPasswordResetEmail registers email request', () async {
      await authRepo.sendPasswordResetEmail('agent.reset@propmatch.ai');
      expect(authRepo.sentPasswordResetEmails, contains('agent.reset@propmatch.ai'));

      final user = authRepo.currentUser;
      expect(user?.isEmailVerified, isTrue);
    });

    testWidgets('2. LoginScreen Forgot Password Dialog opens and sends reset link', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LoginScreen(onLoginSuccess: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Forgot Password?
      final forgotBtn = find.text('Forgot Password?');
      expect(forgotBtn, findsOneWidget);
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      // Submit reset link
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Password reset email sent! Check your inbox.'), findsOneWidget);
      expect(authRepo.sentPasswordResetEmails, contains('agent@propmatch.ai'));
    });

    test('3. Fallback User Profile synthesis on missing Firestore document', () async {
      // Simulate an authenticated user who has no existing document in users/{uid}
      authRepo.switchUser(const SimpleAuthUser(
        uid: 'user-without-firestore-doc',
        email: 'missing.doc@propmatch.my',
        displayName: 'Dr. Lim Guan Eng',
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(provider.currentUserProfile, isNotNull);
      expect(provider.currentUserProfile!.ownerId, equals('user-without-firestore-doc'));
      expect(provider.currentUserProfile!.fullName, equals('Dr. Lim Guan Eng'));
      expect(provider.currentUserProfile!.agencyName, equals('PropMatch Agency'));
      expect(provider.currentUserProfile!.renNumber, equals('REN (Pending)'));
    });

    test('4. Optimistic update rollback on simulated Firestore write failures', () async {
      final failingProvider = AppStateProvider(
        authRepository: authRepo,
        projectRepository: FailingProjectRepository(),
        buyerRepository: FailingBuyerRepository(),
      );

      final project = ProjectModel(
        id: 'proj-fail-test',
        ownerId: 'demo-agent-001',
        name: 'Fail Project',
        developer: 'Fail Dev',
        location: 'George Town',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 500000,
        maximumPrice: 700000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1000,
        description: 'Testing rollback',
        purpose: 'Own Stay',
      );

      // Adding project should throw and rollback collection to empty
      await expectLater(failingProvider.addProject(project), throwsA(isA<Exception>()));
      expect(failingProvider.projects.any((p) => p.id == 'proj-fail-test'), isFalse);
    });

    test('5. PDPA Consent Recording and Withdrawal audit trail immutability', () async {
      final agent = await authRepo.registerWithEmail(
        email: 'pdpa.agent@prop.my',
        password: 'password123',
        fullName: 'Agent PDPA',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      // Grant consent
      final grantRecord = ConsentRecordModel(
        id: 'consent-001',
        ownerId: agent!.uid,
        buyerId: 'buyer-001',
        consentType: 'marketing_communication',
        consentStatus: 'granted',
        consentSource: 'WhatsApp Lead',
      );
      await provider.recordConsent(grantRecord);

      expect(provider.consentRecords.length, equals(1));
      expect(provider.consentRecords.first.consentStatus, equals('granted'));

      // Log withdrawal event (new audit trail record)
      await provider.withdrawMarketingConsentForBuyer('buyer-001');

      // In-memory consent records should now hold both historic events
      expect(provider.consentRecords.length, equals(2));
      expect(provider.consentRecords.any((c) => c.consentStatus == 'withdrawn'), isTrue);
      expect(provider.consentRecords.any((c) => c.consentStatus == 'granted'), isTrue);
    });

    test('6. Empty database analytics computations execute safely without crashing', () async {
      // Authenticate clean account with 0 records
      await authRepo.registerWithEmail(
        email: 'empty.agent@prop.my',
        password: 'password123',
        fullName: 'Clean Agent',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      expect(provider.projects, isEmpty);
      expect(provider.buyers, isEmpty);
      expect(provider.leads, isEmpty);

      // Computed metrics must not throw divide-by-zero or null exceptions
      expect(provider.pipelineConversionRate, equals(0.0));
      expect(provider.averageBuyerBudget, equals(0.0));
      expect(provider.averageMatchRate, equals(0.0));
      expect(provider.topBuyerLocation, equals('Batu Kawan'));
      expect(provider.buyersByBudgetTier['Under RM 450,000'], equals(0));
      expect(provider.leadsBySource['WhatsApp Enquiry'], equals(0));
    });

    test('7. Lead status transitions and follow-up completion toggle', () async {
      final agent = await authRepo.registerWithEmail(
        email: 'pipeline.agent@prop.my',
        password: 'password123',
        fullName: 'Pipeline Agent',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      final lead = LeadModel(
        id: 'lead-test-1',
        ownerId: agent!.uid,
        buyerId: 'b-1',
        projectId: 'p-1',
        buyerName: 'Wong Ah Kow',
        projectName: 'The Light Collection',
        source: 'WhatsApp Enquiry',
        status: 'New',
        dealValue: 900000,
      );
      await provider.addLead(lead);

      expect(provider.newEnquiryCount, equals(1));

      // Transition to Contacted
      await provider.updateLeadStatus('lead-test-1', 'Contacted');
      expect(provider.leads.first.status, equals('Contacted'));

      // Transition to Qualified
      await provider.updateLeadStatus('lead-test-1', 'Qualified');
      expect(provider.qualifiedLeadCount, equals(1));

      // Follow-up toggle
      final followup = FollowupModel(
        id: 'fu-test-1',
        ownerId: agent.uid,
        buyerName: 'Wong Ah Kow',
        projectName: 'The Light Collection',
        task: 'Send brochure via WhatsApp',
        dueDate: 'Tomorrow',
        type: 'Call',
        isCompleted: false,
      );
      await provider.addFollowup(followup);

      expect(provider.followups.first.isCompleted, isFalse);
      await provider.toggleFollowupCompletion('fu-test-1');
      expect(provider.followups.first.isCompleted, isTrue);
    });
  });
}
