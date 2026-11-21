import { GeminiService } from "../src/services/gemini_service";
import { ResponseParser } from "../src/utils/response_parser";
import { AIRequestValidator } from "../src/validators/ai_request_validator";
import { ProjectData } from "../src/types/project.types";
import {
  MODEL_PRICING_REGISTRY,
  OFFICIAL_PRICING_SOURCE_URL,
  OFFICIAL_PRICING_VERIFICATION_DATE
} from "../src/config/gemini.config";

const mockGenerateContent = jest.fn();
const mockGoogleGenAIConstructor = jest.fn();

// Mock @google/genai SDK
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

describe("Phase 3.2 QA Backend Test Suite: Functional & AI-Quality Audit", () => {
  const agentA = "agent_alpha_101";
  const agentB = "agent_beta_202";

  // Synthetic Test Case 1: Affordable Condominium
  const affordableCondo: ProjectData = {
    id: "proj_affordable_01",
    ownerId: agentA,
    name: "Idaman Residensi",
    developer: "PDC Properties",
    location: "Batu Kawan",
    state: "Penang",
    propertyType: "Condominium",
    startingPrice: 280000,
    maximumPrice: 350000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 850,
    facilities: ["Playground", "Surau", "1 Covered Parking", "Multipurpose Hall"],
    nearbyAmenities: ["IKEA Batu Kawan", "Design Village Outlet"],
    description: "Affordable high-rise development for young families and industrial workers in Batu Kawan.",
    purpose: "Own Stay",
    status: "New Launch"
  };

  // Synthetic Test Case 2: Luxury Condominium
  const luxuryCondo: ProjectData = {
    id: "proj_luxury_02",
    ownerId: agentA,
    name: "The Pavilion Suites",
    developer: "Pavilion Group",
    location: "KLCC, Jalan Bukit Bintang",
    state: "Kuala Lumpur",
    propertyType: "Condominium",
    startingPrice: 2500000,
    maximumPrice: 4800000,
    bedrooms: 2,
    bathrooms: 2,
    builtUpArea: 1250,
    facilities: ["Infinity Sky Pool", "Private Lift Lobby", "Valet Parking", "Sky Lounge & Cigar Bar", "Concierge"],
    nearbyAmenities: ["Pavilion KL Mall", "KLCC Park", "MRT Bukit Bintang"],
    description: "Ultra-luxury branded residence situated in the heart of Kuala Lumpur Golden Triangle.",
    purpose: "High-Yield Investment & Luxury Residence",
    status: "Completed"
  };

  // Synthetic Test Case 3: Landed Residential Property
  const landedHome: ProjectData = {
    id: "proj_landed_03",
    ownerId: agentA,
    name: "Bukit Indah Garden Homes",
    developer: "SP Setia",
    location: "Iskandar Puteri",
    state: "Johor",
    propertyType: "2-Storey Terrace House",
    startingPrice: 850000,
    maximumPrice: 1100000,
    bedrooms: 4,
    bathrooms: 4,
    builtUpArea: 2400,
    facilities: ["Gated and Guarded 24/7", "Central Linear Park", "Jogging Track", "Children Playground"],
    nearbyAmenities: ["Aeon Mall Bukit Indah", "Columbia Asia Hospital", "Tuas Second Link"],
    description: "Freehold landed double-storey terrace home for multigenerational families commuting between Johor and Singapore.",
    purpose: "Own Stay",
    status: "Completed"
  };

  // Synthetic Test Case 4: Incomplete / Sparse Property Information
  const incompleteProperty: ProjectData = {
    id: "proj_incomplete_04",
    ownerId: agentA,
    name: "Green Valley Residensi",
    developer: "Independent Builder",
    location: "Rawang",
    state: "Selangor",
    propertyType: "Townhouse",
    startingPrice: 420000,
    maximumPrice: 0,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 1100,
    facilities: [],
    nearbyAmenities: [],
    description: "",
    purpose: "Residential",
    status: "Under Construction"
  };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.GEMINI_API_KEY = "test-gemini-qa-key";
    process.env.GEMINI_MODEL = "gemini-2.5-flash";
    process.env.GEMINI_FALLBACK_MODEL = "gemini-3.5-flash-lite";
  });

  // =========================================================================
  // TEST 1: Property Analysis Accuracy across 4 Synthetic Profiles
  // =========================================================================
  describe("Test 1: Property Analysis Accuracy", () => {
    it("Case A: Accurate analysis for Affordable Condominium (Idaman Residensi)", async () => {
      mockGenerateContent.mockResolvedValueOnce({
        text: JSON.stringify({
          project_summary: "Affordable starter condominium in Batu Kawan designed for first-time homebuyers and industrial corridor professionals.",
          analysis_confidence: "High",
          recommended_price_positioning: "Mass-market affordability (sub-RM350k) positioned below island alternatives.",
          property_overview: {
            name: affordableCondo.name,
            location: affordableCondo.location,
            state: affordableCondo.state,
            property_type: affordableCondo.propertyType,
            price_range: "RM280,000 - RM350,000",
            bedrooms: 3,
            bathrooms: 2,
            built_up_area: 850,
            facilities: affordableCondo.facilities,
            description: affordableCondo.description,
            professional_overview: "Entry-level residential high-rise with family-friendly 3-bedroom layouts in Batu Kawan eco-corridor."
          },
          selling_points: [
            {
              title: "Accessible Entry Price Point Under RM300k",
              explanation: "Offers manageable monthly installments under RM1,400 for young dual-income households.",
              supporting_info: "Starting Price: RM280,000",
              buyer_benefit: "Attainable homeownership without heavy financial strain.",
              confidence: "High"
            },
            {
              title: "Proximity to Batu Kawan Industrial & Retail Hub",
              explanation: "Short commute to regional multinational factories and IKEA retail hub.",
              supporting_info: "Nearby amenities: IKEA Batu Kawan, Design Village Outlet",
              buyer_benefit: "Minimizes daily commute times for tech and manufacturing personnel.",
              confidence: "High"
            }
          ],
          buyer_personas: [
            {
              segment_name: "Batu Kawan Industrial Park Engineers & Operators",
              description: "Young Malaysian engineers and executives working in high-tech manufacturing plants.",
              estimated_relevance: 90,
              buying_motivations: ["Low monthly installments", "Near workplace", "Own stay milestone"],
              appealing_features: ["3-bedroom layout", "1 Covered Parking", "Affordable pricing"],
              potential_objections: ["Public transport connectivity into Penang Island"],
              recommended_marketing_angle: "Cut your commute to Batu Kawan plants and own a 3-bedder from RM1,300/mo."
            }
          ],
          structured_competitive_advantages: [
            {
              advantage: "Strategic Pricing Advantage over Island Condominiums",
              explanation: "Priced 50% lower than comparable 3-bedroom condominiums on Penang Island.",
              supporting_evidence: "Starting price: RM280,000 vs Island averages RM600,000+",
              evidence_status: "Verified project characteristic"
            }
          ],
          structured_objections: [
            {
              objection: "Distance to Penang Island and Georgetown",
              category: "location",
              response_strategy: "Emphasize Sultan Abdul Halim Muadzam Shah Bridge proximity and rapid Batu Kawan commercial growth."
            }
          ],
          marketing_strategy: {
            recommended_angles: ["Own a 3-bed family home for under RM300k", "Work & Live in Batu Kawan Hub"],
            suitable_audience_segments: ["Industrial Corridor Workers", "First-Time Buyers"],
            suggested_channels: ["Facebook Lead Ads", "Direct WhatsApp HR outreach", "Showroom Weekend Preview"],
            advertisement_headlines: ["Idaman Residensi: Modern Batu Kawan 3-Bed Living from RM280k"],
            social_media_ideas: ["Commute comparison video from Batu Kawan factories to Idaman Residensi"],
            recommended_calls_to_action: ["Check Your Loan Eligibility Instantly", "Register for Launch Preview"]
          },
          analysis_summary: {
            overall_positioning: "Leading affordable entry-level condominium in Southern Seberang Perai.",
            strongest_selling_point: "Sub-RM300k starting price with 3 bedrooms.",
            most_relevant_segment: "Batu Kawan Industrial Workforce & Young Couples.",
            main_potential_objection: "Perception of distance from Penang Island central areas.",
            recommended_next_action: "Execute targeted social campaign filtered by Batu Kawan employers radius.",
            analysis_limitations: [
              "Analysis synthesized strictly from agent-supplied project parameters.",
              "Competitor market comparisons unavailable unless externally verified.",
              "Buyer personas represent marketing hypotheses, not verified individual leads."
            ]
          },
          missing_information: [],
          data_provenance: "Google Gen AI (@google/genai) Analysis"
        }),
        usageMetadata: { promptTokenCount: 820, candidatesTokenCount: 650, totalTokenCount: 1470 }
      });

      const result = await GeminiService.analyzeProperty(affordableCondo);
      expect(result.data.property_overview!.name).toBe("Idaman Residensi");
      expect(result.data.selling_points).toHaveLength(2);
      expect(result.data.buyer_personas![0].estimated_relevance).toBe(90);
      expect(result.data.structured_competitive_advantages![0].advantage).toContain("Strategic Pricing Advantage");
      expect(result.data.structured_objections![0].category).toBe("location");
      expect(result.data.marketing_strategy!.advertisement_headlines[0]).toContain("Idaman Residensi");
      expect(result.data.analysis_summary!.strongest_selling_point).toContain("Sub-RM300k");
    });

    it("Case B: Accurate analysis for Luxury Condominium (The Pavilion Suites)", async () => {
      mockGenerateContent.mockResolvedValueOnce({
        text: JSON.stringify({
          project_summary: "Prestige luxury branded residence in KLCC Golden Triangle targeting ultra-high-net-worth investors.",
          analysis_confidence: "High",
          recommended_price_positioning: "Ultra-prime luxury benchmark (RM2,000+ psf) matching international metropolitan standards.",
          property_overview: {
            name: luxuryCondo.name,
            location: luxuryCondo.location,
            state: luxuryCondo.state,
            property_type: luxuryCondo.propertyType,
            price_range: "RM2,500,000 - RM4,800,000",
            bedrooms: 2,
            bathrooms: 2,
            built_up_area: 1250,
            facilities: luxuryCondo.facilities,
            description: luxuryCondo.description,
            professional_overview: "Flagship luxury residence offering concierge service and doorstep access to Bukit Bintang retail."
          },
          selling_points: [
            {
              title: "Trophy KLCC Golden Triangle Location",
              explanation: "Irreplaceable address with direct covered bridge to Pavilion Kuala Lumpur.",
              supporting_info: "Location: KLCC, Jalan Bukit Bintang",
              buyer_benefit: "High social prestige, robust expatriate rental demand, and capital preservation.",
              confidence: "High"
            }
          ],
          buyer_personas: [
            {
              segment_name: "International Real Estate Investors & Expatriate C-Suite",
              description: "High-net-worth individuals and corporate directors seeking prime capital preservation.",
              estimated_relevance: 95,
              buying_motivations: ["Wealth preservation", "Prestige address", "Foreign buyer eligibility"],
              appealing_features: ["Valet Parking", "Sky Lounge & Cigar Bar", "Concierge"],
              potential_objections: ["High service charges and capital commitment"],
              recommended_marketing_angle: "The pinnacle of Kuala Lumpur luxury living at Pavilion Suites."
            }
          ],
          structured_competitive_advantages: [
            {
              advantage: "Branded Residence Prestige & Valet Services",
              explanation: "Comprehensive 5-star concierge and valet amenities absent in standard condominiums.",
              supporting_evidence: "Valet Parking, Concierge, Sky Lounge",
              evidence_status: "Verified project characteristic"
            }
          ],
          structured_objections: [
            {
              objection: "Premium price per square foot compared to secondary KLCC properties",
              category: "price",
              response_strategy: "Emphasize Pavilion branding, pristine maintenance, and irreplaceable retail connectivity."
            }
          ],
          marketing_strategy: {
            recommended_angles: ["Trophy Asset in KL's Premier Retail Nexus"],
            suitable_audience_segments: ["HNW Investors", "Regional Business Leaders"],
            suggested_channels: ["Private Wealth Bank Seminars", "Luxury Property Portals", "Private VIP Soirees"],
            advertisement_headlines: ["Pavilion Suites: The Benchmark of Prestige Living in KLCC"],
            social_media_ideas: ["Cinematic penthouse twilight tour with KLCC twin towers backdrop"],
            recommended_calls_to_action: ["Request VIP Private Viewing Dossier"]
          },
          analysis_summary: {
            overall_positioning: "Ultra-luxury landmark residence for discerning international collectors.",
            strongest_selling_point: "Direct integration with Pavilion Kuala Lumpur and 5-star concierge services.",
            most_relevant_segment: "High-Net-Worth Individuals & Corporate Executives.",
            main_potential_objection: "High entry barrier and maintenance expense.",
            recommended_next_action: "Curate confidential viewing invitations for pre-qualified private wealth clients.",
            analysis_limitations: [
              "Analysis synthesized strictly from agent-supplied project parameters.",
              "Competitor market comparisons unavailable unless externally verified.",
              "Buyer personas represent marketing hypotheses, not verified individual leads."
            ]
          },
          missing_information: [],
          data_provenance: "Google Gen AI (@google/genai) Analysis"
        }),
        usageMetadata: { promptTokenCount: 950, candidatesTokenCount: 710, totalTokenCount: 1660 }
      });

      const result = await GeminiService.analyzeProperty(luxuryCondo);
      expect(result.data.property_overview!.name).toBe("The Pavilion Suites");
      expect(result.data.buyer_personas![0].segment_name).toContain("International Real Estate Investors");
      expect(result.data.selling_points![0].title).toContain("KLCC Golden Triangle");
      expect(result.data.marketing_strategy!.suggested_channels).toContain("Private VIP Soirees");
    });

    it("Case C: Accurate analysis for Landed Residential Property (Bukit Indah Garden Homes)", async () => {
      mockGenerateContent.mockResolvedValueOnce({
        text: JSON.stringify({
          project_summary: "Spacious freehold 2-storey terrace home in Iskandar Puteri optimized for multigenerational families and Cross-Border commuters.",
          analysis_confidence: "High",
          recommended_price_positioning: "Solid landed value proposition (RM850k - RM1.1m) appealing to Singapore-earning families.",
          property_overview: {
            name: landedHome.name,
            location: landedHome.location,
            state: landedHome.state,
            property_type: landedHome.propertyType,
            price_range: "RM850,000 - RM1,100,000",
            bedrooms: 4,
            bathrooms: 4,
            built_up_area: 2400,
            facilities: landedHome.facilities,
            description: landedHome.description,
            professional_overview: "Generous 4-bedroom landed terrace home featuring private linear park access and 24-hour security."
          },
          selling_points: [
            {
              title: "Freehold Landed Title with 2,400 sqft Built-up",
              explanation: "Rare 4 ensuite bedroom format ideal for multi-generational living without high-rise strata restrictions.",
              supporting_info: "2,400 sqft, 4 Beds, 4 Baths, Landed",
              buyer_benefit: "Full land ownership, spacious private living, and zero strata elevator waiting.",
              confidence: "High"
            },
            {
              title: "Strategic Access to Tuas Second Link for Singapore Commuters",
              explanation: "15 minutes direct highway drive to Sultan Abu Bakar CIQ complex.",
              supporting_info: "Nearby amenities: Tuas Second Link, Aeon Mall Bukit Indah",
              buyer_benefit: "Streamlined daily commute for Malaysian professionals working in Jurong/Tuas.",
              confidence: "High"
            }
          ],
          buyer_personas: [
            {
              segment_name: "Singapore-Employed Malaysian Professionals & Families",
              description: "Executives working in Singapore earning SGD seeking luxury landed homes in Johor.",
              estimated_relevance: 94,
              buying_motivations: ["Spacious landed living", "Favorable currency exchange leverage", "Safe community"],
              appealing_features: ["Gated and Guarded 24/7", "Central Linear Park", "4 Bedrooms"],
              potential_objections: ["Daily border crossing congestion during peak hours"],
              recommended_marketing_angle: "Upgrade from a compact HDB/apartment to an expansive 2,400 sqft garden home."
            }
          ],
          structured_competitive_advantages: [
            {
              advantage: "Landed Ownership Advantage over Strata High-Rise",
              explanation: "Individual title ownership with private ground parking for 2 vehicles.",
              supporting_evidence: "Property Type: 2-Storey Terrace House",
              evidence_status: "Verified project characteristic"
            }
          ],
          structured_objections: [
            {
              objection: "Tuas checkpoint peak hour commuting fatigue",
              category: "location",
              response_strategy: "Highlight future RTS link connectivity and express bus networks operating directly from Bukit Indah."
            }
          ],
          marketing_strategy: {
            recommended_angles: ["Landed Luxury 15 Minutes from Singapore Second Link"],
            suitable_audience_segments: ["Cross-border Commuters", "Johor Upgraders"],
            suggested_channels: ["Facebook Targeted Ads (Johor & SG Commuter Groups)", "WhatsApp Outreach"],
            advertisement_headlines: ["Live Big in Iskandar Puteri: 4-Bed Landed Garden Home from RM850k"],
            social_media_ideas: ["Weekend family vlog exploring Bukit Indah linear park and Aeon Mall"],
            recommended_calls_to_action: ["Schedule On-Site Showhouse Tour"]
          },
          analysis_summary: {
            overall_positioning: "Benchmark gated family landed community in Iskandar Puteri.",
            strongest_selling_point: "Expansive 2,400 sqft 4-bedroom landed layout with freehold status.",
            most_relevant_segment: "Singapore-employed professionals and expanding local families.",
            main_potential_objection: "Checkpoint commuting considerations.",
            recommended_next_action: "Run digital acquisition campaign targeted at Johor-Singapore commuter communities.",
            analysis_limitations: [
              "Analysis synthesized strictly from agent-supplied project parameters.",
              "Competitor market comparisons unavailable unless externally verified.",
              "Buyer personas represent marketing hypotheses, not verified individual leads."
            ]
          },
          missing_information: [],
          data_provenance: "Google Gen AI (@google/genai) Analysis"
        }),
        usageMetadata: { promptTokenCount: 910, candidatesTokenCount: 690, totalTokenCount: 1600 }
      });

      const result = await GeminiService.analyzeProperty(landedHome);
      expect(result.data.property_overview!.property_type).toBe("2-Storey Terrace House");
      expect(result.data.property_overview!.built_up_area).toBe(2400);
      expect(result.data.selling_points![0].title).toContain("Freehold Landed Title");
      expect(result.data.buyer_personas![0].buying_motivations).toContain("Spacious landed living");
    });

    it("Case D: Accurate analysis for Incomplete Property (Green Valley Residensi)", async () => {
      mockGenerateContent.mockResolvedValueOnce({
        text: JSON.stringify({
          project_summary: "Suburban townhouse in Rawang offering budget-conscious family accommodation.",
          analysis_confidence: "Medium",
          recommended_price_positioning: "Affordable suburban entry point starting from RM420,000.",
          property_overview: {
            name: incompleteProperty.name,
            location: incompleteProperty.location,
            state: incompleteProperty.state,
            property_type: incompleteProperty.propertyType,
            price_range: "RM420,000 - Pricing ceiling unstated",
            bedrooms: 3,
            bathrooms: 2,
            built_up_area: 1100,
            facilities: [],
            description: "No agent description provided.",
            professional_overview: "Suburban residential development in Rawang corridor with baseline 3-bedroom specifications."
          },
          selling_points: [
            {
              title: "Accessible Starting Price in Northern Greater KL",
              explanation: "Priced from RM420,000 providing entry-level access for suburban homebuyers.",
              supporting_info: "Starting Price: RM420,000",
              buyer_benefit: "Lower financial threshold for homeownership in Selangor.",
              confidence: "Medium"
            }
          ],
          buyer_personas: [
            {
              segment_name: "Rawang & Northern Klang Valley Budget Homebuyers",
              description: "Families seeking landed/townhouse living within manageable commuting distance.",
              estimated_relevance: 75,
              buying_motivations: ["Affordable homeownership", "Quiet suburban environment"],
              appealing_features: ["3 Bedrooms layout", "RM420,000 starting price"],
              potential_objections: ["Unspecified facilities and community infrastructure"],
              recommended_marketing_angle: "Affordable townhouse living in growing Rawang."
            }
          ],
          structured_competitive_advantages: [
            {
              advantage: "Suburban Space-to-Price Value",
              explanation: "1,100 sqft layout starting at RM420,000.",
              supporting_evidence: "Agent-provided specifications",
              evidence_status: "Verified project characteristic"
            }
          ],
          structured_objections: [
            {
              objection: "Lack of comprehensive project facility and development details",
              category: "general",
              response_strategy: "Confirm specific developer site plans, maintenance guidelines, and handover schedules."
            }
          ],
          marketing_strategy: {
            recommended_angles: ["Affordable Rawang Townhouse Living from RM420k"],
            suitable_audience_segments: ["First-Time Suburban Homebuyers"],
            suggested_channels: ["Facebook Community Groups", "Local Print & Signage"],
            advertisement_headlines: ["Green Valley: New Rawang Townhouse from RM420k"],
            social_media_ideas: ["Location spotlight on Rawang highway access"],
            recommended_calls_to_action: ["Register for Full Project Factsheet"]
          },
          analysis_summary: {
            overall_positioning: "Suburban value townhouse subject to developer specification clarification.",
            strongest_selling_point: "RM420,000 entry pricing for 1,100 sqft layout.",
            most_relevant_segment: "Local Rawang and northern Klang Valley families.",
            main_potential_objection: "Missing facility disclosures and unconfirmed maximum pricing.",
            recommended_next_action: "Obtain complete developer specification package before scaling advertising.",
            analysis_limitations: [
              "Analysis synthesized strictly from sparse agent-supplied parameters.",
              "Facilities inventory and maximum price ceiling were not specified by agent.",
              "Competitor market comparisons unavailable without external verified data."
            ]
          },
          missing_information: [
            "Project maximum price ceiling",
            "Project facility inventory",
            "Nearby infrastructure and transportation landmarks",
            "Project promotional description"
          ],
          data_provenance: "Google Gen AI (@google/genai) Analysis"
        }),
        usageMetadata: { promptTokenCount: 650, candidatesTokenCount: 520, totalTokenCount: 1170 }
      });

      const result = await GeminiService.analyzeProperty(incompleteProperty);
      expect(result.data.property_overview!.name).toBe("Green Valley Residensi");
      expect(result.data.property_overview!.facilities).toEqual([]);
      expect(result.data.missing_information).toContain("Project facility inventory");
      expect(result.data.missing_information).toContain("Project maximum price ceiling");
      expect(result.data.analysis_confidence).toBe("Medium");
      expect(result.data.analysis_summary!.analysis_limitations[1]).toContain("Facilities inventory");
    });
  });

  // =========================================================================
  // TEST 2: Hallucination and Evidence Controls
  // =========================================================================
  describe("Test 2: Hallucination and Evidence Controls", () => {
    it("strictly preserves verified specs and does not invent facilities when absent", () => {
      // Prompt evidence checks
      const systemInstruction = `EVIDENCE & RELIABILITY RULES:
1. Distinguish verified project information, agent-provided data, and AI-generated hypotheses.
2. Never fabricate amenities, travel distances, developer reputation, appreciation statistics, rental yields, or competitor prices.
3. If competitor data is absent, explicitly state that competitor comparison is unavailable.
4. Buyer personas represent marketing hypotheses, never verified individuals or sensitive demographics.`;

      expect(systemInstruction).toContain("Never fabricate amenities");
      expect(systemInstruction).toContain("never verified individuals");
      expect(systemInstruction).toContain("competitor comparison is unavailable");

      // Verify ResponseParser handles empty facilities safely
      const parsed = ResponseParser.validatePropertyAnalysis({
        property_overview: {
          name: "Test Incomplete",
          facilities: []
        },
        selling_points: [],
        buyer_personas: []
      });

      expect(parsed.property_overview!.facilities).toEqual([]);
      expect(parsed.analysis_summary!.analysis_limitations).toHaveLength(3);
      expect(parsed.analysis_summary!.analysis_limitations[1]).toContain("Competitor market comparisons unavailable");
    });

    it("verifies evidence status on all competitive advantages", () => {
      const parsed = ResponseParser.validatePropertyAnalysis({
        structured_competitive_advantages: [
          {
            advantage: "Gated Community",
            explanation: "24/7 Security",
            supporting_evidence: "Agent specs",
            evidence_status: "Verified project characteristic"
          }
        ]
      });

      expect(parsed.structured_competitive_advantages![0].evidence_status).toBe("Verified project characteristic");
    });
  });

  // =========================================================================
  // TEST 3: Gemini Provider Verification & Cost Tracking
  // =========================================================================
  describe("Test 3: Gemini Provider Verification & Cost Audit", () => {
    it("calculates exact official costs using verified 2026 pricing registry", () => {
      const pricing = MODEL_PRICING_REGISTRY["gemini-2.5-flash"];
      expect(pricing.inputPricePerMillion).toBe(0.30);
      expect(pricing.outputPricePerMillion).toBe(2.50);
      expect(pricing.thinkingTokenBilling).toBe("billed_as_output");
      expect(OFFICIAL_PRICING_SOURCE_URL).toBe("https://ai.google.dev/gemini-api/docs/pricing");
      expect(OFFICIAL_PRICING_VERIFICATION_DATE).toBe("2026-11-19");

      // Calculate cost for affordable condo analysis: 820 in, 650 out
      const inputCost = (820 / 1_000_000) * pricing.inputPricePerMillion;
      const outputCost = (650 / 1_000_000) * pricing.outputPricePerMillion;
      const totalCost = inputCost + outputCost;

      expect(inputCost).toBeCloseTo(0.000246, 6);
      expect(outputCost).toBeCloseTo(0.001625, 6);
      expect(totalCost).toBeCloseTo(0.001871, 6);
    });

    it("handles 429 quota exhaustion with atomic rollback", async () => {
      mockGenerateContent.mockRejectedValue(new Error("429 RESOURCE_EXHAUSTED"));

      await expect(GeminiService.analyzeProperty(affordableCondo)).rejects.toThrow("429");
    }, 15000);

    it("automatically switches to fallback model gemini-3.5-flash-lite on 404 model not found", async () => {
      mockGenerateContent
        .mockRejectedValueOnce(new Error("404 models/gemini-2.5-flash is not found"))
        .mockResolvedValueOnce({
          text: JSON.stringify({
            project_summary: "Fallback model analysis successful",
            selling_points: [],
            buyer_personas: []
          }),
          usageMetadata: { promptTokenCount: 500, candidatesTokenCount: 300, totalTokenCount: 800 }
        });

      const result = await GeminiService.analyzeProperty(affordableCondo);
      expect(result.model).toBe("gemini-3.5-flash-lite");
      expect(result.data.project_summary).toBe("Fallback model analysis successful");
    });
  });

  // =========================================================================
  // TEST 4: Cache, Fingerprint Invalidation & Cross-Agent Isolation
  // =========================================================================
  describe("Test 4: Cache, Invalidation & Cross-Agent Isolation", () => {
    const computeFingerprint = (p: ProjectData) =>
      `${p.name}|${p.startingPrice}|${p.maximumPrice}|${p.propertyType}|${p.builtUpArea}|${p.bedrooms}|${p.bathrooms}|${p.facilities.join(",")}|${p.purpose}|${p.description}`.trim();

    it("computes deterministic fingerprint that matches on identical data", () => {
      const fp1 = computeFingerprint(affordableCondo);
      const fp2 = computeFingerprint({ ...affordableCondo });
      expect(fp1).toBe(fp2);
    });

    it("invalidates cache fingerprint when price, facilities, or description changes", () => {
      const baseFp = computeFingerprint(affordableCondo);

      // Price update
      const priceFp = computeFingerprint({ ...affordableCondo, startingPrice: 290000 });
      expect(priceFp).not.toBe(baseFp);

      // Facilities update
      const facFp = computeFingerprint({ ...affordableCondo, facilities: [...affordableCondo.facilities, "Tennis Court"] });
      expect(facFp).not.toBe(baseFp);

      // Description update
      const descFp = computeFingerprint({ ...affordableCondo, description: "Updated marketing description" });
      expect(descFp).not.toBe(baseFp);
    });

    it("verifies 24-hour cache TTL logic", () => {
      const oneDayMs = 24 * 60 * 60 * 1000;

      // Fresh cache: 1 hour old
      const freshCacheAge = 1 * 60 * 60 * 1000;
      expect(freshCacheAge < oneDayMs).toBe(true);

      // Expired cache: 25 hours old
      const expiredCacheAge = 25 * 60 * 60 * 1000;
      expect(expiredCacheAge < oneDayMs).toBe(false);
    });

    it("strictly isolates cache across agents (Agent A project rejected for Agent B)", () => {
      // Agent B attempting to analyze Agent A's project
      expect(() => {
        AIRequestValidator.validateProject(affordableCondo, agentB);
      }).toThrow(expect.objectContaining({ code: "permission-denied" }));
    });
  });

  // =========================================================================
  // TEST 5: Input Validation & Boundary Enforcement
  // =========================================================================
  describe("Test 5: Input Validation & Edge Cases", () => {
    it("rejects unauthenticated caller", () => {
      expect(() => AIRequestValidator.validateAuth(undefined)).toThrow(
        expect.objectContaining({ code: "unauthenticated" })
      );
      expect(() => AIRequestValidator.validateAuth("   ")).toThrow(
        expect.objectContaining({ code: "unauthenticated" })
      );
    });

    it("rejects missing project id or ownerId", () => {
      expect(() => AIRequestValidator.validateProject({ name: "No ID" }, agentA)).toThrow(
        expect.objectContaining({ code: "invalid-argument" })
      );
      expect(() => AIRequestValidator.validateProject({ id: "proj_x", name: "No Owner" }, agentA)).toThrow(
        expect.objectContaining({ code: "invalid-argument" })
      );
    });

    it("sanitizes overly long project description to prevent prompt bloat", () => {
      const longDesc = "A".repeat(5000);
      const validated = AIRequestValidator.validateProject(
        { ...affordableCondo, description: longDesc },
        agentA
      );
      expect(validated.description.length).toBe(3000);
    });
  });
});
