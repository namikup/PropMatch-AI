import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for authorized property developer partner feeds and project showroom registration desks.
class DeveloperAdapter implements ProspectSourceAdapter {
  final String _developerName;

  DeveloperAdapter([this._developerName = 'Developer Partner Integration']);

  @override
  String get sourceName => _developerName;

  @override
  String get sourceType => 'Developer';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final developerCode = config['developerCode']?.toString() ?? '';
    final secretKey = config['secretKey']?.toString() ?? '';
    return developerCode.isNotEmpty && secretKey.isNotEmpty;
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    // Phase 4.1: Interface contract ready for developer partner feeds
    return [];
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'];
    final budgetMax = rawRecord['budgetMax'] ?? rawRecord['budget'];
    return (name != null && name.toString().trim().isNotEmpty) &&
        (budgetMax != null && (num.tryParse(budgetMax.toString()) ?? 0) > 0);
  }
}
