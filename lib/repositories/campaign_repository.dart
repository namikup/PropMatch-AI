import '../models/campaign_model.dart';

abstract class CampaignRepository {
  Future<List<CampaignModel>> getCampaigns({required String ownerId});
  Future<CampaignModel?> getCampaignById(String id);
  Future<void> createCampaign(CampaignModel campaign);
  Future<void> updateCampaign(CampaignModel campaign);
  Future<void> deleteCampaign(String id);
}

/// In-memory implementation used during prototype phase
class InMemoryCampaignRepository implements CampaignRepository {
  final List<CampaignModel> _storage = [];

  InMemoryCampaignRepository([List<CampaignModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<CampaignModel>> getCampaigns({required String ownerId}) async {
    return _storage.where((c) => c.ownerId == ownerId).toList();
  }

  @override
  Future<CampaignModel?> getCampaignById(String id) async {
    final matches = _storage.where((c) => c.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createCampaign(CampaignModel campaign) async {
    _storage.insert(0, campaign);
  }

  @override
  Future<void> updateCampaign(CampaignModel campaign) async {
    final index = _storage.indexWhere((c) => c.id == campaign.id);
    if (index != -1) {
      _storage[index] = campaign;
    }
  }

  @override
  Future<void> deleteCampaign(String id) async {
    _storage.removeWhere((c) => c.id == id);
  }
}
