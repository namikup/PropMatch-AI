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
  latencyMs: number;
  status: AIRequestStatus;
  errorMessage?: string;
  timestamp: string;
  projectId?: string;
}

export interface AgentQuotaStatus {
  ownerId: string;
  currentMonthRequests: number;
  monthlyQuota: number;
  remainingRequests: number;
  isAllowed: boolean;
}

// Module A Structured Output Schema
export interface PropertyAnalysisOutput {
  project_summary: string;
  key_selling_points: string[];
  potential_buyer_segments: string[];
  competitive_advantages: string[];
  potential_objections: string[];
  marketing_angles: string[];
  recommended_price_positioning: string;
  analysis_confidence: "High" | "Medium" | "Low";
}

// Module B Structured Output Schema
export interface AudienceSegmentItem {
  segment_name: string;
  description: string;
  estimated_relevance: number; // 0-100
  buying_motivations: string[];
  potential_objections: string[];
  recommended_marketing_channels: string[];
  recommended_content_angles: string[];
  evidence: string[];
  assumptions: string[];
}

export interface AudienceDiscoveryOutput {
  audience_segments: AudienceSegmentItem[];
}

// Module D Structured Output Schema
export interface BuyerMatchingItem {
  buyer_id: string;
  project_id: string;
  overall_score: number; // 0-100
  matching_factors: {
    budget: number;
    location: number;
    property_type: number;
    purchase_purpose: number;
    buying_timeline: number;
  };
  reasons: string[];
  potential_mismatches: string[];
  missing_information: string[];
  recommended_next_action: string;
}

export interface BuyerMatchingOutput {
  matches: BuyerMatchingItem[];
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
