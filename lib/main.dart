import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/emulator_config.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isFirebaseConnected = false;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseConnected = true;
      debugPrint('Firebase Web successfully connected for project property-71665');

      // Connect to local emulators if configured via --dart-define=USE_FIREBASE_EMULATOR=true
      if (EmulatorConfig.useEmulator) {
        EmulatorConfig.connectEmulatorsIfEnabled();
      }
    }
  } catch (e) {
    debugPrint('Firebase Web initialization notice: $e (falling back to prototype in-memory mode)');
    isFirebaseConnected = false;
  }

  runApp(PropMatchApp(isFirebaseConnected: isFirebaseConnected));
}
