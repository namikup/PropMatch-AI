import '../../models/prospect_model.dart';
import 'column_mapping.dart';
import 'normalizer.dart';
import 'duplicate_detector.dart';
import 'consent_mapper.dart';
import 'file_parser.dart';

enum RowValidationStatus {
  valid,
  warning,
  duplicate,
  invalid,
}

class ImportRowValidation {
  final int rowIndex;
  final RowValidationStatus status;
  final List<String> errors;
  final List<String> warnings;
  final ProspectModel? candidate;
  final ParsedConsentResult consentResult;
  final DuplicateMatchInfo duplicateInfo;
  final Map<String, dynamic> rawValues;

  const ImportRowValidation({
    required this.rowIndex,
    required this.status,
    required this.errors,
    required this.warnings,
    this.candidate,
    required this.consentResult,
    required this.duplicateInfo,
    required this.rawValues,
  });

  bool get isValid => status == RowValidationStatus.valid;
  bool get hasWarning => status == RowValidationStatus.warning;
  bool get isDuplicate => status == RowValidationStatus.duplicate;
  bool get isInvalid => status == RowValidationStatus.invalid;
}

class ImportPreviewReport {
  final String fileName;
  final int totalRows;
  final int validCount;
  final int warningCount;
  final int duplicateCount;
  final int invalidCount;
  final int consentReviewCount;
  final List<ImportRowValidation> rows;

  const ImportPreviewReport({
    required this.fileName,
    required this.totalRows,
    required this.validCount,
    required this.warningCount,
    required this.duplicateCount,
    required this.invalidCount,
    required this.consentReviewCount,
    required this.rows,
  });

  bool get hasExecutableRows => (validCount + warningCount) > 0;

  /// Generates a privacy-compliant CSV error report masking all personal information (PII).
  String generateErrorReportCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Row Number,Status,Candidate Name,Phone (Masked),Email (Masked),Issues');

    for (final r in rows) {
      if (r.errors.isEmpty && r.warnings.isEmpty && !r.isDuplicate) continue;

      final rawName = (r.candidate?.fullName ?? r.rawValues['fullName']?.toString() ?? '').trim();
      final maskedName = rawName.isNotEmpty ? _maskName(rawName) : 'Unknown';

      final rawPhone = (r.candidate?.phone.isNotEmpty == true
              ? r.candidate!.phone
              : r.rawValues['phone']?.toString() ?? '')
          .trim();
      final phone = rawPhone.isNotEmpty ? _maskPhone(rawPhone) : 'N/A';

      final rawEmail = (r.candidate?.email.isNotEmpty == true
              ? r.candidate!.email
              : r.rawValues['email']?.toString() ?? '')
          .trim();
      final email = rawEmail.isNotEmpty ? _maskEmail(rawEmail) : 'N/A';

      final issues = [...r.errors, ...r.warnings];
      if (r.isDuplicate) {
        issues.add('Duplicate: ${r.duplicateInfo.matchedField}');
      }

      final cleanIssues = _scrubPiiFromIssues(issues.join('; ')).replaceAll('"', '""');
      buffer.writeln('${r.rowIndex},${r.status.name},"$maskedName","$phone","$email","$cleanIssues"');
    }

    return buffer.toString();
  }

  static String _maskName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Unknown';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.map((p) {
      if (p.length <= 2) return '${p[0]}*';
      return '${p[0]}***${p[p.length - 1]}';
    }).join(' ');
  }

  static String _maskPhone(String phone) {
    final clean = phone.trim();
    if (clean.length <= 6) return '****';
    final prefixLen = clean.length >= 8 ? 5 : 2;
    return '${clean.substring(0, prefixLen)}****${clean.substring(clean.length - 2)}';
  }

  static String _maskEmail(String email) {
    final parts = email.trim().split('@');
    if (parts.length != 2) return '****@***';
    final user = parts[0];
    final domain = parts[1];
    final maskedUser = user.length <= 2 ? '**' : '${user[0]}***${user[user.length - 1]}';
    return '$maskedUser@$domain';
  }

  static String _scrubPiiFromIssues(String text) {
    var scrubbed = CRMDataNormalizer.scrubSensitiveIdentifiers(text);
    // Redact any embedded email addresses
    scrubbed = scrubbed.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[EMAIL-MASKED]',
    );
    // Redact any embedded phone numbers (7+ consecutive digits or +60 sequences)
    scrubbed = scrubbed.replaceAll(
      RegExp(r'(?:\+?60|0)[1-9][0-9\-\s]{6,12}'),
      '[PHONE-MASKED]',
    );
    return scrubbed;
  }
}

/// Orchestrates row-by-row validation, duplicate detection, and consent evaluation.
class CRMImportValidator {
  CRMImportValidator._();

