import '../models/project_model.dart';
import '../models/audience_segment_model.dart';

/// Rule-based AI engine for audience discovery.
///
/// All outputs are AI-generated marketing hypotheses and strategic estimates.
/// They are NOT verified market data, real buyer profiles, or guaranteed
/// conversion statistics. The architecture is modular and ready for future
/// Gemini API integration.
class AIService {
  // ───────────────────────────────────────────────────────────
  //  Core Public API
  // ───────────────────────────────────────────────────────────

  /// Analyzes a property project and generates dynamically ranked potential
  /// audience segments based on the project's specific characteristics.
  ///
  /// The segments returned depend on price, location, type, bedrooms,
  /// built-up area, purpose, facilities and amenities — no two projects
  /// should produce identical segment lists.
  static List<AudienceSegmentModel> discoverAudienceSegments(ProjectModel project) {
    final candidates = <_SegmentCandidate>[];

    // Evaluate candidate segments against project characteristics
    candidates.add(_evaluateYoungProfessionals(project));
    candidates.add(_evaluateFirstTimeBuyers(project));
    candidates.add(_evaluateInvestors(project));
    candidates.add(_evaluateUpgradingFamilies(project));
    candidates.add(_evaluateRetirees(project));
    candidates.add(_evaluateOutOfStateBuyers(project));
    candidates.add(_evaluateRentalInvestors(project));
    candidates.add(_evaluateUndecidedSeekers(project));
    candidates.add(_evaluateDigitalNomads(project));

    // Filter out low-relevance segments (score < 40)
    candidates.removeWhere((c) => c.score < 40);

    // Sort by score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // Assign ranks and build models
    final segments = <AudienceSegmentModel>[];
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      segments.add(c.toModel(
        rank: i + 1,
        projectId: project.id,
        ownerId: project.ownerId,
      ));
    }

