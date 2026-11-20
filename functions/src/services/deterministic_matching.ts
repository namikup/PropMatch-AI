import { SanitizedBuyerData, ProjectData } from "../types/project.types";
import { BuyerMatchingItem, BuyerMatchingOutput } from "../types/ai.types";

export class DeterministicMatchingEngine {
  /**
   * Deterministic Compatibility Calculation across 5 Fixed Dimensions:
   * 1. Budget Compatibility: 25%
   * 2. Location Compatibility: 25%
   * 3. Property Type: 20%
   * 4. Purchase Purpose: 15%
   * 5. Buying Timeline: 15%
   * Total = 100%
   *
   * Gemini NEVER overrides these deterministic scores.
   */
  static calculateMatch(buyer: SanitizedBuyerData, project: ProjectData): BuyerMatchingItem {
    const reasons: string[] = [];
    const mismatched_criteria: string[] = [];
    const missing_information: string[] = [];
    const potential_objections: string[] = [];

    // 1. Budget Compatibility (Weight: 25%)
    let budgetScore = 0.0;
    if (buyer.budgetMin <= 0 && buyer.budgetMax <= 0) {
      missing_information.push("Buyer has not specified a defined budget range.");
      budgetScore = 10.0; // Partial score for unknown
    } else {
      const projectPrice = project.startingPrice;
      if (buyer.budgetMax >= projectPrice && buyer.budgetMin <= project.maximumPrice) {
        // Direct overlap
        budgetScore = 25.0;
        reasons.push(
          `Budget Match: Project starting price RM${projectPrice.toLocaleString()} is comfortably within buyer’s budget (RM${buyer.budgetMin.toLocaleString()} - RM${buyer.budgetMax.toLocaleString()}).`
        );
      } else if (buyer.budgetMax >= projectPrice * 0.9) {
        // Within 10% gap
        budgetScore = 18.0;
        mismatched_criteria.push(
          `Budget Stretch: Project starting price RM${projectPrice.toLocaleString()} is slightly above buyer max budget RM${buyer.budgetMax.toLocaleString()} (~10% gap).`
        );
        potential_objections.push("Price ceiling slightly exceeds initial budget target.");
      } else if (buyer.budgetMax < projectPrice) {
        budgetScore = 5.0;
        mismatched_criteria.push(
          `Budget Shortfall: Project starting price RM${projectPrice.toLocaleString()} exceeds buyer ceiling RM${buyer.budgetMax.toLocaleString()} significantly.`
        );
        potential_objections.push("High entry price point relative to current qualification.");
      } else {
        budgetScore = 20.0;
        reasons.push("High Budget Capacity: Buyer ceiling exceeds maximum project tier.");
      }
    }

    // 2. Location Compatibility (Weight: 25%)
    let locationScore = 0.0;
    const buyerLoc = (buyer.preferredLocation || "").toLowerCase().trim();
    const buyerState = (buyer.preferredState || "").toLowerCase().trim();
    const projLoc = (project.location || "").toLowerCase().trim();
    const projState = (project.state || "").toLowerCase().trim();

    if (!buyerLoc && !buyerState) {
      missing_information.push("Buyer location preferences are not documented.");
      locationScore = 8.0;
    } else if (projLoc.includes(buyerLoc) || buyerLoc.includes(projLoc)) {
      locationScore = 25.0;
      reasons.push(`Exact Location Match: Project is located in ${project.location}, matching buyer’s preferred area.`);
    } else if (projState && buyerState && projState === buyerState) {
      locationScore = 18.0;
      reasons.push(`State Match: Same state (${project.state}), though slightly different neighbourhood.`);
      mismatched_criteria.push(
        `Distance consideration: Buyer preferred ${buyer.preferredLocation}, while project is in ${project.location}.`
      );
      potential_objections.push("Sub-locality differs from buyer's primary commute corridor.");
    } else {
      locationScore = 6.0;
      mismatched_criteria.push(
        `Inter-State Mismatch: Project is in ${project.state}, but buyer prefers ${buyer.preferredState || "another state"}.`
      );
      potential_objections.push("Different state from preferred residential hub.");
    }

    // 3. Property Type Compatibility (Weight: 20%)
    let propertyTypeScore = 0.0;
    const buyerType = (buyer.propertyType || "").toLowerCase().trim();
    const projType = (project.propertyType || "").toLowerCase().trim();

    if (!buyerType) {
      missing_information.push("Preferred property type is unspecified.");
      propertyTypeScore = 7.0;
    } else if (buyerType === projType || projType.includes(buyerType) || buyerType.includes(projType)) {
      propertyTypeScore = 20.0;
      reasons.push(`Property Type Match: Both seek ${project.propertyType}.`);
    } else if (
      (buyerType.includes("condo") || buyerType.includes("apartment") || buyerType.includes("serviced")) &&
      (projType.includes("condo") || projType.includes("apartment") || projType.includes("serviced"))
    ) {
      propertyTypeScore = 16.0;
      reasons.push(`High-rise Category Match: ${project.propertyType} aligns with buyer high-rise preferences.`);
    } else {
      propertyTypeScore = 4.0;
      mismatched_criteria.push(`Type Divergence: Buyer prefers ${buyer.propertyType}, while project offers ${project.propertyType}.`);
      potential_objections.push("Layout format does not match desired landed/high-rise category.");
    }

    // 4. Purchase Purpose (Weight: 15%)
    let purposeScore = 0.0;
    const buyerPurpose = (buyer.purchasePurpose || "").toLowerCase().trim();
    const projPurpose = (project.purpose || "").toLowerCase().trim();

    if (!buyerPurpose) {
      missing_information.push("Buyer purchase purpose (Own Stay vs Investment) not confirmed.");
      purposeScore = 5.0;
    } else if (
      projPurpose.includes(buyerPurpose) ||
      buyerPurpose.includes(projPurpose) ||
      projPurpose.includes("both") ||
      projPurpose.includes("&")
    ) {
      purposeScore = 15.0;
      reasons.push(`Purpose Alignment: Project suitability (${project.purpose}) accommodates buyer objective (${buyer.purchasePurpose}).`);
    } else {
      purposeScore = 6.0;
      mismatched_criteria.push(`Purpose Gap: Project is optimized for ${project.purpose}, whereas buyer prioritizes ${buyer.purchasePurpose}.`);
      potential_objections.push("Project orientation may not fully maximize buyer's core investment or family objective.");
    }

    // 5. Buying Timeline (Weight: 15%)
    let timelineScore = 0.0;
    const timeline = (buyer.buyingTimeline || "").toLowerCase().trim();

    if (timeline.includes("immediately")) {
      timelineScore = project.status === "Completed" ? 15.0 : 10.0;
      if (project.status !== "Completed") {
        mismatched_criteria.push(`Construction Horizon: Buyer is ready immediately, but project status is ${project.status}.`);
        potential_objections.push("Handover timeline does not satisfy immediate move-in requirement.");
      } else {
        reasons.push("Ready Timeline: Immediate move-in ready aligns with buyer urgent timeline.");
      }
    } else if (timeline.includes("3 months") || timeline.includes("6 months")) {
      timelineScore = 14.0;
      reasons.push("Optimal Sales Window: Active purchasing window within 3–6 months.");
    } else if (timeline.includes("1 year")) {
      timelineScore = 11.0;
      reasons.push("Pipeline Lead: Good candidate for ongoing construction stage conversion.");
    } else {
      timelineScore = 6.0;
      missing_information.push("Buyer is currently exploring without firm procurement date.");
    }

    const totalRaw = budgetScore + locationScore + propertyTypeScore + purposeScore + timelineScore;
    const overallScore = Math.round(Math.min(100, Math.max(0, totalRaw)));

    // Confidence Level: High, Medium, Low based on missing fields
    let confidence_level: "High" | "Medium" | "Low" = "High";
    if (missing_information.length >= 2) {
      confidence_level = "Low";
    } else if (missing_information.length === 1) {
      confidence_level = "Medium";
    }

    // Matching Classification:
    // Excellent Match: 85–100
    // Good Match: 70–84
    // Moderate Match: 50–69
    // Low Match: Below 50
    let matching_classification: "Excellent Match" | "Good Match" | "Moderate Match" | "Low Match";
    if (overallScore >= 85) {
      matching_classification = "Excellent Match";
    } else if (overallScore >= 70) {
      matching_classification = "Good Match";
    } else if (overallScore >= 50) {
      matching_classification = "Moderate Match";
    } else {
      matching_classification = "Low Match";
    }

    // Recommended next action
    let recommended_next_action: string;
    if (overallScore >= 85) {
      recommended_next_action = "Prioritize for VIP showroom tour and send complete layout floor plans.";
    } else if (overallScore >= 70) {
      recommended_next_action = "Engage buyer to discuss specific unit layouts and verify bank loan eligibility.";
    } else if (overallScore >= 50) {
      recommended_next_action = `Clarify buyer preferences (specifically regarding ${mismatched_criteria[0] || "budget & timeline"}) before proposing project.`;
    } else {
      recommended_next_action = "Keep in general pipeline; project does not meet buyer's essential requirements.";
    }

    const fallbackExplanation = `${matching_classification} (${overallScore}% compatibility). ${reasons.slice(0, 2).join(" ")} ${mismatched_criteria.length > 0 ? "Consideration: " + mismatched_criteria[0] : ""}`.trim();

    const fallbackOpener = `Hi, I noticed ${project.name} in ${project.location} matches several of your search preferences for a ${project.propertyType}. Would you like me to share the digital brochure?`;

    return {
      buyer_id: buyer.id,
      project_id: project.id,
      overall_score: overallScore,
      confidence_level,
      matching_classification,
      matching_factors: {
        budget: Math.round(budgetScore),
        location: Math.round(locationScore),
        property_type: Math.round(propertyTypeScore),
        purchase_purpose: Math.round(purposeScore),
        buying_timeline: Math.round(timelineScore)
      },
      reasons,
      mismatched_criteria,
      potential_mismatches: mismatched_criteria,
      missing_information,
      potential_objections,
      recommended_next_action,
      ai_explanation: fallbackExplanation,
      suggested_conversation_opener: fallbackOpener
    };
  }

  /**
   * Evaluates all buyers against the project deterministically.
   * Sorts results descending by score.
   */
  static calculateMatches(buyers: SanitizedBuyerData[], project: ProjectData): BuyerMatchingOutput {
    const matches = buyers.map((b) => this.calculateMatch(b, project));

    // Sort descending by score
    matches.sort((a, b) => b.overall_score - a.overall_score);

    let excellentCount = 0;
    let goodCount = 0;
    let moderateCount = 0;
    let lowCount = 0;
    let scoreSum = 0;

    for (const m of matches) {
      scoreSum += m.overall_score;
      if (m.overall_score >= 85) excellentCount++;
      else if (m.overall_score >= 70) goodCount++;
      else if (m.overall_score >= 50) moderateCount++;
      else lowCount++;
    }

    const total = matches.length;
    const averageScore = total > 0 ? Math.round(scoreSum / total) : 0;

    return {
      matches,
      overview: {
        total_evaluated: total,
        excellent_matches: excellentCount,
        good_matches: goodCount,
        moderate_matches: moderateCount,
        low_matches: lowCount,
        average_score: averageScore
      }
    };
  }
}
