import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/audience_segment_model.dart';
import '../models/buyer_model.dart';
import '../models/match_model.dart';
import '../models/property_analysis_model.dart';
import 'ai_service.dart';
import 'matching_service.dart';

/// Structured response container for Property Deep-Dive Analysis (Module A - Phase 3.2)
class PropertyAnalysisResult {
  final String projectSummary;
  final List<String> keySellingPoints;
  final List<String> potentialBuyerSegments;
  final List<String> competitiveAdvantages;
  final List<String> potentialObjections;
  final List<String> marketingAngles;
  final String recommendedPricePositioning;
  final String analysisConfidence;
  final String model;
  final int latencyMs;
  final bool isLiveAI;
  final String? fallbackReason;
  final bool isCached;
  final DateTime? _generatedAt;
  DateTime get generatedAt => _generatedAt ?? DateTime.now();

  // Phase 3.2 Rich Structured Components
  final PropertyOverviewData? propertyOverview;
  final List<SellingPointItem> structuredSellingPoints;
  final List<BuyerPersonaItem> buyerPersonas;
  final List<CompetitiveAdvantageItem> structuredCompetitiveAdvantages;
  final List<ObjectionItem> structuredObjections;
  final MarketingStrategyPlan? marketingStrategy;
  final AnalysisSummaryData? analysisSummary;
  final List<String> missingInformation;
  final String dataProvenance;

  const PropertyAnalysisResult({
    required this.projectSummary,
    required this.keySellingPoints,
    required this.potentialBuyerSegments,
    required this.competitiveAdvantages,
    required this.potentialObjections,
    required this.marketingAngles,
    required this.recommendedPricePositioning,
    required this.analysisConfidence,
    this.model = 'Local Rule Engine (Fallback)',
    this.latencyMs = 0,
    this.isLiveAI = false,
    this.fallbackReason,
    this.isCached = false,
    DateTime? generatedAt,
    this.propertyOverview,
    this.structuredSellingPoints = const [],
    this.buyerPersonas = const [],
    this.structuredCompetitiveAdvantages = const [],
    this.structuredObjections = const [],
    this.marketingStrategy,
    this.analysisSummary,
    this.missingInformation = const [],
    this.dataProvenance = 'PropMatch AI Intelligence Engine',
  }) : _generatedAt = generatedAt;

