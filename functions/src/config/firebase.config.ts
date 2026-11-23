import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();

export const collections = {
  users: db.collection("users"),
  projects: db.collection("projects"),
  buyers: db.collection("buyers"),
  leads: db.collection("leads"),
  followups: db.collection("followups"),
  campaigns: db.collection("campaigns"),
  consentRecords: db.collection("consent_records"),
  propertyAnalyses: db.collection("property_analyses"),
  audienceSegments: db.collection("audience_segments"),
  matches: db.collection("matches"),
  aiUsageLogs: db.collection("ai_usage_logs"),
  agentQuotas: db.collection("agent_quotas"),
  prospects: db.collection("prospects"),
  dataSources: db.collection("data_sources"),
  prospectSourceRecords: db.collection("prospect_source_records"),
  prospectConsents: db.collection("prospect_consents"),
  prospectActivities: db.collection("prospect_activities"),
  prospectImportJobs: db.collection("prospect_import_jobs"),
  prospectMatches: db.collection("prospect_matches"),
  prospectAuditLogs: db.collection("prospect_audit_logs"),
  incomingEnquiries: db.collection("incoming_enquiries"),
  agentPreferences: db.collection("agent_preferences")
};
