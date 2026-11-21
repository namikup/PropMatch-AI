#!/bin/bash
# PropMatch AI — Run Local Emulator Integration Test
# Boots emulators, runs health check and endpoint tests, then terminates cleanly.

echo "Running PropMatch AI Local Emulator Verification..."
npm run build --prefix functions
firebase emulators:exec --only functions,firestore,auth --project property-71665 "node scripts/test_local_emulator.js"
