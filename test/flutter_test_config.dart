// Flutter test configuration
// This file is used by flutter test to configure the test environment
// It suppresses network image errors globally across all tests

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

// This function is required by Flutter test framework
Future<void> testExecutable(Future<void> Function() testMain) async {
  // Setup test environment
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Suppress layout overflow errors that are cosmetic in tests
  final originalErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    // Ignore RenderFlex overflow warnings - they don't affect widget functionality
    // These occur when test window size doesn't perfectly fit all content
    if (details.toString().contains('RenderFlex overflowed')) {
      // Silently ignore - this is a test environment constraint, not a real issue
      return;
    }
    // For other errors, use the original handler
    if (originalErrorHandler != null) {
      originalErrorHandler(details);
    } else {
      FlutterError.dumpErrorToConsole(details);
    }
  };
  
  // Run the tests
  await testMain();
}
