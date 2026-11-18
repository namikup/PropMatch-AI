import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Adapts Firebase Auth [User] to the application's [AuthUser] interface.
class FirebaseAuthUserAdapter implements AuthUser {
  final User _firebaseUser;

  FirebaseAuthUserAdapter(this._firebaseUser);

  @override
  String get uid => _firebaseUser.uid;

  @override
  String get email => _firebaseUser.email ?? '';

  @override
  String get displayName =>
      _firebaseUser.displayName?.isNotEmpty == true
          ? _firebaseUser.displayName!
          : (_firebaseUser.email?.split('@').first ?? 'Property Negotiator');

  @override
  String? get photoUrl => _firebaseUser.photoURL;

  @override
  bool get isEmailVerified => _firebaseUser.emailVerified;

  @override
  Future<void> sendEmailVerification() async {
    await _firebaseUser.sendEmailVerification();
  }
}

/// Production Firebase Authentication repository implementing [AuthRepository].
/// Supports:
/// - Firebase Auth email/password authentication
/// - Persistent web authentication session monitoring
/// - Dedicated demo mode login coexistence (`agent@propmatch.ai`)
/// - User profile creation & retrieval in Firestore `users/{uid}`
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  FirebaseAuth get _firebaseAuth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  AuthUser? _demoUser;
  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast(sync: true);
  StreamSubscription<User?>? _firebaseAuthSub;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _customAuth = firebaseAuth,
        _customFirestore = firestore {
    _initListener();
  }

  void _initListener() {
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        _firebaseAuthSub = _firebaseAuth.authStateChanges().listen((user) {
          if (_demoUser != null) {
            // Retain demo session if explicitly signed in to demo mode
            return;
          }
          if (user != null) {
            _authStateController.add(FirebaseAuthUserAdapter(user));
          } else {
            _authStateController.add(null);
          }
        });
      }
    } catch (_) {
      // Graceful fallback when Firebase app not yet initialized in current environment
    }
  }

  @override
  AuthUser? get currentUser {
    if (_demoUser != null) return _demoUser;
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        final fbUser = _firebaseAuth.currentUser;
        return fbUser != null ? FirebaseAuthUserAdapter(fbUser) : null;
      }
    } catch (_) {}
    return null;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    final controller = StreamController<AuthUser?>.broadcast(sync: true);
    StreamSubscription<AuthUser?>? sub;
    controller.onListen = () {
      controller.add(currentUser);
      sub = _authStateController.stream.listen(controller.add);
    };
    controller.onCancel = () {
      sub?.cancel();
    };
    return controller.stream;
  }

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    final trimmedEmail = email.trim();

    // 1. Check for prototype demo credentials to preserve demo workflow
    if (trimmedEmail == 'agent@propmatch.ai' && password == 'demo1234') {
      _demoUser = const SimpleAuthUser(
        uid: 'demo-agent-001',
        email: 'agent@propmatch.ai',
        displayName: 'Malaysian Agent (REN)',
      );
      _authStateController.add(_demoUser);
      return _demoUser;
    }

    // 2. Real Firebase Authentication
    _demoUser = null;
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    if (credential.user != null) {
      final user = FirebaseAuthUserAdapter(credential.user!);
      _authStateController.add(user);
      return user;
    }

    return null;
  }

  /// Registers a new Malaysian property negotiator via Firebase Authentication
  /// and persists their professional details (REN number, agency, phone) into Firestore `users/{uid}`.
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
    _demoUser = null;
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final fbUser = credential.user;
    if (fbUser != null) {
      await fbUser.updateDisplayName(fullName);

      // Persist profile in Firestore
      final userModel = UserModel(
        id: fbUser.uid,
        ownerId: fbUser.uid,
        fullName: fullName,
        email: fbUser.email ?? email.trim(),
        phone: phone,
        agencyName: agencyName,
        renNumber: renNumber,
        region: region,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(fbUser.uid).set(userModel.toMap());

      final user = FirebaseAuthUserAdapter(fbUser);
      _authStateController.add(user);
      return user;
    }

    return null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        await _firebaseAuth.sendPasswordResetEmail(email: trimmed);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _demoUser = null;
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        await _firebaseAuth.signOut();
      }
    } catch (_) {}
    _authStateController.add(null);
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    if (uid == 'demo-agent-001') {
      return UserModel(
        id: 'usr-001',
        ownerId: 'demo-agent-001',
        fullName: 'Malaysian Agent (REN)',
        email: 'agent@propmatch.ai',
        phone: '+6012-3456789',
        agencyName: 'PropMatch Realty Malaysia',
        renNumber: 'REN 12345',
        region: 'Penang & Northern Region',
      );
    }

    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  void dispose() {
    _firebaseAuthSub?.cancel();
    _authStateController.close();
  }
}
