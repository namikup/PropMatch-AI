import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/property_analysis_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/services/ai_backend_service.dart';
import 'package:propmatch_ai/screens/projects/property_analysis_screen.dart';
import 'package:propmatch_ai/screens/projects/projects_screen.dart';

void main() {
  group('Phase 3.2: AI Property Analysis & Selling Strategy Test Suite', () {
    late ProjectModel sampleProject;
    late ProjectModel incompleteProject;

    setUp(() {
      sampleProject = ProjectModel(
        id: 'proj-penang-001',
        ownerId: 'agent-101',
        name: 'The Light Waterfront Suites',
        developer: 'IJM Land',
        location: 'Gelugor',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 750000.0,
        maximumPrice: 1200000.0,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1100.0,
        purpose: 'Own Stay & High-Yield Investment',
        description: 'Luxury seafront condominium near Penang Bridge.',
        facilities: ['Seafront Infinity Pool', 'EV Charging', 'Gymnasium'],
      );

      incompleteProject = ProjectModel(
        id: 'proj-incomplete-002',
        ownerId: 'agent-101',
        name: '',
        developer: 'Unknown',
        location: '',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 0.0,
        maximumPrice: 0.0,
        bedrooms: 0,
        bathrooms: 0,
        builtUpArea: 0.0,
        purpose: 'Residential',
        description: '',
      );
    });

    test('1. PropertyAnalysisResult serializes and deserializes all 7 structured sections', () {
      final rawMap = {
        'project_summary': 'Comprehensive luxury development in Penang.',
        'property_overview': {
          'name': 'The Light Waterfront Suites',
          'location': 'Gelugor',
          'state': 'Penang',
          'property_type': 'Condominium',
          'price_range': 'RM 750,000 - RM 1,200,000',
          'bedrooms': 3,
          'bathrooms': 2,
          'built_up_area': 1100.0,
          'facilities': ['Seafront Pool', 'Gym'],
          'description': 'Seafront luxury suites',
          'professional_overview': 'High-end executive waterfront residence.',
        },
        'selling_points': [
          {
            'title': 'Prime Seafront Corridor',
            'explanation': 'Unobstructed marine views 5 minutes from Penang Bridge.',
            'supporting_info': 'Project location in Gelugor',
            'buyer_benefit': 'Daily resort ambience with short Bayan Lepas commute',
            'confidence': 'High',
          },
          {
            'title': 'Comprehensive Green Amenities',
            'explanation': 'EV chargers and Olympic-size infinity pool on high deck.',
            'supporting_info': 'EV Charging, Seafront Infinity Pool',
            'buyer_benefit': 'Future-proof living with lower utility footprint',
            'confidence': 'High',
          }
        ],
        'buyer_personas': [
          {
            'segment_name': 'MNC Engineering Executives',
            'description': 'Expatriates and engineers working in Bayan Lepas FTZ.',
            'estimated_relevance': 92.0,
            'buying_motivations': ['Proximity to Bayan Lepas FTZ', 'Modern facilities'],
            'appealing_features': ['Infinity pool', 'EV charging'],
            'potential_objections': ['Traffic on coastal highway during peak hours'],
            'recommended_marketing_angle': 'Cut your daily commute to Bayan Lepas by half.',
          }
        ],
        'competitive_advantages': [
          {
            'advantage': 'Direct Coastal Highway Access',
            'explanation': 'Immediate slip road access to Penang Bridge and George Town.',
            'supporting_evidence': 'Located along Tun Dr Lim Chong Eu Expressway',
            'evidence_status': 'Verified project characteristic',
          }
        ],
        'potential_objections': [
          {
            'objection': 'Price premium vs inland Bayan Baru units',
            'category': 'price',
            'response_strategy': 'Highlight lower density, freehold title, and marine view retention.',
          }
        ],
        'marketing_strategy': {
          'recommended_angles': ['Seafront luxury meets tech corridor convenience'],
          'suitable_audience_segments': ['MNC Tech Managers', 'Penang Upgraders'],
          'suggested_channels': ['Facebook Ads', 'WhatsApp Direct', 'PropertyGuru'],
          'advertisement_headlines': ['Own Penang’s Premier Seafront Address from RM750k'],
          'social_media_ideas': ['Sunset drone tour video across Penang Bridge'],
          'recommended_calls_to_action': ['Schedule Private Showroom VIP Tour'],
        },
        'analysis_summary': {
          'overall_positioning': 'Premium coastal executive suites with sustained capital appreciation.',
          'strongest_selling_point': 'Seafront freehold location 5 mins from bridge.',
          'most_relevant_segment': 'FTZ Engineering Leads & Medical Specialists.',
          'main_potential_objection': 'Entry price point vs non-seafront developments.',
          'recommended_next_action': 'Deploy video ad campaign targeting Bayan Lepas radius.',
          'analysis_limitations': [
            'Analysis synthesized strictly from agent-supplied project parameters.',
            'Competitor comparisons unavailable without external verified data.',
            'Buyer personas represent marketing hypotheses, not verified individual buyer records.'
          ],
        },
        'recommended_price_positioning': 'Premium Tier (Penang Island Waterfront)',
        'analysis_confidence': 'High',
      };

      final result = PropertyAnalysisResult.fromMap(
        rawMap,
        model: 'gemini-2.5-flash',
        latencyMs: 380,
        isLiveAI: true,
      );

      expect(result.isLiveAI, isTrue);
      expect(result.model, equals('gemini-2.5-flash'));
      expect(result.latencyMs, equals(380));
      expect(result.structuredSellingPoints.length, equals(2));
      expect(result.structuredSellingPoints.first.title, equals('Prime Seafront Corridor'));
      expect(result.structuredSellingPoints.first.confidence, equals('High'));

      expect(result.buyerPersonas.length, equals(1));
      expect(result.buyerPersonas.first.segmentName, equals('MNC Engineering Executives'));
      expect(result.buyerPersonas.first.relevanceScore, equals(92.0));

      expect(result.structuredCompetitiveAdvantages.length, equals(1));
      expect(result.structuredCompetitiveAdvantages.first.evidenceStatus, equals('Verified project characteristic'));

      expect(result.structuredObjections.length, equals(1));
      expect(result.structuredObjections.first.category, equals('price'));

      expect(result.marketingStrategy!.headlines.first, contains('Own Penang’s Premier Seafront Address'));
      expect(result.analysisSummary!.strongestSellingPoint, contains('Seafront freehold'));
      expect(result.analysisSummary!.analysisLimitations.length, equals(3));

      // Backwards compatibility getters
      expect(result.keySellingPoints.length, equals(2));
      expect(result.potentialBuyerSegments.first, equals('MNC Engineering Executives'));
      expect(result.competitiveAdvantages.first, equals('Direct Coastal Highway Access'));
      expect(result.potentialObjections.first, equals('Price premium vs inland Bayan Baru units'));
      expect(result.marketingAngles.first, contains('Seafront luxury meets tech corridor'));
    });

    test('2. LocalRuleBasedAIService generates complete 7-section fallback analysis', () async {
      const localService = LocalRuleBasedAIService();
      final analysis = await localService.analyzeProperty(sampleProject);

      expect(analysis.isLiveAI, isFalse);
      expect(analysis.model, equals('Local Rule Engine (Fallback)'));
      expect(analysis.fallbackReason, contains('local rule-based'));
      expect(analysis.propertyOverview, isNotNull);
      expect(analysis.structuredSellingPoints.length, greaterThanOrEqualTo(3));
      expect(analysis.buyerPersonas.length, greaterThanOrEqualTo(2));
      expect(analysis.structuredCompetitiveAdvantages.length, greaterThanOrEqualTo(2));
      expect(analysis.structuredObjections.length, greaterThanOrEqualTo(2));
      expect(analysis.marketingStrategy, isNotNull);
      expect(analysis.marketingStrategy!.suggestedChannels.isNotEmpty, isTrue);
      expect(analysis.analysisSummary, isNotNull);
      expect(analysis.analysisSummary!.analysisLimitations.isNotEmpty, isTrue);
    });

    test('3. AppStateProvider validates required project parameters prior to analysis', () async {
      final appState = AppStateProvider();

      // Attempting to analyze an incomplete project should fail validation
      final error = appState.validateProjectForAnalysis(incompleteProject);
      expect(error, isNotNull);
      expect(error, contains('Project name is required'));

      final priceError = appState.validateProjectForAnalysis(sampleProject.copyWith(startingPrice: 0));
      expect(priceError, contains('starting price (greater than RM 0)'));

      final validCheck = appState.validateProjectForAnalysis(sampleProject);
      expect(validCheck, isNull);

      // Running analysis with incomplete project sets propertyAnalysisError
      final result = await appState.runPropertyAnalysis(project: incompleteProject);
      expect(result, isNull);
      expect(appState.propertyAnalysisError, isNotNull);
      expect(appState.currentPropertyAnalysis, isNull);
    });

    test('4. AppStateProvider handles in-memory caching and forceRefresh regeneration', () async {
      final appState = AppStateProvider();
      await appState.addProject(sampleProject);
      appState.selectProject(sampleProject);

      // First run: executes analysis and populates cache
      expect(appState.cachedPropertyAnalyses.containsKey(sampleProject.id), isFalse);
      final firstAnalysis = await appState.runPropertyAnalysis(project: sampleProject);
      expect(firstAnalysis, isNotNull);
      expect(appState.cachedPropertyAnalyses.containsKey(sampleProject.id), isTrue);
      expect(appState.currentPropertyAnalysis, equals(firstAnalysis));

      // Second run without forceRefresh: returns cached immediately
      final cachedAnalysis = await appState.runPropertyAnalysis(project: sampleProject, forceRefresh: false);
      expect(identical(firstAnalysis, cachedAnalysis), isTrue);

      // Third run with forceRefresh: true regenerates
      final refreshedAnalysis = await appState.runPropertyAnalysis(project: sampleProject, forceRefresh: true);
      expect(refreshedAnalysis, isNotNull);

      // Switching projects updates currentPropertyAnalysis to that project's cache
      final secondProject = sampleProject.copyWith(id: 'proj-002', name: 'Alila Horizon');
      await appState.addProject(secondProject);
      appState.selectProject(secondProject);
      expect(appState.currentPropertyAnalysis, isNull);

      // Switching back restores first project's analysis
      appState.selectProject(sampleProject);
      expect(appState.currentPropertyAnalysis, equals(refreshedAnalysis));
    });

    testWidgets('5. PropertyAnalysisScreen renders all 7 intelligence sections cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppStateProvider();
      await appState.addProject(sampleProject);
      appState.selectProject(sampleProject);

      // Run analysis before pumping screen
      await appState.runPropertyAnalysis(project: sampleProject);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: MaterialApp(
            home: PropertyAnalysisScreen(initialProject: sampleProject),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Provenance Verification
      expect(find.text('AI Property Intelligence — The Light Waterfront Suites'), findsOneWidget);
      expect(find.text('PENANG'), findsOneWidget);
      expect(find.textContaining('RULE-BASED FALLBACK ENGINE'), findsOneWidget);
      expect(find.text('Regenerate Analysis'), findsOneWidget);
      expect(find.text('Copy Strategy Summary'), findsOneWidget);

      // Section A: Overview & Positioning
      expect(find.text('A. Property Overview & Market Positioning'), findsOneWidget);
      expect(find.text('STRATEGIC POSITIONING'), findsOneWidget);

      // Section B: Key Selling Points
      expect(find.text('B. Key Selling Points & Buyer Benefits'), findsOneWidget);

      // Section C: Potential Buyer Personas
      expect(find.text('C. Potential Buyer Personas'), findsOneWidget);

      // Section D: Competitive Advantages & Evidence
      expect(find.text('D. Competitive Advantages & Market Evidence'), findsOneWidget);
      expect(find.textContaining('Competitor comparison unavailable'), findsOneWidget);

      // Section E: Buyer Objections & Response Strategy
      expect(find.text('E. Buyer Objections & Professional Response Strategy'), findsOneWidget);
      expect(find.text('RECOMMENDED AGENT SCRIPT'), findsWidgets);

      // Section F: Recommended Marketing Strategy
      expect(find.text('F. Recommended Marketing Strategy'), findsOneWidget);
      expect(find.text('Campaign Headlines & Taglines:'), findsOneWidget);
      expect(find.text('Suggested Acquisition Channels:'), findsOneWidget);

      // Section G: Strategic Summary & AI Limitations
      expect(find.text('G. Strategic Summary & Operational Boundaries'), findsOneWidget);
      expect(find.text('AI INTELLIGENCE LIMITATIONS & REGULATORY NOTICE'), findsOneWidget);
    });

    testWidgets('6. ProjectsScreen exposes "Analyse Property with AI" and navigates properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppStateProvider();
      await appState.addProject(sampleProject);
      appState.selectProject(sampleProject);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProjectsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the "Analyse Property with AI" button on the project card
      final analyzeBtn = find.text('Analyse Property with AI');
      expect(analyzeBtn, findsWidgets);

      // Ensure button is visible in scrollable viewport and tap it
      await tester.ensureVisible(analyzeBtn.first);
      await tester.pumpAndSettle();
      await tester.tap(analyzeBtn.first);
      await tester.pumpAndSettle();

      // Screen transitions to PropertyAnalysisScreen
      expect(find.byType(PropertyAnalysisScreen), findsOneWidget);
      expect(find.text('AI Property Intelligence — The Light Waterfront Suites'), findsOneWidget);
    });
  });
}
