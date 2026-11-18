import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buyer_model.dart';
import 'buyer_repository.dart';

/// Cloud Firestore implementation of [BuyerRepository].
/// Strictly enforces multi-agent isolation using `where('ownerId', isEqualTo: ownerId)`.
class FirestoreBuyerRepository implements BuyerRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreBuyerRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('buyers');

  @override
  Future<List<BuyerModel>> getBuyers({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final buyers = querySnapshot.docs
        .map((doc) => BuyerModel.fromMap(doc.data()))
        .toList();

    buyers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return buyers;
  }

  @override
  Future<BuyerModel?> getBuyerById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return BuyerModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> createBuyer(BuyerModel buyer) async {
    await _collection.doc(buyer.id).set(buyer.toMap());
  }

  @override
  Future<void> updateBuyer(BuyerModel buyer) async {
    await _collection.doc(buyer.id).update(buyer.toMap());
  }

  @override
  Future<void> deleteBuyer(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<void> saveBulkBuyers(List<BuyerModel> buyers) async {
    if (buyers.isEmpty) return;

    // Chunk into batches of up to 450 (Firestore limit is 500 per batch)
    const chunkSize = 450;
    for (var i = 0; i < buyers.length; i += chunkSize) {
      final end = (i + chunkSize < buyers.length) ? i + chunkSize : buyers.length;
      final chunk = buyers.sublist(i, end);

      final batch = _firestore.batch();
      for (final buyer in chunk) {
        final docRef = _collection.doc(buyer.id);
        batch.set(docRef, buyer.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteDemoBuyers({required String ownerId}) async {
    final snapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .where('isDemo', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) return;

    const chunkSize = 450;
    final docs = snapshot.docs;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final end = (i + chunkSize < docs.length) ? i + chunkSize : docs.length;
      final chunk = docs.sublist(i, end);

      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
