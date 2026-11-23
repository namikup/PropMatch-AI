import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/audience_segment_model.dart';
import 'package:propmatch_ai/models/match_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/services/ai_backend_service.dart';
import 'package:propmatch_ai/services/ai_service.dart';

void main() {
  group('Phase 3.1: AI Backend Service & Fallback Suite', () {
    final testProject = ProjectModel(
      id: 'proj-penang-001',
      ownerId: 'agent-001',
      name: 'The Light Waterfront Suites',
      developer: 'IJM Land',
      location: 'Gelugor',
      state: 'Penang',
      propertyType: 'Condominium',
      startingPrice: 750000,
      maximumPrice: 1200000,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 1100,
      facilities: ['Infinity Pool', 'Gymnasium', 'Tennis Court'],
      nearbyAmenities: ['Penang Bridge', 'Queensbay Mall'],
      description: 'Luxury seafront condominium with panoramic bridge views.',
      purpose: 'Own Stay & Investment',
      status: 'New Launch',
    );

    final testBuyer = BuyerModel(
      id: 'buyer-001',
      ownerId: 'agent-001',
      name: 'Dr. Lim',
      phone: '+60123456789',
      email: 'dr.lim@example.com',
      preferredLocation: 'Gelugor',
      preferredState: 'Penang',
      propertyType: 'Condominium',
      budgetMin: 700000,
      budgetMax: 1000000,
      purchasePurpose: 'Own Stay',
      buyingTimeline: 'Within 3 months',
      leadSource: 'Facebook Ads',
    );

    test('1. LocalRuleBasedAIService generates complete PropertyAnalysisResult', () async {
      const localService = LocalRuleBasedAIService();
      final analysis = await localService.analyzeProperty(testProject);

      expect(analysis.projectSummary, contains('The Light Waterfront Suites'));
      expect(analysis.keySellingPoints.length, greaterThanOrEqualTo(3));
      expect(analysis.potentialBuyerSegments.isNotEmpty, isTrue);
      expect(analysis.competitiveAdvantages.isNotEmpty, isTrue);
      expect(analysis.potentialObjections.isNotEmpty, isTrue);
      expect(analysis.marketingAngles.isNotEmpty, isTrue);
      expect(analysis.model, equals('Local Rule Engine (Fallback)'));
      expect(analysis.isLiveAI, isFalse);
    });

    test('2. LocalRuleBasedAIService discovers audience segments for project', () async {
      const localService = LocalRuleBasedAIService();
      final segments = await localService.discoverAudienceSegments(testProject);

      expect(segments.isNotEmpty, isTrue);
      expect(segments.first.suitabilityScore, greaterThanOrEqualTo(40));
      expect(segments.first.projectId, equals(testProject.id));
    });

    test('3. LocalRuleBasedAIService computes 5-dimension buyer matches correctly', () async {
      const localService = LocalRuleBasedAIService();
      final matches = await localService.matchBuyers(
        project: testProject,
        buyers: [testBuyer],
      );

      expect(matches.length, equals(1));
      final match = matches.first;
      expect(match.overallMatchPercentage, greaterThan(60));
      expect(match.budgetScore, greaterThan(0));
      expect(match.locationScore, greaterThan(0));
      expect(match.buyerId, equals(testBuyer.id));
    });

    test('4. LocalRuleBasedAIService generates multi-channel marketing content', () async {
      const localService = LocalRuleBasedAIService();
      final segment = AudienceSegmentModel(
        projectId: testProject.id,
        ownerId: testProject.ownerId,
        name: 'Young Professionals',
        description: 'Tech commuters',
        interestReason: 'Close to Bayan Lepas',
        budgetCompatibility: 'High',
        propertyPreferences: 'Condo',
        purchasePurpose: 'Own Stay',
        potentialObjections: [],
        recommendedMarketingMessages: [],
        recommendedChannels: ['Facebook'],
        suggestedCallToAction: 'Register Now',
        suitabilityScore: 85,
        rank: 1,
        reasoning: 'Strong fit',
      );

      final content = await localService.generateMarketingContent(
        project: testProject,
        segment: segment,
        channel: 'Facebook Ad',
      );

      expect(content.headlines.isNotEmpty, isTrue);
      expect(content.facebookPost.isNotEmpty, isTrue);
      expect(content.callToActions.isNotEmpty, isTrue);
    });

    test('5. CloudFunctionsAIService safely activates fallback when uninitialized', () async {
      final cloudService = CloudFunctionsAIService(enableFallback: true);

      // Even without initialized Firebase app in unit test, it must not throw and fall back seamlessly
      final analysis = await cloudService.analyzeProperty(testProject);
      expect(analysis.projectSummary, contains(testProject.name));
      expect(analysis.model, equals('Local Rule Engine (Fallback)'));
      expect(analysis.isLiveAI, isFalse);
    });

    test('6. AppStateProvider manages AI service injection and analysis lifecycle', () async {
      final provider = AppStateProvider();
      await provider.addProject(testProject);
      provider.selectProject(testProject);

      expect(provider.currentPropertyAnalysis, isNull);

      // Run property analysis
      await provider.runPropertyAnalysis();
      expect(provider.currentPropertyAnalysis, isNotNull);
      expect(provider.currentPropertyAnalysis!.keySellingPoints.isNotEmpty, isTrue);

      // Run audience discovery
      await provider.runAudienceDiscovery();
      expect(provider.audienceSegments.isNotEmpty, isTrue);

      // Inject custom mock AI service
      var mockInvoked = false;
      provider.setAIService(_MockAIService(() {
        mockInvoked = true;
      }));

      await provider.runPropertyAnalysis();
      expect(mockInvoked, isTrue);
    });

    test('7. AI provenance metadata clearly marks fallback results vs live AI', () async {
      const localService = LocalRuleBasedAIService();
      final analysis = await localService.analyzeProperty(testProject);

      expect(analysis.isLiveAI, isFalse);
      expect(analysis.fallbackReason, contains('local rule-based'));
      expect(analysis.model, contains('Fallback'));

      final segments = await localService.discoverAudienceSegments(testProject);
      expect(segments.first.isLiveAI, isFalse);
      expect(segments.first.generationSource, equals('Rule-based Fallback Engine'));
    });

    test('8. AppStateProvider surfaces AI fallback status and modern model identifier', () async {
      final provider = AppStateProvider();
      expect(provider.currentAIModel, equals('gemini-3.5-flash-lite'));
      expect(provider.isUsingAIFallback, isTrue); // In-memory default uses LocalRuleBasedAIService

      await provider.addProject(testProject);
      provider.selectProject(testProject);
      await provider.runAudienceDiscovery();

      expect(provider.audienceSegments.first.isLiveAI, isFalse);
    });
  });
}

