import { ResponseParser } from "../src/utils/response_parser";
import { AIRequestValidator } from "../src/validators/ai_request_validator";

describe("Property Analysis Schema & Cache Validation (Phase 3.2)", () => {
  const callerUid = "agent_test_001";
  const sampleProject = {
    id: "proj_penang_99",
    ownerId: callerUid,
    name: "Straits Residences",
    developer: "Kerjaya Prospek",
    location: "Seri Tanjung Pinang",
    state: "Penang",
    propertyType: "Serviced Residence",
    startingPrice: 950000,
    maximumPrice: 1500000,
    bedrooms: 2,
    bathrooms: 2,
    builtUpArea: 861,
    facilities: ["Infinity Pool", "Sky Lounge"],
    nearbyAmenities: ["Straits Quay Marina"],
    description: "Cosmopolitan seafront living in Penang.",
    purpose: "Own Stay & Investment",
    status: "Completed"
  };

  it("should parse and validate complete Phase 3.2 structured property analysis schema", () => {
    const rawAnalysisPayload = {
      project_summary: "Cosmopolitan waterfront serviced suites in Seri Tanjung Pinang.",
      analysis_confidence: "High",
      recommended_price_positioning: "Premium coastal pricing aligned with affluent expatriate demand.",
      property_overview: {
        name: "Straits Residences",
        location: "Seri Tanjung Pinang",
        state: "Penang",
        property_type: "Serviced Residence",
        price_range: "RM950,000 - RM1,500,000",
        bedrooms: 2,
        bathrooms: 2,
        built_up_area: 861,
        facilities: ["Infinity Pool", "Sky Lounge"],
        description: "Cosmopolitan seafront living in Penang.",
        professional_overview: "High-spec serviced residence adjacent to Straits Quay Marina."
      },
      selling_points: [
        {
          title: "Prime Marina Enclave Address",
          explanation: "Direct doorstep access to marina retail, dining, and promenade.",
          supporting_info: "Agent-provided location: Seri Tanjung Pinang",
          buyer_benefit: "High lifestyle prestige and enduring tenant demand.",
          confidence: "High"
        },
        {
          title: "Manageable Executive Built-Up",
          explanation: "861 sqft 2-bedroom format ideal for expatriates and young couples.",
          supporting_info: "Built-up: 861 sqft, 2 Beds",
          buyer_benefit: "Low maintenance burden with efficient space utilization.",
          confidence: "High"
        }
      ],
      buyer_personas: [
        {
          segment_name: "Expatriate & Tech Senior Executives",
          description: "MNC leadership based in Penang seeking lock-and-leave coastal living.",
          estimated_relevance: 92,
          buying_motivations: ["Marina lifestyle", "Security", "High rental yield"],
          appealing_features: ["Sky Lounge", "Concierge services"],
          potential_objections: ["Maintenance fees"],
          recommended_marketing_angle: "Executive coastal sanctuary minutes from George Town."
        }
      ],
      structured_competitive_advantages: [
        {
          advantage: "Adjacent to Straits Quay Marina",
          explanation: "One of only a few walkable marina residential enclaves in Northern Malaysia.",
          supporting_evidence: "Nearby amenities: Straits Quay Marina",
          evidence_status: "Verified project characteristic"
        }
      ],
      structured_objections: [
        {
          objection: "Premium entry price compared to mainland developments",
          category: "price",
          response_strategy: "Highlight scarce island waterfront land and long-term capital preservation."
        }
      ],
      marketing_strategy: {
        recommended_angles: ["Prestige Waterfront Living", "High-Yield Expat Rental"],
        suitable_audience_segments: ["Expatriates", "Affluent Retirees"],
        suggested_channels: ["Facebook Lead Ads", "Instagram Reels", "Private Open House"],
        advertisement_headlines: ["Wake Up to Sea Views at Straits Residences"],
        social_media_ideas: ["Video walkthrough of the Sky Lounge sunset"],
        recommended_calls_to_action: ["Schedule Private Viewing", "Download E-Brochure"]
      },
      analysis_summary: {
        overall_positioning: "Top-tier luxury serviced suites in Northern Penang.",
        strongest_selling_point: "Direct marina integration.",
        most_relevant_segment: "Expatriates and executives.",
        main_potential_objection: "High entry price point.",
        recommended_next_action: "Launch digital campaign targeted at Penang expat groups.",
        analysis_limitations: [
          "Competitor comparison unavailable without external verified pricing data.",
          "Buyer personas represent marketing hypotheses."
        ]
      },
      missing_information: ["Maintenance fee per sqft"],
      data_provenance: "Google Gen AI (@google/genai) Analysis"
    };

    const parsed = ResponseParser.validatePropertyAnalysis(rawAnalysisPayload);

    expect(parsed.project_summary).toContain("Cosmopolitan waterfront");
    expect(parsed.selling_points).toHaveLength(2);
    expect(parsed.selling_points![0].title).toBe("Prime Marina Enclave Address");
    expect(parsed.selling_points![0].buyer_benefit).toContain("lifestyle prestige");
    expect(parsed.buyer_personas).toHaveLength(1);
    expect(parsed.buyer_personas![0].estimated_relevance).toBe(92);
    expect(parsed.structured_competitive_advantages![0].evidence_status).toBe("Verified project characteristic");
    expect(parsed.structured_objections![0].category).toBe("price");
    expect(parsed.marketing_strategy!.advertisement_headlines).toHaveLength(1);
    expect(parsed.analysis_summary!.analysis_limitations).toHaveLength(2);
    expect(parsed.key_selling_points).toContain("Prime Marina Enclave Address");
  });

  it("should compute deterministic project fingerprint for cache invalidation", () => {
    const computeFingerprint = (p: typeof sampleProject) =>
      `${p.name}|${p.startingPrice}|${p.maximumPrice}|${p.propertyType}|${p.builtUpArea}|${p.bedrooms}|${p.bathrooms}|${p.facilities.join(",")}|${p.purpose}|${p.description}`.trim();

    const fp1 = computeFingerprint(sampleProject);
    const fp2 = computeFingerprint({ ...sampleProject });
    expect(fp1).toBe(fp2);

    // Modify price -> fingerprint changes -> cache invalidation triggered
    const fpModifiedPrice = computeFingerprint({ ...sampleProject, startingPrice: 980000 });
    expect(fpModifiedPrice).not.toBe(fp1);

    // Modify facilities -> fingerprint changes
    const fpModifiedFacilities = computeFingerprint({ ...sampleProject, facilities: ["Infinity Pool", "Sky Lounge", "Tennis Court"] });
    expect(fpModifiedFacilities).not.toBe(fp1);
  });

  it("should reject cross-agent project analysis access", () => {
    const foreignProject = { ...sampleProject, ownerId: "agent_attacker_999" };
    expect(() => AIRequestValidator.validateProject(foreignProject, callerUid)).toThrow(
      expect.objectContaining({ code: "permission-denied" })
    );
  });

  it("should enforce validation of required project fields", () => {
    expect(() => AIRequestValidator.validateProject(null, callerUid)).toThrow(
      expect.objectContaining({ code: "invalid-argument" })
    );
    expect(() => AIRequestValidator.validateProject({ id: "proj_1" }, callerUid)).toThrow(
      expect.objectContaining({ code: "invalid-argument" })
    );
  });
});
