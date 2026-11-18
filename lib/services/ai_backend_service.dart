import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/audience_segment_model.dart';
import '../models/buyer_model.dart';
import '../models/match_model.dart';
import 'ai_service.dart';
import 'matching_service.dart';

/// Structured response container for Property Deep-Dive Analysis (Module A)
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

  const PropertyAnalysisResult({
    required this.projectSummary,
    required this.keySellingPoints,
    required this.potentialBuyerSegments,
    required this.competitiveAdvantages,
    required this.potentialObjections,
    required this.marketingAngles,
    required this.recommendedPricePositioning,
    required this.analysisConfidence,
    this.model = 'local-rule-engine',
    this.latencyMs = 0,
  });

  factory PropertyAnalysisResult.fromMap(
    Map<String, dynamic> map, {
    String model = 'gemini-1.5-flash',
    int latencyMs = 0,
  }) {
    return PropertyAnalysisResult(
      projectSummary: map['project_summary']?.toString() ?? 'Summary unavailable',
      keySellingPoints: List<String>.from(map['key_selling_points'] ?? []),
      potentialBuyerSegments: List<String>.from(map['potential_buyer_segments'] ?? []),
      competitiveAdvantages: List<String>.from(map['competitive_advantages'] ?? []),
      potentialObjections: List<String>.from(map['potential_objections'] ?? []),
      marketingAngles: List<String>.from(map['marketing_angles'] ?? []),
      recommendedPricePositioning: map['recommended_price_positioning']?.toString() ?? 'Market standard',
      analysisConfidence: map['analysis_confidence']?.toString() ?? 'Medium',
      model: model,
      latencyMs: latencyMs,
    );
  }
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
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project);

  Future<List<AudienceSegmentModel>> discoverAudienceSegments(ProjectModel project);

  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
  });

  Future<SegmentMarketingContent> generateMarketingContent({
    required ProjectModel project,
    required AudienceSegmentModel segment,
    required String channel,
    String language = 'en',
  });

  Future<AIUsageStatsResult?> getUsageStats();
}

