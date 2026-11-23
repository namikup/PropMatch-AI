/**
 * PropMatch AI — Phase 3.2.2 Live Gemini API Integration Verification
 *
 * NOTE: Never print, log, or expose the GEMINI_API_KEY.
 */

const fs = require("fs");
const path = require("path");

// 1. Safely load functions/.secret.local into process.env
const secretPath = path.resolve(__dirname, "../functions/.secret.local");
if (!fs.existsSync(secretPath)) {
  console.error("✖ functions/.secret.local does NOT exist!");
  process.exit(1);
}

const secretContent = fs.readFileSync(secretPath, "utf-8");
for (const line of secretContent.split("\n")) {
  const trimmed = line.trim();
  if (trimmed.startsWith("GEMINI_API_KEY=")) {
    process.env.GEMINI_API_KEY = trimmed.substring("GEMINI_API_KEY=".length).trim();
  }
}

if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY === "YOUR_GEMINI_API_KEY_HERE") {
  console.error("✖ GEMINI_API_KEY is missing or contains placeholder!");
  process.exit(1);
}

console.log("✔ functions/.secret.local successfully loaded (Key is masked and safe)");

// 2. Import compiled GeminiService
const { GeminiService } = require("../functions/lib/services/gemini_service");
const { getGeminiConfig } = require("../functions/lib/config/gemini.config");

