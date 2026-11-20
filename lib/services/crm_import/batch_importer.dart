import '../../models/prospect_model.dart';
import '../../models/prospect_import_job_model.dart';
import '../../models/prospect_activity_model.dart';
import '../../models/prospect_consent_event_model.dart';
import '../../repositories/prospect_repository.dart';
import 'import_validator.dart';
import 'duplicate_detector.dart';
import 'normalizer.dart';

class BatchImportProgress {
  final int current;
  final int total;
  final String currentOperation;

  const BatchImportProgress({
    required this.current,
    required this.total,
    required this.currentOperation,
  });

  double get percentage => total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
}

class BatchImportResult {
  final String jobId;
  final int totalRows;
  final int importedCount;
  final int skippedDuplicatesCount;
  final int mergedCount;
  final int errorCount;
  final List<ProspectModel> importedProspects;
  final ProspectImportJobModel job;

  const BatchImportResult({
    required this.jobId,
    required this.totalRows,
    required this.importedCount,
    required this.skippedDuplicatesCount,
    required this.mergedCount,
    required this.errorCount,
    required this.importedProspects,
    required this.job,
  });
}

/// Executes reliable, idempotent batch persistence of validated prospect records.
class CRMBatchImporter {
  static final Set<String> _inFlightOwnerLocks = <String>{};

  final ProspectRepository repository;
  final String ownerId;

