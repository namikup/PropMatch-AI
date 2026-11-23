export interface AgentPreferencesData {
  agentId: string;
  isAvailableForPlatformLeads: boolean;
  preferredLocations: string[];
  preferredPropertyTypes: string[];
  priceRangeMin: number;
  priceRangeMax: number;
  specializations: string[];
  acceptedEnquiryTypes: string[];
  monthlyLeadQuota: number;
  leadsReceivedThisMonth: number;
  lastLeadAssignedAt?: string;
  updatedAt?: string;
}

export interface RoutingDecisionData {
  isAssigned: boolean;
  assignedAgentId?: string;
  assignedAgentName?: string;
  suitabilityScore?: number;
  routingStatus: "Assigned" | "Unassigned Queue";
  rationale: string;
  factors: string[];
  routingTimestamp: string;
}
