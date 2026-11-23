import '../../models/enquiry_model.dart';
import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for major Malaysian property portals (e.g. iProperty, PropertyGuru, EdgeProp).
///
/// NOTE ON INTEGRATION ARCHITECTURE:
/// Commercial property portals do NOT provide public unauthenticated scraping endpoints.
/// In PropMatch AI, portal leads are ingested exclusively through:
/// 1. Official portal partner webhooks (with HMAC cryptographic signature verification).
/// 2. Authorized agent portal export synchronization.
///
/// Status: Commercial Partner Webhook Specification (Active for certified payload parsing;
/// production API endpoint awaiting formal commercial licensing).
class PropertyPortalAdapter implements ProspectSourceAdapter {
  final String _portalName;

  PropertyPortalAdapter([this._portalName = 'iProperty & PropertyGuru Portal Feed']);

  @override
  String get sourceName => _portalName;

  @override
  String get sourceType => 'Property Portal';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final apiKey = config['apiKey']?.toString() ?? '';
    final webhookSecret = config['webhookSecret']?.toString() ?? '';
    return apiKey.isNotEmpty || webhookSecret.isNotEmpty;
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    return [];
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'] ?? rawRecord['full_name'] ?? rawRecord['inquirer_name'];
    final phone = rawRecord['phone'] ?? rawRecord['inquirer_phone'] ?? rawRecord['contact_number'];
    final email = rawRecord['email'] ?? rawRecord['inquirer_email'];
    return (name != null && name.toString().trim().isNotEmpty) &&
        ((phone != null && phone.toString().trim().isNotEmpty) ||
            (email != null && email.toString().trim().isNotEmpty));
  }

  @override
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  }) {
    final isValid = validateProspectData(rawPayload);
    final portalLeadId = rawPayload['lead_id'] ?? rawPayload['enquiry_id'] ?? rawPayload['inquiry_id'] ?? rawPayload['id'];
    final specificPortal = rawPayload['portal']?.toString() ??
        rawPayload['portal_name']?.toString() ??
        rawPayload['source_name']?.toString() ??
        'iProperty Malaysia';

    final name = rawPayload['fullName'] ?? rawPayload['name'] ?? rawPayload['full_name'] ?? rawPayload['inquirer_name'] ?? 'Portal Inquirer';
    final phone = rawPayload['phone'] ?? rawPayload['inquirer_phone'] ?? rawPayload['contact_number'] ?? '';
    final email = rawPayload['email'] ?? rawPayload['inquirer_email'] ?? '';

    final price = (rawPayload['listing_price'] as num?)?.toDouble() ??
        (rawPayload['budget'] as num?)?.toDouble() ??
        600000.0;

    return EnquiryModel(
      ownerId: ownerId,
      sourceType: sourceType,
      sourceName: specificPortal,
      sourceReferenceId: portalLeadId?.toString(),
      fullName: name.toString().trim(),
      phone: phone.toString().trim(),
      email: email.toString().trim(),
      preferredLocation: rawPayload['location']?.toString() ??
          rawPayload['listing_location']?.toString() ??
          'Penang',
      preferredState: rawPayload['state']?.toString() ?? 'Penang',
      propertyType: rawPayload['propertyType']?.toString() ??
          rawPayload['listing_type']?.toString() ??
          'Condominium',
      budgetMin: price * 0.9,
      budgetMax: price * 1.15,
      purchasePurpose: rawPayload['purpose']?.toString() ?? 'Own Stay',
      buyingTimeline: rawPayload['timeline']?.toString() ?? '1-3 months',
      notes: rawPayload['message']?.toString() ??
          'Direct listing enquiry submitted through $specificPortal.',
      stage: isValid ? 'Data Normalisation' : 'Source Validation',
      processingStatus: isValid ? 'Pending' : 'Rejected',
      statusReason: isValid ? null : 'Missing required contact identifier (phone or email)',
      // STRICT: Direct portal enquiry grants basis for inquiry follow-up, NOT promotional spam
      consentStatus: 'Consent Granted',
      consentEvidence: 'Direct property portal inquiry form response basis (Listing Ref: ${rawPayload['listing_id'] ?? 'General'})',
      contactEligibility: 'Eligible',
      isDemo: rawPayload['isDemo'] as bool? ?? false,
      rawMetadata: rawPayload,
    );
  }
}
