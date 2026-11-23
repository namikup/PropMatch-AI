/// Subscription & Commercial Readiness Models for Phase 4.4.
/// Prepares PropMatch AI for an individual-agent SaaS subscription model
/// while strictly maintaining complete data ownership isolation.
class SubscriptionTier {
  static const String freeStarter = 'Free Starter';
  static const String proAgent = 'Pro Agent';
  static const String eliteCloser = 'Elite Closer';
}

class AgentSubscriptionModel {
  final String agentId;
  final String tier; // 'Free Starter', 'Pro Agent', 'Elite Closer'
  final String status; // 'Active', 'Trial', 'Past Due', 'Canceled'
  final int monthlyPlatformLeadQuota;
  final int monthlyAiMatchQuota;
  final bool hasCustomLandingPageDomain;
  final bool hasPriorityPlatformRouting;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;

  AgentSubscriptionModel({
    required this.agentId,
    this.tier = SubscriptionTier.proAgent,
    this.status = 'Active',
    this.monthlyPlatformLeadQuota = 30,
    this.monthlyAiMatchQuota = 100,
    this.hasCustomLandingPageDomain = true,
    this.hasPriorityPlatformRouting = false,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
  })  : currentPeriodStart = currentPeriodStart ?? DateTime.now(),
        currentPeriodEnd = currentPeriodEnd ?? DateTime.now().add(const Duration(days: 30));

  factory AgentSubscriptionModel.defaultForAgent(String agentId) {
    return AgentSubscriptionModel(
      agentId: agentId,
      tier: SubscriptionTier.proAgent,
      status: 'Active',
      monthlyPlatformLeadQuota: 30,
      monthlyAiMatchQuota: 100,
      hasCustomLandingPageDomain: true,
      hasPriorityPlatformRouting: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agentId': agentId,
      'tier': tier,
      'status': status,
      'monthlyPlatformLeadQuota': monthlyPlatformLeadQuota,
      'monthlyAiMatchQuota': monthlyAiMatchQuota,
      'hasCustomLandingPageDomain': hasCustomLandingPageDomain,
      'hasPriorityPlatformRouting': hasPriorityPlatformRouting,
      'currentPeriodStart': currentPeriodStart.toIso8601String(),
      'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
    };
  }

  factory AgentSubscriptionModel.fromMap(Map<String, dynamic> map) {
    return AgentSubscriptionModel(
      agentId: map['agentId']?.toString() ?? '',
      tier: map['tier']?.toString() ?? SubscriptionTier.freeStarter,
      status: map['status']?.toString() ?? 'Active',
      monthlyPlatformLeadQuota: (map['monthlyPlatformLeadQuota'] as num?)?.toInt() ?? 10,
      monthlyAiMatchQuota: (map['monthlyAiMatchQuota'] as num?)?.toInt() ?? 50,
      hasCustomLandingPageDomain: map['hasCustomLandingPageDomain'] as bool? ?? false,
      hasPriorityPlatformRouting: map['hasPriorityPlatformRouting'] as bool? ?? false,
      currentPeriodStart: map['currentPeriodStart'] != null
          ? DateTime.tryParse(map['currentPeriodStart'].toString()) ?? DateTime.now()
          : DateTime.now(),
      currentPeriodEnd: map['currentPeriodEnd'] != null
          ? DateTime.tryParse(map['currentPeriodEnd'].toString()) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
    );
  }
}
