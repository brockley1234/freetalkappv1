import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Universal test helper to create a simple test page
/// This wrapper handles all common test setup without requiring complex mocking
Widget createSimpleTestWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

/// Verify a widget renders by checking for basic material structure
void expectWidgetRendersBasic(WidgetTester tester) {
  // Should have at least one Text widget or basic Material widget
  final hasContent = find.byType(Text).evaluate().isNotEmpty ||
      find.byType(Container).evaluate().isNotEmpty ||
      find.byType(Column).evaluate().isNotEmpty ||
      find.byType(Row).evaluate().isNotEmpty ||
      find.byType(ListView).evaluate().isNotEmpty ||
      find.byType(SingleChildScrollView).evaluate().isNotEmpty;

  expect(hasContent, true, reason: 'Widget should render with some basic Material content');
}

/// Expect a widget to dispose properly
void expectWidgetDisposesCleanly(WidgetTester tester) {
  final widgetsAfter = find.byType(Scaffold).evaluate().length;
  expect(widgetsAfter, 0, reason: 'Widget should be disposed after replacement');
}
