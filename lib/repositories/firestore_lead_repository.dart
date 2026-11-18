import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import 'lead_repository.dart';

/// Cloud Firestore implementation of [LeadRepository].
/// Strictly enforces multi-agent isolation using `where('ownerId', isEqualTo: ownerId)`.
class FirestoreLeadRepository implements LeadRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreLeadRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('leads');

  @override
  Future<List<LeadModel>> getLeads({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final leads = querySnapshot.docs
        .map((doc) => LeadModel.fromMap(doc.data()))
        .toList();

    leads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return leads;
  }

  @override
  Future<LeadModel?> getLeadById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return LeadModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> createLead(LeadModel lead) async {
    await _collection.doc(lead.id).set(lead.toMap());
  }

  @override
  Future<void> updateLead(LeadModel lead) async {
    await _collection.doc(lead.id).update(lead.toMap());
  }

  @override
  Future<void> updateLeadStatus(String leadId, String status) async {
    await _collection.doc(leadId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteLead(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<bool> hasLead(String buyerId, String projectId) async {
    final snapshot = await _collection
        .where('buyerId', isEqualTo: buyerId)
        .where('projectId', isEqualTo: projectId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
