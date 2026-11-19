# PropMatch AI — Gemini Integration Guide

## 1. Security Architecture & Secret Management

### 1.1 Strict Zero-Frontend Key Exposure Policy
PropMatch AI operates under an absolute security principle:
> **The Gemini API key must NEVER be embedded in Flutter frontend code, client bundles, or web assets.**

All Gemini API calls are initiated and fulfilled exclusively within server-side Firebase Cloud Functions v2 running in `asia-southeast1`.

### 1.2 Google Cloud Secret Manager & Environment Variables
In production Firebase Cloud Functions, secrets are securely injected at runtime using Google Cloud Secret Manager:
```bash
# Set Gemini API key in Google Cloud Secret Manager for Firebase Functions
firebase functions:secrets:set GEMINI_API_KEY
```

In code, the key is accessed via:
```typescript
import { getGeminiConfig } from "./config/gemini.config";

const config = getGeminiConfig();
const apiKey = config.apiKey; // Injected from Secret Manager or process.env
```

If `GEMINI_API_KEY` is absent or unconfigured, the function throws an immediate, sanitized error without attempting network connections.

---

## 2. Model Selection & Configuration

### 2.1 Provider & SDK Identification
- **API Provider**: Google AI Studio / Gemini Developer API (`generativelanguage.googleapis.com`)
- **SDK**: `@google/genai` (Official unified Google Gen AI SDK v3.6.0, migrated from legacy `@google/generative-ai`)
- **Authentication**: API Key via Secret Manager / environment (`GEMINI_API_KEY`)
- **Verification Date**: November 2026
- **Service Tier**: Standard Tier (Synchronous, base rate)

### 2.2 Retired & Shut-Down Models (Permanently Removed)
The following legacy models are retired or shut down and explicitly rejected by the configuration guard:
- `gemini-2.0-flash` (Shut down June 1, 2026)
- `gemini-2.0-flash-lite` (Shut down)
- `gemini-1.5-flash` (Retired)
- `gemini-1.5-pro` (Retired)
- `gemini-1.0-pro` (Retired)

### 2.3 Active Supported Models & Official Pricing (Verified: 2026-11-19)
Official Documentation Source: `https://ai.google.dev/gemini-api/docs/pricing`

PropMatch AI uses a modern, cost-controlled model architecture on the Gemini Developer API:

| Tier | Model Identifier | Primary Usage | Latency (Median) | Input Cost / 1M | Output Cost / 1M (incl. Thinking) | Cached Input / 1M | Reference Free Tier Limits* |
|---|---|---|---|---|---|---|---|
| **Primary** | `gemini-2.5-flash` | Property Analysis, Audience Discovery, Buyer Matching, Marketing Copy | ~1.0s - 2.0s | $0.30 | $2.50 | $0.075 | 15 RPM, 1,500 RPD |
| **Fallback** | `gemini-3.5-flash-lite` | Equivalent-cost failover when primary experiences transient errors | ~0.8s - 1.5s | $0.30 | $2.50 | $0.075 | 15 RPM, 1,500 RPD |
| **Advanced** | `gemini-3.8-flash` | Complex reasoning / enterprise agentic deep dives (Cost-gated) | ~1.5s - 3.0s | $0.75 | $3.75 | $0.1875 | 10 RPM, 1,000 RPD |

*\*Note: Free-tier RPM/RPD values are project-specific reference quotas managed in Google AI Studio, not universally guaranteed SLAs. Standard Pay-as-you-go pricing applies to production traffic.*

> [!WARNING]
> **Scheduled 2027 Price Adjustment for Gemini 3.8 Flash**:
> Per Google's official pricing schedule, `gemini-3.8-flash` introductory rates ($0.75 in / $3.75 out per 1M) remain effective through December 31, 2026. Effective **January 1, 2027**, standard pricing applies at **$1.50 per 1M input / $7.50 per 1M output / $0.375 per 1M cached input**. The `getModelEffectivePricing()` configuration utility automatically accounts for this date transition.

> [!IMPORTANT]
> **Fallback Cost Control Rule**: PropMatch AI pairs `gemini-2.5-flash` (primary) with `gemini-3.5-flash-lite` (fallback). Both models have identical pricing ($0.30 input / $2.50 output per 1M tokens), guaranteeing that automatic fallbacks never inflate agent compute expenses. Fallback to `gemini-3.8-flash` is strictly blocked unless `allowExpensiveFallback` is explicitly enabled.

### 2.4 Hyperparameters & Cost-Guarded Configuration
```typescript
export function getGeminiConfig(injectedKey?: string): GeminiConfig {
  const apiKey = injectedKey || process.env.GEMINI_API_KEY || "";
  const primaryModel = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  const fallbackModel = process.env.GEMINI_FALLBACK_MODEL || "gemini-3.5-flash-lite";
  const allowExpensiveFallback = process.env.GEMINI_ALLOW_EXPENSIVE_FALLBACK === "true";

  validateModelIdentifier(primaryModel, "Primary model");
  validateModelIdentifier(fallbackModel, "Fallback model");
  validateFallbackCostPolicy(primaryModel, fallbackModel, allowExpensiveFallback);

  return {
    apiKey,
    primaryModel,
    fallbackModel,
    allowExpensiveFallback,
    temperature: 0.2, // Low temperature for consistent, analytical rigor
    topP: 0.8,
    maxOutputTokens: 2048,
    timeoutMs: 30000, // 30-second strict deadline
    maxRetries: 2     // Exponential backoff retries for transient errors
  };
}
```

