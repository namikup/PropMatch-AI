import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/screens/matching/matching_screen.dart';
import 'package:propmatch_ai/services/matching_service.dart';

void main() {
  final sampleProject = ProjectModel(
    id: 'proj_mont_kiara',
    ownerId: 'test_agent',
    name: 'The Horizon Residences',
    developer: 'Horizon Sdn Bhd',
    location: 'Mont Kiara',
    state: 'Kuala Lumpur',
    propertyType: 'Condominium',
    startingPrice: 850000,
    maximumPrice: 1200000,
    bedrooms: 3,
    bathrooms: 2,
    builtUpArea: 1250,
    facilities: ['Pool', 'Gym', 'EV Charging'],
    nearbyAmenities: ['Publika', 'Garden International School'],
    description: 'Exclusive luxury high-rise condominium in Mont Kiara.',
    purpose: 'Own Stay',
    status: 'Completed',
  );

  group('Phase 3.3B: MatchingService Deterministic Scoring Engine', () {
    test('Calculates Excellent Match (85-100) with High confidence when all criteria align', () {
      final buyer = BuyerModel(
        id: 'buyer_perfect',
        ownerId: 'test_agent',
        name: 'Datuk Tan Sri Lee',
        phone: '012-3456789',
        preferredLocation: 'Mont Kiara',
        preferredState: 'Kuala Lumpur',
        propertyType: 'Condominium',
        budgetMin: 800000,
        budgetMax: 1300000,
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Immediately',
        leadSource: 'Direct Referral',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: sampleProject);

      expect(match.overallMatchPercentage, equals(100.0));
      expect(match.matchClassification, equals('Excellent Match'));
      expect(match.confidenceLevel, equals('High'));
      expect(match.isExcellentMatch, isTrue);
      expect(match.budgetScore, equals(25.0));
      expect(match.locationScore, equals(25.0));
      expect(match.propertyTypeScore, equals(20.0));
      expect(match.purposeScore, equals(15.0));
      expect(match.timelineScore, equals(15.0));
      expect(match.missingInformation, isEmpty);
      expect(match.mismatchedCriteria, isEmpty);
      expect(match.recommendedNextAction, contains('Prioritize'));
    });

    test('Calculates Good Match (70-84) with high-rise category alignment', () {
      final buyer = BuyerModel(
        id: 'buyer_good',
        ownerId: 'test_agent',
        name: 'Sarah Connor',
        phone: '013-4567890',
        preferredLocation: 'Bangsar',
        preferredState: 'Kuala Lumpur',
        propertyType: 'Serviced Apartment',
        budgetMin: 800000,
        budgetMax: 800000, // starting price 850k * 0.9 = 765k => 18 points
        purchasePurpose: 'Own Stay',
        buyingTimeline: '3 to 6 months',
        leadSource: 'Facebook Ad',
      );

      final matchGood = MatchingService.calculateMatch(buyer: buyer, project: sampleProject);

      expect(matchGood.overallMatchPercentage, inInclusiveRange(70.0, 84.0));
      expect(matchGood.matchClassification, equals('Good Match'));
      expect(matchGood.isGoodMatch, isTrue);
      expect(matchGood.confidenceLevel, equals('High'));
    });

    test('Calculates Moderate Match (50-69) when inter-state or budget gaps exist', () {
      final buyer = BuyerModel(
        id: 'buyer_moderate',
        ownerId: 'test_agent',
        name: 'Ahmad Faiz',
        phone: '014-5678901',
        preferredLocation: 'Petaling Jaya',
        preferredState: 'Selangor', // Different state (6 pts)
        propertyType: 'Condominium', // 20 pts
        budgetMin: 700000,
        budgetMax: 780000, // Stretch within 10% (18 pts)
        purchasePurpose: 'Own Stay', // 15 pts
        buyingTimeline: 'Exploring', // 6 pts
        leadSource: 'Portal Enquiry',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: sampleProject);

      // Score: 18 + 6 + 20 + 15 + 6 = 65 (Moderate Match)
      expect(match.overallMatchPercentage, equals(65.0));
      expect(match.matchClassification, equals('Moderate Match'));
      expect(match.isModerateMatch, isTrue);
    });

    test('Calculates Low Match (<50) when major shortfalls and type divergence exist', () {
      final buyer = BuyerModel(
        id: 'buyer_low',
        ownerId: 'test_agent',
        name: 'Chong Wei',
        phone: '016-7890123',
        preferredLocation: 'Johor Bahru',
        preferredState: 'Johor', // 6 pts
        propertyType: 'Landed Terrace', // 4 pts
        budgetMin: 200000,
        budgetMax: 350000, // Shortfall (5 pts)
        purchasePurpose: 'Investment', // 6 pts
        buyingTimeline: 'Exploring', // 6 pts
        leadSource: 'Walk-in',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: sampleProject);

      // Score: 5 + 6 + 4 + 6 + 6 = 27 (Low Match)
      expect(match.overallMatchPercentage, lessThan(50.0));
      expect(match.matchClassification, equals('Low Match'));
      expect(match.isLowMatch, isTrue);
      expect(match.mismatchedCriteria.length, greaterThanOrEqualTo(2));
    });

    test('Reduces confidence to Low and penalizes missing profile attributes', () {
      final buyer = BuyerModel(
        id: 'buyer_missing',
        ownerId: 'test_agent',
        name: 'Anonymous Lead',
        phone: '017-0000000',
        preferredLocation: '', // Missing
        preferredState: '', // Missing
        propertyType: '', // Missing
        budgetMin: 0, // Missing
        budgetMax: 0,
        purchasePurpose: '', // Missing
        buyingTimeline: '', // Missing
        leadSource: 'Unknown',
      );

      final match = MatchingService.calculateMatch(buyer: buyer, project: sampleProject);

      expect(match.missingInformation.length, greaterThanOrEqualTo(3));
      expect(match.confidenceLevel, equals('Low'));
      expect(match.overallMatchPercentage, lessThan(50.0));
    });
  });

  group('Phase 3.3B: AppStateProvider Buyer Matching State Management', () {
    test('runBuyerMatching calculates matches, caches per project, and updates stats', () async {
      final provider = AppStateProvider();
      await provider.addProject(sampleProject);
      provider.selectProject(sampleProject);

      expect(provider.matches, isEmpty);

      // Execute matching
      await provider.runBuyerMatching(sampleProject);

      expect(provider.matches, isNotEmpty);
      expect(provider.totalEvaluatedMatches, greaterThan(0));
      expect(provider.averageMatchScore, greaterThan(0.0));
      expect(provider.selectedMatch, isNotNull);

      // Test filter cohorts
      provider.setMatchFilter('Excellent Match');
      expect(provider.selectedMatchFilter, equals('Excellent Match'));
      for (final m in provider.filteredMatches) {
        expect(m.isExcellentMatch, isTrue);
      }

      provider.setMatchFilter('All');
      expect(provider.filteredMatches.length, equals(provider.matches.length));

      // Test sorting
      provider.setMatchSortOrder('score');
      final sortedByScore = provider.filteredMatches;
      for (int i = 0; i < sortedByScore.length - 1; i++) {
        expect(
          sortedByScore[i].overallMatchPercentage,
          greaterThanOrEqualTo(sortedByScore[i + 1].overallMatchPercentage),
        );
      }
    });

    test('selectProject restores cached matches seamlessly', () async {
      final provider = AppStateProvider();
      await provider.addProject(sampleProject);

      final secondProject = sampleProject.copyWith(
        id: 'proj_bayan_lepas',
        name: 'The Waterfront Bayan Lepas',
        location: 'Bayan Lepas',
        state: 'Penang',
      );
      await provider.addProject(secondProject);

      provider.selectProject(sampleProject);
      await provider.runBuyerMatching(sampleProject);
      final countProject1 = provider.matches.length;
      expect(countProject1, greaterThan(0));

      // Switch to project 2
      provider.selectProject(secondProject);
      expect(provider.matches, isEmpty); // Not run yet for project 2

      // Switch back to project 1
      provider.selectProject(sampleProject);
      expect(provider.matches.length, equals(countProject1)); // Restored from cache!
    });
  });

  group('Phase 3.3B: MatchingScreen Widget Tests', () {
    testWidgets('Renders MatchingScreen controls, header, and overview stats', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = AppStateProvider();
      await provider.addProject(sampleProject);
      provider.selectProject(sampleProject);
      await provider.runBuyerMatching(sampleProject);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AppStateProvider>.value(
              value: provider,
              child: const MatchingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and active project
      expect(find.text('Intelligent Buyer Matching Engine'), findsOneWidget);
      expect(find.textContaining('The Horizon Residences'), findsWidgets);

      // Verify overview cards
      expect(find.text('Total Evaluated'), findsOneWidget);
      expect(find.text('Average Match'), findsOneWidget);

      // Verify candidate list and inspector
      expect(find.text('Weighted Matching Dimensions'), findsOneWidget);
      expect(find.textContaining('Budget Compatibility (Max 25%)'), findsOneWidget);
      expect(find.textContaining('Location Compatibility (Max 25%)'), findsOneWidget);

      // Verify agent action buttons
      expect(find.text('Add Follow-up'), findsWidgets);
      expect(find.textContaining('Lead'), findsWidgets);
    });
  });
}
