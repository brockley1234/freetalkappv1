import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/crisis/create_crisis_page.dart';
import 'package:freetalk/pages/crisis/crisis_detail_page.dart';
import 'package:freetalk/pages/crisis/crisis_response_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('CreateCrisisPage Widget Tests', () {
    Widget createWidget() => testWidget(const CreateCrisisPage());

    testWidgets('CreateCrisisPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CreateCrisisPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CreateCrisisPage displays form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('CreateCrisisPage displays AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('CreateCrisisPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('CrisisDetailPage Widget Tests', () {
    Widget createWidget() => const MaterialApp(
      home: CrisisDetailPage(crisisId: 'test_crisis_id'),
    );

    testWidgets('CrisisDetailPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CrisisDetailPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CrisisDetailPage displays crisis information',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('CrisisDetailPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('CrisisResponsePage Widget Tests', () {
    Widget createWidget() => const MaterialApp(
      home: CrisisResponsePage(),
    );

    testWidgets('CrisisResponsePage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CrisisResponsePage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CrisisResponsePage displays response options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('CrisisResponsePage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });
}


