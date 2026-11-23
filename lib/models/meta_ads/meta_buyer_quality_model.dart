class MetaBuyerQualityModel {
  final int totalLeads;
  final int validContactableLeads;
  final int qualifiedProspects;
  final int matchedListingCount;
  final int viewingAppointments;
  final int convertedBuyers;
  final double? costPerQualifiedBuyer; // null if qualifiedProspects == 0
  final double? costPerViewingAppointment; // null if viewingAppointments == 0
  final double qualificationRate; // percentage

  const MetaBuyerQualityModel({
    required this.totalLeads,
    required this.validContactableLeads,
    required this.qualifiedProspects,
    required this.matchedListingCount,
    required this.viewingAppointments,
    required this.convertedBuyers,
    this.costPerQualifiedBuyer,
    this.costPerViewingAppointment,
    required this.qualificationRate,
  });

  factory MetaBuyerQualityModel.fromMap(Map<String, dynamic> map) {
    return MetaBuyerQualityModel(
      totalLeads: (map['totalLeads'] as num?)?.toInt() ?? 0,
      validContactableLeads: (map['validContactableLeads'] as num?)?.toInt() ?? 0,
      qualifiedProspects: (map['qualifiedProspects'] as num?)?.toInt() ?? 0,
      matchedListingCount: (map['matchedListingCount'] as num?)?.toInt() ?? 0,
      viewingAppointments: (map['viewingAppointments'] as num?)?.toInt() ?? 0,
      convertedBuyers: (map['convertedBuyers'] as num?)?.toInt() ?? 0,
      costPerQualifiedBuyer: (map['costPerQualifiedBuyer'] as num?)?.toDouble(),
      costPerViewingAppointment: (map['costPerViewingAppointment'] as num?)?.toDouble(),
      qualificationRate: (map['qualificationRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalLeads': totalLeads,
      'validContactableLeads': validContactableLeads,
      'qualifiedProspects': qualifiedProspects,
      'matchedListingCount': matchedListingCount,
      'viewingAppointments': viewingAppointments,
      'convertedBuyers': convertedBuyers,
      'costPerQualifiedBuyer': costPerQualifiedBuyer,
      'costPerViewingAppointment': costPerViewingAppointment,
      'qualificationRate': qualificationRate,
    };
  }
}
