# PropMatch AI — AI Backend API Specification

## 1. Overview & General Standards

The PropMatch AI backend exposes callable functions via Firebase Functions v2. All endpoints require user authentication via Firebase Authentication ID tokens.

- **Base Region**: `asia-southeast1` (Singapore)
- **Protocol**: HTTPS / Firebase Callable RPC
- **Authentication**: Mandatory (`request.auth.uid` must be present)
- **Multi-Tenant Isolation**: Mandatory (`ownerId` of resources must strictly match `request.auth.uid`)

---

## 2. API Endpoints

### 2.1 `analyzeProperty` (Module A)

Conducts an exhaustive strategic real estate analysis on a Malaysian property project.

#### Request Payload
```json
{
  "project": {
    "id": "proj-penang-001",
    "ownerId": "agent-12345",
    "name": "The Light Waterfront Suites",
    "developer": "IJM Land",
    "location": "Gelugor",
    "state": "Penang",
    "propertyType": "Condominium",
    "startingPrice": 750000,
    "maximumPrice": 1200000,
    "bedrooms": 3,
    "bathrooms": 2,
    "builtUpArea": 1100,
    "facilities": ["Infinity Pool", "Gymnasium", "Tennis Court"],
    "nearbyAmenities": ["Penang Bridge", "Queensbay Mall"],
    "description": "Luxury seafront condominium with panoramic bridge views.",
    "purpose": "Own Stay & Investment",
    "status": "New Launch"
  }
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "project_summary": "The Light Waterfront Suites is a premier coastal development in Gelugor, Penang offering strategic bridge access and comprehensive lifestyle facilities.",
    "key_selling_points": [
      "Unobstructed sea and Penang Bridge views",
      "5 minutes from Bayan Lepas Free Industrial Zone",
      "Comprehensive resort amenities and private marina access",
      "Proven capital appreciation track record by IJM Land"
    ],
    "potential_buyer_segments": [
      "Bayan Lepas Tech & Multinational Executives",
      "Interstate Investors from Perak and Kedah",
      "Affluent Retiring Couples seeking luxury facilities"
    ],
    "competitive_advantages": [
      "Direct coastal expressway link bypassing inner city congestion",
      "High perceived developer prestige"
    ],
    "potential_objections": [
      "Premium maintenance fees compared to older mainland developments",
      "Dense traffic along coastal highway during morning rush hour"
    ],
    "marketing_angles": [
      "Prestige waterfront living with unmatched bridge connectivity",
      "Prime semiconductor belt rental yield potential"
    ],
    "recommended_price_positioning": "Priced competitively at RM680/sqft compared to George Town prime luxury benchmarks of RM850/sqft.",
    "analysis_confidence": "High"
  },
  "meta": {
    "model": "gemini-2.5-flash",
    "latencyMs": 1842,
    "tokens": 425
  }
}
```

---

### 2.2 `discoverAudienceSegments` (Module B)

Discovers 4 high-relevance, ranked buyer personas specifically tailored to the project.

#### Request Payload
```json
{
  "project": {
    "id": "proj-penang-001",
    "ownerId": "agent-12345",
    "name": "The Light Waterfront Suites",
    "developer": "IJM Land",
    "location": "Gelugor",
    "state": "Penang",
    "propertyType": "Condominium",
    "startingPrice": 750000,
    "maximumPrice": 1200000,
    "bedrooms": 3,
    "bathrooms": 2,
    "builtUpArea": 1100,
    "facilities": ["Infinity Pool", "Gymnasium"],
    "nearbyAmenities": ["Penang Bridge", "Queensbay Mall"],
    "description": "Luxury seafront condominium.",
    "purpose": "Own Stay",
    "status": "New Launch"
  }
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "audience_segments": [
      {
        "segment_name": "Bayan Lepas Tech & Medical Professionals",
        "description": "Engineers, managers, and physicians aged 28-45 working in southern Penang multinational industrial zones.",
        "estimated_relevance": 92,
        "buying_motivations": [
          "10-minute commute to southern multinational industrial parks",
          "Quiet seafront environment to decompress after long shifts"
        ],
        "potential_objections": [
          "High entry price requiring dual-income qualification"
        ],
        "recommended_marketing_channels": [
          "Facebook Lead Ads",
          "LinkedIn Sponsored Content"
        ],
        "recommended_content_angles": [
          "Cut daily travel time in half with coastal highway connectivity"
        ],
        "evidence": [
          "Starting price RM750k matches senior engineering household incomes"
        ],
        "assumptions": [
          "Minimum combined household income of RM14,000/month"
        ]
      }
    ]
  },
  "meta": {
    "model": "gemini-2.5-flash",
    "latencyMs": 2150,
    "tokens": 512
  }
}
```