  factory PropertyAnalysisResult.fromMap(
    Map<String, dynamic> map, {
    String model = 'gemini-2.5-flash',
    int latencyMs = 0,
    bool isLiveAI = true,
    String? fallbackReason,
    bool isCached = false,
  }) {
    // 1. Selling points (rich or legacy string list)
    final rawSellingPoints = map['selling_points'] as List<dynamic>?;
    final List<SellingPointItem> structuredSPs = [];
    final List<String> spStrings = [];

    if (rawSellingPoints != null && rawSellingPoints.isNotEmpty) {
      for (final sp in rawSellingPoints) {
        if (sp is Map<String, dynamic>) {
          final item = SellingPointItem.fromMap(sp);
          structuredSPs.add(item);
          spStrings.add(item.title);
        } else if (sp is String) {
          spStrings.add(sp);
          structuredSPs.add(SellingPointItem(
            title: sp,
            explanation: sp,
            supportingInfo: 'Agent-provided project specifications',
            buyerBenefit: 'High alignment with buyer expectations',
          ));
        }
      }
    } else if (map['key_selling_points'] != null) {
      for (final sp in (map['key_selling_points'] as List<dynamic>)) {
        final str = sp.toString();
        spStrings.add(str);
        structuredSPs.add(SellingPointItem(
          title: str,
          explanation: str,
          supportingInfo: 'Agent-provided project specifications',
          buyerBenefit: 'High alignment with buyer expectations',
        ));
      }
    }

    // 2. Buyer personas (rich or legacy string list)
    final rawPersonas = map['buyer_personas'] as List<dynamic>?;
    final List<BuyerPersonaItem> personas = [];
    final List<String> personaStrings = [];

    if (rawPersonas != null && rawPersonas.isNotEmpty) {
      for (final p in rawPersonas) {
        if (p is Map<String, dynamic>) {
          final item = BuyerPersonaItem.fromMap(p);
          personas.add(item);
          personaStrings.add(item.segmentName);
        }
      }
    } else if (map['potential_buyer_segments'] != null) {
      for (final s in (map['potential_buyer_segments'] as List<dynamic>)) {
        final str = s.toString();
        personaStrings.add(str);
        personas.add(BuyerPersonaItem(
          segmentName: str,
          description: 'Target demographic identified through property positioning analysis.',
          estimatedRelevance: 75,
          buyingMotivations: ['Quality lifestyle', 'Value for money'],
          appealingFeatures: ['Strategic location', 'Modern layout'],
          potentialObjections: ['Budget evaluation'],
          recommendedMarketingAngle: 'Focus on primary lifestyle benefits.',
        ));
      }
    }

    // 3. Competitive advantages
    final rawAdv = (map['structured_competitive_advantages'] ?? map['competitive_advantages']) as List<dynamic>?;
    final List<CompetitiveAdvantageItem> advList = [];
    final List<String> advStrings = [];

    if (rawAdv != null && rawAdv.isNotEmpty) {
      for (final a in rawAdv) {
        if (a is Map<String, dynamic>) {
          final item = CompetitiveAdvantageItem.fromMap(a);
          advList.add(item);
          advStrings.add(item.advantage);
        } else {
          final str = a.toString();
          advStrings.add(str);
          advList.add(CompetitiveAdvantageItem(
            advantage: str,
            explanation: str,
            supportingEvidence: 'Agent-provided specifications',
            evidenceStatus: 'Verified project characteristic',
          ));
        }
      }
    }

    // 4. Objections
    final rawObj = (map['structured_objections'] ?? map['potential_objections']) as List<dynamic>?;
    final List<ObjectionItem> objList = [];
    final List<String> objStrings = [];

    if (rawObj != null && rawObj.isNotEmpty) {
      for (final o in rawObj) {
        if (o is Map<String, dynamic>) {
          final item = ObjectionItem.fromMap(o);
          objList.add(item);
          objStrings.add(item.objection);
        } else {
          final str = o.toString();
          objStrings.add(str);
          objList.add(ObjectionItem(
            objection: str,
            category: 'general',
            responseStrategy: 'Present value proposition and arrange private viewing.',
          ));
        }
      }
    }

    // 5. Marketing Strategy
    MarketingStrategyPlan? mktPlan;
    final List<String> mktAngles = [];
    if (map['marketing_strategy'] is Map<String, dynamic>) {
      mktPlan = MarketingStrategyPlan.fromMap(map['marketing_strategy'] as Map<String, dynamic>);
      mktAngles.addAll(mktPlan.recommendedAngles);
    } else if (map['marketing_angles'] != null) {
      mktAngles.addAll(List<String>.from(map['marketing_angles']));
      mktPlan = MarketingStrategyPlan(
        recommendedAngles: mktAngles,
        suitableAudienceSegments: personaStrings,
        suggestedChannels: ['Facebook Lead Ads', 'Instagram Reels', 'Private Showroom Preview'],
        advertisementHeadlines: mktAngles,
        socialMediaIdeas: ['Showcase unique architectural features and lifestyle appeal.'],
        recommendedCallsToAction: ['Schedule Viewing', 'Download Floor Plan'],
      );
    }

    // 6. Analysis Summary
    AnalysisSummaryData? summaryData;
    if (map['analysis_summary'] is Map<String, dynamic>) {
      summaryData = AnalysisSummaryData.fromMap(map['analysis_summary'] as Map<String, dynamic>);
    } else {
      summaryData = AnalysisSummaryData(
        overallPositioning: map['recommended_price_positioning']?.toString() ?? 'Strategic regional positioning.',
        strongestSellingPoint: spStrings.isNotEmpty ? spStrings.first : 'Strategic location and layout.',
        mostRelevantSegment: personaStrings.isNotEmpty ? personaStrings.first : 'First-time buyers & upgraders.',
        mainPotentialObjection: objStrings.isNotEmpty ? objStrings.first : 'Price comparison vs surrounding market.',
        recommendedNextAction: 'Initiate targeted digital campaign and showroom previews.',
        analysisLimitations: [
          'Analysis synthesized strictly from agent-supplied project parameters.',
          'Competitor comparisons unavailable without verified external data.',
          'Buyer personas represent marketing hypotheses, not verified individual leads.',
        ],
      );
    }

    // 7. Property Overview
    PropertyOverviewData? overview;
    if (map['property_overview'] is Map<String, dynamic>) {
      overview = PropertyOverviewData.fromMap(map['property_overview'] as Map<String, dynamic>);
    }

    return PropertyAnalysisResult(
      projectSummary: map['project_summary']?.toString() ?? 'Summary unavailable',
      keySellingPoints: spStrings,
      potentialBuyerSegments: personaStrings,
      competitiveAdvantages: advStrings,
      potentialObjections: objStrings,
      marketingAngles: mktAngles,
      recommendedPricePositioning: map['recommended_price_positioning']?.toString() ?? 'Market standard',
      analysisConfidence: map['analysis_confidence']?.toString() ?? 'Medium',
      model: model,
      latencyMs: latencyMs,
      isLiveAI: isLiveAI,
      fallbackReason: fallbackReason,
      isCached: isCached || (map['is_cached'] as bool? ?? false),
      generatedAt: map['generated_at'] != null ? DateTime.tryParse(map['generated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      propertyOverview: overview,
      structuredSellingPoints: structuredSPs,
      buyerPersonas: personas,
      structuredCompetitiveAdvantages: advList,
      structuredObjections: objList,
      marketingStrategy: mktPlan,
      analysisSummary: summaryData,
      missingInformation: List<String>.from(map['missing_information'] ?? []),
      dataProvenance: map['data_provenance']?.toString() ?? (isLiveAI ? 'Google Gen AI (@google/genai) Analysis' : 'Local Rule Engine (Fallback)'),
    );
  }

  Map<String, dynamic> toMap() => {
        'project_summary': projectSummary,
        'key_selling_points': keySellingPoints,
        'potential_buyer_segments': potentialBuyerSegments,
        'competitive_advantages': competitiveAdvantages,
        'potential_objections': potentialObjections,
        'marketing_angles': marketingAngles,
        'recommended_price_positioning': recommendedPricePositioning,
        'analysis_confidence': analysisConfidence,
        'model': model,
        'latency_ms': latencyMs,
        'is_live_ai': isLiveAI,
        'fallback_reason': fallbackReason,
        'is_cached': isCached,
        'generated_at': generatedAt.toIso8601String(),
        if (propertyOverview != null) 'property_overview': propertyOverview!.toMap(),
        'selling_points': structuredSellingPoints.map((s) => s.toMap()).toList(),
        'buyer_personas': buyerPersonas.map((p) => p.toMap()).toList(),
        'structured_competitive_advantages': structuredCompetitiveAdvantages.map((a) => a.toMap()).toList(),
        'structured_objections': structuredObjections.map((o) => o.toMap()).toList(),
        if (marketingStrategy != null) 'marketing_strategy': marketingStrategy!.toMap(),
        if (analysisSummary != null) 'analysis_summary': analysisSummary!.toMap(),
        'missing_information': missingInformation,
        'data_provenance': dataProvenance,
      };
}

/// Agent Quota and AI Usage Statistics
class AIUsageStatsResult {
  final int currentMonthRequests;
  final int monthlyQuota;
  final int remainingRequests;
  final bool isAllowed;
  final Map<String, int> usageByFeature;

  const AIUsageStatsResult({
    required this.currentMonthRequests,
    required this.monthlyQuota,
    required this.remainingRequests,
    required this.isAllowed,
    required this.usageByFeature,
  });

  factory AIUsageStatsResult.fromMap(Map<String, dynamic> map) {
    final quota = map['quota'] as Map<String, dynamic>? ?? {};
    final usage = map['usageByFeature'] as Map<String, dynamic>? ?? {};

    return AIUsageStatsResult(
      currentMonthRequests: (quota['currentMonthRequests'] as num?)?.toInt() ?? 0,
      monthlyQuota: (quota['monthlyQuota'] as num?)?.toInt() ?? 500,
      remainingRequests: (quota['remainingRequests'] as num?)?.toInt() ?? 500,
      isAllowed: quota['isAllowed'] as bool? ?? true,
      usageByFeature: usage.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}

/// Core interface for AI intelligence operations in PropMatch AI.
abstract class AIBackendService {
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false});

  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId);

  Future<List<AudienceSegmentModel>> discoverAudienceSegments(
    ProjectModel project, {
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  });

  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId);

  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
    bool forceRefresh = false,
  });

  Future<List<MatchModel>?> getCachedMatches(String projectId);

  Future<SegmentMarketingContent> generateMarketingContent({
    required ProjectModel project,
    required AudienceSegmentModel segment,
    required String channel,
    String language = 'en',
  });

  Future<AIUsageStatsResult?> getUsageStats();

  /// Data provenance indicator
  bool get isFallbackActive;
  String? get lastError;
}

