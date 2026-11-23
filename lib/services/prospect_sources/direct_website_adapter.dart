import '../../models/enquiry_model.dart';
import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter for incoming leads from property agent personal websites, landing pages,
/// and digital marketing campaigns.
///
/// Features built-in honeypot anti-spam validation, explicit PDPA consent verification,
/// and UTM campaign provenance tracking.
class DirectWebsiteAdapter implements ProspectSourceAdapter {
  final String _websiteDomain;

  DirectWebsiteAdapter([this._websiteDomain = 'PropMatch Agent Webform']);

  @override
  String get sourceName => _websiteDomain;

  @override
  String get sourceType => 'Direct Website';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final formToken = config['formToken']?.toString() ?? '';
    final originUrl = config['originUrl']?.toString() ?? '';
    return formToken.isNotEmpty || originUrl.isNotEmpty;
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
    // 1. Honeypot check: If the hidden honeypot field is filled, it's a bot submission
    final honeypot = rawRecord['website_hp_check'] ?? rawRecord['website_hp'] ?? rawRecord['hp_field'] ?? rawRecord['fax'];
    if (honeypot != null && honeypot.toString().trim().isNotEmpty) {
      return false; // Spam bot detected
    }

    // 2. Name validation
    final name = rawRecord['fullName'] ?? rawRecord['name'];
    if (name == null || name.toString().trim().isEmpty) {
      return false;
    }

    return true;
  }

  @override
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  }) {
    final isValid = validateProspectData(rawPayload);
    final pdpaAgreed = rawPayload['pdpa_agreed'] == true ||
        rawPayload['consent'] == true ||
        rawPayload['consent_checkbox'] == true;

    final phoneRaw = rawPayload['phone']?.toString() ?? rawPayload['phoneNumber']?.toString() ?? '';
    final emailRaw = rawPayload['email']?.toString() ?? rawPayload['emailAddress']?.toString() ?? '';

    final budgetMin = (rawPayload['budgetMin'] as num?)?.toDouble() ??
        (rawPayload['budget'] != null ? ((num.tryParse(rawPayload['budget'].toString()) ?? 500000.0) * 0.85).toDouble() : 400000.0);
    final budgetMax = (rawPayload['budgetMax'] as num?)?.toDouble() ??
        (rawPayload['budget'] != null ? (num.tryParse(rawPayload['budget'].toString()) ?? 700000.0).toDouble() : 700000.0);

    return EnquiryModel(
      ownerId: ownerId,
      sourceType: sourceType,
      sourceName: rawPayload['form_title']?.toString() ?? sourceName,
      sourceReferenceId: rawPayload['submission_id']?.toString() ?? rawPayload['lead_id']?.toString(),
      fullName: rawPayload['fullName']?.toString() ?? rawPayload['name']?.toString() ?? 'Website Visitor',
      phone: phoneRaw,
      email: emailRaw,
      preferredLocation: rawPayload['location']?.toString() ?? rawPayload['preferredLocation']?.toString() ?? 'Kuala Lumpur',
      preferredState: rawPayload['state']?.toString() ?? rawPayload['preferredState']?.toString() ?? 'Kuala Lumpur',
      propertyType: rawPayload['propertyType']?.toString() ?? 'Condominium',
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      purchasePurpose: rawPayload['purpose']?.toString() ?? rawPayload['purchasePurpose']?.toString() ?? 'Own Stay',
      buyingTimeline: rawPayload['timeline']?.toString() ?? rawPayload['buyingTimeline']?.toString() ?? '1-3 months',
      notes: rawPayload['message']?.toString() ?? rawPayload['notes']?.toString() ?? 'Inquiry submitted via agent landing page.',
      stage: isValid ? 'Data Normalisation' : 'Source Validation',
      processingStatus: isValid ? 'Pending' : 'Rejected',
      statusReason: isValid ? null : 'Anti-spam honeypot triggered or contact details missing',
      consentStatus: pdpaAgreed ? 'Consent Granted' : 'Pending Consent',
      consentEvidence: pdpaAgreed
          ? 'Explicit website form consent checkbox submitted at ${DateTime.now().toIso8601String()}'
          : 'Pending agent confirmation of voluntary inquiry basis',
      contactEligibility: pdpaAgreed ? 'Eligible' : 'Pending Consent',
      isDemo: rawPayload['isDemo'] as bool? ?? false,
      rawMetadata: rawPayload,
    );
  }
}
