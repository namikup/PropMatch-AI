import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prospect_model.dart';
import '../models/prospect_consent_event_model.dart';
import '../models/prospect_activity_model.dart';
import '../models/prospect_source_model.dart';
import '../models/prospect_import_job_model.dart';
import 'prospect_repository.dart';

/// Cloud Firestore implementation of [ProspectRepository].
/// Strictly enforces multi-agent isolation and chunks batch operations safely below Firestore's 500-write limit.
class FirestoreProspectRepository implements ProspectRepository {
  static const int maxFirestoreBatchOperations = 450;

  final FirebaseFirestore? _customFirestore;

  FirestoreProspectRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _prospectsCollection =>
      _firestore.collection('prospects');

  CollectionReference<Map<String, dynamic>> get _consentsCollection =>
      _firestore.collection('prospect_consents');

  CollectionReference<Map<String, dynamic>> get _activitiesCollection =>
      _firestore.collection('prospect_activities');

  CollectionReference<Map<String, dynamic>> get _sourcesCollection =>
      _firestore.collection('data_sources');

  CollectionReference<Map<String, dynamic>> get _importJobsCollection =>
      _firestore.collection('prospect_import_jobs');

  @override
  Future<List<ProspectModel>> getProspects({required String ownerId}) async {
    if (ownerId.trim().isEmpty) return [];

    final querySnapshot = await _prospectsCollection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final prospects = querySnapshot.docs
        .map((doc) => ProspectModel.fromMap(doc.data()))
        .toList();

    prospects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return prospects;
  }

