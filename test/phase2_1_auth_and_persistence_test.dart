import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/repositories/auth_repository.dart';
import 'package:propmatch_ai/repositories/project_repository.dart';
import 'package:propmatch_ai/repositories/buyer_repository.dart';
import 'package:propmatch_ai/repositories/lead_repository.dart';
import 'package:propmatch_ai/repositories/followup_repository.dart';
import 'package:propmatch_ai/repositories/campaign_repository.dart';
import 'package:propmatch_ai/repositories/consent_repository.dart';
import 'package:propmatch_ai/screens/auth/login_screen.dart';

void main() {
  group('Phase 2.1: Real Authentication & Persistence Architecture', () {
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

    test('1. Registration in AuthRepository creates complete agent profile with ownerId == uid', () async {
      final user = await authRepo.registerWithEmail(
        email: 'alex.tan@iqiglobal.com',
        password: 'password123',
        fullName: 'Alex Tan Wei Meng',
        renNumber: 'REN 45892',
        agencyName: 'IQI Global Malaysia',
        phone: '+6012-3456789',
        region: 'Penang & Northern Region',
      );

      expect(user, isNotNull);
      expect(user!.email, equals('alex.tan@iqiglobal.com'));
      expect(user.displayName, equals('Alex Tan Wei Meng'));

      final profile = await authRepo.getUserProfile(user.uid);
      expect(profile, isNotNull);
      expect(profile!.ownerId, equals(user.uid));
      expect(profile.fullName, equals('Alex Tan Wei Meng'));
      expect(profile.renNumber, equals('REN 45892'));
      expect(profile.agencyName, equals('IQI Global Malaysia'));
      expect(profile.phone, equals('+6012-3456789'));
      expect(profile.region, equals('Penang & Northern Region'));
    });

    test('2. Sign in with email establishes active auth user and emits on auth stream', () async {
      final emittedUsers = <AuthUser?>[];
      final sub = authRepo.authStateChanges().listen(emittedUsers.add);

      final loggedIn = await authRepo.signInWithEmail('agent.lee@realty.my', 'secure123');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(loggedIn, isNotNull);
      expect(authRepo.currentUser?.uid, equals(loggedIn!.uid));
      expect(emittedUsers.any((u) => u?.uid == loggedIn.uid), isTrue);

      await sub.cancel();
    });

    test('3. Dedicated Demo Mode separation vs real agent login', () async {
      // Demo credentials sign in as demo-agent-001
      final demoUser = await authRepo.signInWithEmail('agent@propmatch.ai', 'demo1234');
      expect(demoUser, isNotNull);
      expect(demoUser!.uid, equals('demo-agent-001'));

      // Real agent email signs in with unique agent uid
      final realUser = await authRepo.signInWithEmail('real.agent@prop.my', 'secretPass');
      expect(realUser, isNotNull);
      expect(realUser!.uid, isNot(equals('demo-agent-001')));
      expect(realUser.uid, contains('real.agent'));
    });

    test('4. Sign out clears currentUser, emits null, and purges provider collections', () async {
      // Setup real agent with data
      final agent = await authRepo.registerWithEmail(
        email: 'chong@realty.com',
        password: 'pass123456',
        fullName: 'Chong Wei',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      await provider.addProject(ProjectModel(
        id: 'proj-c1',
        ownerId: agent!.uid,
        name: 'Chong Condo',
        developer: 'Chong Dev',
        location: 'Georgetown',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 500000,
        maximumPrice: 800000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1050,
        description: 'Test condo',
        purpose: 'Own Stay',
        status: 'New Launch',
      ));

      expect(provider.projects.length, equals(1));

      // Sign out
      await authRepo.signOut();
      await Future.delayed(const Duration(milliseconds: 20));

      expect(authRepo.currentUser, isNull);
      expect(provider.projects, isEmpty);
      expect(provider.buyers, isEmpty);
      expect(provider.currentUserProfile, isNull);
    });

    test('5. Real authenticated accounts never auto-generate 100 demo buyers on buyer matching', () async {
      // Register a real agent
      final realAgent = await authRepo.registerWithEmail(
        email: 'sarah.lim@prop.my',
        password: 'pass123456',
        fullName: 'Sarah Lim',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      expect(provider.isDemoMode, isFalse);
      expect(provider.buyers, isEmpty);

      final project = ProjectModel(
        id: 'proj-real-1',
        ownerId: realAgent!.uid,
        name: 'Gurney Heights',
        developer: 'Gurney Dev',
        location: 'Gurney',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 800000,
        maximumPrice: 1200000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1200,
        description: 'Luxury',
        purpose: 'Own Stay',
        status: 'New Launch',
      );
      await provider.addProject(project);

      // Run buyer matching on real account with empty buyers
      await provider.runBuyerMatching(project);

      // CRITICAL: Real account MUST NOT auto-populate with 100 demo buyers!
      expect(provider.buyers, isEmpty);
      expect(provider.matches, isEmpty);
    });

    test('6. Demo mode still auto-generates 100 demo buyers on matching if buyers are empty', () async {
      await authRepo.signInWithEmail('agent@propmatch.ai', 'demo1234');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(provider.isDemoMode, isTrue);

      // Purge buyers temporarily to test fallback in demo mode
      final p = provider.projects.first;
      await provider.runBuyerMatching(p);

      // Demo mode generates demo buyers
      expect(provider.buyers.length, greaterThanOrEqualTo(100));
      expect(provider.buyers.every((b) => b.isDemo), isTrue);
    });

    test('7. reloadCurrentAgentData refreshes data for authenticated agent', () async {
      final agent = await authRepo.registerWithEmail(
        email: 'khoo@agency.my',
        password: 'pass123456',
        fullName: 'Khoo Teck',
      );
      await Future.delayed(const Duration(milliseconds: 20));

      // Inject project directly into repository
      await projectRepo.createProject(ProjectModel(
        id: 'p-direct',
        ownerId: agent!.uid,
        name: 'Direct Injected Project',
        developer: 'Direct Dev',
        location: 'Batu Kawan',
        state: 'Penang',
        propertyType: 'Landed',
        startingPrice: 600000,
        maximumPrice: 900000,
        bedrooms: 4,
        bathrooms: 3,
        builtUpArea: 1800,
        description: 'Direct injected',
        purpose: 'Own Stay',
        status: 'New Launch',
      ));

      await provider.reloadCurrentAgentData();
      expect(provider.projects.any((p) => p.id == 'p-direct'), isTrue);
    });

    testWidgets('8. LoginScreen renders Sign In & Register tabs, demo banner, and validates inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool loginSuccessCalled = false;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LoginScreen(
              onLoginSuccess: () {
                loginSuccessCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Tabs
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register Agent'), findsOneWidget);

      // Check Demo Sandbox Card
      expect(find.text('Demo Sandbox Available'), findsOneWidget);
      expect(find.text('Use Demo Account'), findsOneWidget);

      // Click "Use Demo Account"
      await tester.tap(find.text('Use Demo Account'));
      await tester.pumpAndSettle();

      // Submit demo sign in
      await tester.tap(find.text('Sign In to SaaS Platform'));
      await tester.pumpAndSettle();

      expect(loginSuccessCalled, isTrue);

      // Switch to Register Agent tab
      await tester.tap(find.text('Register Agent'));
      await tester.pumpAndSettle();

      // Verify registration form fields
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Password *'), findsOneWidget);
      expect(find.text('Confirm *'), findsOneWidget);
      expect(find.text('Phone Number *'), findsOneWidget);
      expect(find.text('REN Number *'), findsOneWidget);
      expect(find.text('Agency Name *'), findsOneWidget);

      // Tap Create Agent Account without filling fields -> triggers validation errors
      await tester.tap(find.text('Create Agent Account'));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
    });
  });
}