  CRMBatchImporter({
    required this.repository,
    required this.ownerId,
  }) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('CRMBatchImporter requires a non-empty authenticated ownerId.');
    }
  }

  Future<BatchImportResult> executeImport({
    required ImportPreviewReport preview,
    required DuplicateResolutionStrategy duplicateStrategy,
    String? jobId,
    void Function(BatchImportProgress progress)? onProgress,
  }) async {
    final sanitizedFileName = _sanitizeSourceName(preview.fileName);
    final effectiveJobId = (jobId != null && jobId.trim().isNotEmpty)
        ? jobId.trim()
        : 'job-${DateTime.now().millisecondsSinceEpoch}';

    final lockKey = '$ownerId:$effectiveJobId';
    if (_inFlightOwnerLocks.contains(lockKey)) {
      throw StateError('Import job $effectiveJobId is already currently executing.');
    }
    _inFlightOwnerLocks.add(lockKey);

    try {
      // 0. Check if this exact jobId was already completed (idempotent replay check)
      final existingJobs = await repository.getImportJobs(ownerId: ownerId);
      final completedMatch = existingJobs.where(
        (j) => j.id == effectiveJobId && j.ownerId == ownerId && j.isCompleted,
      );
      if (completedMatch.isNotEmpty) {
        final existingJob = completedMatch.first;
        return BatchImportResult(
          jobId: existingJob.id,
          totalRows: existingJob.totalRecords,
          importedCount: existingJob.importedCount,
          skippedDuplicatesCount: existingJob.duplicateCount,
          mergedCount: 0,
          errorCount: existingJob.errorCount,
          importedProspects: const [],
          job: existingJob,
        );
      }

      final startedAt = DateTime.now();
      var job = ProspectImportJobModel(
        id: effectiveJobId,
        ownerId: ownerId,
        sourceId: 'src-crm-import',
        sourceName: sanitizedFileName,
        status: 'Processing',
        totalRecords: preview.totalRows,
        importedCount: 0,
        duplicateCount: 0,
        errorCount: preview.invalidCount,
        startedAt: startedAt,
      );

      onProgress?.call(
        BatchImportProgress(
          current: 0,
          total: preview.totalRows,
          currentOperation: 'Initializing import job $effectiveJobId...',
        ),
      );

      // 1. Fetch live prospects from repository to guarantee idempotency across retries
      //    and prevent duplicate creation if the same preview is executed repeatedly.
      final liveProspects = await repository.getProspects(ownerId: ownerId);
      final liveById = <String, ProspectModel>{};
      final liveByPhone = <String, ProspectModel>{};
      final liveByEmail = <String, ProspectModel>{};

      for (final p in liveProspects) {
        if (p.ownerId != ownerId) continue;
        liveById[p.id] = p;
        final normPhone = CRMDataNormalizer.normalizePhone(p.phone);
        if (normPhone.isValid && normPhone.canonical.isNotEmpty) {
          liveByPhone[normPhone.canonical] = p;
        }
        final normEmail = CRMDataNormalizer.normalizeEmail(p.email);
        if (normEmail.isValid && normEmail.canonical.isNotEmpty) {
          liveByEmail[normEmail.canonical] = p;
        }
      }

      final prospectsToCreate = <ProspectModel>[];
      final activitiesToRecord = <ProspectActivityModel>[];
      final consentsToRecord = <ProspectConsentEventModel>[];
      final createdProspects = <ProspectModel>[];

      final seenExecutionPhones = <String>{};
      final seenExecutionEmails = <String>{};
      final seenExecutionIds = <String>{};

      int skippedCount = 0;
      int mergedCount = 0;
      int errorCount = preview.invalidCount;

      for (int i = 0; i < preview.rows.length; i++) {
        final row = preview.rows[i];

        onProgress?.call(
          BatchImportProgress(
            current: i + 1,
            total: preview.totalRows,
            currentOperation: 'Processing row ${i + 1} of ${preview.totalRows}...',
          ),
        );

        // 1. Skip invalid rows
        if (row.isInvalid || row.candidate == null) {
          continue;
        }

        // Enforce ownerId strictly derived from authenticated session
        final candidate = row.candidate!.copyWith(ownerId: ownerId);

        final normPhone = CRMDataNormalizer.normalizePhone(candidate.phone);
        final normEmail = CRMDataNormalizer.normalizeEmail(candidate.email);
        final phoneKey = normPhone.isValid ? normPhone.canonical : '';
        final emailKey = normEmail.isValid ? normEmail.canonical : '';

        // 2. Check if this exact deterministic candidate ID was already persisted in a prior run/retry
        final alreadyPersistedById = liveById[candidate.id];
        if (alreadyPersistedById != null || seenExecutionIds.contains(candidate.id)) {
          skippedCount++;
          continue;
        }

        // 3. Determine live duplicate status (covering both preview-time duplicates and post-preview state changes)
        final matchedLiveProspect = (row.duplicateInfo.matchedId != null
                ? liveById[row.duplicateInfo.matchedId!]
                : null) ??
            (phoneKey.isNotEmpty ? liveByPhone[phoneKey] : null) ??
            (emailKey.isNotEmpty ? liveByEmail[emailKey] : null);

        final isIntraBatchDuplicate =
            (phoneKey.isNotEmpty && seenExecutionPhones.contains(phoneKey)) ||
            (emailKey.isNotEmpty && seenExecutionEmails.contains(emailKey));

        final isEffectiveDuplicate =
            row.isDuplicate || matchedLiveProspect != null || isIntraBatchDuplicate;

        if (isEffectiveDuplicate) {
          if (duplicateStrategy == DuplicateResolutionStrategy.skip || isIntraBatchDuplicate) {
            skippedCount++;
            continue;
          } else if (duplicateStrategy == DuplicateResolutionStrategy.merge) {
            if (matchedLiveProspect != null && matchedLiveProspect.ownerId == ownerId) {
              try {
                final merged = _mergeProspect(matchedLiveProspect, candidate);
                await repository.updateProspect(merged);

                // Update live index
                liveById[merged.id] = merged;
                if (phoneKey.isNotEmpty) liveByPhone[phoneKey] = merged;
                if (emailKey.isNotEmpty) liveByEmail[emailKey] = merged;

                // If incoming row had a consent event (e.g. withdrawal or newly documented opt-in), record it tied to existing.id
                if (row.consentResult.consentEvent != null) {
                  final incomingConsent = row.consentResult.consentEvent!;
                  final mergedConsent = ProspectConsentEventModel(
                    id: 'cst-${matchedLiveProspect.id}-${incomingConsent.status.toLowerCase()}-${row.rowIndex}',
                    ownerId: ownerId,
                    prospectId: matchedLiveProspect.id,
                    consentType: incomingConsent.consentType,
                    purpose: incomingConsent.purpose,
                    communicationChannels: incomingConsent.communicationChannels,
                    status: incomingConsent.status,
                    source: incomingConsent.source,
                    evidenceText: incomingConsent.evidenceText,
                    consentTimestamp: incomingConsent.consentTimestamp,
                    withdrawalTimestamp: incomingConsent.withdrawalTimestamp,
                  );
                  consentsToRecord.add(mergedConsent);
                }

                // Log deterministic merge activity
                activitiesToRecord.add(
                  ProspectActivityModel(
                    id: 'act-merge-${matchedLiveProspect.id}-${row.rowIndex}',
                    ownerId: ownerId,
                    prospectId: matchedLiveProspect.id,
                    activityType: 'Record Merged',
                    title: 'Merged updates from CRM Import ($sanitizedFileName)',
                    description: 'Updated fields from duplicate row ${row.rowIndex}.',
                    actor: 'CRM Import Engine',
                  ),
                );
                mergedCount++;
                if (phoneKey.isNotEmpty) seenExecutionPhones.add(phoneKey);
                if (emailKey.isNotEmpty) seenExecutionEmails.add(emailKey);
                continue;
              } catch (_) {
                errorCount++;
                continue;
              }
            }
            // Fallback if matched record is a CRM Buyer (cannot merge into prospect table) or not found
            skippedCount++;
            continue;
          }
          // DuplicateResolutionStrategy.importAnyway: falls through to create
        }

        // Track keys in current execution
        seenExecutionIds.add(candidate.id);
        if (phoneKey.isNotEmpty) {
          seenExecutionPhones.add(phoneKey);
          liveByPhone[phoneKey] = candidate;
        }
        if (emailKey.isNotEmpty) {
          seenExecutionEmails.add(emailKey);
          liveByEmail[emailKey] = candidate;
        }
        liveById[candidate.id] = candidate;

        prospectsToCreate.add(candidate);

        activitiesToRecord.add(
          ProspectActivityModel(
            id: 'act-imp-${candidate.id}',
            ownerId: ownerId,
            prospectId: candidate.id,
            activityType: 'Imported',
            title: 'Imported from CRM File ($sanitizedFileName)',
            description: 'Top-of-funnel prospect ingested via CRM Import Engine.',
            actor: 'CRM Import Engine',
          ),
        );

        if (row.consentResult.consentEvent != null) {
          final rawEvent = row.consentResult.consentEvent!;
          consentsToRecord.add(
            ProspectConsentEventModel(
              id: 'cst-${candidate.id}',
              ownerId: ownerId,
              prospectId: candidate.id,
              consentType: rawEvent.consentType,
              purpose: rawEvent.purpose,
              communicationChannels: rawEvent.communicationChannels,
              status: rawEvent.status,
              source: rawEvent.source,
              evidenceText: rawEvent.evidenceText,
              consentTimestamp: rawEvent.consentTimestamp,
              withdrawalTimestamp: rawEvent.withdrawalTimestamp,
            ),
          );
        }
      }

      // 4. Persist batch in repository (chunked safely in FirestoreProspectRepository)
      if (prospectsToCreate.isNotEmpty) {
        onProgress?.call(
          BatchImportProgress(
            current: preview.totalRows,
            total: preview.totalRows,
            currentOperation: 'Saving ${prospectsToCreate.length} records to repository...',
          ),
        );

        await repository.saveBulkProspects(prospectsToCreate);
        createdProspects.addAll(prospectsToCreate);
      }

      if (activitiesToRecord.isNotEmpty) {
        await repository.recordBulkActivities(activitiesToRecord);
      }

      if (consentsToRecord.isNotEmpty) {
        await repository.recordBulkConsentEvents(consentsToRecord);
      }

      // 5. Finalize Import Job record (sanitized metadata only, no PII)
      final finalStatus = (errorCount > 0 && (createdProspects.isNotEmpty || mergedCount > 0))
          ? 'Completed'
          : (errorCount > 0 && createdProspects.isEmpty && mergedCount == 0 && skippedCount == 0
              ? 'Failed'
              : 'Completed');

      job = job.copyWith(
        status: finalStatus,
        importedCount: createdProspects.length,
        duplicateCount: skippedCount + mergedCount,
        errorCount: errorCount,
        errorSummary: errorCount > 0
            ? '$errorCount row(s) failed validation during import.'
            : null,
        completedAt: DateTime.now(),
      );

      await repository.saveImportJob(job);

      onProgress?.call(
        BatchImportProgress(
          current: preview.totalRows,
          total: preview.totalRows,
          currentOperation: 'Import completed successfully.',
        ),
      );

      return BatchImportResult(
        jobId: effectiveJobId,
        totalRows: preview.totalRows,
        importedCount: createdProspects.length,
        skippedDuplicatesCount: skippedCount,
        mergedCount: mergedCount,
        errorCount: errorCount,
        importedProspects: createdProspects,
        job: job,
      );
    } finally {
      _inFlightOwnerLocks.remove(lockKey);
    }
  }

  ProspectModel _mergeProspect(ProspectModel existing, ProspectModel incoming) {
    // STRICT CONSENT PRECEDENCE:
    // 1. If either existing or incoming has 'Do Not Contact' (withdrawn consent),
    //    the merged record MUST remain 'Do Not Contact' with empty consented purposes/channels.
    // 2. If existing is 'Pending Consent' and incoming is 'Eligible', upgrade to 'Eligible'.
    // 3. If existing is 'Eligible' and incoming is 'Pending Consent', preserve 'Eligible'.
    String mergedEligibility;
    List<String> mergedPurposes;
    List<String> mergedChannels;

    if (existing.isDoNotContact || incoming.isDoNotContact) {
      mergedEligibility = 'Do Not Contact';
      mergedPurposes = const [];
      mergedChannels = const [];
    } else if (existing.isEligibleForContact || incoming.isEligibleForContact) {
      mergedEligibility = 'Eligible';
      mergedPurposes = <String>{
        ...existing.consentedPurposes,
        ...incoming.consentedPurposes,
      }.toList();
      mergedChannels = <String>{
        ...existing.consentedChannels,
        ...incoming.consentedChannels,
      }.toList();
    } else {
      mergedEligibility = existing.contactEligibility;
      mergedPurposes = existing.consentedPurposes;
      mergedChannels = existing.consentedChannels;
    }

    return existing.copyWith(
      fullName: incoming.fullName.isNotEmpty ? incoming.fullName : existing.fullName,
      phone: incoming.phone.isNotEmpty ? incoming.phone : existing.phone,
      email: incoming.email.isNotEmpty ? incoming.email : existing.email,
      budgetMin: incoming.budgetMin > 0 ? incoming.budgetMin : existing.budgetMin,
      budgetMax: incoming.budgetMax > 0 ? incoming.budgetMax : existing.budgetMax,
      preferredLocations: [
        ...existing.preferredLocations,
        ...incoming.preferredLocations.where((l) => !existing.preferredLocations.contains(l)),
      ],
      propertyTypes: [
        ...existing.propertyTypes,
        ...incoming.propertyTypes.where((t) => !existing.propertyTypes.contains(t)),
      ],
      // Preserve existing verificationStatus (never auto-verify or downgrade verification on import merge)
      verificationStatus: existing.verificationStatus,
      contactEligibility: mergedEligibility,
      consentedPurposes: mergedPurposes,
      consentedChannels: mergedChannels,
      notes: '${existing.notes}\n[Merged from CRM Import]: ${incoming.notes}'.trim(),
      updatedAt: DateTime.now(),
    );
  }

  static String _sanitizeSourceName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'CRM_Import.csv';
    // Strip any file system path prefixes
    final baseName = trimmed.split(RegExp(r'[/\\]')).last;
    return baseName.length > 120 ? baseName.substring(0, 120) : baseName;
  }
}
