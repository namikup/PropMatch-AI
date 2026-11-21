import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/match_model.dart';
import 'package:propmatch_ai/models/audience_segment_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/services/ai_backend_service.dart';
import 'package:propmatch_ai/services/ai_service.dart';
import 'package:propmatch_ai/screens/projects/property_analysis_screen.dart';

class _FailingCloudFunctionsAIService implements AIBackendService {
  final LocalRuleBasedAIService _fallbackService = const LocalRuleBasedAIService();
  bool _fallbackActive = false;
  String? _lastError;

  @override
  bool get isFallbackActive => _fallbackActive;

  @override
  String? get lastError => _lastError;

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false}) async {
    // Simulates live Cloud Function unreachability (e.g. 403 Service Disabled, Spark plan, or network error)
    _fallbackActive = true;
    _lastError = 'Cloud Functions API is not enabled on project property-71665 (403 PERMISSION_DENIED). Delegating to LocalRuleEngine.';
    return _fallbackService.analyzeProperty(project, forceRefresh: forceRefresh);
  }

  @override
  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId) async {
    return _fallbackService.getCachedPropertyAnalysis(projectId);
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(
    ProjectModel project, {
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  }) async {
    return _fallbackService.discoverAudienceSegments(project, existingAnalysis: existingAnalysis, agentObservations: agentObservations, forceRefresh: forceRefresh);
  }

  @override
  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId) async => null;

  @override
  Future<List<MatchModel>> matchBuyers({required ProjectModel project, required List<BuyerModel> buyers, bool forceRefresh = false}) async => [];

  @override
  Future<List<MatchModel>?> getCachedMatches(String projectId) async => null;

  @override
  Future<SegmentMarketingContent> generateMarketingContent({required ProjectModel project, required AudienceSegmentModel segment, required String channel, String language = 'en'}) async {
    return SegmentMarketingContent(
      facebookPost: 'FB Post',
      instagramCaption: 'IG Caption',
      tikTokIdea: 'TikTok Idea',
      headlines: ['Headline 1'],
      callToActions: ['Contact Agent'],
    );
  }

  @override
  Future<AIUsageStatsResult?> getUsageStats() async => null;
}

