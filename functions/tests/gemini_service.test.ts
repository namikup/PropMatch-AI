import { GeminiService } from "../src/services/gemini_service";
import { DeterministicMatchingEngine } from "../src/services/deterministic_matching";
import { ProjectData, SanitizedBuyerData } from "../src/types/project.types";
import {
  validateModelIdentifier,
  validateFallbackCostPolicy,
  getModelEffectivePricing,
  RETIRED_MODELS,
  ACTIVE_SUPPORTED_MODELS,
  MODEL_PRICING_REGISTRY,
  OFFICIAL_PRICING_SOURCE_URL,
  OFFICIAL_PRICING_VERIFICATION_DATE
} from "../src/config/gemini.config";

const mockGenerateContent = jest.fn();
const mockGoogleGenAIConstructor = jest.fn();

// Mock the modern @google/genai SDK
jest.mock("@google/genai", () => {
  return {
    GoogleGenAI: jest.fn().mockImplementation((options?: { apiKey?: string }) => {
      mockGoogleGenAIConstructor(options);
      return {
        models: {
          generateContent: mockGenerateContent
        }
      };
    })
  };
});

describe("Google Gen AI SDK Migration & Model Registry (Phase 3.1.3)", () => {
  it("should initialize GoogleGenAI with configured API key", async () => {
    process.env.GEMINI_API_KEY = "test-genai-sdk-key";
    process.env.GEMINI_MODEL = "gemini-2.5-flash";
    process.env.GEMINI_FALLBACK_MODEL = "gemini-3.5-flash-lite";

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify({
        project_summary: "SDK Migration Verified",
        key_selling_points: ["Fast", "Modern", "Type-safe"],
        potential_buyer_segments: ["Tech Buyers"],
        competitive_advantages: ["Google Gen AI SDK"],
        potential_objections: [],
        marketing_angles: ["Innovation"],
        recommended_price_positioning: "Fair",
        analysis_confidence: "High"
      }),
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 80, totalTokenCount: 180 }
    });

    const sampleProject: ProjectData = {
      id: "proj_init_test",
      ownerId: "agent_01",
      name: "Test Modern Project",
      developer: "Dev Corp",
      location: "Cyberjaya",
      state: "Selangor",
      propertyType: "Condominium",
      startingPrice: 500000,
      maximumPrice: 800000,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 1000,
      facilities: ["Pool"],
      nearbyAmenities: ["Mall"],
      description: "Modern living.",
      purpose: "Own Stay",
      status: "New Launch"
    };

    await GeminiService.analyzeProperty(sampleProject);

    expect(mockGoogleGenAIConstructor).toHaveBeenCalledWith(
      expect.objectContaining({ apiKey: "test-genai-sdk-key" })
    );
  });

  it("should reject all retired model identifiers including 2.0 and 1.5 versions", () => {
    const retiredToCheck = [
      "gemini-2.0-flash",
      "gemini-2.0-flash-lite",
      "gemini-1.5-flash",
      "gemini-1.5-pro",
      "gemini-1.0-pro"
    ];

    for (const model of retiredToCheck) {
      expect(RETIRED_MODELS).toContain(model);
      expect(() => validateModelIdentifier(model)).toThrow(/retired or shut down and no longer supported/);
    }
  });

  it("should reject unverified or unknown model identifiers", () => {
    expect(() => validateModelIdentifier("gemini-fake-model")).toThrow(/unrecognized or unverified/);
    expect(() => validateModelIdentifier("gpt-4o")).toThrow(/unrecognized or unverified/);
    expect(() => validateModelIdentifier("claude-3-opus")).toThrow(/unrecognized or unverified/);
  });

  it("should reject missing or empty configuration", () => {
    expect(() => validateModelIdentifier("")).toThrow(/cannot be empty or undefined/);
    expect(() => validateModelIdentifier("   ")).toThrow(/cannot be empty or undefined/);
    expect(() => validateModelIdentifier(null as any)).toThrow(/cannot be empty or undefined/);
    expect(() => validateModelIdentifier(undefined as any)).toThrow(/cannot be empty or undefined/);
  });

  it("should accept active supported models (gemini-2.5-flash, gemini-3.5-flash-lite, gemini-3.8-flash)", () => {
    for (const activeModel of ACTIVE_SUPPORTED_MODELS) {
      expect(() => validateModelIdentifier(activeModel)).not.toThrow();
      expect(validateModelIdentifier(activeModel)).toBe(activeModel);
    }
  });

  it("should verify official pricing registry schema, source, and standard service tier", () => {
    expect(OFFICIAL_PRICING_SOURCE_URL).toBe("https://ai.google.dev/gemini-api/docs/pricing");
    expect(OFFICIAL_PRICING_VERIFICATION_DATE).toBe("2026-11-19");

    // gemini-2.5-flash check
    const flashPricing = MODEL_PRICING_REGISTRY["gemini-2.5-flash"];
    expect(flashPricing.inputPricePerMillion).toBe(0.30);
    expect(flashPricing.outputPricePerMillion).toBe(2.50);
    expect(flashPricing.serviceTier).toBe("standard");
    expect(flashPricing.thinkingTokenBilling).toBe("billed_as_output");
    expect(flashPricing.cachedInputPricePerMillion).toBe(0.075);
    expect(flashPricing.referenceFreeTierRpmLimit).toBe(15);

    // gemini-3.5-flash-lite check
    const litePricing = MODEL_PRICING_REGISTRY["gemini-3.5-flash-lite"];
    expect(litePricing.inputPricePerMillion).toBe(0.30);
    expect(litePricing.outputPricePerMillion).toBe(2.50);
    expect(litePricing.serviceTier).toBe("standard");

    // gemini-3.8-flash check
    const advPricing = MODEL_PRICING_REGISTRY["gemini-3.8-flash"];
    expect(advPricing.inputPricePerMillion).toBe(0.75);
    expect(advPricing.outputPricePerMillion).toBe(3.75);
    expect(advPricing.cachedInputPricePerMillion).toBe(0.1875);
    expect(advPricing.futurePricingEffective2027).toBeDefined();
    expect(advPricing.futurePricingEffective2027?.effectiveDate).toBe("2027-01-01");
    expect(advPricing.futurePricingEffective2027?.inputPricePerMillion).toBe(1.50);
    expect(advPricing.futurePricingEffective2027?.outputPricePerMillion).toBe(7.50);
    expect(advPricing.futurePricingEffective2027?.cachedInputPricePerMillion).toBe(0.375);
  });

  it("should calculate effective pricing reflecting 2027 price increase for gemini-3.8-flash", () => {
    const date2026 = new Date("2026-11-19");
    const date2027 = new Date("2027-01-02");

    // Before Jan 1, 2027: promotional introductory rate
    const pricing2026 = getModelEffectivePricing("gemini-3.8-flash", date2026);
    expect(pricing2026.inputPricePerMillion).toBe(0.75);
    expect(pricing2026.outputPricePerMillion).toBe(3.75);
    expect(pricing2026.cachedInputPricePerMillion).toBe(0.1875);

    // On or after Jan 1, 2027: standard rate
    const pricing2027 = getModelEffectivePricing("gemini-3.8-flash", date2027);
    expect(pricing2027.inputPricePerMillion).toBe(1.50);
    expect(pricing2027.outputPricePerMillion).toBe(7.50);
    expect(pricing2027.cachedInputPricePerMillion).toBe(0.375);
  });

  it("should enforce fallback cost control policy across model tiers", () => {
    // Equal cost fallback allowed
    expect(() =>
      validateFallbackCostPolicy("gemini-2.5-flash", "gemini-3.5-flash-lite", false)
    ).not.toThrow();

    // Expensive fallback blocked by default
    expect(() =>
      validateFallbackCostPolicy("gemini-2.5-flash", "gemini-3.8-flash", false)
    ).toThrow(/Cost Control Violation/);

    // Expensive fallback permitted only with explicit override
    expect(() =>
      validateFallbackCostPolicy("gemini-2.5-flash", "gemini-3.8-flash", true)
    ).not.toThrow();
  });
});

