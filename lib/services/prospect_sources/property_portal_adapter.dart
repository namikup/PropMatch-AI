import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for major Malaysian property portals (e.g. iProperty, PropertyGuru, EdgeProp).
/// In Phase 4.1, establishes structure and mock capabilities without live external scraping or unverified network calls.
class PropertyPortalAdapter implements ProspectSourceAdapter {
  final String _portalName;

  PropertyPortalAdapter([this._portalName = 'Property Portal Feed']);

  @override
  String get sourceName => _portalName;

  @override
  String get sourceType => 'Property Portal';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final apiKey = config['apiKey']?.toString() ?? '';
    final portalEndpoint = config['endpoint']?.toString() ?? '';
    return apiKey.isNotEmpty || portalEndpoint.isNotEmpty;
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    // Phase 4.1: Interface contract ready for future authorized portal API keys
    return [];
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'];
    final phone = rawRecord['phone'];
    final email = rawRecord['email'];
    return (name != null && name.toString().trim().isNotEmpty) &&
        ((phone != null && phone.toString().trim().isNotEmpty) ||
            (email != null && email.toString().trim().isNotEmpty));
  }
}