/// Local rule-based AI service implementation.
/// Used for demo mode, unit testing, and graceful offline fallback.
class LocalRuleBasedAIService implements AIBackendService {
  const LocalRuleBasedAIService();

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project) async {
    final points = <String>[
      '${project.propertyType} located strategically in ${project.location}, ${project.state}',
      'Competitive pricing from RM${project.startingPrice.toStringAsFixed(0)} to RM${project.maximumPrice.toStringAsFixed(0)}',
      'Spacious ${project.builtUpArea.toStringAsFixed(0)} sqft layout with ${project.bedrooms} bedrooms & ${project.bathrooms} bathrooms',
      if (project.facilities.isNotEmpty) 'Lifestyle facilities: ${project.facilities.take(3).join(', ')}',
      if (project.nearbyAmenities.isNotEmpty) 'Convenient nearby amenities: ${project.nearbyAmenities.take(3).join(', ')}',
    ];

    return PropertyAnalysisResult(
      projectSummary: '${project.name} by ${project.developer} is a ${project.status} ${project.propertyType} in ${project.location}, tailored for ${project.purpose.toLowerCase()}.',
      keySellingPoints: points,
      potentialBuyerSegments: [
        'First-Time Homebuyers & Young Families',
        'Local Upgraders seeking modern lifestyle',
        if (project.purpose.contains('Investment')) 'Rental Yield & Capital Appreciation Investors',
      ],
      competitiveAdvantages: [
        'Strategic road connectivity and infrastructure in ${project.location}',
        'Comprehensive internal facilities tailored for modern living',
      ],
      potentialObjections: [
        'Market competition from neighboring developments in ${project.state}',
        'Financing approval considerations for first-time purchasers',
      ],
      marketingAngles: [
        'Spacious family sanctuary with direct highway accessibility',
        'High rental appeal and long-term capital preservation',
      ],
      recommendedPricePositioning: 'Priced competitively within the median ${project.propertyType} segment in ${project.state}.',
      analysisConfidence: 'High',
      model: 'local-rule-engine',
      latencyMs: 15,
    );
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(ProjectModel project) async {
    return AIService.discoverAudienceSegments(project);
  }

  @override
  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
  }) async {
    final matches = <MatchModel>[];
    for (final buyer in buyers) {
      matches.add(MatchingService.calculateMatch(buyer: buyer, project: project));
    }
    matches.sort((a, b) => b.overallMatchPercentage.compareTo(a.overallMatchPercentage));
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
/// to LocalRuleBasedAIService to ensure seamless operation without errors.
class CloudFunctionsAIService implements AIBackendService {
  final FirebaseFunctions _functions;
  final LocalRuleBasedAIService _fallbackService;
  final bool enableFallback;

  CloudFunctionsAIService({
    FirebaseFunctions? functions,
    LocalRuleBasedAIService? fallbackService,
    this.enableFallback = true,
  })  : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
        _fallbackService = fallbackService ?? const LocalRuleBasedAIService();

  @override
  Future<PropertyAnalysisResult> analyzeProperty(ProjectModel project) async {
    try {
      final callable = _functions.httpsCallable('analyzeProperty');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final meta = result.data['meta'] as Map<String, dynamic>? ?? {};

      return PropertyAnalysisResult.fromMap(
        data,
        model: meta['model']?.toString() ?? 'gemini-1.5-flash',
        latencyMs: (meta['latencyMs'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] analyzeProperty fallback: $e');
      }
      if (enableFallback) {
        return _fallbackService.analyzeProperty(project);
      }
      rethrow;
    }
  }

  @override
  Future<List<AudienceSegmentModel>> discoverAudienceSegments(ProjectModel project) async {
    try {
      final callable = _functions.httpsCallable('discoverAudienceSegments');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final rawSegments = data['audience_segments'] as List<dynamic>? ?? [];

      if (rawSegments.isEmpty && enableFallback) {
        return _fallbackService.discoverAudienceSegments(project);
      }

      final segments = <AudienceSegmentModel>[];
      for (int i = 0; i < rawSegments.length; i++) {
        final item = rawSegments[i] as Map<String, dynamic>;
        segments.add(AudienceSegmentModel(
          projectId: project.id,
          ownerId: project.ownerId,
          name: item['segment_name']?.toString() ?? 'Audience Segment ${i + 1}',
          description: item['description']?.toString() ?? '',
          interestReason: (item['evidence'] as List<dynamic>?)?.join('. ') ?? '',
          budgetCompatibility: 'High: Evaluated against RM${project.startingPrice.toStringAsFixed(0)} entry',
          propertyPreferences: '${project.propertyType}, ${project.bedrooms} Bedrooms, ${project.builtUpArea.toStringAsFixed(0)} sqft',
          purchasePurpose: project.purpose,
          potentialObjections: List<String>.from(item['potential_objections'] ?? []),
          recommendedMarketingMessages: List<String>.from(item['recommended_content_angles'] ?? []),
          recommendedChannels: List<String>.from(item['recommended_marketing_channels'] ?? []),
          suggestedCallToAction: 'Register for Priority Preview',
          suitabilityScore: (item['estimated_relevance'] as num?)?.toDouble() ?? 75.0,
          rank: i + 1,
          reasoning: (item['evidence'] as List<dynamic>?)?.join('. ') ?? 'High alignment with project attributes.',
        ));
      }

      return segments;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] discoverAudienceSegments fallback: $e');
      }
      if (enableFallback) {
        return _fallbackService.discoverAudienceSegments(project);
      }
      rethrow;
    }
  }

  @override
  Future<List<MatchModel>> matchBuyers({
    required ProjectModel project,
    required List<BuyerModel> buyers,
  }) async {
    try {
      final callable = _functions.httpsCallable('matchBuyers');
      final result = await callable.call<Map<String, dynamic>>({
        'project': project.toMap(),
        'buyers': buyers.map((b) => b.toMap()).toList(),
      });

      final data = result.data['data'] as Map<String, dynamic>? ?? {};
      final rawMatches = data['matches'] as List<dynamic>? ?? [];

      if (rawMatches.isEmpty && enableFallback) {
        return _fallbackService.matchBuyers(project: project, buyers: buyers);
      }

      final buyerMap = {for (final b in buyers) b.id: b};

      final matches = <MatchModel>[];
      for (final m in rawMatches) {
        final item = m as Map<String, dynamic>;
        final buyerId = item['buyer_id']?.toString() ?? '';
        final buyer = buyerMap[buyerId];
        final factors = item['matching_factors'] as Map<String, dynamic>? ?? {};

        matches.add(MatchModel(
          ownerId: project.ownerId,
          buyerId: buyerId,
          projectId: item['project_id']?.toString() ?? project.id,
          buyerName: buyer?.name ?? 'Prospective Buyer',
          projectName: project.name,
          overallMatchPercentage: (item['overall_score'] as num?)?.toDouble() ?? 50.0,
          budgetScore: (factors['budget'] as num?)?.toDouble() ?? 0.0,
          locationScore: (factors['location'] as num?)?.toDouble() ?? 0.0,
          propertyTypeScore: (factors['property_type'] as num?)?.toDouble() ?? 0.0,
          purposeScore: (factors['purchase_purpose'] as num?)?.toDouble() ?? 0.0,
          timelineScore: (factors['buying_timeline'] as num?)?.toDouble() ?? 0.0,
          explanation: (item['reasons'] as List<dynamic>?)?.join('. ') ?? 'Calculated using AI Matching factors.',
          matchingFactors: List<String>.from(item['reasons'] ?? []),
          potentialConcerns: List<String>.from(item['potential_mismatches'] ?? []),
          missingInformation: List<String>.from(item['missing_information'] ?? []),
        ));
      }

      matches.sort((a, b) => b.overallMatchPercentage.compareTo(a.overallMatchPercentage));
      return matches;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] matchBuyers fallback: $e');
      }
      if (enableFallback) {
        return _fallbackService.matchBuyers(project: project, buyers: buyers);
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
    try {
      final callable = _functions.httpsCallable('generateMarketingContent');
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

      return SegmentMarketingContent(
        headlines: [data['headline']?.toString() ?? 'Exclusive Property Launch'],
        facebookPost: fbPost.isNotEmpty ? fbPost : (data['primary_text']?.toString() ?? ''),
        instagramCaption: igPost.isNotEmpty ? igPost : (data['primary_text']?.toString() ?? ''),
        tikTokIdea: ttIdea.isNotEmpty ? ttIdea : 'Video walkthrough focusing on ${segment.name}',
        callToActions: [data['call_to_action']?.toString() ?? 'Register Interest'],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudFunctionsAIService] generateMarketingContent fallback: $e');
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
    try {
      final callable = _functions.httpsCallable('getAIUsageStats');
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