/// Local rule-based AI service implementation.
/// Used for demo mode, unit testing, and graceful offline fallback.
class LocalRuleBasedAIService implements AIBackendService {
  final String? customFallbackReason;
  static final Map<String, PropertyAnalysisResult> _localCache = {};
  static final Map<String, List<AudienceSegmentModel>> _localAudienceCache = {};
  static final Map<String, List<MatchModel>> _localMatchCache = {};

  const LocalRuleBasedAIService({this.customFallbackReason});

  @override
  bool get isFallbackActive => true;

  @override
  String? get lastError => customFallbackReason;

  @override
  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId) async {
    return _localCache[projectId];
  }

  @override
  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId) async {
    return _localAudienceCache[projectId];
  }

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false}) async {
    if (!forceRefresh && _localCache.containsKey(project.id)) {
      return _localCache[project.id]!;
    }

    final sellingPoints = <SellingPointItem>[
      SellingPointItem(
        title: 'Strategic Location in ${project.location}',
        explanation: 'Prime position in ${project.location}, ${project.state} providing excellent road connectivity.',
        supportingInfo: 'Location: ${project.location}, State: ${project.state}',
        buyerBenefit: 'Reduced daily commuting time and stable long-term capital preservation.',
        confidence: 'High',
      ),
      SellingPointItem(
        title: 'Competitive Entry Pricing',
        explanation: 'Priced from RM${project.startingPrice.toStringAsFixed(0)} to RM${project.maximumPrice.toStringAsFixed(0)} for ${project.propertyType}.',
        supportingInfo: 'Agent-supplied price range: RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}',
        buyerBenefit: 'Lower initial cash outlay and accessible loan installment financing.',
        confidence: 'High',
      ),
      SellingPointItem(
        title: 'Functional ${project.builtUpArea.toStringAsFixed(0)} sqft Layout',
        explanation: '${project.bedrooms} bedrooms & ${project.bathrooms} bathrooms optimized for modern families.',
        supportingInfo: '${project.builtUpArea.toStringAsFixed(0)} sqft, ${project.bedrooms} Beds, ${project.bathrooms} Baths',
        buyerBenefit: 'Comfortable living spaces with versatile work-from-home or family zones.',
        confidence: 'High',
      ),
      if (project.facilities.isNotEmpty)
        SellingPointItem(
          title: 'Curated Lifestyle Facilities',
          explanation: 'Includes ${project.facilities.take(3).join(', ')} for resident wellness.',
          supportingInfo: 'Facilities: ${project.facilities.join(', ')}',
          buyerBenefit: 'Comprehensive on-site recreation without external club memberships.',
          confidence: 'Medium',
        ),
    ];

    final personas = <BuyerPersonaItem>[
      BuyerPersonaItem(
        segmentName: 'First-Time Homebuyers & Young Families',
        description: 'Professionals seeking their first modern home with accessible financing.',
        estimatedRelevance: 88,
        buyingMotivations: ['Homeownership milestone', 'Family growth', 'Quality security'],
        appealingFeatures: ['Affordable entry pricing', '${project.bedrooms} Bedrooms layout'],
        potentialObjections: ['Financing approval criteria', 'Downpayment adequacy'],
        recommendedMarketingAngle: 'Own a modern ${project.propertyType} with manageable monthly installments.',
      ),
      BuyerPersonaItem(
        segmentName: 'Local Upgraders seeking Modern Amenities',
        description: 'Residents living in older surrounding developments wanting contemporary facilities.',
        estimatedRelevance: 82,
        buyingMotivations: ['Upgraded lifestyle', 'Modern security', 'Better facilities'],
        appealingFeatures: project.facilities.isNotEmpty ? project.facilities : ['Security', 'Pool'],
        potentialObjections: ['Monthly maintenance fee impact'],
        recommendedMarketingAngle: 'Upgrade your family lifestyle with resort amenities in ${project.location}.',
      ),
      if (project.purpose.contains('Investment'))
        BuyerPersonaItem(
          segmentName: 'Rental Yield & Capital Appreciation Investors',
          description: 'Experienced real estate investors looking for tenant demand corridors.',
          estimatedRelevance: 78,
          buyingMotivations: ['Rental cash flow', 'Long-term equity buildup'],
          appealingFeatures: ['Proximity to regional hubs', 'Tenant-friendly layout'],
          potentialObjections: ['Surrounding rental competition'],
          recommendedMarketingAngle: 'High-appeal tenant format in thriving ${project.location}.',
        ),
    ];

    final advantages = <CompetitiveAdvantageItem>[
      CompetitiveAdvantageItem(
        advantage: 'Infrastructure Connectivity in ${project.location}',
        explanation: 'Immediate access to primary state expressways and transportation routes.',
        supportingEvidence: 'Agent-provided location: ${project.location}, ${project.state}',
        evidenceStatus: 'Verified project characteristic',
      ),
      CompetitiveAdvantageItem(
        advantage: 'Integrated Residential Facilities',
        explanation: 'Comprehensive facilities catering to active lifestyles.',
        supportingEvidence: project.facilities.isNotEmpty ? project.facilities.join(', ') : 'Standard infrastructure',
        evidenceStatus: 'Agent-provided feature',
      ),
    ];

    final objections = <ObjectionItem>[
      ObjectionItem(
        objection: 'Concerns over surrounding development density or competition',
        category: 'location',
        responseStrategy: 'Highlight unique project facilities, developer build quality, and layout efficiency.',
      ),
      ObjectionItem(
        objection: 'Buyer uncertainty on monthly installment affordability',
        category: 'financing',
        responseStrategy: 'Provide tailored mortgage package comparisons and step-by-step loan eligibility assessment.',
      ),
    ];

    final mktStrategy = MarketingStrategyPlan(
      recommendedAngles: [
        'Spacious family sanctuary with direct highway accessibility in ${project.location}',
        'Exceptional entry price for a ${project.propertyType} in ${project.state}',
        'Contemporary facilities designed for family wellness and security',
      ],
      suitableAudienceSegments: personas.map((p) => p.segmentName).toList(),
      suggestedChannels: ['Facebook Lead Ads', 'Instagram Reels Walkthrough', 'Private Showroom Preview'],
      advertisementHeadlines: [
        'Exclusive Launch: ${project.name} in ${project.location}',
        'From RM${project.startingPrice.toStringAsFixed(0)}: Your Ideal ${project.propertyType}',
        'Spacious ${project.bedrooms}-Bedroom Living at ${project.name}',
      ],
      socialMediaIdeas: [
        'Video tour highlighting ${project.builtUpArea.toStringAsFixed(0)} sqft spacious living room.',
        'Carousel showing facilities: ${project.facilities.take(4).join(', ')}.',
      ],
      recommendedCallsToAction: [
        'Register for Priority Showroom Preview',
        'Download Complete Floor Plan Brochure',
      ],
    );

    final summary = AnalysisSummaryData(
      overallPositioning: 'Priced competitively within the median ${project.propertyType} segment in ${project.state}.',
      strongestSellingPoint: 'Prime road connectivity and accessible pricing starting from RM${project.startingPrice.toStringAsFixed(0)}.',
      mostRelevantSegment: 'First-time homebuyers and local upgraders.',
      mainPotentialObjection: 'Financing qualification and surrounding project competition.',
      recommendedNextAction: 'Distribute targeted social campaigns and invite qualified pre-registered leads to showroom open house.',
      analysisLimitations: [
        'Analysis synthesized from local rule-based fallback heuristics.',
        'Competitor market comparisons unavailable without external verified data.',
        'Buyer personas represent marketing hypotheses, not verified individual leads.',
      ],
    );

    final overview = PropertyOverviewData(
      name: project.name,
      location: project.location,
      state: project.state,
      propertyType: project.propertyType,
      priceRange: 'RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}',
      bedrooms: project.bedrooms,
      bathrooms: project.bathrooms,
      builtUpArea: project.builtUpArea,
      facilities: project.facilities,
      description: project.description,
      professionalOverview: '${project.name} by ${project.developer} is a ${project.status} ${project.propertyType} in ${project.location}, tailored for ${project.purpose.toLowerCase()}.',
    );

    final result = PropertyAnalysisResult(
      projectSummary: overview.professionalOverview,
      keySellingPoints: sellingPoints.map((s) => s.title).toList(),
      potentialBuyerSegments: personas.map((p) => p.segmentName).toList(),
      competitiveAdvantages: advantages.map((a) => a.advantage).toList(),
      potentialObjections: objections.map((o) => o.objection).toList(),
      marketingAngles: mktStrategy.recommendedAngles,
      recommendedPricePositioning: summary.overallPositioning,
      analysisConfidence: 'High',
      model: 'Local Rule Engine (Fallback)',
      latencyMs: 15,
      isLiveAI: false,
      fallbackReason: customFallbackReason ?? 'Operating in local rule-based engine',
      isCached: false,
      generatedAt: DateTime.now(),
      propertyOverview: overview,
      structuredSellingPoints: sellingPoints,
      buyerPersonas: personas,
      structuredCompetitiveAdvantages: advantages,
      structuredObjections: objections,
      marketingStrategy: mktStrategy,
      analysisSummary: summary,
      missingInformation: [
        if (project.facilities.isEmpty) 'Detailed facility inventory',
        if (project.nearbyAmenities.isEmpty) 'Surrounding infrastructure landmarks',
      ],
      dataProvenance: 'Rule-based Fallback Engine (Local Heuristics)',
    );

    _localCache[project.id] = result;
    return result;
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(
    ProjectModel project, {
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _localAudienceCache.containsKey(project.id)) {
      return _localAudienceCache[project.id]!;
    }

    final segments = AIService.discoverAudienceSegments(project).take(5).toList();
    final results = segments.map((s) {
      final ev = <String>[
        'Property located in ${project.location}, ${project.state}',
        'Entry pricing: RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}',
        'Unit specification: ${project.bedrooms} Beds, ${project.bathrooms} Baths, ${project.builtUpArea.toStringAsFixed(0)} sqft',
        if (project.facilities.isNotEmpty) 'Facilities: ${project.facilities.take(3).join(', ')}',
        if (agentObservations != null && agentObservations.trim().isNotEmpty)
          'Agent market observation: $agentObservations',
      ];
      final assump = <String>[
        'Target group has sufficient debt service ratio for RM${project.startingPrice.toStringAsFixed(0)} purchase',
        'Buyers prioritize connectivity and modern layout amenities',
      ];
      final features = <String>[
        'Strategic location in ${project.location}',
        'Functional ${project.builtUpArea.toStringAsFixed(0)} sqft layout',
        if (project.facilities.isNotEmpty) ...project.facilities.take(3),
      ];
      final formats = <String>[
        '15s Video Reel / Walkthrough',
        'Carousel Ad highlighting layout & facilities',
        'WhatsApp PDF One-Pager Brochure',
      ];

      return AudienceSegmentModel(
        id: s.id,
        projectId: s.projectId,
        ownerId: s.ownerId,
        name: s.name,
        description: s.description,
        interestReason: s.interestReason,
        budgetCompatibility: s.budgetCompatibility,
        propertyPreferences: s.propertyPreferences,
        purchasePurpose: s.purchasePurpose,
        potentialObjections: s.potentialObjections,
        recommendedMarketingMessages: s.recommendedMarketingMessages,
        recommendedChannels: s.recommendedChannels,
        suggestedCallToAction: s.suggestedCallToAction,
        suitabilityScore: s.suitabilityScore,
        rank: s.rank,
        reasoning: s.reasoning,
        marketingAngle: s.marketingAngle,
        scoringFactors: s.scoringFactors,
        ageRange: s.ageRange,
        incomeRange: s.incomeRange,
        geographicTargets: s.geographicTargets,
        missingInformation: s.missingInformation,
        matchingPropertyCharacteristics: features,
        demographicDisclaimer: s.demographicDisclaimer,
        isLiveAI: false,
        generationSource: 'Rule-based Fallback Engine',
        fallbackReason: customFallbackReason ?? 'Operating in local rule-based engine',
        appealingFeatures: features,
        recommendedContentFormats: formats,
        evidence: ev,
        assumptions: assump,
        confidenceLevel: 'High',
        marketDemandDisclaimer: 'AI-generated audience hypothesis — not verified market demand.',
        isCached: false,
        sourceVersion: 'v3.3A-local',
        createdAt: s.createdAt,
      );
    }).toList();

    _localAudienceCache[project.id] = results;
    return results;
  }

  @override
  Future<List<MatchModel>?> getCachedMatches(String projectId) async {
    return _localMatchCache[projectId];
  }

  @override
  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _localMatchCache.containsKey(project.id)) {
      return _localMatchCache[project.id]!;
    }

    final matches = MatchingService.matchBuyersWithProject(
      buyers: buyers,
      project: project,
    );
    _localMatchCache[project.id] = matches;
    return matches;
  }

  @override
  Future<SegmentMarketingContent> generateMarketingContent({
    required ProjectModel project,
    required AudienceSegmentModel segment,
    required String channel,
    String language = 'en',
  }) async {
    return AIService.generateSegmentMarketingContent(project, segment);
  }

  @override
  Future<AIUsageStatsResult?> getUsageStats() async {
    return const AIUsageStatsResult(
      currentMonthRequests: 0,
      monthlyQuota: 500,
      remainingRequests: 500,
      isAllowed: true,
      usageByFeature: {},
    );
  }
}

