import '../../models/prospect_model.dart';
import '../../models/enquiry_model.dart';

/// Abstract contract for all external and internal prospect data adapters.
/// Designed for multi-source ingestion (property portals, agency co-broke networks, developers, CRM exports, direct webforms).
abstract class ProspectSourceAdapter {
  String get sourceName;
  String get sourceType; // 'Property Portal', 'Partner Agency', 'Developer', 'CRM Import', 'Direct Website'

  /// Tests connectivity, credentials, or API configuration.
  Future<bool> testConnection(Map<String, dynamic> config);

  /// Ingests or fetches prospective buyers from the source.
  /// All returned prospects MUST have contactEligibility defaulting to 'Pending Consent' or 'Ineligible'.
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  });

  /// Validates raw payload before mapping into [ProspectModel] or [EnquiryModel].
  bool validateProspectData(Map<String, dynamic> rawRecord);

  /// Parses raw incoming enquiry payload into a standardized [EnquiryModel].
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  });
}
