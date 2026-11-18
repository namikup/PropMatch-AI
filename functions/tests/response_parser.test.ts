import { ResponseParser } from "../src/utils/response_parser";

describe("ResponseParser", () => {
  describe("parseCleanJson", () => {
    it("should parse standard JSON string correctly", () => {
      const raw = '{"project_summary": "Luxury condo in Penang", "key_selling_points": ["Sea view"]}';
      const result = ResponseParser.parseCleanJson<any>(raw);
      expect(result.project_summary).toBe("Luxury condo in Penang");
      expect(result.key_selling_points).toEqual(["Sea view"]);
    });

    it("should strip markdown code fences (```json ... ```)", () => {
      const raw = "```json\n{\n  \"status\": \"success\",\n  \"score\": 95\n}\n```";
      const result = ResponseParser.parseCleanJson<any>(raw);
      expect(result.status).toBe("success");
      expect(result.score).toBe(95);
    });

    it("should strip generic markdown code fences (``` ... ```)", () => {
      const raw = "```\n{\n  \"name\": \"Gurney Bay\"\n}\n```";
      const result = ResponseParser.parseCleanJson<any>(raw);
      expect(result.name).toBe("Gurney Bay");
    });

    it("should strip conversational text preceding or succeeding the JSON block", () => {
      const raw = "Here is the property analysis you requested:\n```json\n{\n  \"summary\": \"Great value\"\n}\n```\nHope this helps your marketing campaign!";
      const result = ResponseParser.parseCleanJson<any>(raw);
      expect(result.summary).toBe("Great value");
    });

    it("should throw error for invalid malformed JSON", () => {
      const raw = "This is not json at all { unclosed bracket";
      expect(() => ResponseParser.parseCleanJson(raw)).toThrow();
    });

    it("should throw error for empty input", () => {
      expect(() => ResponseParser.parseCleanJson("")).toThrow("Empty or non-string response");
    });
  });

  describe("validatePropertyAnalysis", () => {
    it("should normalize valid property analysis data", () => {
      const valid = {
        project_summary: "A premier transit-oriented development.",
        key_selling_points: ["Direct LRT link", "High rental demand"],
        potential_buyer_segments: ["Urban Commuters"],
        competitive_advantages: ["Lowest price per sqft in area"],
        potential_objections: ["High density"],
        marketing_angles: ["Work in KL, live in convenience"],
        recommended_price_positioning: "Priced 10% below market average",
        analysis_confidence: "High"
      };

      const normalized = ResponseParser.validatePropertyAnalysis(valid);
      expect(normalized.project_summary).toBe("A premier transit-oriented development.");
      expect(normalized.key_selling_points.length).toBe(2);
      expect(normalized.analysis_confidence).toBe("High");
    });

    it("should provide safe defaults for missing or malformed fields", () => {
      const malformed = {
        project_summary: 123, // wrong type
        analysis_confidence: "InvalidConfidence"
      };

      const normalized = ResponseParser.validatePropertyAnalysis(malformed);
      expect(normalized.project_summary).toBe("Summary unavailable");
      expect(normalized.key_selling_points).toEqual([]);
      expect(normalized.analysis_confidence).toBe("Medium");
    });
  });

  describe("validateAudienceDiscovery", () => {
    it("should validate and clamp estimated_relevance", () => {
      const input = {
        audience_segments: [
          {
            segment_name: "Tech Expats",
            estimated_relevance: 120, // Should be clamped to 100
            buying_motivations: ["Proximity to Cyberjaya"],
            recommended_marketing_channels: ["LinkedIn Ads"]
          }
        ]
      };

      const result = ResponseParser.validateAudienceDiscovery(input);
      expect(result.audience_segments.length).toBe(1);
      expect(result.audience_segments[0].estimated_relevance).toBe(100);
      expect(result.audience_segments[0].segment_name).toBe("Tech Expats");
    });
  });

  describe("validateBuyerMatching", () => {
    it("should validate match scores and factors", () => {
      const input = {
        matches: [
          {
            buyer_id: "buyer-123",
            project_id: "project-456",
            overall_score: 85,
            matching_factors: {
              budget: 25,
              location: 25,
              property_type: 20,
              purchase_purpose: 15,
              buying_timeline: 0
            },
            reasons: ["Ideal budget range"]
          }
        ]
      };

      const result = ResponseParser.validateBuyerMatching(input);
      expect(result.matches.length).toBe(1);
      expect(result.matches[0].overall_score).toBe(85);
      expect(result.matches[0].matching_factors.budget).toBe(25);
    });
  });

  describe("validateMarketingContent", () => {
    it("should validate multi-channel marketing content", () => {
      const input = {
        headline: "Own Your Sanctuary in Penang",
        primary_text: "Spacious sea-facing residences from RM650,000.",
        call_to_action: "Book Private Tour",
        channels: [
          {
            platform: "Facebook Ad",
            content: "Wake up to ocean views every morning...",
            hashtags: ["#PenangProperty"]
          }
        ],
        language: "en"
      };

      const result = ResponseParser.validateMarketingContent(input);
      expect(result.headline).toBe("Own Your Sanctuary in Penang");
      expect(result.language).toBe("en");
      expect(result.channels[0].hashtags).toEqual(["#PenangProperty"]);
    });
  });
});
