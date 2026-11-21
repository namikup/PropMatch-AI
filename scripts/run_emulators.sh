#!/bin/bash
# PropMatch AI — Start Local Firebase Emulators (Development Only)
# Runs Functions (5001), Firestore (8080), Auth (9099), and UI (4000)

echo "Starting PropMatch AI Firebase Local Emulator Suite..."
echo "Project: property-71665"
echo "Functions: http://127.0.0.1:5001 (asia-southeast1)"
echo "Firestore: http://127.0.0.1:8080"
echo "Auth: http://127.0.0.1:9099"
echo "UI: http://127.0.0.1:4000"
echo ""

firebase emulators:start --only functions,firestore,auth --project property-71665
