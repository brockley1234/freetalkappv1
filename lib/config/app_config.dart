import 'package:flutter/foundation.dart';

/// Environment configuration for the app
enum Environment {
  development,
  staging,
  production,
}

class AppConfig {
  // Current environment - Uses compile-time constants for production safety
  // In release mode, ALWAYS uses production (no localhost possible)
  static const Environment environment =
      kDebugMode ? Environment.development : Environment.production;

  // App Information
  /// App name
  static const String appName = 'FreeTalk';
  static const String appVersion = '2.0.4'; // Updated to match pubspec.yaml

  // Development override for testing on physical devices/emulators
  // Set this to your computer's local IP when testing on devices
  // Leave as null to use localhost (only works in browser/desktop)
  // Example: 'http://192.168.1.100:5000'
  static const String? developmentOverride = null;

  // API Configuration based on environment
  static String get baseApi {
    // CRITICAL: In release builds (kReleaseMode), ONLY production URL is used
    // This prevents localhost URLs from ever being used in Play Store builds
    if (kReleaseMode) {
      return 'https://freetalk.site'; // Production only for release builds
    }

    // Check for development override (for testing on devices)
    if (environment == Environment.development && developmentOverride != null) {
      return developmentOverride!;
    }

    switch (environment) {
      case Environment.development:
        return 'http://localhost:5000';
      case Environment.staging:
        return 'https://freetalk.site';
      case Environment.production:
        return 'https://freetalk.site';
    }
  }

  static String get baseUrl => '$baseApi/api';
  static String get videosbaseUrl => '$baseApi/api/videos';
  static String get messagebaseUrl => '$baseApi/api/messages';

  // Web base URL for deep links (e.g., https://freetalk.site/post/123)
  static String get webBaseUrl => 'https://freetalk.site';

  // API Keys
  // NOTE: Giphy API key is now stored securely on the backend
  // Use the /api/giphy endpoints instead of direct API calls
  // @deprecated - Use backend proxy at /api/giphy/search instead
  @Deprecated('Use backend proxy at /api/giphy/search instead')
  static const String giphyApiKey = ''; // Removed for security - use backend proxy

  // Feature Flags
  static const bool enableAnalytics = !kDebugMode;
  static const bool enableCrashReporting = !kDebugMode;

  // Logging
  static const bool enableDebugLogs = kDebugMode;
  static const bool enableNetworkLogs = kDebugMode;

  // Cache Configuration
  static const int cacheMaxAge = 3600; // 1 hour in seconds
  static const int imageCacheSize = 100; // Max number of cached images

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // Pagination
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // File Upload Limits
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxFilesPerPost = 10;

  // Rate Limiting (client-side)
  static const Duration minTimeBetweenRequests = Duration(milliseconds: 100);

  // Token Configuration
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // Environment Info for debugging
  static String get environmentName {
    switch (environment) {
      case Environment.development:
        return 'Development';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Production';
    }
  }

  static bool get isProduction => environment == Environment.production;
  static bool get isDevelopment => environment == Environment.development;
  static bool get isStaging => environment == Environment.staging;

  // Print configuration (for debugging)
  static void printConfig() {
    if (kDebugMode) {
      print('=== App Configuration ===');
      print('Environment: $environmentName');
      print('Base API: $baseApi');
      print('Base URL: $baseUrl');
      print('Debug Logs: $enableDebugLogs');
      print('Analytics: $enableAnalytics');
      print('========================');
    }
  }
}
