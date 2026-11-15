import 'package:uuid/uuid.dart';

class AudienceSegmentModel {
  final String id;
  final String projectId;
  final String ownerId;
  final String name; // e.g. "Young Tech Professionals", "First-time Homebuyers"
  final String description;
  final String interestReason;
  final String budgetCompatibility; // e.g. "High: RM400k - RM550k range matches"
  final String propertyPreferences; // e.g. "3 bedrooms, modern facilities, gym, near highways"
  final String purchasePurpose; // Own Stay, Investment, Both
  final List<String> potentialObjections; // e.g. ["Higher maintenance fees", "Traffic congestion"]
  final List<String> recommendedMarketingMessages;
  final List<String> recommendedChannels; // ["Facebook Lead Ads", "Instagram Carousel", "TikTok"]
  final String suggestedCallToAction; // e.g. "Download Floor Plan & Early Bird Rebate"
  final double suitabilityScore; // 0 to 100
  final int rank;
  final String reasoning;
  final DateTime createdAt;

  AudienceSegmentModel({
    String? id,
    required this.projectId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.interestReason,
    required this.budgetCompatibility,
    required this.propertyPreferences,
    required this.purchasePurpose,
    required this.potentialObjections,
    required this.recommendedMarketingMessages,
    required this.recommendedChannels,
    required this.suggestedCallToAction,
    required this.suitabilityScore,
    required this.rank,
    required this.reasoning,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'interestReason': interestReason,
      'budgetCompatibility': budgetCompatibility,
      'propertyPreferences': propertyPreferences,
      'purchasePurpose': purchasePurpose,
      'potentialObjections': potentialObjections,
      'recommendedMarketingMessages': recommendedMarketingMessages,
      'recommendedChannels': recommendedChannels,
      'suggestedCallToAction': suggestedCallToAction,
      'suitabilityScore': suitabilityScore,
      'rank': rank,
      'reasoning': reasoning,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AudienceSegmentModel.fromMap(Map<String, dynamic> map) {
    return AudienceSegmentModel(
      id: map['id'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      interestReason: map['interestReason'] as String? ?? '',
      budgetCompatibility: map['budgetCompatibility'] as String? ?? '',
      propertyPreferences: map['propertyPreferences'] as String? ?? '',
      purchasePurpose: map['purchasePurpose'] as String? ?? '',
      potentialObjections: List<String>.from(map['potentialObjections'] ?? []),
      recommendedMarketingMessages:
          List<String>.from(map['recommendedMarketingMessages'] ?? []),
      recommendedChannels: List<String>.from(map['recommendedChannels'] ?? []),
      suggestedCallToAction: map['suggestedCallToAction'] as String? ?? '',
      suitabilityScore: (map['suitabilityScore'] as num?)?.toDouble() ?? 0.0,
      rank: (map['rank'] as num?)?.toInt() ?? 1,
      reasoning: map['reasoning'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
