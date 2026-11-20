import 'package:uuid/uuid.dart';

class MatchModel {
  final String id;
  final String ownerId;
  final String buyerId;
  final String projectId;
  final String buyerName;
  final String projectName;
  final bool isDemoBuyer;
  final double overallMatchPercentage; // 0 - 100
  final double budgetScore; // 0 - 25
  final double locationScore; // 0 - 25
  final double propertyTypeScore; // 0 - 20
  final double purposeScore; // 0 - 15
  final double timelineScore; // 0 - 15
  final String explanation;
  final List<String> matchingFactors;
  final List<String> missingInformation;
  final List<String> potentialConcerns;
  final List<String> mismatchedCriteria;
  final List<String> potentialObjections;
  final String confidenceLevel; // "High" | "Medium" | "Low"
  final String matchClassification; // "Excellent Match" | "Good Match" | "Moderate Match" | "Low Match"
  final String recommendedNextAction;
  final String? aiExplanation;
  final String? suggestedConversationOpener;
  final bool isLiveAI;
  final bool isCached;
  final String? sourceVersion;
  final String calculationSource;
  final DateTime calculatedAt;

  MatchModel({
    String? id,
    required this.ownerId,
    required this.buyerId,
    required this.projectId,
    required this.buyerName,
    required this.projectName,
    this.isDemoBuyer = false,
    this.isLiveAI = false,
    this.isCached = false,
    this.sourceVersion,
    this.calculationSource = 'Rule-based Fallback Engine',
    required this.overallMatchPercentage,
    required this.budgetScore,
    required this.locationScore,
    required this.propertyTypeScore,
    required this.purposeScore,
    required this.timelineScore,
    required this.explanation,
    required this.matchingFactors,
    required this.missingInformation,
    required this.potentialConcerns,
    List<String>? mismatchedCriteria,
    List<String>? potentialObjections,
    String? confidenceLevel,
    String? matchClassification,
    String? recommendedNextAction,
    this.aiExplanation,
    this.suggestedConversationOpener,
    DateTime? calculatedAt,
  })  : id = id ?? const Uuid().v4(),
        mismatchedCriteria = mismatchedCriteria ?? List<String>.from(potentialConcerns),
        potentialObjections = potentialObjections ?? [],
        confidenceLevel = confidenceLevel ??
            (missingInformation.length >= 2
                ? 'Low'
                : missingInformation.length == 1
                    ? 'Medium'
                    : 'High'),
        matchClassification = matchClassification ??
            (overallMatchPercentage >= 85
                ? 'Excellent Match'
                : overallMatchPercentage >= 70
                    ? 'Good Match'
                    : overallMatchPercentage >= 50
                        ? 'Moderate Match'
                        : 'Low Match'),
        recommendedNextAction = recommendedNextAction ??
            (overallMatchPercentage >= 85
                ? 'Prioritize for private showroom preview and furnish layout options.'
                : overallMatchPercentage >= 70
                    ? 'Engage buyer to review specific layouts and loan pre-qualification.'
                    : overallMatchPercentage >= 50
                        ? 'Clarify buyer criteria and financing flexibility before presentation.'
                        : 'Retain in general nurture pipeline; project not suitable at present.'),
        calculatedAt = calculatedAt ?? DateTime.now();

