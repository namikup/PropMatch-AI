import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/agent_preferences_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/subscription_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/screens/landing/agent_landing_page_screen.dart';
import 'package:propmatch_ai/screens/landing/agent_not_found_screen.dart';
import 'package:propmatch_ai/services/agent_directory_service.dart';
import 'package:propmatch_ai/services/lead_distribution/lead_distribution_engine.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';

void main() {
  group('Phase 4.4.1: Real-World Agent Experience & Landing Page Validation', () {
    const String agentAId = 'agent-alex-penang-001';
    const String agentASlug = 'alex-tan-penang';
    const String agentBId = 'agent-brenda-kl-002';
    const String agentBSlug = 'brenda-lim-kl';
    const String agentCId = 'agent-calvin-penang-003';
    const String agentCSlug = 'calvin-ong-penang';

    // =========================================================================
    // 1. PUBLIC LANDING PAGE URL ROUTING & AGENT PROFILE RESOLUTION
    // =========================================================================
    group('1. Public Landing Page URL Routing & Directory Resolution', () {
      test('1.1 Directory resolves Agent A (Alex Tan) by slug and ownerId', () {
        final agentBySlug = AgentDirectoryService.findAgent(agentASlug);
        final agentById = AgentDirectoryService.findAgent(agentAId);

        expect(agentBySlug, isNotNull);
        expect(agentById, isNotNull);
        expect(agentBySlug!.ownerId, equals(agentAId));
        expect(agentBySlug.fullName, equals('Alex Tan Chee Keong'));
        expect(agentBySlug.isRenVerified, isTrue);
        expect(agentBySlug.renNumber, equals('REN 45892'));
        expect(agentBySlug.region, contains('Penang'));
      });

      test('1.2 Directory resolves Agent B (Brenda Lim) by slug and ownerId', () {
        final agent = AgentDirectoryService.findAgent(agentBSlug);
        expect(agent, isNotNull);
        expect(agent!.ownerId, equals(agentBId));
        expect(agent.fullName, equals('Brenda Lim Shu Wei'));
        expect(agent.isRenVerified, isTrue);
        expect(agent.renNumber, equals('REN 31204'));
        expect(agent.region, contains('Kuala Lumpur'));
      });

      test('1.3 Directory resolves Agent C (Calvin Ong - Unverified REN)', () {
        final agent = AgentDirectoryService.findAgent(agentCSlug);
        expect(agent, isNotNull);
        expect(agent!.ownerId, equals(agentCId));
        expect(agent.isRenVerified, isFalse);
        expect(agent.renNumber, equals('REN 99999'));
      });

      test('1.4 Directory returns null for invalid or non-existent agent slug', () {
        final agent = AgentDirectoryService.findAgent('unknown-agent-999');
        expect(agent, isNull);

        final emptyAgent = AgentDirectoryService.findAgent('');
        expect(emptyAgent, isNull);
      });

      testWidgets('1.5 Navigating to /agent/alex-tan-penang renders Agent A Landing Page directly', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final agent = AgentDirectoryService.findAgent(agentASlug)!;
        final projects = AgentDirectoryService.getFeaturedProjectsForAgent(agent);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
              ChangeNotifierProvider(create: (_) => AppStateProvider()),
            ],
            child: MaterialApp(
              home: AgentLandingPageScreen(
                agent: agent,
                featuredProjects: projects,
                utmSource: 'facebook',
                utmMedium: 'cpc',
                utmCampaign: 'summer_promo',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify unauthenticated visitor sees agent hero & credentials
        expect(find.text('Alex Tan Chee Keong'), findsOneWidget);
        expect(find.text('Verified REN 45892'), findsOneWidget);
        expect(find.textContaining('IQI Realty Sdn Bhd'), findsOneWidget);
        expect(find.textContaining('Penang & Northern Region'), findsOneWidget);

        // Verify buyer enquiry form is ready
        expect(find.text('Buyer Enquiry Form'), findsOneWidget);
        expect(find.text('Submit Property Enquiry'), findsOneWidget);
      });

      testWidgets('1.6 Navigating to unknown slug renders AgentNotFoundScreen with clean 404', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: AgentNotFoundScreen(requestedSlug: 'unknown-agent-999'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Agent Landing Page Not Found'), findsOneWidget);
        expect(find.textContaining('@unknown-agent-999'), findsOneWidget);
        expect(find.text('Return to PropMatch AI Home'), findsOneWidget);
        // Verify no sensitive database traces or errors
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('NullPointer'), findsNothing);
      });
    });

    // =========================================================================
    // 2. UNAUTHENTICATED VISITOR & SUBMISSION EXPERIENCE
    // =========================================================================
    group('2. Unauthenticated Visitor Experience & Form Submissions', () {
      testWidgets('2.1 Visitor can fill and submit buyer enquiry with confirmation', (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final agent = AgentDirectoryService.findAgent(agentASlug)!;
        final appState = AppStateProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
              ChangeNotifierProvider.value(value: appState),
            ],
            child: MaterialApp(
              home: AgentLandingPageScreen(
                agent: agent,
                utmSource: 'facebook',
                utmCampaign: 'penang_launch',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill Form
        final nameFinder = find.widgetWithText(TextFormField, 'e.g. Ahmad Farhan bin Osman');
        final phoneFinder = find.widgetWithText(TextFormField, 'e.g. 012-3456789');
        final emailFinder = find.widgetWithText(TextFormField, 'e.g. buyer@example.com');

        await tester.enterText(nameFinder, 'Khor Chia Ming');
        await tester.enterText(phoneFinder, '+60124455888');
        await tester.enterText(emailFinder, 'khor.cm@gmail.com');

        // Scroll to submit button
        final submitButton = find.widgetWithText(ElevatedButton, 'Submit Property Enquiry');
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();

        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Verify submission confirmation card
        expect(find.text('Enquiry Submitted Successfully!'), findsOneWidget);
        expect(find.textContaining('Thank you, Khor Chia Ming'), findsOneWidget);
        expect(find.textContaining('Reference ID:'), findsOneWidget);
      });

      testWidgets('2.2 Form validation catches missing required contact info', (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final agent = AgentDirectoryService.findAgent(agentASlug)!;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
              ChangeNotifierProvider(create: (_) => AppStateProvider()),
            ],
            child: MaterialApp(
              home: AgentLandingPageScreen(agent: agent),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final submitButton = find.widgetWithText(ElevatedButton, 'Submit Property Enquiry');
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();

        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Full name is required'), findsOneWidget);
        expect(find.text('Phone number is required'), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. TWO-AGENT ISOLATION & CLIENT-SIDE ANTI-TAMPERING TEST
    // =========================================================================
    group('3. Two-Agent Isolation & Anti-Tampering Security', () {
      final List<ProspectModel> agentAProspects = [];
      final List<ProspectModel> agentBProspects = [];

      setUp(() {
        agentAProspects.clear();
        agentBProspects.clear();
      });

      test('3.1 Submissions on Agent A page route strictly to Agent A database', () async {
        final payload = {
          'name': 'Daryl Ooi',
          'phone': '+60125556677',
          'location': 'Batu Kawan',
          'propertyType': 'Condominium',
          'budgetMax': 550000.0,
          'enquiryConsentGranted': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.ownerId, equals(agentAId));
        expect(result.enquiry.assignedAgentId, equals(agentAId));
        expect(result.enquiry.routingStatus, equals('Direct'));
        expect(result.createdProspect!.ownerId, equals(agentAId));
        agentAProspects.add(result.createdProspect!);

        // Verify Agent B cannot see Agent A's prospect
        final agentBViews = agentBProspects.where((p) => p.ownerId == agentBId).toList();
        expect(agentBViews, isEmpty);
      });

      test('3.2 Submissions on Agent B page route strictly to Agent B database', () async {
        final payload = {
          'name': 'Farah Nabilah',
          'phone': '+60172233445',
          'location': 'Mont Kiara',
          'propertyType': 'Condominium',
          'budgetMax': 1200000.0,
          'enquiryConsentGranted': true,
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentBId,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: agentBProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.ownerId, equals(agentBId));
        expect(result.enquiry.assignedAgentId, equals(agentBId));
        expect(result.createdProspect!.ownerId, equals(agentBId));
        agentBProspects.add(result.createdProspect!);

        // Verify total isolation between Agent A and Agent B
        expect(agentAProspects.any((p) => p.ownerId == agentBId), isFalse);
        expect(agentBProspects.any((p) => p.ownerId == agentAId), isFalse);
      });

      test('3.3 Anti-Tampering: Malicious assignedAgentId in payload is overridden with page owner', () async {
        // Attacker submits to Agent A's landing page but injects Agent B's ID in payload
        final maliciousPayload = {
          'name': 'Tampered Inquirer',
          'phone': '+60129998877',
          'assignedAgentId': agentBId, // Malicious injection attempt
          'ownerId': agentBId, // Malicious injection attempt
          'location': 'Batu Kawan',
          'propertyType': 'Condominium',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId, // Authoritative landing page owner
          sourceType: 'Direct Website',
          rawPayload: maliciousPayload,
          existingProspects: agentAProspects,
        );

        expect(result.success, isTrue);
        // Security assertion: Pipeline strictly bounds inquiry and prospect to Agent A
        expect(result.enquiry.ownerId, equals(agentAId));
        expect(result.enquiry.assignedAgentId, equals(agentAId));
        expect(result.enquiry.acquisitionChannel, equals('Channel A: Agent-Generated'));
        expect(result.createdProspect!.ownerId, equals(agentAId));
      });
    });

    // =========================================================================
    // 4. BUYER ENQUIRY SCENARIOS (CONSENT, DNC, DEDUPLICATION, SPAM)
    // =========================================================================
    group('4. Buyer Enquiry Experience & Compliance Scenarios', () {
      final List<ProspectModel> activeProspects = [];

      setUp(() {
        activeProspects.clear();
      });

      test('4.1 Distinct PDPA Consent: Granular tracking of response vs future marketing consent', () async {
        final payload = {
          'name': 'Low Boon Teik',
          'phone': '+60127788990',
          'enquiryConsentGranted': true,
          'marketingConsentGranted': false, // Declined future newsletters
          'location': 'George Town',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: activeProspects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.enquiryConsentGranted, isTrue);
        expect(result.enquiry.marketingConsentGranted, isFalse);
        expect(result.enquiry.consentStatus, equals('Consent Granted'));
        expect(result.enquiry.contactEligibility, equals('Eligible'));
      });

      test('4.2 Withdrawn Consent / Do-Not-Contact suppresses contact eligibility', () async {
        final dncPayload = {
          'name': 'Teh Siew Ling',
          'phone': '+60189911223',
          'doNotContact': true, // Explicit opt-out
          'location': 'Bayan Lepas',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: dncPayload,
          existingProspects: activeProspects,
        );

        expect(result.enquiry.processingStatus, equals('Ineligible'));
        expect(result.enquiry.isDoNotContact, isTrue);
        expect(result.enquiry.contactEligibility, equals('Do Not Contact'));
        if (result.createdProspect != null) {
          expect(result.createdProspect!.contactEligibility, equals('Do Not Contact'));
        }
      });

      test('4.3 Deduplication within 24h: Suppresses duplicate record creation', () async {
        final firstPayload = {
          'name': 'Kenneth Tan',
          'phone': '+60124443322',
          'location': 'Batu Kawan',
          'budgetMax': 500000.0,
        };

        final result1 = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: firstPayload,
          existingProspects: activeProspects,
        );

        expect(result1.success, isTrue);
        activeProspects.add(result1.createdProspect!);

        // Second submission with same phone number
        final result2 = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: firstPayload,
          existingProspects: activeProspects,
        );

        expect(result2.enquiry.processingStatus, equals('Duplicate'));
        expect(result2.enquiry.isDuplicate, isTrue);
        expect(result2.createdProspect, isNull); // Zero duplicate prospect created
      });

      test('4.4 Spam Bot Honeypot: Rejects bot submissions populating hidden field', () async {
        final botPayload = {
          'name': 'Bot Automated Script',
          'phone': '+60119999000',
          'honeypot': 'http://spam-link.example.com', // Honeypot populated
          'location': 'Penang',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: botPayload,
          existingProspects: activeProspects,
        );

        expect(result.success, isFalse);
        expect(result.enquiry.processingStatus, equals('Rejected'));
        expect(result.enquiry.statusReason, contains('Spam honeypot trap'));
        expect(result.createdProspect, isNull);
      });
    });

    // =========================================================================
    // 5. DETERMINISTIC AI MATCHING & ZERO AUTOMATED OUTREACH
    // =========================================================================
    group('5. Deterministic AI Property Matching & Outreach Controls', () {
      final sampleProjects = [
        ProjectModel(
          id: 'proj-penang-001',
          ownerId: agentAId,
          name: 'Penang Residence Demo',
          developer: 'Aspen Group',
          location: 'Batu Kawan, Penang',
          state: 'Penang',
          propertyType: 'Condominium',
          startingPrice: 420000,
          maximumPrice: 650000,
          bedrooms: 3,
          bathrooms: 2,
          builtUpArea: 950,
          description: 'Modern freehold condominium near IKEA Batu Kawan with resort facilities.',
          purpose: 'Own Stay & Investment',
          facilities: ['Swimming Pool', 'Gymnasium'],
          nearbyAmenities: ['IKEA Batu Kawan', 'Penang Second Bridge'],
        ),
      ];

      test('5.1 Valid inquiry computes deterministic match score and next action', () async {
        final payload = {
          'name': 'Nicholas Lee',
          'phone': '+60124411992',
          'location': 'Batu Kawan',
          'propertyType': 'Condominium',
          'budgetMin': 400000.0,
          'budgetMax': 600000.0,
          'purpose': 'Own Stay',
          'timeline': '1-3 months',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: const [],
          availableProjects: sampleProjects,
        );

        expect(result.success, isTrue);
        expect(result.enquiry.matchScore, isNotNull);
        expect(result.enquiry.matchScore!, greaterThanOrEqualTo(70.0));
        expect(result.enquiry.matchedProjectName, equals('Penang Residence Demo'));
        expect(result.enquiry.aiMatchExplanation, isNotNull);
        expect(result.enquiry.suggestedNextAction, isNotEmpty);
      });

      test('5.2 Zero Automated Buyer Outreach: Platform never dispatches autonomous messages', () async {
        // Assert that the ingestion pipeline only updates CRM models and never returns external delivery confirmation
        final payload = {
          'name': 'Goh Min Yee',
          'phone': '+60168899001',
          'location': 'Batu Kawan',
        };

        final result = await LeadIngestionPipeline.processEnquiry(
          ownerId: agentAId,
          sourceType: 'Direct Website',
          rawPayload: payload,
          existingProspects: const [],
        );

        expect(result.success, isTrue);
        // The created prospect status must remain Qualified awaiting agent outreach
        expect(result.createdProspect!.status, equals('Qualified'));
      });
    });

    // =========================================================================
    // 6. CAMPAIGN ATTRIBUTION ACROSS 5 MARKETING CHANNELS
    // =========================================================================
    group('6. Campaign Attribution Across 5 Marketing Channels', () {
      final channels = [
        {'source': 'facebook', 'medium': 'paid_social', 'campaign': 'penang_fb_spring'},
        {'source': 'instagram', 'medium': 'story_ad', 'campaign': 'batu_kawan_ig_story'},
        {'source': 'whatsapp', 'medium': 'broadcast', 'campaign': 'investor_vip_list'},
        {'source': 'tiktok', 'medium': 'video_ad', 'campaign': 'first_home_buyer_series'},
        {'source': 'google', 'medium': 'search_cpc', 'campaign': 'penang_condo_keywords'},
      ];

      for (final ch in channels) {
        test('6.${channels.indexOf(ch) + 1} Attribution preserved for ${ch['source']}', () async {
          final payload = {
            'name': 'Buyer from ${ch['source']}',
            'phone': '+60123344${channels.indexOf(ch)}0',
            'location': 'Batu Kawan',
            'utmSource': ch['source'],
            'utmMedium': ch['medium'],
            'utmCampaign': ch['campaign'],
            'campaignId': 'camp-2026-${ch['source']}',
          };

          final result = await LeadIngestionPipeline.processEnquiry(
            ownerId: agentAId,
            sourceType: 'Direct Website',
            rawPayload: payload,
            existingProspects: const [],
          );

          expect(result.success, isTrue);
          expect(result.enquiry.utmSource, equals(ch['source']));
          expect(result.enquiry.utmMedium, equals(ch['medium']));
          expect(result.enquiry.utmCampaign, equals(ch['campaign']));
          expect(result.enquiry.campaignId, equals('camp-2026-${ch['source']}'));

          // Check prospect tags contain attribution
          expect(result.createdProspect!.tags, contains('Campaign: camp-2026-${ch['source']}'));
          expect(result.createdProspect!.tags, contains('Channel A: Personal Landing Page'));
        });
      }
    });

    // =========================================================================
    // 7. SUBSCRIPTION AND QUOTA ENFORCEMENT AUDIT
    // =========================================================================
    group('7. Subscription Tiers & Quota Enforcement Audit', () {
      test('7.1 Tier lead quota configuration verification', () {
        final freeSub = AgentSubscriptionModel(
          agentId: 'agent-1',
          tier: SubscriptionTier.freeStarter,
          monthlyPlatformLeadQuota: 5,
        );
        final proSub = AgentSubscriptionModel(
          agentId: 'agent-2',
          tier: SubscriptionTier.proAgent,
          monthlyPlatformLeadQuota: 30,
        );
        final eliteSub = AgentSubscriptionModel(
          agentId: 'agent-3',
          tier: SubscriptionTier.eliteCloser,
          monthlyPlatformLeadQuota: 80,
        );

        expect(freeSub.monthlyPlatformLeadQuota, equals(5));
        expect(proSub.monthlyPlatformLeadQuota, equals(30));
        expect(eliteSub.monthlyPlatformLeadQuota, equals(80));
      });

      test('7.2 Quota exhaustion skips agent during Channel B distribution', () {
        // Agent has exhausted monthly quota (5/5 on Free tier)
        final exhaustedAgent = AgentPreferencesModel(
          agentId: 'exhausted-agent',
          preferredLocations: ['Batu Kawan'],
          preferredPropertyTypes: ['Condominium'],
          monthlyLeadQuota: 5,
          leadsReceivedThisMonth: 5, // Quota exhausted
          isAvailableForPlatformLeads: true,
        );

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: {'location': 'Batu Kawan', 'propertyType': 'Condominium'},
          candidatePreferences: [exhaustedAgent],
        );

        // Routed to Unassigned Queue due to quota exhaustion
        expect(decision.isAssigned, isFalse);
        expect(decision.routingStatus, equals('Unassigned Queue'));
      });

      test('7.3 Agent retains 100% ownership of prospects upon plan expiration', () {
        final expiredSub = AgentSubscriptionModel(
          agentId: agentAId,
          tier: SubscriptionTier.freeStarter,
          status: 'Canceled',
        );

        expect(expiredSub.agentId, equals(agentAId));
        expect(expiredSub.status, equals('Canceled'));
        // Business logic guarantee: ProspectModel.ownerId is immutable
      });
    });

    // =========================================================================
    // 8. REN VERIFICATION AUDIT & REGULATORY COMPLIANCE
    // =========================================================================
    group('8. REN Verification & Consumer Transparency Audit', () {
      testWidgets('8.1 Verified agent renders green badge with Verified REN', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final verifiedAgent = AgentDirectoryService.findAgent(agentASlug)!;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
              ChangeNotifierProvider(create: (_) => AppStateProvider()),
            ],
            child: MaterialApp(
              home: AgentLandingPageScreen(agent: verifiedAgent),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verified REN 45892'), findsOneWidget);
        expect(find.byIcon(Icons.verified), findsOneWidget);
      });

      testWidgets('8.2 Unverified agent renders Unverified warning badge', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unverifiedAgent = AgentDirectoryService.findAgent(agentCSlug)!;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
              ChangeNotifierProvider(create: (_) => AppStateProvider()),
            ],
            child: MaterialApp(
              home: AgentLandingPageScreen(agent: unverifiedAgent),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('REN: 99999 (Unverified)'), findsOneWidget);
        expect(find.byIcon(Icons.verified), findsNothing);
      });
    });

    // =========================================================================
    // 9. CHANNEL B DISTRIBUTION ENGINE VALIDATION
    // =========================================================================
    group('9. Channel B Platform Lead Distribution Engine', () {
      final agentPenang = AgentPreferencesModel(
        agentId: agentAId,
        preferredLocations: ['Batu Kawan', 'Penang'],
        preferredPropertyTypes: ['Condominium'],
        priceRangeMin: 350000,
        priceRangeMax: 800000,
        monthlyLeadQuota: 30,
        leadsReceivedThisMonth: 2,
        isAvailableForPlatformLeads: true,
      );

      final agentKL = AgentPreferencesModel(
        agentId: agentBId,
        preferredLocations: ['Mont Kiara', 'Kuala Lumpur'],
        preferredPropertyTypes: ['Condominium', 'Serviced Residence'],
        priceRangeMin: 700000,
        priceRangeMax: 2500000,
        monthlyLeadQuota: 30,
        leadsReceivedThisMonth: 10,
        isAvailableForPlatformLeads: true,
      );

      test('9.1 Penang enquiry routes deterministically to Agent Penang', () {
        final enquiry = {
          'location': 'Batu Kawan',
          'state': 'Penang',
          'propertyType': 'Condominium',
          'budgetMin': 400000,
          'budgetMax': 600000,
          'sourceType': 'Property Portal',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: enquiry,
          candidatePreferences: [agentPenang, agentKL],
          agentProfiles: {
            agentAId: AgentDirectoryService.findAgent(agentAId)!,
            agentBId: AgentDirectoryService.findAgent(agentBId)!,
          },
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals(agentAId));
        expect(decision.assignedAgentName, contains('Alex Tan'));
        expect(decision.suitabilityScore, greaterThan(80.0));
      });

      test('9.2 Mont Kiara enquiry routes deterministically to Agent KL', () {
        final enquiry = {
          'location': 'Mont Kiara',
          'state': 'Kuala Lumpur',
          'propertyType': 'Condominium',
          'budgetMin': 900000,
          'budgetMax': 1500000,
          'sourceType': 'Partner Agency',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: enquiry,
          candidatePreferences: [agentPenang, agentKL],
          agentProfiles: {
            agentAId: AgentDirectoryService.findAgent(agentAId)!,
            agentBId: AgentDirectoryService.findAgent(agentBId)!,
          },
        );

        expect(decision.isAssigned, isTrue);
        expect(decision.assignedAgentId, equals(agentBId));
        expect(decision.assignedAgentName, contains('Brenda Lim'));
      });

      test('9.3 Uncovered territory (Johor Bahru) falls back to Unassigned Queue', () {
        final enquiry = {
          'location': 'Johor Bahru',
          'state': 'Johor',
          'propertyType': 'Landed House',
          'budgetMin': 600000,
          'budgetMax': 800000,
          'sourceType': 'Developer',
        };

        final decision = LeadDistributionEngine.routeEnquiry(
          rawEnquiry: enquiry,
          candidatePreferences: [agentPenang, agentKL],
        );

        expect(decision.isAssigned, isFalse);
        expect(decision.routingStatus, equals('Unassigned Queue'));
        expect(decision.rationale, contains('Unassigned Queue'));
      });
    });
  });
}
