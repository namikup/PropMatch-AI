import { GeminiService } from "../src/services/gemini_service";
import { ProjectData, SanitizedBuyerData } from "../src/types/project.types";

const mockGenerateContent = jest.fn();

jest.mock("@google/generative-ai", () => {
  return {
    GoogleGenerativeAI: jest.fn().mockImplementation(() => {
      return {
        getGenerativeModel: jest.fn().mockImplementation(() => {
          return {
            generateContent: mockGenerateContent
          };
        })
      };
    })
  };
});

describe("GeminiService", () => {
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
  });

  it("should successfully execute analyzeProperty and return structured output", async () => {
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
      response: {
        text: () => JSON.stringify(mockApiResponse),
        usageMetadata: {
          promptTokenCount: 200,
          candidatesTokenCount: 150,
          totalTokenCount: 350
        }
      }
    });

    const result = await GeminiService.analyzeProperty(sampleProject);

    expect(result.data.project_summary).toContain("Premier coastal development");
    expect(result.data.key_selling_points.length).toBe(3);
    expect(result.promptTokens).toBe(200);
    expect(result.candidateTokens).toBe(150);
    expect(result.totalTokens).toBe(350);
  });

  it("should successfully execute discoverAudienceSegments", async () => {
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
      response: {
        text: () => JSON.stringify(mockApiResponse),
        usageMetadata: {
          promptTokenCount: 220,
          candidatesTokenCount: 180,
          totalTokenCount: 400
        }
      }
    });

    const result = await GeminiService.discoverAudienceSegments(sampleProject);
    expect(result.data.audience_segments.length).toBe(1);
    expect(result.data.audience_segments[0].segment_name).toBe("Penang Bridge Commuters");
    expect(result.data.audience_segments[0].estimated_relevance).toBe(90);
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
      response: {
        text: () => JSON.stringify(mockApiResponse),
        usageMetadata: {
          promptTokenCount: 250,
          candidatesTokenCount: 160,
          totalTokenCount: 410
        }
      }
    });

    const result = await GeminiService.matchBuyers(sampleProject, sanitizedBuyers);
    expect(result.data.matches.length).toBe(1);
    expect(result.data.matches[0].overall_score).toBe(92);
    expect(result.data.matches[0].buyer_id).toBe("buyer_101");
  });

  it("should retry on transient 429 / resource exhausted error and succeed", async () => {
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

    // First call rejects with 429
    mockGenerateContent.mockRejectedValueOnce(new Error("429 RESOURCE_EXHAUSTED"));
    // Second call succeeds
    mockGenerateContent.mockResolvedValueOnce({
      response: {
        text: () => JSON.stringify(mockApiResponse),
        usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50, totalTokenCount: 150 }
      }
    });

    const result = await GeminiService.analyzeProperty(sampleProject);
    expect(result.data.project_summary).toContain("Recovered successfully");
  });
});