  @override
  Future<ProspectModel?> getProspectById(String id, {String? ownerId}) async {
    final doc = await _prospectsCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      final model = ProspectModel.fromMap(doc.data()!);
      if (ownerId != null && ownerId.isNotEmpty && model.ownerId != ownerId) {
        return null;
      }
      return model;
    }
    return null;
  }

  @override
  Future<void> createProspect(ProspectModel prospect) async {
    if (prospect.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot persist prospect without a valid ownerId.');
    }
    await _prospectsCollection.doc(prospect.id).set(prospect.toMap());
  }

  @override
  Future<void> updateProspect(ProspectModel prospect) async {
    if (prospect.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot update prospect without a valid ownerId.');
    }
    await _prospectsCollection.doc(prospect.id).update(prospect.toMap());
  }

  @override
  Future<void> deleteProspect(String id, {String? ownerId}) async {
    if (ownerId != null && ownerId.isNotEmpty) {
      final existing = await getProspectById(id, ownerId: ownerId);
      if (existing == null) return;
    }
    await _prospectsCollection.doc(id).delete();
  }

  @override
  Future<void> saveBulkProspects(List<ProspectModel> prospects) async {
    if (prospects.isEmpty) return;

    for (int start = 0; start < prospects.length; start += maxFirestoreBatchOperations) {
      final end = (start + maxFirestoreBatchOperations < prospects.length)
          ? start + maxFirestoreBatchOperations
          : prospects.length;
      final chunk = prospects.sublist(start, end);

      final batch = _firestore.batch();
      for (final prospect in chunk) {
        if (prospect.ownerId.trim().isEmpty) {
          throw ArgumentError('Cannot persist prospect without a valid ownerId.');
        }
        final docRef = _prospectsCollection.doc(prospect.id);
        batch.set(docRef, prospect.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteDemoProspects({required String ownerId}) async {
    if (ownerId.trim().isEmpty) return;

    final querySnapshot = await _prospectsCollection
        .where('ownerId', isEqualTo: ownerId)
        .where('isDemo', isEqualTo: true)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final docs = querySnapshot.docs;
    for (int start = 0; start < docs.length; start += maxFirestoreBatchOperations) {
      final end = (start + maxFirestoreBatchOperations < docs.length)
          ? start + maxFirestoreBatchOperations
          : docs.length;
      final chunk = docs.sublist(start, end);

      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<List<ProspectConsentEventModel>> getConsentsForProspect(
    String prospectId, {
    String? ownerId,
  }) async {
    Query<Map<String, dynamic>> query = _consentsCollection
        .where('prospectId', isEqualTo: prospectId);
    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final querySnapshot = await query.get();

    final consents = querySnapshot.docs
        .map((doc) => ProspectConsentEventModel.fromMap(doc.data()))
        .toList();

    consents.sort((a, b) => b.consentTimestamp.compareTo(a.consentTimestamp));
    return consents;
  }

  @override
  Future<void> recordConsentEvent(ProspectConsentEventModel consent) async {
    if (consent.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot record consent event without a valid ownerId.');
    }
    await _consentsCollection.doc(consent.id).set(consent.toMap());
  }

  @override
  Future<void> recordBulkConsentEvents(
    List<ProspectConsentEventModel> consents,
  ) async {
    if (consents.isEmpty) return;

    for (int start = 0; start < consents.length; start += maxFirestoreBatchOperations) {
      final end = (start + maxFirestoreBatchOperations < consents.length)
          ? start + maxFirestoreBatchOperations
          : consents.length;
      final chunk = consents.sublist(start, end);

      final batch = _firestore.batch();
      for (final consent in chunk) {
        if (consent.ownerId.trim().isEmpty) {
          throw ArgumentError('Cannot record consent event without a valid ownerId.');
        }
        final docRef = _consentsCollection.doc(consent.id);
        batch.set(docRef, consent.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<List<ProspectActivityModel>> getActivitiesForProspect(
    String prospectId, {
    String? ownerId,
  }) async {
    Query<Map<String, dynamic>> query = _activitiesCollection
        .where('prospectId', isEqualTo: prospectId);
    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final querySnapshot = await query.get();

    final activities = querySnapshot.docs
        .map((doc) => ProspectActivityModel.fromMap(doc.data()))
        .toList();

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities;
  }

  @override
  Future<void> recordActivity(ProspectActivityModel activity) async {
    if (activity.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot record activity without a valid ownerId.');
    }
    await _activitiesCollection.doc(activity.id).set(activity.toMap());
  }

  @override
  Future<void> recordBulkActivities(
    List<ProspectActivityModel> activities,
  ) async {
    if (activities.isEmpty) return;

    for (int start = 0; start < activities.length; start += maxFirestoreBatchOperations) {
      final end = (start + maxFirestoreBatchOperations < activities.length)
          ? start + maxFirestoreBatchOperations
          : activities.length;
      final chunk = activities.sublist(start, end);

      final batch = _firestore.batch();
      for (final activity in chunk) {
        if (activity.ownerId.trim().isEmpty) {
          throw ArgumentError('Cannot record activity without a valid ownerId.');
        }
        final docRef = _activitiesCollection.doc(activity.id);
        batch.set(docRef, activity.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<List<ProspectSourceModel>> getDataSources({required String ownerId}) async {
    if (ownerId.trim().isEmpty) return [];

    final querySnapshot = await _sourcesCollection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    return querySnapshot.docs
        .map((doc) => ProspectSourceModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> saveDataSource(ProspectSourceModel source) async {
    if (source.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot save data source without a valid ownerId.');
    }
    await _sourcesCollection.doc(source.id).set(source.toMap());
  }

  @override
  Future<List<ProspectImportJobModel>> getImportJobs({required String ownerId}) async {
    if (ownerId.trim().isEmpty) return [];

    final querySnapshot = await _importJobsCollection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final jobs = querySnapshot.docs
        .map((doc) => ProspectImportJobModel.fromMap(doc.data()))
        .toList();

    jobs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return jobs;
  }

  @override
  Future<void> saveImportJob(ProspectImportJobModel job) async {
    if (job.ownerId.trim().isEmpty) {
      throw ArgumentError('Cannot save import job without a valid ownerId.');
    }
    await _importJobsCollection.doc(job.id).set(job.toMap());
  }
}