---

### 2.3 `matchBuyers` (Module D)

Performs 5-dimension AI matching between a project and an array of up to 50 agent buyers.

#### Request Payload
```json
{
  "project": {
    "id": "proj-penang-001",
    "ownerId": "agent-12345",
    "name": "The Light Waterfront Suites",
    "location": "Gelugor",
    "state": "Penang",
    "propertyType": "Condominium",
    "startingPrice": 750000,
    "maximumPrice": 1200000,
    "bedrooms": 3,
    "purpose": "Own Stay"
  },
  "buyers": [
    {
      "id": "buyer-001",
      "ownerId": "agent-12345",
      "preferredLocation": "Gelugor",
      "preferredState": "Penang",
      "propertyType": "Condominium",
      "budgetMin": 700000,
      "budgetMax": 1000000,
      "bedroomsNeeded": 3,
      "purchasePurpose": "Own Stay",
      "buyingTimeline": "Within 3 months",
      "hasMarketingConsent": true
    }
  ]
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "matches": [
      {
        "buyer_id": "buyer-001",
        "project_id": "proj-penang-001",
        "overall_score": 94,
        "matching_factors": {
          "budget": 25,
          "location": 25,
          "property_type": 20,
          "purchase_purpose": 12,
          "buying_timeline": 12
        },
        "reasons": [
          "Budget of RM700k-RM1M directly encompasses starting price of RM750k",
          "Exact match for Gelugor, Penang location preference",
          "Exact match for 3-bedroom Condominium requirement"
        ],
        "potential_mismatches": [],
        "missing_information": [
          "Specific financing pre-approval status unknown"
        ],
        "recommended_next_action": "Invite buyer to private showroom preview this Saturday"
      }
    ]
  },
  "meta": {
    "model": "gemini-2.5-flash",
    "latencyMs": 1980,
    "tokens": 460
  }
}
```

---

### 2.4 `generateMarketingContent` (Module E)

Generates localized, conversion-focused multi-channel marketing copy.

#### Request Payload
```json
{
  "project": { ... },
  "segmentName": "Young Tech Professionals",
  "channel": "Facebook Ad",
  "language": "en"
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "headline": "Wake Up to Ocean Sunrises Just 10 Mins from the Tech Park",
    "primary_text": "Tired of wasting 2 hours daily in Penang bridge traffic? The Light Waterfront offers resort-style living with direct coastal highway access...",
    "call_to_action": "Register for Early Bird Priority Pass",
    "channels": [
      {
        "platform": "Facebook Ad",
        "content": "🌊 Experience coastal luxury without the commute.\n\n✨ 3-Bedroom layouts from RM750,000\n✨ Direct link to Coastal Highway\n✨ Infinity pool & private marina\n\n👇 Click below for floor plans & VIP pricing.",
        "hashtags": ["#PenangProperty", "#TheLightWaterfront", "#DreamHome"]
      }
    ],
    "content_calendar_suggestion": "Schedule for Tuesday & Thursday evenings at 7:30 PM (peak executive mobile engagement)",
    "language": "en"
  },
  "meta": {
    "model": "gemini-2.5-flash",
    "latencyMs": 1420,
    "tokens": 380
  }
}
```

---

### 2.5 `getAIUsageStats`

Retrieves the authenticated agent's quota status and consumption history.

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "quota": {
      "ownerId": "agent-12345",
      "currentMonthRequests": 24,
      "monthlyQuota": 500,
      "remainingRequests": 476,
      "isAllowed": true
    },
    "recentLogs": [ ... ],
    "usageByFeature": {
      "property_analysis": 6,
      "audience_discovery": 10,
      "buyer_matching": 8
    }
  }
}
```

---

## 3. Standard Error Codes & Handling

| Error Code | HTTP Equivalent | Trigger Scenario | Client Handling |
|---|---|---|---|
| `unauthenticated` | 401 Unauthorized | Missing or expired Firebase Auth token | Redirect agent to login screen. |
| `permission-denied` | 403 Forbidden | Requesting resource where `ownerId != auth.uid` | Show permission denial alert. |
| `invalid-argument` | 400 Bad Request | Missing required fields, excessive batch size (>50) | Display form validation error. |
| `resource-exhausted` | 429 Too Many Requests | Agent monthly quota exceeded or Gemini rate limit | Display upgrade prompt or retry notice. |
| `deadline-exceeded` | 504 Gateway Timeout | Model call exceeded 30 seconds | Prompt user to retry with smaller data set. |
| `internal` | 500 Server Error | Unexpected backend or model exception | Transparently fall back to local rule engine. |
