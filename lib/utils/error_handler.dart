import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility for handling errors with automatic retry logic
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Retry a failed operation with exponential backoff
  Future<T> retryOperation<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      attempts++;

      try {
        return await operation();
      } catch (error) {
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          debugPrint('❌ Error not retryable: $error');
          rethrow;
        }

        // Check if we've exhausted all attempts
        if (attempts >= maxAttempts) {
          debugPrint(
            '❌ Max retry attempts ($maxAttempts) reached for operation',
          );
          rethrow;
        }

        // Log retry attempt
        debugPrint(
          '🔄 Retry attempt $attempts/$maxAttempts after ${delay.inSeconds}s delay',
        );
        debugPrint('   Error: $error');

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
  }

  /// Handle network errors specifically
  bool isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('failed host lookup');
  }

  /// Handle HTTP errors
  bool isRetryableHttpError(int? statusCode) {
    if (statusCode == null) return false;
    // Retry on server errors (500-599) and rate limiting (429)
    return statusCode >= 500 && statusCode < 600 || statusCode == 429;
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection error. Please check your internet connection.';
    }

    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Session expired. Please login again.';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'The requested resource was not found.';
    }

    if (errorStr.contains('server error') || errorStr.contains('500')) {
      return 'Server error. Please try again later.';
    }

    // Return the original error message if no match
    return error.toString();
  }

  /// Log error with context
  void logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalInfo,
  }) {
    debugPrint('❌ ERROR ${context != null ? 'in $context' : ''}');
    debugPrint('   Message: $error');

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      debugPrint('   Additional Info: $additionalInfo');
    }

    if (stackTrace != null && kDebugMode) {
      debugPrint('   Stack Trace:\n$stackTrace');
    }
  }

  /// Create a safe operation wrapper
  Future<T?> safeOperation<T>({
    required Future<T> Function() operation,
    required String operationName,
    T? fallback,
    bool silent = false,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (!silent) {
        logError(error, stackTrace, context: operationName);
      }
      return fallback;
    }
  }
}
