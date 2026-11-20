import '../models/buyer_model.dart';
import '../models/project_model.dart';
import '../models/match_model.dart';

class MatchingService {
  /// Matches a single buyer with a single project using the 5 weighted dimensions.
  /// Weights:
  /// - Budget compatibility: 25%
  /// - Location compatibility: 25%
  /// - Property type: 20%
  /// - Purchase purpose: 15%
  /// - Buying timeline: 15%
  static MatchModel calculateMatch({
    required BuyerModel buyer,
    required ProjectModel project,
  }) {
    final factors = <String>[];
    final concerns = <String>[];
    final missingInfo = <String>[];

    // 1. Budget Compatibility (Weight: 25%)
    double budgetScore = 0.0;
    if (buyer.budgetMin <= 0 && buyer.budgetMax <= 0) {
      missingInfo.add('Buyer has not specified a defined budget range.');
      budgetScore = 10.0; // Partial score, never 100% for unknown
    } else {
      final projectPrice = project.startingPrice;
      if (buyer.budgetMax >= projectPrice && buyer.budgetMin <= project.maximumPrice) {
        // Direct overlap
        budgetScore = 25.0;
        factors.add('Budget Match: Project starting price RM${projectPrice.toStringAsFixed(0)} is comfortably within buyer’s budget (RM${buyer.budgetMin.toStringAsFixed(0)} - RM${buyer.budgetMax.toStringAsFixed(0)}).');
      } else if (buyer.budgetMax >= projectPrice * 0.90) {
        // Close within 10%
        budgetScore = 18.0;
        concerns.add('Budget Stretch: Project starting price RM${projectPrice.toStringAsFixed(0)} is slightly above buyer max budget RM${buyer.budgetMax.toStringAsFixed(0)} (~10% gap).');
      } else if (buyer.budgetMax < projectPrice) {
        budgetScore = 5.0;
        concerns.add('Budget Shortfall: Project starting price RM${projectPrice.toStringAsFixed(0)} exceeds buyer ceiling RM${buyer.budgetMax.toStringAsFixed(0)} significantly.');
      } else {
        budgetScore = 20.0;
        factors.add('High Budget Capacity: Buyer ceiling exceeds maximum project tier.');
      }
    }

    // 2. Location Compatibility (Weight: 25%)
    double locationScore = 0.0;
    final buyerLoc = buyer.preferredLocation.toLowerCase().trim();
    final buyerState = buyer.preferredState.toLowerCase().trim();
    final projLoc = project.location.toLowerCase().trim();
    final projState = project.state.toLowerCase().trim();

    if (buyerLoc.isEmpty && buyerState.isEmpty) {
      missingInfo.add('Buyer location preferences are not documented.');
      locationScore = 8.0; // Partial score for unknown
    } else if (projLoc.contains(buyerLoc) || buyerLoc.contains(projLoc)) {
      locationScore = 25.0;
      factors.add('Exact Location Match: Project is located in ${project.location}, exactly matching buyer’s preferred area.');
    } else if (projState == buyerState) {
      locationScore = 18.0;
      factors.add('State Match: Same state (${project.state}), though slightly different neighbourhood.');
      concerns.add('Distance consideration: Buyer preferred ${buyer.preferredLocation}, while project is in ${project.location}.');
    } else {
      locationScore = 6.0;
      concerns.add('Inter-State Mismatch: Project is in ${project.state}, but buyer prefers ${buyer.preferredState}.');
    }

    // 3. Property Type Compatibility (Weight: 20%)
    double propertyTypeScore = 0.0;
    final buyerType = buyer.propertyType.toLowerCase();
    final projType = project.propertyType.toLowerCase();

    if (buyerType.isEmpty) {
      missingInfo.add('Preferred property type is unspecified.');
      propertyTypeScore = 7.0;
    } else if (buyerType == projType || projType.contains(buyerType) || buyerType.contains(projType)) {
      propertyTypeScore = 20.0;
      factors.add('Property Type Match: Both seek ${project.propertyType}.');
    } else if ((buyerType.contains('condo') || buyerType.contains('apartment') || buyerType.contains('serviced')) &&
        (projType.contains('condo') || projType.contains('apartment') || projType.contains('serviced'))) {
      propertyTypeScore = 16.0;
      factors.add('High-rise Category Match: ${project.propertyType} aligns with buyer high-rise preferences.');
    } else {
      propertyTypeScore = 4.0;
      concerns.add('Type Divergence: Buyer prefers ${buyer.propertyType}, while project offers ${project.propertyType}.');
    }

    // 4. Purchase Purpose (Weight: 15%)
    double purposeScore = 0.0;
    final buyerPurpose = buyer.purchasePurpose.toLowerCase();
    final projPurpose = project.purpose.toLowerCase();

    if (buyerPurpose.isEmpty) {
      missingInfo.add('Buyer purchase purpose (Own Stay vs Investment) not confirmed.');
      purposeScore = 5.0;
    } else if (projPurpose.contains(buyerPurpose) || buyerPurpose.contains(projPurpose) || projPurpose.contains('both') || projPurpose.contains('&')) {
      purposeScore = 15.0;
      factors.add('Purpose Alignment: Project suitability (${project.purpose}) fully accommodates buyer objective (${buyer.purchasePurpose}).');
    } else {
      purposeScore = 6.0;
      concerns.add('Purpose Gap: Project is optimized for ${project.purpose}, whereas buyer prioritizes ${buyer.purchasePurpose}.');
    }

    // 5. Buying Timeline (Weight: 15%)
    double timelineScore = 0.0;
    final timeline = buyer.buyingTimeline.toLowerCase();

    if (timeline.contains('immediately')) {
      timelineScore = project.status == 'Completed' ? 15.0 : 10.0;
      if (project.status != 'Completed') {
        concerns.add('Construction Horizon: Buyer is ready immediately, but project status is ${project.status}.');
      } else {
        factors.add('Ready Timeline: Immediate move-in ready aligns with buyer urgent timeline.');
      }
    } else if (timeline.contains('3 months') || timeline.contains('6 months')) {
      timelineScore = 14.0;
      factors.add('Optimal Sales Window: Active purchasing window within 3–6 months.');
    } else if (timeline.contains('1 year')) {
      timelineScore = 11.0;
      factors.add('Pipeline Lead: Good candidate for ongoing construction stage conversion.');
    } else {
      timelineScore = 6.0;
      missingInfo.add('Buyer is currently exploring without firm procurement date.');
    }

    final totalScore = budgetScore + locationScore + propertyTypeScore + purposeScore + timelineScore;
    final clampedScore = totalScore.clamp(0.0, 100.0);

    // Classification
    String classification;
    if (clampedScore >= 85) {
      classification = 'Excellent Match';
    } else if (clampedScore >= 70) {
      classification = 'Good Match';
    } else if (clampedScore >= 50) {
      classification = 'Moderate Match';
    } else {
      classification = 'Low Match';
    }

    // Confidence Level
    String confidence;
    if (missingInfo.length >= 2) {
      confidence = 'Low';
    } else if (missingInfo.length == 1) {
      confidence = 'Medium';
    } else {
      confidence = 'High';
    }

    // Recommended Action
    String nextAction;
    if (clampedScore >= 85) {
      nextAction = 'Prioritize for private showroom preview and furnish layout options.';
    } else if (clampedScore >= 70) {
      nextAction = 'Engage buyer to review specific unit layouts and verify bank loan pre-qualification.';
    } else if (clampedScore >= 50) {
      nextAction = 'Clarify buyer criteria (specifically ${concerns.isNotEmpty ? concerns.first : 'budget and location'}) before proposing.';
    } else {
      nextAction = 'Retain in general nurture pipeline; project not suitable at present.';
    }

    final objections = <String>[];
    if (budgetScore < 20) {
      objections.add('Price point and monthly repayment commitment.');
    }
    if (locationScore < 20) {
      objections.add('Commute distance to primary workplace or family hub.');
    }
    if (propertyTypeScore < 18) {
      objections.add('Property format or density differs from initial criteria.');
    }

    final fallbackOpener =
        'Hi ${buyer.name}, I noticed ${project.name} in ${project.location} fits several of your preferences for a ${project.propertyType}. Would you like me to share the digital brochure?';

    final narrativeExplanation =
        '$classification (${clampedScore.round()}% compatibility). ${factors.take(2).join(' ')} ${concerns.isNotEmpty ? 'Consideration: ${concerns.first}' : ''}'
            .trim();

    return MatchModel(
      ownerId: project.ownerId,
      buyerId: buyer.id,
      projectId: project.id,
      buyerName: buyer.name,
      projectName: project.name,
      isDemoBuyer: buyer.isDemo,
      overallMatchPercentage: clampedScore,
      budgetScore: budgetScore,
      locationScore: locationScore,
      propertyTypeScore: propertyTypeScore,
      purposeScore: purposeScore,
      timelineScore: timelineScore,
      explanation: narrativeExplanation,
      aiExplanation: narrativeExplanation,
      matchingFactors: factors,
      missingInformation: missingInfo,
      potentialConcerns: concerns,
      mismatchedCriteria: concerns,
      potentialObjections: objections,
      confidenceLevel: confidence,
      matchClassification: classification,
      recommendedNextAction: nextAction,
      suggestedConversationOpener: fallbackOpener,
      calculationSource: 'Rule-based Deterministic Engine',
    );
  }

  /// Calculates matches across a list of buyers for a specific project
  static List<MatchModel> matchBuyersWithProject({
    required List<BuyerModel> buyers,
    required ProjectModel project,
  }) {
    final matches = buyers
        .map((buyer) => calculateMatch(buyer: buyer, project: project))
        .toList();

    // Sort descending by match percentage
    matches.sort((a, b) => b.overallMatchPercentage.compareTo(a.overallMatchPercentage));
    return matches;
  }
}
