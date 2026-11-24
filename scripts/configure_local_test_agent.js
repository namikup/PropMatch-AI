/**
 * PropMatch AI — Dedicated Local Test Agent Configuration Helper
 *
 * PURPOSE:
 * Configures your OWN Facebook Page, Page Access Token, and Agent Identity inside
 * the local Firebase Firestore Emulator (127.0.0.1:8080).
 *
 * STRICT SAFETY & ISOLATION GUARDS:
 * - Operates EXCLUSIVELY on the local Firestore Emulator (127.0.0.1 or localhost). Refuses to touch production.
 * - Associates test webhooks ONLY with your dedicated test agent (e.g., test-agent-dev-001).
 * - Zero references to pilot-agent-malik-001 or proj-penang-pilot-001.
 * - NEVER logs or exposes raw access tokens or client secrets to stdout or terminal logs.
 * - Halts seeding without data mutation if required credentials are not yet set.
 *
 * USAGE:
 * export TEST_AGENT_ID="test-agent-dev-001"
 * export TEST_FACEBOOK_PAGE_ID="YOUR_ACTUAL_PAGE_ID"
 * export TEST_FACEBOOK_PAGE_NAME="My Test Real Estate Page"
 * export TEST_PAGE_ACCESS_TOKEN="YOUR_ACTUAL_PAGE_ACCESS_TOKEN"
 *
 * node scripts/configure_local_test_agent.js
 */

const http = require("http");

// Configuration from environment variables
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT_ID = "property-71665";

const TEST_AGENT_ID = process.env.TEST_AGENT_ID || "test-agent-dev-001";
const TEST_AGENT_NAME = process.env.TEST_AGENT_NAME || "Developer Test Agent";
const TEST_PAGE_ID = process.env.TEST_FACEBOOK_PAGE_ID || "";
const TEST_PAGE_NAME = process.env.TEST_FACEBOOK_PAGE_NAME || "Developer Real Estate Page";
const TEST_PAGE_TOKEN = process.env.TEST_PAGE_ACCESS_TOKEN || "";
const TEST_AD_ACCOUNT_ID = process.env.TEST_AD_ACCOUNT_ID || "act_dev_test_999";

/**
 * Validates that the target host is strictly a local loopback address.
 * Throws a fatal security error if external hosts are targeted.
 */
function validateLocalEmulatorHost(host) {
  if (!host || typeof host !== "string") {
    throw new Error("Invalid emulator host: host must be a non-empty string");
  }
  const parts = host.split(":");
  const hostname = parts[0];
  const port = parseInt(parts[1], 10);

  const isLocal = hostname === "127.0.0.1" || hostname === "localhost";
  if (!isLocal || isNaN(port)) {
    throw new Error(
      `SECURITY BOUNDARY VIOLATION: Target host '${host}' is not a local emulator loopback (127.0.0.1 or localhost). Operations outside the local emulator are strictly prohibited.`
    );
  }
  return { hostname, port };
}

/**
 * Checks connectivity to the Firestore Emulator.
 * Queries the official emulator root health-check endpoint (GET http://<host>/).
 * The Firestore Emulator responds with HTTP 200 and body 'Ok'.
 */
function checkFirestoreEmulatorHealth(host = EMULATOR_HOST, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    try {
      const { hostname, port } = validateLocalEmulatorHost(host);

      const req = http.request(
        {
          hostname,
          port,
          path: "/",
          method: "GET",
          timeout: timeoutMs
        },
        (res) => {
          let body = "";
          res.on("data", (chunk) => (body += chunk));
          res.on("end", () => {
            const trimmed = body.trim();
            if (res.statusCode === 200 && trimmed.toLowerCase().includes("ok")) {
              resolve({ ok: true, status: res.statusCode, body: trimmed });
            } else {
              resolve({ ok: false, status: res.statusCode, body: trimmed });
            }
          });
        }
      );

      req.on("timeout", () => {
        req.destroy();
        reject(new Error(`Timeout (${timeoutMs}ms) connecting to Firestore Emulator on http://${host}`));
      });

      req.on("error", (err) => reject(err));
      req.end();
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Helper to make authenticated admin REST API calls against the local Firestore emulator.
 * Uses Authorization: Bearer owner to authenticate as an admin process on the emulator.
 */
function firestoreRestCall(path, method, body, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    try {
      const { hostname, port } = validateLocalEmulatorHost(EMULATOR_HOST);
      const postData = body ? JSON.stringify(body) : "";

      const req = http.request(
        {
          hostname,
          port,
          path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
          method,
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(postData),
            "Authorization": "Bearer owner" // Grants admin emulator access bypassing client rules
          },
          timeout: timeoutMs
        },
        (res) => {
          let resBody = "";
          res.on("data", (chunk) => (resBody += chunk));
          res.on("end", () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve({ ok: true, status: res.statusCode, data: resBody ? JSON.parse(resBody) : {} });
            } else {
              resolve({ ok: false, status: res.statusCode, error: resBody });
            }
          });
        }
      );

      req.on("timeout", () => {
        req.destroy();
        reject(new Error(`Timeout (${timeoutMs}ms) executing ${method} /${path}`));
      });

      req.on("error", reject);
      if (postData) req.write(postData);
      req.end();
    } catch (err) {
      reject(err);
    }
  });
}

