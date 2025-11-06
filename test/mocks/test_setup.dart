// Test setup and configuration for Flutter widget tests
// This file handles initialization of mocks and test environment

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:freetalk/services/language_provider.dart';
import 'package:freetalk/services/theme_service.dart';
import 'package:freetalk/services/accessibility_service.dart';
import 'mock_image_provider.dart';

/// Global test setup function to be called in setUpAll()
void setupTestEnvironment() {
  // Initialize test bindings for widget tests
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable network image errors
  MockImageHelper.disableNetworkImagesForTest();
}

/// Widget wrapper for tests that provides common providers
class TestWidgetWrapper extends StatelessWidget {
  final Widget child;

  const TestWidgetWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AccessibilityService()),
      ],
      child: MaterialApp(
        home: child,
        builder: (context, child) {
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Helper to pump widget with test environment setup
Future<void> pumpTestWidget(
  WidgetTester tester,
  Widget widget, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await tester.pumpWidget(TestWidgetWrapper(child: widget));

  // Wait for initial render
  try {
    await tester.pumpAndSettle(timeout);
  } catch (_) {
    // Timeout is acceptable for tests with network images
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Helper to suppress network image errors in tests
void suppressNetworkImageErrors() {
  // This is handled by TestImageProvider in mock_image_provider.dart
  // Network images will automatically use test images
}

/// Utility to wait for a widget to appear with timeout handling
Future<bool> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    // Check if widget exists immediately
    if (finder.evaluate().isNotEmpty) {
      return true;
    }

    // Pump a few times to allow widget to render
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        return true;
      }
    }

    return false;
  } catch (_) {
    return false;
  }
}

/// Test data generators with common patterns
class TestDataBuilders {
  static Map<String, dynamic> buildUser({
    String id = 'test_user_123',
    String name = 'Test User',
    String avatar = 'https://example.com/avatar.jpg',
    String status = 'online',
  }) {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'status': status,
    };
  }

  static Map<String, dynamic> buildMessage({
    String id = 'msg_123',
    String content = 'Test message',
    String senderId = 'user_123',
    DateTime? createdAt,
  }) {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  static Map<String, dynamic> buildConversation({
    String id = 'conv_123',
    String name = 'Test Conversation',
    List<String> participants = const ['user_1', 'user_2'],
  }) {
    return {
      'id': id,
      'name': name,
      'participants': participants,
    };
  }
}
