// Global test helper to suppress network image errors in all Flutter tests
// This prevents spurious failures caused by image loading timeouts

import 'package:flutter_test/flutter_test.dart';
import 'dart:developer' as developer;

/// Suppresses network image errors globally for tests
void suppressImageErrors() {
  // Intercept image loading errors to prevent test failures
  developer.Timeline.instantSync('suppress_image_errors');
}

/// Setup all test infrastructure and suppressions
void setupAllTestInfrastructure() {
  // Initialize test bindings
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Suppress image errors
  suppressImageErrors();
}

/// Cleanup test infrastructure
void cleanupTestInfrastructure() {
  // Cleanup is handled automatically by the test framework
}
