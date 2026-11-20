import '../../models/prospect_consent_event_model.dart';

/// Detailed result of evaluating source-provided consent markers.
class ParsedConsentResult {
  final String contactEligibility; // 'Pending Consent', 'Eligible', 'Do Not Contact', 'Ineligible'
  final List<String> consentedPurposes; // e.g. ['Direct Inquiry Response']
  final List<String> consentedChannels; // e.g. ['WhatsApp'], ['Email']
  final bool requiresConsentReview;
  final String? complianceNote;
  final ProspectConsentEventModel? consentEvent;

  const ParsedConsentResult({
    required this.contactEligibility,
    this.consentedPurposes = const [],
    this.consentedChannels = const [],
    required this.requiresConsentReview,
    this.complianceNote,
    this.consentEvent,
  });

  bool get permitsBroadMarketing =>
      contactEligibility == 'Eligible' &&
      consentedPurposes.contains('Marketing & Promotion');
}

/// Evaluates source data for consent indicators while strictly enforcing opt-in rules.
class CRMConsentMapper {
  CRMConsentMapper._();

  /// Maps source consent values to a compliant [ParsedConsentResult].
  ///
  /// STRICT RULES:
  /// 1. All records default to 'Pending Consent' unless explicit documented
  ///    evidence of granted permission is present.
  /// 2. Generic checkboxes or boolean 'true' without supporting evidence remain
  ///    flagged as 'Pending Consent'.
  /// 3. Consent is scoped to its specific purpose and communication channel;
  ///    a 'Direct Inquiry Response' grant does NOT grant broad marketing eligibility.
  static ParsedConsentResult evaluateConsent({
    required String ownerId,
    required String prospectId,
    dynamic rawConsentStatus,
    dynamic rawConsentEvidence,
    String? sourceName,
    String? explicitPurpose,
    List<String>? explicitChannels,
  }) {
    final statusStr = rawConsentStatus?.toString().trim().toLowerCase() ?? '';
    final evidenceStr = rawConsentEvidence?.toString().trim() ?? '';
    final effectiveSource = (sourceName != null && sourceName.trim().isNotEmpty)
        ? sourceName.trim()
        : 'CRM File Import';

    final inferredPurpose = (explicitPurpose != null && explicitPurpose.trim().isNotEmpty)
        ? explicitPurpose.trim()
        : _inferPurpose('$statusStr $evidenceStr');

    final inferredChannels = (explicitChannels != null && explicitChannels.isNotEmpty)
        ? explicitChannels
        : _inferChannels('$effectiveSource $evidenceStr');

    // Deterministic consent event ID tied to prospectId so retries are idempotent
    final deterministicConsentId = 'cst-$prospectId';

    // 1. Explicit Opt-Out / DNC detected
    if (_isOptOut(statusStr) || _hasOptOutEvidence(evidenceStr)) {
      final now = DateTime.now();
      final consentEvent = ProspectConsentEventModel(
        id: deterministicConsentId,
        ownerId: ownerId,
        prospectId: prospectId,
        consentType: 'Marketing & Promotion',
        purpose: 'Marketing & Promotion',
        communicationChannels: const ['All'],
        status: 'Withdrawn',
        source: effectiveSource,
        evidenceText: evidenceStr.isNotEmpty
            ? evidenceStr
            : 'Opt-out signal recorded in imported CRM dataset.',
        consentTimestamp: now,
        withdrawalTimestamp: now,
      );

      return ParsedConsentResult(
        contactEligibility: 'Do Not Contact',
        consentedPurposes: const [],
        consentedChannels: const [],
        requiresConsentReview: false,
        complianceNote: 'Explicit opt-out detected in source data. Marked as Do Not Contact.',
        consentEvent: consentEvent,
      );
    }

    // 2. Explicit Opt-In detected
    if (_isOptIn(statusStr)) {
      final hasVerifiableEvidence = evidenceStr.length >= 8 &&
          !_isGenericPlaceholder(evidenceStr);

      if (hasVerifiableEvidence) {
        final consentEvent = ProspectConsentEventModel(
          id: deterministicConsentId,
          ownerId: ownerId,
          prospectId: prospectId,
          consentType: inferredPurpose,
          purpose: inferredPurpose,
          communicationChannels: inferredChannels,
          status: 'Granted',
          source: effectiveSource,
          evidenceText: evidenceStr,
          consentTimestamp: DateTime.now(),
        );

        // Non-communication consent (e.g. Third-Party Sharing alone) does NOT establish direct contact eligibility
        final establishesContactEligibility =
            inferredPurpose == 'Direct Inquiry Response' ||
            inferredPurpose == 'Property Recommendations' ||
            inferredPurpose == 'Marketing & Promotion';

        if (!establishesContactEligibility) {
          return ParsedConsentResult(
            contactEligibility: 'Pending Consent',
            consentedPurposes: [inferredPurpose],
            consentedChannels: const [],
            requiresConsentReview: true,
            complianceNote:
                'Granted consent for "$inferredPurpose" does not authorize direct buyer outreach. Retained as Pending Consent.',
            consentEvent: consentEvent,
          );
        }

        return ParsedConsentResult(
          contactEligibility: 'Eligible',
          consentedPurposes: [inferredPurpose],
          consentedChannels: inferredChannels,
          requiresConsentReview: false,
          complianceNote:
              'Documented opt-in evidence verified for purpose "$inferredPurpose" via [${inferredChannels.join(', ')}].',
          consentEvent: consentEvent,
        );
      } else {
        // Generic boolean marker without verifiable evidence: DO NOT grant contact eligibility!
        final consentEvent = ProspectConsentEventModel(
          id: deterministicConsentId,
          ownerId: ownerId,
          prospectId: prospectId,
          consentType: inferredPurpose,
          purpose: inferredPurpose,
          communicationChannels: inferredChannels,
          status: 'Pending Verification',
          source: effectiveSource,
          evidenceText: evidenceStr.isNotEmpty
              ? evidenceStr
              : 'Generic consent marker present in source without verifiable audit trail.',
        );

        return ParsedConsentResult(
          contactEligibility: 'Pending Consent',
          consentedPurposes: const [],
          consentedChannels: const [],
          requiresConsentReview: true,
          complianceNote:
              'Generic opt-in marker detected without documented proof. Retained as Pending Consent under PDPA guidelines.',
          consentEvent: consentEvent,
        );
      }
    }

    // 3. Default: No consent supplied -> Strict Pending Consent
    return const ParsedConsentResult(
      contactEligibility: 'Pending Consent',
      consentedPurposes: [],
      consentedChannels: [],
      requiresConsentReview: false,
      complianceNote: 'No source consent records supplied. Defaulted to Pending Consent.',
      consentEvent: null,
    );
  }

