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
  aiUsageLogs: db.collection("ai_usage_logs"),
  agentQuotas: db.collection("agent_quotas")
};
