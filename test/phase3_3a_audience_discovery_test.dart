import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/audience_segment_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/services/ai_backend_service.dart';
import 'package:propmatch_ai/screens/audience/audience_discovery_screen.dart';
import 'package:propmatch_ai/screens/projects/property_analysis_screen.dart';

void main() {
  group('Phase 3.3A: AI Audience Discovery & Market Demand Intelligence Test Suite', () {
    late ProjectModel sampleProject;

    setUp(() {
      sampleProject = ProjectModel(
        id: 'proj-penang-001',
        ownerId: 'demo-agent-001',
        name: 'Penang Bayview Residences',
        location: 'Batu Kawan',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 480000,
        maximumPrice: 650000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1050,
        developer: 'EcoPenang Land',
        status: 'Under Construction',
        purpose: 'Own Stay & Investment',
        description: 'Modern waterfront condominium connected to Batu Kawan Industrial Park.',
        facilities: ['Infinity Pool', 'Gymnasium', 'EV Charging Station', 'Sky Lounge'],
        nearbyAmenities: ['Design Village Mall', 'IKEA Batu Kawan', 'Batu Kawan Hospital'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('1. AudienceSegmentModel serializes and deserializes all Phase 3.3A fields correctly', () {
      final segment = AudienceSegmentModel(
        id: 'seg-test-01',
        projectId: 'proj-penang-001',
        ownerId: 'demo-agent-001',
        name: 'Tech Engineers & Industrial Upgraders',
        description: 'Engineers from Batu Kawan Industrial Park seeking modern apartments.',
        interestReason: 'Close proximity to major MNC manufacturing campuses.',
        budgetCompatibility: 'High: Entry price RM480,000 matches dual-income engineer budget.',
        propertyPreferences: 'Condominium, 3 Bedrooms, modern facilities',
        purchasePurpose: 'Own Stay',
        potentialObjections: ['High management maintenance fees', 'Distance to Penang Island'],
        recommendedMarketingMessages: [
          '5-minute commute to Batu Kawan Industrial Hub',
          'Resort wellness at your doorstep',
        ],
        recommendedChannels: ['Facebook Lead Ads', 'Instagram Carousel'],
        suggestedCallToAction: 'Book Showroom Preview',
        suitabilityScore: 92.0,
        rank: 1,
        reasoning: 'Exceptional geographic and price alignment.',
        appealingFeatures: ['EV Charging Station', 'Infinity Pool', '1050 sqft layout'],
        recommendedContentFormats: ['15s Video Reel', 'Carousel Ad', 'WhatsApp Flyer'],
        evidence: [
          'Project located in Batu Kawan, Penang',
          'Starting price RM480,000',
          '3 Bedrooms, 2 Bathrooms, 1050 sqft',
        ],
        assumptions: [
          'MNC tech workers have combined income of RM9,000+',
          'Proximity to workplace reduces car travel weariness',
        ],
        confidenceLevel: 'High',
        marketDemandDisclaimer: 'AI-generated audience hypothesis — not verified market demand.',
        isCached: true,
        sourceVersion: 'v3.3A-fingerprint-123',
      );

      final map = segment.toMap();
      expect(map['id'], 'seg-test-01');
      expect(map['appealingFeatures'], contains('EV Charging Station'));
      expect(map['recommendedContentFormats'], contains('15s Video Reel'));
      expect(map['evidence'], hasLength(3));
      expect(map['assumptions'], hasLength(2));
      expect(map['confidenceLevel'], 'High');
      expect(map['isCached'], isTrue);
      expect(map['sourceVersion'], 'v3.3A-fingerprint-123');

      // Deserialization
      final restored = AudienceSegmentModel.fromMap(map);
      expect(restored.id, segment.id);
      expect(restored.name, segment.name);
      expect(restored.appealingFeatures, segment.appealingFeatures);
      expect(restored.recommendedContentFormats, segment.recommendedContentFormats);
      expect(restored.evidence, segment.evidence);
      expect(restored.assumptions, segment.assumptions);
      expect(restored.confidenceLevel, 'High');
      expect(restored.isCached, isTrue);

      // Verify getters
      expect(restored.suggestedMessages, segment.recommendedMarketingMessages);
      expect(restored.recommendedPlatforms, segment.recommendedChannels);
      expect(restored.estimatedRelevance, 92.0);
      expect(restored.buyingMotivations, isNotEmpty);
    });

    test('2. LocalRuleBasedAIService generates complete 3.3A audience segments with caching & observations', () async {
      const service = LocalRuleBasedAIService();

      final segments = await service.discoverAudienceSegments(
        sampleProject,
        agentObservations: 'High demand from newly posted doctors at Batu Kawan Hospital.',
        forceRefresh: true,
      );

      expect(segments.length, inInclusiveRange(3, 6));
      final first = segments.first;
      expect(first.evidence, isNotEmpty);
      expect(first.evidence.any((e) => e.contains('Batu Kawan Hospital')), isTrue);
      expect(first.assumptions, isNotEmpty);
      expect(first.appealingFeatures, isNotEmpty);
      expect(first.recommendedContentFormats, isNotEmpty);
      expect(first.confidenceLevel, 'High');
      expect(first.marketDemandDisclaimer, contains('AI-generated audience hypothesis'));

      // Check caching
      final cached = await service.getCachedAudienceSegments(sampleProject.id);
      expect(cached, isNotNull);
      expect(cached!.length, segments.length);
    });

    test('3. AppStateProvider manages audience discovery, caching, and forceRefresh lifecycle', () async {
      final provider = AppStateProvider();
      await provider.addProject(sampleProject);
      provider.selectProject(sampleProject);
      provider.clearAudienceDiscovery(projectId: sampleProject.id);

      expect(provider.audienceSegments, isEmpty);
      expect(provider.isDiscoveringAudience, isFalse);

      // Run audience discovery
      final result = await provider.runAudienceDiscovery(
        project: sampleProject,
        agentObservations: 'Local semiconductor engineers seeking immediate upgrade.',
        forceRefresh: true,
      );

      expect(result, isNotNull);
      expect(provider.audienceSegments, isNotEmpty);
      expect(provider.lastAgentObservations, 'Local semiconductor engineers seeking immediate upgrade.');
      expect(provider.cachedAudienceSegments.containsKey(sampleProject.id), isTrue);

      // Switching projects caches and clears active results
      final anotherProject = ProjectModel(
        id: 'proj-kl-002',
        ownerId: 'demo-agent-001',
        name: 'KL Eco Metropolis',
        location: 'Bangsar South',
        state: 'Kuala Lumpur',
        propertyType: 'Serviced Residence',
        startingPrice: 750000,
        maximumPrice: 1200000,
        bedrooms: 2,
        bathrooms: 2,
        builtUpArea: 850,
        developer: 'Metropolis Dev',
        status: 'Completed',
        purpose: 'Investment',
        description: 'Prime transit-oriented serviced residence.',
        facilities: ['Sky Pool'],
        nearbyAmenities: ['LRT Station'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await provider.addProject(anotherProject);
      provider.selectProject(anotherProject);
      expect(provider.audienceSegments, isEmpty);

      // Switching back restores cached audience segments instantly
      provider.selectProject(sampleProject);
      expect(provider.audienceSegments, isNotEmpty);
      expect(provider.audienceSegments.first.projectId, sampleProject.id);
    });

    testWidgets('4. AudienceDiscoveryScreen renders mandatory disclaimer, overview stats, and segment cards', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = AppStateProvider();
      await provider.addProject(sampleProject);
      provider.selectProject(sampleProject);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: provider),
            ChangeNotifierProvider<NavigationProvider>(create: (_) => NavigationProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AudienceDiscoveryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Mandatory Disclaimer
      expect(find.text('MANDATORY MARKET DEMAND INTELLIGENCE DISCLAIMER'), findsOneWidget);
      expect(find.textContaining('AI-generated audience hypothesis — not verified market demand.'), findsOneWidget);

      // Run Discovery
      await provider.runAudienceDiscovery(project: sampleProject, forceRefresh: true);
      await tester.pumpAndSettle();

      // Check Overview Metrics
      expect(find.text('Discovered Segments'), findsOneWidget);
      expect(find.text('Average Fit Score'), findsOneWidget);

      // Check Action Buttons
      expect(find.text('Market Observations'), findsOneWidget);
      expect(find.text('Compare Segments'), findsOneWidget);
      expect(find.text('Save to Cloud'), findsOneWidget);
      expect(find.text('Copy Brief'), findsWidgets);
    });

    testWidgets('5. PropertyAnalysisScreen includes "Discover Potential Buyers" actions', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = AppStateProvider();
      await provider.addProject(sampleProject);
      provider.selectProject(sampleProject);
      await provider.runPropertyAnalysis(project: sampleProject);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: provider),
            ChangeNotifierProvider<NavigationProvider>(create: (_) => NavigationProvider()),
          ],
          child: MaterialApp(
            home: PropertyAnalysisScreen(initialProject: sampleProject),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Discover Potential Buyers" button in AppBar and Section C
      expect(find.text('Discover Potential Buyers'), findsWidgets);
    });
  });
}
