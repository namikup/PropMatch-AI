import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/config/pilot_config.dart';
import 'package:propmatch_ai/models/user_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/services/agent_directory_service.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';
import 'package:propmatch_ai/screens/prospects/buyer_intelligence_screen.dart';
import 'package:propmatch_ai/screens/settings/settings_screen.dart';
import 'package:propmatch_ai/screens/auth/login_screen.dart';

void main() {
  group('Phase 4.4.2 — Single-Agent Private Pilot Access Controls', () {
    test('1.1 Single-Agent Pilot configuration flags are active and strict', () {
      expect(PilotConfig.isSingleAgentPilotMode, isTrue);
      expect(PilotConfig.allowUnrestrictedPublicRegistration, isFalse);
      expect(PilotConfig.enablePublicAgentDirectory, isFalse);
      expect(PilotConfig.enablePlatformLeadDistribution, isFalse);
      expect(PilotConfig.enableSubscriptionTiersUI, isFalse);
      expect(PilotConfig.enableMultiAgentSwitching, isFalse);
      expect(PilotConfig.pilotRegistrationInviteCode, equals('PILOT-MY-2026'));
    });

    test('1.2 Authorization check distinguishes pilot agent, admins, and unauthorized users', () {
      // Authorized: Designated Pilot Agent
      expect(PilotConfig.isUserAuthorized(PilotConfig.defaultPilotAgentEmail, PilotConfig.defaultPilotAgentOwnerId), isTrue);
      expect(PilotConfig.isUserAuthorized('alex.tan@iqirealty.com', 'agent-alex-penang-001'), isTrue);

      // Authorized: Administrators (separate maintenance access)
      expect(PilotConfig.isUserAuthorized('admin@propmatch.ai', 'admin-uid-001'), isTrue);
      expect(PilotConfig.isUserAuthorized('developer@propmatch.ai', 'dev-uid-002'), isTrue);

      // Blocked: Random public uninvited users
      expect(PilotConfig.isUserAuthorized('stranger@gmail.com', 'random-uid-999'), isFalse);
      expect(PilotConfig.isUserAuthorized('competitor@propertyguru.com', 'comp-uid-888'), isFalse);
    });

    test('1.3 Unrestricted registration without invite code is blocked', () {
      // Missing or wrong invite code must not match
      expect(''.trim() == PilotConfig.pilotRegistrationInviteCode, isFalse);
      expect('WRONG_CODE'.trim() == PilotConfig.pilotRegistrationInviteCode, isFalse);

      // Valid invite code matches
      expect('PILOT-MY-2026'.trim() == PilotConfig.pilotRegistrationInviteCode, isTrue);
    });
  });

  group('Phase 4.4.2 — UI Scoping & Multi-Agent Feature Disabling', () {
    testWidgets('2.1 Buyer Intelligence Screen hides Channel B & subscription tiers in pilot mode',
        (tester) async {
      final appState = AppStateProvider();
      final navProvider = NavigationProvider();

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<NavigationProvider>.value(value: navProvider),
          ],
          child: const MaterialApp(
            home: BuyerIntelligenceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check retained tabs
      expect(find.text('Prospect Database'), findsOneWidget);
      expect(find.text('Incoming Enquiries (Pipeline)'), findsOneWidget);
      expect(find.text('Agent Landing Page & Campaigns (Channel A)'), findsOneWidget);
      expect(find.text('Sources & Integrations'), findsOneWidget);

      // Verify that Platform Lead Preferences (Channel B) and Subscription Tiers are hidden
      expect(find.text('Platform Lead Preferences (Channel B)'), findsNothing);
      expect(find.text('Active Plan Tier'), findsNothing);
      expect(find.text('Deterministic Routing Algorithm'), findsNothing);
    });

    testWidgets('2.2 Settings Screen shows Single-Agent Private Pilot Status card',
        (tester) async {
      final appState = AppStateProvider();

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Single-Agent Private Pilot Status'), findsOneWidget);
      expect(find.text('Single-Agent Exclusive'), findsOneWidget);
      expect(find.text('100% Agent-Owned (Multi-tenant ownerId enforced)'), findsOneWidget);
      expect(find.text('Disabled (No public agent directory or comparison)'), findsOneWidget);
    });

    testWidgets('2.3 Login Screen provides direct public landing link for buyers without accounts',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(),
          child: MaterialApp(
            home: LoginScreen(onLoginSuccess: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify public buyer navigation option
      expect(find.text('Public Visitor or Buyer? View Featured Properties'), findsOneWidget);
      expect(find.text('No account needed to browse properties or submit an enquiry.'), findsOneWidget);
    });
  });

  group('Phase 4.4.2 — Real Property Portfolio Connection to Landing Page', () {
    test('3.1 Pilot agent registered properties take precedence over demo projects', () {
      final pilotAgent = UserModel(
        id: 'usr-pilot-001',
        ownerId: 'pilot-agent-001',
        landingPageSlug: 'pilot-malik',
        fullName: 'Malik Tan',
        email: 'malik@iqirealty.com',
        agencyName: 'IQI Realty Sdn Bhd',
        renNumber: 'REN 52891',
        region: 'Penang & Northern Region',
      );

      final realProject = ProjectModel(
        id: 'proj-real-pilot-001',
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
        description: 'Actual verified pilot listing in Batu Kawan.',
        ownerId: 'pilot-agent-001',
      );

      final otherProject = ProjectModel(
        id: 'proj-other-002',
        name: 'KL Luxury Suites',
        developer: 'KL Dev',
        state: 'Kuala Lumpur',
        location: 'Mont Kiara',
        propertyType: 'Condominium',
        startingPrice: 1200000,
        maximumPrice: 1500000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1200,
        purpose: 'Investment',
        description: 'Other agent listing.',
        ownerId: 'other-agent-999',
      );

      final featured = AgentDirectoryService.getFeaturedProjectsForAgent(
        pilotAgent,
        availableProjects: [realProject, otherProject],
      );

      // Featured projects must strictly contain ONLY the pilot agent's real property
      expect(featured.length, equals(1));
      expect(featured.first.id, equals('proj-real-pilot-001'));
      expect(featured.first.name, equals('Eco Horizon Astonia Townhome'));
      expect(featured.first.ownerId, equals('pilot-agent-001'));
    });

    test('3.2 Unauthenticated buyer can submit enquiry on pilot property with strict data ownership',
        () async {
      const pilotOwnerId = 'pilot-agent-001';

      final realProject = ProjectModel(
        id: 'proj-real-pilot-001',
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
        description: 'Actual verified pilot listing in Batu Kawan.',
        ownerId: pilotOwnerId,
      );

      final payload = {
        'name': 'David Lee',
        'phone': '+60124998877',
        'email': 'david.lee@techfirm.com',
        'propertyType': 'Terrace House',
        'location': 'Batu Kawan',
        'budgetMax': 750000.0,
        'buyingPurpose': 'Own Stay',
        'timeline': 'Within 3 months',
        'projectId': realProject.id,
        'enquiryConsentGranted': true,
        'marketingConsentGranted': true,
        'notes': 'Interested in the corner lot.',
        'campaignId': 'batu-kawan-roadshow',
        'utmSource': 'facebook',
        'utmMedium': 'cpc',
        'utmCampaign': 'pilot_launch',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Direct Website',
        rawPayload: payload,
        existingProspects: const [],
        availableProjects: [realProject],
      );

      expect(result.success, isTrue);
      expect(result.enquiry.ownerId, equals(pilotOwnerId));
      expect(result.enquiry.assignedAgentId, equals(pilotOwnerId));
      expect(result.createdProspect, isNotNull);
      expect(result.createdProspect!.ownerId, equals(pilotOwnerId));
      expect(result.createdProspect!.fullName, equals('David Lee'));
      expect(result.createdProspect!.contactEligibility, equals('Eligible'));
      expect(result.createdProspect!.tags, contains('Campaign: batu-kawan-roadshow'));
      expect(result.createdProspect!.tags, contains('Channel A: Personal Landing Page'));
    });

    test('3.3 Security: Anti-tampering prevents stealing pilot leads by overriding assignedAgentId',
        () async {
      const pilotOwnerId = 'pilot-agent-001';

      // Attacker attempts to forge assignedAgentId in the payload to another owner
      final maliciousPayload = {
        'name': 'Spoofed Buyer',
        'phone': '+60178889999',
        'propertyType': 'Terrace House',
        'location': 'Batu Kawan',
        'budgetMax': 650000.0,
        'assignedAgentId': 'malicious-agent-666',
        'ownerId': 'malicious-agent-666',
        'enquiryConsentGranted': true,
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId, // Authoritative landing page owner
        sourceType: 'Direct Website',
        rawPayload: maliciousPayload,
        existingProspects: const [],
      );

      // Ownership must be forcefully bounded to the host page's pilot agent
      expect(result.success, isTrue);
      expect(result.enquiry.ownerId, equals(pilotOwnerId));
      expect(result.enquiry.assignedAgentId, equals(pilotOwnerId));
      expect(result.createdProspect!.ownerId, equals(pilotOwnerId));
    });
  });
}