---

## 3. Structured JSON Schema Enforcement

To guarantee predictable, type-safe deserialization in Flutter Web without relying on regex scraping, all Gemini invocations use native JSON mode via the `@google/genai` SDK:
```typescript
import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({ apiKey: config.apiKey });
const response = await ai.models.generateContent({
  model: modelName,
  contents: prompt,
  config: {
    systemInstruction,
    responseMimeType: "application/json",
    temperature: 0.2,
    topP: 0.8,
    maxOutputTokens: 2048
  }
});
```

### 3.1 Defensive Parsing & Markdown Fence Stripping
Even when `responseMimeType: "application/json"` is active, LLMs occasionally enclose JSON within markdown fences (````json ... ````) or append polite introductory text. The `ResponseParser` utility executes a robust multi-stage sanitization:
1. Strips leading ````json and trailing ```` markers.
2. Identifies the outermost `{ ... }` or `[ ... ]` delimiters.
3. Deserializes with `JSON.parse()`.
4. Normalizes all missing or null properties to type-safe defaults (clamping scores between 0–100, defaulting null arrays to `[]`).

---

## 4. Prompt Engineering Patterns for the Malaysian Property Market

### 4.1 Malaysian Market Context System Instruction
All prompts leverage specialized domain personas incorporating Malaysian real estate realities:
```typescript
const systemInstruction = `You are an elite Malaysian real estate investment strategist and marketing analyst for PropMatch AI.
Your role is to deeply analyze Malaysian property project characteristics and return comprehensive, actionable strategic insights.
Always return structured JSON adhering strictly to the required schema. Never include conversational filler.
Consider Malaysian market dynamics, state-level pricing (e.g. Penang, Selangor, KL, Johor), property types, and demographic trends.`;
```

### 4.2 Module Prompt Specifications

#### Module A: Property Deep-Dive Analysis (`analyzeProperty`)
- **Inputs**: Name, Developer, Location, State, Property Type, Price Range (RM), Built-up Area, Bedrooms/Bathrooms, Purpose, Facilities, Amenities, Description.
- **Outputs**:
  - `project_summary`: 2–3 sentence market positioning.
  - `key_selling_points`: 4 concrete value drivers.
  - `potential_buyer_segments`: Preliminary buyer categories.
  - `competitive_advantages`: Location/facility edge vs regional competitors.
  - `potential_objections`: Buyer friction points (e.g., density, maintenance fee).
  - `marketing_angles`: Hooks for campaigns.
  - `recommended_price_positioning`: Pricing context relative to regional median.
  - `analysis_confidence`: High / Medium / Low.

#### Module B: Audience Discovery (`discoverAudienceSegments`)
- **Inputs**: Project specifications.
- **Outputs**: Array of 4 high-relevance persona segments containing:
  - `segment_name`, `description`, `estimated_relevance` (0–100).
  - `buying_motivations`, `potential_objections`.
  - `recommended_marketing_channels` (e.g., Facebook Lead Ads, Instagram Reel, Google Search).
  - `recommended_content_angles`, `evidence`, `assumptions`.

#### Module D: Buyer-Property Matching (`matchBuyers`)
- **Inputs**: Project specification + Array of Sanitized Buyer Profiles (PII stripped).
- **Outputs**: Matched scores evaluated against 5 dimensions:
  1. Budget Compatibility (25%)
  2. Location Compatibility (25%)
  3. Property Type (20%)
  4. Purchase Purpose (15%)
  5. Buying Timeline (15%)
  - Concrete explanations, potential mismatches, data gaps, and recommended agent next action.

#### Module E: Multi-Channel Marketing Content (`generateMarketingContent`)
- **Inputs**: Project specification, Target Segment, Target Channel, Language (`en` / `bm` / `zh`).
- **Outputs**: Punchy headline, persuasive primary text, direct-response CTA, platform-formatted copy with hashtags, and content calendar advice.

---

## 5. Error Handling & Timeout Strategy

### 5.1 Timeout Guard (30 Seconds)
Every LLM call is raced against an explicit timer:
```typescript
let timer: NodeJS.Timeout | null = null;
const timeoutPromise = new Promise<never>((_, reject) => {
  timer = setTimeout(() => {
    reject(new Error(`Gemini API call timed out after ${config.timeoutMs}ms.`));
  }, config.timeoutMs);
});

try {
  const result = await Promise.race([executionPromise, timeoutPromise]);
} finally {
  if (timer) clearTimeout(timer);
}
```

### 5.2 Exponential Backoff Retry Policy
If Gemini responds with HTTP 429 (`RESOURCE_EXHAUSTED`) or 503 (`UNAVAILABLE`), the system backs off before retrying:
$$\text{delay} = 2^{\text{attempt}} \times 500\text{ ms}$$
- Attempt 1 failure: Wait 1,000 ms -> Retry.
- Attempt 2 failure: Wait 2,000 ms -> Retry.
- If primary model exhausted: Switch to fallback model (`gemini-3.5-flash-lite`).
