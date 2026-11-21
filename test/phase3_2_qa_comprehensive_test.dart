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

class _MockLiveAIService implements AIBackendService {
  final PropertyAnalysisResult mockResult;
  _MockLiveAIService(this.mockResult);

  @override
  bool get isFallbackActive => false;
  @override
  String? get lastError => null;

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false}) async => mockResult;

  @override
  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId) async => mockResult;

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(ProjectModel project, {PropertyAnalysisResult? existingAnalysis, String? agentObservations, bool forceRefresh = false}) async => [];

  @override
  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId) async => null;

  @override
  Future<List<MatchModel>> matchBuyers({required ProjectModel project, required List<BuyerModel> buyers, bool forceRefresh = false}) async => [];

  @override
  Future<List<MatchModel>?> getCachedMatches(String projectId) async => null;

  @override
  Future<SegmentMarketingContent> generateMarketingContent({required ProjectModel project, required AudienceSegmentModel segment, required String channel, String language = 'en'}) async {
    return SegmentMarketingContent(
      facebookPost: 'FB',
      instagramCaption: 'IG',
      tikTokIdea: 'TT',
      headlines: ['HL'],
      callToActions: ['CTA'],
    );
  }

  @override
  Future<AIUsageStatsResult?> getUsageStats() async => null;
}