class _MockAIService implements AIBackendService {
  final VoidCallback onInvoke;
  _MockAIService(this.onInvoke);

  @override
  bool get isFallbackActive => false;

  @override
  String? get lastError => null;

  @override
  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId) async => null;

  @override
  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId) async => null;

  @override
  Future<List<MatchModel>?> getCachedMatches(String projectId) async => null;

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false}) async {
    onInvoke();
    return const PropertyAnalysisResult(
      projectSummary: 'Mock analysis',
      keySellingPoints: ['Mock point'],
      potentialBuyerSegments: ['Mock segment'],
      competitiveAdvantages: ['Mock advantage'],
      potentialObjections: ['Mock objection'],
      marketingAngles: ['Mock angle'],
      recommendedPricePositioning: 'Mock positioning',
      analysisConfidence: 'High',
      model: 'mock-engine',
    );
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(
    ProjectModel project, {
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  }) async => [];

  @override
  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
    bool forceRefresh = false,
  }) async => [];

  @override
  Future<SegmentMarketingContent> generateMarketingContent({
    required ProjectModel project,
    required AudienceSegmentModel segment,
    required String channel,
    String language = 'en',
  }) async => SegmentMarketingContent(
    headlines: ['Mock'],
    facebookPost: 'Mock',
    instagramCaption: 'Mock',
    tikTokIdea: 'Mock',
    callToActions: ['Mock'],
  );

  @override
  Future<AIUsageStatsResult?> getUsageStats() async => null;
}
