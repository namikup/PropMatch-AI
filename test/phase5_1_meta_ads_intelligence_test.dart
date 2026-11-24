import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propmatch_ai/models/meta_ads/meta_connection_model.dart';
import 'package:propmatch_ai/models/meta_ads/meta_buyer_quality_model.dart';
import 'package:propmatch_ai/models/project_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';
import 'package:propmatch_ai/services/prospect_sources/source_registry.dart';
import 'package:propmatch_ai/services/prospect_sources/meta_lead_ads_adapter.dart';
import 'package:propmatch_ai/services/lead_ingestion/lead_ingestion_pipeline.dart';
import 'package:propmatch_ai/screens/campaigns/campaigns_screen.dart';
import 'package:propmatch_ai/screens/campaigns/meta_ads_intelligence_screen.dart';

void main() {
  group('Phase 5.1 — Meta Ads Intelligence Integration Test Suite', () {
    const pilotOwnerId = 'pilot-agent-malik-001';

    final realListing = ProjectModel(
      id: 'proj-penang-pilot-001',
      name: 'Eco Horizon Astonia Townhome',
      developer: 'EcoWorld Development',
      state: 'Penang',
      location: 'Batu Kawan',
      propertyType: 'Terrace House',
      startingPrice: 680000,
      maximumPrice: 850000,
      bedrooms: 4,
      bathrooms: 3,
      builtUpArea: 1850,
      purpose: 'Own Stay & Investment',
      status: 'Under Construction',
      description: 'Gated & guarded landed strata home near Design Village.',
      ownerId: pilotOwnerId,
    );

    // =========================================================================
    // 1. DATA MODELS & DETERMINISTIC CALCULATIONS
    // =========================================================================
    test('1.1 MetaConnectionModel serializes and tracks missing permissions accurately', () {
      final initialConn = MetaConnectionModel.initial(pilotOwnerId);
      expect(initialConn.isConnected, isFalse);
      expect(initialConn.missingPermissions, contains('ads_read'));
      expect(initialConn.missingPermissions, contains('ads_management'));
      expect(initialConn.missingPermissions, contains('leads_retrieval'));

      final connectedConn = MetaConnectionModel(
        ownerId: pilotOwnerId,
        facebookPageId: 'page-123',
        facebookPageName: 'Malik Tan Real Estate',
        adAccountId: 'act_492019482910',
        adAccountName: 'Penang Landed Campaigns',
        currency: 'MYR',
        isConnected: true,
        connectionStatus: 'Connected',
        grantedPermissions: const [
          'ads_read',
          'ads_management',
          'leads_retrieval',
          'pages_manage_metadata',
          'pages_manage_ads',
          'pages_read_engagement',
          'pages_show_list',
        ],
        missingPermissions: const [],
        updatedAt: DateTime.now(),
      );

      final map = connectedConn.toMap();
      final revived = MetaConnectionModel.fromMap(map);

      expect(revived.isConnected, isTrue);
      expect(revived.adAccountId, equals('act_492019482910'));
      expect(revived.currency, equals('MYR'));
      expect(revived.grantedPermissions.length, equals(7));
      expect(revived.missingPermissions.isEmpty, isTrue);
    });

    test('1.2 MetaBuyerQualityModel preserves null when viewings are zero without fabricating values', () {
      const emptyQuality = MetaBuyerQualityModel(
        totalLeads: 12,
        validContactableLeads: 10,
        qualifiedProspects: 0,
        matchedListingCount: 0,
        viewingAppointments: 0,
        convertedBuyers: 0,
        costPerQualifiedBuyer: null,
        costPerViewingAppointment: null,
        qualificationRate: 0.0,
      );

      expect(emptyQuality.costPerQualifiedBuyer, isNull);
      expect(emptyQuality.costPerViewingAppointment, isNull);

      const activeQuality = MetaBuyerQualityModel(
        totalLeads: 32,
        validContactableLeads: 28,
        qualifiedProspects: 18,
        matchedListingCount: 18,
        viewingAppointments: 5,
        convertedBuyers: 1,
        costPerQualifiedBuyer: 43.33,
        costPerViewingAppointment: 156.0,
        qualificationRate: 56.3,
      );

      expect(activeQuality.costPerQualifiedBuyer, equals(43.33));
      expect(activeQuality.costPerViewingAppointment, equals(156.0));
      expect(activeQuality.qualificationRate, equals(56.3));
    });

    // =========================================================================
    // 2. META LEAD ADS ADAPTER & REGISTRY
    // =========================================================================
    test('2.1 MetaLeadAdsAdapter is registered in ProspectSourceRegistry', () {
      final adapter = ProspectSourceRegistry.getAdapter('Facebook Lead Ads');
      expect(adapter, isNotNull);
      expect(adapter, isA<MetaLeadAdsAdapter>());
      expect(adapter!.sourceType, equals('Facebook Lead Ads'));
    });

    test('2.2 MetaLeadAdsAdapter validates and parses Instant Form lead payload', () {
      final adapter = MetaLeadAdsAdapter();

      // Missing name and contact
      expect(adapter.validateProspectData({}), isFalse);

      // Valid record
      final validPayload = {
        'leadgenId': 'lead-meta-999',
        'fullName': 'Lim Guan Eng',
        'phone': '012-4455888',
        'email': 'guaneng@penang.my',
        'preferredLocation': 'Batu Kawan',
        'budget': 'RM800,000',
        'purpose': 'Own Stay',
        'timeline': 'Within 3 months',
        'campaignId': 'meta-camp-aston-001',
        'formId': 'instant-form-landed-2026',
      };

      expect(adapter.validateProspectData(validPayload), isTrue);

      final enquiry = adapter.parseEnquiry(
        ownerId: pilotOwnerId,
        rawPayload: validPayload,
      );

      expect(enquiry.ownerId, equals(pilotOwnerId));
      expect(enquiry.sourceType, equals('Facebook Lead Ads'));
      expect(enquiry.sourceReferenceId, equals('lead-meta-999'));
      expect(enquiry.fullName, equals('Lim Guan Eng'));
      expect(enquiry.phone, equals('012-4455888'));
      expect(enquiry.budgetMax, equals(800000.0));
      expect(enquiry.enquiryConsentGranted, isTrue);
      expect(enquiry.marketingConsentGranted, isFalse); // Never unrestricted
      expect(enquiry.contactEligibility, equals('Eligible'));
      expect(enquiry.consentEvidence, contains('Meta Instant Form Submission'));
    });

    // =========================================================================
    // 3. PIPELINE INTEGRATION & DETERMINISTIC MATCHING
    // =========================================================================
    test('3.1 Ingesting Facebook Lead Ads through LeadIngestionPipeline matches real property', () async {
      final leadPayload = {
        'name': 'Chong Wei Feng',
        'phone': '016-8877665',
        'email': 'weifeng@badminton.my',
        'location': 'Batu Kawan',
        'propertyType': 'Terrace House',
        'budgetMax': 820000.0,
        'buyingPurpose': 'Own Stay',
        'timeline': 'Within 3 months',
        'enquiryConsentGranted': true,
        'campaignId': 'meta-camp-aston-001',
      };

      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: pilotOwnerId,
        sourceType: 'Facebook Lead Ads',
        rawPayload: leadPayload,
        existingProspects: const [],
        availableProjects: [realListing],
      );

      expect(result.success, isTrue);
      expect(result.enquiry.sourceType, equals('Facebook Lead Ads'));
      expect(result.createdProspect, isNotNull);
      expect(result.createdProspect!.ownerId, equals(pilotOwnerId));
      expect(result.createdProspect!.contactEligibility, equals('Eligible'));
      expect(result.matchedProjectId, equals('proj-penang-pilot-001'));
      expect(result.matchScore, isNotNull);
      expect(result.matchScore!, greaterThanOrEqualTo(85.0)); // High deterministic match
    });

    // =========================================================================
    // 4. WIDGET RENDERING & TAB NAVIGATION
    // =========================================================================
    testWidgets('4.1 CampaignsScreen renders tab selector and defaults to Meta Ads Intelligence', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampaignsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Meta Ads Intelligence'), findsWidgets);
      expect(find.text('Multi-Channel Creatives'), findsOneWidget);

      // Verify Meta Ads tab button is rendered and selected by default
      expect(find.byType(MetaAdsIntelligenceScreen), findsOneWidget);

      // Switch to Multi-Channel Creatives tab
      await tester.tap(find.text('Multi-Channel Creatives'));
      await tester.pumpAndSettle();

      expect(find.text('Multi-Channel Campaigns'), findsOneWidget);
      expect(find.byType(MetaAdsIntelligenceScreen), findsNothing);

      // Switch back to Meta Ads Intelligence tab
      await tester.tap(find.text('Meta Ads Intelligence'));
      await tester.pumpAndSettle();

      expect(find.byType(MetaAdsIntelligenceScreen), findsOneWidget);
    });

    testWidgets('4.2 MetaAdsIntelligenceScreen renders KPIs, Funnel, and Gemini AI sections', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MetaAdsIntelligenceScreen(ownerId: pilotOwnerId),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connection Card Elements
      expect(find.text('Meta Advertising Asset Connection'), findsOneWidget);
      expect(find.text('Connected'), findsWidgets);
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Granted Meta Permissions:'), findsOneWidget);

      // KPI Elements
      expect(find.text('Advertising Performance Overview'), findsOneWidget);
      expect(find.text('Total Ad Spend'), findsOneWidget);

      // Buyer Quality & Funnel
      expect(find.text('Meta Ad Buyer Quality & Pipeline Conversion'), findsOneWidget);
      expect(find.text('Cost per Qualified Buyer'), findsOneWidget);
      expect(find.text('Cost per Viewing Appointment'), findsOneWidget);

      // Campaign Comparison
      expect(find.text('Campaign Performance & Comparison'), findsOneWidget);
      expect(find.textContaining('Eco Horizon Astonia Townhome'), findsWidgets);

      // Gemini AI Intelligence
      expect(find.text('Gemini AI Advertising Intelligence'), findsOneWidget);
      expect(find.text('Re-Analyze with Gemini'), findsOneWidget);
      expect(find.textContaining('Statistical Confidence'), findsOneWidget);
    });
  });
}
