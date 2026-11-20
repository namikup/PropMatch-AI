import '../models/prospect_model.dart';
import '../models/prospect_consent_event_model.dart';
import '../models/prospect_activity_model.dart';
import '../models/prospect_source_model.dart';
import '../models/prospect_import_job_model.dart';

abstract class ProspectRepository {
  Future<List<ProspectModel>> getProspects({required String ownerId});
  Future<ProspectModel?> getProspectById(String id, {String? ownerId});
  Future<void> createProspect(ProspectModel prospect);
  Future<void> updateProspect(ProspectModel prospect);
  Future<void> deleteProspect(String id, {String? ownerId});
  Future<void> saveBulkProspects(List<ProspectModel> prospects);
  Future<void> deleteDemoProspects({required String ownerId});

  // Consent Events (PDPA Audit Trail)
  Future<List<ProspectConsentEventModel>> getConsentsForProspect(
    String prospectId, {
    String? ownerId,
  });
  Future<void> recordConsentEvent(ProspectConsentEventModel consent);
  Future<void> recordBulkConsentEvents(List<ProspectConsentEventModel> consents);

  // Activity History
  Future<List<ProspectActivityModel>> getActivitiesForProspect(
    String prospectId, {
    String? ownerId,
  });
  Future<void> recordActivity(ProspectActivityModel activity);
  Future<void> recordBulkActivities(List<ProspectActivityModel> activities);

  // Data Sources
  Future<List<ProspectSourceModel>> getDataSources({required String ownerId});
  Future<void> saveDataSource(ProspectSourceModel source);

  // Import Jobs History
  Future<List<ProspectImportJobModel>> getImportJobs({required String ownerId});
  Future<void> saveImportJob(ProspectImportJobModel job);
}

/// In-memory implementation of [ProspectRepository] for testing and demo mode.
class InMemoryProspectRepository implements ProspectRepository {
  final List<ProspectModel> _prospects = [];
  final List<ProspectConsentEventModel> _consents = [];
  final List<ProspectActivityModel> _activities = [];
  final List<ProspectSourceModel> _sources = [];
  final List<ProspectImportJobModel> _importJobs = [];

  InMemoryProspectRepository([
    List<ProspectModel>? initialProspects,
    List<ProspectSourceModel>? initialSources,
  ]) {
    if (initialProspects != null) {
      _prospects.addAll(initialProspects);
    }
    if (initialSources != null) {
      _sources.addAll(initialSources);
    }
  }

  @override
  Future<List<ProspectModel>> getProspects({required String ownerId}) async {
    return _prospects.where((p) => p.ownerId == ownerId).toList();
  }

  @override
  Future<ProspectModel?> getProspectById(String id, {String? ownerId}) async {
    final matches = _prospects.where(
      (p) => p.id == id && (ownerId == null || p.ownerId == ownerId),
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createProspect(ProspectModel prospect) async {
    final existingIdx = _prospects.indexWhere((p) => p.id == prospect.id);
    if (existingIdx != -1) {
      _prospects[existingIdx] = prospect;
    } else {
      _prospects.insert(0, prospect);
    }
  }

  @override
  Future<void> updateProspect(ProspectModel prospect) async {
    final index = _prospects.indexWhere(
      (p) => p.id == prospect.id && p.ownerId == prospect.ownerId,
    );
    if (index != -1) {
      _prospects[index] = prospect;
    }
  }

  @override
  Future<void> deleteProspect(String id, {String? ownerId}) async {
    _prospects.removeWhere(
      (p) => p.id == id && (ownerId == null || p.ownerId == ownerId),
    );
  }

  @override
  Future<void> saveBulkProspects(List<ProspectModel> prospects) async {
    for (final prospect in prospects) {
      final idx = _prospects.indexWhere((p) => p.id == prospect.id);
      if (idx != -1) {
        _prospects[idx] = prospect;
      } else {
        _prospects.add(prospect);
      }
    }
  }

  @override
  Future<void> deleteDemoProspects({required String ownerId}) async {
    _prospects.removeWhere((p) => p.ownerId == ownerId && p.isDemo);
  }

  @override
  Future<List<ProspectConsentEventModel>> getConsentsForProspect(
    String prospectId, {
    String? ownerId,
  }) async {
    final list = _consents
        .where(
          (c) =>
              c.prospectId == prospectId &&
              (ownerId == null || c.ownerId == ownerId),
        )
        .toList();
    list.sort((a, b) => b.consentTimestamp.compareTo(a.consentTimestamp));
    return list;
  }

  @override
  Future<void> recordConsentEvent(ProspectConsentEventModel consent) async {
    // Idempotent append-only guard: prevent duplicate consent events on retry
    final alreadyExists = _consents.any(
      (c) =>
          c.id == consent.id ||
          (c.ownerId == consent.ownerId &&
              c.prospectId == consent.prospectId &&
              c.consentType == consent.consentType &&
              c.status == consent.status &&
              c.source == consent.source &&
              c.evidenceText == consent.evidenceText),
    );
    if (!alreadyExists) {
      _consents.insert(0, consent);
    }
  }

  @override
  Future<void> recordBulkConsentEvents(
    List<ProspectConsentEventModel> consents,
  ) async {
    for (final consent in consents) {
      await recordConsentEvent(consent);
    }
  }

  @override
  Future<List<ProspectActivityModel>> getActivitiesForProspect(
    String prospectId, {
    String? ownerId,
  }) async {
    final list = _activities
        .where(
          (a) =>
              a.prospectId == prospectId &&
              (ownerId == null || a.ownerId == ownerId),
        )
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Future<void> recordActivity(ProspectActivityModel activity) async {
    final alreadyExists = _activities.any((a) => a.id == activity.id);
    if (!alreadyExists) {
      _activities.insert(0, activity);
    }
  }

  @override
  Future<void> recordBulkActivities(
    List<ProspectActivityModel> activities,
  ) async {
    for (final activity in activities) {
      await recordActivity(activity);
    }
  }

  @override
  Future<List<ProspectSourceModel>> getDataSources({required String ownerId}) async {
    return _sources.where((s) => s.ownerId == ownerId).toList();
  }

  @override
  Future<void> saveDataSource(ProspectSourceModel source) async {
    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index != -1) {
      _sources[index] = source;
    } else {
      _sources.add(source);
    }
  }

  @override
  Future<List<ProspectImportJobModel>> getImportJobs({required String ownerId}) async {
    final list = _importJobs.where((j) => j.ownerId == ownerId).toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  @override
  Future<void> saveImportJob(ProspectImportJobModel job) async {
    final index = _importJobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _importJobs[index] = job;
    } else {
      _importJobs.insert(0, job);
    }
  }
}
