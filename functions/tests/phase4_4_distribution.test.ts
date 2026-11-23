import { LeadDistributionService } from "../src/services/lead_distribution_service";
import { AgentPreferencesData } from "../src/types/agent_preferences.types";

describe("Phase 4.4: Platform Lead Distribution & Transparent Routing Engine (Backend)", () => {
  const agentAPrefs: AgentPreferencesData = {
    agentId: "agent-alex-penang",
    isAvailableForPlatformLeads: true,
    preferredLocations: ["Batu Kawan", "George Town", "Bayan Lepas"],
    preferredPropertyTypes: ["Condominium", "Serviced Residence"],
    priceRangeMin: 350000,
    priceRangeMax: 800000,
    specializations: ["First-time Homebuyer", "High-Rise Residential"],
    acceptedEnquiryTypes: ["Property Portal", "Developer", "Partner Agency"],
    monthlyLeadQuota: 30,
    leadsReceivedThisMonth: 10,
    lastLeadAssignedAt: new Date(Date.now() - 3600000 * 48).toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const agentBPrefs: AgentPreferencesData = {
    agentId: "agent-brenda-kl",
    isAvailableForPlatformLeads: true,
    preferredLocations: ["Mont Kiara", "KLCC", "Bangsar"],
    preferredPropertyTypes: ["Condominium", "Luxury Residence"],
    priceRangeMin: 1200000,
    priceRangeMax: 4000000,
    specializations: ["Luxury Investment", "Expat / MM2H"],
    acceptedEnquiryTypes: ["Property Portal", "Developer"],
    monthlyLeadQuota: 50,
    leadsReceivedThisMonth: 5,
    lastLeadAssignedAt: new Date(Date.now() - 3600000 * 24).toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const agentCPrefs: AgentPreferencesData = {
    agentId: "agent-calvin-penang",
    isAvailableForPlatformLeads: true,
    preferredLocations: ["Batu Kawan", "Penang"],
    preferredPropertyTypes: ["Condominium", "Terrace House"],
    priceRangeMin: 400000,
    priceRangeMax: 700000,
    specializations: ["First-time Homebuyer"],
    acceptedEnquiryTypes: ["Property Portal", "Developer", "Partner Agency"],
    monthlyLeadQuota: 20,
    leadsReceivedThisMonth: 12,
    lastLeadAssignedAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    updatedAt: new Date().toISOString(),
  };

  test("1. Location, property type, and budget matching routes deterministically to eligible agent", () => {
    const rawEnquiry = {
      preferredLocation: "Batu Kawan",
      preferredState: "Penang",
      propertyType: "Condominium",
      budgetMin: 450000,
      budgetMax: 550000,
      sourceType: "Property Portal",
    };

    const decision = LeadDistributionService.routeEnquiry(
      rawEnquiry,
      [agentAPrefs, agentBPrefs],
      { "agent-alex-penang": { fullName: "Alex Tan" } }
    );

    expect(decision.isAssigned).toBe(true);
    expect(decision.assignedAgentId).toBe("agent-alex-penang");
    expect(decision.assignedAgentName).toBe("Alex Tan");
    expect(decision.routingStatus).toBe("Assigned");
    expect(decision.suitabilityScore).toBeGreaterThanOrEqual(80);
    expect(decision.factors.length).toBeGreaterThan(0);
  });

  test("2. Geographic territory divergence excludes candidate agents outside target area", () => {
    const klEnquiry = {
      preferredLocation: "Mont Kiara",
      preferredState: "Kuala Lumpur",
      propertyType: "Condominium",
      budgetMin: 1500000,
      budgetMax: 2000000,
      sourceType: "Property Portal",
    };

    const decision = LeadDistributionService.routeEnquiry(
      klEnquiry,
      [agentAPrefs, agentBPrefs],
      { "agent-brenda-kl": { fullName: "Brenda Lim" } }
    );

    expect(decision.isAssigned).toBe(true);
    expect(decision.assignedAgentId).toBe("agent-brenda-kl");
    expect(decision.assignedAgentName).toBe("Brenda Lim");
  });

  test("3. Unassigned Queue Holding: Zero matching candidates routes enquiry to Unassigned Queue without PII exposure", () => {
    const isolatedEnquiry = {
      preferredLocation: "Miri",
      preferredState: "Sarawak",
      propertyType: "Industrial Land",
      budgetMin: 100000,
      budgetMax: 200000,
      sourceType: "Direct Website",
    };

    const decision = LeadDistributionService.routeEnquiry(
      isolatedEnquiry,
      [agentAPrefs, agentBPrefs, agentCPrefs]
    );

    expect(decision.isAssigned).toBe(false);
    expect(decision.assignedAgentId).toBeUndefined();
    expect(decision.routingStatus).toBe("Unassigned Queue");
    expect(decision.rationale).toContain("Unassigned Queue");
  });

  test("4. Agent opt-out (isAvailableForPlatformLeads: false) excludes agent from distribution", () => {
    const optedOutPrefs: AgentPreferencesData = {
      ...agentAPrefs,
      isAvailableForPlatformLeads: false,
    };

    const enquiry = {
      preferredLocation: "Batu Kawan",
      preferredState: "Penang",
      propertyType: "Condominium",
      budgetMin: 450000,
      budgetMax: 550000,
      sourceType: "Property Portal",
    };

    const decision = LeadDistributionService.routeEnquiry(
      enquiry,
      [optedOutPrefs]
    );

    expect(decision.isAssigned).toBe(false);
    expect(decision.routingStatus).toBe("Unassigned Queue");
  });

  test("5. Monthly quota limit exhaustion excludes agent from assignment", () => {
    const exhaustedPrefs: AgentPreferencesData = {
      ...agentAPrefs,
      monthlyLeadQuota: 20,
      leadsReceivedThisMonth: 20, // Reached limit
    };

    const enquiry = {
      preferredLocation: "Batu Kawan",
      preferredState: "Penang",
      propertyType: "Condominium",
      budgetMin: 450000,
      budgetMax: 550000,
      sourceType: "Property Portal",
    };

    // Agent C is eligible backup
    const decision = LeadDistributionService.routeEnquiry(
      enquiry,
      [exhaustedPrefs, agentCPrefs],
      { "agent-calvin-penang": { fullName: "Calvin Ooi" } }
    );

    expect(decision.isAssigned).toBe(true);
    expect(decision.assignedAgentId).toBe("agent-calvin-penang");
  });

  test("6. Fair rotation tie-breaker prioritizes agent with older assignment timestamp", () => {
    const tie1: AgentPreferencesData = {
      ...agentAPrefs,
      agentId: "tie-agent-1",
      leadsReceivedThisMonth: 10,
      lastLeadAssignedAt: new Date(Date.now() - 3600000 * 72).toISOString(), // 3 days ago
    };

    const tie2: AgentPreferencesData = {
      ...agentAPrefs,
      agentId: "tie-agent-2",
      leadsReceivedThisMonth: 10,
      lastLeadAssignedAt: new Date(Date.now() - 3600000 * 6).toISOString(), // 6 hours ago
    };

    const enquiry = {
      preferredLocation: "Batu Kawan",
      preferredState: "Penang",
      propertyType: "Condominium",
      budgetMin: 450000,
      budgetMax: 550000,
      sourceType: "Property Portal",
    };

    const decision = LeadDistributionService.routeEnquiry(
      enquiry,
      [tie1, tie2]
    );

    expect(decision.isAssigned).toBe(true);
    expect(decision.assignedAgentId).toBe("tie-agent-1");
  });
});
