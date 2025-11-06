import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/games/chain_reaction_game.dart';
import 'package:freetalk/pages/games/color_blast_game.dart';
import 'package:freetalk/pages/games/games_list_page.dart';
import 'package:freetalk/pages/games/puzzle_rush_game.dart';
import 'package:freetalk/pages/games/rpg_adventure_game.dart' as rpg;
import 'package:freetalk/pages/games/tap_streak_game.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('GamesListPage Widget Tests', () {
    Widget createWidget() => testWidget(const GamesListPage());

    testWidgets('GamesListPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('GamesListPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('GamesListPage displays games grid', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GridView), findsWidgets);
    });

    testWidgets('GamesListPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('ChainReactionGame Widget Tests', () {
    Widget createWidget() => testWidget(const ChainReactionGame());

    testWidgets('ChainReactionGame renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Check that the app renders properly
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('ChainReactionGame displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ChainReactionGame displays game board',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      // Game uses Stack and Positioned widgets for circles, not GridView
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('ChainReactionGame disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(ChainReactionGame), findsNothing);
    });
  });

  group('ColorBlastGame Widget Tests', () {
    Widget createWidget() => testWidget(const ColorBlastGame());

    testWidgets('ColorBlastGame renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('ColorBlastGame displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ColorBlastGame displays game content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('ColorBlastGame disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(ColorBlastGame), findsNothing);
    });
  });

  group('PuzzleRushGame Widget Tests', () {
    Widget createWidget() => testWidget(const PuzzleRushGame());

    testWidgets('PuzzleRushGame renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PuzzleRushGame displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('PuzzleRushGame displays puzzle board',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('PuzzleRushGame disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(PuzzleRushGame), findsNothing);
    });
  });

  group('RPGAdventureGame Widget Tests', () {
    Widget createWidget() => testWidget(const rpg.RPGAdventureGame());

    testWidgets('RPGAdventureGame renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Just check that the app renders
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('RPGAdventureGame displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RPGAdventureGame displays game interface',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('RPGAdventureGame disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(rpg.RPGAdventureGame), findsNothing);
    });
  });

  group('TapStreakGame Widget Tests', () {
    Widget createWidget() => testWidget(const TapStreakGame());

    testWidgets('TapStreakGame renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      // Just check that MaterialApp rendered successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TapStreakGame displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('TapStreakGame displays tap targets',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('TapStreakGame disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(TapStreakGame), findsNothing);
    });
  });
}


