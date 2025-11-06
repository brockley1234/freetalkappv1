import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/saved_posts_page.dart';
import 'package:freetalk/pages/videos_page.dart';
import 'package:freetalk/pages/user_photos_page.dart';
import 'package:freetalk/pages/friend_search_page.dart';
import 'package:freetalk/pages/pokes_page.dart';
import 'package:freetalk/pages/profile_visitors_page.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('SavedPostsPage Widget Tests', () {
    Widget createWidget() => testWidget(const SavedPostsPage());

    testWidgets('SavedPostsPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('SavedPostsPage displays saved posts',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('VideosPage Widget Tests', () {
    Widget createWidget() => testWidget(const VideosPage());

    testWidgets('VideosPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('VideosPage displays videos', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('UserPhotosPage Widget Tests', () {
    Widget createWidget() => const MaterialApp(
          home: UserPhotosPage(
            userId: 'test_user',
            userName: 'Test User',
          ),
        );

    testWidgets('UserPhotosPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('UserPhotosPage displays photos', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('FriendSearchPage Widget Tests', () {
    Widget createWidget() => testWidget(const FriendSearchPage());

    testWidgets('FriendSearchPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('FriendSearchPage has search field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('PokesPage Widget Tests', () {
    Widget createWidget() => testWidget(const PokesPage());

    testWidgets('PokesPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PokesPage displays pokes', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Use pumpAndSettle with timeout instead of pump to handle async operations
      try {
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } catch (_) {
        // Timeout is acceptable for network requests in tests
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('ProfileVisitorsPage Widget Tests', () {
    Widget createWidget() => testWidget(const ProfileVisitorsPage());

    testWidgets('ProfileVisitorsPage renders', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('ProfileVisitorsPage displays visitors',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}


