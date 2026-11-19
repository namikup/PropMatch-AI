# PropMatch AI — AI Usage & Cost Control Architecture

## 1. Unit Economics & Token Pricing (Verified: 2026-11-19)

Documentation Source: `https://ai.google.dev/gemini-api/docs/pricing`

PropMatch AI utilizes `gemini-2.5-flash` as its primary operational model on the Google Gemini Developer API.
Official published rates:
- **Input Tokens**: $0.30 per 1,000,000 tokens ($0.00030 per 1,000 tokens)
- **Output Tokens**: $2.50 per 1,000,000 tokens ($0.00250 per 1,000 tokens) (Thinking tokens billed as output tokens)
- **Cached Input Tokens**: $0.075 per 1,000,000 tokens
- **Fallback Model**: `gemini-3.5-flash-lite` ($0.30 input / $2.50 output per 1M tokens — identical cost profile)

### 1.1 Service Tier Comparison & Implementation Scope
Google Gemini Developer API provides four distinct service tiers:
1. **Standard Tier (Implemented)**: Full base price, synchronous, immediate response. This is the production tier used by PropMatch AI for live agent dashboard operations.
2. **Priority Tier**: 75%–100% price premium over Standard. Low-latency, non-sheddable compute for mission-critical enterprise applications.
3. **Flex Tier**: 50% discount compared to Standard. Synchronous with best-effort latency (1–15 min target) using off-peak capacity.
4. **Batch Tier**: 50% discount compared to Standard. Asynchronous bulk processing (up to 24-hour turnaround) for background data ingestion.

*PropMatch AI exclusively utilizes **Standard Tier** for all interactive agent-facing callable functions.*

### 1.2 Assumed Workload Token Breakdown by AI Feature

| Module | Feature Name | Assumed Input Tokens | Assumed Output Tokens | Total Tokens | Approx Cost per Invocation (USD) | Approx Cost per Invocation (MYR) |
|---|---|---|---|---|---|---|
| **Module A** | Property Deep Analysis | 220 | 200 | 420 | $0.000566 | ~RM 0.0025 |
| **Module B** | Audience Discovery | 250 | 280 | 530 | $0.000775 | ~RM 0.0035 |
| **Module D** | Buyer Matching (20 Buyers) | 300 | 250 | 550 | $0.000715 | ~RM 0.0032 |
| **Module E** | Marketing Copy Generation | 200 | 220 | 420 | $0.000610 | ~RM 0.0027 |

**Assumed Workload Details**:
- **Property Analysis (Module A)**: ~220 input tokens (project name, developer, location, state, type, price range, bedrooms/bathrooms, built-up sqft, facilities, amenities, description) + ~200 output tokens (structured JSON summary, 4 key selling points, 3 segments, advantages, objections, angles, pricing recommendation).
- **Audience Discovery (Module B)**: ~250 input tokens (project specs and targeting prompts) + ~280 output tokens (4 detailed persona segments with demographic profile, marketing channels, content angles, evidence).
- **Buyer Matching for 20 Buyers (Module D)**: ~300 input tokens (project specs + 20 sanitized buyer profiles with budgets, locations, purposes, timelines) + ~250 output tokens (scored JSON array with 5-factor breakdown, reasons, mismatches, and recommended actions).
- **Marketing Copy (Module E)**: ~200 input tokens (target segment, project attributes, platform choice, language) + ~220 output tokens (punchy headline, body copy, CTA, platform hashtags, posting schedule).

**Average Blended Cost per Complete Property Campaign Flow** (Modules A + B + D + E):
$$\text{Total Campaign Tokens: } \approx 970 \text{ in} + 950 \text{ out} = 1,920 \text{ total}$$
$$\text{Cost per Project Workflow} \approx \$0.00266 \text{ USD} \ (\approx \text{RM } 0.012)$$

### 1.3 Workload Specificity Notice for 500 Monthly Requests
> [!IMPORTANT]
> **Workload-Dependent Cost Disclaimer**:
> Estimating that 500 monthly operations per agent costs under **$0.40 USD (RM 1.80)** strictly assumes the standard workload distribution modeled above (~1,000 average tokens per invocation on `gemini-2.5-flash`).
> If an agent runs intensive multi-buyer batches (e.g. 50 buyers per batch) or if the advanced `gemini-3.8-flash` model is authorized after January 1, 2027 ($1.50 in / $7.50 out per 1M), monthly compute expenses will scale from $0.40 up to $4.50+ depending on workload volume and reasoning token generation.

### 1.4 Separation of Pre-Flight Estimates vs Actual Provider Usage
- **Pre-Flight Estimation**: `AIUsageService.calculateEstimatedCostUsd` computes projected costs for UI preview, budgeting, and capacity planning based on current rate cards.
- **Post-Execution Accounting**: Actual billing and audit logs in `ai_usage_logs` record exact token counts returned by Google Gen AI's `response.usageMetadata` (`promptTokenCount`, `candidatesTokenCount`, `totalTokenCount`, `thoughtsTokenCount`), logging `isEstimated: false`.

---

## 2. Quota Management & Rate Limiting

### 2.1 Default Monthly Quota
Every property agent account is assigned a baseline quota of **500 AI requests per calendar month**.

```typescript
export interface AgentQuotaStatus {
  ownerId: string;
  currentMonthRequests: number;
  monthlyQuota: number;       // Default: 500
  remainingRequests: number;
  isAllowed: boolean;
}
```

### 2.2 Pre-Flight Quota Enforcement
Before invoking the Gemini API, `AIUsageService.checkQuota(ownerId)` evaluates consumption:
1. Queries `ai_usage_logs` where `ownerId == callerUid` and `timestamp >= startOfCurrentMonth`.
2. Compares count against `agent_quotas/{ownerId}.monthlyQuota`.
3. If current requests $\ge$ quota, immediately throws `HttpsError('resource-exhausted')`.

### 2.3 Duplicate Request Suppression & Result Caching
To prevent agents from unintentionally exhausting their monthly quotas by clicking repeatedly:
1. **Firestore Result Caching**:
   `analyzeProperty` persists the completed analysis in Firestore collection `property_analyses/{projectId}_analysis`. Repeated queries for unchanged projects retrieve the cached document, incurring zero Gemini API costs.
2. **Client-Side Debouncing & Loading Flags**:
   The Flutter client disables action buttons and displays a progress indicator while an AI request is in-flight (`_isDiscoveringAudience = true`, `_isMatching = true`), preventing accidental rapid-fire double submissions.

---

## 3. Scale Projection & Infrastructure Budgeting

| Metric | Single Pilot Agent | 100 Active Agents | 1,000 Active Agents | 10,000 Scale (Enterprise) |
|---|---|---|---|---|
| **Monthly Invocations** | ~150 calls | ~25,000 calls | ~350,000 calls | ~4,000,000 calls |
| **Total Monthly Tokens** | ~75,000 tokens | ~12,500,000 tokens | ~175,000,000 tokens | ~2,000,000,000 tokens |
| **Gemini API Cost / Month** | **< $0.15 USD** | **~$35.00 USD** | **~$480.00 USD** | **~$5,500.00 USD** |
| **Firebase Cloud Functions** | Free Tier | Free Tier | ~$1.20 USD | ~$15.00 USD |
| **Estimated Total Compute** | **< $0.15 USD** | **~$35.00 USD** | **~$481.20 USD** | **~$5,515.00 USD** |

The centralized serverless architecture guarantees linear cost scaling with near-zero idle compute overhead.
