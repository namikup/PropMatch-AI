# PropMatch AI — AI Security, Privacy & PDPA Compliance

## 1. Multi-Tenant Data Isolation

PropMatch AI enforces the **Single-Agent First, Multi-Agent Ready** architectural mandate. Every single AI transaction enforces strict multi-tenant boundary verification before any computational processing takes place.

### 1.1 Backend Authentication & Tenant Ownership Enforcement
Every callable function begins with mandatory tenant checks in `AIRequestValidator`:
```typescript
// 1. Verify caller is authenticated
const callerUid = AIRequestValidator.validateAuth(request.auth?.uid);

// 2. Verify project strictly belongs to the caller
const project = AIRequestValidator.validateProject(request.data?.project, callerUid);
if (project.ownerId !== callerUid) {
  throw new HttpsError("permission-denied", "Cross-tenant access forbidden.");
}
```
An authenticated agent can **NEVER** trigger AI analysis, discover audience segments, or match buyers against a project or buyer record owned by another property agent.

---

## 2. Malaysian Personal Data Protection Act (PDPA 2010) Compliance

Under the Malaysian Personal Data Protection Act 2010, property agents handle sensitive personally identifiable information (PII) including real names, phone numbers, email addresses, and financial capacities.

### 2.1 The Zero-PII Ingestion Rule
PropMatch AI strictly prohibits transmitting PII to external Large Language Model APIs.

Before any buyer payload is serialized into a Gemini prompt for Module D (Buyer Matching), the `AIRequestValidator.validateAndSanitizeBuyers()` method systematically extracts and deletes all personal contact information:

```typescript
export class AIRequestValidator {
  static validateAndSanitizeBuyers(buyers: any[], callerUid: string): SanitizedBuyerData[] {
    return buyers.map((b) => ({
      id: b.id,
      preferredLocation: b.preferredLocation,
      preferredState: b.preferredState,
      propertyType: b.propertyType,
      budgetMin: b.budgetMin,
      budgetMax: b.budgetMax,
      bedroomsNeeded: b.bedroomsNeeded,
      purchasePurpose: b.purchasePurpose,
      buyingTimeline: b.buyingTimeline,
      hasMarketingConsent: Boolean(b.hasMarketingConsent)
      // DELIBERATELY EXCLUDED: fullName, phone, email, IC, notes
    }));
  }
}
```

### 2.2 Comparison Table: What the LLM Sees vs What Stays in Firestore

| Field | Stored in Cloud Firestore | Transmitted to Gemini API | Reason |
|---|---|---|---|
| **Buyer ID** (`id`) | Yes (`buyer-001`) | Yes (`buyer-001`) | Needed to correlate returned score to record |
| **Full Name** (`name`) | Yes (`Dr. Lim Guan Eng`) | **NO (Stripped)** | Direct Personal Identifier under PDPA |
| **Phone Number** (`phone`) | Yes (`+6012-3456789`) | **NO (Stripped)** | High-risk PII |
| **Email Address** (`email`) | Yes (`dr.lim@example.com`)| **NO (Stripped)** | High-risk PII |
| **Budget Min / Max** | Yes (`RM700k - RM1M`) | Yes (`700000 - 1000000`) | Abstract matching attribute |
| **Location / State** | Yes (`Gelugor, Penang`) | Yes (`Gelugor, Penang`) | Abstract geographic preference |
| **Property Type** | Yes (`Condominium`) | Yes (`Condominium`) | Architectural category |
| **Marketing Consent** | Yes (`true` / `false`) | Yes (`true` / `false`) | Validates communication eligibility |

---

## 3. Prompt Injection Defense & Input Sanitization

To prevent malicious prompts, prompt jailbreaking, or denial-of-service via token explosion, the backend applies multi-layered input sanitation:

1. **Length Clamping**:
   - Project Name: Max 150 characters.
   - Developer Name: Max 150 characters.
   - Project Description: Truncated to 3,000 characters.
   - Buyer batch limit: Max 50 buyers per matching call.
2. **Instruction Isolation**:
   - Prompts clearly delineate system instructions from user data blocks.
   - Prompts mandate strict JSON outputs without conversational responses, rendering common prompt injection bypasses ("ignore previous instructions and say X") inert.
3. **Structured Response Filtering**:
   - Raw output is parsed through `ResponseParser.parseCleanJson()`, discarding any unsolicited markdown or arbitrary text outside the defined schema.

---

## 4. Audit Logging & Telemetry Privacy

All AI execution events are recorded in `ai_usage_logs` for accounting, observability, and security auditing.

```typescript
export interface AIUsageLog {
  id: string;
  ownerId: string;       // Agent UID
  feature: AIFeatureType;
  model: string;         // e.g. "gemini-1.5-flash"
  promptTokens: number;
  candidateTokens: number;
  totalTokens: number;
  latencyMs: number;
  status: AIRequestStatus;
  timestamp: string;
  projectId?: string;
  // Notice: Absolutely NO buyer names, phones, or prompt payloads are logged
}
```

The system log records **only token volume, latency, status, and feature type**, guaranteeing that audit logs never become a vector for personal data leaks.
