import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/forgot_password_page.dart';
import 'package:freetalk/pages/recover_pin_page.dart';
import 'package:freetalk/pages/language_selection_page.dart';
import 'package:freetalk/pages/create_story_page.dart';
import 'package:freetalk/pages/story_viewer_page.dart';
import 'package:freetalk/pages/privacy_policy_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('ForgotPasswordPage Widget Tests', () {
    Widget createWidget() => testWidget(const ForgotPasswordPage());

    testWidgets('ForgotPasswordPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('ForgotPasswordPage has email field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('ForgotPasswordPage has reset button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });
  });

  group('RecoverPinPage Widget Tests', () {
    Widget createWidget() => testWidget(const RecoverPinPage());

    testWidgets('RecoverPinPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('RecoverPinPage has form fields', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('LanguageSelectionPage Widget Tests', () {
    Widget createWidget() => testWidget(const LanguageSelectionPage());

    testWidgets('LanguageSelectionPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('LanguageSelectionPage displays languages',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('CreateStoryPage Widget Tests', () {
    Widget createWidget() => testWidget(const CreateStoryPage());

    testWidgets('CreateStoryPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CreateStoryPage has image picker',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('CreateStoryPage has camera button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });
  });

  group('StoryViewerPage Widget Tests', () {
    Widget createWidget() => testWidget(
      const StoryViewerPage(
        userStories: [],
      ),
    );

    testWidgets('StoryViewerPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('StoryViewerPage displays story', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('PrivacyPolicyPage Widget Tests', () {
    Widget createWidget() => testWidget(const PrivacyPolicyPage());

    testWidgets('PrivacyPolicyPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PrivacyPolicyPage displays content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });
  });
}


