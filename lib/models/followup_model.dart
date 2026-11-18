import 'package:uuid/uuid.dart';

class FollowupModel {
  final String id;
  final String ownerId;
  final String buyerName;
  final String? buyerId;
  final String projectName;
  final String? projectId;
  final String task;
  final String dueDate;
  final String type; // Showroom Viewing, WhatsApp Follow-up, Investor Consultation, Loan Screening, Custom Follow-up
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  FollowupModel({
    String? id,
    required this.ownerId,
    required this.buyerName,
    this.buyerId,
    required this.projectName,
    this.projectId,
    required this.task,
    required this.dueDate,
    this.type = 'Custom Follow-up',
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  FollowupModel copyWith({
    String? id,
    String? ownerId,
    String? buyerName,
    String? buyerId,
    String? projectName,
    String? projectId,
    String? task,
    String? dueDate,
    String? type,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowupModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      buyerName: buyerName ?? this.buyerName,
      buyerId: buyerId ?? this.buyerId,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      task: task ?? this.task,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'buyerName': buyerName,
      'buyerId': buyerId,
      'projectName': projectName,
      'projectId': projectId,
      'task': task,
      'dueDate': dueDate,
      'type': type,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FollowupModel.fromMap(Map<String, dynamic> map) {
    return FollowupModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      buyerId: map['buyerId'] as String?,
      projectName: map['projectName'] as String? ?? '',
      projectId: map['projectId'] as String?,
      task: map['task'] as String? ?? '',
      dueDate: map['dueDate'] as String? ?? '',
      type: map['type'] as String? ?? 'Custom Follow-up',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
