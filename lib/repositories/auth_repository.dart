import 'dart:async';
import '../models/user_model.dart';

abstract class AuthUser {
  String get uid;
  String get email;
  String get displayName;
  String? get photoUrl;
  bool get isEmailVerified;
  Future<void> sendEmailVerification();
}

class SimpleAuthUser implements AuthUser {
  @override
  final String uid;
  @override
  final String email;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  @override
  final bool isEmailVerified;

  const SimpleAuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isEmailVerified = true,
  });

  @override
  Future<void> sendEmailVerification() async {}
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String renNumber = '',
    String agencyName = '',
    String phone = '',
    String region = 'Penang & Northern Region',
  });
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<UserModel?> getUserProfile(String uid);
}

/// In-memory implementation used during prototype phase
class InMemoryAuthRepository implements AuthRepository {
  AuthUser? _user = const SimpleAuthUser(
    uid: 'demo-agent-001',
    email: 'agent@propmatch.ai',
    displayName: 'Malaysian Agent (REN)',
  );

  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  final Map<String, UserModel> _userProfiles = {
    'demo-agent-001': UserModel(
      id: 'usr-001',
      ownerId: 'demo-agent-001',
      fullName: 'Malaysian Agent (REN)',
      email: 'agent@propmatch.ai',
      phone: '+6012-3456789',
      agencyName: 'PropMatch Realty Malaysia',
      renNumber: 'REN 12345',
      region: 'Penang & Northern Region',
    ),
  };

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() {
    final controller = StreamController<AuthUser?>.broadcast(sync: true);
    StreamSubscription<AuthUser?>? sub;
    controller.onListen = () {
      controller.add(_user);
      sub = _authStateController.stream.listen(controller.add);
    };
    controller.onCancel = () {
      sub?.cancel();
    };
    return controller.stream;
  }

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    final uid = email == 'agent@propmatch.ai' ? 'demo-agent-001' : 'agent-${email.split('@').first}';
    _user = SimpleAuthUser(
      uid: uid,
      email: email,
      displayName: 'Agent ($email)',
    );
    _authStateController.add(_user);
    return _user;
  }

  @override
  Future<AuthUser?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String renNumber = '',
    String agencyName = '',
    String phone = '',
    String region = 'Penang & Northern Region',
  }) async {
    final uid = 'agent-${email.split('@').first}';
    _user = SimpleAuthUser(
      uid: uid,
      email: email,
      displayName: fullName,
    );
    _userProfiles[uid] = UserModel(
      id: uid,
      ownerId: uid,
      fullName: fullName,
      email: email,
      phone: phone,
      agencyName: agencyName,
      renNumber: renNumber,
      region: region,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(_user);
    return _user;
  }

  final List<String> sentPasswordResetEmails = [];

  void switchUser(AuthUser? user) {
    _user = user;
    _authStateController.add(user);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    sentPasswordResetEmails.add(email.trim());
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _authStateController.add(null);
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    return _userProfiles[uid];
  }
}
