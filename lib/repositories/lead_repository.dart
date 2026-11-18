import '../models/lead_model.dart';

abstract class LeadRepository {
  Future<List<LeadModel>> getLeads({required String ownerId});
  Future<LeadModel?> getLeadById(String id);
  Future<void> createLead(LeadModel lead);
  Future<void> updateLead(LeadModel lead);
  Future<void> updateLeadStatus(String leadId, String status);
  Future<void> deleteLead(String id);
  Future<bool> hasLead(String buyerId, String projectId);
}

/// In-memory implementation used during prototype phase
class InMemoryLeadRepository implements LeadRepository {
  final List<LeadModel> _storage = [];

  InMemoryLeadRepository([List<LeadModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<LeadModel>> getLeads({required String ownerId}) async {
    return _storage.where((l) => l.ownerId == ownerId).toList();
  }

  @override
  Future<LeadModel?> getLeadById(String id) async {
    final matches = _storage.where((l) => l.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createLead(LeadModel lead) async {
    _storage.insert(0, lead);
  }

  @override
  Future<void> updateLead(LeadModel lead) async {
    final index = _storage.indexWhere((l) => l.id == lead.id);
    if (index != -1) {
      _storage[index] = lead;
    }
  }

  @override
  Future<void> updateLeadStatus(String leadId, String status) async {
    final index = _storage.indexWhere((l) => l.id == leadId);
    if (index != -1) {
      _storage[index] = _storage[index].copyWith(status: status);
    }
  }

  @override
  Future<void> deleteLead(String id) async {
    _storage.removeWhere((l) => l.id == id);
  }

  @override
  Future<bool> hasLead(String buyerId, String projectId) async {
    return _storage.any((l) => l.buyerId == buyerId && l.projectId == projectId);
  }
}
