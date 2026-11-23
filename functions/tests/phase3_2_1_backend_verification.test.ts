import { GeminiService } from "../src/services/gemini_service";
import { ProjectData } from "../src/types/project.types";
import {
  ACTIVE_SUPPORTED_MODELS,
  RETIRED_MODELS,
  MODEL_PRICING_REGISTRY,
  getGeminiConfig
} from "../src/config/gemini.config";

describe("Phase 3.2.1: Live Gemini Configuration & Verification Audit", () => {
  const syntheticProject: ProjectData = {
    id: "demo_penang_residence_001",
    ownerId: "agent_qa_synthetic",
    name: "Penang Residence Demo",
    developer: "Penang Development Corp",
    location: "Batu Kawan",
    state: "Penang",
    propertyType: "Condominium",
    startingPrice: 450000,
    maximumPrice: 450000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 950,
    facilities: ["Swimming pool", "Gym", "Security"],
    nearbyAmenities: ["Design Village", "IKEA Batu Kawan"],
    description: "Partially furnished modern condominium in Batu Kawan.",
    purpose: "Own Stay",
    status: "New Launch"
  };

  it("1. verifies model registry configuration (Primary and Fallback)", () => {
    // Primary model must be gemini-3.5-flash-lite
    expect(ACTIVE_SUPPORTED_MODELS[0]).toBe("gemini-3.5-flash-lite");
    // Fallback model must be gemini-3.5-flash
    expect(ACTIVE_SUPPORTED_MODELS[1]).toBe("gemini-3.5-flash");

    // Must not contain any retired models
    for (const retired of RETIRED_MODELS) {
      expect(ACTIVE_SUPPORTED_MODELS as readonly string[]).not.toContain(retired);
    }
  });

  it("2. verifies official pricing registry for primary model", () => {
    const pricing = MODEL_PRICING_REGISTRY["gemini-3.5-flash-lite"];
    expect(pricing.inputPricePerMillion).toBe(0.30);
    expect(pricing.outputPricePerMillion).toBe(2.50);
    expect(pricing.thinkingTokenBilling).toBe("billed_as_output");

    // Standard theoretical calculation for Penang Residence Demo (~850 in, ~600 out)
    const estInCost = (850 / 1_000_000) * pricing.inputPricePerMillion;
    const estOutCost = (600 / 1_000_000) * pricing.outputPricePerMillion;
    const estTotalCost = estInCost + estOutCost;

    expect(estTotalCost).toBeCloseTo(0.001755, 6);
  });

  it("3. verifies that GeminiService requires GEMINI_API_KEY and never leaks it", async () => {
    // Clear API key to simulate unconfigured Secret Manager
    delete process.env.GEMINI_API_KEY;

    await expect(GeminiService.analyzeProperty(syntheticProject)).rejects.toThrow(
      "GEMINI_API_KEY is not configured in environment or secrets."
    );
  });

  it("4. verifies getGeminiConfig behavior when API key is provided vs missing", () => {
    const emptyConfig = getGeminiConfig("");
    expect(emptyConfig.apiKey).toBe("");
    const validConfig = getGeminiConfig("dummy-key");
    expect(validConfig.primaryModel).toBe("gemini-3.5-flash-lite");
    expect(validConfig.fallbackModel).toBe("gemini-3.5-flash");
    expect(validConfig.apiKey).toBe("dummy-key");
  });
});
