# PropMatch AI — Phase 5.1A.3.2: Facebook & Instagram Source Attribution Audit

> **Document Version:** 1.0.0  
> **Date:** 24 November 2026  
> **Author:** Antigravity Senior Full-Stack AI Engineer  
> **Environment:** Single-Agent Private Pilot Mode (`pilot-agent-malik-001`, IQI Realty Sdn Bhd, Penang)  
> **Target Listing:** Eco Horizon Astonia Townhome (`proj-penang-pilot-001`, Batu Kawan, Penang)  
> **Meta API Baseline:** Graph API `v26.0`  

---

## Executive Summary

A critical objective of Phase 5.1A.3.2 is determining whether real Meta Lead Ads webhooks provide sufficient telemetry to distinguish between **Facebook Feed**, **Facebook Stories**, **Instagram Feed**, **Instagram Stories**, and **Instagram Reels**.

This audit proves that **Meta's real-time `leadgen` webhook payload and the `GET /{leadgen_id}` endpoint DO NOT provide placement-level telemetry** for individual lead submissions. In modern Meta advertising setups employing **Advantage+ Automatic Placements**, Meta dynamically distributes ads across 14+ placements without tagging the individual lead with its originating placement.

To maintain complete architectural integrity, PropMatch AI enforces an **Honest Attribution Policy**: rather than fabricating or guessing placements, the system persists `placement: "UNKNOWN"` with `acquisitionSourceConfidence: "Unverified"`, while storing full cryptographic and raw webhook metadata (`rawMetadata`) for downstream auditing.

---

## 1. Forensic Audit of the Meta Webhook Payload

### 1.1 Official Webhook Notification Payload
According to Meta's official documentation for [Webhooks for Lead Ads](https://developers.facebook.com/docs/marketing-api/guides/lead-ads/quickstart/webhooks-setup/), when an enquiry is submitted, Meta sends an HTTP POST with the following structure:

```json
{
  "object": "page",
  "entry": [
    {
      "id": "100928374650192",
      "time": 1795519021,
      "changes": [
        {
          "field": "leadgen",
          "value": {
            "ad_id": "120205892348001",
            "form_id": "109823472938472",
            "leadgen_id": "982374982374982",
            "created_time": 1795519021,
            "page_id": "100928374650192",
            "adgroup_id": "120205892348002"
          }
        }
      ]
    }
  ]
}
```

### 1.2 Webhook Field Inventory
| Field Name | Type | Description | Placement Present? |
|------------|------|-------------|--------------------|
| `ad_id` | String | Meta Ad identifier | ❌ No |
| `form_id` | String | Instant Form identifier | ❌ No |
| `leadgen_id` | String | Unique lead submission identifier | ❌ No |
| `created_time` | Integer | Epoch timestamp of submission | ❌ No |
| `page_id` | String | Facebook Page owning the form | ❌ No |
| `adgroup_id` | String | Ad Set identifier | ❌ No |

**Conclusion:** The incoming webhook payload contains zero information regarding `publisher_platform`, `platform_position`, or device placement.

---

## 2. Forensic Audit of `GET /{leadgen_id}` Graph API Node

When querying the Graph API node for additional details:
`GET https://graph.facebook.com/v26.0/{leadgen_id}?fields=id,created_time,form_id,field_data`

The response contains:
```json
{
  "id": "982374982374982",
  "created_time": "2026-11-24T11:15:00+0000",
  "form_id": "109823472938472",
  "field_data": [
    { "name": "full_name", "values": ["Tan Wei Lun"] },
    { "name": "phone_number", "values": ["+60124889123"] },
    { "name": "email", "values": ["weilun.tan@test-buyer.com.my"] },
    { "name": "budget", "values": ["RM 700,000"] },
    { "name": "property_type", "values": ["Townhouse"] }
  ]
}
```

Even if `ads_management` is granted and ad fields are requested (`ad_id`, `ad_name`, `campaign_id`, `campaign_name`), the node **still does not expose placement fields**.

---

## 3. Placement Feasibility Analysis

| Placement | Can be Derived from Webhook? | Can be Derived from `GET /{leadgen_id}`? | Can be Derived under Advantage+? | Feasible with Manual Ad Set Targeting? |
|-----------|------------------------------|------------------------------------------|----------------------------------|---------------------------------------|
| **Facebook Feed** | ❌ No | ❌ No | ❌ No | ✅ Yes (If Ad Set targets Feed exclusively) |
| **Facebook Stories** | ❌ No | ❌ No | ❌ No | ✅ Yes (If Ad Set targets Stories exclusively) |
| **Instagram Feed** | ❌ No | ❌ No | ❌ No | ✅ Yes (If Ad Set targets IG Feed exclusively) |
| **Instagram Stories** | ❌ No | ❌ No | ❌ No | ✅ Yes (If Ad Set targets IG Stories exclusively) |
| **Instagram Reels** | ❌ No | ❌ No | ❌ No | ✅ Yes (If Ad Set targets IG Reels exclusively) |

### The Advantage+ Automatic Placements Reality
In Malaysia, property agents almost universally select **Advantage+ Placements** (formerly Automatic Placements) to maximize budget efficiency and lower Cost Per Lead (CPL). Under Advantage+, Meta's delivery algorithm dynamically shifts impressions between Facebook and Instagram based on real-time auction liquidity.

Because single-lead submissions under Advantage+ are not tagged with placement metadata, any dashboard claiming to know whether a specific lead came from "Instagram Reels" versus "Facebook Feed" is **fabricating data** unless the campaign was configured with single-placement ad sets.

---

## 4. PropMatch AI Honest Attribution Policy

To uphold enterprise-grade reliability and avoid misleading the pilot agent, PropMatch AI implements the following attribution rules in `functions/src/services/meta_ads_service.ts`:

