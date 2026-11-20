import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/models/prospect_source_model.dart';
import 'package:propmatch_ai/models/prospect_source_record_model.dart';
import 'package:propmatch_ai/models/prospect_consent_event_model.dart';
import 'package:propmatch_ai/models/prospect_activity_model.dart';
import 'package:propmatch_ai/models/prospect_import_job_model.dart';
import 'package:propmatch_ai/models/prospect_match_model.dart';
import 'package:propmatch_ai/repositories/prospect_repository.dart';
import 'package:propmatch_ai/services/prospect_sources/source_registry.dart';
import 'package:propmatch_ai/services/prospect_sources/crm_import_adapter.dart';
import 'package:propmatch_ai/services/prospect_sources/property_portal_adapter.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/screens/prospects/buyer_intelligence_screen.dart';

void main() {
  group('Phase 4.1: Buyer Intelligence Models & PDPA Compliance', () {
    test('ProspectModel serialization and strict default contact eligibility', () {
      final prospect = ProspectModel(
        id: 'pros-test-001',
        ownerId: 'agent-123',
        fullName: 'Lee Chong Wei',
        phone: '+6012-4458921',
        email: 'chongwei@badminton.my',
        icNumber: '821021-07-5531',
        preferredLocations: ['Bukit Mertajam', 'Batu Kawan'],
        preferredState: 'Penang',
        propertyTypes: ['Condominium', 'Semi-D'],
        budgetMin: 600000,
        budgetMax: 900000,
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        primarySource: 'Property Portal',
      );

      // Verify STRICT PDPA default: Imported / Discovered records must NEVER default to Eligible
      expect(prospect.contactEligibility, equals('Pending Consent'));
      expect(prospect.isEligibleForContact, isFalse);
      expect(prospect.isPendingConsent, isTrue);
      expect(prospect.isDoNotContact, isFalse);

      // Verify masked IC
      expect(prospect.maskedIc, equals('821021-07-****'));

      // Verify budget display
      expect(prospect.budgetDisplay, equals('RM 600k - RM 900k'));

      // Verify round-trip serialization
      final map = prospect.toMap();
      final reconstituted = ProspectModel.fromMap(map);
      expect(reconstituted.id, equals(prospect.id));
      expect(reconstituted.ownerId, equals(prospect.ownerId));
      expect(reconstituted.fullName, equals('Lee Chong Wei'));
      expect(reconstituted.preferredLocations, contains('Batu Kawan'));
      expect(reconstituted.contactEligibility, equals('Pending Consent'));
    });

    test('ProspectSourceModel and Source Records tracking', () {
      final source = ProspectSourceModel(
        id: 'src-001',
        ownerId: 'agent-123',
        name: 'iProperty Malaysia Lead Integration',
        type: 'Property Portal',
        totalProspectsImported: 45,
      );

      expect(source.name, contains('iProperty'));
      expect(source.type, equals('Property Portal'));

      final record = ProspectSourceRecordModel(
        id: 'rec-001',
        ownerId: 'agent-123',
        prospectId: 'pros-test-001',
        sourceId: 'src-001',
        sourceName: 'iProperty Malaysia',
        sourceType: 'Property Portal',
        externalReference: 'ext-9921',
        rawMetadata: {'campaign': 'Batu Kawan New Launch'},
      );

      final map = record.toMap();
      final reconstituted = ProspectSourceRecordModel.fromMap(map);
      expect(reconstituted.externalReference, equals('ext-9921'));
      expect(reconstituted.prospectId, equals('pros-test-001'));
    });

    test('ProspectConsentEventModel append-only audit log serialization', () {
      final consent = ProspectConsentEventModel(
        id: 'cst-001',
        ownerId: 'agent-123',
        prospectId: 'pros-test-001',
        consentType: 'Marketing & Promotion',
        status: 'Granted',
        source: 'WhatsApp Written Consent',
        evidenceText: 'Replied "AGREE" to opt-in message on 19 Nov 2026.',
      );

      expect(consent.isGranted, isTrue);
      expect(consent.isWithdrawn, isFalse);
      expect(consent.evidenceText, contains('AGREE'));

      final map = consent.toMap();
      final reconstituted = ProspectConsentEventModel.fromMap(map);
      expect(reconstituted.id, equals('cst-001'));
      expect(reconstituted.status, equals('Granted'));
      expect(reconstituted.source, equals('WhatsApp Written Consent'));
    });

    test('ProspectActivityModel and ProspectImportJobModel serialization', () {
      final activity = ProspectActivityModel(
        id: 'act-001',
        ownerId: 'agent-123',
        prospectId: 'pros-test-001',
        activityType: 'Status Change',
        title: 'Status changed to Qualified',
        description: 'Agent verified buyer pre-qualification score.',
      );

      expect(activity.activityType, equals('Status Change'));
      final actMap = activity.toMap();
      final reconstitutedAct = ProspectActivityModel.fromMap(actMap);
      expect(reconstitutedAct.title, equals('Status changed to Qualified'));

      final job = ProspectImportJobModel(
        id: 'job-001',
        ownerId: 'agent-123',
        sourceId: 'src-001',
        sourceName: 'Showroom CSV Desk',
        totalRecords: 50,
        importedCount: 48,
        duplicateCount: 2,
        errorCount: 0,
        status: 'Completed',
      );

      expect(job.status, equals('Completed'));
      expect(job.importedCount, equals(48));
      final jobMap = job.toMap();
      final reconstitutedJob = ProspectImportJobModel.fromMap(jobMap);
      expect(reconstitutedJob.sourceName, equals('Showroom CSV Desk'));
    });

    test('ProspectMatchModel linking prospect and property project', () {
      final match = ProspectMatchModel(
        id: 'pm-001',
        ownerId: 'agent-123',
        prospectId: 'pros-test-001',
        projectId: 'proj-001',
        prospectName: 'Lee Chong Wei',
        projectName: 'EXSIM Demo Residence',
        overallCompatibility: 92.5,
        matchClassification: 'Excellent Match',
      );

      expect(match.overallCompatibility, equals(92.5));
      expect(match.matchClassification, equals('Excellent Match'));
    });
  });

  group('Phase 4.1: Data Source Adapters & Registry', () {
    test('CRMImportAdapter parses CSV into prospects with strictly Pending Consent', () {
      final adapter = CRMImportAdapter();
      const csv = '''full_name,phone,email,ic_number,location,state,budget_min,budget_max,property_type
Tan Sri Robert Kuok,+6012-9988112,kuok@group.my,500101-07-1122,Batu Ferringhi,Penang,2000000,5000000,Bungalow
Nurul Izzah,+6019-2233445,nurul@permatang.my,801123-10-8899,Permatang Pauh,Penang,450000,650000,Condominium''';

      final prospects = adapter.parseCsv(csv, ownerId: 'agent-test-1');
      expect(prospects.length, equals(2));

      final first = prospects.first;
      expect(first.fullName, equals('Tan Sri Robert Kuok'));
      expect(first.budgetMin, equals(2000000));
      expect(first.budgetMax, equals(5000000));
      expect(first.status, equals('Imported'));
      // STRICT PDPA REQUIREMENT:
      expect(first.contactEligibility, equals('Pending Consent'));
      expect(first.isEligibleForContact, isFalse);

      final second = prospects.last;
      expect(second.fullName, equals('Nurul Izzah'));
      expect(second.preferredLocations, contains('Permatang Pauh'));
      expect(second.contactEligibility, equals('Pending Consent'));
    });

    test('PropertyPortalAdapter and Registry provide default Malaysian channels', () {
      final portalAdapter = PropertyPortalAdapter();
      expect(portalAdapter.sourceType, equals('Property Portal'));

      final sources = ProspectSourceRegistry.getInitialSourcesForAgent('agent-test-1');
      expect(sources.length, greaterThanOrEqualTo(4));
      expect(sources.any((s) => s.name.contains('Portals Feed')), isTrue);
      expect(sources.any((s) => s.type == 'Property Portal'), isTrue);
      expect(sources.any((s) => s.type == 'Developer'), isTrue);
      expect(sources.any((s) => s.type == 'Partner Agency'), isTrue);
      expect(sources.any((s) => s.type == 'CRM Import'), isTrue);
    });
  });

  group('Phase 4.1: ProspectRepository & Agent Isolation', () {
    test('InMemoryProspectRepository enforces multi-agent isolation', () async {
      final repo = InMemoryProspectRepository([
        ProspectModel(
          id: 'p-1',
          ownerId: 'agent-A',
          fullName: 'Prospect Agent A',
          preferredState: 'Penang',
          budgetMin: 400000,
          budgetMax: 600000,
          primarySource: 'Portal',
        ),
        ProspectModel(
          id: 'p-2',
          ownerId: 'agent-B',
          fullName: 'Prospect Agent B',
          preferredState: 'Selangor',
          budgetMin: 500000,
          budgetMax: 700000,
          primarySource: 'Agency',
        ),
      ]);

      final agentAProspects = await repo.getProspects(ownerId: 'agent-A');
      expect(agentAProspects.length, equals(1));
      expect(agentAProspects.first.fullName, equals('Prospect Agent A'));

      final agentBProspects = await repo.getProspects(ownerId: 'agent-B');
      expect(agentBProspects.length, equals(1));
      expect(agentBProspects.first.fullName, equals('Prospect Agent B'));

      final unknownProspects = await repo.getProspects(ownerId: 'agent-unknown');
      expect(unknownProspects, isEmpty);
    });

    test('InMemoryProspectRepository records append-only consents and activities', () async {
      final repo = InMemoryProspectRepository();

      final consent = ProspectConsentEventModel(
        id: 'c-1',
        ownerId: 'agent-A',
        prospectId: 'p-1',
        consentType: 'Marketing',
        status: 'Granted',
        source: 'Showroom Registration',
      );
      await repo.recordConsentEvent(consent);

      final consents = await repo.getConsentsForProspect('p-1');
      expect(consents.length, equals(1));
      expect(consents.first.source, equals('Showroom Registration'));

      final activity = ProspectActivityModel(
        id: 'a-1',
        ownerId: 'agent-A',
        prospectId: 'p-1',
        activityType: 'Consent Recorded',
        title: 'Consent Captured',
        description: 'Physical card signed.',
      );
      await repo.recordActivity(activity);

      final activities = await repo.getActivitiesForProspect('p-1');
      expect(activities.length, equals(1));
      expect(activities.first.title, equals('Consent Captured'));
    });
  });

  group('Phase 4.1: AppStateProvider Prospect Intelligence Management', () {
    test('Default demo agent loads initial prospects and metrics accurately', () {
      final appState = AppStateProvider();

      expect(appState.totalProspectsCount, greaterThan(0));
      expect(appState.demoProspectsCount, greaterThan(0));
      expect(appState.discoveredProspectsCount, greaterThanOrEqualTo(0));
      expect(appState.verifiedProspectsCount, greaterThanOrEqualTo(0));
      expect(appState.contactEligibleProspectsCount, greaterThanOrEqualTo(0));
      expect(appState.qualifiedProspectsCount, greaterThanOrEqualTo(0));
    });

    test('Filtering by status, eligibility, and search query', () {
      final appState = AppStateProvider();

      // Search filter
      appState.setProspectSearchQuery('Batu Kawan');
      final filtered = appState.filteredProspects;
      for (final p in filtered) {
        final matches = p.preferredLocations.any((l) => l.contains('Batu Kawan')) ||
            p.fullName.contains('Batu Kawan') ||
            p.phone.contains('Batu Kawan');
        expect(matches, isTrue);
      }

      // Reset search, test eligibility filter
      appState.setProspectSearchQuery('');
      appState.setProspectEligibilityFilter('Eligible');
      final eligibleOnly = appState.filteredProspects;
      for (final p in eligibleOnly) {
        expect(p.contactEligibility, equals('Eligible'));
      }

      // Test status filter
      appState.setProspectEligibilityFilter('All');
      appState.setProspectStatusFilter('Discovered');
      final discoveredOnly = appState.filteredProspects;
      for (final p in discoveredOnly) {
        expect(p.status, equals('Discovered'));
      }
    });

    test('PDPA Consent recording automatically promotes prospect to Eligible or DNC', () async {
      final appState = AppStateProvider();
      final prospect = ProspectModel(
        id: 'pros-test-consent',
        ownerId: 'demo-agent-001',
        fullName: 'Test Consent Subject',
        preferredState: 'Penang',
        budgetMin: 500000,
        budgetMax: 700000,
        primarySource: 'Portal',
        contactEligibility: 'Pending Consent',
      );
      await appState.createProspect(prospect);

      // Verify initially Pending Consent
      expect(appState.allProspects.firstWhere((p) => p.id == prospect.id).contactEligibility, equals('Pending Consent'));

      // Record Granted Consent
      final consentGranted = ProspectConsentEventModel(
        id: 'cst-grant',
        ownerId: 'demo-agent-001',
        prospectId: prospect.id,
        consentType: 'Marketing & Promotion',
        status: 'Granted',
        source: 'WhatsApp Written Consent',
        evidenceText: 'Opted in via chat.',
      );
      await appState.recordProspectConsent(consentGranted);

      // Prospect must now be automatically Eligible
      expect(appState.allProspects.firstWhere((p) => p.id == prospect.id).contactEligibility, equals('Eligible'));
      expect(appState.allProspects.firstWhere((p) => p.id == prospect.id).isEligibleForContact, isTrue);

      // Now record Withdrawn Consent
      final consentWithdrawn = ProspectConsentEventModel(
        id: 'cst-withdrawn',
        ownerId: 'demo-agent-001',
        prospectId: prospect.id,
        consentType: 'Marketing & Promotion',
        status: 'Withdrawn',
        source: 'Web Form Opt-In',
        evidenceText: 'Buyer unsubscribed.',
      );
      await appState.recordProspectConsent(consentWithdrawn);

      // Prospect must now be strictly Do Not Contact
      expect(appState.allProspects.firstWhere((p) => p.id == prospect.id).contactEligibility, equals('Do Not Contact'));
      expect(appState.allProspects.firstWhere((p) => p.id == prospect.id).isDoNotContact, isTrue);
    });

    test('Convert Prospect to Active Buyer CRM maintains complete collection isolation', () async {
      final appState = AppStateProvider();
      final prospect = ProspectModel(
        id: 'pros-convert-001',
        ownerId: 'demo-agent-001',
        fullName: 'Dato Seri Michelle Yeoh',
        phone: '+6012-9988776',
        email: 'michelle@oscar.my',
        preferredLocations: ['Ipoh', 'George Town'],
        preferredState: 'Perak',
        propertyTypes: ['Bungalow'],
        budgetMin: 3000000,
        budgetMax: 6000000,
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        primarySource: 'Partner Agency',
        status: 'Discovered',
      );
      await appState.createProspect(prospect);

      final initialBuyerCount = appState.totalBuyerCount;

      // Convert to Buyer
      final createdBuyer = await appState.convertProspectToBuyer(prospect);

      // Verify new buyer exists in CRM
      expect(appState.totalBuyerCount, equals(initialBuyerCount + 1));
      expect(createdBuyer.name, equals('Dato Seri Michelle Yeoh'));
      expect(createdBuyer.budgetMin, equals(3000000));
      expect(createdBuyer.preferredState, equals('Perak'));

      // Verify prospect status is promoted to Qualified
      final updatedProspect = appState.allProspects.firstWhere((p) => p.id == prospect.id);
      expect(updatedProspect.status, equals('Qualified'));
    });

    test('Purge demo prospects and generate demo prospects', () async {
      final appState = AppStateProvider();

      // Ensure demo prospects are purged
      await appState.purgeDemoProspects();
      expect(appState.demoProspectsCount, equals(0));

      // Regenerate demo prospects
      await appState.generateDemoProspects();
      expect(appState.demoProspectsCount, greaterThan(0));
    });
  });

  group('Phase 4.1: BuyerIntelligenceScreen UI Widgets', () {
    testWidgets('Renders Buyer Intelligence Screen with Header, KPI Cards, and Table', (tester) async {
      final appState = AppStateProvider();
      final nav = NavigationProvider();

      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appState),
            ChangeNotifierProvider.value(value: nav),
          ],
          child: const MaterialApp(
            home: BuyerIntelligenceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Buyer Intelligence & Prospect Discovery'), findsOneWidget);
      expect(find.text('Import CSV'), findsOneWidget);

      // Verify KPI Metrics Cards
      expect(find.text('Total Prospects'), findsOneWidget);
      expect(find.text('Newly Discovered'), findsOneWidget);
      expect(find.text('Verified Profiles'), findsOneWidget);
      expect(find.text('Contact Eligible'), findsOneWidget);
      expect(find.text('Qualified Prospects'), findsOneWidget);

      // Verify Filter Bar
      expect(find.text('Clear Filters'), findsOneWidget);

      // Verify Table Columns
      expect(find.text('Prospect Name & ID'), findsOneWidget);
      expect(find.text('Contact Eligibility (PDPA)'), findsOneWidget);
      expect(find.text('Preferences & Budget'), findsOneWidget);
      expect(find.text('AI Score'), findsOneWidget);

      // Verify sample prospect from demo data
      expect(find.text('Tan Sri William Chen (Demo)'), findsOneWidget);
    });
  });
}
