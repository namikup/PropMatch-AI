import '../models/consent_record_model.dart';

abstract class ConsentRepository {
  Future<List<ConsentRecordModel>> getConsentRecords({required String ownerId});
  Future<List<ConsentRecordModel>> getConsentsForBuyer(String buyerId);
  Future<void> recordConsent(ConsentRecordModel consent);
  Future<void> withdrawConsent({
    required String buyerId,
    required String consentType,
    String? ownerId,
    String consentSource = 'Agent Manual Withdrawal',
  });
}

/// In-memory implementation used during prototype phase
class InMemoryConsentRepository implements ConsentRepository {
  final List<ConsentRecordModel> _storage = [];

  InMemoryConsentRepository([List<ConsentRecordModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<ConsentRecordModel>> getConsentRecords({required String ownerId}) async {
    return _storage.where((c) => c.ownerId == ownerId).toList();
  }

  @override
  Future<List<ConsentRecordModel>> getConsentsForBuyer(String buyerId) async {
    return _storage.where((c) => c.buyerId == buyerId).toList();
  }

  @override
  Future<void> recordConsent(ConsentRecordModel consent) async {
    _storage.insert(0, consent);
  }

  @override
  Future<void> withdrawConsent({
    required String buyerId,
    required String consentType,
    String? ownerId,
    String consentSource = 'Agent Manual Withdrawal',
  }) async {
    // Append-only audit trail: create a separate withdrawal event record
    // without mutating or destroying the original grant record.
    final effectiveOwnerId = ownerId ??
        (_storage.where((c) => c.buyerId == buyerId).isNotEmpty
            ? _storage.firstWhere((c) => c.buyerId == buyerId).ownerId
            : 'system');

    final withdrawalRecord = ConsentRecordModel(
      ownerId: effectiveOwnerId,
      buyerId: buyerId,
      consentType: consentType,
      consentStatus: 'withdrawn',
      consentSource: consentSource,
      consentTimestamp: DateTime.now(),
      withdrawalTimestamp: DateTime.now(),
    );

    _storage.insert(0, withdrawalRecord);
  }
}
