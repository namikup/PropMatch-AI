import 'package:uuid/uuid.dart';

/// Represents a matched pairing between a prospective buyer and a property development project.
class ProspectMatchModel {
  final String id;
  final String ownerId;
  final String prospectId;
  final String projectId;
  final String prospectName;
  final String projectName;
  final double overallCompatibility; // 0 - 100
  final String matchClassification; // 'Excellent Match', 'Good Match', 'Moderate Match', 'Low Match'
  final List<String> reasons;
  final List<String> hesitations;
  final bool isContactEligible;
  final DateTime matchedAt;

  ProspectMatchModel({
    String? id,
    required this.ownerId,
    required this.prospectId,
    required this.projectId,
    required this.prospectName,
    required this.projectName,
    required this.overallCompatibility,
    required this.matchClassification,
    this.reasons = const [],
    this.hesitations = const [],
    this.isContactEligible = false,
    DateTime? matchedAt,
  })  : id = id ?? const Uuid().v4(),
        matchedAt = matchedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'prospectId': prospectId,
      'projectId': projectId,
      'prospectName': prospectName,
      'projectName': projectName,
      'overallCompatibility': overallCompatibility,
      'matchClassification': matchClassification,
      'reasons': reasons,
      'hesitations': hesitations,
      'isContactEligible': isContactEligible,
      'matchedAt': matchedAt.toIso8601String(),
    };
  }

  factory ProspectMatchModel.fromMap(Map<String, dynamic> map) {
    return ProspectMatchModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      prospectId: map['prospectId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      prospectName: map['prospectName'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      overallCompatibility: (map['overallCompatibility'] as num?)?.toDouble() ?? 0.0,
      matchClassification: map['matchClassification'] as String? ?? 'Moderate Match',
      reasons: List<String>.from(map['reasons'] ?? []),
      hesitations: List<String>.from(map['hesitations'] ?? []),
      isContactEligible: map['isContactEligible'] as bool? ?? false,
      matchedAt: map['matchedAt'] != null
          ? DateTime.tryParse(map['matchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
