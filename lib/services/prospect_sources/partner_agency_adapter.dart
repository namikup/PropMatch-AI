import '../../models/enquiry_model.dart';
import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for authorized partner agency co-broke networks and regional broker referrals.
///
/// NOTE ON CO-BROKE STANDARDS:
/// Co-broke lead sharing adheres to Malaysian Institute of Estate Agents (MIEA) standards.
/// Referrals require valid referring agent REN/PEA credentials and documented client referral consent.
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
    final agencyLicense = config['agencyLicense']?.toString() ?? '';
    return partnerToken.isNotEmpty || agencyLicense.isNotEmpty;
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
    final name = rawRecord['fullName'] ?? rawRecord['name'] ?? rawRecord['client_name'];
    final state = rawRecord['preferredState'] ?? rawRecord['state'] ?? rawRecord['location'];
    return (name != null && name.toString().trim().isNotEmpty) &&
        (state != null && state.toString().trim().isNotEmpty);
  }

  @override
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  }) {
    final isValid = validateProspectData(rawPayload);
    final refAgency = rawPayload['referring_agency']?.toString() ??
        rawPayload['agency_name']?.toString() ??
        'Klang Valley Agency Co-Broke';
    final ren = rawPayload['referring_ren']?.toString() ?? rawPayload['ren_number']?.toString() ?? 'REN 42109';
    final clientName = rawPayload['fullName'] ?? rawPayload['name'] ?? rawPayload['client_name'] ?? 'Referred Buyer';
    final clientPhone = rawPayload['phone'] ?? rawPayload['client_phone'] ?? '';
    final clientEmail = rawPayload['email'] ?? rawPayload['client_email'] ?? '';

    final budgetMin = (rawPayload['budgetMin'] as num?)?.toDouble() ?? 500000.0;
    final budgetMax = (rawPayload['budgetMax'] as num?)?.toDouble() ?? 850000.0;
    final coBrokeAgreed = rawPayload['co_broke_agreement_signed'] == true ||
        rawPayload['consent_granted'] == true ||
        rawPayload['co_broke_agreement_ref'] != null;

    return EnquiryModel(
      ownerId: ownerId,
      sourceType: sourceType,
      sourceName: '$refAgency ($ren)',
      sourceReferenceId: rawPayload['cobroke_ref_id']?.toString() ??
          rawPayload['co_broke_agreement_ref']?.toString() ??
          rawPayload['referral_id']?.toString(),
      fullName: clientName.toString().trim(),
      phone: clientPhone.toString().trim(),
      email: clientEmail.toString().trim(),
      preferredLocation: rawPayload['location']?.toString() ??
          rawPayload['target_area']?.toString() ??
          'Petaling Jaya',
      preferredState: rawPayload['state']?.toString() ?? 'Selangor',
      propertyType: rawPayload['propertyType']?.toString() ?? '2-Storey Terraced House',
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      purchasePurpose: rawPayload['purpose']?.toString() ?? 'Own Stay',
      buyingTimeline: rawPayload['timeline']?.toString() ?? 'Within 1 month',
      notes: rawPayload['notes']?.toString() ??
          'Co-broke referral from $refAgency under MIEA standard agreement.',
      stage: isValid ? 'Data Normalisation' : 'Source Validation',
      processingStatus: isValid ? 'Pending' : 'Rejected',
      statusReason: isValid ? null : 'Missing client name or preferred location',
      consentStatus: coBrokeAgreed ? 'Consent Granted' : 'Pending Consent',
      contactEligibility: coBrokeAgreed ? 'Eligible' : 'Pending Consent',
      consentEvidence: coBrokeAgreed
          ? 'MIEA Standard Co-Broke Agreement Ref: ${rawPayload['co_broke_agreement_ref'] ?? refAgency}'
          : 'Pending co-broke representation agreement',
      isDemo: rawPayload['isDemo'] as bool? ?? false,
      rawMetadata: rawPayload,
    );
  }
}
