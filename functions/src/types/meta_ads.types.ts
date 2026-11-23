/**
 * Meta Ads Intelligence Types for PropMatch AI
 * Supports Meta Graph API v19.0+, Marketing API, Ads Insights API, and Lead Ads Webhooks.
 */

export interface MetaConnectionConfig {
  ownerId: string;
  facebookPageId: string;
  facebookPageName: string;
  adAccountId: string; // e.g. act_492019482910
  adAccountName: string;
  currency: string; // MYR
  isConnected: boolean;
  connectionStatus: 'Connected' | 'Disconnected' | 'Reauthorization Required' | 'Error';
  grantedPermissions: string[];
  missingPermissions: string[];
  lastSyncAt?: string;
  lastSyncError?: string;
  tokenExpiresAt?: string;
  isTokenExpired: boolean;
  requiresAppReview: boolean;
  updatedAt: string;
}

export interface MetaSecureCredentials {
  ownerId: string;
  accessToken: string; // Stored only in private backend collection
  tokenType: 'user' | 'page' | 'system';
  scope: string[];
  expiresAt: number; // Unix timestamp ms
  pageAccessTokens?: Record<string, string>; // pageId -> token
  updatedAt: string;
}

export interface MetaBuyerQualityMetrics {
  totalLeads: number;
  validContactableLeads: number;
  qualifiedProspects: number;
  matchedListingCount: number;
  viewingAppointments: number;
  convertedBuyers: number;
  costPerQualifiedBuyer: number | null;
  costPerViewingAppointment: number | null;
  qualificationRate: number; // e.g. 45.5%
}

export interface MetaAdSummary {
  id: string;
  adSetId: string;
  name: string;
  status: 'ACTIVE' | 'PAUSED' | 'ARCHIVED' | 'DISAPPROVED';
  creativeTitle: string;
  creativeBody: string;
  previewUrl?: string;
  spend: number;
  impressions: number;
  clicks: number;
  leads: number;
  costPerLead: number;
}

export interface MetaAdSetSummary {
  id: string;
  name: string;
  status: 'ACTIVE' | 'PAUSED' | 'ARCHIVED';
  targetingSummary?: string;
  spend: number;
  leads: number;
  costPerLead: number;
}

export interface MetaCampaignSummary {
  id: string;
  ownerId: string;
  campaignId: string;
  campaignName: string;
  status: 'ACTIVE' | 'PAUSED' | 'ARCHIVED' | 'COMPLETED';
  objective: string;
  dailyBudget?: number;
  lifetimeBudget?: number;
  spend: number;
  impressions: number;
  reach: number;
  clicks: number;
  ctr: number; // %
  cpc: number; // MYR
  cpm: number; // MYR
  leads: number;
  costPerLead: number; // MYR
  dateStart: string;
  dateStop: string;
  adSets?: MetaAdSetSummary[];
  ads?: MetaAdSummary[];
  qualityMetrics: MetaBuyerQualityMetrics;
  updatedAt: string;
}

export interface MetaLeadFieldData {
  name: string;
  values: string[];
}

export interface MetaLeadPayload {
  leadgenId: string;
  formId: string;
  pageId: string;
  adId?: string;
  adName?: string;
  adSetId?: string;
  campaignId?: string;
  campaignName?: string;
  createdTime: number; // Unix timestamp
  fieldData: MetaLeadFieldData[];
  isOrganic?: boolean;
}

export interface MetaAICampaignInsight {
  generatedAt: string;
  dataPeriod: string;
  sampleSizeLeads: number;
  statisticalConfidence: 'High' | 'Moderate' | 'Low' | 'Insufficient Data';
  executiveSummary: string;
  topPerformingCampaigns: string[];
  inefficientCampaigns: string[];
  buyerQualityFindings: string[];
  creativeAndAudienceRecommendations: string[];
  budgetAdvisory: string; // Strictly advisory suggestions; never modifies live budgets
}
