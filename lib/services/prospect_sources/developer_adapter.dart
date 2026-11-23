import '../../models/enquiry_model.dart';
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
    return [];
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'] ?? rawRecord['visitor_name'];
    final phone = rawRecord['phone'] ?? rawRecord['visitor_phone'] ?? rawRecord['contact_number'];
    final email = rawRecord['email'] ?? rawRecord['visitor_email'];
    final budgetMax = rawRecord['budgetMax'] ?? rawRecord['budget_max'] ?? rawRecord['budget'] ?? rawRecord['target_price'];
    final hasBudget = budgetMax != null && (num.tryParse(budgetMax.toString()) ?? 0) > 0;
    final hasContact = (phone != null && phone.toString().trim().isNotEmpty) ||
        (email != null && email.toString().trim().isNotEmpty);

    return (name != null && name.toString().trim().isNotEmpty) && (hasBudget || hasContact);
  }

  @override
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  }) {
    final isValid = validateProspectData(rawPayload);
    final devName = rawPayload['developer_name']?.toString() ??
        rawPayload['developer']?.toString() ??
        'Eco World Showroom Gallery';
    final projectName = rawPayload['project_name']?.toString() ?? 'Eco Horizon Gallery';
    final visitorName = rawPayload['fullName'] ?? rawPayload['name'] ?? rawPayload['visitor_name'] ?? 'Showroom Visitor';
    final phone = rawPayload['phone'] ?? rawPayload['visitor_phone'] ?? rawPayload['contact_number'] ?? '';
    final email = rawPayload['email'] ?? rawPayload['visitor_email'] ?? '';

    final budget = (rawPayload['budget_max'] as num?)?.toDouble() ??
        (rawPayload['budget'] as num?)?.toDouble() ??
        (num.tryParse(rawPayload['target_price']?.toString() ?? '') ?? 450000.0).toDouble();
    final visitorSlipSigned = rawPayload['visitor_consent_slip_signed'] == true ||
        rawPayload['showroom_consent'] == true ||
        rawPayload['signed_pdpa'] == true;

    return EnquiryModel(
      ownerId: ownerId,
      sourceType: sourceType,
      sourceName: '$devName — $projectName',
      sourceReferenceId: rawPayload['slip_serial_no']?.toString() ?? rawPayload['slip_id']?.toString() ?? rawPayload['registration_id']?.toString(),
      fullName: visitorName.toString().trim(),
      phone: phone.toString().trim(),
      email: email.toString().trim(),
      preferredLocation: rawPayload['interest_location']?.toString() ?? rawPayload['location']?.toString() ?? 'Batu Kawan',
      preferredState: rawPayload['state']?.toString() ?? 'Penang',
      propertyType: rawPayload['interest_type']?.toString() ?? rawPayload['propertyType']?.toString() ?? 'Condominium',
      budgetMin: budget * 0.9,
      budgetMax: budget * 1.1,
      purchasePurpose: rawPayload['purpose']?.toString() ?? 'Own Stay',
      buyingTimeline: rawPayload['timeline']?.toString() ?? 'Within 3 months',
      notes: rawPayload['notes']?.toString() ??
          'Sales gallery walk-in registration at $projectName showroom desk.',
      stage: isValid ? 'Data Normalisation' : 'Source Validation',
      processingStatus: isValid ? 'Pending' : 'Rejected',
      statusReason: isValid ? null : 'Missing visitor name or valid budget target',
      consentStatus: visitorSlipSigned ? 'Consent Granted' : 'Pending Consent',
      consentEvidence: visitorSlipSigned
          ? 'Physical / digital showroom registration slip signed at $devName gallery'
          : 'Pending verification of showroom visitor card consent',
      contactEligibility: visitorSlipSigned ? 'Eligible' : 'Pending Consent',
      isDemo: rawPayload['isDemo'] as bool? ?? false,
      rawMetadata: rawPayload,
    );
  }
}
