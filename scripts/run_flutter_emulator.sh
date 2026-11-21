#!/bin/bash
# PropMatch AI — Run Flutter Web in Local Emulator Mode
# Connects to localhost emulators via --dart-define=USE_FIREBASE_EMULATOR=true

echo "Launching PropMatch AI Flutter Web in Emulator Mode..."
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
