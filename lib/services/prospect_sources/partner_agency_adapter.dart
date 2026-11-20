import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for authorized partner agency co-broke networks and regional broker referrals.
class PartnerAgencyAdapter implements ProspectSourceAdapter {
  final String _agencyName;

  PartnerAgencyAdapter([this._agencyName = 'Partner Agency Co-Broke Network']);

  @override
  String get sourceName => _agencyName;

  @override
  String get sourceType => 'Partner Agency';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final partnerToken = config['partnerToken']?.toString() ?? '';
    return partnerToken.isNotEmpty;
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    // Phase 4.1: Interface contract ready for future authorized agency co-broke webhooks
    return [];
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'];
    final state = rawRecord['preferredState'] ?? rawRecord['state'];
    return (name != null && name.toString().trim().isNotEmpty) &&
        (state != null && state.toString().trim().isNotEmpty);
  }
}