  static String _inferPurpose(String combinedText) {
    final lower = combinedText.toLowerCase();
    if (lower.contains('third-party') || lower.contains('third party') || lower.contains('partner sharing')) {
      return 'Third-Party Sharing';
    }
    if (lower.contains('marketing') ||
        lower.contains('promotion') ||
        lower.contains('promotional') ||
        lower.contains('newsletter') ||
        lower.contains('broadcast')) {
      return 'Marketing & Promotion';
    }
    if (lower.contains('recommendation')) {
      return 'Property Recommendations';
    }
    return 'Direct Inquiry Response';
  }

  static List<String> _inferChannels(String combinedText) {
    final lower = combinedText.toLowerCase();
    final channels = <String>[];
    if (lower.contains('whatsapp')) channels.add('WhatsApp');
    if (lower.contains('email') || lower.contains('e-mail')) channels.add('Email');
    if (lower.contains('sms')) channels.add('SMS');
    if (lower.contains('call') || lower.contains('phone') || lower.contains('tel')) {
      channels.add('Phone');
    }
    if (channels.isEmpty) {
      channels.add('Direct Inquiry Channel');
    }
    return List<String>.unmodifiable(channels);
  }

  static bool _isOptIn(String status) {
    final clean = status.trim().toLowerCase();
    if (clean.isEmpty) return false;
    const optInKeywords = {
      'granted',
      'yes',
      'true',
      'opt_in',
      'optin',
      'opt-in',
      'opted in',
      'opted_in',
      'opted-in',
      'agreed',
      'agree',
      'subscribed',
      'setuju',
      '1',
    };
    if (optInKeywords.contains(clean)) return true;
    return clean.startsWith('opted in') || clean.startsWith('granted');
  }

  static bool _isOptOut(String status) {
    final clean = status.trim().toLowerCase();
    if (clean.isEmpty) return false;
    const optOutKeywords = {
      'withdrawn',
      'no',
      'false',
      'opt_out',
      'optout',
      'opt-out',
      'opted out',
      'opted_out',
      'opted-out',
      'dnc',
      'do not contact',
      'unsubscribed',
      'unsubscribe',
      'batal',
      '0',
      'reject',
      'rejected',
      'revoked',
      'revoke',
      'stop',
    };
    if (optOutKeywords.contains(clean)) return true;
    return clean.contains('opt out') ||
        clean.contains('opted out') ||
        clean.contains('opt-out') ||
        clean.contains('do not contact') ||
        clean.contains('withdrawn') ||
        clean.contains('unsubscribed');
  }

  static bool _hasOptOutEvidence(String evidence) {
    final lower = evidence.toLowerCase();
    return lower.contains('do not contact') ||
        lower.contains('requested removal') ||
        lower.contains('unsubscribed') ||
        lower.contains('withdrew consent');
  }

  static bool _isGenericPlaceholder(String evidence) {
    final lower = evidence.toLowerCase().trim();
    const genericTokens = {
      'yes',
      'true',
      'ok',
      'consent',
      'consented',
      'agreed',
      'agree',
      'opt in',
      'opted in',
      'opt-in',
      'opt_in',
      'granted',
      'checked',
      'ticked',
      'verified',
      'approved',
      'default',
      'imported',
      'n/a',
      'na',
      'none',
      'nil',
      '1',
      'y',
    };
    return genericTokens.contains(lower);
  }
}
