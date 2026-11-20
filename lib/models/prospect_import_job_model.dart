import 'package:uuid/uuid.dart';

/// Tracks the lifecycle and execution statistics of batch prospect imports.
class ProspectImportJobModel {
  final String id;
  final String ownerId;
  final String sourceId;
  final String sourceName;
  final String status; // 'Pending', 'Processing', 'Completed', 'Failed', 'Partially Completed'
  final int totalRecords;
  final int importedCount;
  final int duplicateCount;
  final int errorCount;
  final String? errorSummary;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  ProspectImportJobModel({
    String? id,
    required this.ownerId,
    required this.sourceId,
    required this.sourceName,
    this.status = 'Pending',
    this.totalRecords = 0,
    this.importedCount = 0,
    this.duplicateCount = 0,
    this.errorCount = 0,
    this.errorSummary,
    DateTime? startedAt,
    this.completedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status == 'Completed';
  bool get isFailed => status == 'Failed';
  bool get isProcessing => status == 'Processing';

  ProspectImportJobModel copyWith({
    String? id,
    String? ownerId,
    String? sourceId,
    String? sourceName,
    String? status,
    int? totalRecords,
    int? importedCount,
    int? duplicateCount,
    int? errorCount,
    String? errorSummary,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return ProspectImportJobModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      status: status ?? this.status,
      totalRecords: totalRecords ?? this.totalRecords,
      importedCount: importedCount ?? this.importedCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      errorCount: errorCount ?? this.errorCount,
      errorSummary: errorSummary ?? this.errorSummary,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'status': status,
      'totalRecords': totalRecords,
      'importedCount': importedCount,
      'duplicateCount': duplicateCount,
      'errorCount': errorCount,
      'errorSummary': errorSummary,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProspectImportJobModel.fromMap(Map<String, dynamic> map) {
    return ProspectImportJobModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      totalRecords: (map['totalRecords'] as num?)?.toInt() ?? 0,
      importedCount: (map['importedCount'] as num?)?.toInt() ?? 0,
      duplicateCount: (map['duplicateCount'] as num?)?.toInt() ?? 0,
      errorCount: (map['errorCount'] as num?)?.toInt() ?? 0,
      errorSummary: map['errorSummary'] as String?,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
