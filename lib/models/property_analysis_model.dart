/// Single Selling Point with supporting rationale and buyer benefit (Section B)
class SellingPointItem {
  final String title;
  final String explanation;
  final String supportingInfo;
  final String buyerBenefit;
  final String confidence; // High, Medium, Low

  const SellingPointItem({
    required this.title,
    required this.explanation,
    required this.supportingInfo,
    required this.buyerBenefit,
    this.confidence = 'High',
  });

  factory SellingPointItem.fromMap(Map<String, dynamic> map) {
    return SellingPointItem(
      title: map['title']?.toString() ?? 'Key Selling Point',
      explanation: map['explanation']?.toString() ?? '',
      supportingInfo: map['supporting_info']?.toString() ?? 'Agent-provided project specs',
      buyerBenefit: map['buyer_benefit']?.toString() ?? 'Value alignment for prospective buyers',
      confidence: map['confidence']?.toString() ?? 'High',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'explanation': explanation,
        'supporting_info': supportingInfo,
        'buyer_benefit': buyerBenefit,
        'confidence': confidence,
      };
}

/// Potential Buyer Persona with targeting motivations (Section C)
class BuyerPersonaItem {
  final String segmentName;
  final String description;
  final double estimatedRelevance; // 0-100
  final List<String> buyingMotivations;
  final List<String> appealingFeatures;
  final List<String> potentialObjections;
  final String recommendedMarketingAngle;

  const BuyerPersonaItem({
    required this.segmentName,
    required this.description,
    required this.estimatedRelevance,
    required this.buyingMotivations,
    required this.appealingFeatures,
    required this.potentialObjections,
    required this.recommendedMarketingAngle,
  });

  double get relevanceScore => estimatedRelevance;
  List<String> get keyMotivations => buyingMotivations;
  String get recommendedHook => recommendedMarketingAngle;

  factory BuyerPersonaItem.fromMap(Map<String, dynamic> map) {
    return BuyerPersonaItem(
      segmentName: map['segment_name']?.toString() ?? 'Target Persona',
      description: map['description']?.toString() ?? '',
      estimatedRelevance: (map['estimated_relevance'] as num?)?.toDouble() ?? 75.0,
      buyingMotivations: List<String>.from(map['buying_motivations'] ?? []),
      appealingFeatures: List<String>.from(map['appealing_features'] ?? []),
      potentialObjections: List<String>.from(map['potential_objections'] ?? []),
      recommendedMarketingAngle: map['recommended_marketing_angle']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'segment_name': segmentName,
        'description': description,
        'estimated_relevance': estimatedRelevance,
        'buying_motivations': buyingMotivations,
        'appealing_features': appealingFeatures,
        'potential_objections': potentialObjections,
        'recommended_marketing_angle': recommendedMarketingAngle,
      };
}

/// Competitive Advantage with verified evidence status (Section D)
class CompetitiveAdvantageItem {
  final String advantage;
  final String explanation;
  final String supportingEvidence;
  final String evidenceStatus; // "Verified project characteristic", "Agent-provided feature", "Competitor comparison unavailable"

  const CompetitiveAdvantageItem({
    required this.advantage,
    required this.explanation,
    required this.supportingEvidence,
    required this.evidenceStatus,
  });

  factory CompetitiveAdvantageItem.fromMap(Map<String, dynamic> map) {
    return CompetitiveAdvantageItem(
      advantage: map['advantage']?.toString() ?? 'Key Advantage',
      explanation: map['explanation']?.toString() ?? '',
      supportingEvidence: map['supporting_evidence']?.toString() ?? 'Project specifications',
      evidenceStatus: map['evidence_status']?.toString() ?? 'Verified project characteristic',
    );
  }

  Map<String, dynamic> toMap() => {
        'advantage': advantage,
        'explanation': explanation,
        'supporting_evidence': supportingEvidence,
        'evidence_status': evidenceStatus,
      };
}

/// Potential Buyer Objection with professional handling strategy (Section E)
class ObjectionItem {
  final String objection;
  final String category; // price, location, financing, size, facilities, timing, general
  final String responseStrategy;

  const ObjectionItem({
    required this.objection,
    required this.category,
    required this.responseStrategy,
  });

  String get recommendedResponse => responseStrategy;

  factory ObjectionItem.fromMap(Map<String, dynamic> map) {
    return ObjectionItem(
      objection: map['objection']?.toString() ?? 'Buyer Hesitation',
      category: map['category']?.toString() ?? 'general',
      responseStrategy: map['response_strategy']?.toString() ?? 'Present value proposition and arrange private viewing.',
    );
  }

  Map<String, dynamic> toMap() => {
        'objection': objection,
        'category': category,
        'response_strategy': responseStrategy,
      };
}

/// Complete Marketing Strategy Plan (Section F)
class MarketingStrategyPlan {
  final List<String> recommendedAngles;
  final List<String> suitableAudienceSegments;
  final List<String> suggestedChannels;
  final List<String> advertisementHeadlines;
  final List<String> socialMediaIdeas;
  final List<String> recommendedCallsToAction;

