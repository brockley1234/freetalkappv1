import 'dart:async';
import '../utils/app_logger.dart';

/// Service for optimizing network requests with batching, deduplication, and smart retry logic
class NetworkOptimizationService {
  static final NetworkOptimizationService _instance =
      NetworkOptimizationService._internal();

  factory NetworkOptimizationService() {
    return _instance;
  }

  NetworkOptimizationService._internal();

  // Request deduplication cache - prevents duplicate requests
  final Map<String, Future<dynamic>> _pendingRequests = {};
  final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _deduplicationWindow = Duration(milliseconds: 500);

  // Request batching
  final Map<String, List<dynamic>> _batchQueue = {};
  final Map<String, Timer> _batchTimers = {};
  static const Duration _batchDelay = Duration(milliseconds: 100);

  // Exponential backoff tracking
  final Map<String, int> _retryCount = {};
  final Map<String, DateTime> _lastRetryTime = {};
  static const int _maxRetries = 3;

  /// Deduplicates requests - if the same request is made within the deduplication window,
  /// returns the pending request instead of making a new one
  Future<T> deduplicateRequest<T>(
    String key,
    Future<T> Function() requestFn,
  ) async {
    // Check if we have a pending request for this key
    if (_pendingRequests.containsKey(key)) {
      AppLogger().debug('🔄 Deduplicating request: $key');
      return _pendingRequests[key] as Future<T>;
    }

    // Check if we've made a similar request recently
    final lastTime = _lastRequestTime[key];
    if (lastTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(lastTime);
      if (timeSinceLastRequest < _deduplicationWindow) {
        AppLogger().debug(
          '⏱️ Request throttled (made ${timeSinceLastRequest.inMilliseconds}ms ago): $key',
        );
        // Wait for pending request if available
        if (_pendingRequests.containsKey(key)) {
          return _pendingRequests[key] as Future<T>;
        }
      }
    }

    // Create and store the pending request
    final pendingRequest = requestFn();
    _pendingRequests[key] = pendingRequest;
    _lastRequestTime[key] = DateTime.now();

    try {
      final result = await pendingRequest;
      AppLogger().debug('✅ Request completed: $key');
      return result;
    } catch (e) {
      AppLogger().error('❌ Request failed: $key', error: e);
      rethrow;
    } finally {
      // Clean up after a short delay to allow for additional calls
      Future.delayed(const Duration(milliseconds: 50), () {
        _pendingRequests.remove(key);
      });
    }
  }

  /// Batches multiple requests together and sends them in a single call
  /// Useful for combining multiple API calls that can be handled together
  void batchRequest<T>(
    String batchKey,
    dynamic request,
    void Function(List<dynamic> batch) onBatch,
  ) {
    // Initialize batch queue for this key if needed
    _batchQueue.putIfAbsent(batchKey, () => []);

    // Add request to batch
    _batchQueue[batchKey]!.add(request);

    // Cancel existing timer if present
    _batchTimers[batchKey]?.cancel();

    // If we've reached a batch size threshold (10), send immediately
    if (_batchQueue[batchKey]!.length >= 10) {
      _flushBatch(batchKey, onBatch);
    } else {
      // Otherwise, set a timer to send after delay
      _batchTimers[batchKey] = Timer(_batchDelay, () {
        _flushBatch(batchKey, onBatch);
      });
    }
  }

  void _flushBatch<T>(
    String batchKey,
    void Function(List<dynamic> batch) onBatch,
  ) {
    final batch = _batchQueue[batchKey];
    if (batch != null && batch.isNotEmpty) {
      AppLogger()
          .debug('📦 Flushing batch: $batchKey with ${batch.length} items');
      onBatch(batch);
      _batchQueue[batchKey] = [];
      _batchTimers[batchKey]?.cancel();
      _batchTimers.remove(batchKey);
    }
  }

  /// Implements exponential backoff retry logic
  /// Returns the delay before the next retry attempt
  Duration getExponentialBackoff(String key) {
    final currentRetry = _retryCount[key] ?? 0;

    if (currentRetry >= _maxRetries) {
      AppLogger().warning('⚠️ Max retries reached for: $key');
      return Duration.zero; // Signal that retries are exhausted
    }

    // Exponential backoff: 1s, 2s, 4s, 8s... with jitter
    final baseDelay = Duration(seconds: 1 << currentRetry); // 2^currentRetry
    final jitter = Duration(
      milliseconds: (currentRetry * 100 + 50), // Add some randomness
    );

    _retryCount[key] = currentRetry + 1;
    _lastRetryTime[key] = DateTime.now();

    final totalDelay = Duration(
      milliseconds: baseDelay.inMilliseconds + jitter.inMilliseconds,
    );

    AppLogger().debug(
      '🔄 Retry $currentRetry for $key - waiting ${totalDelay.inMilliseconds}ms',
    );

    return totalDelay;
  }

  /// Reset retry count for a key (call after successful request)
  void resetRetryCount(String key) {
    _retryCount.remove(key);
    _lastRetryTime.remove(key);
    AppLogger().debug('🔄 Reset retry count for: $key');
  }

  /// Check if a request should be retried
  bool shouldRetry(String key) {
    final retries = _retryCount[key] ?? 0;
    return retries < _maxRetries;
  }

  /// Get current retry count for a key
  int getRetryCount(String key) {
    return _retryCount[key] ?? 0;
  }

  /// Clear all pending state (useful for logout or app reset)
  void clear() {
    AppLogger().info('🧹 Clearing network optimization state');
    _pendingRequests.clear();
    _lastRequestTime.clear();
    _batchQueue.clear();
    _batchTimers.forEach((key, timer) => timer.cancel());
    _batchTimers.clear();
    _retryCount.clear();
    _lastRetryTime.clear();
  }

  /// Get statistics about pending requests
  Map<String, dynamic> getStats() {
    return {
      'pendingRequests': _pendingRequests.length,
      'batchedItems':
          _batchQueue.values.fold<int>(0, (sum, b) => sum + b.length),
      'retryingKeys': _retryCount.length,
      'deduplicationWindow': _deduplicationWindow.inMilliseconds,
      'maxRetries': _maxRetries,
    };
  }
}
