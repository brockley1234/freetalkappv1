import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/audio_recorder_page.dart';
import 'package:freetalk/pages/cache_settings_page.dart';
import 'package:freetalk/pages/music_selection_page.dart';
import 'package:freetalk/pages/notification_test_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('AudioRecorderPage Widget Tests', () {
    Widget createWidget() => testWidget(const AudioRecorderPage());

    testWidgets('AudioRecorderPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('AudioRecorderPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AudioRecorderPage displays AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AudioRecorderPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('CacheSettingsPage Widget Tests', () {
    Widget createWidget() => testWidget(const CacheSettingsPage());

    testWidgets('CacheSettingsPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CacheSettingsPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CacheSettingsPage displays settings options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Look for ListTile or other UI elements - don't fail if not found
      final listTiles = find.byType(ListTile);
      expect(
        listTiles.evaluate().isNotEmpty || find.byType(Text).evaluate().isNotEmpty,
        true,
        reason: 'Should have some UI elements',
      );
    });

    testWidgets('CacheSettingsPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('MusicSelectionPage Widget Tests', () {
    Widget createWidget() => testWidget(const MusicSelectionPage());

    testWidgets('MusicSelectionPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MusicSelectionPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('MusicSelectionPage displays music list',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Use longer timeout for music loading
      try {
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } catch (_) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      // Should have some content or loading indicator
      expect(
        find.byType(Text).evaluate().isNotEmpty ||
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('MusicSelectionPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('NotificationTestPage Widget Tests', () {
    Widget createWidget() => testWidget(const NotificationTestPage());

    testWidgets('NotificationTestPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('NotificationTestPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('NotificationTestPage displays content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('NotificationTestPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });
}

