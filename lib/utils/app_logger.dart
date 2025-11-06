import 'package:flutter/foundation.dart';

/// Log levels for filtering console output
enum LogLevel {
  none, // No logging
  error, // Only errors
  warning, // Errors and warnings
  info, // Errors, warnings, and info
  debug, // Everything including debug messages
}

/// Centralized logging utility for the app
/// Respects build mode and log level settings
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  /// Current log level - set this to control what appears in console
  /// Set to LogLevel.error for production-like experience
  /// Set to LogLevel.warning to see only important issues
  LogLevel _logLevel = kDebugMode ? LogLevel.warning : LogLevel.none;

  /// Set the log level
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  /// Get current log level
  LogLevel get logLevel => _logLevel;

  /// Log an error message (always shown unless LogLevel.none)
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (_logLevel.index >= LogLevel.error.index) {
      debugPrint('❌ ERROR: $message');
      if (error != null) debugPrint('   Details: $error');
      if (stackTrace != null && kDebugMode) {
        debugPrint('   Stack: $stackTrace');
      }
    }
  }

  /// Log a warning message
  void warning(String message) {
    if (_logLevel.index >= LogLevel.warning.index) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  /// Log an info message
  void info(String message) {
    if (_logLevel.index >= LogLevel.info.index) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log a debug message (verbose, only in debug builds with debug level)
  void debug(String message) {
    if (kDebugMode && _logLevel.index >= LogLevel.debug.index) {
      debugPrint('🔍 DEBUG: $message');
    }
  }

  /// Log a performance issue
  void performance(String message) {
    if (_logLevel.index >= LogLevel.warning.index) {
      debugPrint('🐌 PERFORMANCE: $message');
    }
  }

  /// Log a network request (only in debug level)
  void network(String message) {
    if (kDebugMode && _logLevel.index >= LogLevel.debug.index) {
      debugPrint('🌐 NETWORK: $message');
    }
  }

  /// Log a socket event (only in debug level)
  void socket(String message) {
    if (kDebugMode && _logLevel.index >= LogLevel.debug.index) {
      debugPrint('📡 SOCKET: $message');
    }
  }

  /// Convenience getters for quick logging
  static AppLogger get instance => _instance;
  static void e(String msg, {Object? error, StackTrace? st}) =>
      _instance.error(msg, error: error, stackTrace: st);
  static void w(String msg) => _instance.warning(msg);
  static void i(String msg) => _instance.info(msg);
  static void d(String msg) => _instance.debug(msg);
  static void p(String msg) => _instance.performance(msg);
  static void n(String msg) => _instance.network(msg);
  static void s(String msg) => _instance.socket(msg);
}
