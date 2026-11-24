/**
 * Verification test for scripts/meta_webhook_proxy.js security boundaries
 */
const http = require("http");
const { spawn } = require("child_process");

async function runTest() {
  console.log("Testing Restricted Webhook Proxy Security Boundaries...\n");

  // 1. Mock Target Emulator Server on 5991
  const mockTarget = http.createServer((req, res) => {
    if (req.url.startsWith("/property-71665/asia-southeast1/metaWebhookHandler")) {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("CHALLENGE_ACCEPTED_OR_EVENT_RECEIVED");
    } else {
      res.writeHead(500, { "Content-Type": "text/plain" });
      res.end("SHOULD_NEVER_BE_REACHED");
    }
  });

  await new Promise((resolve) => mockTarget.listen(5991, "127.0.0.1", resolve));

  // 2. Start Proxy Process pointing to Mock Target
  const proxyProc = spawn("node", ["scripts/meta_webhook_proxy.js"], {
    env: { ...process.env, PROXY_PORT: "5995", EMULATOR_PORT: "5991" }
  });

  // Wait 500ms for proxy to bind
  await new Promise((resolve) => setTimeout(resolve, 500));

  function makeRequest(method, path) {
    return new Promise((resolve, reject) => {
      const req = http.request(
        {
          hostname: "127.0.0.1",
          port: 5995,
          path,
          method
        },
        (res) => {
          let body = "";
          res.on("data", (chunk) => (body += chunk));
          res.on("end", () => resolve({ status: res.statusCode, body }));
        }
      );
      req.on("error", reject);
      req.end();
    });
  }

  try {
    // Test A: Unauthorized internal function path
    const testA = await makeRequest("GET", "/property-71665/asia-southeast1/analyzeProperty");
    console.log(`• Access to internal function /analyzeProperty: HTTP ${testA.status} (${testA.status === 403 ? "✅ BLOCKED (403)" : "❌ FAILED"})`);
    if (testA.status !== 403) throw new Error("Security check failed: proxy allowed unauthorized function path");

    // Test B: Unauthorized root admin path
    const testB = await makeRequest("GET", "/admin/metrics");
    console.log(`• Access to internal path /admin/metrics:        HTTP ${testB.status} (${testB.status === 403 ? "✅ BLOCKED (403)" : "❌ FAILED"})`);
    if (testB.status !== 403) throw new Error("Security check failed: proxy allowed admin path");

    // Test C: Unauthorized HTTP method
    const testC = await makeRequest("DELETE", "/property-71665/asia-southeast1/metaWebhookHandler");
    console.log(`• Unsupported DELETE method on webhook:        HTTP ${testC.status} (${testC.status === 405 ? "✅ REJECTED (405)" : "❌ FAILED"})`);
    if (testC.status !== 405) throw new Error("Security check failed: proxy allowed DELETE method");

    // Test D: Whitelisted webhook path
    const testD = await makeRequest("GET", "/property-71665/asia-southeast1/metaWebhookHandler?hub.mode=subscribe");
    console.log(`• Allowed Webhook Route:                       HTTP ${testD.status} (${testD.status === 200 ? "✅ FORWARDED (200)" : "❌ FAILED"})`);
    if (testD.status !== 200) throw new Error("Proxy failed to forward whitelisted webhook path");

    // Test E: Root alias
    const testE = await makeRequest("GET", "/?hub.mode=subscribe");
    console.log(`• Root Alias Route ('/'):                      HTTP ${testE.status} (${testE.status === 200 ? "✅ FORWARDED (200)" : "❌ FAILED"})`);
    if (testE.status !== 200) throw new Error("Proxy failed to forward root alias");

    console.log("\nAll proxy security boundary tests PASSED successfully!");
  } finally {
    proxyProc.kill();
    mockTarget.close();
  }
}

runTest().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
