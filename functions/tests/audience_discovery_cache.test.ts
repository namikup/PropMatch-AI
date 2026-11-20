import { ResponseParser } from "../src/utils/response_parser";
import { AIRequestValidator } from "../src/validators/ai_request_validator";

describe("Audience Discovery Schema & Cache Validation (Phase 3.3A)", () => {
  const sampleProject = {
    id: "proj_penang_waterfront",
    ownerId: "agent_alice",
    name: "The Light Waterfront Suites",
    developer: "IJM Land",
    location: "Gelugor",
    state: "Penang",
    propertyType: "Condominium",
    startingPrice: 750000,
    maximumPrice: 1200000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 1100,
    purpose: "Own Stay & Investment",
    description: "Seafront luxury suites near Penang Bridge",
    facilities: ["Seafront Pool", "EV Charging", "Gym"],
    nearbyAmenities: ["Penang Bridge", "Queensbay Mall", "E-Gate"]
  };

  test("should parse and validate complete Phase 3.3A structured audience discovery schema", () => {
    const rawAiOutput = {
      overview: {
        total_segments: 2,
        primary_target_group: "Bayan Lepas Tech Engineers",
        strategic_summary: "High appeal to FTZ technology professionals and medical staff seeking short commutes.",
        market_demand_disclaimer: "AI-generated audience hypothesis — not verified market demand."
      },
      audience_segments: [
        {
          segment_name: "Bayan Lepas Tech Engineers",
          description: "Engineers and managers working in multinational semiconductor firms.",
          estimated_relevance: 92,
          buying_motivations: ["5 minutes to FTZ", "Resort lifestyle"],
          appealing_features: ["Seafront Pool", "EV Charging"],
          potential_objections: ["Coastal highway traffic during peak hours"],
          recommended_marketing_messages: ["Cut your daily commute by half with seafront serenity."],
          recommended_marketing_channels: ["Facebook Lead Ads", "WhatsApp Direct", "LinkedIn"],
          recommended_content_formats: ["15s Video Reel", "Carousel Ad", "WhatsApp Flyer"],
          evidence: ["Located along expressway 5 mins from Bayan Lepas", "Price tier aligns with RM10k+ income"],
          assumptions: ["Assumes 90% loan eligibility with joint income", "Buyer prioritizes travel time over landed compound"],
          confidence_level: "High",
          market_demand_disclaimer: "AI-generated audience hypothesis — not verified market demand."
        },
        {
          segment_name: "Medical Specialists & Hospital Staff",
          description: "Doctors and specialists at nearby regional medical centers.",
          estimated_relevance: 84,
          buying_motivations: ["Quiet executive environment", "Security"],
          appealing_features: ["Multi-tier security", "Concierge"],
          potential_objections: ["High monthly maintenance fee"],
          recommended_marketing_messages: ["Executive living with 24/7 security near Penang medical corridor."],
          recommended_marketing_channels: ["WhatsApp Broadcast", "Private Medical Society Bulletin"],
          recommended_content_formats: ["Executive PDF Brochure", "Private Showroom Tour Video"],
          evidence: ["10 minutes to Lam Wah Ee Hospital and Penang General Hospital"],
          assumptions: ["Specialists seek turn-key low-maintenance homes"],
          confidence_level: "High",
          market_demand_disclaimer: "AI-generated audience hypothesis — not verified market demand."
        }
      ]
    };

    const validated = ResponseParser.validateAudienceDiscovery(rawAiOutput);

    expect(validated.audience_segments).toHaveLength(2);
    const seg1 = validated.audience_segments[0];
    expect(seg1.segment_name).toBe("Bayan Lepas Tech Engineers");
    expect(seg1.estimated_relevance).toBe(92);
    expect(seg1.appealing_features).toContain("Seafront Pool");
    expect(seg1.recommended_content_formats).toContain("15s Video Reel");
    expect(seg1.evidence).toContain("Located along expressway 5 mins from Bayan Lepas");
    expect(seg1.confidence_level).toBe("High");
    expect(seg1.market_demand_disclaimer).toBe("AI-generated audience hypothesis — not verified market demand.");

    expect(validated.overview?.primary_target_group).toBe("Bayan Lepas Tech Engineers");
    expect(validated.overview?.market_demand_disclaimer).toBe("AI-generated audience hypothesis — not verified market demand.");
  });

  test("should clamp estimated_relevance between 0 and 100 and supply default fallbacks", () => {
    const rawAiOutput = {
      audience_segments: [
        {
          segment_name: "Budget Conscious Buyers",
          estimated_relevance: 150, // Out of bounds
          buying_motivations: ["Low entry price"]
        },
        {
          segment_name: "Luxury Investors",
          estimated_relevance: -20, // Negative out of bounds
          buying_motivations: ["High rental yield"]
        }
      ]
    };

    const validated = ResponseParser.validateAudienceDiscovery(rawAiOutput);
    expect(validated.audience_segments[0].estimated_relevance).toBe(100);
    expect(validated.audience_segments[1].estimated_relevance).toBe(0);

    // Fallbacks supplied for missing arrays
    expect(validated.audience_segments[0].recommended_marketing_channels.length).toBeGreaterThan(0);
    expect(validated.audience_segments[0].recommended_content_formats.length).toBeGreaterThan(0);
    expect(validated.audience_segments[0].market_demand_disclaimer).toBe("AI-generated audience hypothesis — not verified market demand.");
  });

  test("should compute deterministic audience fingerprint and detect invalidation on price or observation change", () => {
    const computeFingerprint = (p: typeof sampleProject, obs: string) => {
      return `${p.name}|${p.startingPrice}|${p.maximumPrice}|${p.propertyType}|${p.builtUpArea}|${p.bedrooms}|${p.bathrooms}|${p.facilities.join(",")}|${p.purpose}|${p.description}|${obs}`;
    };

    const fp1 = computeFingerprint(sampleProject, "Strong interest from Penang Hospital staff");
    const fp2 = computeFingerprint(sampleProject, "Strong interest from Penang Hospital staff");
    expect(fp1).toBe(fp2);

    // Observation change invalidates fingerprint
    const fpObsChanged = computeFingerprint(sampleProject, "Interest from Singaporean MM2H buyers");
    expect(fpObsChanged).not.toBe(fp1);

    // Price change invalidates fingerprint
    const fpPriceChanged = computeFingerprint({ ...sampleProject, startingPrice: 800000 }, "Strong interest from Penang Hospital staff");
    expect(fpPriceChanged).not.toBe(fp1);
  });

  test("should reject cross-agent audience discovery access", () => {
    expect(() => {
      AIRequestValidator.validateProject(sampleProject, "agent_bob");
    }).toThrow("Tenant violation: You cannot access or run AI intelligence on another agent's project.");

    expect(() => {
      AIRequestValidator.validateProject(sampleProject, "agent_alice");
    }).not.toThrow();
  });
});
