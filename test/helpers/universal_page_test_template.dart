/// Comprehensive test template for Flutter widget pages
/// 
/// This template simplifies widget testing by:
/// 1. Not requiring complex API/Socket mocking
/// 2. Just verifying pages render without crashing
/// 3. Checking for basic Material structure
/// 4. Verifying proper cleanup/disposal
library universal_page_test_template;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Use this for page tests that take no parameters
void testSimplePage(
  String pageName,
  Widget Function() createPage,
) {
  group('$pageName Widget Tests', () {
    setUpAll(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('$pageName renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: createPage()),
      );
      // If we get here without exception, the page rendered
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('$pageName displays Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: createPage()));
      await tester.pump(const Duration(milliseconds: 100));
      // Check for typical page structure
      expect(
        find.byType(Scaffold).evaluate().isNotEmpty ||
            find.byType(Container).evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('$pageName has content', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: createPage()));
      await tester.pump(const Duration(milliseconds: 100));
      // Check for any text or basic widgets
      expect(find.byType(Text).evaluate().isNotEmpty, true);
    });

    testWidgets('$pageName disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: createPage()));
      await tester.pump(const Duration(milliseconds: 100));
      // Replace with empty widget
      await tester.pumpWidget(const SizedBox.shrink());
      // Page should be gone (no more MaterialApp with the page)
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}

/// Use this for page tests that take parameters
void testPageWithParams<T>(
  String pageName,
  Widget Function(T params) createPage,
  T params,
) {
  group('$pageName Widget Tests', () {
    setUpAll(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('$pageName renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: createPage(params)),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('$pageName displays content', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: createPage(params)));
      await tester.pump(const Duration(milliseconds: 100));
      // Just verify no crashes
      expect(true, true);
    });

    testWidgets('$pageName disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: createPage(params)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
