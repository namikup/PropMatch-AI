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
     * Validates and normalizes PropertyAnalysisOutput (Phase 3.2 Rich Schema)
     */
    static validatePropertyAnalysis(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid PropertyAnalysisOutput: Expected JSON object.");
        }
        // 1. Normalize Selling Points
        const rawSellingPoints = Array.isArray(data.selling_points)
            ? data.selling_points
            : Array.isArray(data.key_selling_points)
                ? data.key_selling_points
                : [];
        const selling_points = rawSellingPoints.map((item) => {
            if (typeof item === "string") {
                return {
                    title: item,
                    explanation: item,
                    supporting_info: "Agent-provided project specifications",
                    buyer_benefit: "High alignment with buyer expectations",
                    confidence: "High"
                };
            }
            return {
                title: typeof item?.title === "string" ? item.title : "Key Selling Point",
                explanation: typeof item?.explanation === "string" ? item.explanation : "",
                supporting_info: typeof item?.supporting_info === "string" ? item.supporting_info : "Agent-supplied property data",
                buyer_benefit: typeof item?.buyer_benefit === "string" ? item.buyer_benefit : "",
                confidence: ["High", "Medium", "Low"].includes(item?.confidence) ? item.confidence : "Medium"
            };
        });
        const key_selling_points = selling_points.map((sp) => sp.title);
        // 2. Normalize Buyer Personas
        const rawPersonas = Array.isArray(data.buyer_personas)
            ? data.buyer_personas
            : Array.isArray(data.potential_buyer_segments)
                ? data.potential_buyer_segments
                : [];
        const buyer_personas = rawPersonas.map((p) => {
            if (typeof p === "string") {
                return {
                    segment_name: p,
                    description: "Target demographic identified through property positioning analysis.",
                    estimated_relevance: 80,
                    buying_motivations: ["Quality lifestyle", "Value for money"],
                    appealing_features: ["Strategic location", "Modern layout"],
                    potential_objections: ["Budget evaluation"],
                    recommended_marketing_angle: "Focus on primary lifestyle benefits."
                };
            }
            return {
                segment_name: typeof p?.segment_name === "string" ? p.segment_name : "Prospective Buyer Persona",
                description: typeof p?.description === "string" ? p.description : "",
                estimated_relevance: typeof p?.estimated_relevance === "number" ? Math.min(100, Math.max(0, p.estimated_relevance)) : 75,
                buying_motivations: Array.isArray(p?.buying_motivations) ? p.buying_motivations.map(String) : [],
                appealing_features: Array.isArray(p?.appealing_features) ? p.appealing_features.map(String) : [],
                potential_objections: Array.isArray(p?.potential_objections) ? p.potential_objections.map(String) : [],
                recommended_marketing_angle: typeof p?.recommended_marketing_angle === "string" ? p.recommended_marketing_angle : ""
            };
        });
        const potential_buyer_segments = buyer_personas.map((bp) => bp.segment_name);
        // 3. Normalize Competitive Advantages
        const rawAdvantages = Array.isArray(data.structured_competitive_advantages)
            ? data.structured_competitive_advantages
            : Array.isArray(data.competitive_advantages)
                ? data.competitive_advantages
                : [];
        const structured_competitive_advantages = rawAdvantages.map((a) => {
            if (typeof a === "string") {
                return {
                    advantage: a,
                    explanation: a,
                    supporting_evidence: "Agent-provided project specifications",
                    evidence_status: "Verified project characteristic"
                };
            }
            return {
                advantage: typeof a?.advantage === "string" ? a.advantage : "Distinctive Feature",
                explanation: typeof a?.explanation === "string" ? a.explanation : "",
                supporting_evidence: typeof a?.supporting_evidence === "string" ? a.supporting_evidence : "Agent-provided information",
                evidence_status: typeof a?.evidence_status === "string" ? a.evidence_status : "Verified project characteristic"
            };
        });
        const competitive_advantages = structured_competitive_advantages.map((ca) => ca.advantage);
        // 4. Normalize Objections
        const rawObjections = Array.isArray(data.structured_objections)
            ? data.structured_objections
            : Array.isArray(data.potential_objections)
                ? data.potential_objections
                : [];
        const structured_objections = rawObjections.map((o) => {
            if (typeof o === "string") {
                return {
                    objection: o,
                    category: "general",
                    response_strategy: "Present project advantages and market value proposition."
                };
            }
            const cat = ["price", "location", "financing", "size", "facilities", "timing", "general"].includes(o?.category)
                ? o.category
                : "general";
            return {
                objection: typeof o?.objection === "string" ? o.objection : "Buyer Hesitation",
                category: cat,
                response_strategy: typeof o?.response_strategy === "string" ? o.response_strategy : "Consult agent on tailored financing or viewing."
            };
        });
        const potential_objections = structured_objections.map((so) => so.objection);
        // 5. Normalize Marketing Strategy
        const mkt = data.marketing_strategy || {};
        const marketing_strategy = {
            recommended_angles: Array.isArray(mkt.recommended_angles)
                ? mkt.recommended_angles.map(String)
                : Array.isArray(data.marketing_angles)
                    ? data.marketing_angles.map(String)
                    : [],
            suitable_audience_segments: Array.isArray(mkt.suitable_audience_segments)
                ? mkt.suitable_audience_segments.map(String)
                : potential_buyer_segments,
            suggested_channels: Array.isArray(mkt.suggested_channels)
                ? mkt.suggested_channels.map(String)
                : ["Facebook Lead Ads", "Instagram Reels", "Private Showroom Preview"],
            advertisement_headlines: Array.isArray(mkt.advertisement_headlines)
                ? mkt.advertisement_headlines.map(String)
                : [],
            social_media_ideas: Array.isArray(mkt.social_media_ideas)
                ? mkt.social_media_ideas.map(String)
                : [],
            recommended_calls_to_action: Array.isArray(mkt.recommended_calls_to_action)
                ? mkt.recommended_calls_to_action.map(String)
                : ["Schedule Showroom Tour", "Download Floor Plan"]
        };
        const marketing_angles = marketing_strategy.recommended_angles.length > 0
            ? marketing_strategy.recommended_angles
            : (Array.isArray(data.marketing_angles) ? data.marketing_angles.map(String) : []);
        // 6. Normalize Summary & Limitations
        const sum = data.analysis_summary || {};
        const analysis_summary = {
            overall_positioning: typeof sum.overall_positioning === "string" ? sum.overall_positioning : (typeof data.recommended_price_positioning === "string" ? data.recommended_price_positioning : "Strategic positioning within regional development corridor."),
            strongest_selling_point: typeof sum.strongest_selling_point === "string" ? sum.strongest_selling_point : (key_selling_points[0] || "Strategic location and layout."),
            most_relevant_segment: typeof sum.most_relevant_segment === "string" ? sum.most_relevant_segment : (potential_buyer_segments[0] || "First-time homebuyers and professionals."),
            main_potential_objection: typeof sum.main_potential_objection === "string" ? sum.main_potential_objection : (potential_objections[0] || "Pricing evaluation vs surrounding developments."),
            recommended_next_action: typeof sum.recommended_next_action === "string" ? sum.recommended_next_action : "Initiate targeted digital campaign and showroom open house previews.",
            analysis_limitations: Array.isArray(sum.analysis_limitations)
                ? sum.analysis_limitations.map(String)
                : [
                    "Analysis synthesized strictly from agent-supplied project parameters.",
                    "Competitor market comparisons unavailable unless externally verified.",
                    "Buyer personas represent marketing hypotheses, not verified individual leads."
                ]
        };
        // 7. Property Overview
        const pov = data.property_overview || {};
        const property_overview = {
            name: typeof pov.name === "string" ? pov.name : "",
            location: typeof pov.location === "string" ? pov.location : "",
            state: typeof pov.state === "string" ? pov.state : "",
            property_type: typeof pov.property_type === "string" ? pov.property_type : "",
            price_range: typeof pov.price_range === "string" ? pov.price_range : "",
            bedrooms: typeof pov.bedrooms === "number" ? pov.bedrooms : 0,
            bathrooms: typeof pov.bathrooms === "number" ? pov.bathrooms : 0,
            built_up_area: typeof pov.built_up_area === "number" ? pov.built_up_area : 0,
            facilities: Array.isArray(pov.facilities) ? pov.facilities.map(String) : [],
            description: typeof pov.description === "string" ? pov.description : "",
            professional_overview: typeof pov.professional_overview === "string" ? pov.professional_overview : (typeof data.project_summary === "string" ? data.project_summary : "")
        };
        return {
            project_summary: typeof data.project_summary === "string" ? data.project_summary : "Summary unavailable",
            key_selling_points,
            potential_buyer_segments,
            competitive_advantages,
            potential_objections,
            marketing_angles,
            recommended_price_positioning: typeof data.recommended_price_positioning === "string" ? data.recommended_price_positioning : "Market standard",
            analysis_confidence: ["High", "Medium", "Low"].includes(data.analysis_confidence) ? data.analysis_confidence : "Medium",
            property_overview,
            selling_points,
            buyer_personas,
            structured_competitive_advantages,
            structured_objections,
            marketing_strategy,
            analysis_summary,
            missing_information: Array.isArray(data.missing_information) ? data.missing_information.map(String) : [],
            data_provenance: typeof data.data_provenance === "string" ? data.data_provenance : "Gemini AI Developer API Analysis"
        };
    }
    /**
     * Validates and normalizes AudienceDiscoveryOutput (Phase 3.3A)
     */
    static validateAudienceDiscovery(data) {
        if (!data || typeof data !== "object") {
            throw new Error("Invalid AudienceDiscoveryOutput: Expected JSON object.");
        }
        const segmentsRaw = Array.isArray(data.audience_segments) ? data.audience_segments : [];
        const audience_segments = segmentsRaw.map((s) => {
            const messages = Array.isArray(s.recommended_marketing_messages)
                ? s.recommended_marketing_messages.map(String)
                : Array.isArray(s.recommended_content_angles)
                    ? s.recommended_content_angles.map(String)
                    : [];
            const channels = Array.isArray(s.recommended_marketing_channels) && s.recommended_marketing_channels.length > 0
                ? s.recommended_marketing_channels.map(String)
                : ["Facebook Ads", "WhatsApp Broadcast", "Property Portals"];
            const formats = Array.isArray(s.recommended_content_formats) && s.recommended_content_formats.length > 0
                ? s.recommended_content_formats.map(String)
                : ["Short Video Reel", "Carousel Ad", "WhatsApp Flyer"];
            const conf = ["High", "Medium", "Low"].includes(s.confidence_level)
                ? s.confidence_level
                : "High";
            return {
                id: typeof s.id === "string" ? s.id : undefined,
                segment_name: typeof s.segment_name === "string" ? s.segment_name : "Target Audience",
                description: typeof s.description === "string" ? s.description : "",
                estimated_relevance: typeof s.estimated_relevance === "number" ? Math.min(100, Math.max(0, s.estimated_relevance)) : 75,
                buying_motivations: Array.isArray(s.buying_motivations) ? s.buying_motivations.map(String) : [],
                appealing_features: Array.isArray(s.appealing_features) ? s.appealing_features.map(String) : [],
                potential_objections: Array.isArray(s.potential_objections) ? s.potential_objections.map(String) : [],
                recommended_marketing_messages: messages,
                recommended_marketing_channels: channels,
                recommended_content_formats: formats,
                recommended_content_angles: messages,
                evidence: Array.isArray(s.evidence) ? s.evidence.map(String) : ["Agent-provided project specifications"],
                assumptions: Array.isArray(s.assumptions) ? s.assumptions.map(String) : ["Demographic and income alignment with project pricing tier"],
                confidence_level: conf,
                market_demand_disclaimer: "AI-generated audience hypothesis — not verified market demand."
            };
        });
        const ov = data.overview && typeof data.overview === "object" ? data.overview : {};
        const overview = {
            total_segments: audience_segments.length,
            primary_target_group: typeof ov.primary_target_group === "string" ? ov.primary_target_group : (audience_segments[0]?.segment_name || "Primary Audience"),
            strategic_summary: typeof ov.strategic_summary === "string" ? ov.strategic_summary : "Audience hypothesis derived from property pricing, location, and specifications.",
            market_demand_disclaimer: "AI-generated audience hypothesis — not verified market demand."
        };
        return { audience_segments, overview };
    }
    /**
     * Validates and normalizes BuyerMatchingOutput (Phase 3.3B)
     * If deterministic baseline matches are provided, strictly preserves deterministic scores
     * and classifications while enriching with Gemini's explanations, objections, and conversation openers.
     */
    static validateBuyerMatching(data, baseline) {
        if (!data || typeof data !== "object") {
            if (baseline)
                return baseline;
            throw new Error("Invalid BuyerMatchingOutput: Expected JSON object.");
        }
        const matchesRaw = Array.isArray(data.matches) ? data.matches : [];
        const aiMatchMap = new Map();
        for (const m of matchesRaw) {
            if (m && typeof m.buyer_id === "string") {
                aiMatchMap.set(m.buyer_id, m);
            }
        }
        if (baseline) {
            // Deterministic baseline takes absolute precedence for scores & factors
            const enrichedMatches = baseline.matches.map((detMatch) => {
                const aiMatch = aiMatchMap.get(detMatch.buyer_id);
                if (!aiMatch) {
                    return detMatch;
                }
                const aiExplanation = typeof aiMatch.ai_explanation === "string" && aiMatch.ai_explanation.trim().length > 0
                    ? aiMatch.ai_explanation.trim()
                    : detMatch.ai_explanation;
                const conversationOpener = typeof aiMatch.suggested_conversation_opener === "string" && aiMatch.suggested_conversation_opener.trim().length > 0
                    ? aiMatch.suggested_conversation_opener.trim()
                    : detMatch.suggested_conversation_opener;
                const objections = Array.isArray(aiMatch.potential_objections) && aiMatch.potential_objections.length > 0
                    ? aiMatch.potential_objections.map(String)
                    : detMatch.potential_objections;
                const nextAction = typeof aiMatch.recommended_next_action === "string" && aiMatch.recommended_next_action.trim().length > 0
                    ? aiMatch.recommended_next_action.trim()
                    : detMatch.recommended_next_action;
                return {
                    ...detMatch,
                    ai_explanation: aiExplanation,
                    suggested_conversation_opener: conversationOpener,
                    potential_objections: objections,
                    recommended_next_action: nextAction
                };
            });
            return {
                matches: enrichedMatches,
                overview: baseline.overview
            };
        }
        // Fallback if no baseline passed (e.g. legacy or standalone test)
        const matches = matchesRaw.map((m) => {
            const score = typeof m.overall_score === "number" ? Math.min(100, Math.max(0, m.overall_score)) : 50;
            let classification = "Moderate Match";
            if (score >= 85)
                classification = "Excellent Match";
            else if (score >= 70)
                classification = "Good Match";
            else if (score >= 50)
                classification = "Moderate Match";
            else
                classification = "Low Match";
            const missing = Array.isArray(m.missing_information) ? m.missing_information.map(String) : [];
            let conf = "High";
            if (missing.length >= 2)
                conf = "Low";
            else if (missing.length === 1)
                conf = "Medium";
            return {
                buyer_id: typeof m.buyer_id === "string" ? m.buyer_id : "",
                project_id: typeof m.project_id === "string" ? m.project_id : "",
                overall_score: score,
                confidence_level: conf,
                matching_classification: classification,
                matching_factors: {
                    budget: typeof m.matching_factors?.budget === "number" ? m.matching_factors.budget : 0,
                    location: typeof m.matching_factors?.location === "number" ? m.matching_factors.location : 0,
                    property_type: typeof m.matching_factors?.property_type === "number" ? m.matching_factors.property_type : 0,
                    purchase_purpose: typeof m.matching_factors?.purchase_purpose === "number" ? m.matching_factors.purchase_purpose : 0,
                    buying_timeline: typeof m.matching_factors?.buying_timeline === "number" ? m.matching_factors.buying_timeline : 0
                },
                reasons: Array.isArray(m.reasons) ? m.reasons.map(String) : [],
                mismatched_criteria: Array.isArray(m.mismatched_criteria)
                    ? m.mismatched_criteria.map(String)
                    : Array.isArray(m.potential_mismatches)
                        ? m.potential_mismatches.map(String)
                        : [],
                potential_mismatches: Array.isArray(m.potential_mismatches) ? m.potential_mismatches.map(String) : [],
                missing_information: missing,
                potential_objections: Array.isArray(m.potential_objections) ? m.potential_objections.map(String) : [],
                recommended_next_action: typeof m.recommended_next_action === "string" ? m.recommended_next_action : "Follow up with buyer",
                ai_explanation: typeof m.ai_explanation === "string" ? m.ai_explanation : undefined,
                suggested_conversation_opener: typeof m.suggested_conversation_opener === "string" ? m.suggested_conversation_opener : undefined
            };
        });
        return {
            matches,
            overview: {
                total_evaluated: matches.length,
                excellent_matches: matches.filter((m) => m.overall_score >= 85).length,
                good_matches: matches.filter((m) => m.overall_score >= 70 && m.overall_score < 85).length,
                moderate_matches: matches.filter((m) => m.overall_score >= 50 && m.overall_score < 70).length,
                low_matches: matches.filter((m) => m.overall_score < 50).length,
                average_score: matches.length > 0 ? Math.round(matches.reduce((acc, curr) => acc + curr.overall_score, 0) / matches.length) : 0
            }
        };
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