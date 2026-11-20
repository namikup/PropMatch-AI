import '../../models/prospect_model.dart';
import '../../models/buyer_model.dart';
import 'normalizer.dart';

enum DuplicateType {
  none,
  existingProspect,
  existingBuyer,
  intraFileDuplicate,
}

enum DuplicateResolutionStrategy {
  skip,
  merge,
  importAnyway,
}

class DuplicateMatchInfo {
  final DuplicateType type;
  final String? matchedId;
  final String? matchedName;
  final String matchedField; // 'Phone', 'Email', 'Both (Phone & Email)'
  final String? originalOwnerId;

  const DuplicateMatchInfo({
    required this.type,
    this.matchedId,
    this.matchedName,
    required this.matchedField,
    this.originalOwnerId,
  });

  bool get isDuplicate => type != DuplicateType.none;
}

/// Agent-scoped duplicate detection engine ensuring strict multi-tenant isolation.
class CRMDuplicateDetector {
  final String currentOwnerId;
  final Map<String, ProspectModel> _existingProspectsByPhone = {};
  final Map<String, ProspectModel> _existingProspectsByEmail = {};
  final Map<String, BuyerModel> _existingBuyersByPhone = {};
  final Map<String, BuyerModel> _existingBuyersByEmail = {};

  final Set<String> _intraBatchSeenPhones = {};
  final Set<String> _intraBatchSeenEmails = {};

  CRMDuplicateDetector({
    required this.currentOwnerId,
    required List<ProspectModel> existingProspects,
    required List<BuyerModel> existingBuyers,
  }) {
    if (currentOwnerId.trim().isEmpty) {
      return;
    }

    // STRICT TENANT ISOLATION: Only index records strictly belonging to current agent
    for (final prospect in existingProspects) {
      if (prospect.ownerId != currentOwnerId) continue;

      final normPhone = CRMDataNormalizer.normalizePhone(prospect.phone);
      if (normPhone.isValid && normPhone.canonical.isNotEmpty) {
        _existingProspectsByPhone[normPhone.canonical] = prospect;
      }

      final normEmail = CRMDataNormalizer.normalizeEmail(prospect.email);
      if (normEmail.isValid && normEmail.canonical.isNotEmpty) {
        _existingProspectsByEmail[normEmail.canonical] = prospect;
      }
    }

    for (final buyer in existingBuyers) {
      if (buyer.ownerId != currentOwnerId) continue;

      final normPhone = CRMDataNormalizer.normalizePhone(buyer.phone);
      if (normPhone.isValid && normPhone.canonical.isNotEmpty) {
        _existingBuyersByPhone[normPhone.canonical] = buyer;
      }

      final normEmail = CRMDataNormalizer.normalizeEmail(buyer.email);
      if (normEmail.isValid && normEmail.canonical.isNotEmpty) {
        _existingBuyersByEmail[normEmail.canonical] = buyer;
      }
    }
  }

  /// Evaluates a candidate record for duplicates against agent database and earlier batch rows.
  /// Automatically normalizes inputs so different Malaysian phone formats or email casings match reliably.
  DuplicateMatchInfo checkDuplicate({
    String? canonicalPhone,
    String? canonicalEmail,
    String? phone,
    String? email,
    int rowIndex = 0,
  }) {
    final rawPhoneInput = canonicalPhone ?? phone ?? '';
    final rawEmailInput = canonicalEmail ?? email ?? '';

    final normPhone = CRMDataNormalizer.normalizePhone(rawPhoneInput);
    final normEmail = CRMDataNormalizer.normalizeEmail(rawEmailInput);

    final validPhone = normPhone.isValid ? normPhone.canonical : '';
    final validEmail = normEmail.isValid ? normEmail.canonical : '';

    final hasPhone = validPhone.isNotEmpty;
    final hasEmail = validEmail.isNotEmpty;

    if (!hasPhone && !hasEmail) {
      return const DuplicateMatchInfo(
        type: DuplicateType.none,
        matchedField: 'None',
      );
    }

    // 1. Check against agent's existing prospects
    final prospectPhoneMatch = hasPhone ? _existingProspectsByPhone[validPhone] : null;
    final prospectEmailMatch = hasEmail ? _existingProspectsByEmail[validEmail] : null;

    if (prospectPhoneMatch != null || prospectEmailMatch != null) {
      final matchedProspect = prospectPhoneMatch ?? prospectEmailMatch!;
      final matchedField = (prospectPhoneMatch != null && prospectEmailMatch != null)
          ? 'Both (Phone & Email)'
          : (prospectPhoneMatch != null ? 'Phone' : 'Email');

      // Also record in intra-batch seen sets so subsequent duplicate rows in same file are caught
      if (hasPhone) _intraBatchSeenPhones.add(validPhone);
      if (hasEmail) _intraBatchSeenEmails.add(validEmail);

      return DuplicateMatchInfo(
        type: DuplicateType.existingProspect,
        matchedId: matchedProspect.id,
        matchedName: matchedProspect.fullName,
        matchedField: matchedField,
        originalOwnerId: currentOwnerId,
      );
    }

    // 2. Check against agent's existing CRM buyers
    final buyerPhoneMatch = hasPhone ? _existingBuyersByPhone[validPhone] : null;
    final buyerEmailMatch = hasEmail ? _existingBuyersByEmail[validEmail] : null;

    if (buyerPhoneMatch != null || buyerEmailMatch != null) {
      final matchedBuyer = buyerPhoneMatch ?? buyerEmailMatch!;
      final matchedField = (buyerPhoneMatch != null && buyerEmailMatch != null)
          ? 'Both (Phone & Email)'
          : (buyerPhoneMatch != null ? 'Phone' : 'Email');

      if (hasPhone) _intraBatchSeenPhones.add(validPhone);
      if (hasEmail) _intraBatchSeenEmails.add(validEmail);

      return DuplicateMatchInfo(
        type: DuplicateType.existingBuyer,
        matchedId: matchedBuyer.id,
        matchedName: matchedBuyer.name,
        matchedField: matchedField,
        originalOwnerId: currentOwnerId,
      );
    }

    // 3. Check intra-file duplicate (same contact info appears in multiple rows of same upload)
    final isIntraPhone = hasPhone && _intraBatchSeenPhones.contains(validPhone);
    final isIntraEmail = hasEmail && _intraBatchSeenEmails.contains(validEmail);

    if (isIntraPhone || isIntraEmail) {
      final matchedField = (isIntraPhone && isIntraEmail)
          ? 'Both (Phone & Email)'
          : (isIntraPhone ? 'Phone' : 'Email');

      if (hasPhone) _intraBatchSeenPhones.add(validPhone);
      if (hasEmail) _intraBatchSeenEmails.add(validEmail);

      return DuplicateMatchInfo(
        type: DuplicateType.intraFileDuplicate,
        matchedField: 'Intra-File Duplicate ($matchedField)',
      );
    }

    // Track for subsequent intra-batch rows
    if (hasPhone) _intraBatchSeenPhones.add(validPhone);
    if (hasEmail) _intraBatchSeenEmails.add(validEmail);

    return const DuplicateMatchInfo(
      type: DuplicateType.none,
      matchedField: 'None',
    );
  }

  /// Resets intra-file tracking cache if re-evaluating.
  void resetBatchCache() {
    _intraBatchSeenPhones.clear();
    _intraBatchSeenEmails.clear();
  }
}
