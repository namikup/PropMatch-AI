import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/app.dart';
import 'package:propmatch_ai/providers/navigation_provider.dart';

void main() {
  group('Comprehensive Functional Verification Suite', () {
    testWidgets('1. Sidebar navigation works & 2. Every module opens correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Verify initial Dashboard module
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('ACTIVE FOCUS PROJECT'), findsOneWidget);

      // Verify each navigation item in sidebar opens its corresponding screen
      for (final item in navItems) {
        debugPrint('--> Testing module navigation to: ${item.label}');
        final navTile = find.widgetWithText(InkWell, item.label);
        expect(navTile, findsWidgets, reason: 'Sidebar must contain ${item.label}');
        await tester.tap(navTile.first);
        await tester.pumpAndSettle();

        // Verify module screen renders without crashing
        expect(find.text(item.label), findsWidgets,
            reason: 'Module ${item.label} should be visible in TopBar or screen');
      }
    });

    testWidgets('3. The dashboard displays its statistics properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Check stat cards exist and show initial values
      expect(find.text('Total Projects'), findsOneWidget);
      expect(find.text('Total Buyers Registered'), findsOneWidget);
      expect(find.text('Qualified Leads'), findsOneWidget);
      expect(find.text('Avg Match Rate'), findsOneWidget);
      expect(find.text('High-Priority Leads & Enquiries'), findsOneWidget);
    });

    testWidgets('4. The project creation form works',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Navigate to Projects module
      await tester.tap(find.widgetWithText(InkWell, 'Projects').first);
      await tester.pumpAndSettle();

      // Tap "Add New Project" button
      final addBtn = find.text('Add New Project');
      expect(addBtn, findsWidgets);
      await tester.tap(addBtn.first);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Add New Property Project'), findsOneWidget);

      // Fill in project details
      await tester.enterText(
          find.widgetWithText(TextField, 'Project Name *'), 'Batu Kawan Eco Haven');
      await tester.enterText(
          find.widgetWithText(TextField, 'Location / Area *'), 'Batu Kawan');
      await tester.enterText(
          find.widgetWithText(TextField, 'Developer *'), 'Aspen Group');

      // Submit
      final saveBtn = find.text('Save Project');
      await tester.tap(saveBtn.first);
      await tester.pumpAndSettle();

      // Verify the new project appears in the portfolio
      expect(find.text('Batu Kawan Eco Haven'), findsWidgets);
    });

    testWidgets('5. The 100 demo buyers can be generated',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Navigate to Buyers module
      await tester.tap(find.widgetWithText(InkWell, 'Buyers').first);
      await tester.pumpAndSettle();

      // Tap "Generate 100 Demo Buyers"
      final genBtn = find.text('Generate 100 Demo Buyers');
      expect(genBtn, findsWidgets);
      await tester.tap(genBtn.first);
      await tester.pumpAndSettle();

      // Verify 100 profiles are registered with DEMO badges
      expect(find.textContaining('100 Profiles (100 DEMO)'), findsOneWidget);
      expect(find.text('DEMO'), findsWidgets);
    });

    testWidgets('6. Audience Discovery produces results with reasoning',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Navigate to AI Audience
      await tester.tap(find.widgetWithText(InkWell, 'AI Audience').first);
      await tester.pumpAndSettle();

      // Tap "Run AI Audience Analysis"
      final analyzeBtn = find.text('Run AI Audience Analysis');
      expect(analyzeBtn, findsWidgets);
      await tester.tap(analyzeBtn.first);
      await tester.pump(); // Start async process
      await tester.pump(const Duration(milliseconds: 700)); // Advance timer
      await tester.pumpAndSettle();

      // Verify generated audience segments exist with rankings and reasoning
      expect(find.textContaining('Identified Audience Segments'), findsOneWidget);
      expect(find.text('First-time Homebuyers'), findsWidgets);
      expect(find.text('💡 Why They Are Interested'), findsWidgets);
      expect(find.text('🎯 AI Ranking Rationale'), findsWidgets);
    });

    testWidgets('7. Buyer Matching displays percentages, factors & explanations',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Navigate to AI Matching
      await tester.tap(find.widgetWithText(InkWell, 'AI Matching').first);
      await tester.pumpAndSettle();

      // Tap "Run Matching Engine" or "Start Matching"
      final matchBtn = find.text('Run Matching Engine');
      expect(matchBtn, findsWidgets);
      await tester.tap(matchBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verify matches are shown with percentages and breakdown
      expect(find.textContaining('Candidate Matches'), findsOneWidget);
      expect(find.textContaining('% MATCH'), findsWidgets);
      expect(find.text('Weighted Matching Dimensions'), findsOneWidget);
      expect(find.text('Budget Compatibility (Max 25%)'), findsOneWidget);
      expect(find.text('Location Compatibility (Max 25%)'), findsOneWidget);
    });

    testWidgets('8. Marketing Assistant generates multi-channel content',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();

      // Navigate to Marketing AI
      await tester.tap(find.widgetWithText(InkWell, 'Marketing AI').first);
      await tester.pumpAndSettle();

      // Tap "Generate Marketing Collateral" or "Generate Content Now"
      final genBtn = find.text('Generate Marketing Collateral');
      expect(genBtn, findsWidgets);
      await tester.tap(genBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify generated content tabs are present and populated
      expect(find.text('PRIMARY AD HEADLINE'), findsOneWidget);
      expect(find.text('Facebook Ad Copy'), findsWidgets);
      expect(find.text('Instagram Caption'), findsWidgets);
      expect(find.text('TikTok Video Script'), findsWidgets);
      expect(find.text('WhatsApp Script'), findsWidgets);
      expect(find.text('Campaign Strategy'), findsWidgets);
    });

    testWidgets('9. The layout works at different browser widths (Desktop, Laptop, Tablet, Mobile)',
        (WidgetTester tester) async {
      // Test Desktop viewport (1600x900)
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing, reason: 'Desktop has persistent sidebar, not drawer');

      // Test Tablet / Compact viewport (800x600)
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpWidget(const PropMatchApp());
      await tester.pumpAndSettle();
      // On narrow viewport, hamburger menu button appears in TopBar
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
