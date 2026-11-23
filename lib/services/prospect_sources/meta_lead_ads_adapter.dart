import 'package:uuid/uuid.dart';
import '../../models/prospect_model.dart';
import '../../models/enquiry_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter for Meta Facebook & Instagram Lead Ads (Instant Forms).
/// Maps Meta leadgen payloads into standardized [EnquiryModel] and [ProspectModel].
class MetaLeadAdsAdapter implements ProspectSourceAdapter {
  @override
  String get sourceName => 'Meta Facebook & Instagram Lead Ads';

  @override
  String get sourceType => 'Facebook Lead Ads';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    final adAccountId = config['adAccountId'] as String?;
    final pageId = config['pageId'] as String?;
    return (adAccountId != null && adAccountId.isNotEmpty) ||
        (pageId != null && pageId.isNotEmpty);
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['full_name'] ?? rawRecord['name'];
    final phone = rawRecord['phone'] ?? rawRecord['phone_number'] ?? rawRecord['contact_number'];
    final email = rawRecord['email'];

    if (name == null || name.toString().trim().isEmpty) return false;
    final hasPhone = phone != null && phone.toString().trim().length >= 8;
    final hasEmail = email != null && email.toString().contains('@');
    return hasPhone || hasEmail;
  }

  @override
  EnquiryModel parseEnquiry({
    required String ownerId,
    required Map<String, dynamic> rawPayload,
  }) {
    final leadId = rawPayload['leadgenId'] ?? rawPayload['leadgen_id'] ?? const Uuid().v4();
    final name = (rawPayload['fullName'] ?? rawPayload['full_name'] ?? rawPayload['name'] ?? 'Facebook Inquirer').toString().trim();
    final phone = (rawPayload['phone'] ?? rawPayload['phone_number'] ?? '').toString().trim();
    final email = (rawPayload['email'] ?? '').toString().trim().toLowerCase();
    final location = (rawPayload['preferredLocation'] ?? rawPayload['city'] ?? rawPayload['location'] ?? 'Penang').toString().trim();
    final propertyType = (rawPayload['propertyType'] ?? rawPayload['property_type'] ?? 'Terrace House').toString().trim();

    double budgetMax = 0.0;
    if (rawPayload['budgetMax'] != null) {
      budgetMax = (rawPayload['budgetMax'] as num).toDouble();
    } else if (rawPayload['budget'] != null) {
      final rawBudget = rawPayload['budget'].toString();
      final match = RegExp(r'(\d[\d,\.]*)').firstMatch(rawBudget);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
        budgetMax = parsed < 1000 ? parsed * 1000 : parsed;
      }
    }
    if (budgetMax <= 0) budgetMax = 750000.0;

    final campaignId = (rawPayload['campaignId'] ?? rawPayload['campaign_id'] ?? 'meta-camp-pilot-001').toString();
    final formId = (rawPayload['formId'] ?? rawPayload['form_id'] ?? 'meta-form-001').toString();
    final adId = rawPayload['adId'] ?? rawPayload['ad_id'];

    return EnquiryModel(
      ownerId: ownerId,
      assignedAgentId: ownerId,
      sourceType: 'Facebook Lead Ads',
      sourceName: 'Meta Instant Form',
      sourceReferenceId: leadId.toString(),
      fullName: name,
      phone: phone,
      email: email,
      preferredLocation: location,
      preferredState: 'Penang',
      propertyType: propertyType,
      budgetMin: budgetMax * 0.8,
      budgetMax: budgetMax,
      purchasePurpose: (rawPayload['purchasePurpose'] ?? rawPayload['purpose'] ?? 'Own Stay').toString(),
      buyingTimeline: (rawPayload['buyingTimeline'] ?? rawPayload['timeline'] ?? 'Within 3 months').toString(),
      notes: 'Captured via Meta Instant Form (Form ID: $formId, Ad ID: ${adId ?? "N/A"})',
      campaignId: campaignId,
      referralSource: 'Meta Instant Form: $formId',
      utmSource: 'facebook',
      utmMedium: 'paid_lead_ad',
      utmCampaign: (rawPayload['utmCampaign'] ?? 'penang_landed_pilot').toString(),
      enquiryConsentGranted: true, // Submitted via form
      marketingConsentGranted: false, // Explicit opt-in only
      consentEvidence: 'Meta Instant Form Submission (ID: $leadId) with Privacy Policy Checkbox',
      contactEligibility: 'Eligible',
      processingStatus: 'Received',
    );
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    // Lead retrieval in Meta Ads is push-based via Webhooks or manual Instant Form sync.
    return [];
  }
}
