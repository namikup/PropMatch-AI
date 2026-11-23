import { AgentPreferencesData, RoutingDecisionData } from "../types/agent_preferences.types";

export interface CandidateAgentMatch {
  preferences: AgentPreferencesData;
  suitabilityScore: number;
  matchFactors: string[];
  penaltyFactors: string[];
}

export class LeadDistributionService {
  /**
   * Evaluates candidate agents and deterministically routes a platform-generated enquiry.
   */
  static routeEnquiry(
    rawEnquiry: Record<string, unknown>,
    candidatePreferences: AgentPreferencesData[],
    agentProfiles: Record<string, { fullName: string }> = {}
  ): RoutingDecisionData {
    const loc = String(rawEnquiry.preferredLocation || rawEnquiry.location || "").toLowerCase().trim();
    const state = String(rawEnquiry.preferredState || rawEnquiry.state || "").toLowerCase().trim();
    const type = String(rawEnquiry.propertyType || "").toLowerCase().trim();
    const source = String(rawEnquiry.sourceType || "").trim();
    const budgetMin = Number(rawEnquiry.budgetMin) || 400000;
    const budgetMax = Number(rawEnquiry.budgetMax) || 700000;

    const eligibleMatches: CandidateAgentMatch[] = [];

    for (const pref of candidatePreferences) {
      if (!pref.isAvailableForPlatformLeads) continue;
      if (pref.leadsReceivedThisMonth >= (pref.monthlyLeadQuota || 30)) continue;

      // Check source acceptance
      if (pref.acceptedEnquiryTypes && pref.acceptedEnquiryTypes.length > 0) {
        const accepts = pref.acceptedEnquiryTypes.some((t) => t.toLowerCase() === source.toLowerCase());
        if (!accepts) continue;
      }

      let score = 0;
      const factors: string[] = [];
      const penalties: string[] = [];

      // 1. Location match (40 pts max)
      let locationMatched = false;
      for (const targetLoc of pref.preferredLocations || []) {
        const l = targetLoc.toLowerCase().trim();
        if (loc.includes(l) || l.includes(loc)) {
          score += 40;
          locationMatched = true;
          factors.push(`Area match: ${targetLoc} matches enquiry area (${loc}).`);
          break;
        } else if (state.includes(l) || l.includes(state)) {
          score += 25;
          locationMatched = true;
          factors.push(`State match: ${targetLoc} covers state (${state}).`);
          break;
        }
      }

      if (!locationMatched) {
        penalties.push("Location outside agent focus territory.");
        continue; // Mandatory hard filter
      }

      // 2. Property type match (30 pts max)
      let typeMatched = false;
      for (const pt of pref.preferredPropertyTypes || []) {
        const t = pt.toLowerCase().trim();
        if (type.includes(t) || t.includes(type)) {
          score += 30;
          typeMatched = true;
          factors.push(`Property type category match: ${pt}.`);
          break;
        }
      }
      if (!typeMatched) {
        if (type.includes("condo") || type.includes("residence")) {
          score += 15;
          factors.push("High-rise category overlap.");
        } else {
          penalties.push(`Property type divergence (${type}).`);
        }
      }

      // 3. Price / Budget overlap (20 pts max)
      const pMin = pref.priceRangeMin ?? 350000;
      const pMax = pref.priceRangeMax ?? 1500000;
      const overlapMin = Math.max(budgetMin, pMin);
      const overlapMax = Math.min(budgetMax, pMax);

      if (overlapMin <= overlapMax) {
        score += 20;
        factors.push(`Budget overlap: RM${budgetMin.toLocaleString()}–${budgetMax.toLocaleString()} overlaps focus.`);
      } else {
        score += 5;
        penalties.push("Budget outside preferred price bracket.");
      }

      // 4. Fair rotation bonus (10 pts max)
      const quota = pref.monthlyLeadQuota || 30;
      const loadRatio = (pref.leadsReceivedThisMonth || 0) / quota;
      const rotationBonus = Math.max(0, Math.min(10, (1 - loadRatio) * 10));
      score += rotationBonus;
      factors.push(`Capacity rotation index: ${rotationBonus.toFixed(1)} pts.`);

      const clampedScore = Math.min(100, Math.max(0, score));
      if (clampedScore >= 50) {
        eligibleMatches.push({
          preferences: pref,
          suitabilityScore: clampedScore,
          matchFactors: factors,
          penaltyFactors: penalties
        });
      }
    }

    if (eligibleMatches.length === 0) {
      return {
        isAssigned: false,
        routingStatus: "Unassigned Queue",
        rationale: `No eligible agent found matching location (${loc}, ${state}) and property type (${type}).`,
        factors: ["Enquiry retained in unassigned queue awaiting manual assignment or expanded agent criteria."],
        routingTimestamp: new Date().toISOString()
      };
    }

    // Sort by suitability score descending
    // Tie-breaker: least recently assigned agent
    eligibleMatches.sort((a, b) => {
      if (b.suitabilityScore !== a.suitabilityScore) {
        return b.suitabilityScore - a.suitabilityScore;
      }
      const timeA = a.preferences.lastLeadAssignedAt ? new Date(a.preferences.lastLeadAssignedAt).getTime() : 0;
      const timeB = b.preferences.lastLeadAssignedAt ? new Date(b.preferences.lastLeadAssignedAt).getTime() : 0;
      return timeA - timeB;
    });

    const chosen = eligibleMatches[0];
    const agentName = agentProfiles[chosen.preferences.agentId]?.fullName || chosen.preferences.agentId;

    return {
      isAssigned: true,
      assignedAgentId: chosen.preferences.agentId,
      assignedAgentName: agentName,
      suitabilityScore: chosen.suitabilityScore,
      routingStatus: "Assigned",
      rationale: `Assigned to ${agentName} with suitability score ${chosen.suitabilityScore.toFixed(1)}% based on location specialization and property compatibility.`,
      factors: chosen.matchFactors,
      routingTimestamp: new Date().toISOString()
    };
  }
}
