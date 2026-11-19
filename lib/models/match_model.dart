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
  final bool isLiveAI;
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
    DateTime? calculatedAt,
  })  : id = id ?? const Uuid().v4(),
        calculatedAt = calculatedAt ?? DateTime.now();

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
      'isLiveAI': isLiveAI,
      'calculationSource': calculationSource,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      isDemoBuyer: map['isDemoBuyer'] as bool? ?? false,
      isLiveAI: map['isLiveAI'] as bool? ?? false,
      calculationSource: map['calculationSource'] as String? ?? 'Rule-based Fallback Engine',
      overallMatchPercentage:
          (map['overallMatchPercentage'] as num?)?.toDouble() ?? 0.0,
      budgetScore: (map['budgetScore'] as num?)?.toDouble() ?? 0.0,
      locationScore: (map['locationScore'] as num?)?.toDouble() ?? 0.0,
      propertyTypeScore:
          (map['propertyTypeScore'] as num?)?.toDouble() ?? 0.0,
      purposeScore: (map['purposeScore'] as num?)?.toDouble() ?? 0.0,
      timelineScore: (map['timelineScore'] as num?)?.toDouble() ?? 0.0,
      explanation: map['explanation'] as String? ?? '',
      matchingFactors: List<String>.from(map['matchingFactors'] ?? []),
      missingInformation: List<String>.from(map['missingInformation'] ?? []),
      potentialConcerns: List<String>.from(map['potentialConcerns'] ?? []),
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