  const MarketingStrategyPlan({
    required this.recommendedAngles,
    required this.suitableAudienceSegments,
    required this.suggestedChannels,
    required this.advertisementHeadlines,
    required this.socialMediaIdeas,
    required this.recommendedCallsToAction,
  });

  List<String> get headlines => advertisementHeadlines;
  List<String> get socialMediaAngles => socialMediaIdeas;
  List<String> get callToActions => recommendedCallsToAction;

  factory MarketingStrategyPlan.fromMap(Map<String, dynamic> map) {
    return MarketingStrategyPlan(
      recommendedAngles: List<String>.from(map['recommended_angles'] ?? []),
      suitableAudienceSegments: List<String>.from(map['suitable_audience_segments'] ?? []),
      suggestedChannels: List<String>.from(map['suggested_channels'] ?? []),
      advertisementHeadlines: List<String>.from(map['advertisement_headlines'] ?? []),
      socialMediaIdeas: List<String>.from(map['social_media_ideas'] ?? []),
      recommendedCallsToAction: List<String>.from(map['recommended_calls_to_action'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'recommended_angles': recommendedAngles,
        'suitable_audience_segments': suitableAudienceSegments,
        'suggested_channels': suggestedChannels,
        'advertisement_headlines': advertisementHeadlines,
        'social_media_ideas': socialMediaIdeas,
        'recommended_calls_to_action': recommendedCallsToAction,
      };
}

/// Executive Summary & Boundary Notice (Section G)
class AnalysisSummaryData {
  final String overallPositioning;
  final String strongestSellingPoint;
  final String mostRelevantSegment;
  final String mainPotentialObjection;
  final String recommendedNextAction;
  final List<String> analysisLimitations;

  const AnalysisSummaryData({
    required this.overallPositioning,
    required this.strongestSellingPoint,
    required this.mostRelevantSegment,
    required this.mainPotentialObjection,
    required this.recommendedNextAction,
    required this.analysisLimitations,
  });

  String get primaryTargetAudience => mostRelevantSegment;
  String get mainObjection => mainPotentialObjection;
  String get recommendedNextStep => recommendedNextAction;
  String get limitationsText => analysisLimitations.join('\n\n');

  factory AnalysisSummaryData.fromMap(Map<String, dynamic> map) {
    return AnalysisSummaryData(
      overallPositioning: map['overall_positioning']?.toString() ?? 'Strategic regional positioning.',
      strongestSellingPoint: map['strongest_selling_point']?.toString() ?? 'Prime location and layout.',
      mostRelevantSegment: map['most_relevant_segment']?.toString() ?? 'First-time buyers & upgraders.',
      mainPotentialObjection: map['main_potential_objection']?.toString() ?? 'Price comparison vs surrounding market.',
      recommendedNextAction: map['recommended_next_action']?.toString() ?? 'Initiate targeted digital campaign and showroom previews.',
      analysisLimitations: List<String>.from(map['analysis_limitations'] ?? [
        'Analysis synthesized strictly from agent-supplied project parameters.',
        'Competitor comparisons unavailable without verified external data.',
        'Buyer personas represent marketing hypotheses, not verified individuals.'
      ]),
    );
  }

  Map<String, dynamic> toMap() => {
        'overall_positioning': overallPositioning,
        'strongest_selling_point': strongestSellingPoint,
        'most_relevant_segment': mostRelevantSegment,
        'main_potential_objection': mainPotentialObjection,
        'recommended_next_action': recommendedNextAction,
        'analysis_limitations': analysisLimitations,
      };
}

/// Property Overview Details (Section A)
class PropertyOverviewData {
  final String name;
  final String location;
  final String state;
  final String propertyType;
  final String priceRange;
  final int bedrooms;
  final int bathrooms;
  final double builtUpArea;
  final List<String> facilities;
  final String description;
  final String professionalOverview;

  const PropertyOverviewData({
    required this.name,
    required this.location,
    required this.state,
    required this.propertyType,
    required this.priceRange,
    required this.bedrooms,
    required this.bathrooms,
    required this.builtUpArea,
    required this.facilities,
    required this.description,
    required this.professionalOverview,
  });

  String get positioningStatement => professionalOverview;
  String get targetBuyerCategory => 'Target Submarket';

  factory PropertyOverviewData.fromMap(Map<String, dynamic> map) {
    return PropertyOverviewData(
      name: map['name']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      propertyType: map['property_type']?.toString() ?? '',
      priceRange: map['price_range']?.toString() ?? '',
      bedrooms: (map['bedrooms'] as num?)?.toInt() ?? 0,
      bathrooms: (map['bathrooms'] as num?)?.toInt() ?? 0,
      builtUpArea: (map['built_up_area'] as num?)?.toDouble() ?? 0.0,
      facilities: List<String>.from(map['facilities'] ?? []),
      description: map['description']?.toString() ?? '',
      professionalOverview: map['professional_overview']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': location,
        'state': state,
        'property_type': propertyType,
        'price_range': priceRange,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'built_up_area': builtUpArea,
        'facilities': facilities,
        'description': description,
        'professional_overview': professionalOverview,
      };
}
