import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/services/matching_service.dart';
import 'package:propmatch_ai/services/ai_service.dart';
import 'package:propmatch_ai/services/demo_data_service.dart';

void main() {
  group('AI Buyer Matching Engine Tests', () {
    final project = ProjectModel(
      ownerId: 'agent-1',
      name: 'EXSIM Demo Residence',
      developer: 'EXSIM',
      location: 'Batu Kawan',
      state: 'Penang',
      propertyType: 'Condominium',
      startingPrice: 450000,
      maximumPrice: 580000,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 950,
      description: 'Modern condo near BKIP',
      purpose: 'Own Stay & Investment',
    );

    test('High compatibility match calculates correct weights', () {
      final buyer = BuyerModel(
        ownerId: 'agent-1',
        name: 'Ahmad Ismail',
        budgetMin: 400000,
        budgetMax: 550000,
        preferredLocation: 'Batu Kawan',
        preferredState: 'Penang',
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        leadSource: 'Facebook Ads',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: project);

      expect(match.overallMatchPercentage, greaterThanOrEqualTo(80.0));
      expect(match.budgetScore, equals(25.0));
      expect(match.locationScore, equals(25.0));
      expect(match.propertyTypeScore, equals(20.0));
      expect(match.purposeScore, equals(15.0));
      expect(match.matchingFactors.isNotEmpty, isTrue);
    });

    test('Budget shortfall and interstate mismatch reduce score and generate concerns', () {
      final buyer = BuyerModel(
        ownerId: 'agent-1',
        name: 'John Doe',
        budgetMin: 200000,
        budgetMax: 300000, // Insufficient for 450k
        preferredLocation: 'Johor Bahru',
        preferredState: 'Johor',
        propertyType: 'Terrace House',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Just exploring',
        leadSource: 'Portal',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: project);

      expect(match.overallMatchPercentage, lessThan(50.0));
      expect(match.potentialConcerns.isNotEmpty, isTrue);
    });
  });

  group('Demo Data & AI Audience Discovery Tests', () {
    test('100 Demo buyers are generated with isDemo flag', () {
      final buyers = DemoDataService.generate100DemoBuyers();
      expect(buyers.length, equals(100));
      for (final b in buyers) {
        expect(b.isDemo, isTrue);
        expect(b.name.isNotEmpty, isTrue);
      }
    });

    test('AI Audience Discovery generates ranked segments with reasoning', () {
      final project = DemoDataService.getInitialProjects().first;
      final segments = AIService.discoverAudienceSegments(project);

      expect(segments.length, greaterThanOrEqualTo(5));
      expect(segments.first.suitabilityScore, greaterThan(70.0));
      expect(segments.first.reasoning.isNotEmpty, isTrue);
      expect(segments.first.potentialObjections.isNotEmpty, isTrue);
    });
  });
}
