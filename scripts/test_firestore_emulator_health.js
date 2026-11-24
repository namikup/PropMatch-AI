/**
 * PropMatch AI — Focused Firestore Emulator Health Check & Security Test
 *
 * Verifies:
 * 1. Health check detects running Firestore Emulator on 127.0.0.1:8080.
 * 2. Health check catches and reports offline/unreachable ports gracefully.
 * 3. Security Boundary: Script strictly blocks non-loopback hosts (e.g. firestore.googleapis.com).
 * 4. Safe Execution: Running configure_local_test_agent.js without credentials verifies connectivity
 *    and pauses seeding without modifying any data.
 */

const {
  validateLocalEmulatorHost,
  checkFirestoreEmulatorHealth,
  configureLocalTestAgent
} = require("./configure_local_test_agent");

async function runTests() {
  console.log("================================================================================");
  console.log("  PropMatch AI — Firestore Emulator Connectivity & Boundary Test");
  console.log("================================================================================\n");

  let passed = 0;
  let total = 0;

  // Test 1: Connectivity to Running Firestore Emulator
  total++;
  try {
    process.stdout.write("Test 1: Check live Firestore Emulator connectivity (127.0.0.1:8080)... ");
    const result = await checkFirestoreEmulatorHealth("127.0.0.1:8080");
    if (result.ok && result.status === 200 && result.body.toLowerCase().includes("ok")) {
      console.log("✅ PASS (HTTP 200, 'Ok')");
      passed++;
    } else {
      console.log(`❌ FAIL (Unexpected response: ${JSON.stringify(result)})`);
    }
  } catch (err) {
    console.log(`❌ FAIL (Error: ${err.message})`);
  }

  // Test 2: Connectivity failure on offline port
  total++;
  try {
    process.stdout.write("Test 2: Check offline port handling (127.0.0.1:54321)... ");
    await checkFirestoreEmulatorHealth("127.0.0.1:54321", 1000);
    console.log("❌ FAIL (Should have thrown connection error)");
  } catch (err) {
    if (err.message.includes("ECONNREFUSED") || err.message.includes("Timeout")) {
      console.log(`✅ PASS (Properly caught offline port: ${err.code || err.message})`);
      passed++;
    } else {
      console.log(`❌ FAIL (Unexpected error: ${err.message})`);
    }
  }

  // Test 3: Security Boundary — Block external/production hosts
  total++;
  try {
    process.stdout.write("Test 3: Security boundary blocks external hosts (firestore.googleapis.com)... ");
    validateLocalEmulatorHost("firestore.googleapis.com:8080");
    console.log("❌ FAIL (Should have thrown security error)");
  } catch (err) {
    if (err.message.includes("SECURITY BOUNDARY VIOLATION")) {
      console.log("✅ PASS (Blocked non-loopback host)");
      passed++;
    } else {
      console.log(`❌ FAIL (Unexpected error: ${err.message})`);
    }
  }

  // Test 4: Security Boundary — Block public IPs
  total++;
  try {
    process.stdout.write("Test 4: Security boundary blocks remote IP (192.168.1.100:8080)... ");
    validateLocalEmulatorHost("192.168.1.100:8080");
    console.log("❌ FAIL (Should have thrown security error)");
  } catch (err) {
    if (err.message.includes("SECURITY BOUNDARY VIOLATION")) {
      console.log("✅ PASS (Blocked remote IP address)");
      passed++;
    } else {
      console.log(`❌ FAIL (Unexpected error: ${err.message})`);
    }
  }

  // Test 5: Safe Execution — Connectivity verified, seeding halted without credentials
  total++;
  try {
    process.stdout.write("Test 5: Safe configuration run halts when credentials absent... \n");
    // Ensure credentials env vars are empty for this test
    const oldPageId = process.env.TEST_FACEBOOK_PAGE_ID;
    const oldToken = process.env.TEST_PAGE_ACCESS_TOKEN;
    delete process.env.TEST_FACEBOOK_PAGE_ID;
    delete process.env.TEST_PAGE_ACCESS_TOKEN;

    const res = await configureLocalTestAgent();
    if (res.status === "HEALTH_CHECK_ONLY" && res.emulatorActive === true && res.seeded === false) {
      console.log("✅ PASS (Emulator verified, zero mutations executed)");
      passed++;
    } else {
      console.log(`❌ FAIL (Unexpected execution result: ${JSON.stringify(res)})`);
    }

    // Restore env vars
    if (oldPageId) process.env.TEST_FACEBOOK_PAGE_ID = oldPageId;
    if (oldToken) process.env.TEST_PAGE_ACCESS_TOKEN = oldToken;
  } catch (err) {
    console.log(`❌ FAIL (Error: ${err.message})`);
  }

  console.log("\n================================================================================");
  console.log(`  Summary: ${passed}/${total} checks passed`);
  console.log("================================================================================\n");

  if (passed !== total) {
    process.exit(1);
  }
}

if (require.main === module) {
  runTests().catch((err) => {
    console.error("Test runner failed:", err);
    process.exit(1);
  });
}
