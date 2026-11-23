class MetaAIInsightModel {
  final DateTime generatedAt;
  final String dataPeriod;
  final int sampleSizeLeads;
  final String statisticalConfidence; // 'High', 'Moderate', 'Low', 'Insufficient Data'
  final String executiveSummary;
  final List<String> topPerformingCampaigns;
  final List<String> inefficientCampaigns;
  final List<String> buyerQualityFindings;
  final List<String> creativeAndAudienceRecommendations;
  final String budgetAdvisory;

  const MetaAIInsightModel({
    required this.generatedAt,
    required this.dataPeriod,
    required this.sampleSizeLeads,
    required this.statisticalConfidence,
    required this.executiveSummary,
    required this.topPerformingCampaigns,
    required this.inefficientCampaigns,
    required this.buyerQualityFindings,
    required this.creativeAndAudienceRecommendations,
    required this.budgetAdvisory,
  });

  factory MetaAIInsightModel.fromMap(Map<String, dynamic> map) {
    return MetaAIInsightModel(
      generatedAt: map['generatedAt'] != null
          ? DateTime.tryParse(map['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dataPeriod: map['dataPeriod'] as String? ?? 'Active Campaign Window (Last 30 Days)',
      sampleSizeLeads: (map['sampleSizeLeads'] as num?)?.toInt() ?? 0,
      statisticalConfidence: map['statisticalConfidence'] as String? ?? 'Low',
      executiveSummary: map['executiveSummary'] as String? ?? '',
      topPerformingCampaigns: List<String>.from(map['topPerformingCampaigns'] ?? []),
      inefficientCampaigns: List<String>.from(map['inefficientCampaigns'] ?? []),
      buyerQualityFindings: List<String>.from(map['buyerQualityFindings'] ?? []),
      creativeAndAudienceRecommendations:
          List<String>.from(map['creativeAndAudienceRecommendations'] ?? []),
      budgetAdvisory: map['budgetAdvisory'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'dataPeriod': dataPeriod,
      'sampleSizeLeads': sampleSizeLeads,
      'statisticalConfidence': statisticalConfidence,
      'executiveSummary': executiveSummary,
      'topPerformingCampaigns': topPerformingCampaigns,
      'inefficientCampaigns': inefficientCampaigns,
      'buyerQualityFindings': buyerQualityFindings,
      'creativeAndAudienceRecommendations': creativeAndAudienceRecommendations,
      'budgetAdvisory': budgetAdvisory,
    };
  }
}
