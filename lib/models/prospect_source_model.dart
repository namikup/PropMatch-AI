import 'package:uuid/uuid.dart';

/// Represents an external or internal data channel that feeds prospects into the agent's database.
class ProspectSourceModel {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 'Property Portal', 'Partner Agency', 'Developer', 'CRM Import'
  final String status; // 'Active', 'Paused', 'Configured', 'Disconnected'
  final Map<String, dynamic> configuration;
  final int totalProspectsImported;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProspectSourceModel({
    String? id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.status = 'Configured',
    this.configuration = const {},
    this.totalProspectsImported = 0,
    this.lastSyncAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status == 'Active';

  ProspectSourceModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? type,
    String? status,
    Map<String, dynamic>? configuration,
    int? totalProspectsImported,
    DateTime? lastSyncAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProspectSourceModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      configuration: configuration ?? this.configuration,
      totalProspectsImported: totalProspectsImported ?? this.totalProspectsImported,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'type': type,
      'status': status,
      'configuration': configuration,
      'totalProspectsImported': totalProspectsImported,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProspectSourceModel.fromMap(Map<String, dynamic> map) {
    return ProspectSourceModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'Property Portal',
      status: map['status'] as String? ?? 'Configured',
      configuration: Map<String, dynamic>.from(map['configuration'] ?? {}),
      totalProspectsImported: (map['totalProspectsImported'] as num?)?.toInt() ?? 0,
      lastSyncAt: map['lastSyncAt'] != null
          ? DateTime.tryParse(map['lastSyncAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