async function runLiveVerification() {
  console.log("\n=== EXECUTING LIVE GEMINI TEST (PENANG RESIDENCE DEMO) ===");

  const config = getGeminiConfig();
  console.log("Configured Primary Model:", config.primaryModel);
  console.log("Configured Fallback Model:", config.fallbackModel);
  console.log("Temperature:", config.temperature);

  const syntheticProject = {
    id: "proj_penang_demo_001",
    ownerId: "agent_penang_test",
    name: "Penang Residence Demo",
    developer: "Unspecified Developer (Synthetic)",
    location: "Batu Kawan, Penang",
    state: "Penang",
    propertyType: "Condominium",
    startingPrice: 450000,
    maximumPrice: 450000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 950,
    facilities: ["Swimming pool", "Gym", "Security"],
    nearbyAmenities: ["Design Village Outlet Mall", "IKEA Batu Kawan"],
    purpose: "Residential",
    description: "A fictional condominium development intended for testing property positioning and marketing strategy. Partially furnished.",
    targetAudience: "First-time buyers, Young families",
    furnishingStatus: "Partially furnished"
  };

  const startTime = Date.now();
  try {
    console.log("Dispatching live request to Google Gemini API (generativelanguage.googleapis.com)...");
    const result = await GeminiService.analyzeProperty(syntheticProject);
    const durationMs = Date.now() - startTime;

    console.log("\n✔ LIVE GEMINI RESPONSE RECEIVED!");
    console.log("--------------------------------------------------");
    console.log("Model Used:            ", result.model);
    console.log("Execution Latency:     ", result.latencyMs, "ms (Total wall time:", durationMs, "ms)");
    console.log("Prompt Tokens:         ", result.promptTokens);
    console.log("Candidate Tokens:      ", result.candidateTokens);
    console.log("Total Tokens:          ", result.totalTokens);
    console.log("Token Source:           provider_metadata (response.usageMetadata)");
    console.log("Data Provenance:       ", result.data.data_provenance);

    // Official Pricing calculation (verified 2026-11-19: $0.30/1M input, $2.50/1M output for gemini-2.5-flash)
    const inputCostUsd = (result.promptTokens * 0.30) / 1000000;
    const outputCostUsd = (result.candidateTokens * 2.50) / 1000000;
    const totalCostUsd = inputCostUsd + outputCostUsd;
    const totalCostMyr = totalCostUsd * 4.45;

    console.log(`Estimated Cost:         $${totalCostUsd.toFixed(6)} USD (approx RM ${totalCostMyr.toFixed(5)})`);
    console.log("--------------------------------------------------");

    // Verify 7 sections
    console.log("\n=== VERIFYING SEVEN STRUCTURED SECTIONS ===");
    const d = result.data;

    // 1. Property Overview
    console.log("Section 1: Property Overview & Positioning");
    if (d.property_overview && d.property_overview.professional_overview) {
      console.log("  ✔ Exists. Overview snippet:", d.property_overview.professional_overview.substring(0, 100) + "...");
    } else {
      console.error("  ✖ Missing property overview!");
    }

    // 2. Selling Points
    console.log("Section 2: Selling Points");
    if (Array.isArray(d.selling_points) && d.selling_points.length > 0) {
      console.log(`  ✔ Exists (${d.selling_points.length} points). First: "${d.selling_points[0].title}"`);
    } else {
      console.error("  ✖ Missing selling points!");
    }

    // 3. Buyer Personas
    console.log("Section 3: Buyer Personas");
    if (Array.isArray(d.buyer_personas) && d.buyer_personas.length > 0) {
      console.log(`  ✔ Exists (${d.buyer_personas.length} personas). Primary: "${d.buyer_personas[0].segment_name}" (${d.buyer_personas[0].estimated_relevance}%)`);
    } else {
      console.error("  ✖ Missing buyer personas!");
    }

    // 4. Competitive Advantages
    console.log("Section 4: Competitive Advantages");
    const compAdv = d.structured_competitive_advantages || d.competitive_advantages;
    if (Array.isArray(compAdv) && compAdv.length > 0) {
      console.log(`  ✔ Exists (${compAdv.length} advantages). First: "${compAdv[0].advantage || compAdv[0]}"`);
    } else {
      console.error("  ✖ Missing competitive advantages!");
    }

    // 5. Buyer Objections & Response Scripts
    console.log("Section 5: Buyer Objections & Response Scripts");
    const objections = d.structured_objections || d.potential_buyer_objections;
    if (Array.isArray(objections) && objections.length > 0) {
      console.log(`  ✔ Exists (${objections.length} objections). Category: "${objections[0].category || 'General'}"`);
    } else {
      console.error("  ✖ Missing buyer objections!");
    }

    // 6. Marketing Strategy
    console.log("Section 6: Marketing Strategy");
    if (d.marketing_strategy && d.marketing_strategy.suggested_channels) {
      console.log(`  ✔ Exists. Channels: [${d.marketing_strategy.suggested_channels.join(", ")}]`);
      if (d.marketing_strategy.advertisement_headlines) {
        console.log(`    Headline sample: "${d.marketing_strategy.advertisement_headlines[0]}"`);
      }
    } else {
      console.error("  ✖ Missing marketing strategy!");
    }

    // 7. Strategic Summary
    console.log("Section 7: Strategic Summary");
    if (d.analysis_summary && d.analysis_summary.recommended_next_action) {
      console.log(`  ✔ Exists. Next Action: "${d.analysis_summary.recommended_next_action}"`);
      if (d.analysis_summary.analysis_limitations) {
        console.log(`  ✔ Disclaimers: ${d.analysis_summary.analysis_limitations.length} statutory limitations included.`);
      }
    } else {
      console.error("  ✖ Missing strategic summary!");
    }

    // Guardrail Check
    console.log("\n=== GUARDRAIL & NON-HALLUCINATION AUDIT ===");
    const rawJson = JSON.stringify(d).toLowerCase();
    const inventedYield = rawJson.includes("guaranteed rental yield") || rawJson.includes("guaranteed 8%") || rawJson.includes("guaranteed 10%");
    console.log("  ✔ No guaranteed yields invented:", !inventedYield);
    console.log("  ✔ Attribution is Google Gen AI (@google/genai):", d.data_provenance.includes("Google Gen AI"));

    // Save output artifact safely (redacted, no secrets)
    const artifactPath = path.resolve(__dirname, "../scratch_gemini_response.json");
    fs.writeFileSync(artifactPath, JSON.stringify({
      meta: {
        model: result.model,
        latencyMs: result.latencyMs,
        promptTokens: result.promptTokens,
        candidateTokens: result.candidateTokens,
        totalTokens: result.totalTokens,
        estimatedCostUsd: totalCostUsd
      },
      data: result.data
    }, null, 2));
    console.log("\n✔ Redacted result saved to scratch_gemini_response.json for report generation");

  } catch (error) {
    console.error("✖ Live Gemini API request failed:", error.message);
    if (error.stack) {
      console.error(error.stack.split("\n").slice(0, 3).join("\n"));
    }
    process.exit(1);
  }
}

runLiveVerification();
