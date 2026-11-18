import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consent_record_model.dart';
import 'consent_repository.dart';

/// Cloud Firestore implementation of [ConsentRepository].
/// Strictly maintains an immutable, append-only PDPA compliance audit trail.
class FirestoreConsentRepository implements ConsentRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreConsentRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('consent_records');

  @override
  Future<List<ConsentRecordModel>> getConsentRecords({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final records = querySnapshot.docs
        .map((doc) => ConsentRecordModel.fromMap(doc.data()))
        .toList();

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<List<ConsentRecordModel>> getConsentsForBuyer(String buyerId) async {
    final querySnapshot = await _collection
        .where('buyerId', isEqualTo: buyerId)
        .get();

    final records = querySnapshot.docs
        .map((doc) => ConsentRecordModel.fromMap(doc.data()))
        .toList();

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<void> recordConsent(ConsentRecordModel consent) async {
    await _collection.doc(consent.id).set(consent.toMap());
  }

  @override
  Future<void> withdrawConsent({
    required String buyerId,
    required String consentType,
    String? ownerId,
    String consentSource = 'Agent Manual Withdrawal',
  }) async {
    // Append-only audit record: under PDPA 2010 regulations, we never mutate
    // or overwrite historical consent entries. We log a discrete withdrawal event.
    final withdrawalEvent = ConsentRecordModel(
      ownerId: ownerId ?? 'unknown',
      buyerId: buyerId,
      consentType: consentType,
      consentStatus: 'withdrawn',
      consentSource: consentSource,
      consentTimestamp: DateTime.now(),
      withdrawalTimestamp: DateTime.now(),
    );

    await _collection.doc(withdrawalEvent.id).set(withdrawalEvent.toMap());
  }
}
