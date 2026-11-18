"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeminiService = void 0;
const generative_ai_1 = require("@google/generative-ai");
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
        const genAI = new generative_ai_1.GoogleGenerativeAI(config.apiKey);
        const primaryModel = preferredModel || config.primaryModel;
        const fallbackModel = config.fallbackModel;
        let lastError;
        const modelsToTry = [primaryModel, fallbackModel];
        for (const modelName of modelsToTry) {
            let attempts = 0;
            const maxAttempts = config.maxRetries + 1;
            while (attempts < maxAttempts) {
                attempts++;
                try {
                    const generativeModel = genAI.getGenerativeModel({
                        model: modelName,
                        generationConfig: {
                            responseMimeType: "application/json",
                            temperature: config.temperature,
                            topP: config.topP,
                            maxOutputTokens: config.maxOutputTokens
                        },
                        systemInstruction
                    });
                    let timer = null;
                    // Timeout promise
                    const timeoutPromise = new Promise((_, reject) => {
                        timer = setTimeout(() => {
                            reject(new Error(`Gemini API call timed out after ${config.timeoutMs}ms.`));
                        }, config.timeoutMs);
                    });
                    // Execution promise
                    const executionPromise = (async () => {
                        const result = await generativeModel.generateContent(prompt);
                        const response = await result.response;
                        return {
                            text: response.text(),
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
            logger_1.Logger.warn(`Switching to fallback model after failures on ${modelName}`);
        }
        throw lastError || new Error("Failed to execute Gemini AI generation.");
    }
    /**
     * Module A — Deep Property Analysis
     */
    static async analyzeProperty(project) {
        const systemInstruction = `You are an elite Malaysian real estate investment strategist and marketing analyst for PropMatch AI.
Your role is to deeply analyze Malaysian property project characteristics and return comprehensive, actionable strategic insights.
Always return structured JSON adhering strictly to the required schema. Never include conversational filler.
Consider Malaysian market dynamics, state-level pricing (e.g. Penang, Selangor, KL, Johor), property types, and demographic trends.`;
        const prompt = `Perform a comprehensive property analysis for the following Malaysian development:
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

Provide output in JSON matching this exact structure:
{
  "project_summary": "Concise 2-3 sentence overview highlighting the project's market position",
  "key_selling_points": ["Point 1", "Point 2", "Point 3", "Point 4"],
  "potential_buyer_segments": ["Segment A", "Segment B", "Segment C"],
  "competitive_advantages": ["Advantage 1", "Advantage 2", "Advantage 3"],
  "potential_objections": ["Objection 1", "Objection 2"],
  "marketing_angles": ["Angle 1", "Angle 2", "Angle 3"],
  "recommended_price_positioning": "Strategic pricing recommendation based on surrounding market",
  "analysis_confidence": "High"
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validatePropertyAnalysis(parsed);
        });
    }
    /**
     * Module B — Audience Discovery
     */
    static async discoverAudienceSegments(project) {
        const systemInstruction = `You are a high-performance digital marketing strategist specializing in Malaysian property buyer discovery.
Generate high-relevance, distinct audience persona segments for real estate marketing campaigns.
Return valid JSON only.`;
        const prompt = `Generate 4 distinct, highly qualified audience segments for marketing this Malaysian property:
Project: ${project.name} (${project.propertyType})
Location: ${project.location}, ${project.state}
Price: RM${project.startingPrice} - RM${project.maximumPrice}
Built-up: ${project.builtUpArea} sqft (${project.bedrooms} Beds)
Facilities: ${project.facilities.join(", ")}
Amenities: ${project.nearbyAmenities.join(", ")}
Purpose: ${project.purpose}

Format your response as JSON matching:
{
  "audience_segments": [
    {
      "segment_name": "Specific persona title",
      "description": "Demographic and behavioral background",
      "estimated_relevance": 85,
      "buying_motivations": ["Reason 1", "Reason 2"],
      "potential_objections": ["Concern 1", "Concern 2"],
      "recommended_marketing_channels": ["Facebook Lead Ads", "Instagram Reel", "Google Search"],
      "recommended_content_angles": ["Angle 1", "Angle 2"],
      "evidence": ["Why this project suits them based on facilities or price"],
      "assumptions": ["Key assumptions made regarding this segment"]
    }
  ]
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validateAudienceDiscovery(parsed);
        });
    }
    /**
     * Module D — Buyer Matching Intelligence
     */
    static async matchBuyers(project, buyers) {
        const systemInstruction = `You are a precision buyer-property matching engine for PropMatch AI.
Evaluate how well each prospective buyer aligns with the property across 5 dimensions:
1. Budget Compatibility (Weight: 25%)
2. Location Compatibility (Weight: 25%)
3. Property Type (Weight: 20%)
4. Purchase Purpose (Weight: 15%)
5. Buying Timeline (Weight: 15%)
Return valid JSON only.`;
        const buyersPayload = JSON.stringify(buyers, null, 2);
        const prompt = `Evaluate the following ${buyers.length} prospective buyers against the property development:
Property: ${project.name} in ${project.location}, ${project.state}
Price Range: RM${project.startingPrice} to RM${project.maximumPrice}
Type: ${project.propertyType}, Bedrooms: ${project.bedrooms}, Purpose: ${project.purpose}

Buyers:
${buyersPayload}

Output JSON format:
{
  "matches": [
    {
      "buyer_id": "buyer_id_here",
      "project_id": "${project.id}",
      "overall_score": 88,
      "matching_factors": {
        "budget": 25,
        "location": 20,
        "property_type": 18,
        "purchase_purpose": 12,
        "buying_timeline": 13
      },
      "reasons": ["Specific alignment reasons"],
      "potential_mismatches": ["Any concerns or budget stretches"],
      "missing_information": ["Any missing criteria from buyer profile"],
      "recommended_next_action": "e.g. Schedule private showroom viewing"
    }
  ]
}`;
        return this.executeWithTimeoutAndRetry(prompt, systemInstruction, (raw) => {
            const parsed = response_parser_1.ResponseParser.parseCleanJson(raw);
            return response_parser_1.ResponseParser.validateBuyerMatching(parsed);
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