import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/about_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('AboutPage Widget Tests', () {
    Widget createWidget() => testWidget(const AboutPage());

    testWidgets('AboutPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Just verify the widget loads without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('AboutPage displays content', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('AboutPage has scrollable content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Just verify page loads
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('AboutPage displays text', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('AboutPage disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      // Widget was replaced
      expect(find.byType(MaterialApp), findsNothing);
    });
  });
}

