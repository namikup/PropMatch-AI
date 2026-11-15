import 'package:uuid/uuid.dart';

class CampaignModel {
  final String id;
  final String ownerId;
  final String name;
  final String projectId;
  final String projectName;
  final String? audienceSegmentId;
  final String audienceSegmentName;
  final String platform; // Facebook, Instagram, TikTok, WhatsApp, Google Ads
  final String contentHeadline;
  final String contentBody;
  final String callToAction;
  final String status; // Draft, Active, Completed, Paused
  final int reach;
  final int clicks;
  final int enquiries;
  final DateTime createdAt;

  CampaignModel({
    String? id,
    required this.ownerId,
    required this.name,
    required this.projectId,
    required this.projectName,
    this.audienceSegmentId,
    this.audienceSegmentName = '',
    required this.platform,
    required this.contentHeadline,
    required this.contentBody,
    required this.callToAction,
    this.status = 'Draft',
    this.reach = 0,
    this.clicks = 0,
    this.enquiries = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'projectId': projectId,
      'projectName': projectName,
      'audienceSegmentId': audienceSegmentId,
      'audienceSegmentName': audienceSegmentName,
      'platform': platform,
      'contentHeadline': contentHeadline,
      'contentBody': contentBody,
      'callToAction': callToAction,
      'status': status,
      'reach': reach,
      'clicks': clicks,
      'enquiries': enquiries,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CampaignModel.fromMap(Map<String, dynamic> map) {
    return CampaignModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      audienceSegmentId: map['audienceSegmentId'] as String?,
      audienceSegmentName: map['audienceSegmentName'] as String? ?? '',
      platform: map['platform'] as String? ?? 'Facebook',
      contentHeadline: map['contentHeadline'] as String? ?? '',
      contentBody: map['contentBody'] as String? ?? '',
      callToAction: map['callToAction'] as String? ?? '',
      status: map['status'] as String? ?? 'Draft',
      reach: (map['reach'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
      enquiries: (map['enquiries'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
