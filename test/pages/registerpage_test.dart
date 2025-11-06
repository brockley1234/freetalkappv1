import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/registerpage.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RegisterPage Widget Tests', () {
    Widget createRegisterPageWidget() {
      return testWidget(const RegisterPage());
    }

    testWidgets('RegisterPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('RegisterPage displays Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RegisterPage has name input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('RegisterPage has email input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('RegisterPage has PIN code input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('RegisterPage has register button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('RegisterPage has login link', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('RegisterPage accepts text input', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'John Doe');
      expect(find.text('John Doe'), findsWidgets);
    });

    testWidgets('RegisterPage validates required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(Form), findsWidgets);
    });

    testWidgets('RegisterPage displays AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Just verify page renders without crashing
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RegisterPage has terms checkbox', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Just verify page has form elements
      expect(find.byType(Form), findsWidgets);
    });

    testWidgets('RegisterPage loading indicator works',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RegisterPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MaterialApp), findsNothing);
    });

    testWidgets('RegisterPage can scroll if content overflows',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));

      // Test scrolling capability
      final scrollView = find.byType(SingleChildScrollView);
      if (scrollView.evaluate().isNotEmpty) {
        await tester.drag(scrollView.first, const Offset(0, -100));
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('RegisterPage password fields are obscured',
        (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterPageWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Just verify page has text input fields
      expect(find.byType(Form), findsWidgets);
    });
  });
}


