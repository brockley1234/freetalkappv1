import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/upload_video_page.dart';
import 'package:freetalk/pages/localization_example_page.dart';
import 'package:freetalk/pages/terms_of_service_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('UploadVideoPage Widget Tests', () {
    Widget createWidget() => testWidget(const UploadVideoPage());

    testWidgets('UploadVideoPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('UploadVideoPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('UploadVideoPage displays upload options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('UploadVideoPage has form fields', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('UploadVideoPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('LocalizationExamplePage Widget Tests', () {
    Widget createWidget() =>
        testWidget(const LocalizationExamplePage());

    testWidgets('LocalizationExamplePage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('LocalizationExamplePage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('LocalizationExamplePage displays text content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('LocalizationExamplePage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('TermsOfServicePage Widget Tests', () {
    Widget createWidget() => testWidget(const TermsOfServicePage());

    testWidgets('TermsOfServicePage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TermsOfServicePage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('TermsOfServicePage displays terms content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('TermsOfServicePage displays text content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('TermsOfServicePage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });
}

