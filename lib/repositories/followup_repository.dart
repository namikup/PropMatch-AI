import '../models/followup_model.dart';

abstract class FollowupRepository {
  Future<List<FollowupModel>> getFollowups({required String ownerId});
  Future<FollowupModel?> getFollowupById(String id);
  Future<void> createFollowup(FollowupModel followup);
  Future<void> updateFollowup(FollowupModel followup);
  Future<void> toggleCompletion(String id);
  Future<void> deleteFollowup(String id);
}

/// In-memory implementation used during prototype phase
class InMemoryFollowupRepository implements FollowupRepository {
  final List<FollowupModel> _storage = [];

  InMemoryFollowupRepository([List<FollowupModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<FollowupModel>> getFollowups({required String ownerId}) async {
    return _storage.where((f) => f.ownerId == ownerId).toList();
  }

  @override
  Future<FollowupModel?> getFollowupById(String id) async {
    final matches = _storage.where((f) => f.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createFollowup(FollowupModel followup) async {
    _storage.insert(0, followup);
  }

  @override
  Future<void> updateFollowup(FollowupModel followup) async {
    final index = _storage.indexWhere((f) => f.id == followup.id);
    if (index != -1) {
      _storage[index] = followup;
    }
  }

  @override
  Future<void> toggleCompletion(String id) async {
    final index = _storage.indexWhere((f) => f.id == id);
    if (index != -1) {
      final cur = _storage[index];
      _storage[index] = cur.copyWith(isCompleted: !cur.isCompleted);
    }
  }

  @override
  Future<void> deleteFollowup(String id) async {
    _storage.removeWhere((f) => f.id == id);
  }
}
