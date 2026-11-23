/// Agent Preferences Model for Phase 4.4: Dual-Channel Buyer Acquisition.
/// Controls agent opt-in, criteria filters, and availability for Channel B (Platform-Generated Enquiries).
class AgentPreferencesModel {
  final String agentId;
  final bool isAvailableForPlatformLeads;
  final List<String> preferredLocations;
  final List<String> preferredPropertyTypes;
  final double priceRangeMin;
  final double priceRangeMax;
  final List<String> specializations; // e.g. 'First-time Homebuyer', 'Luxury Investment', 'Commercial', 'Expat/MM2H'
  final List<String> acceptedEnquiryTypes; // e.g. 'Property Portal', 'Developer', 'Partner Agency'
  final int monthlyLeadQuota;
  final int leadsReceivedThisMonth;
  final DateTime? lastLeadAssignedAt;
  final DateTime updatedAt;

  AgentPreferencesModel({
    required this.agentId,
    this.isAvailableForPlatformLeads = true,
    this.preferredLocations = const ['Batu Kawan', 'George Town', 'Bayan Lepas', 'Penang'],
    this.preferredPropertyTypes = const ['Condominium', 'Serviced Residence', 'Terrace House'],
    this.priceRangeMin = 350000.0,
    this.priceRangeMax = 1500000.0,
    this.specializations = const ['First-time Homebuyer', 'High-Rise Residential', 'Own Stay'],
    this.acceptedEnquiryTypes = const ['Property Portal', 'Developer', 'Partner Agency'],
    this.monthlyLeadQuota = 30,
    this.leadsReceivedThisMonth = 0,
    this.lastLeadAssignedAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get hasRemainingQuota => leadsReceivedThisMonth < monthlyLeadQuota;

  AgentPreferencesModel copyWith({
    String? agentId,
    bool? isAvailableForPlatformLeads,
    List<String>? preferredLocations,
    List<String>? preferredPropertyTypes,
    double? priceRangeMin,
    double? priceRangeMax,
    List<String>? specializations,
    List<String>? acceptedEnquiryTypes,
    int? monthlyLeadQuota,
    int? leadsReceivedThisMonth,
    DateTime? lastLeadAssignedAt,
    DateTime? updatedAt,
  }) {
    return AgentPreferencesModel(
      agentId: agentId ?? this.agentId,
      isAvailableForPlatformLeads: isAvailableForPlatformLeads ?? this.isAvailableForPlatformLeads,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      preferredPropertyTypes: preferredPropertyTypes ?? this.preferredPropertyTypes,
      priceRangeMin: priceRangeMin ?? this.priceRangeMin,
      priceRangeMax: priceRangeMax ?? this.priceRangeMax,
      specializations: specializations ?? this.specializations,
      acceptedEnquiryTypes: acceptedEnquiryTypes ?? this.acceptedEnquiryTypes,
      monthlyLeadQuota: monthlyLeadQuota ?? this.monthlyLeadQuota,
      leadsReceivedThisMonth: leadsReceivedThisMonth ?? this.leadsReceivedThisMonth,
      lastLeadAssignedAt: lastLeadAssignedAt ?? this.lastLeadAssignedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agentId': agentId,
      'isAvailableForPlatformLeads': isAvailableForPlatformLeads,
      'preferredLocations': preferredLocations,
      'preferredPropertyTypes': preferredPropertyTypes,
      'priceRangeMin': priceRangeMin,
      'priceRangeMax': priceRangeMax,
      'specializations': specializations,
      'acceptedEnquiryTypes': acceptedEnquiryTypes,
      'monthlyLeadQuota': monthlyLeadQuota,
      'leadsReceivedThisMonth': leadsReceivedThisMonth,
      'lastLeadAssignedAt': lastLeadAssignedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AgentPreferencesModel.fromMap(Map<String, dynamic> map) {
    return AgentPreferencesModel(
      agentId: map['agentId']?.toString() ?? '',
      isAvailableForPlatformLeads: map['isAvailableForPlatformLeads'] as bool? ?? true,
      preferredLocations: (map['preferredLocations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['Batu Kawan', 'George Town', 'Bayan Lepas', 'Penang'],
      preferredPropertyTypes: (map['preferredPropertyTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['Condominium', 'Serviced Residence', 'Terrace House'],
      priceRangeMin: (map['priceRangeMin'] as num?)?.toDouble() ?? 350000.0,
      priceRangeMax: (map['priceRangeMax'] as num?)?.toDouble() ?? 1500000.0,
      specializations: (map['specializations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['First-time Homebuyer', 'High-Rise Residential'],
      acceptedEnquiryTypes: (map['acceptedEnquiryTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['Property Portal', 'Developer', 'Partner Agency'],
      monthlyLeadQuota: (map['monthlyLeadQuota'] as num?)?.toInt() ?? 30,
      leadsReceivedThisMonth: (map['leadsReceivedThisMonth'] as num?)?.toInt() ?? 0,
      lastLeadAssignedAt: map['lastLeadAssignedAt'] != null
          ? DateTime.tryParse(map['lastLeadAssignedAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
