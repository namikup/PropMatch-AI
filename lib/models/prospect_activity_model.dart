import 'package:uuid/uuid.dart';

/// Append-only activity entry capturing significant lifecycle events for a prospect.
class ProspectActivityModel {
  final String id;
  final String ownerId;
  final String prospectId;
  final String activityType; // Discovered, Status Change, Contact Eligibility Update, Consent Recorded, Consent Withdrawn, Note Added, Matched to Project, Exported
  final String title;
  final String description;
  final String actor; // e.g. 'Agent (UID)', 'System Import Adapter', 'AI Matching Engine'
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  ProspectActivityModel({
    String? id,
    required this.ownerId,
    required this.prospectId,
    required this.activityType,
    required this.title,
    this.description = '',
    this.actor = 'Agent User',
    this.metadata = const {},
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'prospectId': prospectId,
      'activityType': activityType,
      'title': title,
      'description': description,
      'actor': actor,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ProspectActivityModel.fromMap(Map<String, dynamic> map) {
    return ProspectActivityModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      prospectId: map['prospectId'] as String? ?? '',
      activityType: map['activityType'] as String? ?? 'Status Change',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      actor: map['actor'] as String? ?? 'Agent User',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
