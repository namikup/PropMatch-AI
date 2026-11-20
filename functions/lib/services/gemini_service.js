"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeminiService = void 0;
const genai_1 = require("@google/genai");
const gemini_config_1 = require("../config/gemini.config");
const response_parser_1 = require("../utils/response_parser");
const logger_1 = require("../utils/logger");
class GeminiService {
    static async executeWithTimeoutAndRetry(prompt, systemInstruction, parser, preferredModel) {
        const config = (0, gemini_config_1.getGeminiConfig)();
        const startTime = Date.now();
        if (!config.apiKey) {
            throw new Error("GEMINI_API_KEY is not configured in environment or secrets.");
        }
        const ai = new genai_1.GoogleGenAI({ apiKey: config.apiKey });
        const primaryModel = preferredModel
            ? (0, gemini_config_1.validateModelIdentifier)(preferredModel, "Preferred model")
            : config.primaryModel;
        const fallbackModel = config.fallbackModel;
        // Validate that automatic fallback adheres to cost control policy
        if (primaryModel !== fallbackModel) {
            (0, gemini_config_1.validateFallbackCostPolicy)(primaryModel, fallbackModel, config.allowExpensiveFallback);
        }
        let lastError;
        const modelsToTry = primaryModel === fallbackModel ? [primaryModel] : [primaryModel, fallbackModel];
        for (const modelName of modelsToTry) {
            let attempts = 0;
            const maxAttempts = config.maxRetries + 1;
            while (attempts < maxAttempts) {
                attempts++;
                try {
                    let timer = null;
                    // Timeout promise
                    const timeoutPromise = new Promise((_, reject) => {
                        timer = setTimeout(() => {
                            reject(new Error(`Gemini API call timed out after ${config.timeoutMs}ms.`));
                        }, config.timeoutMs);
                    });
                    // Execution promise via official @google/genai SDK
                    const executionPromise = (async () => {
                        const response = await ai.models.generateContent({
                            model: modelName,
                            contents: prompt,
                            config: {
                                systemInstruction,
                                responseMimeType: "application/json",
                                temperature: config.temperature,
                                topP: config.topP,
                                maxOutputTokens: config.maxOutputTokens
                            }
                        });
                        return {
                            text: response.text || "",
                            usage: response.usageMetadata
                        };
                    })();
                    let res;
                    try {
                        res = await Promise.race([executionPromise, timeoutPromise]);
                    }
                    finally {
                        if (timer)
                            clearTimeout(timer);
                    }
                    const { text, usage } = res;
                    const latencyMs = Date.now() - startTime;
                    const parsedData = parser(text);
                    return {
                        data: parsedData,
                        model: modelName,
                        latencyMs,
                        promptTokens: usage?.promptTokenCount || 0,
                        candidateTokens: usage?.candidatesTokenCount || 0,
                        totalTokens: usage?.totalTokenCount || 0
                    };
                }
                catch (err) {
                    lastError = err;
                    const errMsg = err instanceof Error ? err.message : String(err);
                    logger_1.Logger.warn(`Gemini attempt ${attempts}/${maxAttempts} failed on ${modelName}: ${errMsg}`);
                    // Detect model-unavailable errors (404 / NOT_FOUND / unreleased / deprecated)
                    const isModelUnavailable = errMsg.includes("404") ||
                        errMsg.includes("not found") ||
                        errMsg.includes("is not supported") ||
                        errMsg.includes("NOT_FOUND");
                    if (isModelUnavailable) {
                        logger_1.Logger.error(`Gemini model '${modelName}' is unavailable or unverified on provider`, { error: errMsg });
                        // Model does not exist or is deprecated; retrying same model is futile
                        break;
                    }
                    // Determine if retryable
                    const isRetryable = errMsg.includes("429") ||
                        errMsg.includes("503") ||
                        errMsg.includes("500") ||
                        errMsg.includes("RESOURCE_EXHAUSTED") ||
                        errMsg.includes("quota");
                    if (isRetryable && attempts < maxAttempts) {
                        const backoffMs = Math.pow(2, attempts) * 500;
                        await new Promise((res) => setTimeout(res, backoffMs));
                    }
                    else {
                        // Break from retry loop to switch model or throw
                        break;
                    }
                }
            }
            if (modelName === primaryModel && modelsToTry.length > 1) {
                logger_1.Logger.warn(`Switching to fallback model '${fallbackModel}' after failures on ${primaryModel}`);
            }
        }
        throw lastError || new Error("Failed to execute Gemini AI generation.");
    }
    /**
     * Module A — Deep Property Analysis & Selling Strategy (Phase 3.2)
     */
    static async analyzeProperty(project) {
        const systemInstruction = `You are an elite Malaysian real estate investment strategist and marketing analyst for PropMatch AI.
Your role is to deeply analyze Malaysian property project characteristics and return comprehensive, actionable strategic insights.
Always return structured JSON adhering strictly to the required schema. Never include conversational filler.
Consider Malaysian market dynamics, state-level pricing (e.g. Penang, Selangor, KL, Johor), property types, and demographic trends.

EVIDENCE & RELIABILITY RULES:
1. Distinguish verified project information, agent-provided data, and AI-generated hypotheses.
2. Never fabricate amenities, travel distances, developer reputation, appreciation statistics, rental yields, or competitor prices.
3. If competitor data is absent, explicitly state that competitor comparison is unavailable.
4. Buyer personas represent marketing hypotheses, never verified individuals or sensitive demographics.`;
        const prompt = `Perform a comprehensive Phase 3.2 property analysis and selling strategy for this Malaysian development:
Project Name: ${project.name}
Developer: ${project.developer}
Location: ${project.location}, ${project.state}
Property Type: ${project.propertyType}
Price Range: RM${project.startingPrice.toLocaleString()} - RM${project.maximumPrice.toLocaleString()}
Built-up Area: ${project.builtUpArea} sqft (${project.bedrooms} bedrooms, ${project.bathrooms} bathrooms)
Target Purpose: ${project.purpose}
Status: ${project.status}
Key Facilities: ${project.facilities.join(", ") || "Standard facilities"}
Nearby Amenities: ${project.nearbyAmenities.join(", ") || "Standard infrastructure"}
Project Description: ${project.description}

Provide JSON adhering to this exact schema:
{
  "project_summary": "Concise 2-3 sentence overview highlighting the project's market position",
  "key_selling_points": ["Short point 1", "Short point 2", "Short point 3"],
  "potential_buyer_segments": ["Segment 1", "Segment 2", "Segment 3"],
  "competitive_advantages": ["Advantage 1", "Advantage 2"],
  "potential_objections": ["Objection 1", "Objection 2"],
  "marketing_angles": ["Angle 1", "Angle 2", "Angle 3"],
  "recommended_price_positioning": "Strategic pricing recommendation based on surrounding market",
  "analysis_confidence": "High",

  "property_overview": {
    "name": "${project.name}",
    "location": "${project.location}",
    "state": "${project.state}",
    "property_type": "${project.propertyType}",
    "price_range": "RM${project.startingPrice.toLocaleString()} - RM${project.maximumPrice.toLocaleString()}",
    "bedrooms": ${project.bedrooms},
    "bathrooms": ${project.bathrooms},
    "built_up_area": ${project.builtUpArea},
    "facilities": ${JSON.stringify(project.facilities)},
    "description": ${JSON.stringify(project.description)},
    "professional_overview": "Comprehensive overview highlighting architectural type, lifestyle features, and regional value."
  },

  "selling_points": [
    {
      "title": "Clear selling point headline",
      "explanation": "Why this matters in the current market",
      "supporting_info": "Exact project attribute supporting this (e.g. Starting price RM${project.startingPrice})",
      "buyer_benefit": "Direct tangible benefit to the buyer",
      "confidence": "High"
    }
  ],

  "buyer_personas": [
    {
      "segment_name": "Specific persona label (e.g. Bayan Lepas Tech Executives)",
      "description": "Background, work profile, and life stage",
      "estimated_relevance": 85,
      "buying_motivations": ["Reason 1", "Reason 2"],
      "appealing_features": ["Feature A", "Feature B"],
      "potential_objections": ["Concern 1", "Concern 2"],
      "recommended_marketing_angle": "Tailored messaging hook"
    }
  ],

  "structured_competitive_advantages": [
    {
      "advantage": "Advantage title",
      "explanation": "Detailed explanation based on provided features",
      "supporting_evidence": "Evidence from agent specifications",
      "evidence_status": "Verified project characteristic"
    }
  ],

  "structured_objections": [
    {
      "objection": "Likely objection or hesitation",
      "category": "price",
      "response_strategy": "Professional agent script and response strategy"
    }
  ],

  "marketing_strategy": {
    "recommended_angles": ["Angle 1", "Angle 2", "Angle 3"],
    "suitable_audience_segments": ["Segment 1", "Segment 2"],
    "suggested_channels": ["Facebook Lead Ads", "Instagram Reels", "Private Preview"],
    "advertisement_headlines": ["Headline 1", "Headline 2", "Headline 3"],
    "social_media_ideas": ["Content concept 1", "Content concept 2"],
    "recommended_calls_to_action": ["Book Showroom Preview", "Download Master Floorplan"]
  },

  "analysis_summary": {
    "overall_positioning": "Summary of positioning in the regional market",
    "strongest_selling_point": "The single most compelling attribute",
    "most_relevant_segment": "The primary persona to prioritize in ad spend",
    "main_potential_objection": "Primary friction point agents must prepare for",
    "recommended_next_action": "Actionable next step for the property agent",
    "analysis_limitations": [
      "Analysis synthesized strictly from agent-supplied project parameters.",
      "Competitor comparisons unavailable unless externally verified.",
      "Buyer personas represent marketing hypotheses, not verified individual leads."
    ]
  },

  "missing_information": [],
  "data_provenance": "Google Gen AI (@google/genai) Analysis"
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validatePropertyAnalysis(parsed);
        });
    }
    /**
     * Module B — Audience Discovery & Market Demand Intelligence (Phase 3.3A)
     */
    static async discoverAudienceSegments(project, existingAnalysis, agentObservations) {
        const systemInstruction = `You are an evidence-aware Malaysian real estate audience intelligence strategist for PropMatch AI.
Discover 3 to 6 potential buyer audience segments strictly relevant to the supplied property project.

STRICT EVIDENCE & COMPLIANCE POLICY:
1. Distinguish between (a) verified project attributes, (b) agent-provided market observations, and (c) AI marketing hypotheses.
2. DO NOT invent numbers of people searching for properties, actual buyer counts, demand statistics, or contact details of identifiable people.
3. Every audience segment represents an analytical marketing hypothesis, NOT verified market demand or guaranteed buyer leads.
4. Estimated relevance scores (0-100) reflect demographic and feature alignment with the property, NOT actual conversion probabilities.
5. Return valid JSON only matching the requested schema.`;
        let contextDetails = `Project: ${project.name} (${project.propertyType})
Developer: ${project.developer}
Location: ${project.location}, ${project.state}
Price Range: RM${project.startingPrice} - RM${project.maximumPrice}
Built-up: ${project.builtUpArea} sqft (${project.bedrooms} Beds, ${project.bathrooms} Baths)
Facilities: ${project.facilities.join(", ")}
Amenities: ${project.nearbyAmenities.join(", ")}
Intended Purpose: ${project.purpose}
Project Description: ${project.description}`;
        if (existingAnalysis) {
            if (existingAnalysis.project_summary) {
                contextDetails += `\nExisting Property Analysis Summary: ${existingAnalysis.project_summary}`;
            }
            if (existingAnalysis.key_selling_points && existingAnalysis.key_selling_points.length > 0) {
                contextDetails += `\nVerified Key Selling Points: ${existingAnalysis.key_selling_points.join("; ")}`;
            }
            if (existingAnalysis.recommended_price_positioning) {
                contextDetails += `\nPrice Positioning: ${existingAnalysis.recommended_price_positioning}`;
            }
        }
        if (agentObservations && agentObservations.trim().length > 0) {
            contextDetails += `\nAgent-Provided Local Market Observations: ${agentObservations.trim()}`;
        }
        const prompt = `Analyze the following Malaysian property and generate approximately 3 to 6 distinct, highly qualified potential buyer audience segments:

${contextDetails}

Evaluate which buyer profiles are genuinely suitable for this property (e.g., first-time homebuyers, young working professionals, upgraders/families, investors, interstate migrants, lifestyle retirees). Do NOT generate unsuitable segments automatically if the property's pricing or attributes do not align.

Format your response as JSON matching:
{
  "overview": {
    "total_segments": 4,
    "primary_target_group": "Name of top audience to prioritize",
    "strategic_summary": "1-2 sentence executive summary of overall buyer demand alignment",
    "market_demand_disclaimer": "AI-generated audience hypothesis — not verified market demand."
  },
  "audience_segments": [
    {
      "segment_name": "Specific persona title (e.g. Bayan Lepas Multinational Tech Engineers)",
      "description": "Demographic, economic profile, and life stage of this segment",
      "estimated_relevance": 88,
      "buying_motivations": ["Commute convenience to Bayan Lepas FTZ", "Resort facilities for young active lifestyle"],
      "appealing_features": ["Proximity to expressway", "Freehold title", "High-speed internet ready"],
      "potential_objections": ["Higher density vs landed properties", "Peak hour traffic along coastal expressway"],
      "recommended_marketing_messages": ["Cut your daily commute by half — Seafront living 5 mins from Bayan Lepas"],
      "recommended_marketing_channels": ["Facebook Lead Ads", "WhatsApp Direct Broadcast", "Property Portals", "Xiaohongshu (RED)"],
      "recommended_content_formats": ["15s Video Reel", "Carousel Floorplan Ad", "WhatsApp PDF Brochure"],
      "evidence": ["Project located 5 mins from FTZ corridor", "Starting price RM${project.startingPrice} matches monthly household income >RM8,000"],
      "assumptions": ["Assumes household monthly income aligns with 3.8% mortgage rate", "Assumes buyer values lifestyle amenities over land title"],
      "confidence_level": "High",
      "market_demand_disclaimer": "AI-generated audience hypothesis — not verified market demand."
    }
  ]
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validateAudienceDiscovery(parsed);
        });
    }
    /**
     * Module D — Buyer Matching Intelligence (Phase 3.3B)
     * The deterministic engine pre-computes scores. Gemini generates rich explanations,
     * feature relevance, objection management, and conversation openers.
     */
    static async matchBuyers(project, buyers, baseline) {
        const systemInstruction = `You are an elite Malaysian real estate advisory engine for PropMatch AI.
Your task is to provide expert contextual explanations, objection handling, and follow-up guidance for pre-computed buyer compatibility matches.

STRICT CONSTRAINTS & COMPLIANCE:
1. DO NOT modify, adjust, or invent compatibility scores or matching dimensions. The deterministic scores are strictly fixed.
2. Provide rich, highly specific qualitative insights for each buyer:
   - "ai_explanation": A concise narrative (2-3 sentences) explaining why the buyer matches or does not match this specific property based on their preferences.
   - "potential_objections": Realistic concerns or hesitations this buyer profile may voice regarding price, layout, location, or timing.
   - "recommended_next_action": Concrete next step for the property agent (e.g. loan qualification check, video walkthrough, showroom tour, unit floorplan comparison).
   - "suggested_conversation_opener": A respectful, high-converting WhatsApp/call opening message customized for this match.
3. Strict PDPA & privacy: Never hallucinate or assume personal identity or unverified details.
4. Output valid JSON strictly following the requested schema.`;
        const matchContext = baseline.matches.map((m) => {
            const buyerData = buyers.find((b) => b.id === m.buyer_id);
            return {
                buyer_id: m.buyer_id,
                deterministic_score: m.overall_score,
                classification: m.matching_classification,
                confidence: m.confidence_level,
                factors: m.matching_factors,
                preferences: buyerData
                    ? {
                        budget: `RM${buyerData.budgetMin.toLocaleString()} - RM${buyerData.budgetMax.toLocaleString()}`,
                        preferredLocation: buyerData.preferredLocation,
                        preferredState: buyerData.preferredState,
                        propertyType: buyerData.propertyType,
                        purpose: buyerData.purchasePurpose,
                        timeline: buyerData.buyingTimeline
                    }
                    : {}
            };
        });
        const prompt = `Review the following ${matchContext.length} pre-calculated deterministic buyer matches for this Malaysian property development:

Property Details:
Project: ${project.name} in ${project.location}, ${project.state}
Price Range: RM${project.startingPrice.toLocaleString()} to RM${project.maximumPrice.toLocaleString()}
Type: ${project.propertyType}, Bedrooms: ${project.bedrooms}, Bathrooms: ${project.bathrooms}
Purpose: ${project.purpose}, Status: ${project.status}
Key Facilities: ${project.facilities.join(", ") || "Standard facilities"}

Pre-Calculated Deterministic Matches:
${JSON.stringify(matchContext, null, 2)}

Provide strategic explanations, objections, and conversation openers adhering to this JSON format:
{
  "matches": [
    {
      "buyer_id": "buyer_id_here",
      "ai_explanation": "Detailed explanation of match compatibility and lifestyle fit for this property",
      "potential_objections": ["Specific objection 1", "Specific objection 2"],
      "recommended_next_action": "Specific next action for the property agent",
      "suggested_conversation_opener": "Personalized WhatsApp / phone outreach opener"
    }
  ]
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validateBuyerMatching(parsed, baseline);
        });
    }
    /**
     * Module E — Multi-Channel Marketing Content Generation
     */
    static async generateMarketingContent(project, segmentName, channel, language = "en") {
        const systemInstruction = `You are an expert Malaysian real estate copywriter producing conversion-focused property marketing copy.
Produce compelling ad copy localized for the Malaysian property market in ${language.toUpperCase()}.
Return valid JSON only.`;
        const prompt = `Generate marketing copy tailored for the following audience and property:
Project: ${project.name} (${project.propertyType})
Location: ${project.location}, ${project.state}
Price: From RM${project.startingPrice}
Target Segment: ${segmentName}
Target Channel: ${channel}
Language: ${language}

Output JSON format:
{
  "headline": "Punchy, attention-grabbing headline",
  "primary_text": "Engaging body copy highlighting benefits, location advantages, and pain points",
  "call_to_action": "Clear direct response CTA",
  "channels": [
    {
      "platform": "${channel}",
      "content": "Formatted post with appropriate tone",
      "hashtags": ["#PropMatch", "#MalaysiaProperty"]
    }
  ],
  "content_calendar_suggestion": "Recommended posting time and campaign frequency",
  "language": "${language}"
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validateMarketingContent(parsed);
        });
    }
}
exports.GeminiService = GeminiService;
//# sourceMappingURL=gemini_service.js.map