    return segments;
  }

  /// Generates geographic targeting strategy for a segment based on a project.
  /// Returns which Malaysian states buyers could come from with rationale.
  static List<GeographicTarget> generateGeographicStrategy(
    ProjectModel project,
    AudienceSegmentModel segment,
  ) {
    final targets = <GeographicTarget>[];
    final projState = project.state;
    final projLocation = project.location;
    final price = project.startingPrice;

    // 1. Local state — highest natural affinity
    targets.add(GeographicTarget(
      state: projState,
      rationale:
          "Local market within $projState. Buyers are already familiar with $projLocation "
          "and surrounding infrastructure. Lowest friction for showroom visits and loan processing.",
      relevanceScore: 90.0,
      marketingOpportunity:
          "Immediate catchment of local tenants and upgraders seeking modern amenities without relocating away from their community.",
      campaignAngle:
          "Upgrade your family lifestyle in $projLocation without leaving the neighbourhood you know and trust.",
      assumptions: [
        "Assumes existing local residents are seeking to upgrade from older surrounding developments",
        "Assumes proximity to familiar daily commute routes and family circles is the primary purchase driver",
        "Assumes local buyer affinity is not diminished by nearby competing developer launches",
      ],
      marketingApproach: [
        "Geo-fenced Facebook & Instagram ads within 30km radius",
        "WhatsApp broadcast to local agent referral networks",
        "Local newspaper & weekend mall roadshows",
      ],
    ));

    // 2. KL / Selangor — outbound capital & lifestyle migration
    if (projState != "Kuala Lumpur" && projState != "Selangor") {
      final klScore = price <= 600000 ? 82.0 : (price <= 900000 ? 74.0 : 66.0);
      targets.add(GeographicTarget(
        state: "Kuala Lumpur & Selangor",
        rationale:
            "KL/Selangor professionals seeking more affordable property or holiday/retirement homes "
            "outside the Klang Valley. $projState property prices offer strong value compared to KL equivalents.",
        relevanceScore: klScore,
        marketingOpportunity:
            "Capturing out-of-state capital flight and hybrid remote workers seeking spacious living at half the Klang Valley price point.",
        campaignAngle:
            "Half the KL price tag for twice the lifestyle and space in beautiful $projState.",
        assumptions: [
          "Hypothetical persona assuming Klang Valley buyers are open to out-of-state property for investment or holiday use",
          "Assumes buyers are willing to utilize digital viewing tools and engage local tenant management services",
          "Does not represent recorded cross-state census migration figures",
        ],
        marketingApproach: [
          "Digital ads targeting KL/Selangor IP addresses interested in $projState property",
          "Virtual 360 showroom tours for out-of-state convenience",
          "Partnership with KL-based property expos and investor seminars",
        ],
      ));
    }

    // 3. Neighbouring states
    final neighbours = _getNeighbouringStates(projState);
    for (final neighbour in neighbours) {
      if (neighbour == "Kuala Lumpur" || neighbour == "Selangor") continue;
      final score = price <= 500000 ? 72.0 : 62.0;
      targets.add(GeographicTarget(
        state: neighbour,
        rationale:
            "Cross-border proximity to $projState. $neighbour residents can commute or "
            "relocate with minimal lifestyle disruption. "
            "Shared regional economic corridor drives employment migration.",
        relevanceScore: score,
        marketingOpportunity:
            "Inter-state commuters and professionals working in adjacent regional industrial or commercial nodes.",
        campaignAngle:
            "Strategic cross-border living: Enjoy modern amenities closer to regional growth hubs.",
        assumptions: [
          "Assumes daily or weekly highway transit between $neighbour and $projState is viable for buyers",
          "Assumes localized supply in $neighbour has fewer modern lifestyle facilities at this price tier",
          "Hypothetical market sizing based on geographic proximity, not actual transaction volumes",
        ],
        marketingApproach: [
          "Facebook/Instagram ads targeting $neighbour residents aged 25-50",
          "Co-marketing with $neighbour-based property agents",
          "Weekend cross-border property bus tours",
        ],
      ));
    }

    // 4. Singapore (for southern states or projects in reasonable brackets)
    if (projState == "Johor" ||
        projState == "Melaka" ||
        (price >= 300000 && price <= 800000)) {
      targets.add(GeographicTarget(
        state: "Singapore (Cross-border)",
        rationale:
            "Singaporean buyers and Malaysian PRs in Singapore seek affordable Malaysian property "
            "as investment or weekend homes. Currency advantage makes RM-denominated property attractive.",
        relevanceScore: projState == "Johor" ? 78.0 : 54.0,
        marketingOpportunity:
            "Strong SGD currency exchange rate enhancing purchasing power for RM-denominated residential assets.",
        campaignAngle:
            "Leverage your currency advantage: Own luxury freehold property in Malaysia from RM${price.toStringAsFixed(0)}.",
        assumptions: [
          "Assumes buyers satisfy state regulatory minimum price thresholds for foreign or PR ownership where applicable",
          "Assumes buyer motivation is driven by currency exchange advantages or long-term retirement security",
          "Does not represent verified Singaporean buyer registry records",
        ],
        marketingApproach: [
          "Facebook/Instagram ads targeting Malaysians living in Singapore",
          "Singapore property expo booth partnerships",
          "Cross-border webinar series in English and Mandarin",
        ],
      ));
    }

    // 5. Northern Corridor (Penang-Kedah)
    if ((projState == "Penang" || projState == "Kedah") &&
        !neighbours.contains(projState == "Penang" ? "Kedah" : "Penang")) {
      final corridorState = projState == "Penang" ? "Kedah" : "Penang";
      targets.add(GeographicTarget(
        state: corridorState,
        rationale:
            "The Penang-Kedah Northern Corridor Economic Region (NCER) drives cross-state "
            "employment and lifestyle migration. $corridorState residents working in $projState "
            "seek permanent housing closer to workplaces.",
        relevanceScore: 74.0,
        marketingOpportunity:
            "Industrial workforce expansion across manufacturing parks (e.g., BKIP, Kulim Hi-Tech Park, Bayan Lepas).",
        campaignAngle:
            "Work in the Northern tech corridor, live in modern resort comfort.",
        assumptions: [
          "Assumes regular talent movement between industrial clusters across the state border",
          "Assumes buyers prioritize proximity to expressways and bridges over state boundaries",
          "Strategic corridor hypothesis based on industrial zoning, not confirmed census data",
        ],
        marketingApproach: [
          "Targeted digital ads to $corridorState commuters",
          "Joint roadshows at NCER employment hubs",
          "WhatsApp drip campaigns via cross-state agent referrals",
        ],
      ));
    }

    // Sort by relevance
    targets.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return targets;
  }

  // ───────────────────────────────────────────────────────────
  //  Per-segment Marketing Content Generation
  // ───────────────────────────────────────────────────────────

  /// Generates platform-specific marketing content for a given audience
  /// segment and property project. All content is AI-generated creative copy.
  static SegmentMarketingContent generateSegmentMarketingContent(
    ProjectModel project,
    AudienceSegmentModel segment,
  ) {
    final loc = project.location;
    final state = project.state;
    final price = "RM${project.startingPrice.toStringAsFixed(0)}";
    final name = project.name;
    final beds = project.bedrooms;
    final sqft = project.builtUpArea.toStringAsFixed(0);
    final dev = project.developer;
    final segName = segment.name;

    return SegmentMarketingContent(
      facebookPost: _generateFacebookPost(
          name, dev, loc, state, price, beds, sqft, segName, segment),
      instagramCaption: _generateInstagramCaption(
          name, loc, price, beds, sqft, segName),
      tikTokIdea: _generateTikTokIdea(name, loc, price, segName, segment),
      headlines: _generateHeadlines(name, loc, price, segName, segment),
      callToActions: _generateCTAs(name, segName, segment),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Private: Segment Evaluation Functions
  // ───────────────────────────────────────────────────────────

  static _SegmentCandidate _evaluateYoungProfessionals(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 44;

    // Tech hub proximity
    final techHubs = [
      "batu kawan",
      "bayan lepas",
      "kulim",
      "cyberjaya",
      "bangsar south",
      "petaling jaya",
      "mont kiara",
      "damansara"
    ];
    final isNearTech = techHubs.any((h) => p.location.toLowerCase().contains(h));
    if (isNearTech) {
      score += 18;
      factors.add("+18 — Located near major employment/tech hub (${p.location})");
      matchingChars.add("Location within prime employment/tech node (${p.location})");
    } else {
      score -= 6;
      factors.add("-6 — Location (${p.location}) is not recognized as a tier-1 tech or corporate cluster");
    }

    // Price accessibility
    if (p.startingPrice <= 500000) {
      score += 16;
      factors.add("+16 — Entry price <= RM500k fits young professional salary brackets");
      matchingChars.add("Accessible entry price of RM${p.startingPrice.toStringAsFixed(0)} (est. mortgage ~RM${(p.startingPrice * 0.005).toStringAsFixed(0)}/mo)");
    } else if (p.startingPrice <= 700000) {
      score += 10;
      factors.add("+10 — Entry price <= RM700k accessible for mid-level professionals");
      matchingChars.add("Mid-range pricing (RM${p.startingPrice.toStringAsFixed(0)}) suits mid-career executives");
    } else {
      score -= 12;
      factors.add("-12 — Price above RM700k reduces affordability for early-career professionals");
    }

    // Modern amenities
    final modernKeywords = ["co-working", "gym", "wifi", "ev", "smart", "lounge"];
    final modernCount = p.facilities
        .where((f) => modernKeywords.any((k) => f.toLowerCase().contains(k)))
        .length;
    if (modernCount >= 2) {
      score += 12;
      factors.add("+12 — $modernCount modern lifestyle facilities (co-working/gym/EV)");
      matchingChars.add("Modern lifestyle facilities available ($modernCount amenities detected)");
    } else if (modernCount == 1) {
      score += 6;
      factors.add("+6 — 1 modern lifestyle amenity identified");
    } else {
      score -= 6;
      factors.add("-6 — Lacks modern lifestyle facilities (no co-working/smart features detected)");
    }

    // Bedrooms
    if (p.bedrooms <= 3) {
      score += 6;
      factors.add("+6 — ${p.bedrooms}-bedroom layout suits single/couple professionals");
      matchingChars.add("${p.bedrooms}-bedroom unit layout matches single or couple living");
    } else {
      score -= 6;
      factors.add("-6 — ${p.bedrooms} bedrooms exceed standard compact requirements of young executives");
    }

    // Property type
    if (p.propertyType == "Condominium" ||
        p.propertyType == "Serviced Residence" ||
        p.propertyType == "Studio") {
      score += 6;
      factors.add("+6 — ${p.propertyType} format preferred by young urban professionals");
      matchingChars.add("Modern high-rise format: ${p.propertyType}");
    }

    // Missing information check
    if (p.facilities.isEmpty) {
      missingInfo.add("Project facilities list is empty; lifestyle fit could not be fully verified");
    } else if (!p.facilities.any((f) => f.toLowerCase().contains("wifi") || f.toLowerCase().contains("co-working"))) {
      missingInfo.add("High-speed fibre broadband readiness and co-working workspace hours not documented");
    }
    if (p.nearbyAmenities.isEmpty) {
      missingInfo.add("Public transit stations (LRT/MRT/bus) and travel-time to business districts not provided");
    }
    missingInfo.add("Maintenance fee / sinking fund per square foot not specified in project profile");

    return _SegmentCandidate(
      name: isNearTech ? "Young Tech & MNC Professionals" : "Young Working Professionals",
      description:
          "Ages 26–36, salaried professionals and engineers seeking high-convenience "
          "living with modern amenities close to employment corridors.",
      interestReason:
          "Proximity to major employment hubs in ${p.location}, modern lifestyle "
          "facilities, and easy highway connectivity reducing commute stress.",
      budgetCompatibility:
          "Entry price of RM${p.startingPrice.toStringAsFixed(0)} "
          "${p.startingPrice <= 500000 ? 'is well within' : p.startingPrice <= 700000 ? 'is accessible to' : 'stretches'} "
          "estimated monthly household income RM7,000–RM12,000 "
          "(mortgage ~RM${(p.startingPrice * 0.005).toStringAsFixed(0)}/month).",
      propertyPreferences:
          "${p.bedrooms}-bedroom units with high-speed internet, "
          "dedicated work-from-home space, EV chargers, and secure parcel lockers.",
      purchasePurpose: p.purpose.contains("Investment")
          ? "Own Stay & Future Capital Gain"
          : "Own Stay",
      potentialObjections: [
        "High monthly service/maintenance fees eroding disposable income",
        "Traffic congestion during peak shift hours near industrial zones",
        "Concern over developer oversupply in the ${p.location} corridor",
      ],
      recommendedMessages: [
        "Cut Your Daily Commute from ${p.location}: Live Where Modern Tech Meets Resort Living.",
        "Why Rent When You Can Own a ${p.bedrooms}-Bedroom Haven for under RM${(p.startingPrice * 0.005).toStringAsFixed(0)}/mo?",
        "Designed for Remote Workers & Executives: Co-Working Lounges & Sky Facilities Included.",
      ],
      recommendedChannels: [
        "Facebook Lead Ads (Tech employer interests, age 26-36)",
        "Instagram Reels (After-work amenities, modern interiors)",
        "LinkedIn Sponsored Content (Professionals in ${p.state})",
      ],
      suggestedCTA: "Download Early-Bird Tech Executive Brochure & Financial Eligibility Calculator",
      score: score.clamp(0, 93),
      reasoning:
          "The project positioning in ${p.location} (${p.state}) "
          "paired with an entry price of RM${p.startingPrice.toStringAsFixed(0)} "
          "${isNearTech ? 'and proximity to tech/industrial hubs ' : ''}"
          "aligns with the earning trajectory and lifestyle preferences of young professionals.",
      marketingAngle:
          "Position as the smart career move — Live where you work, play where you live. "
          "Emphasise commute time savings, modern co-working facilities, and wealth-building through ownership vs renting.",
      scoringFactors: factors,
      ageRange: "26–36",
      incomeRange: "RM7,000–RM12,000/month",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (26–36) and salary (RM7,000–RM12,000/mo) are modeled on entry price RM${p.startingPrice.toStringAsFixed(0)} assuming ~4.2% interest over 30 years with DSR < 40%. This is a strategic marketing hypothesis, not verified census or CRM data.",
    );
  }

  static _SegmentCandidate _evaluateFirstTimeBuyers(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 44;

    // Price factor
    if (p.startingPrice <= 400000) {
      score += 20;
      factors.add("+20 — Price <= RM400k ideal for first-time buyer government incentives");
      matchingChars.add("High-affordability entry price (RM${p.startingPrice.toStringAsFixed(0)}) qualifies for stamp duty waiver");
    } else if (p.startingPrice <= 500000) {
      score += 16;
      factors.add("+16 — Price <= RM500k within first-home stamp duty exemption range");
      matchingChars.add("Affordable price of RM${p.startingPrice.toStringAsFixed(0)} within national homeownership scheme tier");
    } else if (p.startingPrice <= 650000) {
      score += 8;
      factors.add("+8 — Price <= RM650k still accessible with dual-income couples");
      matchingChars.add("Entry price (RM${p.startingPrice.toStringAsFixed(0)}) achievable with combined couple income");
    } else {
      score -= 14;
      factors.add("-14 — Price above RM650k significantly exceeds first-time homebuyer budget comfort");
    }

    // Family-ready layout
    if (p.bedrooms >= 3) {
      score += 10;
      factors.add("+10 — ${p.bedrooms} bedrooms accommodate starting families");
      matchingChars.add("${p.bedrooms} bedrooms provide future-proof room for marriage and children");
    } else if (p.bedrooms == 2) {
      score += 6;
      factors.add("+6 — 2 bedrooms suitable for young couples");
      matchingChars.add("2-bedroom layout suitable for starting newlyweds");
    } else {
      score -= 8;
      factors.add("-8 — 1-bedroom/studio format inadequate for matrimonial homebuyer cohort");
    }

    // Safe environment indicators
    final safetyKeywords = ["security", "gated", "cctv", "guard", "24/7", "smart"];
    final hasSecurity = p.facilities
        .any((f) => safetyKeywords.any((k) => f.toLowerCase().contains(k)));
    if (hasSecurity) {
      score += 8;
      factors.add("+8 — Gated/secured environment appeals to first-time buyers");
      matchingChars.add("Gated security infrastructure provides safe environment for new owners");
    } else {
      score -= 6;
      factors.add("-6 — Project profile does not explicitly confirm 24/7 multi-tier security");
    }

    // Nearby schools, groceries
    final familyAmenities = ["school", "preschool", "groceries", "hospital", "clinic", "pharmacy"];
    final nearbyFamily = p.nearbyAmenities
        .where((a) => familyAmenities.any((k) => a.toLowerCase().contains(k)))
        .length;
    if (nearbyFamily >= 2) {
      score += 8;
      factors.add("+8 — $nearbyFamily nearby family-essential amenities (schools/medical)");
      matchingChars.add("Proximity to daily family necessities: $nearbyFamily amenities identified");
    } else if (nearbyFamily == 1) {
      score += 4;
      factors.add("+4 — 1 nearby family essential amenity identified");
    } else {
      score -= 4;
      factors.add("-4 — Limited nearby schools and daily grocery amenities documented");
    }

    // Missing information check
    missingInfo.add("Government first-home schemes (i-Miliki, PR1MA) or developer legal fee subsidies not confirmed in listing");
    if (!p.facilities.any((f) => f.toLowerCase().contains("car") || f.toLowerCase().contains("parking"))) {
      missingInfo.add("Number of allocated covered car park bays per unit not specified");
    }
    if (p.nearbyAmenities.isEmpty) {
      missingInfo.add("Proximity to childcare centres, clinics, and daily grocery markets unconfirmed");
    }

    return _SegmentCandidate(
      name: "First-time Homebuyers",
      description:
          "Young couples and newlyweds aged 25–34 seeking their first matrimonial home "
          "with accessible pricing, government stamp duty exemptions, and low initial downpayment.",
      interestReason:
          "Qualifies for national homeownership incentives (stamp duty exemptions), "
          "affordable downpayment packages, and versatile ${p.bedrooms}-bedroom layout suitable for starting a family.",
      budgetCompatibility:
          "${p.startingPrice <= 500000 ? 'High' : p.startingPrice <= 650000 ? 'Moderate' : 'Low'} Compatibility: "
          "Starting price of RM${p.startingPrice.toStringAsFixed(0)} "
          "${p.startingPrice <= 500000 ? 'is within comfortable reach' : 'requires careful budgeting'} "
          "for dual-income couples earning combined RM6,000+.",
      propertyPreferences:
          "Safe gated environment, 2+ carpark bays, proximity to "
          "groceries, pharmacies, and reputable preschools.",
      purchasePurpose: "Own Stay",
      potentialObjections: [
        "Concern about progressive interest payments during construction",
        "Loan rejection or margin of finance lower than 90%",
        "Strict household budget constraints during renovation period",
      ],
      recommendedMessages: [
        "Stop Paying Your Landlord Mortgage: Own Your Dream Home with 0% Downpayment!",
        "First-Time Buyer Privilege: Stamp Duty Exemption on Your First Home.",
        "Spacious ${p.bedrooms}-Bedroom Layout Designed for Your Growing Family in ${p.location}.",
      ],
      recommendedChannels: [
        "Meta Carousel Ads (Installment breakdown vs rent comparison)",
        "TikTok First-Home Guide Videos (EPF Account 2 withdrawal tips)",
        "Direct WhatsApp Consultations (Complimentary loan screening)",
      ],
      suggestedCTA: "Check Your Loan Pre-Approval & Unlock 1st-Home Zero Downpayment Package",
      score: score.clamp(0, 92),
      reasoning:
          "The unit configuration (${p.bedrooms} bedrooms, ${p.builtUpArea.toStringAsFixed(0)} sqft) "
          "offers practical living space at "
          "${p.startingPrice <= 500000 ? 'an ideal' : 'a viable'} entry bracket in ${p.state}.",
      marketingAngle:
          "Focus on overcoming the renting fear. Lead with monthly installment comparisons "
          "against current rental rates. Highlight government incentives and zero-downpayment packages.",
      scoringFactors: factors,
      ageRange: "25–34",
      incomeRange: "RM5,000–RM9,000/month (combined household)",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (25–34) and household income (RM5,000–RM9,000/mo) assume dual-earning couples qualifying under 40% net DSR thresholds for an entry price of RM${p.startingPrice.toStringAsFixed(0)}. This is a marketing targeting model, not verified applicant financial records.",
    );
  }

  static _SegmentCandidate _evaluateInvestors(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 40;

    // Investment purpose
    if (p.purpose.contains("Investment")) {
      score += 16;
      factors.add("+16 — Project explicitly marketed for investment purpose");
      matchingChars.add("Developer explicitly positions project for investment returns");
    } else {
      score -= 8;
      factors.add("-8 — Project purpose primarily designated for own-stay living");
    }

    // High-yield property types
    if (p.propertyType == "Condominium" ||
        p.propertyType == "Serviced Residence" ||
        p.propertyType == "Studio") {
      score += 10;
      factors.add("+10 — ${p.propertyType} has historically strong rental demand");
      matchingChars.add("High-tenant-affinity format: ${p.propertyType}");
    } else {
      score -= 6;
      factors.add("-6 — ${p.propertyType} format carries higher maintenance or lower tenant turnover");
    }

    // Location near industrial/commercial hubs
    final tenantHubs = [
      "industrial",
      "bkip",
      "ftz",
      "university",
      "hospital",
      "airport",
      "mall",
      "commercial"
    ];
    final nearTenantSource = p.nearbyAmenities
        .any((a) => tenantHubs.any((k) => a.toLowerCase().contains(k)));
    if (nearTenantSource) {
      score += 14;
      factors.add("+14 — Near industrial/commercial/educational hubs generating tenant demand");
      matchingChars.add("Adjacent tenant demand generator detected in nearby amenities");
    } else {
      score -= 8;
      factors.add("-8 — No major educational, commercial, or industrial tenant hubs documented nearby");
    }

    // Price-to-yield consideration
    if (p.startingPrice <= 600000) {
      score += 10;
      factors.add("+10 — Sub-RM600k entry enables attractive gross rental yield (est. 5-7%)");
      matchingChars.add("Competitive entry pricing (RM${p.startingPrice.toStringAsFixed(0)}) supports estimated 5-7% gross yield");
    } else if (p.startingPrice <= 900000) {
      score += 4;
      factors.add("+4 — Mid-range pricing offers moderate yield potential");
    } else {
      score -= 10;
      factors.add("-10 — High capital entry price compresses gross rental yields");
    }

    // Built-up area efficiency
    if (p.builtUpArea <= 1200 && p.builtUpArea >= 400) {
      score += 6;
      factors.add("+6 — Efficient ${p.builtUpArea.toStringAsFixed(0)} sqft layout minimises vacancy risk");
      matchingChars.add("Compact layout (${p.builtUpArea.toStringAsFixed(0)} sqft) minimizes vacancy periods");
    }

    // Missing information check
    missingInfo.add("Projected rental yield and estimated monthly maintenance fees per sqft not specified");
    missingInfo.add("Building management operator track record and Airbnb/tenancy guidelines not documented");
    if (p.maximumPrice <= p.startingPrice) {
      missingInfo.add("Upper-tier penthouse or dual-key pricing variations not provided in listing");
    }

    return _SegmentCandidate(
      name: "Property Investors & Rental Yield Seekers",
      description:
          "Experienced or semi-active property investors aged 35–55 seeking positive cash-flow, "
          "solid gross rental yield (5%-7%), and capital upside driven by regional expansion.",
      interestReason:
          "High tenant demand from incoming expatriates, engineers, medical staff, and contractors "
          "in ${p.location}. ${nearTenantSource ? 'Nearby industrial/commercial hubs create reliable tenant pools.' : 'Growing regional development drives future demand.'}",
      budgetCompatibility:
          "High: Investors typically hold available cash or refinancing equity for 10%-20% capital outlay. "
          "Entry at RM${p.startingPrice.toStringAsFixed(0)} is within portfolio allocation comfort.",
      propertyPreferences:
          "Dual-key capable or high-yield rental units, fully furnished developer packages, "
          "on-site building management, and concierge services.",
      purchasePurpose: "Investment",
      potentialObjections: [
        "Future tenant turnover rate and competition from nearby pipeline projects",
        "Rising bank interest rates impacting net rental yields",
        "Upkeep and wear-and-tear costs for tenanted properties",
      ],
      recommendedMessages: [
        "Projected 5.8% Gross Rental Yield in Fast-Growing ${p.location} Corridor.",
        "Turnkey Investment Package: Fully Furnished with Tenant Management Options.",
        "Ride the Expansion Wave of ${p.state} Industrial Masterplan with High-Yield Real Estate.",
      ],
      recommendedChannels: [
        "Google Search Ads (invest in ${p.location} property, best yield condo ${p.state})",
        "Email Newsletters to High-Net-Worth Investor Lists",
        "Property Investor Webinar & Exclusive VIP Preview Invitations",
      ],
      suggestedCTA: "Request Full 5-Year Rental Yield Projection & Capital Appreciation Report",
      score: score.clamp(0, 91),
      reasoning:
          "${p.purpose.contains('Investment') ? 'Explicitly positioned for investment.' : 'Property characteristics support investment viability.'} "
          "Proximity to ${nearTenantSource ? 'multinational/commercial zones' : 'growing regional infrastructure'} "
          "creates ${nearTenantSource ? 'reliable, recurring' : 'emerging'} tenant pools.",
      marketingAngle:
          "Lead with numbers: estimated rental yield, capital appreciation projections, and ROI timelines. "
          "Target existing property owners looking to expand their portfolio.",
      scoringFactors: factors,
      ageRange: "35–55",
      incomeRange: "RM15,000+/month or existing property equity",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (35–55) and income (RM15,000+/mo or equivalent equity) represent typical high-net-worth investor qualifications. Figures are analytical marketing estimates, not verified bank balances or tax records.",
    );
  }

  static _SegmentCandidate _evaluateUpgradingFamilies(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 42;

    // Family-sized layout
    if (p.bedrooms >= 4) {
      score += 18;
      factors.add("+18 — ${p.bedrooms} bedrooms ideal for upgrading families with children");
      matchingChars.add("Large ${p.bedrooms}-bedroom layout accommodates multi-child household");
    } else if (p.bedrooms >= 3) {
      score += 12;
      factors.add("+12 — ${p.bedrooms} bedrooms accommodate growing families");
      matchingChars.add("Practical ${p.bedrooms}-bedroom family configuration");
    } else {
      score -= 14;
      factors.add("-14 — Less than 3 bedrooms insufficient for family upgraders");
    }

    // Built-up area
    if (p.builtUpArea >= 1200) {
      score += 12;
      factors.add("+12 — ${p.builtUpArea.toStringAsFixed(0)} sqft provides generous family living space");
      matchingChars.add("Expansive ${p.builtUpArea.toStringAsFixed(0)} sqft built-up area");
    } else if (p.builtUpArea >= 900) {
      score += 6;
      factors.add("+6 — ${p.builtUpArea.toStringAsFixed(0)} sqft adequate for small families");
      matchingChars.add("Adequate ${p.builtUpArea.toStringAsFixed(0)} sqft space for nuclear family");
    } else {
      score -= 10;
      factors.add("-10 — Under 900 sqft too compact for family upgraders");
    }

    // Family amenities
    final familyFacilities = [
      "pool",
      "playground",
      "park",
      "children",
      "splash",
      "bbq",
      "garden",
      "sports",
      "court",
      "jogging"
    ];
    final familyCount = p.facilities
        .where((f) => familyFacilities.any((k) => f.toLowerCase().contains(k)))
        .length;
    if (familyCount >= 3) {
      score += 12;
      factors.add("+12 — $familyCount family-friendly facilities (pools/playgrounds/parks)");
      matchingChars.add("Rich child-friendly recreational amenities ($familyCount facilities)");
    } else if (familyCount >= 1) {
      score += 6;
      factors.add("+6 — $familyCount family recreation facilities available");
    } else {
      score -= 8;
      factors.add("-8 — No dedicated children play facilities or parks detected in amenities");
    }

    // Landed property bonus
    if (p.propertyType == "Terrace House" ||
        p.propertyType == "Semi-Detached" ||
        p.propertyType == "Bungalow" ||
        p.propertyType == "Townhouse") {
      score += 8;
      factors.add("+8 — ${p.propertyType} format preferred by upgrading families");
      matchingChars.add("Landed residential format: ${p.propertyType}");
    }

    // Missing information check
    missingInfo.add("Number of allocated side-by-side car park bays not specified");
    missingInfo.add("Proximity to primary/secondary schools and pediatric healthcare not fully documented");
    if (!p.facilities.any((f) => f.toLowerCase().contains("security") || f.toLowerCase().contains("guard"))) {
      missingInfo.add("Gated guarded security tier and visitor management system not detailed");
    }

    return _SegmentCandidate(
      name: "Upgrading Families",
      description:
          "Local families aged 35–50 living in older terrace houses or smaller apartments, "
          "wanting newer lifestyle facilities, 24/7 security, and modern recreational zones for children.",
      interestReason:
          "Children amenities, swimming pools, secured perimeter surveillance, "
          "and clean multi-tier security. ${p.builtUpArea >= 1000 ? 'Generous ${p.builtUpArea.toStringAsFixed(0)} sqft space for growing families.' : ''}",
      budgetCompatibility:
          "High: Often supported by the sale or refinancing of existing property. "
          "Price of RM${p.startingPrice.toStringAsFixed(0)} is achievable with existing equity.",
      propertyPreferences:
          "At least 3 bedrooms, covered carpark spaces, "
          "${p.propertyType.contains('Terrace') || p.propertyType.contains('Semi') ? 'landed garden space' : 'separate wet & dry kitchens'}, "
          "and quiet residential zoning.",
      purchasePurpose: "Own Stay",
      potentialObjections: [
        "Adjusting from landed living to strata/condo lifestyle",
        "Strata house rules regarding renovations and pet policies",
        "Adequacy of storage space for larger family belongings",
      ],
      recommendedMessages: [
        "Upgrade Your Family Lifestyle: Gated Security, Pools, and Endless Play Areas.",
        "Give Your Children the Childhood They Deserve in a Protected Community.",
        "Spacious ${p.bedrooms}-Bedroom Living with Premium Facilities in ${p.location}.",
      ],
      recommendedChannels: [
        "Facebook Community Groups & Geo-fenced Ads (15km radius)",
        "Local School & Weekend Mall Activation Booths",
        "Family-themed Instagram Content & Photo Contests",
      ],
      suggestedCTA: "Book a Private Weekend Family Showroom Tour with Refreshments",
      score: score.clamp(0, 92),
      reasoning:
          "Family-friendly ${p.bedrooms}-bedroom layout with ${p.builtUpArea.toStringAsFixed(0)} sqft "
          "${familyCount >= 2 ? 'and $familyCount recreation facilities ' : ''}"
          "fulfills parents desire for active, secure childhood recreation.",
      marketingAngle:
          "Appeal to parental aspirations — Give your children the neighbourhood they deserve. "
          "Show families enjoying facilities. Use emotional storytelling over data-driven pitches.",
      scoringFactors: factors,
      ageRange: "35–50",
      incomeRange: "RM10,000–RM20,000/month (household)",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (35–50) and household income (RM10,000–RM20,000/mo) assume prior property ownership and refinancing/sale equity. Model assumes family living requirements, not verified census records.",
    );
  }

  static _SegmentCandidate _evaluateRetirees(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 32;

    // Scenic/resort locations
    final scenicKeywords = [
      "george town",
      "gurney",
      "tanjung bungah",
      "batu ferringhi",
      "langkawi",
      "cameron",
      "genting",
      "port dickson",
      "desaru",
      "kota kinabalu"
    ];
    final isScenic = scenicKeywords.any((k) => p.location.toLowerCase().contains(k));
    if (isScenic) {
      score += 18;
      factors.add("+18 — Scenic/resort location attractive for retirement lifestyle");
      matchingChars.add("Tranquil scenic setting in ${p.location}");
    } else {
      score -= 4;
      factors.add("-4 — Urban/industrial location less conducive to tranquil retirement living");
    }

    // Premium property types
    if (p.propertyType == "Penthouse" ||
        p.propertyType == "Bungalow" ||
        p.propertyType == "Serviced Residence") {
      score += 10;
      factors.add("+10 — ${p.propertyType} format appeals to premium retiree market");
      matchingChars.add("Elevated serviced living format: ${p.propertyType}");
    }

    // Price bracket
    if (p.startingPrice >= 500000 && p.startingPrice <= 1500000) {
      score += 8;
      factors.add("+8 — Price range matches retiree savings and EPF withdrawal brackets");
      matchingChars.add("Pricing (RM${p.startingPrice.toStringAsFixed(0)}) aligns with typical EPF/downsizing capital");
    }

    // Health facilities nearby
    final healthKeywords = ["hospital", "clinic", "medical"];
    final nearHealth = p.nearbyAmenities
        .any((a) => healthKeywords.any((k) => a.toLowerCase().contains(k)));
    if (nearHealth) {
      score += 10;
      factors.add("+10 — Nearby medical facilities important for retirement planning");
      matchingChars.add("Convenient access to medical/healthcare facilities");
    } else {
      score -= 8;
      factors.add("-8 — No primary hospitals or healthcare centres documented within walking distance");
    }

    if (p.builtUpArea >= 800) {
      score += 4;
      factors.add("+4 — Adequate space for comfortable retirement living");
      matchingChars.add("Spacious single-level floor plan (${p.builtUpArea.toStringAsFixed(0)} sqft)");
    }

    // Missing information check
    missingInfo.add("Universal design accessibility features (step-free showers, wheelchair ramps, grab bar points) unconfirmed");
    missingInfo.add("Emergency call system or on-site nursing concierge presence not documented");
    if (!p.facilities.any((f) => f.toLowerCase().contains("lift") || f.toLowerCase().contains("elevator"))) {
      missingInfo.add("High-speed stretcher lift availability not specified in high-rise specs");
    }

    return _SegmentCandidate(
      name: "Retirees & Pre-retirement Planners",
      description:
          "Individuals and couples aged 50–65 planning their post-career living arrangement. "
          "Seeking comfortable, low-maintenance homes near healthcare and leisure amenities.",
      interestReason:
          "${isScenic ? 'Attractive scenic location in ${p.location}. ' : ''}"
          "${nearHealth ? 'Proximity to medical facilities for peace of mind. ' : ''}"
          "Modern managed facilities reduce home maintenance burden.",
      budgetCompatibility:
          "High: Funded through EPF withdrawals, savings, or downsizing existing property. "
          "RM${p.startingPrice.toStringAsFixed(0)} aligns with retirement portfolio allocation.",
      propertyPreferences:
          "Single-level or lift-accessible units, scenic views, "
          "low-maintenance finishes, and walking-distance medical facilities.",
      purchasePurpose: "Own Stay",
      potentialObjections: [
        "Concern about strata maintenance fees on fixed retirement income",
        "Accessibility features (wheelchair-friendly, grab bars) may need additions",
        "Distance from adult children and grandchildren",
      ],
      recommendedMessages: [
        "Your Golden Years Deserve a Golden View. Retire in ${p.location}.",
        "Low-Maintenance Luxury: Focus on Living, Not Upkeep.",
        "Minutes from ${p.state} Best Hospitals. Peace of Mind Included.",
      ],
      recommendedChannels: [
        "Facebook Ads (Age 50-65, interests: retirement planning, travel)",
        "Print media in community newsletters and retirement magazines",
        "EPF retirement planning seminar partnerships",
      ],
      suggestedCTA: "Schedule a Personalised Retirement Living Consultation & Property Viewing",
      score: score.clamp(0, 86),
      reasoning:
          "${isScenic ? 'Scenic location' : 'Location'} and managed lifestyle facilities "
          "${nearHealth ? 'with nearby healthcare access ' : ''}"
          "position this property as a viable retirement option.",
      marketingAngle:
          "Sell the lifestyle, not the property. Focus on the next chapter — freedom from "
          "maintenance, scenic living, healthcare proximity. Use aspirational retirement imagery.",
      scoringFactors: factors,
      ageRange: "50–65",
      incomeRange: "EPF savings / pension / existing property equity",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (50–65) assumes mature homeowners financing via EPF Account savings, pension annuities, or landed-property downsizing. This is an analytical persona, not verified census data.",
    );
  }

  static _SegmentCandidate _evaluateOutOfStateBuyers(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 42;

    // States with strong out-of-state appeal
    final attractiveStates = ["Penang", "Johor", "Melaka", "Sabah", "Sarawak", "Kedah"];
    if (attractiveStates.contains(p.state)) {
      score += 12;
      factors.add("+12 — ${p.state} has strong out-of-state/expat appeal");
      matchingChars.add("Host state (${p.state}) has recognized interstate lifestyle and retirement appeal");
    } else {
      score -= 6;
      factors.add("-6 — Location in ${p.state} typically relies heavily on localized intra-district buyers");
    }

    // Price advantage vs KL
    if (p.startingPrice <= 700000) {
      score += 10;
      factors.add("+10 — Significant price advantage over equivalent KL properties");
      matchingChars.add("Price point (RM${p.startingPrice.toStringAsFixed(0)}) provides significant value vs Klang Valley equivalents");
    } else {
      score -= 6;
      factors.add("-6 — Luxury price tier reduces capital flight arbitrage benefit vs KL properties");
    }

    // Tourism/lifestyle factors
    final lifestyleKeywords = [
      "beach",
      "sea",
      "hill",
      "resort",
      "heritage",
      "nature",
      "island",
      "airport",
      "highway"
    ];
    final lifestyleCount = p.nearbyAmenities
        .where((a) => lifestyleKeywords.any((k) => a.toLowerCase().contains(k)))
        .length;
    final facilityLifestyle = p.facilities
        .where((f) => lifestyleKeywords.any((k) => f.toLowerCase().contains(k)))
        .length;
    if (lifestyleCount + facilityLifestyle >= 2) {
      score += 8;
      factors.add("+8 — Lifestyle/scenic amenities attractive for relocation");
      matchingChars.add("Lifestyle and scenic environment (${lifestyleCount + facilityLifestyle} features)");
    }

    // Highway/airport connectivity
    final connectKeywords = ["highway", "bridge", "airport", "transit", "lrt", "mrt"];
    final hasConnect = p.nearbyAmenities
        .any((a) => connectKeywords.any((k) => a.toLowerCase().contains(k)));
    if (hasConnect) {
      score += 6;
      factors.add("+6 — Good highway/airport connectivity for out-of-state buyers");
      matchingChars.add("Interstate transit connectivity documented in nearby amenities");
    } else {
      score -= 4;
      factors.add("-4 — Direct expressway or airport access not explicitly documented");
    }

    // Missing information check
    missingInfo.add("Virtual 360 showroom tour and digital loan submission tools not linked to project");
    missingInfo.add("Local property management / absentee owner inspection services not specified");
    if (p.nearbyAmenities.isEmpty) {
      missingInfo.add("Distance to regional airports and expressways not confirmed in listing");
    }

    return _SegmentCandidate(
      name: "Out-of-State Relocators & Expatriates",
      description:
          "Buyers relocating from Klang Valley, other states, or abroad due to career postings, "
          "regional HQ transfers, or lifestyle/retirement plans in ${p.state}.",
      interestReason:
          "Significantly lower price-per-square-foot compared to Kuala Lumpur/Singapore, "
          "combined with renowned ${p.state} lifestyle, food culture, and coastal accessibility.",
      budgetCompatibility:
          "Very High: Accustomed to higher property price levels in capital cities. "
          "RM${p.startingPrice.toStringAsFixed(0)} represents strong value.",
      propertyPreferences:
          "Turnkey move-in condition, scenic views (sea, hill, or skyline), "
          "direct highway/airport connectivity, and international school proximity.",
      purchasePurpose: "Own Stay & Investment",
      potentialObjections: [
        "Unfamiliarity with local municipal amenities and sub-districts",
        "Distance from elderly family members in home states",
        "Concern about resale liquidity in a non-primary market",
      ],
      recommendedMessages: [
        "Relocating to ${p.state}? Experience Luxury Living at Half the KL Price Tag.",
        "Your Ideal Holiday Home & Lifestyle Sanctuary in Beautiful ${p.state}.",
        "Direct Highway Access: ${hasConnect ? 'Connected to major transit networks' : 'Minutes to Airport & Expressways'}.",
      ],
      recommendedChannels: [
        "Targeted Digital Campaigns (KL/Selangor IP addresses interested in ${p.state})",
        "YouTube Video Walkthroughs with Neighbourhood Drone Overviews",
        "Expat Relocation Forum Sponsorships & LinkedIn Ads",
      ],
      suggestedCTA: "Schedule a Virtual 360 Live Video Tour with an Expat Relocation Specialist",
      score: score.clamp(0, 88),
      reasoning:
          "${p.state} infrastructure projects and lifestyle appeal attract "
          "continuous professional talent migration. "
          "Price advantage of RM${p.startingPrice.toStringAsFixed(0)} vs KL equivalents is compelling.",
      marketingAngle:
          "Sell the destination, not just the property. Position ${p.state} as a lifestyle upgrade "
          "from congested KL living. Use drone footage, food culture, and work-life balance messaging.",
      scoringFactors: factors,
      ageRange: "30–50",
      incomeRange: "RM12,000+/month or existing KL/Singapore property equity",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (30–50) and income assume relocators with Klang Valley or Singapore financial benchmarks. Persona is a strategic outbound marketing hypothesis, not verified interstate migration statistics.",
    );
  }

  static _SegmentCandidate _evaluateRentalInvestors(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 38;

    // Student/worker rental demand
    final rentalDemandKeywords = [
      "university",
      "college",
      "hospital",
      "industrial",
      "ftz",
      "factory",
      "mall",
      "commercial"
    ];
    final nearRentalDemand = p.nearbyAmenities
        .where((a) => rentalDemandKeywords.any((k) => a.toLowerCase().contains(k)))
        .length;
    if (nearRentalDemand >= 2) {
      score += 18;
      factors.add("+18 — $nearRentalDemand nearby tenant demand generators (university/industrial/commercial)");
      matchingChars.add("High tenant pool: Proximity to $nearRentalDemand employment/education nodes");
    } else if (nearRentalDemand >= 1) {
      score += 10;
      factors.add("+10 — $nearRentalDemand nearby tenant demand source");
    } else {
      score -= 6;
      factors.add("-6 — Limited nearby tertiary institutions or multinational commercial employment hubs");
    }

    // Smaller, efficient units
    if (p.propertyType == "Studio" || (p.bedrooms <= 2 && p.builtUpArea <= 800)) {
      score += 12;
      factors.add("+12 — Compact unit format ideal for short-term/student rental market");
      matchingChars.add("Compact layout (${p.builtUpArea.toStringAsFixed(0)} sqft) optimized for short-term tenancy");
    }

    // Low entry price
    if (p.startingPrice <= 400000) {
      score += 14;
      factors.add("+14 — Sub-RM400k enables higher rental yield percentage");
      matchingChars.add("Sub-RM400k entry price expands gross rental yield margins");
    } else if (p.startingPrice <= 550000) {
      score += 8;
      factors.add("+8 — Moderate entry price supports acceptable yield");
    } else {
      score -= 8;
      factors.add("-8 — Entry price above RM550k reduces cash-on-cash yield for short-stay units");
    }

    // Tourism potential
    final tourismKeywords = ["beach", "heritage", "resort", "george town", "langkawi", "island"];
    final hasTourism = tourismKeywords.any((k) =>
        p.location.toLowerCase().contains(k) ||
        p.nearbyAmenities.any((a) => a.toLowerCase().contains(k)));
    if (hasTourism) {
      score += 10;
      factors.add("+10 — Tourism potential for short-term rental strategy");
      matchingChars.add("Tourist appeal in ${p.location} supports weekend/holiday occupancy");
    }

    // Missing information check
    missingInfo.add("Strata title Joint Management Body (JMB) rules regarding short-term hosting (Airbnb) not confirmed");
    missingInfo.add("Self-check-in smart digital locks and baggage drop facilities not listed");
    missingInfo.add("Local short-term rental licensing requirements in ${p.state} not specified");

    return _SegmentCandidate(
      name: "Short-term Rental & Airbnb Investors",
      description:
          "Digital-savvy investors aged 28–45 interested in short-term rental income through "
          "Airbnb, Booking.com, or platform-managed furnished units near tourist/commercial zones.",
      interestReason:
          "${hasTourism ? 'Tourism demand in ${p.location} supports short-term rental income. ' : ''}"
          "${nearRentalDemand >= 1 ? 'Nearby commercial/educational hubs provide long-term tenant fallback.' : ''}",
      budgetCompatibility:
          "Moderate to High: Entry price of RM${p.startingPrice.toStringAsFixed(0)} "
          "${p.startingPrice <= 400000 ? 'enables attractive short-term yield returns' : 'requires careful yield calculations'}.",
      propertyPreferences:
          "Fully furnished developer packages, WiFi-ready, stylish modern interiors, "
          "and flexible short-term tenancy building rules.",
      purchasePurpose: "Investment (Short-term Rental)",
      potentialObjections: [
        "Building management may restrict short-term rentals",
        "Platform commission fees (15-20%) eroding net income",
        "Seasonal fluctuation in tourism-driven occupancy rates",
      ],
      recommendedMessages: [
        "Turn Your Property Investment into Passive Income: Projected 8-12% Rental Yield.",
        "Designer Interiors Included: Move-in and List on Day One.",
        "${p.location} Growth = Your Rental Income Opportunity.",
      ],
      recommendedChannels: [
        "Instagram Reels (Showcasing furnished unit interiors and location aesthetics)",
        "YouTube Investor Case Study Videos",
        "Property Investment Facebook Groups & Telegram Channels",
      ],
      suggestedCTA: "Download Short-term Rental Yield Calculator & Furnished Package Brochure",
      score: score.clamp(0, 88),
      reasoning:
          "${hasTourism ? 'Tourism appeal' : 'Location dynamics'} and "
          "${nearRentalDemand >= 1 ? 'proximity to tenant demand generators' : 'regional growth'} "
          "support short-term rental viability at the RM${p.startingPrice.toStringAsFixed(0)} price point.",
      marketingAngle:
          "Lead with passive income potential and lifestyle investing. "
          "Show real rental listing mockups and nightly rate estimates for the area.",
      scoringFactors: factors,
      ageRange: "28–45",
      incomeRange: "RM10,000+/month or existing investment portfolio",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (28–45) and income assumptions model digitally-connected real estate operators. Yields are strategic simulation estimates, not guaranteed commercial returns.",
    );
  }

  static _SegmentCandidate _evaluateUndecidedSeekers(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 42;

    // High competition areas
    final highCompetition = [
      "batu kawan",
      "setia alam",
      "cyberjaya",
      "iskandar",
      "mont kiara",
      "bangsar",
      "cheras"
    ];
    final isHighComp = highCompetition.any((h) => p.location.toLowerCase().contains(h));
    if (isHighComp) {
      score += 12;
      factors.add("+12 — High-competition corridor (${p.location}) creates extensive comparison shopping");
      matchingChars.add("High-visibility launch in active development corridor (${p.location})");
    } else {
      score -= 4;
      factors.add("-4 — Non-cluster location experiences fewer comparison-shopping walk-ins");
    }

    if (p.startingPrice >= 350000 && p.startingPrice <= 800000) {
      score += 8;
      factors.add("+8 — Mid-range pricing bracket (RM${p.startingPrice.toStringAsFixed(0)}) attracts widespread portal browsing");
      matchingChars.add("Mainstream sweet-spot pricing attracts high exploratory web traffic");
    }

    if (p.status == "New Launch" || p.status == "Upcoming") {
      score += 6;
      factors.add("+6 — ${p.status} status generates strong early-phase curiosity");
      matchingChars.add("Project development phase: ${p.status}");
    }

    // Missing information check
    missingInfo.add("Project comparison matrix against neighbouring competitor developments not documented");
    missingInfo.add("Limited-time developer price guarantee or early-bird rebate terms not specified");
    if (p.description.length < 30) {
      missingInfo.add("Detailed project description narrative absent; unique differentiation points unclear");
    }

    return _SegmentCandidate(
      name: "Undecided Property Seekers",
      description:
          "Active browsers on property portals comparing 4–5 developments across ${p.state}, "
          "needing clear differentiation, special rebates, and risk-free holding terms.",
      interestReason:
          "Developer reputation (${p.developer}), transparent pricing, "
          "and limited-time package perks that reduce hesitation.",
      budgetCompatibility:
          "Variable: Requires consultative financing breakdown to determine optimal unit type.",
      propertyPreferences:
          "High value-for-money, low defect track record, strong completion track record, "
          "and competitive developer rebate packages.",
      purchasePurpose: "Own Stay & Investment",
      potentialObjections: [
        "Wanting to wait and see if prices drop further or interest rates decrease",
        "Comparison fatigue from visiting too many competing showrooms",
        "Analysis paralysis — unable to commit without side-by-side data",
      ],
      recommendedMessages: [
        "Don't Buy Any Property in ${p.location} Until You Compare Our Value Matrix!",
        "Limited Early-Bird Allotment: Lock In Developer Price Protection Guarantee.",
        "Free Side-by-Side Comparison: Why Smart Buyers Choose ${p.name}.",
      ],
      recommendedChannels: [
        "Google Display Network Retargeting (Website Visitors)",
        "Comparison Infographics on Facebook & WhatsApp",
        "Interactive Web Quiz: Which ${p.state} Home Matches Your Budget?",
      ],
      suggestedCTA: "Request Free Project Comparison Sheet & Exclusive Developer Rebate Voucher",
      score: score.clamp(0, 85),
      reasoning:
          "Captures top-of-funnel traffic that requires educational nurturing. "
          "${isHighComp ? 'High developer density in ${p.location} increases comparison behaviour. ' : ''}"
          "Conversion requires consultative selling approach.",
      marketingAngle:
          "Position as the smart shortcut — provide comparison tools, checklists, and transparent "
          "pricing that saves buyers research time. Convert through trust and education, not pressure.",
      scoringFactors: factors,
      ageRange: "25–50",
      incomeRange: "Variable (RM5,000–RM18,000/month)",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Broad age (25–50) and variable income assume top-of-funnel portal browsers evaluating multiple options across ${p.state}. Persona models behavioural comparison patterns, not registered buyer leads.",
    );
  }

  static _SegmentCandidate _evaluateDigitalNomads(ProjectModel p) {
    final factors = <String>[];
    final missingInfo = <String>[];
    final matchingChars = <String>[];
    double score = 30;

    // WiFi/co-working facilities
    final digitalKeywords = ["co-working", "wifi", "lounge", "smart", "internet"];
    final hasDigital = p.facilities
        .where((f) => digitalKeywords.any((k) => f.toLowerCase().contains(k)))
        .length;
    if (hasDigital >= 2) {
      score += 18;
      factors.add("+18 — $hasDigital digital-ready facilities (co-working/WiFi/smart home)");
      matchingChars.add("Remote-work friendly facilities ($hasDigital digital amenities detected)");
    } else if (hasDigital >= 1) {
      score += 10;
      factors.add("+10 — $hasDigital digital amenity available");
      matchingChars.add("1 remote-work lifestyle facility detected");
    } else {
      score -= 8;
      factors.add("-8 — No co-working lounge, high-speed WiFi, or smart amenities listed");
    }

    // Lifestyle location
    final lifestyleKeywords = [
      "george town",
      "langkawi",
      "penang",
      "melaka",
      "kota kinabalu",
      "kuching",
      "beach",
      "heritage"
    ];
    final isLifestyle = lifestyleKeywords.any((k) =>
        p.location.toLowerCase().contains(k) || p.state.toLowerCase().contains(k));
    if (isLifestyle) {
      score += 14;
      factors.add("+14 — ${p.state} lifestyle/cultural appeal for digital nomad community");
      matchingChars.add("Culturally vibrant lifestyle location in ${p.state}");
    } else {
      score -= 4;
      factors.add("-4 — Non-destination location lacks distinctive digital nomad lifestyle appeal");
    }

    if (p.startingPrice <= 500000) {
      score += 10;
      factors.add("+10 — Affordable entry for remote-working lifestyle investors");
      matchingChars.add("Accessible price (RM${p.startingPrice.toStringAsFixed(0)}) for international/remote base");
    }

    if (p.propertyType == "Studio" || p.bedrooms <= 2) {
      score += 6;
      factors.add("+6 — Compact layout fits digital nomad needs");
      matchingChars.add("Manageable unit size (${p.bedrooms} beds, ${p.builtUpArea.toStringAsFixed(0)} sqft)");
    }

    // Missing information check
    missingInfo.add("Broadband ISP infrastructure (fibre optic speed tier, backup power) unverified");
    missingInfo.add("Co-working space opening hours, meeting room booking, and guest policy not documented");
    missingInfo.add("DE Rantau nomad visa eligibility alignment not confirmed");

    return _SegmentCandidate(
      name: "Digital Nomads & Remote Workers",
      description:
          "Location-independent professionals aged 25–40 seeking a Malaysian base "
          "with strong internet, co-working facilities, and lifestyle amenities.",
      interestReason:
          "${isLifestyle ? 'Renowned ${p.state} lifestyle appeal. ' : ''}"
          "${hasDigital >= 1 ? 'On-site co-working and digital infrastructure. ' : ''}"
          "National initiatives such as DE Rantau support long-term remote worker residencies.",
      budgetCompatibility:
          "Moderate: Purchasing as a base rather than primary home. "
          "RM${p.startingPrice.toStringAsFixed(0)} is attractive vs Southeast Asian alternatives.",
      propertyPreferences:
          "Furnished units with high-speed fibre internet, standing desk space, "
          "cafe-style co-working lounges, and walkable food/lifestyle districts.",
      purchasePurpose: "Own Stay & Investment",
      potentialObjections: [
        "May prefer renting flexibility over ownership commitment",
        "Concerns about internet speed and reliability",
        "Visa and foreign ownership restrictions",
      ],
      recommendedMessages: [
        "Your Corner Office Has an Infinity Pool: Remote Work from ${p.location}.",
        "Work from Paradise: Co-Working Lounge, Sky Gym, and ${p.state} Street Food Downstairs.",
        "Own Your Remote Work Base in Southeast Asia from RM${p.startingPrice.toStringAsFixed(0)}.",
      ],
      recommendedChannels: [
        "Instagram/TikTok (Digital nomad lifestyle content)",
        "Nomad List & Remote Work Forums",
        "LinkedIn Targeted Ads (Remote-first company employees)",
      ],
      suggestedCTA: "Download Remote Worker Lifestyle Guide & Virtual Tour of Co-Working Amenities",
      score: score.clamp(0, 84),
      reasoning:
          "${hasDigital >= 1 ? 'Digital-ready facilities' : 'Location'} and "
          "${isLifestyle ? 'lifestyle appeal' : 'regional growth'} "
          "position this for the growing remote work property market.",
      marketingAngle:
          "Sell the lifestyle freedom narrative — Your office has a pool view. "
          "Show real co-working spaces and neighbourhood cafe culture. Target digital nomad communities.",
      scoringFactors: factors,
      ageRange: "25–40",
      incomeRange: "RM8,000–RM25,000/month (remote/freelance income)",
      missingInformation: missingInfo,
      matchingPropertyCharacteristics: matchingChars,
      demographicDisclaimer:
          "Hypothetical Persona Assumption: Age (25–40) assumes location-independent professionals. Persona models remote lifestyle work trends, not registered foreign work permit statistics.",
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Private: Content Generation Helpers
  // ───────────────────────────────────────────────────────────

  static String _generateFacebookPost(
    String name,
    String dev,
    String loc,
    String state,
    String price,
    int beds,
    String sqft,
    String segName,
    AudienceSegmentModel segment,
  ) {
    return "ATTENTION: $segName in ${loc.toUpperCase()}, ${state.toUpperCase()}!\n\n"
        "Introducing $name by $dev — designed with YOUR priorities in mind.\n\n"
        "Why This Property Fits You:\n"
        "Starting from only $price\n"
        "$beds Bedrooms & modern functional layout ($sqft sqft)\n"
        "Full resort-style amenities included\n"
        "${segment.interestReason.split('.').first}\n\n"
        "Exclusive Launch Package:\n"
        "• 0% Downpayment Option Available*\n"
        "• Free SPA & Legal Fees Subsidies\n"
        "• Limited early-bird pricing protection\n\n"
        "${segment.suggestedCallToAction}\n\n"
        "#MalaysianProperty #${state}Property #$segName #HomeOwnership";
  }

  static String _generateInstagramCaption(
    String name,
    String loc,
    String price,
    int beds,
    String sqft,
    String segName,
  ) {
    return "Finding your dream home in $loc just got easier. ✨\n\n"
        "Say hello to $name:\n"
        "🛋️ $beds Bedrooms | $sqft sqft of pure comfort\n"
        "🏊 Resort-grade sky amenities\n"
        "💰 From $price | Perfect for $segName\n\n"
        "Tag someone who needs to see this! 👇\n"
        "DM us \"FLOORPLAN\" or tap the link in bio.\n\n"
        "#${loc.replaceAll(' ', '')}Living #MalaysianHomes #DreamHome #PropTech";
  }

  static String _generateTikTokIdea(
    String name,
    String loc,
    String price,
    String segName,
    AudienceSegmentModel segment,
  ) {
    return "TIKTOK CONCEPT: POV: You are a $segName finding $name\n\n"
        "[00:00-00:03] HOOK:\n"
        "(Point at camera) \"If you are a $segName looking in $loc, WATCH THIS!\"\n\n"
        "[00:04-00:12] SHOWCASE:\n"
        "(Fast b-roll: showroom walkthrough, amenity drone shots, neighbourhood highlights)\n"
        "\"This brand-new development just opened starting at only $price!\"\n\n"
        "[00:13-00:22] VALUE:\n"
        "\"${segment.recommendedMarketingMessages.isNotEmpty ? segment.recommendedMarketingMessages.first.replaceAll('"', '') : 'Incredible value for the location.'}\"\n\n"
        "[00:23-00:30] CTA:\n"
        "\"Comment '${name.split(' ').first.toUpperCase()}' below or click the link in bio!\"";
  }

  static List<String> _generateHeadlines(
    String name,
    String loc,
    String price,
    String segName,
    AudienceSegmentModel segment,
  ) {
    return [
      "✨ $segName: $name from $price in $loc",
      "🏠 Stop Renting, Start Owning in $loc from $price",
      "💡 Why Smart $segName Are Choosing $name",
      "🎯 Exclusive: ${segment.suggestedCallToAction}",
      "📍 $loc Best-Kept Property Secret for $segName",
    ];
  }

  static List<String> _generateCTAs(
    String name,
    String segName,
    AudienceSegmentModel segment,
  ) {
    return [
      segment.suggestedCallToAction,
      "WhatsApp Us Now for Exclusive $segName Package",
      "Book Free Weekend Showroom Visit",
      "Download Complete Floor Plan & Price List",
      "Check Your Loan Eligibility in 2 Minutes",
    ];
  }

  // ───────────────────────────────────────────────────────────
  //  Private: Utility Helpers
  // ───────────────────────────────────────────────────────────

  static List<String> _getNeighbouringStates(String state) {
    const neighbours = {
      "Penang": ["Kedah", "Perak"],
      "Kedah": ["Penang", "Perak", "Perlis"],
      "Perlis": ["Kedah"],
      "Perak": ["Penang", "Kedah", "Selangor", "Pahang", "Kelantan"],
      "Selangor": ["Kuala Lumpur", "Perak", "Pahang", "Negeri Sembilan"],
      "Kuala Lumpur": ["Selangor"],
      "Putrajaya": ["Selangor"],
      "Negeri Sembilan": ["Selangor", "Melaka", "Pahang", "Johor"],
      "Melaka": ["Negeri Sembilan", "Johor"],
      "Johor": ["Melaka", "Negeri Sembilan", "Pahang"],
      "Pahang": ["Selangor", "Perak", "Kelantan", "Terengganu", "Negeri Sembilan", "Johor"],
      "Kelantan": ["Perak", "Pahang", "Terengganu"],
      "Terengganu": ["Kelantan", "Pahang"],
      "Sabah": ["Sarawak"],
      "Sarawak": ["Sabah"],
      "Labuan": ["Sabah"],
    };
    return neighbours[state] ?? [];
  }
}

/// Result of per-segment marketing content generation.
class SegmentMarketingContent {
  final String facebookPost;
  final String instagramCaption;
  final String tikTokIdea;
  final List<String> headlines;
  final List<String> callToActions;

  SegmentMarketingContent({
    required this.facebookPost,
    required this.instagramCaption,
    required this.tikTokIdea,
    required this.headlines,
    required this.callToActions,
  });
}

/// Internal candidate used during scoring before final model creation.
class _SegmentCandidate {
  final String name;
  final String description;
  final String interestReason;
  final String budgetCompatibility;
  final String propertyPreferences;
  final String purchasePurpose;
  final List<String> potentialObjections;
  final List<String> recommendedMessages;
  final List<String> recommendedChannels;
  final String suggestedCTA;
  final double score;
  final String reasoning;
  final String marketingAngle;
  final List<String> scoringFactors;
  final String ageRange;
  final String incomeRange;
  final List<String> missingInformation;
  final List<String> matchingPropertyCharacteristics;
  final String demographicDisclaimer;

  _SegmentCandidate({
    required this.name,
    required this.description,
    required this.interestReason,
    required this.budgetCompatibility,
    required this.propertyPreferences,
    required this.purchasePurpose,
    required this.potentialObjections,
    required this.recommendedMessages,
    required this.recommendedChannels,
    required this.suggestedCTA,
    required this.score,
    required this.reasoning,
    required this.marketingAngle,
    required this.scoringFactors,
    required this.ageRange,
    required this.incomeRange,
    this.missingInformation = const [],
    this.matchingPropertyCharacteristics = const [],
    this.demographicDisclaimer = '',
  });

  AudienceSegmentModel toModel({
    required int rank,
    required String projectId,
    required String ownerId,
  }) {
    return AudienceSegmentModel(
      projectId: projectId,
      ownerId: ownerId,
      name: name,
      description: description,
      interestReason: interestReason,
      budgetCompatibility: budgetCompatibility,
      propertyPreferences: propertyPreferences,
      purchasePurpose: purchasePurpose,
      potentialObjections: potentialObjections,
      recommendedMarketingMessages: recommendedMessages,
      recommendedChannels: recommendedChannels,
      suggestedCallToAction: suggestedCTA,
      suitabilityScore: score,
      rank: rank,
      reasoning: reasoning,
      marketingAngle: marketingAngle,
      scoringFactors: scoringFactors,
      ageRange: ageRange,
      incomeRange: incomeRange,
      missingInformation: missingInformation,
      matchingPropertyCharacteristics: matchingPropertyCharacteristics,
      demographicDisclaimer: demographicDisclaimer,
    );
  }
}
