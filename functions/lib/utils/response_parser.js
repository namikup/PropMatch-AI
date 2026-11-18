"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ResponseParser = void 0;
class ResponseParser {
    /**
     * Strips markdown fences, quotes, and whitespace from raw LLM output and parses JSON.
     */
    static parseCleanJson(rawText) {
        if (!rawText || typeof rawText !== "string") {
            throw new Error("Empty or non-string response received from model.");
        }
        let cleaned = rawText.trim();
        // Strip markdown code fences ```json ... ``` or ``` ... ```
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.replace(/^```[a-zA-Z]*\n?/, "");
            cleaned = cleaned.replace(/\n?```$/, "");
            cleaned = cleaned.trim();
        }
        // Sometimes models output leading text before a JSON block; locate the first '{' or '['
        const firstBrace = cleaned.indexOf("{");
        const firstBracket = cleaned.indexOf("[");
        let startIndex = -1;
        if (firstBrace !== -1 && firstBracket !== -1) {
            startIndex = Math.min(firstBrace, firstBracket);
        }
        else if (firstBrace !== -1) {
            startIndex = firstBrace;
        }
        else if (firstBracket !== -1) {
            startIndex = firstBracket;
        }
        if (startIndex > 0) {
            cleaned = cleaned.substring(startIndex);
        }
        // Locate the matching end brace or bracket
        const lastBrace = cleaned.lastIndexOf("}");
        const lastBracket = cleaned.lastIndexOf("]");
        const endIndex = Math.max(lastBrace, lastBracket);
        if (endIndex !== -1 && endIndex < cleaned.length - 1) {
            cleaned = cleaned.substring(0, endIndex + 1);
        }
        try {
            return JSON.parse(cleaned);
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            throw new Error(`Failed to parse model output into JSON: ${msg}. Cleaned payload: ${cleaned.substring(0, 300)}`);
        }
    }
    /**
     * Validates and normalizes PropertyAnalysisOutput
     */
    static validatePropertyAnalysis(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid PropertyAnalysisOutput: Expected JSON object.");
        }
        return {
            project_summary: typeof data.project_summary === "string" ? data.project_summary : "Summary unavailable",
            key_selling_points: Array.isArray(data.key_selling_points) ? data.key_selling_points.map(String) : [],
            potential_buyer_segments: Array.isArray(data.potential_buyer_segments) ? data.potential_buyer_segments.map(String) : [],
            competitive_advantages: Array.isArray(data.competitive_advantages) ? data.competitive_advantages.map(String) : [],
            potential_objections: Array.isArray(data.potential_objections) ? data.potential_objections.map(String) : [],
            marketing_angles: Array.isArray(data.marketing_angles) ? data.marketing_angles.map(String) : [],
            recommended_price_positioning: typeof data.recommended_price_positioning === "string" ? data.recommended_price_positioning : "Market standard",
            analysis_confidence: ["High", "Medium", "Low"].includes(data.analysis_confidence) ? data.analysis_confidence : "Medium"
        };
    }
    /**
     * Validates and normalizes AudienceDiscoveryOutput
     */
    static validateAudienceDiscovery(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid AudienceDiscoveryOutput: Expected JSON object.");
        }
        const segmentsRaw = Array.isArray(data.audience_segments) ? data.audience_segments : [];
        const audience_segments = segmentsRaw.map((s) => ({
            segment_name: typeof s.segment_name === "string" ? s.segment_name : "Target Audience",
            description: typeof s.description === "string" ? s.description : "",
            estimated_relevance: typeof s.estimated_relevance === "number" ? Math.min(100, Math.max(0, s.estimated_relevance)) : 70,
            buying_motivations: Array.isArray(s.buying_motivations) ? s.buying_motivations.map(String) : [],
            potential_objections: Array.isArray(s.potential_objections) ? s.potential_objections.map(String) : [],
            recommended_marketing_channels: Array.isArray(s.recommended_marketing_channels) ? s.recommended_marketing_channels.map(String) : [],
            recommended_content_angles: Array.isArray(s.recommended_content_angles) ? s.recommended_content_angles.map(String) : [],
            evidence: Array.isArray(s.evidence) ? s.evidence.map(String) : [],
            assumptions: Array.isArray(s.assumptions) ? s.assumptions.map(String) : []
        }));
        return { audience_segments };
    }
    /**
     * Validates and normalizes BuyerMatchingOutput
     */
    static validateBuyerMatching(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid BuyerMatchingOutput: Expected JSON object.");
        }
        const matchesRaw = Array.isArray(data.matches) ? data.matches : [];
        const matches = matchesRaw.map((m) => ({
            buyer_id: typeof m.buyer_id === "string" ? m.buyer_id : "",
            project_id: typeof m.project_id === "string" ? m.project_id : "",
            overall_score: typeof m.overall_score === "number" ? Math.min(100, Math.max(0, m.overall_score)) : 50,
            matching_factors: {
                budget: typeof m.matching_factors?.budget === "number" ? m.matching_factors.budget : 0,
                location: typeof m.matching_factors?.location === "number" ? m.matching_factors.location : 0,
                property_type: typeof m.matching_factors?.property_type === "number" ? m.matching_factors.property_type : 0,
                purchase_purpose: typeof m.matching_factors?.purchase_purpose === "number" ? m.matching_factors.purchase_purpose : 0,
                buying_timeline: typeof m.matching_factors?.buying_timeline === "number" ? m.matching_factors.buying_timeline : 0
            },
            reasons: Array.isArray(m.reasons) ? m.reasons.map(String) : [],
            potential_mismatches: Array.isArray(m.potential_mismatches) ? m.potential_mismatches.map(String) : [],
            missing_information: Array.isArray(m.missing_information) ? m.missing_information.map(String) : [],
            recommended_next_action: typeof m.recommended_next_action === "string" ? m.recommended_next_action : "Follow up"
        }));
        return { matches };
    }
    /**
     * Validates and normalizes MarketingContentOutput
     */
    static validateMarketingContent(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid MarketingContentOutput: Expected JSON object.");
        }
        return {
            headline: typeof data.headline === "string" ? data.headline : "Exclusive Property Launch",
            primary_text: typeof data.primary_text === "string" ? data.primary_text : "",
            call_to_action: typeof data.call_to_action === "string" ? data.call_to_action : "Register Now",
            channels: Array.isArray(data.channels)
                ? data.channels.map((ch) => ({
                    platform: typeof ch.platform === "string" ? ch.platform : "Social Media",
                    content: typeof ch.content === "string" ? ch.content : "",
                    hashtags: Array.isArray(ch.hashtags) ? ch.hashtags.map(String) : []
                }))
                : [],
            content_calendar_suggestion: typeof data.content_calendar_suggestion === "string" ? data.content_calendar_suggestion : "",
            language: ["en", "bm", "zh"].includes(data.language) ? data.language : "en"
        };
    }
}
exports.ResponseParser = ResponseParser;
//# sourceMappingURL=response_parser.js.map