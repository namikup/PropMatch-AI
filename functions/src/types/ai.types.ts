export type AIFeatureType =
  | "property_analysis"
  | "audience_discovery"
  | "buyer_matching"
  | "marketing_content";

export type AIRequestStatus = "pending" | "success" | "failed" | "rate_limited";

export interface AIUsageLog {
  id: string;
  ownerId: string;
  feature: AIFeatureType;
  model: string;
  promptTokens?: number;
  candidateTokens?: number;
  totalTokens?: number;
  tokenSource?: "provider_metadata" | "heuristic_estimation";
  isEstimated?: boolean;
  estimatedCostUsd?: number;
  latencyMs: number;
  status: AIRequestStatus;
  errorMessage?: string;
  timestamp: string;
  projectId?: string;
  idempotencyKey?: string;
}

export interface AgentQuotaStatus {
  ownerId: string;
  currentMonthRequests: number;
  monthlyQuota: number;
  remainingRequests: number;
  isAllowed: boolean;
  billingCycle?: string;
  reservedRequests?: number;
  successRequests?: number;
  failureRequests?: number;
}

// Module A Structured Output Schema & Sub-Components (Phase 3.2)
export interface SellingPointItem {
  title: string;
  explanation: string;
  supporting_info: string;
  buyer_benefit: string;
  confidence: "High" | "Medium" | "Low";
}

export interface BuyerPersonaItem {
  segment_name: string;
  description: string;
  estimated_relevance: number; // 0-100
  buying_motivations: string[];
  appealing_features: string[];
  potential_objections: string[];
  recommended_marketing_angle: string;
}

export interface CompetitiveAdvantageItem {
  advantage: string;
  explanation: string;
  supporting_evidence: string;
  evidence_status: string; // e.g. "Agent-provided feature", "Verified project characteristic", "Competitor comparison unavailable"
}

export interface ObjectionItem {
  objection: string;
  category: "price" | "location" | "financing" | "size" | "facilities" | "timing" | "general";
  response_strategy: string;
}

export interface MarketingStrategyPlan {
  recommended_angles: string[];
  suitable_audience_segments: string[];
  suggested_channels: string[];
  advertisement_headlines: string[];
  social_media_ideas: string[];
  recommended_calls_to_action: string[];
}

export interface AnalysisSummaryData {
  overall_positioning: string;
  strongest_selling_point: string;
  most_relevant_segment: string;
  main_potential_objection: string;
  recommended_next_action: string;
  analysis_limitations: string[];
}

export interface PropertyAnalysisOutput {
  project_summary: string;
  key_selling_points: string[];
  potential_buyer_segments: string[];
  competitive_advantages: string[];
  potential_objections: string[];
  marketing_angles: string[];
  recommended_price_positioning: string;
  analysis_confidence: "High" | "Medium" | "Low";

  // Phase 3.2 Rich Structured Objects
  property_overview?: {
    name: string;
    location: string;
    state: string;
    property_type: string;
    price_range: string;
    bedrooms: number;
    bathrooms: number;
    built_up_area: number;
    facilities: string[];
    description: string;
    professional_overview: string;
  };
  selling_points?: SellingPointItem[];
  buyer_personas?: BuyerPersonaItem[];
  structured_competitive_advantages?: CompetitiveAdvantageItem[];
  structured_objections?: ObjectionItem[];
  marketing_strategy?: MarketingStrategyPlan;
  analysis_summary?: AnalysisSummaryData;
  missing_information?: string[];
  data_provenance?: string;
}

// Module B Structured Output Schema (Phase 3.3A)
export interface AudienceSegmentItem {
  id?: string;
  segment_name: string;
  description: string;
  estimated_relevance: number; // 0-100 (Demographic and feature fit score; not conversion probability)
  buying_motivations: string[];
  appealing_features: string[];
  potential_objections: string[];
  recommended_marketing_messages: string[];
  recommended_marketing_channels: string[];
  recommended_content_formats: string[];
  recommended_content_angles: string[];
  evidence: string[];
  assumptions: string[];
  confidence_level: "High" | "Medium" | "Low";
  market_demand_disclaimer: string;
}

export interface AudienceDiscoveryOutput {
  audience_segments: AudienceSegmentItem[];
  overview?: {
    total_segments: number;
    primary_target_group: string;
    strategic_summary: string;
    market_demand_disclaimer: string;
  };
}

// Module D Structured Output Schema (Phase 3.3B)
export interface BuyerMatchingItem {
  buyer_id: string;
  buyer_name?: string;
  project_id: string;
  overall_score: number; // 0-100 (locked deterministic compatibility score)
  confidence_level: "High" | "Medium" | "Low";
  matching_classification: "Excellent Match" | "Good Match" | "Moderate Match" | "Low Match";
  matching_factors: {
    budget: number;
    location: number;
    property_type: number;
    purchase_purpose: number;
    buying_timeline: number;
  };
  reasons: string[];
  mismatched_criteria: string[];
  potential_mismatches: string[];
  missing_information: string[];
  potential_objections: string[];
  recommended_next_action: string;
  ai_explanation?: string;
  suggested_conversation_opener?: string;
  is_cached?: boolean;
  source_version?: string;
}

export interface BuyerMatchingOutput {
  matches: BuyerMatchingItem[];
  overview: {
    total_evaluated: number;
    excellent_matches: number;
    good_matches: number;
    moderate_matches: number;
    low_matches: number;
    average_score: number;
  };
}

// Module E Structured Output Schema
export interface MarketingContentOutput {
  headline: string;
  primary_text: string;
  call_to_action: string;
  channels: {
    platform: string;
    content: string;
    hashtags?: string[];
  }[];
  content_calendar_suggestion: string;
  language: "en" | "bm" | "zh";
}
