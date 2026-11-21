import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Configuration for local Firebase Emulator Suite connectivity in development.
///
/// Activated via compile-time flag: `--dart-define=USE_FIREBASE_EMULATOR=true`.
/// In production or standard builds, [useEmulator] is false and this is completely inert.
class EmulatorConfig {
  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const String emulatorHost = 'localhost';
  static const int functionsPort = 5001;
  static const int firestorePort = 8080;
  static const int authPort = 9099;
  static const String functionsRegion = 'asia-southeast1';

  static bool _configured = false;

  /// Connects Firebase SDKs to local emulator suite when [useEmulator] is true.
  static void connectEmulatorsIfEnabled() {
    if (!useEmulator || _configured) return;
    try {
      FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
      FirebaseFunctions.instanceFor(region: functionsRegion)
          .useFunctionsEmulator(emulatorHost, functionsPort);
      _configured = true;
      if (kDebugMode) {
        debugPrint(
          '[EmulatorConfig] Connected to Firebase Local Emulator Suite '
          '(Functions: $functionsPort, Firestore: $firestorePort, Auth: $authPort)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmulatorConfig] Error connecting to emulators: $e');
      }
    }
  }
}
