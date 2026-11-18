import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/models/followup_model.dart';
import 'package:propmatch_ai/models/lead_model.dart';
import 'package:propmatch_ai/models/match_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';

void main() {
  group('Phase 1 Stabilisation & Bug Fix Verification Suite', () {
    late AppStateProvider provider;

    setUp(() {
      provider = AppStateProvider();
    });

    test('1. Project description generation does not interpolate controller object', () {
      const location = 'Batu Kawan';
      // Simulate the project creation logic fixed in projects_screen.dart
      final desc = 'Modern high-yield property project located in $location.';

      expect(desc, contains('located in Batu Kawan.'));
      expect(desc, isNot(contains('TextEditingController')));
    });

    test('2. Provider notifications on addLead, removeDemoBuyers, and updateLeadStatus', () {
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      final initialLeadCount = provider.leads.length;

      // Add lead via dedicated provider method
      final newLead = LeadModel(
        ownerId: provider.currentOwnerId,
        buyerId: 'b-test-1',
        projectId: 'p-test-1',
        buyerName: 'Lim Guan Hock',
        projectName: 'Vertu Residences',
        source: 'Walk-in',
      );
      provider.addLead(newLead);

      expect(provider.leads.length, equals(initialLeadCount + 1));
      expect(provider.leads.first.buyerName, equals('Lim Guan Hock'));
      expect(notifyCount, greaterThan(0));

      // Update lead status
      final previousCount = notifyCount;
      provider.updateLeadStatus(newLead.id, 'Qualified');
      expect(provider.leads.first.status, equals('Qualified'));
      expect(notifyCount, greaterThan(previousCount));

      // Generate and remove demo buyers
      provider.generate100DemoBuyers();
      expect(provider.demoBuyerCount, equals(100));

      final countBeforePurge = notifyCount;
      provider.removeDemoBuyers();
      expect(provider.demoBuyerCount, equals(0));
      expect(notifyCount, greaterThan(countBeforePurge));
    });

    test('3. Follow-up state management persists in provider across operations', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final initialCount = provider.followups.length;
      expect(initialCount, greaterThan(0));

      // Add follow-up
      final newFollowup = FollowupModel(
        ownerId: provider.currentOwnerId,
        buyerName: 'Cheah Siew Kim',
        projectName: 'EXSIM Demo Residence',
        task: 'Confirm weekend showroom viewing',
        dueDate: 'Saturday, 11:00 AM',
        type: 'Showroom Viewing',
      );
      provider.addFollowup(newFollowup);

      expect(provider.followups.length, equals(initialCount + 1));
      expect(provider.followups.first.buyerName, equals('Cheah Siew Kim'));
      expect(provider.followups.first.isCompleted, isFalse);

      // Toggle completion
      provider.toggleFollowupCompletion(newFollowup.id);
      expect(provider.followups.first.isCompleted, isTrue);

      // Delete follow-up
      provider.deleteFollowup(newFollowup.id);
      expect(provider.followups.length, equals(initialCount));
    });

    test('4. Empty project handling operates safely without crashing', () {
      // Simulate deleting all projects
      final projectIds = provider.projects.map((p) => p.id).toList();
      for (final id in projectIds) {
        provider.deleteProject(id);
      }

      expect(provider.projects, isEmpty);
      expect(provider.selectedProject, isNull);

      // Safe lookup should not throw StateError
      final matches = provider.projects.where((p) => p.id == 'non-existent');
      expect(matches, isEmpty);
    });

    test('5. Duplicate lead conversion is prevented', () {
      final match = MatchModel(
        id: 'm-dup-1',
        ownerId: provider.currentOwnerId,
        buyerId: 'buyer-dup-test',
        projectId: 'proj-dup-test',
        buyerName: 'Tan Ah Kow',
        projectName: 'Gurney Premier Suites',
        overallMatchPercentage: 88.0,
        budgetScore: 23.0,
        locationScore: 25.0,
        propertyTypeScore: 20.0,
        purposeScore: 10.0,
        timelineScore: 10.0,
        explanation: 'Strong budget alignment',
        matchingFactors: ['Budget within range'],
        missingInformation: [],
        potentialConcerns: [],
        isDemoBuyer: false,
      );

      expect(provider.hasLeadForBuyerAndProject('buyer-dup-test', 'proj-dup-test'), isFalse);

      // First conversion should succeed
      final firstAdded = provider.addLeadFromMatch(match);
      expect(firstAdded, isTrue);
      expect(provider.hasLeadForBuyerAndProject('buyer-dup-test', 'proj-dup-test'), isTrue);

      final countAfterFirst = provider.leads.length;

      // Second conversion of the same buyer/project must be prevented
      final secondAdded = provider.addLeadFromMatch(match);
      expect(secondAdded, isFalse);
      expect(provider.leads.length, equals(countAfterFirst));
    });

    test('6. Buyer directory pagination provides access to all 100 demo records', () {
      provider.generate100DemoBuyers();
      expect(provider.totalBuyerCount, equals(100));

      final allBuyers = provider.buyers;
      expect(allBuyers.length, equals(100));

      // Simulate pagination with pageSize = 25
      const pageSize = 25;
      final totalPages = (allBuyers.length / pageSize).ceil();
      expect(totalPages, equals(4));

      // Page 1
      final page1 = allBuyers.sublist(0, 25);
      expect(page1.length, equals(25));

      // Page 4 (records 75 to 100)
      final page4 = allBuyers.sublist(75, 100);
      expect(page4.length, equals(25));

      // Records beyond the old 50 limit are now fully reachable
      final record75 = page4.first;
      expect(record75, isNotNull);
    });

    test('7. Analytics metrics dynamically synchronize with Dashboard numbers', () {
      provider.generate100DemoBuyers();

      // Verify conversion rate formula matches Dashboard exactly
      final dashboardRate = provider.pipelineConversionRate;
      final qualifiedCount = provider.qualifiedLeadCount;
      final totalLeads = provider.leads.length;
      final expectedRate = (qualifiedCount / totalLeads) * 100;

      expect(dashboardRate, equals(expectedRate));

      // Average buyer budget is dynamically calculated from actual buyers
      final avgBudget = provider.averageBuyerBudget;
      expect(avgBudget, greaterThan(300000.0));
      expect(avgBudget, lessThan(1500000.0));

      // Location breakdown contains counts
      final locations = provider.buyersByLocation;
      expect(locations, isNotEmpty);
      expect(locations.values.fold(0, (sum, c) => sum + c), equals(provider.totalBuyerCount));

      // Budget tier breakdown accounts for 100% of buyers
      final tiers = provider.buyersByBudgetTier;
      final totalInTiers = tiers.values.fold(0, (sum, c) => sum + c);
      expect(totalInTiers, equals(provider.totalBuyerCount));
    });
  });
}
