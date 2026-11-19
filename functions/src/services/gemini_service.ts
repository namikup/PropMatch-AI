import { GoogleGenAI } from "@google/genai";
import {
  getGeminiConfig,
  validateModelIdentifier,
  validateFallbackCostPolicy,
  SupportedGeminiModel
} from "../config/gemini.config";
import { ProjectData, SanitizedBuyerData } from "../types/project.types";
import {
  PropertyAnalysisOutput,
  AudienceDiscoveryOutput,
  BuyerMatchingOutput,
  MarketingContentOutput
} from "../types/ai.types";
import { ResponseParser } from "../utils/response_parser";
import { Logger } from "../utils/logger";

export interface LLMExecutionResult<T> {
  data: T;
  model: string;
  latencyMs: number;
  promptTokens: number;
  candidateTokens: number;
  totalTokens: number;
}

export class GeminiService {
  private static async executeWithTimeoutAndRetry<T>(
    prompt: string,
    systemInstruction: string,
    parser: (raw: string) => T,
    preferredModel?: string
  ): Promise<LLMExecutionResult<T>> {
    const config = getGeminiConfig();
    const startTime = Date.now();

    if (!config.apiKey) {
      throw new Error("GEMINI_API_KEY is not configured in environment or secrets.");
    }

    const ai = new GoogleGenAI({ apiKey: config.apiKey });
    const primaryModel: SupportedGeminiModel = preferredModel
      ? validateModelIdentifier(preferredModel, "Preferred model")
      : config.primaryModel;
    const fallbackModel: SupportedGeminiModel = config.fallbackModel;

    // Validate that automatic fallback adheres to cost control policy
    if (primaryModel !== fallbackModel) {
      validateFallbackCostPolicy(primaryModel, fallbackModel, config.allowExpensiveFallback);
    }

    let lastError: unknown;
    const modelsToTry: SupportedGeminiModel[] =
      primaryModel === fallbackModel ? [primaryModel] : [primaryModel, fallbackModel];

    for (const modelName of modelsToTry) {
      let attempts = 0;
      const maxAttempts = config.maxRetries + 1;

      while (attempts < maxAttempts) {
        attempts++;
        try {
          let timer: NodeJS.Timeout | null = null;
          // Timeout promise
          const timeoutPromise = new Promise<never>((_, reject) => {
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

          let res: { text: string; usage: any };
          try {
            res = await Promise.race([executionPromise, timeoutPromise]);
          } finally {
            if (timer) clearTimeout(timer);
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
        } catch (err: unknown) {
          lastError = err;
          const errMsg = err instanceof Error ? err.message : String(err);
          Logger.warn(`Gemini attempt ${attempts}/${maxAttempts} failed on ${modelName}: ${errMsg}`);

          // Detect model-unavailable errors (404 / NOT_FOUND / unreleased / deprecated)
          const isModelUnavailable =
            errMsg.includes("404") ||
            errMsg.includes("not found") ||
            errMsg.includes("is not supported") ||
            errMsg.includes("NOT_FOUND");

          if (isModelUnavailable) {
            Logger.error(`Gemini model '${modelName}' is unavailable or unverified on provider`, { error: errMsg });
            // Model does not exist or is deprecated; retrying same model is futile
            break;
          }

          // Determine if retryable
          const isRetryable =
            errMsg.includes("429") ||
            errMsg.includes("503") ||
            errMsg.includes("500") ||
            errMsg.includes("RESOURCE_EXHAUSTED") ||
            errMsg.includes("quota");

          if (isRetryable && attempts < maxAttempts) {
            const backoffMs = Math.pow(2, attempts) * 500;
            await new Promise((res) => setTimeout(res, backoffMs));
          } else {
            // Break from retry loop to switch model or throw
            break;
          }
        }
      }

      if (modelName === primaryModel && modelsToTry.length > 1) {
        Logger.warn(`Switching to fallback model '${fallbackModel}' after failures on ${primaryModel}`);
      }
    }

    throw lastError || new Error("Failed to execute Gemini AI generation.");
  }

  /**
   * Module A — Deep Property Analysis & Selling Strategy (Phase 3.2)
   */
  static async analyzeProperty(project: ProjectData): Promise<LLMExecutionResult<PropertyAnalysisOutput>> {
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
      const parsed = ResponseParser.parseCleanJson<any>(raw);
      return ResponseParser.validatePropertyAnalysis(parsed);
    });
  }

  /**
   * Module B — Audience Discovery
   */
  static async discoverAudienceSegments(project: ProjectData): Promise<LLMExecutionResult<AudienceDiscoveryOutput>> {
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
      const parsed = ResponseParser.parseCleanJson<any>(raw);
      return ResponseParser.validateAudienceDiscovery(parsed);
    });
  }

  /**
   * Module D — Buyer Matching Intelligence
   */
  static async matchBuyers(
    project: ProjectData,
    buyers: SanitizedBuyerData[]
  ): Promise<LLMExecutionResult<BuyerMatchingOutput>> {
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
      const parsed = ResponseParser.parseCleanJson<any>(raw);
      return ResponseParser.validateBuyerMatching(parsed);
    });
  }

  /**
   * Module E — Multi-Channel Marketing Content Generation
   */
  static async generateMarketingContent(
    project: ProjectData,
    segmentName: string,
    channel: string,
    language: "en" | "bm" | "zh" = "en"
  ): Promise<LLMExecutionResult<MarketingContentOutput>> {
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
      const parsed = ResponseParser.parseCleanJson<any>(raw);
      return ResponseParser.validateMarketingContent(parsed);
    });
  }
}