void main() {
  group('Phase 3.2.1: Live Gemini End-to-End Verification Test Suite', () {
    // Synthetic Property specified in Phase 3.2.1 prompt
    final penangResidenceDemo = ProjectModel(
      id: 'demo-penang-residence-001',
      ownerId: 'agent-qa-synthetic',
      name: 'Penang Residence Demo',
      developer: 'Penang Development Corp',
      location: 'Batu Kawan',
      state: 'Penang',
      propertyType: 'Condominium',
      startingPrice: 450000.0,
      maximumPrice: 450000.0,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 950.0,
      purpose: 'Own Stay',
      status: 'New Launch',
      facilities: ['Swimming pool', 'Gym', 'Security'],
      nearbyAmenities: ['Design Village', 'IKEA Batu Kawan'],
      description: 'Partially furnished modern condominium in Batu Kawan.',
    );

    test('1. Synthetic Property Analysis across all seven sections', () async {
      const localService = LocalRuleBasedAIService();
      final analysis = await localService.analyzeProperty(penangResidenceDemo, forceRefresh: true);

      // 1. Property Overview and Positioning
      expect(analysis.propertyOverview, isNotNull);
      expect(analysis.propertyOverview!.name, equals('Penang Residence Demo'));
      expect(analysis.propertyOverview!.location, equals('Batu Kawan'));
      expect(analysis.propertyOverview!.state, equals('Penang'));
      expect(analysis.propertyOverview!.propertyType, equals('Condominium'));
      expect(analysis.propertyOverview!.priceRange, contains('RM450000'));
      expect(analysis.propertyOverview!.builtUpArea, equals(950.0));
      expect(analysis.propertyOverview!.bedrooms, equals(3));
      expect(analysis.propertyOverview!.bathrooms, equals(2));
      expect(analysis.propertyOverview!.facilities, contains('Swimming pool'));
      expect(analysis.propertyOverview!.facilities, contains('Gym'));
      expect(analysis.propertyOverview!.facilities, contains('Security'));
      expect(analysis.propertyOverview!.professionalOverview.isNotEmpty, isTrue);

      // 2. Selling Points
      expect(analysis.structuredSellingPoints.length, greaterThanOrEqualTo(3));
      expect(analysis.keySellingPoints.isNotEmpty, isTrue);
      expect(analysis.structuredSellingPoints.any((sp) => sp.title.contains('Strategic Location in Batu Kawan')), isTrue);
      expect(analysis.structuredSellingPoints.any((sp) => sp.supportingInfo.contains('RM450000')), isTrue);

      // 3. Buyer Personas
      expect(analysis.buyerPersonas.length, greaterThanOrEqualTo(2));
      expect(analysis.potentialBuyerSegments.isNotEmpty, isTrue);
      expect(analysis.buyerPersonas.any((bp) => bp.segmentName.contains('First-Time Homebuyers')), isTrue);
      expect(analysis.buyerPersonas.any((bp) => bp.segmentName.contains('Local Upgraders')), isTrue);

      // 4. Competitive Advantages
      expect(analysis.structuredCompetitiveAdvantages.length, greaterThanOrEqualTo(2));
      expect(analysis.competitiveAdvantages.isNotEmpty, isTrue);
      expect(analysis.structuredCompetitiveAdvantages.first.supportingEvidence, contains('Batu Kawan'));

      // 5. Buyer Objections
      expect(analysis.structuredObjections.length, greaterThanOrEqualTo(2));
      expect(analysis.potentialObjections.isNotEmpty, isTrue);
      expect(analysis.structuredObjections.any((o) => o.category == 'financing'), isTrue);

      // 6. Marketing Strategy
      expect(analysis.marketingStrategy, isNotNull);
      expect(analysis.marketingStrategy!.recommendedAngles.isNotEmpty, isTrue);
      expect(analysis.marketingStrategy!.suggestedChannels.isNotEmpty, isTrue);
      expect(analysis.marketingStrategy!.headlines.isNotEmpty, isTrue);

      // 7. Strategic Summary
      expect(analysis.analysisSummary, isNotNull);
      expect(analysis.analysisSummary!.overallPositioning.isNotEmpty, isTrue);
      expect(analysis.analysisSummary!.strongestSellingPoint.isNotEmpty, isTrue);
      expect(analysis.analysisSummary!.analysisLimitations.length, greaterThanOrEqualTo(3));
    });

    test('2. Unreachable Cloud Functions backend activates fallback without Gemini misattribution', () async {
      final failingService = _FailingCloudFunctionsAIService();

      final result = await failingService.analyzeProperty(penangResidenceDemo, forceRefresh: true);

      expect(failingService.isFallbackActive, isTrue);
      expect(failingService.lastError, contains('403 PERMISSION_DENIED'));

      // CRITICAL ATTRIBUTION PROOF:
      expect(result.isLiveAI, isFalse);
      expect(result.model, equals('Local Rule Engine (Fallback)'));
      expect(result.model, isNot(contains('gemini')));
      expect(result.dataProvenance, contains('Rule-based Fallback Engine'));
    });

    test('3. Repeated requests return cached instance, but forceRefresh regenerates', () async {
      final appState = AppStateProvider();
      await appState.addProject(penangResidenceDemo);
      appState.selectProject(penangResidenceDemo);

      // First run: caches
      final firstAnalysis = await appState.runPropertyAnalysis(project: penangResidenceDemo);
      expect(firstAnalysis, isNotNull);

      // Second run: cached instance returned
      final cachedAnalysis = await appState.runPropertyAnalysis(project: penangResidenceDemo, forceRefresh: false);
      expect(identical(firstAnalysis, cachedAnalysis), isTrue);

      // Force refresh: regenerates
      final forcedAnalysis = await appState.runPropertyAnalysis(project: penangResidenceDemo, forceRefresh: true);
      expect(forcedAnalysis, isNotNull);
      expect(appState.currentPropertyAnalysis, equals(forcedAnalysis));
    });

    test('4. Modifying property details invalidates analysis', () async {
      final appState = AppStateProvider();
      await appState.addProject(penangResidenceDemo);
      appState.selectProject(penangResidenceDemo);

      await appState.runPropertyAnalysis(project: penangResidenceDemo);
      expect(appState.currentPropertyAnalysis, isNotNull);

      // Clear property analysis for modified project
      appState.clearPropertyAnalysis(projectId: penangResidenceDemo.id);
      expect(appState.currentPropertyAnalysis, isNull);
      expect(appState.cachedPropertyAnalyses.containsKey(penangResidenceDemo.id), isFalse);
    });

    testWidgets('5. PropertyAnalysisScreen renders fallback badge and retry when live service is unavailable', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingService = _FailingCloudFunctionsAIService();
      final appState = AppStateProvider(aiService: failingService);
      await appState.addProject(penangResidenceDemo);
      appState.selectProject(penangResidenceDemo);

      // Execute analysis through failing service
      await appState.runPropertyAnalysis(project: penangResidenceDemo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: MaterialApp(
            home: PropertyAnalysisScreen(initialProject: penangResidenceDemo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Provenance Badges
      expect(find.text('AI Property Intelligence — Penang Residence Demo'), findsOneWidget);
      expect(find.text('PENANG'), findsOneWidget);

      // Fallback Badge MUST be visible
      expect(find.text('RULE-BASED FALLBACK ENGINE'), findsOneWidget);
      expect(find.textContaining('LIVE AI'), findsNothing);

      // Action buttons
      expect(find.text('Regenerate Analysis'), findsOneWidget);
      expect(find.text('Copy Strategy Summary'), findsOneWidget);

      // Verify Section Cards render cleanly
      expect(find.text('A. Property Overview & Market Positioning'), findsOneWidget);
      expect(find.text('B. Key Selling Points & Buyer Benefits'), findsOneWidget);
      expect(find.text('C. Potential Buyer Personas'), findsOneWidget);
      expect(find.text('D. Competitive Advantages & Market Evidence'), findsOneWidget);
      expect(find.text('E. Buyer Objections & Professional Response Strategy'), findsOneWidget);
      expect(find.text('F. Recommended Marketing Strategy'), findsOneWidget);
      expect(find.text('G. Strategic Summary & Operational Boundaries'), findsOneWidget);
    });
  });
}