/// Production Cloud Functions AI service connecting to Firebase & Gemini API.
/// If Cloud Functions are unavailable or in demo mode, automatically falls back
/// to LocalRuleBasedAIService while explicitly logging provenance metadata.
class CloudFunctionsAIService implements AIBackendService {
  final FirebaseFunctions? _customFunctions;
  final LocalRuleBasedAIService _fallbackService;
  final bool enableFallback;

  bool _isFallbackActive = false;
  String? _lastError;

  CloudFunctionsAIService({
    FirebaseFunctions? functions,
    LocalRuleBasedAIService? fallbackService,
    this.enableFallback = true,
  })  : _customFunctions = functions,
        _fallbackService = fallbackService ?? const LocalRuleBasedAIService();

  @override
  bool get isFallbackActive => _isFallbackActive;

  @override
  String? get lastError => _lastError;

  FirebaseFunctions? get _functions {
    if (_customFunctions != null) return _customFunctions;
    try {
      return FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] Firebase not initialized: $e');
      }
      return null;
    }
  }

  @override
  Future<PropertyAnalysisResult?> getCachedPropertyAnalysis(String projectId) async {
    final functions = _functions;
    if (functions == null) {
      return _fallbackService.getCachedPropertyAnalysis(projectId);
    }

    try {
      final callable = functions.httpsCallable('getPropertyAnalysis');
      final result = await callable.call<Map<String, dynamic>>({
        'projectId': projectId,
      });

      final data = result.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};
      return PropertyAnalysisResult.fromMap(
        data,
        model: meta['model']?.toString() ?? 'gemini-2.5-flash',
        latencyMs: 5,
        isLiveAI: true,
        isCached: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] getCachedPropertyAnalysis error: $e');
      }
      return _fallbackService.getCachedPropertyAnalysis(projectId);
    }
  }

  @override
  Future<List<AudienceSegmentModel>?> getCachedAudienceSegments(String projectId) async {
    final functions = _functions;
    if (functions == null) {
      return _fallbackService.getCachedAudienceSegments(projectId);
    }

    try {
      final callable = functions.httpsCallable('getAudienceSegments');
      final result = await callable.call<Map<String, dynamic>>({
        'projectId': projectId,
      });

      final data = result.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final rawSegments = data['audience_segments'] as List<dynamic>? ?? [];
      if (rawSegments.isEmpty) return null;

      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};
      final isCached = meta['cached'] as bool? ?? true;
      final modelName = meta['model']?.toString() ?? 'gemini-2.5-flash';

      final segments = <AudienceSegmentModel>[];
      for (int i = 0; i < rawSegments.length; i++) {
        final item = rawSegments[i] as Map<String, dynamic>;
        segments.add(AudienceSegmentModel.fromMap({
          ...item,
          'projectId': projectId,
          'is_live_ai': true,
          'model': modelName,
          'isCached': isCached,
        }));
      }
      return segments;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] getCachedAudienceSegments error: $e');
      }
      return _fallbackService.getCachedAudienceSegments(projectId);
    }
  }

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project, {bool forceRefresh = false}) async {
    final functions = _functions;
    if (functions == null) {
      _isFallbackActive = true;
      _lastError = 'Firebase Functions not initialized. Using offline rule engine.';
      return _fallbackService.analyzeProperty(project, forceRefresh: forceRefresh);
    }

    try {
      final callable = functions.httpsCallable('analyzeProperty');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
        'forceRefresh': forceRefresh,
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};

      _isFallbackActive = false;
      _lastError = null;

      return PropertyAnalysisResult.fromMap(
        data,
        model: meta['model']?.toString() ?? 'gemini-2.5-flash',
        latencyMs: (meta['latencyMs'] as num?)?.toInt() ?? 0,
        isLiveAI: true,
        isCached: meta['cached'] as bool? ?? false,
      );
    } catch (e) {
      _isFallbackActive = true;
      _lastError = 'Live AI error: $e';
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] analyzeProperty fallback activated: $e');
      }
      if (enableFallback) {
        return _fallbackService.analyzeProperty(project, forceRefresh: forceRefresh);
      }
      rethrow;
    }
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(
    ProjectModel project, {
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  }) async {
    final functions = _functions;
    if (functions == null) {
      _isFallbackActive = true;
      _lastError = 'Firebase Functions not initialized. Using offline rule engine.';
      return _fallbackService.discoverAudienceSegments(
        project,
        existingAnalysis: existingAnalysis,
        agentObservations: agentObservations,
        forceRefresh: forceRefresh,
      );
    }

    try {
      final callable = functions.httpsCallable('discoverAudienceSegments');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
        if (existingAnalysis != null) 'existingAnalysis': existingAnalysis.toMap(),
        if (agentObservations != null && agentObservations.isNotEmpty) 'agentObservations': agentObservations,
        'forceRefresh': forceRefresh,
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};
      final rawSegments = data['audience_segments'] as List<dynamic>? ?? [];

      if (rawSegments.isEmpty && enableFallback) {
        _isFallbackActive = true;
        _lastError = 'No segments returned from backend. Using rule engine.';
        return _fallbackService.discoverAudienceSegments(
          project,
          existingAnalysis: existingAnalysis,
          agentObservations: agentObservations,
          forceRefresh: forceRefresh,
        );
      }

      final isCached = meta['cached'] as bool? ?? false;
      final modelName = meta['model']?.toString() ?? 'gemini-2.5-flash';

      final segments = <AudienceSegmentModel>[];
      for (int i = 0; i < rawSegments.length; i++) {
        final item = rawSegments[i] as Map<String, dynamic>;
        segments.add(AudienceSegmentModel.fromMap({
          ...item,
          'projectId': project.id,
          'ownerId': project.ownerId,
          'is_live_ai': true,
          'model': modelName,
          'isCached': isCached,
        }));
      }

      _isFallbackActive = false;
      _lastError = null;
      return segments;
    } catch (e) {
      _isFallbackActive = true;
      _lastError = 'Live AI error: $e';
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] discoverAudienceSegments fallback activated: $e');
      }
      if (enableFallback) {
        return _fallbackService.discoverAudienceSegments(
          project,
          existingAnalysis: existingAnalysis,
          agentObservations: agentObservations,
          forceRefresh: forceRefresh,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<MatchModel>?> getCachedMatches(String projectId) async {
    final functions = _functions;
    if (functions == null) {
      return _fallbackService.getCachedMatches(projectId);
    }

    try {
      final callable = functions.httpsCallable('getMatches');
      final result = await callable.call<Map<String, dynamic>>({
        'projectId': projectId,
      });

      final data = result.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final rawMatches = data['matches'] as List<dynamic>? ?? [];
      final isLiveAI = result.data['meta']?['isLiveAI'] as bool? ?? false;
      final calcSource = result.data['meta']?['calculationSource']?.toString() ?? 'Firestore Cache';

      return rawMatches.map((m) {
        final item = m as Map<String, dynamic>;
        return MatchModel.fromMap({
          ...item,
          'projectId': projectId,
          'isLiveAI': isLiveAI,
          'calculationSource': calcSource,
          'isCached': true,
        });
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] getCachedMatches fallback: $e');
      }
      return _fallbackService.getCachedMatches(projectId);
    }
  }

  @override
  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
    bool forceRefresh = false,
  }) async {
    final functions = _functions;
    if (functions == null) {
      _isFallbackActive = true;
      _lastError = 'Firebase Functions not initialized. Using offline rule engine.';
      return _fallbackService.matchBuyers(project: project, buyers: buyers, forceRefresh: forceRefresh);
    }

    try {
      final callable = functions.httpsCallable('matchBuyers');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
        'buyers': buyers.map((b) => b.toMap()).toList(),
        'forceRefresh': forceRefresh,
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final rawMatches = data['matches'] as List<dynamic>? ?? [];
      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};
      final isLiveAI = meta['isLiveAI'] as bool? ?? false;
      final isCached = meta['cached'] as bool? ?? false;
      final modelUsed = meta['model']?.toString() ?? 'gemini-2.5-flash';

      if (rawMatches.isEmpty && enableFallback) {
        _isFallbackActive = true;
        _lastError = 'No matches returned from backend. Using rule engine.';
        return _fallbackService.matchBuyers(project: project, buyers: buyers, forceRefresh: forceRefresh);
      }

      final buyerMap = {for (final b in buyers) b.id: b};

      final matches = <MatchModel>[];
      for (final m in rawMatches) {
        final item = m as Map<String, dynamic>;
        final buyerId = item['buyer_id']?.toString() ?? '';
        final buyer = buyerMap[buyerId];

        matches.add(MatchModel.fromMap({
          ...item,
          'buyerId': buyerId,
          'projectId': item['project_id']?.toString() ?? project.id,
          'buyerName': buyer?.name ?? item['buyer_name'] ?? 'Prospective Buyer',
          'projectName': project.name,
          'isDemoBuyer': buyer?.isDemo ?? false,
          'isLiveAI': isLiveAI,
          'isCached': isCached,
          'calculationSource': isLiveAI ? modelUsed : 'Rule-based Deterministic Engine (Fallback)',
        }));
      }

      matches.sort((a, b) => b.overallMatchPercentage.compareTo(a.overallMatchPercentage));
      _isFallbackActive = false;
      _lastError = null;
      return matches;
    } catch (e) {
      _isFallbackActive = true;
      _lastError = 'Live AI error: $e';
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] matchBuyers fallback activated: $e');
      }
      if (enableFallback) {
        return _fallbackService.matchBuyers(project: project, buyers: buyers, forceRefresh: forceRefresh);
      }
      rethrow;
    }
  }

  @override
  Future<SegmentMarketingContent> generateMarketingContent({
    required ProjectModel project,
    required AudienceSegmentModel segment,
    required String channel,
    String language = 'en',
  }) async {
    final functions = _functions;
    if (functions == null) {
      _isFallbackActive = true;
      _lastError = 'Firebase Functions not initialized. Using offline rule engine.';
      return _fallbackService.generateMarketingContent(
        project: project,
        segment: segment,
        channel: channel,
        language: language,
      );
    }

    try {
      final callable = functions.httpsCallable('generateMarketingContent');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
        'segmentName': segment.name,
        'channel': channel,
        'language': language,
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final channels = data['channels'] as List<dynamic>? ?? [];

      String fbPost = '';
      String igPost = '';
      String ttIdea = '';

      for (final ch in channels) {
        final chMap = ch as Map<String, dynamic>;
        final platform = (chMap['platform']?.toString() ?? '').toLowerCase();
        final content = chMap['content']?.toString() ?? '';
        if (platform.contains('facebook')) {
          fbPost = content;
        } else if (platform.contains('instagram')) {
          igPost = content;
        } else if (platform.contains('tiktok')) {
          ttIdea = content;
        }
      }

      _isFallbackActive = false;
      _lastError = null;

      return SegmentMarketingContent(
        headlines: [data['headline']?.toString() ?? 'Exclusive Property Launch'],
        facebookPost: fbPost.isNotEmpty ? fbPost : (data['primary_text']?.toString() ?? ''),
        instagramCaption: igPost.isNotEmpty ? igPost : (data['primary_text']?.toString() ?? ''),
        tikTokIdea: ttIdea.isNotEmpty ? ttIdea : 'Video walkthrough focusing on ${segment.name}',
        callToActions: [data['call_to_action']?.toString() ?? 'Register Interest'],
      );
    } catch (e) {
      _isFallbackActive = true;
      _lastError = 'Live AI error: $e';
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] generateMarketingContent fallback activated: $e');
      }
      if (enableFallback) {
        return _fallbackService.generateMarketingContent(
          project: project,
          segment: segment,
          channel: channel,
          language: language,
        );
      }
      rethrow;
    }
  }

  @override
  Future<AIUsageStatsResult?> getUsageStats() async {
    final functions = _functions;
    if (functions == null) {
      return _fallbackService.getUsageStats();
    }

    try {
      final callable = functions.httpsCallable('getAIUsageStats');
      final result = await callable.call<Map<String, dynamic>>();
      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      return AIUsageStatsResult.fromMap(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] getUsageStats fallback: $e');
      }
      if (enableFallback) {
        return _fallbackService.getUsageStats();
      }
      rethrow;
    }
  }
}
