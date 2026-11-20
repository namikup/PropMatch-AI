import '../../models/prospect_model.dart';

/// Abstract contract for all external and internal prospect data adapters.
/// Designed for future integrations (property portals, agency co-broke networks, developers, CRM exports).
abstract class ProspectSourceAdapter {
  String get sourceName;
  String get sourceType; // 'Property Portal', 'Partner Agency', 'Developer', 'CRM Import'

  /// Tests connectivity, credentials, or API configuration.
  Future<bool> testConnection(Map<String, dynamic> config);

  /// Ingests or fetches prospective buyers from the source.
  /// All returned prospects MUST have contactEligibility defaulting to 'Pending Consent' or 'Ineligible'.
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  });

  /// Validates raw payload before mapping into [ProspectModel].
  bool validateProspectData(Map<String, dynamic> rawRecord);
}