void main() {
  group('Phase 3.2 QA Comprehensive Suite: Functional & AI-Quality Audit', () {
    // -----------------------------------------------------------------------
    // Synthetic Test Cases
    // -----------------------------------------------------------------------

    // Profile 1: Affordable Condominium
    final affordableCondo = ProjectModel(
      id: 'proj-qa-affordable-01',
      ownerId: 'agent-qa-101',
      name: 'Idaman Residensi',
      developer: 'PDC Properties',
      location: 'Batu Kawan',
      state: 'Penang',
      propertyType: 'Condominium',
      startingPrice: 280000.0,
      maximumPrice: 350000.0,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 850.0,
      purpose: 'Own Stay',
      status: 'New Launch',
      facilities: ['Playground', 'Surau', '1 Covered Parking', 'Multipurpose Hall'],
      nearbyAmenities: ['IKEA Batu Kawan', 'Design Village Outlet'],
      description: 'Affordable high-rise development for young families and industrial workers in Batu Kawan.',
    );

    // Profile 2: Luxury Condominium
    final luxuryCondo = ProjectModel(
      id: 'proj-qa-luxury-02',
      ownerId: 'agent-qa-101',
      name: 'The Pavilion Suites',
      developer: 'Pavilion Group',
      location: 'KLCC, Jalan Bukit Bintang',
      state: 'Kuala Lumpur',
      propertyType: 'Condominium',
      startingPrice: 2500000.0,
      maximumPrice: 4800000.0,
      bedrooms: 2,
      bathrooms: 2,
      builtUpArea: 1250.0,
      purpose: 'High-Yield Investment & Luxury Residence',
      status: 'Completed',
      facilities: ['Infinity Sky Pool', 'Private Lift Lobby', 'Valet Parking', 'Sky Lounge & Cigar Bar', 'Concierge'],
      nearbyAmenities: ['Pavilion KL Mall', 'KLCC Park', 'MRT Bukit Bintang'],
      description: 'Ultra-luxury branded residence situated in the heart of Kuala Lumpur Golden Triangle.',
    );

    // Profile 3: Landed Residential Property
    final landedHome = ProjectModel(
      id: 'proj-qa-landed-03',
      ownerId: 'agent-qa-101',
      name: 'Bukit Indah Garden Homes',
      developer: 'SP Setia',
      location: 'Iskandar Puteri',
      state: 'Johor',
      propertyType: '2-Storey Terrace House',
      startingPrice: 850000.0,
      maximumPrice: 1100000.0,
      bedrooms: 4,
      bathrooms: 4,
      builtUpArea: 2400.0,
      purpose: 'Own Stay',
      status: 'Completed',
      facilities: ['Gated and Guarded 24/7', 'Central Linear Park', 'Jogging Track', 'Children Playground'],
      nearbyAmenities: ['Aeon Mall Bukit Indah', 'Columbia Asia Hospital', 'Tuas Second Link'],
      description: 'Freehold landed double-storey terrace home for multigenerational families commuting between Johor and Singapore.',
    );

    // Profile 4: Property with Incomplete Information
    final incompleteProperty = ProjectModel(
      id: 'proj-qa-incomplete-04',
      ownerId: 'agent-qa-101',
      name: 'Green Valley Residensi',
      developer: 'Independent Builder',
      location: 'Rawang',
      state: 'Selangor',
      propertyType: 'Townhouse',
      startingPrice: 420000.0,
      maximumPrice: 0.0,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 1100.0,
      purpose: 'Residential',
      status: 'Under Construction',
      facilities: [],
      nearbyAmenities: [],
      description: '',
    );

    // =========================================================================
    // TEST 1: Property Analysis Accuracy across 4 Synthetic Profiles
    // =========================================================================
    group('Test 1: Property Analysis Accuracy across Profiles', () {
      test('1.1 Affordable Condominium produces all 7 structured sections', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(affordableCondo);

        // Section 1: Overview
        expect(analysis.propertyOverview, isNotNull);
        expect(analysis.propertyOverview!.name, equals('Idaman Residensi'));
        expect(analysis.propertyOverview!.propertyType, equals('Condominium'));
        expect(analysis.propertyOverview!.builtUpArea, equals(850.0));
        expect(analysis.propertyOverview!.bedrooms, equals(3));
        expect(analysis.propertyOverview!.bathrooms, equals(2));

        // Section 2: Selling Points
        expect(analysis.structuredSellingPoints.length, greaterThanOrEqualTo(3));
        expect(analysis.structuredSellingPoints.any((sp) => sp.title.contains('Competitive Entry Pricing')), isTrue);
        expect(analysis.keySellingPoints.isNotEmpty, isTrue);

        // Section 3: Buyer Personas
        expect(analysis.buyerPersonas.length, greaterThanOrEqualTo(2));
        expect(analysis.buyerPersonas.any((bp) => bp.segmentName.contains('First-Time Homebuyers')), isTrue);

        // Section 4: Competitive Advantages
        expect(analysis.structuredCompetitiveAdvantages.length, greaterThanOrEqualTo(2));
        expect(analysis.competitiveAdvantages.isNotEmpty, isTrue);

        // Section 5: Buyer Objections
        expect(analysis.structuredObjections.length, greaterThanOrEqualTo(2));
        expect(analysis.potentialObjections.isNotEmpty, isTrue);

        // Section 6: Marketing Strategy
        expect(analysis.marketingStrategy, isNotNull);
        expect(analysis.marketingStrategy!.recommendedAngles.isNotEmpty, isTrue);
        expect(analysis.marketingStrategy!.suggestedChannels.isNotEmpty, isTrue);
        expect(analysis.marketingStrategy!.headlines.isNotEmpty, isTrue);

        // Section 7: Strategic Summary
        expect(analysis.analysisSummary, isNotNull);
        expect(analysis.analysisSummary!.overallPositioning.isNotEmpty, isTrue);
        expect(analysis.analysisSummary!.strongestSellingPoint.isNotEmpty, isTrue);
        expect(analysis.analysisSummary!.analysisLimitations.isNotEmpty, isTrue);
      });

      test('1.2 Luxury Condominium emphasizes high-end attributes', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(luxuryCondo);

        expect(analysis.propertyOverview!.name, equals('The Pavilion Suites'));
        expect(analysis.propertyOverview!.priceRange, contains('RM2500000'));
        expect(analysis.structuredSellingPoints.any((sp) => sp.supportingInfo.contains('RM2500000')), isTrue);
        // Includes investment persona because purpose includes Investment
        expect(analysis.buyerPersonas.any((bp) => bp.segmentName.contains('Investor')), isTrue);
        expect(analysis.structuredCompetitiveAdvantages.first.advantage, contains('KLCC'));
      });

      test('1.3 Landed Residential Property correctly reflects landed specs', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(landedHome);

        expect(analysis.propertyOverview!.propertyType, equals('2-Storey Terrace House'));
        expect(analysis.propertyOverview!.builtUpArea, equals(2400.0));
        expect(analysis.propertyOverview!.bedrooms, equals(4));
        expect(analysis.structuredSellingPoints.any((sp) => sp.explanation.contains('4 bedrooms')), isTrue);
        expect(analysis.structuredCompetitiveAdvantages.first.supportingEvidence, contains('Iskandar Puteri'));
      });

      test('1.4 Incomplete Property gracefully handles missing data without crashing', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(incompleteProperty);

        expect(analysis.propertyOverview!.name, equals('Green Valley Residensi'));
        expect(analysis.propertyOverview!.facilities.isEmpty, isTrue);
        // Flags missing information explicitly
        expect(analysis.missingInformation, contains('Detailed facility inventory'));
        expect(analysis.missingInformation, contains('Surrounding infrastructure landmarks'));
        expect(analysis.analysisSummary!.analysisLimitations.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // TEST 2: Hallucination and Evidence Guardrails
    // =========================================================================
    group('Test 2: Hallucination and Evidence Guardrails', () {
      test('2.1 Never hallucinates facilities absent from property specifications', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(incompleteProperty);

        // Incomplete property has empty facilities. Analysis overview facilities must be empty!
        expect(analysis.propertyOverview!.facilities.isEmpty, isTrue);

        // Facility selling point should NOT be present when project.facilities is empty
        final hasFacilitySellingPoint = analysis.structuredSellingPoints.any(
          (sp) => sp.title == 'Curated Lifestyle Facilities',
        );
        expect(hasFacilitySellingPoint, isFalse);
      });

      test('2.2 Preserves exact agent-provided specifications without alteration', () async {
        const localService = LocalRuleBasedAIService();
        final analysis = await localService.analyzeProperty(affordableCondo);

        expect(analysis.propertyOverview!.builtUpArea, equals(850.0));
        expect(analysis.propertyOverview!.bedrooms, equals(3));
        expect(analysis.propertyOverview!.bathrooms, equals(2));
        expect(analysis.propertyOverview!.facilities, equals(affordableCondo.facilities));
      });

      test('2.3 Distinguishes verified project facts from marketing hypotheses', () {
        final analysis = PropertyAnalysisResult.fromMap({
          'project_summary': 'Verified test',
          'structured_competitive_advantages': [
            {
              'advantage': 'Highway Access',
              'explanation': 'Direct ramp',
              'supporting_evidence': 'Location: Batu Kawan',
              'evidence_status': 'Verified project characteristic',
            }
          ],
          'buyer_personas': [
            {
              'segment_name': 'Industrial Workers',
              'description': 'Target profile hypothesis',
              'estimated_relevance': 85.0,
            }
          ],
          'analysis_summary': {
            'overall_positioning': 'Market positioning',
            'analysis_limitations': [
              'Analysis synthesized strictly from agent-supplied project parameters.',
              'Competitor comparisons unavailable without external verified data.',
              'Buyer personas represent marketing hypotheses, not verified individual leads.',
            ]
          }
        });

        // Evidence status on advantage is verified
        expect(analysis.structuredCompetitiveAdvantages.first.evidenceStatus, equals('Verified project characteristic'));

        // Limitations explicitly label personas as marketing hypotheses
        expect(
          analysis.analysisSummary!.analysisLimitations.any(
            (l) => l.contains('Buyer personas represent marketing hypotheses'),
          ),
          isTrue,
        );
        expect(
          analysis.analysisSummary!.analysisLimitations.any(
            (l) => l.contains('Competitor comparisons unavailable'),
          ),
          isTrue,
        );
      });
    });

    // =========================================================================
    // TEST 3: Gemini Provider Verification & Fallback Attribution
    // =========================================================================
    group('Test 3: Gemini Provider Verification & Fallback Attribution', () {
      test('3.1 Live AI result accurately tracks provider model, latency, and tokens', () {
        final liveResult = PropertyAnalysisResult.fromMap(
          {
            'project_summary': 'Live AI test result',
            'selling_points': [],
            'buyer_personas': [],
          },
          model: 'gemini-2.5-flash',
          latencyMs: 412,
          isLiveAI: true,
          isCached: false,
        );

        expect(liveResult.isLiveAI, isTrue);
        expect(liveResult.model, equals('gemini-2.5-flash'));
        expect(liveResult.latencyMs, equals(412));
        expect(liveResult.isCached, isFalse);
        expect(liveResult.fallbackReason, isNull);
      });

      test('3.2 Fallback result is NEVER misattributed as Gemini', () async {
        const localService = LocalRuleBasedAIService(customFallbackReason: 'Network unreachable');
        final fallbackResult = await localService.analyzeProperty(affordableCondo, forceRefresh: true);

        // CRITICAL ATTRIBUTION CHECKS
        expect(fallbackResult.isLiveAI, isFalse);
        expect(fallbackResult.model, equals('Local Rule Engine (Fallback)'));
        expect(fallbackResult.model, isNot(contains('gemini')));
        expect(fallbackResult.fallbackReason, equals('Network unreachable'));
        expect(fallbackResult.dataProvenance, contains('Rule-based Fallback Engine'));
      });

      test('3.3 CloudFunctionsAIService routes cleanly to fallback on null functions', () async {
        final cloudService = CloudFunctionsAIService(
          functions: null, // Simulate unavailable backend
        );

        final result = await cloudService.analyzeProperty(affordableCondo);

        expect(cloudService.isFallbackActive, isTrue);
        expect(result.isLiveAI, isFalse);
        expect(result.model, contains('Fallback'));
      });
    });

    // =========================================================================
    // TEST 4: Cache and Refresh Behavior
    // =========================================================================
    group('Test 4: Cache and Refresh Behavior', () {
      test('4.1 Repeated analysis returns identical cached instance', () async {
        final appState = AppStateProvider();
        await appState.addProject(affordableCondo);
        appState.selectProject(affordableCondo);

        // First call
        final firstRun = await appState.runPropertyAnalysis(project: affordableCondo);
        expect(firstRun, isNotNull);

        // Second call (cache hit)
        final secondRun = await appState.runPropertyAnalysis(project: affordableCondo, forceRefresh: false);
        expect(identical(firstRun, secondRun), isTrue);
      });

      test('4.2 forceRefresh: true regenerates analysis', () async {
        final appState = AppStateProvider();
        await appState.addProject(affordableCondo);
        appState.selectProject(affordableCondo);

        final firstRun = await appState.runPropertyAnalysis(project: affordableCondo);
        expect(firstRun, isNotNull);
        final refreshedRun = await appState.runPropertyAnalysis(project: affordableCondo, forceRefresh: true);

        expect(refreshedRun, isNotNull);
        expect(appState.currentPropertyAnalysis, equals(refreshedRun));
      });

      test('4.3 Project switching updates currentPropertyAnalysis to target cache', () async {
        final appState = AppStateProvider();
        await appState.addProject(affordableCondo);
        await appState.addProject(luxuryCondo);

        // Analyze condo 1
        appState.selectProject(affordableCondo);
        await appState.runPropertyAnalysis(project: affordableCondo);
        expect(appState.currentPropertyAnalysis?.propertyOverview?.name, equals('Idaman Residensi'));

        // Switch to condo 2 (not yet analyzed)
        appState.selectProject(luxuryCondo);
        expect(appState.currentPropertyAnalysis, isNull);

        // Analyze condo 2
        await appState.runPropertyAnalysis(project: luxuryCondo);
        expect(appState.currentPropertyAnalysis?.propertyOverview?.name, equals('The Pavilion Suites'));

        // Switch back to condo 1: restored from cache!
        appState.selectProject(affordableCondo);
        expect(appState.currentPropertyAnalysis?.propertyOverview?.name, equals('Idaman Residensi'));
      });
    });

    // =========================================================================
    // TEST 5: User Experience, Validation, & Visual Distinction
    // =========================================================================
    group('Test 5: User Experience & Validation', () {
      test('5.1 Pre-analysis project validation blocks incomplete input', () {
        final appState = AppStateProvider();

        // Empty name
        final nameErr = appState.validateProjectForAnalysis(
          affordableCondo.copyWith(name: '   '),
        );
        expect(nameErr, contains('Project name is required'));

        // Empty location
        final locErr = appState.validateProjectForAnalysis(
          affordableCondo.copyWith(location: ''),
        );
        expect(locErr, contains('Project location is required'));

        // Empty property type
        final typeErr = appState.validateProjectForAnalysis(
          affordableCondo.copyWith(propertyType: ''),
        );
        expect(typeErr, contains('Property type is required'));

        // Zero price
        final priceErr = appState.validateProjectForAnalysis(
          affordableCondo.copyWith(startingPrice: 0.0),
        );
        expect(priceErr, contains('starting price (greater than RM 0)'));
      });

      testWidgets('5.2 UI renders Live AI badge vs Fallback badge cleanly', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final liveAnalysis = PropertyAnalysisResult.fromMap(
          {
            'project_summary': 'Live AI test summary',
            'property_overview': {
              'name': 'Idaman Residensi',
              'location': 'Batu Kawan',
              'state': 'Penang',
              'property_type': 'Condominium',
              'price_range': 'RM280,000 - RM350,000',
              'bedrooms': 3,
              'bathrooms': 2,
              'built_up_area': 850.0,
              'facilities': ['Playground'],
              'description': 'Live description',
              'professional_overview': 'Live overview',
            },
            'selling_points': [
              {
                'title': 'Live Selling Point 1',
                'explanation': 'Live explanation',
                'supporting_info': 'Starting Price RM280k',
                'buyer_benefit': 'Low installment',
                'confidence': 'High',
              }
            ],
            'buyer_personas': [
              {
                'segment_name': 'Live Persona 1',
                'description': 'Live persona description',
                'estimated_relevance': 90.0,
                'buying_motivations': ['Affordable'],
                'appealing_features': ['Playground'],
                'potential_objections': ['Traffic'],
                'recommended_marketing_angle': 'Live marketing angle',
              }
            ],
            'structured_competitive_advantages': [
              {
                'advantage': 'Live Advantage 1',
                'explanation': 'Live explanation',
                'supporting_evidence': 'Live evidence',
                'evidence_status': 'Verified project characteristic',
              }
            ],
            'structured_objections': [
              {
                'objection': 'Live Objection 1',
                'category': 'location',
                'response_strategy': 'Live strategy',
              }
            ],
            'marketing_strategy': {
              'recommended_angles': ['Live Angle 1'],
              'suitable_audience_segments': ['Live Persona 1'],
              'suggested_channels': ['Facebook Ads'],
              'advertisement_headlines': ['Live Headline 1'],
              'social_media_ideas': ['Live idea 1'],
              'recommended_calls_to_action': ['Book Tour'],
            },
            'analysis_summary': {
              'overall_positioning': 'Live positioning',
              'strongest_selling_point': 'Live selling point',
              'most_relevant_segment': 'Live Persona 1',
              'main_potential_objection': 'Live objection',
              'recommended_next_action': 'Live next action',
              'analysis_limitations': [
                'Analysis synthesized strictly from agent-supplied project parameters.',
                'Competitor comparisons unavailable without external verified data.',
                'Buyer personas represent marketing hypotheses, not verified individual leads.',
              ],
            },
          },
          model: 'gemini-2.5-flash',
          latencyMs: 340,
          isLiveAI: true,
          isCached: false,
        );

        final appState = AppStateProvider(
          aiService: _MockLiveAIService(liveAnalysis),
        );
        await appState.addProject(affordableCondo);
        appState.selectProject(affordableCondo);
        await appState.runPropertyAnalysis(project: affordableCondo);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ],
            child: MaterialApp(
              home: PropertyAnalysisScreen(initialProject: affordableCondo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Live AI badge should be present
        expect(find.text('LIVE AI (gemini-2.5-flash)'), findsOneWidget);
        expect(find.text('RULE-BASED FALLBACK ENGINE'), findsNothing);
      });
    });
  });
}
