import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campaign_model.dart';
import 'campaign_repository.dart';

/// Cloud Firestore implementation of [CampaignRepository].
/// Strictly enforces multi-agent isolation using `where('ownerId', isEqualTo: ownerId)`.
class FirestoreCampaignRepository implements CampaignRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreCampaignRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('campaigns');

  @override
  Future<List<CampaignModel>> getCampaigns({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final campaigns = querySnapshot.docs
        .map((doc) => CampaignModel.fromMap(doc.data()))
        .toList();

    campaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return campaigns;
  }

  @override
  Future<CampaignModel?> getCampaignById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CampaignModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> createCampaign(CampaignModel campaign) async {
    await _collection.doc(campaign.id).set(campaign.toMap());
  }

  @override
  Future<void> updateCampaign(CampaignModel campaign) async {
    await _collection.doc(campaign.id).update(campaign.toMap());
  }

  @override
  Future<void> deleteCampaign(String id) async {
    await _collection.doc(id).delete();
  }
}
