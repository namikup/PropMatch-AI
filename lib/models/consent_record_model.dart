import 'package:uuid/uuid.dart';

class ConsentRecordModel {
  final String id;
  final String ownerId;
  final String buyerId;
  final String consentType; // 'enquiry_response', 'marketing_communication'
  final String consentStatus; // 'granted', 'withdrawn'
  final String consentSource; // 'Agent Direct Registration', 'Web Form', 'WhatsApp Lead'
  final DateTime consentTimestamp;
  final DateTime? withdrawalTimestamp;
  final DateTime createdAt;

  ConsentRecordModel({
    String? id,
    required this.ownerId,
    required this.buyerId,
    required this.consentType,
    this.consentStatus = 'granted',
    required this.consentSource,
    DateTime? consentTimestamp,
    this.withdrawalTimestamp,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        consentTimestamp = consentTimestamp ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  ConsentRecordModel copyWith({
    String? id,
    String? ownerId,
    String? buyerId,
    String? consentType,
    String? consentStatus,
    String? consentSource,
    DateTime? consentTimestamp,
    DateTime? withdrawalTimestamp,
    DateTime? createdAt,
  }) {
    return ConsentRecordModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      buyerId: buyerId ?? this.buyerId,
      consentType: consentType ?? this.consentType,
      consentStatus: consentStatus ?? this.consentStatus,
      consentSource: consentSource ?? this.consentSource,
      consentTimestamp: consentTimestamp ?? this.consentTimestamp,
      withdrawalTimestamp: withdrawalTimestamp ?? this.withdrawalTimestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'buyerId': buyerId,
      'consentType': consentType,
      'consentStatus': consentStatus,
      'consentSource': consentSource,
      'consentTimestamp': consentTimestamp.toIso8601String(),
      'withdrawalTimestamp': withdrawalTimestamp?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ConsentRecordModel.fromMap(Map<String, dynamic> map) {
    return ConsentRecordModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      consentType: map['consentType'] as String? ?? 'enquiry_response',
      consentStatus: map['consentStatus'] as String? ?? 'granted',
      consentSource: map['consentSource'] as String? ?? 'Agent Direct Registration',
      consentTimestamp: map['consentTimestamp'] != null
          ? DateTime.tryParse(map['consentTimestamp']) ?? DateTime.now()
          : DateTime.now(),
      withdrawalTimestamp: map['withdrawalTimestamp'] != null
          ? DateTime.tryParse(map['withdrawalTimestamp'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
