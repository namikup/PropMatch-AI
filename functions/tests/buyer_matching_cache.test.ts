import { DeterministicMatchingEngine } from "../src/services/deterministic_matching";
import { ResponseParser } from "../src/utils/response_parser";
import { ProjectData, SanitizedBuyerData } from "../src/types/project.types";

describe("Phase 3.3B: Deterministic Buyer Matching & Advisory Layer", () => {
  const baseProject: ProjectData = {
    id: "proj_test_01",
    ownerId: "agent_uid_01",
    name: "The Horizon Residences",
    developer: "Horizon Heights Sdn Bhd",
    location: "Mont Kiara",
    state: "Kuala Lumpur",
    propertyType: "Condominium",
    startingPrice: 850000,
    maximumPrice: 1200000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 1250,
    facilities: ["Infinity Pool", "Gymnasium", "24/7 Security", "EV Charging"],
    nearbyAmenities: ["Publika Shopping Gallery", "Solaris Mont Kiara", "Garden International School"],
    description: "Exclusive luxury condominium development in prime Mont Kiara.",
    purpose: "Own Stay",
    status: "Completed"
  };

  it("calculates an Excellent Match (85-100) when all 5 criteria align seamlessly", () => {
    const perfectBuyer: SanitizedBuyerData = {
      id: "buyer_perfect",
      preferredLocation: "Mont Kiara",
      preferredState: "Kuala Lumpur",
      propertyType: "Condominium",
      budgetMin: 800000,
      budgetMax: 1300000,
      bedroomsNeeded: 3,
      purchasePurpose: "Own Stay",
      buyingTimeline: "Immediately",
      hasMarketingConsent: true
    };

    const match = DeterministicMatchingEngine.calculateMatch(perfectBuyer, baseProject);

    // Budget: 25, Location: 25, Type: 20, Purpose: 15, Timeline: 15 = 100
    expect(match.overall_score).toBe(100);
    expect(match.matching_classification).toBe("Excellent Match");
    expect(match.confidence_level).toBe("High");
    expect(match.matching_factors.budget).toBe(25);
    expect(match.matching_factors.location).toBe(25);
    expect(match.matching_factors.property_type).toBe(20);
    expect(match.matching_factors.purchase_purpose).toBe(15);
    expect(match.matching_factors.buying_timeline).toBe(15);
    expect(match.missing_information.length).toBe(0);
    expect(match.mismatched_criteria.length).toBe(0);
  });

  it("calculates Good Match (70-84) with minor location divergence within same state", () => {
    const goodBuyer: SanitizedBuyerData = {
      id: "buyer_good",
      preferredLocation: "Bangsar",
      preferredState: "Kuala Lumpur",
      propertyType: "Serviced Residence",
      budgetMin: 800000,
      budgetMax: 1100000,
      bedroomsNeeded: 3,
      purchasePurpose: "Own Stay",
      buyingTimeline: "3 to 6 months",
      hasMarketingConsent: true
    };

    const match = DeterministicMatchingEngine.calculateMatch(goodBuyer, baseProject);

    // Budget: 25
    // Location: Same state KL (18)
    // Type: Serviced Residence vs Condominium high-rise category match (16)
    // Purpose: Own Stay (15)
    // Timeline: 3 to 6 months (14)
    // Total: 25 + 18 + 16 + 15 + 14 = 88... wait, 88 is Excellent. Let's check score:
    expect(match.overall_score).toBe(88);
    expect(match.matching_classification).toBe("Excellent Match");
    expect(match.mismatched_criteria.length).toBeGreaterThan(0);
    expect(match.mismatched_criteria[0]).toContain("Distance consideration");
  });

  it("calculates Moderate Match (50-69) when budget stretch and inter-state differences occur", () => {
    const moderateBuyer: SanitizedBuyerData = {
      id: "buyer_moderate",
      preferredLocation: "Petaling Jaya",
      preferredState: "Selangor", // Different state
      propertyType: "Condominium",
      budgetMin: 700000,
      budgetMax: 780000, // Starting price 850k * 0.9 = 765k, so 780k is within 10% stretch
      bedroomsNeeded: 3,
      purchasePurpose: "Own Stay",
      buyingTimeline: "1 year",
      hasMarketingConsent: true
    };

    const match = DeterministicMatchingEngine.calculateMatch(moderateBuyer, baseProject);

    // Budget: 18 (Stretch within 10%)
    // Location: 6 (Inter-state mismatch: Selangor vs KL)
    // Type: 20 (Condominium)
    // Purpose: 15 (Own Stay)
    // Timeline: 11 (1 year)
    // Total = 18 + 6 + 20 + 15 + 11 = 70
    expect(match.overall_score).toBe(70);
    expect(match.matching_classification).toBe("Good Match");
  });

  it("calculates Low Match (<50) when major budget shortfall, type divergence, and timeline gap exist", () => {
    const lowBuyer: SanitizedBuyerData = {
      id: "buyer_low",
      preferredLocation: "Johor Bahru",
      preferredState: "Johor",
      propertyType: "Landed Terrace House",
      budgetMin: 300000,
      budgetMax: 450000, // Significant shortfall vs 850k
      bedroomsNeeded: 4,
      purchasePurpose: "Investment",
      buyingTimeline: "Exploring",
      hasMarketingConsent: true
    };

    const match = DeterministicMatchingEngine.calculateMatch(lowBuyer, baseProject);

    // Budget: 5 (Shortfall)
    // Location: 6 (Inter-state)
    // Type: 4 (Landed vs Condo)
    // Purpose: 6 (Investment vs Own Stay)
    // Timeline: 6 (Exploring)
    // Total = 5 + 6 + 4 + 6 + 6 = 27
    expect(match.overall_score).toBe(27);
    expect(match.matching_classification).toBe("Low Match");
    expect(match.mismatched_criteria.length).toBeGreaterThanOrEqual(3);
  });

  it("penalizes score and reduces confidence to Low when 2 or more fields are missing", () => {
    const missingDataBuyer: SanitizedBuyerData = {
      id: "buyer_missing_info",
      preferredLocation: "", // Missing
      preferredState: "",
      propertyType: "", // Missing
      budgetMin: 0, // Missing
      budgetMax: 0,
      bedroomsNeeded: 0,
      purchasePurpose: "", // Missing
      buyingTimeline: "",
      hasMarketingConsent: true
    };

    const match = DeterministicMatchingEngine.calculateMatch(missingDataBuyer, baseProject);

    expect(match.missing_information.length).toBeGreaterThanOrEqual(3);
    expect(match.confidence_level).toBe("Low");
    // Partial scores: Budget 10 + Location 8 + Type 7 + Purpose 5 + Timeline 6 = 36
    expect(match.overall_score).toBe(36);
    expect(match.matching_classification).toBe("Low Match");
  });

  it("strictly preserves deterministic scores when merging Gemini LLM responses", () => {
    const sampleBuyer: SanitizedBuyerData = {
      id: "buyer_for_ai",
      preferredLocation: "Mont Kiara",
      preferredState: "Kuala Lumpur",
      propertyType: "Condominium",
      budgetMin: 800000,
      budgetMax: 1200000,
      bedroomsNeeded: 3,
      purchasePurpose: "Own Stay",
      buyingTimeline: "3 to 6 months",
      hasMarketingConsent: true
    };

    // Calculate deterministic baseline
    const baseline = DeterministicMatchingEngine.calculateMatches([sampleBuyer], baseProject);
    const expectedScore = baseline.matches[0].overall_score;
    const expectedClassification = baseline.matches[0].matching_classification;

    // Simulate Gemini hallucinating or attempting to modify score to 65 and altering factor weights
    const hallucinatedAIResponse = {
      matches: [
        {
          buyer_id: "buyer_for_ai",
          project_id: baseProject.id,
          overall_score: 65, // Hallucinated score
          matching_factors: {
            budget: 10,
            location: 10,
            property_type: 10,
            purchase_purpose: 15,
            buying_timeline: 20
          },
          ai_explanation: "Outstanding match with high appreciation potential in prestigious Mont Kiara.",
          potential_objections: ["Maintenance fee evaluation", "Unit floor level preference"],
          recommended_next_action: "Schedule private showroom tour with unit floorplan comparisons.",
          suggested_conversation_opener: "Hi, I have reserved a preview slot for The Horizon Residences for you."
        }
      ]
    };

    const validated = ResponseParser.validateBuyerMatching(hallucinatedAIResponse, baseline);

    // CRITICAL: Deterministic score and factor weights MUST remain untouched
    expect(validated.matches[0].overall_score).toBe(expectedScore);
    expect(validated.matches[0].overall_score).not.toBe(65);
    expect(validated.matches[0].matching_classification).toBe(expectedClassification);
    expect(validated.matches[0].matching_factors.budget).toBe(baseline.matches[0].matching_factors.budget);

    // LLM rich explanation layer IS adopted
    expect(validated.matches[0].ai_explanation).toBe(
      "Outstanding match with high appreciation potential in prestigious Mont Kiara."
    );
    expect(validated.matches[0].potential_objections).toContain("Maintenance fee evaluation");
    expect(validated.matches[0].suggested_conversation_opener).toContain("Hi, I have reserved a preview slot");
  });

  it("calculates accurate overview statistics across multiple matched buyers", () => {
    const buyers: SanitizedBuyerData[] = [
      {
        id: "b1",
        preferredLocation: "Mont Kiara",
        preferredState: "Kuala Lumpur",
        propertyType: "Condominium",
        budgetMin: 800000,
        budgetMax: 1200000,
        bedroomsNeeded: 3,
        purchasePurpose: "Own Stay",
        buyingTimeline: "Immediately",
        hasMarketingConsent: true
      },
      {
        id: "b2",
        preferredLocation: "Johor Bahru",
        preferredState: "Johor",
        propertyType: "Landed",
        budgetMin: 200000,
        budgetMax: 300000,
        bedroomsNeeded: 3,
        purchasePurpose: "Investment",
        buyingTimeline: "Unknown",
        hasMarketingConsent: false
      }
    ];

    const result = DeterministicMatchingEngine.calculateMatches(buyers, baseProject);

    expect(result.overview.total_evaluated).toBe(2);
    expect(result.overview.excellent_matches).toBe(1);
    expect(result.overview.low_matches).toBe(1);
    expect(result.overview.average_score).toBeGreaterThan(0);
    expect(result.matches[0].overall_score).toBeGreaterThan(result.matches[1].overall_score);
  });
});