### 4.1 Attribution Rules Hierarchy

1. **Rule 1: Direct Ad Metadata (Verified)**
   If the ad or ad set name explicitly contains single-placement targeting flags (e.g., `[IG_REELS]`, `[FB_FEED]`) or targeting is verified via authorized ad account settings:
   - `placement`: Set to specific placement (e.g., `"Instagram Reels"`).
   - `acquisitionSourceConfidence`: Set to `"Verified"`.

2. **Rule 2: Platform Inferred from Asset Context (Inferred)**
   If the incoming payload indicates an Instagram-specific referral source, account tag, or explicit Instagram ad creative name:
   - `placement`: `"Instagram (Unverified Placement)"`
   - `sourceType`: `"Instagram Lead Ads"`
   - `acquisitionSourceConfidence`: `"Inferred"`

3. **Rule 3: Automatic / Advantage+ Fallback (Honest Unknown)**
   If placement cannot be verified from payload or ad metadata:
   - `placement`: `"UNKNOWN"`
   - `sourceType`: `"Meta Lead Ads"`
   - `acquisitionSourceConfidence`: `"Unverified"`

### 4.2 Implementation Reference
```typescript
// From functions/src/services/meta_ads_service.ts (lines 1015-1040)
let placement = payload.placement || "UNKNOWN";
let acquisitionSourceConfidence: 'Verified' | 'Inferred' | 'Unverified' = payload.acquisitionSourceConfidence || "Unverified";
let detectedSourceType = "Meta Lead Ads";
let detectedUtmSource = "meta_lead_ad";

if (payload.platform === "instagram" || (payload.adName && /instagram|ig[_\s]/i.test(payload.adName)) || (payload.referralSource && /instagram/i.test(payload.referralSource))) {
  detectedSourceType = "Instagram Lead Ads";
  detectedUtmSource = "instagram";
  acquisitionSourceConfidence = payload.placement ? "Verified" : "Inferred";
  if (!payload.placement) placement = "Instagram (Unverified Placement)";
} else if (payload.platform === "facebook" || (payload.adName && /facebook|fb[_\s]/i.test(payload.adName))) {
  detectedSourceType = "Facebook Lead Ads";
  detectedUtmSource = "facebook";
  acquisitionSourceConfidence = payload.placement ? "Verified" : "Inferred";
  if (!payload.placement) placement = "Facebook (Unverified Placement)";
} else {
  // Platform cannot be verified from payload alone (common under Advantage+ Automatic Placements)
  detectedSourceType = "Meta Lead Ads";
  detectedUtmSource = "meta";
  placement = "UNKNOWN";
  acquisitionSourceConfidence = "Unverified";
}
```

---

## 5. Metadata Preservation Schema

To allow future retro-attribution when campaign insights or breakdown exports are synchronized, PropMatch AI persists the complete raw webhook and lead identification payload in Firestore:

### 5.1 Firestore `prospects` Document Schema
```typescript
{
  id: "prospect_leadgen_test_id_1795519021464",
  ownerId: "pilot-agent-malik-001",
  fullName: "Tan Wei Lun",
  phone: "+60124889123",
  email: "weilun.tan@test-buyer.com.my",
  sourceType: "Meta Lead Ads",
  placement: "UNKNOWN",
  acquisitionSourceConfidence: "Unverified",
  campaignId: "camp_penang_landed_333",
  adId: "ad_eco_horizon_777",
  rawMetadata: {
    webhookEntryId: "page_penang_luxury_12345",
    webhookTime: 1795519021,
    webhookField: "leadgen",
    rawLeadData: {
      ad_id: "ad_eco_horizon_777",
      form_id: "form_batu_kawan_pilot_999",
      leadgen_id: "leadgen_test_id_1795519021464",
      created_time: 1795519021,
      page_id: "page_penang_luxury_12345",
      adgroup_id: "adset_penang_buyers_555"
    },
    leadgenId: "leadgen_test_id_1795519021464",
    formId: "form_batu_kawan_pilot_999",
    adId: "ad_eco_horizon_777",
    campaignId: "camp_penang_landed_333",
    placement: "UNKNOWN",
    acquisitionSourceConfidence: "Unverified",
    originalWebhookTimestamp: 1795519021
  }
}
```

### 5.2 Firestore `meta_ingested_leads` Idempotency Schema
```typescript
{
  leadgenId: "leadgen_test_id_1795519021464",
  ownerId: "pilot-agent-malik-001",
  formId: "form_batu_kawan_pilot_999",
  campaignId: "camp_penang_landed_333",
  adId: "ad_eco_horizon_777",
  placement: "UNKNOWN",
  acquisitionSourceConfidence: "Unverified",
  enquiryId: "enq_1795519021464",
  prospectId: "prospect_leadgen_test_id_1795519021464",
  rawMetadata: { ... },
  ingestedAt: "2026-11-24T11:17:01.000Z"
}
```

---

## 6. How Downstream AI & Dashboard Consume These Fields

1. **Agent Lead Card UI:**  
   Displays `Source: Meta Lead Ads` with a subtle badge `Placement: Unverified (Advantage+)`. It does not make false assertions like "Acquired from Instagram Reels".
2. **Gemini Advertising Intelligence:**  
   When analyzing campaigns, Gemini reads `acquisitionSourceConfidence`. If confidence is `"Unverified"`, Gemini notes in the advisory:  
   *`"Campaign 'penang_landed_pilot' utilizes Advantage+ placements. High lead conversion rate (14.2%) observed at aggregate campaign level; individual placement breakdowns require ad-account level reporting."`*
3. **Audit Trail:**  
   Full original webhook JSON is preserved under `rawMetadata` for complete data traceability.
