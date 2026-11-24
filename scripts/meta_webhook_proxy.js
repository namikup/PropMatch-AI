/**
 * PropMatch AI — Restricted Local Reverse Proxy for Meta Webhook Testing
 *
 * PURPOSE:
 * Exposes ONLY the single Meta webhook endpoint to external reverse tunnels (Cloudflare Tunnel).
 * Strictly shields all other Firebase Functions emulator endpoints (analyzeProperty,
 * discoverTargetAudience, importProspectsBatch, etc.) from external exposure.
 *
 * ZERO EXTERNAL DEPENDENCIES:
 * Uses exclusively Node.js standard library (http, url).
 *
 * ARCHITECTURE:
 * [Internet: Meta Server]
 *        │ (HTTPS)
 *        ▼
 * [Cloudflare Tunnel]
 *        │ (HTTP localhost:5005)
 *        ▼
 * [This Restricted Proxy: Port 5005] ──▶ Rejects all unauthorized paths with 403 Forbidden
 *        │ (Whitelisted path only)
 *        ▼
 * [Firebase Functions Emulator: Port 5001]
 * (/property-71665/asia-southeast1/metaWebhookHandler)
 */

const http = require("http");
const { URL } = require("url");

// Configuration (overridable via environment variables)
const PROXY_PORT = parseInt(process.env.PROXY_PORT || "5005", 10);
const TARGET_HOST = process.env.EMULATOR_HOST || "127.0.0.1";
const TARGET_PORT = parseInt(process.env.EMULATOR_PORT || "5001", 10);
const ALLOWED_PATH = "/property-71665/asia-southeast1/metaWebhookHandler";

console.log("================================================================================");
console.log("  PropMatch AI — Restricted Webhook Reverse Proxy");
console.log("================================================================================");
console.log(`  Proxy Listening On:       http://127.0.0.1:${PROXY_PORT}`);
console.log(`  Target Emulator Target:   http://${TARGET_HOST}:${TARGET_PORT}`);
console.log(`  Strict Whitelisted Route: ${ALLOWED_PATH}`);
console.log("  All other paths, functions, and admin ports are STRICTLY BLOCKED (403 Forbidden)");
console.log("================================================================================\n");

const server = http.createServer((req, res) => {
  const startTime = Date.now();
  const parsedUrl = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  let pathname = parsedUrl.pathname;

  // Allow root path "/" to map cleanly to the webhook handler for simplified tunnel URLs
  if (pathname === "/") {
    pathname = ALLOWED_PATH;
  }

  // 1. Strict Route Whitelist Enforcement
  if (pathname !== ALLOWED_PATH) {
    const elapsed = Date.now() - startTime;
    console.warn(`[SECURITY 403] BLOCKED unauthorized path: ${req.method} ${parsedUrl.pathname} (${elapsed}ms)`);
    res.writeHead(403, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      error: "Forbidden",
      message: "Access Denied: This tunnel is restricted to the PropMatch AI Meta Webhook handler only.",
      allowedRoute: ALLOWED_PATH
    }));
    return;
  }

  // 2. Strict Method Whitelist (Meta Webhooks only use GET and POST)
  if (req.method !== "GET" && req.method !== "POST") {
    const elapsed = Date.now() - startTime;
    console.warn(`[SECURITY 405] BLOCKED unsupported method: ${req.method} ${pathname} (${elapsed}ms)`);
    res.writeHead(405, { "Content-Type": "application/json", "Allow": "GET, POST" });
    res.end(JSON.stringify({
      error: "Method Not Allowed",
      message: "Only GET (handshake) and POST (event delivery) methods are supported."
    }));
    return;
  }

  // 3. Prepare target request to Firebase Functions Emulator
  const targetPath = `${ALLOWED_PATH}${parsedUrl.search}`;
  const forwardHeaders = { ...req.headers };
  // Set accurate host header for emulator routing
  forwardHeaders["host"] = `${TARGET_HOST}:${TARGET_PORT}`;
  forwardHeaders["x-forwarded-for"] = req.socket.remoteAddress || "127.0.0.1";
  forwardHeaders["x-forwarded-proto"] = req.headers["x-forwarded-proto"] || "https";

  const targetReq = http.request(
    {
      hostname: TARGET_HOST,
      port: TARGET_PORT,
      path: targetPath,
      method: req.method,
      headers: forwardHeaders
    },
    (targetRes) => {
      res.writeHead(targetRes.statusCode, targetRes.headers);
      targetRes.pipe(res);

      targetRes.on("end", () => {
        const elapsed = Date.now() - startTime;
        const statusBadge = targetRes.statusCode >= 200 && targetRes.statusCode < 300 ? "✅" : "⚠️";
        console.log(`[PROXY] ${statusBadge} ${req.method} ${ALLOWED_PATH} -> HTTP ${targetRes.statusCode} (${elapsed}ms)`);
      });
    }
  );

  targetReq.on("error", (err) => {
    const elapsed = Date.now() - startTime;
    console.error(`[PROXY 502] Failed to connect to Firebase Functions Emulator on port ${TARGET_PORT}:`, err.message);
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      error: "Bad Gateway",
      message: `Cannot reach Firebase Functions emulator on http://${TARGET_HOST}:${TARGET_PORT}. Ensure 'firebase emulators:start' is running.`,
      details: err.message
    }));
  });

  // Pipe raw incoming body bytes directly to preserve HMAC signature integrity
  req.pipe(targetReq);
});

server.listen(PROXY_PORT, "127.0.0.1", () => {
  console.log(`🚀 Restricted Webhook Proxy active on http://127.0.0.1:${PROXY_PORT}`);
  console.log("Ready to accept connections from Cloudflare Tunnel.\n");
});

// Graceful shutdown handling
process.on("SIGINT", () => {
  console.log("\nShutting down Restricted Webhook Proxy...");
  server.close(() => process.exit(0));
});
process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
