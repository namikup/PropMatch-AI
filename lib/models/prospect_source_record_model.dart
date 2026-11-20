import 'package:uuid/uuid.dart';

/// Captures origin attribution and provenance metadata for a prospect from a specific source event.
class ProspectSourceRecordModel {
  final String id;
  final String ownerId;
  final String prospectId;
  final String sourceId;
  final String sourceName;
  final String sourceType;
  final String? externalReference; // Portal inquiry ID, campaign lead ID, partner ref
  final Map<String, dynamic> rawMetadata;
  final DateTime capturedAt;
  final DateTime createdAt;

  ProspectSourceRecordModel({
    String? id,
    required this.ownerId,
    required this.prospectId,
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    this.externalReference,
    this.rawMetadata = const {},
    DateTime? capturedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        capturedAt = capturedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'prospectId': prospectId,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'sourceType': sourceType,
      'externalReference': externalReference,
      'rawMetadata': rawMetadata,
      'capturedAt': capturedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProspectSourceRecordModel.fromMap(Map<String, dynamic> map) {
    return ProspectSourceRecordModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      prospectId: map['prospectId'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      sourceType: map['sourceType'] as String? ?? 'Property Portal',
      externalReference: map['externalReference'] as String?,
      rawMetadata: Map<String, dynamic>.from(map['rawMetadata'] ?? {}),
      capturedAt: map['capturedAt'] != null
          ? DateTime.tryParse(map['capturedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
