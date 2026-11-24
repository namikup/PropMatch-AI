import 'meta_buyer_quality_model.dart';

class MetaAdModel {
  final String id;
  final String adSetId;
  final String name;
  final String status;
  final String creativeTitle;
  final String creativeBody;
  final String? previewUrl;
  final double spend;
  final int impressions;
  final int clicks;
  final int leads;
  final double costPerLead;

  const MetaAdModel({
    required this.id,
    required this.adSetId,
    required this.name,
    required this.status,
    required this.creativeTitle,
    required this.creativeBody,
    this.previewUrl,
    required this.spend,
    required this.impressions,
    required this.clicks,
    required this.leads,
    required this.costPerLead,
  });

  factory MetaAdModel.fromMap(Map<String, dynamic> map) {
    return MetaAdModel(
      id: map['id'] as String? ?? '',
      adSetId: map['adSetId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      creativeTitle: map['creativeTitle'] as String? ?? '',
      creativeBody: map['creativeBody'] as String? ?? '',
      previewUrl: map['previewUrl'] as String?,
      spend: (map['spend'] as num?)?.toDouble() ?? 0.0,
      impressions: (map['impressions'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
      leads: (map['leads'] as num?)?.toInt() ?? 0,
      costPerLead: (map['costPerLead'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adSetId': adSetId,
      'name': name,
      'status': status,
      'creativeTitle': creativeTitle,
      'creativeBody': creativeBody,
      'previewUrl': previewUrl,
      'spend': spend,
      'impressions': impressions,
      'clicks': clicks,
      'leads': leads,
      'costPerLead': costPerLead,
    };
  }
}

class MetaAdSetModel {
  final String id;
  final String name;
  final String status;
  final String? targetingSummary;
  final double spend;
  final int leads;
  final double costPerLead;

  const MetaAdSetModel({
    required this.id,
    required this.name,
    required this.status,
    this.targetingSummary,
    required this.spend,
    required this.leads,
    required this.costPerLead,
  });

  factory MetaAdSetModel.fromMap(Map<String, dynamic> map) {
    return MetaAdSetModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      targetingSummary: map['targetingSummary'] as String?,
      spend: (map['spend'] as num?)?.toDouble() ?? 0.0,
      leads: (map['leads'] as num?)?.toInt() ?? 0,
      costPerLead: (map['costPerLead'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'targetingSummary': targetingSummary,
      'spend': spend,
      'leads': leads,
      'costPerLead': costPerLead,
    };
  }
}

class MetaCampaignModel {
  final String id;
  final String ownerId;
  final String campaignId;
  final String campaignName;
  final String status;
  final String objective;
  final double? dailyBudget;
  final double? lifetimeBudget;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double ctr;
  final double cpc;
  final double cpm;
  final int leads;
  final double costPerLead;
  final String dateStart;
  final String dateStop;
  final String dataSource;
  final MetaBuyerQualityModel qualityMetrics;
  final List<MetaAdSetModel> adSets;
  final List<MetaAdModel> ads;
  final DateTime updatedAt;

  const MetaCampaignModel({
    required this.id,
    required this.ownerId,
    required this.campaignId,
    required this.campaignName,
    required this.status,
    required this.objective,
    this.dailyBudget,
    this.lifetimeBudget,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.ctr,
    required this.cpc,
    required this.cpm,
    required this.leads,
    required this.costPerLead,
    required this.dateStart,
    required this.dateStop,
    this.dataSource = 'REAL_META_API',
    required this.qualityMetrics,
    this.adSets = const [],
    this.ads = const [],
    required this.updatedAt,
  });

  factory MetaCampaignModel.fromMap(Map<String, dynamic> map) {
    return MetaCampaignModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      campaignId: map['campaignId'] as String? ?? '',
      campaignName: map['campaignName'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      objective: map['objective'] as String? ?? 'OUTCOME_LEADS',
      dailyBudget: (map['dailyBudget'] as num?)?.toDouble(),
      lifetimeBudget: (map['lifetimeBudget'] as num?)?.toDouble(),
      spend: (map['spend'] as num?)?.toDouble() ?? 0.0,
      impressions: (map['impressions'] as num?)?.toInt() ?? 0,
      reach: (map['reach'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
      ctr: (map['ctr'] as num?)?.toDouble() ?? 0.0,
      cpc: (map['cpc'] as num?)?.toDouble() ?? 0.0,
      cpm: (map['cpm'] as num?)?.toDouble() ?? 0.0,
      leads: (map['leads'] as num?)?.toInt() ?? 0,
      costPerLead: (map['costPerLead'] as num?)?.toDouble() ?? 0.0,
      dateStart: map['dateStart'] as String? ?? '',
      dateStop: map['dateStop'] as String? ?? '',
      dataSource: map['dataSource'] as String? ?? 'REAL_META_API',
      qualityMetrics: map['qualityMetrics'] != null
          ? MetaBuyerQualityModel.fromMap(Map<String, dynamic>.from(map['qualityMetrics']))
          : const MetaBuyerQualityModel(
              totalLeads: 0,
              validContactableLeads: 0,
              qualifiedProspects: 0,
              matchedListingCount: 0,
              viewingAppointments: 0,
              convertedBuyers: 0,
              qualificationRate: 0.0,
            ),
      adSets: (map['adSets'] as List<dynamic>?)
              ?.map((e) => MetaAdSetModel.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      ads: (map['ads'] as List<dynamic>?)
              ?.map((e) => MetaAdModel.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'status': status,
      'objective': objective,
      'dailyBudget': dailyBudget,
      'lifetimeBudget': lifetimeBudget,
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'ctr': ctr,
      'cpc': cpc,
      'cpm': cpm,
      'leads': leads,
      'costPerLead': costPerLead,
      'dateStart': dateStart,
      'dateStop': dateStop,
      'dataSource': dataSource,
      'qualityMetrics': qualityMetrics.toMap(),
      'adSets': adSets.map((e) => e.toMap()).toList(),
      'ads': ads.map((e) => e.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