function stringValue(val) {
  return { stringValue: val || "" };
}

function booleanValue(val) {
  return { booleanValue: Boolean(val) };
}

function arrayValue(arr) {
  return { values: (arr || []).map((v) => ({ stringValue: String(v) })) };
}

async function configureLocalTestAgent() {
  console.log("================================================================================");
  console.log("  PropMatch AI — Local Test Agent & Facebook Page Setup");
  console.log("================================================================================");
  console.log(`  Target Firestore Emulator: http://${EMULATOR_HOST}`);
  console.log(`  Dedicated Test Agent ID:   ${TEST_AGENT_ID}`);
  console.log(`  Test Agent Name:           ${TEST_AGENT_NAME}`);
  console.log(`  Your Facebook Page ID:     ${TEST_PAGE_ID || "⚠️ [NOT SET]"}`);
  console.log(`  Your Facebook Page Name:   ${TEST_PAGE_NAME}`);
  console.log(`  Page Access Token Status:  ${TEST_PAGE_TOKEN ? `🔒 [SET - ${TEST_PAGE_TOKEN.length} characters (Redacted)]` : "⚠️ [NOT SET]"}`);
  console.log("================================================================================\n");

  // Step 1: Health Check — Verify Firestore Emulator is active and responding
  console.log("1. Checking Firestore Emulator connectivity...");
  let health;
  try {
    health = await checkFirestoreEmulatorHealth(EMULATOR_HOST);
    if (!health.ok) {
      throw new Error(`Emulator health check failed with HTTP ${health.status}: ${health.body}`);
    }
    console.log(`   ✔ Firestore Emulator is ACTIVE and RESPONDING on http://${EMULATOR_HOST} (HTTP ${health.status} "${health.body}")\n`);
  } catch (err) {
    console.error(`   ❌ Cannot connect to Firestore Emulator on http://${EMULATOR_HOST}: ${err.message}`);
    console.error("      Ensure 'firebase emulators:start' is running in Terminal 1 before executing this script.");
    process.exit(1);
  }

  // Step 2: Environment Variable Guard — Do NOT seed unless required credentials are provided
  console.log("2. Verifying required environment variables for seeding...");
  const missingEnv = [];
  if (!TEST_PAGE_ID) missingEnv.push("TEST_FACEBOOK_PAGE_ID");
  if (!TEST_PAGE_TOKEN) missingEnv.push("TEST_PAGE_ACCESS_TOKEN");

  if (missingEnv.length > 0) {
    console.log("   ⚠️  CONNECTIVITY CONFIRMED, BUT SEEDING IS PAUSED:");
    missingEnv.forEach((v) => console.log(`      - Missing required environment variable: ${v}`));
    console.log("\n   Zero documents were modified in the Firestore Emulator.");
    console.log("   When you are ready to seed your personal test agent, run:\n");
    console.log(`   export TEST_AGENT_ID="${TEST_AGENT_ID}"`);
    console.log(`   export TEST_AGENT_NAME="${TEST_AGENT_NAME}"`);
    console.log('   export TEST_FACEBOOK_PAGE_ID="YOUR_ACTUAL_FACEBOOK_PAGE_ID"');
    console.log('   export TEST_FACEBOOK_PAGE_NAME="YOUR_FACEBOOK_PAGE_NAME"');
    console.log('   export TEST_PAGE_ACCESS_TOKEN="YOUR_ACTUAL_PAGE_ACCESS_TOKEN"');
    console.log("   node scripts/configure_local_test_agent.js\n");
    console.log("================================================================================");
    console.log("  Health Check: PASS | Seeding: PAUSED (Awaiting Credentials)");
    console.log("================================================================================\n");
    return { status: "HEALTH_CHECK_ONLY", emulatorActive: true, seeded: false };
  }

  console.log("   ✔ All required environment variables are present.");
  console.log("   Proceeding with isolated test agent configuration in local Firestore Emulator...\n");

  // Step 3: Seed user profile: users/{TEST_AGENT_ID}
  const userPayload = {
    fields: {
      id: stringValue(TEST_AGENT_ID),
      ownerId: stringValue(TEST_AGENT_ID),
      fullName: stringValue(TEST_AGENT_NAME),
      email: stringValue("dev-test-agent@propmatch.local"),
      agency: stringValue("Developer Test Agency"),
      role: stringValue("agent"),
      isPilotAgent: booleanValue(true),
      createdAt: stringValue(new Date().toISOString())
    }
  };
  const userRes = await firestoreRestCall(`users/${TEST_AGENT_ID}`, "PATCH", userPayload);
  console.log(`• Seeded Agent Profile (users/${TEST_AGENT_ID}): ${userRes.ok ? "✅ SUCCESS" : "❌ FAILED"}`);
  if (!userRes.ok) {
    console.error("  Error detail:", userRes.error);
    process.exit(1);
  }

  // Step 4: Seed Meta Connection: meta_connections/{TEST_AGENT_ID}
  const connectionPayload = {
    fields: {
      ownerId: stringValue(TEST_AGENT_ID),
      facebookPageId: stringValue(TEST_PAGE_ID),
      facebookPageName: stringValue(TEST_PAGE_NAME),
      adAccountId: stringValue(TEST_AD_ACCOUNT_ID),
      adAccountName: stringValue("Dev Test Ad Account"),
      currency: stringValue("MYR"),
      timezone: stringValue("Asia/Kuala_Lumpur"),
      dataSource: stringValue("REAL_META_API"),
      isConnected: booleanValue(true),
      connectionStatus: stringValue("Connected"),
      grantedPermissions: {
        arrayValue: arrayValue([
          "ads_read",
          "ads_management",
          "leads_retrieval",
          "pages_manage_metadata",
          "pages_manage_ads",
          "pages_read_engagement",
          "pages_show_list"
        ])
      },
      missingPermissions: { arrayValue: { values: [] } },
      isTokenExpired: booleanValue(false),
      requiresAppReview: booleanValue(false),
      updatedAt: stringValue(new Date().toISOString())
    }
  };
  const connRes = await firestoreRestCall(`meta_connections/${TEST_AGENT_ID}`, "PATCH", connectionPayload);
  console.log(`• Seeded Meta Connection (meta_connections/${TEST_AGENT_ID}): ${connRes.ok ? "✅ SUCCESS" : "❌ FAILED"}`);
  if (!connRes.ok) {
    console.error("  Error detail:", connRes.error);
    process.exit(1);
  }

  // Step 5: Seed Private Credentials: _private_meta_credentials/{TEST_AGENT_ID}
  const credsPayload = {
    fields: {
      ownerId: stringValue(TEST_AGENT_ID),
      accessToken: stringValue(TEST_PAGE_TOKEN),
      tokenType: stringValue("page"),
      pageAccessTokens: {
        mapValue: {
          fields: {
            [TEST_PAGE_ID]: stringValue(TEST_PAGE_TOKEN)
          }
        }
      },
      scope: {
        arrayValue: arrayValue([
          "leads_retrieval",
          "pages_manage_ads",
          "pages_read_engagement"
        ])
      },
      updatedAt: stringValue(new Date().toISOString())
    }
  };
  const credRes = await firestoreRestCall(`_private_meta_credentials/${TEST_AGENT_ID}`, "PATCH", credsPayload);
  console.log(`• Seeded Secure Credentials (_private_meta_credentials/${TEST_AGENT_ID}): ${credRes.ok ? "✅ SUCCESS (Token stored in local emulator)" : "❌ FAILED"}`);
  if (!credRes.ok) {
    console.error("  Error detail:", credRes.error);
    process.exit(1);
  }

  // Step 6: Seed Dedicated Developer Test Project (Isolated from Malik's Eco Horizon listing)
  const testProjectPayload = {
    fields: {
      id: stringValue("proj-test-dev-001"),
      ownerId: stringValue(TEST_AGENT_ID),
      name: stringValue("Developer Test Villa"),
      developer: stringValue("PropMatch Test Developer"),
      location: stringValue("Kuala Lumpur"),
      state: stringValue("Kuala Lumpur"),
      propertyType: stringValue("Condominium"),
      startingPrice: { integerValue: "500000" },
      maximumPrice: { integerValue: "650000" },
      bedrooms: { integerValue: "3" },
      bathrooms: { integerValue: "2" },
      builtUpArea: { integerValue: "1200" },
      purpose: stringValue("Own Stay"),
      status: stringValue("Under Construction")
    }
  };
  const projRes = await firestoreRestCall("projects/proj-test-dev-001", "PATCH", testProjectPayload);
  console.log(`• Seeded Test Listing (projects/proj-test-dev-001): ${projRes.ok ? "✅ SUCCESS" : "❌ FAILED"}`);
  if (!projRes.ok) {
    console.error("  Error detail:", projRes.error);
    process.exit(1);
  }

  console.log("\n================================================================================");
  console.log("  Setup Complete!");
  console.log("  - Any test leads submitted to Page ID '" + TEST_PAGE_ID + "' will route ONLY to '" + TEST_AGENT_ID + "'.");
  console.log("  - Zero leads will be associated with 'pilot-agent-malik-001' or 'proj-penang-pilot-001'.");
  console.log("================================================================================\n");

  return { status: "SEEDED", emulatorActive: true, seeded: true };
}

module.exports = {
  validateLocalEmulatorHost,
  checkFirestoreEmulatorHealth,
  firestoreRestCall,
  configureLocalTestAgent
};

if (require.main === module) {
  configureLocalTestAgent().catch((err) => {
    console.error("Execution failed:", err);
    process.exit(1);
  });
}
