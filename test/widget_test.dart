import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/app.dart';

void main() {
  testWidgets('App renders Web SaaS Dashboard initially', (WidgetTester tester) async {
    // Set a desktop viewport size (1400x900)
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PropMatchApp());
    await tester.pumpAndSettle();

    // Verify Dashboard Top Bar & Brand are present
    expect(find.text('PropMatch AI'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('ACTIVE FOCUS PROJECT'), findsOneWidget);
  });

  testWidgets('Dashboard displays active project and stats', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PropMatchApp());
    await tester.pumpAndSettle();

    // Verify initial project spotlight shows EXSIM Demo Residence
    expect(find.text('EXSIM Demo Residence'), findsWidgets);

    // Verify stat cards
    expect(find.text('Total Projects'), findsOneWidget);
    expect(find.text('Total Buyers Registered'), findsOneWidget);
    expect(find.text('Qualified Leads'), findsOneWidget);
  });
}
