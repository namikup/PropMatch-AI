import 'package:uuid/uuid.dart';

class LeadModel {
  final String id;
  final String ownerId;
  final String buyerId;
  final String projectId;
  final String buyerName;
  final String projectName;
  final String status; // New, Contacted, Qualified, Proposal Sent, Negotiating, Won, Lost
  final String source; // Facebook Ads, WhatsApp Enquiry, etc.
  final double dealValue;
  final String notes;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeadModel({
    String? id,
    required this.ownerId,
    required this.buyerId,
    required this.projectId,
    required this.buyerName,
    required this.projectName,
    this.status = 'New',
    required this.source,
    this.dealValue = 0.0,
    this.notes = '',
    this.isDemo = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  LeadModel copyWith({
    String? id,
    String? ownerId,
    String? buyerId,
    String? projectId,
    String? buyerName,
    String? projectName,
    String? status,
    String? source,
    double? dealValue,
    String? notes,
    bool? isDemo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      buyerId: buyerId ?? this.buyerId,
      projectId: projectId ?? this.projectId,
      buyerName: buyerName ?? this.buyerName,
      projectName: projectName ?? this.projectName,
      status: status ?? this.status,
      source: source ?? this.source,
      dealValue: dealValue ?? this.dealValue,
      notes: notes ?? this.notes,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'buyerId': buyerId,
      'projectId': projectId,
      'buyerName': buyerName,
      'projectName': projectName,
      'status': status,
      'source': source,
      'dealValue': dealValue,
      'notes': notes,
      'isDemo': isDemo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LeadModel.fromMap(Map<String, dynamic> map) {
    return LeadModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      status: map['status'] as String? ?? 'New',
      source: map['source'] as String? ?? 'Direct',
      dealValue: (map['dealValue'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      isDemo: map['isDemo'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
