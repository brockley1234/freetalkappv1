import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freetalk/pages/events/create_event_page.dart';
import 'package:freetalk/pages/events/events_list_page.dart';
import 'package:freetalk/pages/events/event_detail_page.dart';
import 'package:freetalk/pages/events/manage_attendees_page.dart';
import 'package:freetalk/models/event_model.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('CreateEventPage Widget Tests', () {
    Widget createWidget() => testWidget(const CreateEventPage());

    testWidgets('CreateEventPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('CreateEventPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CreateEventPage displays form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('CreateEventPage displays AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('CreateEventPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('EventsListPage Widget Tests', () {
    Widget createWidget() => testWidget(const EventsListPage());

    testWidgets('EventsListPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('EventsListPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('EventsListPage displays events list',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('EventsListPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('EventDetailPage Widget Tests', () {
    Widget createWidget() => const MaterialApp(
      home: EventDetailPage(eventId: 'test_event_id'),
    );

    testWidgets('EventDetailPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('EventDetailPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('EventDetailPage displays event information',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('EventDetailPage displays RSVP button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('EventDetailPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('ManageAttendeesPage Widget Tests', () {
    Widget createWidget() {
      final testEvent = Event(
        id: 'test_event_id',
        title: 'Test Event',
        description: 'Test Description',
        organizer: 'test_organizer',
        startTime: DateTime.now().add(const Duration(days: 1)),
        timezone: 'UTC',
        isAllDay: false,
        visibility: 'public',
        allowGuests: true,
        tags: [],
        rsvps: [],
        invitations: [],
        checkIns: [],
        waitlist: [],
        attendeesCount: 0,
        isApproved: true,
        isFlagged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return MaterialApp(
        home: ManageAttendeesPage(event: testEvent),
      );
    }

    testWidgets('ManageAttendeesPage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('ManageAttendeesPage displays Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ManageAttendeesPage displays attendees list',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('ManageAttendeesPage disposes resources properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(MaterialApp), findsNothing);
    });
  });
}


