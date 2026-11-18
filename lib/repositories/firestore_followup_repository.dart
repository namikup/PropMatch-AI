import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/followup_model.dart';
import 'followup_repository.dart';

/// Cloud Firestore implementation of [FollowupRepository].
/// Strictly enforces multi-agent isolation using `where('ownerId', isEqualTo: ownerId)`.
class FirestoreFollowupRepository implements FollowupRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreFollowupRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('followups');

  @override
  Future<List<FollowupModel>> getFollowups({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final followups = querySnapshot.docs
        .map((doc) => FollowupModel.fromMap(doc.data()))
        .toList();

    followups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return followups;
  }

  @override
  Future<FollowupModel?> getFollowupById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return FollowupModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> createFollowup(FollowupModel followup) async {
    await _collection.doc(followup.id).set(followup.toMap());
  }

  @override
  Future<void> updateFollowup(FollowupModel followup) async {
    await _collection.doc(followup.id).update(followup.toMap());
  }

  @override
  Future<void> toggleCompletion(String id) async {
    final docRef = _collection.doc(id);
    final doc = await docRef.get();
    if (doc.exists && doc.data() != null) {
      final current = doc.data()!['isCompleted'] as bool? ?? false;
      await docRef.update({
        'isCompleted': !current,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> deleteFollowup(String id) async {
    await _collection.doc(id).delete();
  }
}