  static ImportPreviewReport validateTable({
    required ParsedTable table,
    required ColumnMappingConfig mapping,
    required CRMDuplicateDetector duplicateDetector,
    required String ownerId,
    String? sourceName,
  }) {
    duplicateDetector.resetBatchCache();

    final headerIndices = <TargetProspectField, int>{};
    for (final entry in mapping.mappings.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        final idx = table.headers.indexOf(entry.value!);
        if (idx != -1) {
          headerIndices[entry.key] = idx;
        }
      }
    }

    final rowValidations = <ImportRowValidation>[];
    int validCount = 0;
    int warningCount = 0;
    int duplicateCount = 0;
    int invalidCount = 0;
    int consentReviewCount = 0;

    for (int i = 0; i < table.rows.length; i++) {
      final rawRow = table.rows[i];
      final rowIndex = i + 2; // 1-indexed, accounting for header row
      final errors = <String>[];
      final warnings = <String>[];

      // Extract mapped values safely
      String getCell(TargetProspectField field) {
        final colIdx = headerIndices[field];
        if (colIdx == null || colIdx >= rawRow.length) return '';
        final val = rawRow[colIdx];
        return val != null ? val.toString().trim() : '';
      }

      final rawName = getCell(TargetProspectField.fullName);
      final rawPhone = getCell(TargetProspectField.phone);
      final rawEmail = getCell(TargetProspectField.email);
      final rawBudgetMin = getCell(TargetProspectField.budgetMin);
      final rawBudgetMax = getCell(TargetProspectField.budgetMax);
      final rawLocation = getCell(TargetProspectField.preferredLocation);
      final rawState = getCell(TargetProspectField.preferredState);
      final rawType = getCell(TargetProspectField.propertyType);
      final rawPurpose = getCell(TargetProspectField.purchasePurpose);
      final rawTimeline = getCell(TargetProspectField.buyingTimeline);
      final rawSourceRef = getCell(TargetProspectField.sourceReference);
      final rawConsent = getCell(TargetProspectField.consentStatus);
      final rawEvidence = getCell(TargetProspectField.consentEvidence);
      final rawNotes = getCell(TargetProspectField.notes);

      final rawValues = {
        'fullName': rawName,
        'phone': rawPhone,
        'email': rawEmail,
        'location': rawLocation,
      };

      // 1. Validate Required Identity: Full Name
      if (rawName.isEmpty) {
        errors.add('Prospect name is missing.');
      } else if (rawName.length < 2) {
        errors.add('Prospect name is too short (minimum 2 characters).');
      }

      // 2. Validate Contact Channel: At least one valid phone or email is required
      final isPhoneEmpty = CRMDataNormalizer.isPlaceholderOrEmpty(rawPhone);
      final isEmailEmpty = CRMDataNormalizer.isPlaceholderOrEmpty(rawEmail);
      final normPhone = CRMDataNormalizer.normalizePhone(rawPhone);
      final normEmail = CRMDataNormalizer.normalizeEmail(rawEmail);

      if (isPhoneEmpty && isEmailEmpty) {
        errors.add('At least one contact identifier (Phone or Email) must be provided.');
      } else if (!normPhone.isValid && !normEmail.isValid) {
        errors.add('No valid contact identifier found. Provide a valid Malaysian phone number or email address.');
      } else {
        if (!isPhoneEmpty && !normPhone.isValid) {
          warnings.add(normPhone.error ?? 'Invalid phone number format.');
        }
        if (!isEmailEmpty && !normEmail.isValid) {
          warnings.add(normEmail.error ?? 'Invalid email address syntax.');
        }
      }

      // 3. Normalize Budget Bounds
      final normBudget = CRMDataNormalizer.normalizeBudget(
        minRaw: rawBudgetMin,
        maxRaw: rawBudgetMax,
      );
      if (normBudget.isDefaulted && rawBudgetMin.isEmpty && rawBudgetMax.isEmpty) {
        warnings.add('No budget provided; assigned default bracket (RM 400k - RM 750k).');
      } else if (normBudget.isDefaulted && (rawBudgetMin.isNotEmpty || rawBudgetMax.isNotEmpty)) {
        warnings.add('Unparseable budget value; assigned default bracket (RM 400k - RM 750k).');
      }

      // 4. Infer Location & State
      final location = rawLocation.isNotEmpty ? rawLocation : 'Penang';
      final state = rawState.isNotEmpty
          ? rawState
          : CRMDataNormalizer.inferStateFromLocation(location);

      // 5. Evaluate Duplicate Status (Agent-Scoped, using ONLY valid canonical contact keys)
      final duplicateInfo = duplicateDetector.checkDuplicate(
        canonicalPhone: normPhone.isValid ? normPhone.canonical : '',
        canonicalEmail: normEmail.isValid ? normEmail.canonical : '',
        rowIndex: rowIndex,
      );

      // 6. Deterministic Prospect ID for Idempotent Retries
      final contactKey = normPhone.isValid
          ? normPhone.canonical
          : (normEmail.isValid ? normEmail.canonical : rawName.toLowerCase());
      final prospectId = _generateDeterministicProspectId(
        ownerId: ownerId,
        fileName: table.fileName,
        rowIndex: rowIndex,
        contactKey: contactKey,
      );

      // 7. Evaluate Consent & Contact Eligibility
      final consentResult = CRMConsentMapper.evaluateConsent(
        ownerId: ownerId,
        prospectId: prospectId,
        rawConsentStatus: rawConsent,
        rawConsentEvidence: rawEvidence,
        sourceName: sourceName ?? 'CRM File Import',
      );

      if (consentResult.requiresConsentReview) {
        consentReviewCount++;
        warnings.add(consentResult.complianceNote ?? 'Consent review required.');
      }

      // Determine Overall Status
      RowValidationStatus rowStatus;
      if (errors.isNotEmpty) {
        rowStatus = RowValidationStatus.invalid;
        invalidCount++;
      } else if (duplicateInfo.isDuplicate) {
        rowStatus = RowValidationStatus.duplicate;
        duplicateCount++;
      } else if (warnings.isNotEmpty) {
        rowStatus = RowValidationStatus.warning;
        warningCount++;
      } else {
        rowStatus = RowValidationStatus.valid;
        validCount++;
      }

      // Build Candidate Prospect Model if not invalid
      ProspectModel? candidate;
      if (errors.isEmpty) {
        final sanitizedNotes = CRMDataNormalizer.scrubSensitiveIdentifiers(
          rawNotes.isNotEmpty ? rawNotes : 'Imported via CRM file (${table.fileName}).',
        );

        candidate = ProspectModel(
          id: prospectId,
          ownerId: ownerId,
          fullName: rawName,
          phone: normPhone.isValid ? normPhone.canonical : '',
          email: normEmail.isValid ? normEmail.canonical : '',
          icNumber: null, // Data minimization: never collect NRIC via CRM import
          preferredLocations: [location],
          preferredState: state,
          propertyTypes: rawType.isNotEmpty ? [rawType] : const ['Condominium'],
          budgetMin: normBudget.min,
          budgetMax: normBudget.max,
          purchasePurpose: rawPurpose.isNotEmpty ? rawPurpose : 'Own Stay',
          buyingTimeline: rawTimeline.isNotEmpty ? rawTimeline : 'Within 3 months',
          status: 'Imported',
          // Verification must remain separate from syntax validation & contact eligibility
          verificationStatus: 'Unverified',
          contactEligibility: consentResult.contactEligibility,
          consentedPurposes: consentResult.consentedPurposes,
          consentedChannels: consentResult.consentedChannels,
          primarySource: 'CRM Import',
          primarySourceId: rawSourceRef.isNotEmpty ? rawSourceRef : null,
          confidenceScore: normPhone.isValid && normEmail.isValid ? 85.0 : 70.0,
          notes: sanitizedNotes,
          isDemo: false,
          tags: [
            if (duplicateInfo.isDuplicate) 'Duplicate Reference',
            if (consentResult.requiresConsentReview) 'Consent Verification Needed',
          ],
        );
      }

      rowValidations.add(
        ImportRowValidation(
          rowIndex: rowIndex,
          status: rowStatus,
          errors: errors,
          warnings: warnings,
          candidate: candidate,
          consentResult: consentResult,
          duplicateInfo: duplicateInfo,
          rawValues: rawValues,
        ),
      );
    }

    return ImportPreviewReport(
      fileName: table.fileName,
      totalRows: table.rows.length,
      validCount: validCount,
      warningCount: warningCount,
      duplicateCount: duplicateCount,
      invalidCount: invalidCount,
      consentReviewCount: consentReviewCount,
      rows: rowValidations,
    );
  }

  /// Generates a deterministic, URL/Firestore-safe ID from ownerId, file, row, and contact key.
  static String _generateDeterministicProspectId({
    required String ownerId,
    required String fileName,
    required int rowIndex,
    required String contactKey,
  }) {
    final seed = '$ownerId|$fileName|$rowIndex|$contactKey';
    int hash1 = 0x811c9dc5;
    int hash2 = 0x01000193;
    for (int i = 0; i < seed.length; i++) {
      final code = seed.codeUnitAt(i);
      hash1 ^= code;
      hash1 = (hash1 * 0x01000193) & 0x7fffffff;
      hash2 ^= (code + i);
      hash2 = (hash2 * 0x811c9dc5) & 0x7fffffff;
    }
    return 'pros-imp-${hash1.toRadixString(16)}-${hash2.toRadixString(16)}-$rowIndex';
  }
}