describe("GeminiService Request Execution via @google/genai", () => {
  const sampleProject: ProjectData = {
    id: "proj_01",
    ownerId: "agent_01",
    name: "The Light Waterfront",
    developer: "IJM Land",
    location: "Gelugor",
    state: "Penang",
    propertyType: "Condominium",
    startingPrice: 850000,
    maximumPrice: 1500000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 1200,
    facilities: ["Marina", "Infinity Pool", "Tennis Court"],
    nearbyAmenities: ["Penang Bridge", "Queensbay Mall"],
    description: "Iconic waterfront living with high investment potential.",
    purpose: "Own Stay & Investment",
    status: "Completed"
  };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.GEMINI_API_KEY = "test-mock-api-key";
    process.env.GEMINI_MODEL = "gemini-2.5-flash";
    process.env.GEMINI_FALLBACK_MODEL = "gemini-3.5-flash-lite";
  });

  it("should successfully execute analyzeProperty and extract usageMetadata", async () => {
    const mockApiResponse = {
      project_summary: "Premier coastal development in Penang with direct bridge access.",
      key_selling_points: ["Waterfront view", "Strategic connectivity", "Luxury facilities"],
      potential_buyer_segments: ["Affluent Professionals", "Expatriates"],
      competitive_advantages: ["Integrated marina lifestyle"],
      potential_objections: ["High monthly maintenance fee"],
      marketing_angles: ["Prestige waterfront address"],
      recommended_price_positioning: "Priced competitively with regional luxury benchmarks",
      analysis_confidence: "High"
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: {
        promptTokenCount: 200,
        candidatesTokenCount: 150,
        totalTokenCount: 350
      }
    });

    const result = await GeminiService.analyzeProperty(sampleProject);

    expect(result.data.project_summary).toContain("Premier coastal development");
    expect(result.data.key_selling_points.length).toBe(3);
    expect(result.model).toBe("gemini-2.5-flash");
    expect(result.promptTokens).toBe(200);
    expect(result.candidateTokens).toBe(150);
    expect(result.totalTokens).toBe(350);
  });

  it("should throw error and never leak secrets when GEMINI_API_KEY is missing", async () => {
    delete process.env.GEMINI_API_KEY;
    await expect(GeminiService.analyzeProperty(sampleProject)).rejects.toThrow(
      "GEMINI_API_KEY is not configured in environment or secrets."
    );
  });

  it("should successfully execute discoverAudienceSegments with structured JSON", async () => {
    const mockApiResponse = {
      audience_segments: [
        {
          segment_name: "Penang Bridge Commuters",
          description: "Engineers and multinational executives working in Bayan Lepas FIZ.",
          estimated_relevance: 90,
          buying_motivations: ["5 minutes to Penang Bridge"],
          potential_objections: ["Peak hour traffic"],
          recommended_marketing_channels: ["Facebook Ads", "LinkedIn"],
          recommended_content_angles: ["Cut daily commute in half"],
          evidence: ["Close proximity to coastal highway"],
          assumptions: ["Employed in tech/manufacturing sector"]
        }
      ]
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: {
        promptTokenCount: 220,
        candidatesTokenCount: 180,
        totalTokenCount: 400
      }
    });

    const result = await GeminiService.discoverAudienceSegments(sampleProject);
    expect(result.data.audience_segments.length).toBe(1);
    expect(result.data.audience_segments[0].segment_name).toBe("Penang Bridge Commuters");
    expect(result.data.audience_segments[0].estimated_relevance).toBe(90);
    expect(result.totalTokens).toBe(400);
  });

  it("should successfully execute matchBuyers with sanitized buyer data", async () => {
    const sanitizedBuyers: SanitizedBuyerData[] = [
      {
        id: "buyer_101",
        preferredLocation: "Gelugor",
        preferredState: "Penang",
        propertyType: "Condominium",
        budgetMin: 800000,
        budgetMax: 1200000,
        bedroomsNeeded: 3,
        purchasePurpose: "Own Stay",
        buyingTimeline: "Immediate",
        hasMarketingConsent: true
      }
    ];

    const mockApiResponse = {
      matches: [
        {
          buyer_id: "buyer_101",
          project_id: sampleProject.id,
          overall_score: 92,
          matching_factors: {
            budget: 25,
            location: 25,
            property_type: 20,
            purchase_purpose: 12,
            buying_timeline: 10
          },
          reasons: ["Location and budget fit perfectly"],
          potential_mismatches: [],
          missing_information: [],
          recommended_next_action: "Invite to weekend open house"
        }
      ]
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: {
        promptTokenCount: 250,
        candidatesTokenCount: 160,
        totalTokenCount: 410
      }
    });

    const baseline = DeterministicMatchingEngine.calculateMatches(sanitizedBuyers, sampleProject);
    const result = await GeminiService.matchBuyers(sampleProject, sanitizedBuyers, baseline);
    expect(result.data.matches.length).toBe(1);
    expect(result.data.matches[0].overall_score).toBe(baseline.matches[0].overall_score);
    expect(result.data.matches[0].buyer_id).toBe("buyer_101");
  });

  it("should successfully execute generateMarketingContent", async () => {
    const mockApiResponse = {
      headline: "Waterfront Luxury in Penang",
      primary_text: "Experience modern coastal living with panoramic bridge views.",
      call_to_action: "Book Viewing Today",
      channels: [
        {
          platform: "Facebook",
          content: "Special developer incentives available for a limited time.",
          hashtags: ["#PenangProperty", "#WaterfrontLiving"]
        }
      ],
      content_calendar_suggestion: "Post on Tuesday morning",
      language: "en"
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: {
        promptTokenCount: 200,
        candidatesTokenCount: 120,
        totalTokenCount: 320
      }
    });

    const result = await GeminiService.generateMarketingContent(
      sampleProject,
      "Expatriates",
      "Facebook",
      "en"
    );

    expect(result.data.headline).toBe("Waterfront Luxury in Penang");
    expect(result.data.channels[0].hashtags).toContain("#PenangProperty");
  });

  it("should retry on transient 429 error and succeed on second attempt", async () => {
    const mockApiResponse = {
      project_summary: "Recovered successfully after rate limit backoff.",
      key_selling_points: ["Resilient"],
      potential_buyer_segments: ["All"],
      competitive_advantages: ["Quality"],
      potential_objections: [],
      marketing_angles: ["Quality"],
      recommended_price_positioning: "Fair",
      analysis_confidence: "Medium"
    };

    mockGenerateContent.mockRejectedValueOnce(new Error("429 RESOURCE_EXHAUSTED"));
    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50, totalTokenCount: 150 }
    });

    const result = await GeminiService.analyzeProperty(sampleProject);
    expect(result.data.project_summary).toContain("Recovered successfully");
  });

  it("should switch immediately to fallback model on 404 model-unavailable without retrying unavailable model", async () => {
    const mockApiResponse = {
      project_summary: "Fallback model executed successfully.",
      key_selling_points: ["Reliable fallback"],
      potential_buyer_segments: ["All"],
      competitive_advantages: ["High availability"],
      potential_objections: [],
      marketing_angles: ["Stability"],
      recommended_price_positioning: "Fair",
      analysis_confidence: "High"
    };

    // Primary model fails with 404 (model not found)
    mockGenerateContent.mockRejectedValueOnce(new Error("404 models/gemini-2.5-flash is not found"));
    // Fallback model succeeds
    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockApiResponse),
      usageMetadata: { promptTokenCount: 120, candidatesTokenCount: 60, totalTokenCount: 180 }
    });

    const result = await GeminiService.analyzeProperty(sampleProject);
    expect(result.model).toBe("gemini-3.5-flash-lite");
    expect(result.data.project_summary).toContain("Fallback model executed successfully");
  });
});
