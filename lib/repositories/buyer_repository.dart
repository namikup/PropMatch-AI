import '../models/buyer_model.dart';

abstract class BuyerRepository {
  Future<List<BuyerModel>> getBuyers({required String ownerId});
  Future<BuyerModel?> getBuyerById(String id);
  Future<void> createBuyer(BuyerModel buyer);
  Future<void> updateBuyer(BuyerModel buyer);
  Future<void> deleteBuyer(String id);
  Future<void> saveBulkBuyers(List<BuyerModel> buyers);
  Future<void> deleteDemoBuyers({required String ownerId});
}

/// In-memory implementation used during prototype phase
class InMemoryBuyerRepository implements BuyerRepository {
  final List<BuyerModel> _storage = [];

  InMemoryBuyerRepository([List<BuyerModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<BuyerModel>> getBuyers({required String ownerId}) async {
    return _storage.where((b) => b.ownerId == ownerId).toList();
  }

  @override
  Future<BuyerModel?> getBuyerById(String id) async {
    final matches = _storage.where((b) => b.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createBuyer(BuyerModel buyer) async {
    _storage.insert(0, buyer);
  }

  @override
  Future<void> updateBuyer(BuyerModel buyer) async {
    final index = _storage.indexWhere((b) => b.id == buyer.id);
    if (index != -1) {
      _storage[index] = buyer;
    }
  }

  @override
  Future<void> deleteBuyer(String id) async {
    _storage.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> saveBulkBuyers(List<BuyerModel> buyers) async {
    _storage.addAll(buyers);
  }

  @override
  Future<void> deleteDemoBuyers({required String ownerId}) async {
    _storage.removeWhere((b) => b.ownerId == ownerId && b.isDemo);
  }
}