  bool get isExcellentMatch => overallMatchPercentage >= 85;
  bool get isGoodMatch => overallMatchPercentage >= 70 && overallMatchPercentage < 85;
  bool get isModerateMatch => overallMatchPercentage >= 50 && overallMatchPercentage < 70;
  bool get isLowMatch => overallMatchPercentage < 50;
  String get formattedScore => '${overallMatchPercentage.round()}%';
  String get effectiveExplanation =>
      (aiExplanation != null && aiExplanation!.trim().isNotEmpty) ? aiExplanation! : explanation;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'buyerId': buyerId,
      'projectId': projectId,
      'buyerName': buyerName,
      'projectName': projectName,
      'isDemoBuyer': isDemoBuyer,
      'overallMatchPercentage': overallMatchPercentage,
      'budgetScore': budgetScore,
      'locationScore': locationScore,
      'propertyTypeScore': propertyTypeScore,
      'purposeScore': purposeScore,
      'timelineScore': timelineScore,
      'explanation': explanation,
      'matchingFactors': matchingFactors,
      'missingInformation': missingInformation,
      'potentialConcerns': potentialConcerns,
      'mismatchedCriteria': mismatchedCriteria,
      'potentialObjections': potentialObjections,
      'confidenceLevel': confidenceLevel,
      'matchClassification': matchClassification,
      'recommendedNextAction': recommendedNextAction,
      'aiExplanation': aiExplanation,
      'suggestedConversationOpener': suggestedConversationOpener,
      'isLiveAI': isLiveAI,
      'isCached': isCached,
      'sourceVersion': sourceVersion,
      'calculationSource': calculationSource,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    final score = (map['overallMatchPercentage'] as num?)?.toDouble() ??
        (map['overall_score'] as num?)?.toDouble() ??
        0.0;

    final missing = List<String>.from(map['missingInformation'] ?? map['missing_information'] ?? []);
    final factors = List<String>.from(map['matchingFactors'] ?? map['reasons'] ?? []);
    final concerns = List<String>.from(map['potentialConcerns'] ?? map['potential_mismatches'] ?? []);
    final mismatches = List<String>.from(map['mismatchedCriteria'] ?? map['mismatched_criteria'] ?? concerns);
    final objections = List<String>.from(map['potentialObjections'] ?? map['potential_objections'] ?? []);

    final factorsMap = map['matching_factors'] as Map<String, dynamic>?;

    return MatchModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? map['buyer_id'] as String? ?? '',
      projectId: map['projectId'] as String? ?? map['project_id'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? map['buyer_name'] as String? ?? '',
      projectName: map['projectName'] as String? ?? map['project_name'] as String? ?? '',
      isDemoBuyer: map['isDemoBuyer'] as bool? ?? false,
      isLiveAI: map['isLiveAI'] as bool? ?? false,
      isCached: map['isCached'] as bool? ?? map['is_cached'] as bool? ?? false,
      sourceVersion: map['sourceVersion'] as String? ?? map['source_version'] as String?,
      calculationSource: map['calculationSource'] as String? ?? 'Rule-based Fallback Engine',
      overallMatchPercentage: score,
      budgetScore: (map['budgetScore'] as num?)?.toDouble() ??
          (factorsMap?['budget'] as num?)?.toDouble() ??
          0.0,
      locationScore: (map['locationScore'] as num?)?.toDouble() ??
          (factorsMap?['location'] as num?)?.toDouble() ??
          0.0,
      propertyTypeScore: (map['propertyTypeScore'] as num?)?.toDouble() ??
          (factorsMap?['property_type'] as num?)?.toDouble() ??
          0.0,
      purposeScore: (map['purposeScore'] as num?)?.toDouble() ??
          (factorsMap?['purchase_purpose'] as num?)?.toDouble() ??
          0.0,
      timelineScore: (map['timelineScore'] as num?)?.toDouble() ??
          (factorsMap?['buying_timeline'] as num?)?.toDouble() ??
          0.0,
      explanation: map['explanation'] as String? ?? map['ai_explanation'] as String? ?? '',
      matchingFactors: factors,
      missingInformation: missing,
      potentialConcerns: concerns,
      mismatchedCriteria: mismatches,
      potentialObjections: objections,
      confidenceLevel: map['confidenceLevel'] as String? ?? map['confidence_level'] as String?,
      matchClassification: map['matchClassification'] as String? ?? map['matching_classification'] as String?,
      recommendedNextAction: map['recommendedNextAction'] as String? ?? map['recommended_next_action'] as String?,
      aiExplanation: map['aiExplanation'] as String? ?? map['ai_explanation'] as String?,
      suggestedConversationOpener: map['suggestedConversationOpener'] as String? ??
          map['suggested_conversation_opener'] as String?,
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
