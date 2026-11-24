# PropMatch AI — Phase 5.1A.3: OAuth & Credential Security Audit (Corrected)

**Target Pilot Agent**: Malik Tan (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
**Execution Environment**: Single-Agent Private Pilot Mode  
**Backend Framework**: Firebase Cloud Functions v2 (Node.js 20 / TypeScript)  
**Region**: `asia-southeast1` (Singapore)  
**Audit Date**: November 2026 (Phase 5.1A.3.1 Technical Corrections)  

---

## 1. Executive Security Overview

This security audit inspects the cryptographic guarantees, token handling pipelines, storage boundaries, and client-server isolation mechanisms protecting Meta credentials in PropMatch AI.

Following the Phase 5.1A.3.1 technical review, this audit verifies that permission updates, central version configuration, and fallback mechanisms strictly preserve all security guarantees:
- **CSRF Protection via HMAC-SHA256**: Timing-safe verification using `crypto.timingSafeEqual`.
- **Zero Token Leakage**: Tokens never leave the backend Cloud Functions execution environment.
- **Server-Side Credential Isolation**: Secure storage in `_private_meta_credentials/{ownerId}` governed by Firestore default-deny rules.
- **Strict Read-Only Enforcement**: Immutable application code boundary preventing any write operations to Meta advertising accounts.

---

## 2. Cryptographic OAuth State & CSRF Protection

### 2.1 State Generation Architecture

In `functions/src/services/meta_ads_service.ts`:
```typescript
static generateOAuthState(ownerId: string, secretKey: string): string {
  const nonce = crypto.randomBytes(16).toString("hex");
  const timestamp = Date.now();
  const payload = JSON.stringify({ ownerId, nonce, timestamp });
  const hmac = crypto.createHmac("sha256", secretKey).update(payload).digest("hex");
  return Buffer.from(JSON.stringify({ payload, hmac })).toString("base64url");
}
```

- **Cryptographic Entropy**: 16-byte cryptographically secure pseudorandom nonce (`crypto.randomBytes(16)`).
- **Tenant & Identity Binding**: Embeds the authenticated agent's `ownerId` directly into the signed payload.
- **Temporal Lifetime**: Timestamp enforces a strict **15-minute expiration** window.
- **Integrity Seal**: HMAC-SHA256 signature generated with the server's `META_APP_SECRET`.

### 2.2 Constant-Time Verification

```typescript
static verifyOAuthState(stateString: string, expectedOwnerId: string, secretKey: string): boolean {
  try {
    const decoded = JSON.parse(Buffer.from(stateString, "base64url").toString("utf-8"));
    const { payload, hmac } = decoded;
    const expectedHmac = crypto.createHmac("sha256", secretKey).update(payload).digest("hex");
    const hmacBuffer = Buffer.from(hmac, "hex");
    const expectedBuffer = Buffer.from(expectedHmac, "hex");

    // Constant-time comparison prevents timing side-channel attacks
    if (hmacBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(hmacBuffer, expectedBuffer)) {
      return false;
    }

    const data = JSON.parse(payload);
    if (data.ownerId !== expectedOwnerId) return false;

    // Enforce 15-minute maximum lifetime
    const maxAgeMs = 15 * 60 * 1000;
    if (Date.now() - data.timestamp > maxAgeMs) return false;

    return true;
  } catch (_) {
    return false;
  }
}
```

**Guarantees Verified**:
- Prevents authorization code interception or injection by malicious third parties.
- Prevents cross-agent token binding (Agent B cannot bind their Meta account to Agent A's profile).
- Rejects expired state tokens (> 15 mins).
- Constant-time comparison eliminates timing side-channel analysis.

---

## 3. Short-to-Long-Lived Token Exchange

PropMatch AI implements a two-step server-to-server token exchange:
1. **Short-Lived User Token**: Obtained via client OAuth redirect (~1–2 hour lifespan).
2. **Long-Lived User Token Exchange**: Backend exchanges short token via `GET /v26.0/oauth/access_token?grant_type=fb_exchange_token&client_id={id}&client_secret={secret}&fb_exchange_token={shortToken}`.
   - Yields a **60-day long-lived User Access Token**.
3. **Permanent Page Access Tokens**: Backend queries `GET /v26.0/me/accounts` with the 60-day user token. Page Access Tokens derived from a long-lived user token **do not expire** as long as the user retains administrative access to the Page.
4. **Credential Persistence**: Stored exclusively in server-only collection `_private_meta_credentials/{ownerId}`.

---

## 4. Server-Side Storage Isolation (`_private_meta_credentials`)

### 4.1 Schema Distinction

```
Firestore Root
│
├── meta_connections/{ownerId}          <-- PUBLIC CONFIGURATION (Read-Only to Authenticated Owner)
│     ├── ownerId: "pilot-agent-malik-001"
│     ├── facebookPageId: "109823481234567"
│     ├── facebookPageName: "Malik Tan Real Estate"
│     ├── adAccountId: "act_492019482910"
│     ├── isConnected: true
│     ├── connectionStatus: "Connected"
│     ├── grantedPermissions: ["ads_read", "leads_retrieval", ...]
│     ├── isTokenExpired: false
│     └── (ZERO ACCESS TOKENS OR SECRETS)
│
└── _private_meta_credentials/{ownerId}   <-- SERVER-ONLY (BLOCKED TO CLIENT SDK)
      ├── ownerId: "pilot-agent-malik-001"
      ├── accessToken: "EAABw4..."
      ├── tokenType: "user"
      ├── scope: ["ads_read", "leads_retrieval", ...]
      ├── expiresAt: 1769162400000
      └── pageAccessTokens: { "109823481234567": "EAABw4_PAGE..." }
```

### 4.2 Security Rules Audit (`firestore.rules`)

In `firestore.rules`:
```javascript
match /meta_connections/{ownerId} {
  allow read: if request.auth != null && request.auth.uid == ownerId;
  allow write: if false; // Writes restricted to Cloud Functions Admin SDK
}

// _private_meta_credentials has NO matching rule.
// Evaluates to default-deny: client SDK reads and writes are BLOCKED by default.
```

Even with an authenticated Firebase user session, direct client queries to `_private_meta_credentials` return `PERMISSION_DENIED`.

---

## 5. Zero Token Leakage Verification

1. **API Responses**: No callable Cloud Function (`getMetaConnectionStatus`, `syncMetaCampaigns`, `getMetaCampaigns`, `listMetaAssets`) returns access tokens.
2. **Flutter Web Client**: `lib/models/meta_ads/meta_connection_model.dart` contains zero credential fields.
3. **Application Logs**: `Logger.info` and `Logger.error` do not output tokens or app secrets.
4. **Browser DevTools**: Network traces over HTTPS contain only public metadata.

---

## 6. Evaluation of Updated Permission Requirements on Token Handling

The Phase 5.1A.3.1 permission audit established that:
- `ads_management` is **not** mandatory for retrieving lead questions and customer answers.
- `leads_retrieval` + `pages_manage_ads` + `pages_show_list` + `pages_read_engagement` + `ads_read` is the recommended least-privilege scope.

### Impact on Token Handling:
1. **Token Scope Flexibility**: The backend token inspection endpoint (`/debug_token`) dynamically parses granted scopes. If `ads_management` is missing, the backend does **not** fail or mark the connection as `Reauthorization Required`. Instead, it gracefully activates the core lead fields fallback on `GET /{leadgen_id}`.
2. **Read-Only Code Guarantee**: Even if an agent grants `ads_management`, PropMatch AI's backend contains zero code paths that execute write operations against Meta's Marketing API. The token handling pipeline remains 100% read-only.
3. **Re-Authentication Flow**: When tokens reach 50 days of age, the UI alerts the agent. Re-authorization updates the existing document in `_private_meta_credentials` without disrupting historical campaign telemetry or lead attribution.

---

## 7. Security Audit Verdict

| Criterion | Implementation | Audit Result |
| :--- | :--- | :---: |
| **CSRF State Validation** | HMAC-SHA256 with 16-byte nonce & 15-min TTL | ✅ SECURE |
| **Timing-Safe Equality** | `crypto.timingSafeEqual` across state & webhook HMAC | ✅ VERIFIED |
| **Server-Side Isolation** | `_private_meta_credentials` default-deny in Firestore | ✅ 100% ISOLATED |
| **Zero Client Token Exposure** | No tokens in Flutter Web models, logs, or APIs | ✅ ZERO LEAKAGE |
| **Read-Only Architecture** | Code contains zero write endpoints for campaigns/budgets | ✅ IMMUTABLE |

**Status**: **PASSED OAUTH & CREDENTIAL SECURITY AUDIT**
