import 'dart:async';
import '../utils/app_logger.dart';

/// Service for optimizing Socket.IO connections with reconnection backoff and event throttling
class SocketOptimizationService {
  static final SocketOptimizationService _instance =
      SocketOptimizationService._internal();

  factory SocketOptimizationService() {
    return _instance;
  }

  SocketOptimizationService._internal();

  // Exponential backoff tracking for reconnection
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 1000; // milliseconds
  static const int _maxReconnectDelay = 30000; // 30 seconds max

  // Event throttling - prevents flooding from high-frequency events
  final Map<String, DateTime> _lastEventTime = {};
  final Map<String, dynamic> _lastEventData = {};
  final Map<String, Duration> _throttleDurations = {};

  /// Register a throttled event listener
  /// Only allows the callback to fire if at least [throttleDuration] has passed since last call
  void registerThrottledListener(
    String eventKey,
    Duration throttleDuration,
  ) {
    _throttleDurations[eventKey] = throttleDuration;
    _lastEventTime[eventKey] = DateTime.now().subtract(throttleDuration);
    AppLogger().debug(
        '📡 Registered throttled listener: $eventKey (${throttleDuration.inMilliseconds}ms)');
  }

  /// Check if an event should be processed or throttled
  bool shouldProcessEvent(String eventKey, dynamic eventData) {
    final throttleDuration = _throttleDurations[eventKey];
    if (throttleDuration == null) {
      return true; // No throttling registered
    }

    final lastTime = _lastEventTime[eventKey];
    if (lastTime == null) {
      _lastEventTime[eventKey] = DateTime.now();
      return true;
    }

    final timeSinceLastEvent = DateTime.now().difference(lastTime);
    if (timeSinceLastEvent >= throttleDuration) {
      _lastEventTime[eventKey] = DateTime.now();
      _lastEventData[eventKey] = eventData;
      return true;
    }

    // Store the data in case we need it later
    _lastEventData[eventKey] = eventData;
    AppLogger().debug(
        '🚫 Event throttled: $eventKey (${timeSinceLastEvent.inMilliseconds}ms ago)');
    return false;
  }

  /// Get the last event data for a throttled event
  dynamic getLastEventData(String eventKey) {
    return _lastEventData[eventKey];
  }

  /// Calculate exponential backoff delay for reconnection
  Duration getReconnectDelay() {
    // Formula: min(base * 2^attempt, max) + random jitter
    final exponentialDelay = _baseReconnectDelay * (1 << _reconnectAttempts);
    final delayMs = (exponentialDelay > _maxReconnectDelay
            ? _maxReconnectDelay
            : exponentialDelay)
        .toInt();

    // Add jitter (±10% of delay)
    final jitter = (delayMs * 0.1).toInt();
    final actualDelay =
        delayMs + (DateTime.now().millisecond % (jitter * 2)) - jitter;

    AppLogger().debug(
      '⏱️ Reconnect attempt ${_reconnectAttempts + 1}: waiting ${actualDelay}ms',
    );

    return Duration(milliseconds: actualDelay);
  }

  /// Increment reconnect attempts
  void incrementReconnectAttempts() {
    _reconnectAttempts++;
    AppLogger().debug(
      '🔄 Reconnect attempts: $_reconnectAttempts/$_maxReconnectAttempts',
    );
  }

  /// Reset reconnect attempts (call on successful connection)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    AppLogger().debug('✅ Reset reconnect attempts');
  }

  /// Check if we should continue attempting to reconnect
  bool shouldAttemptReconnect() {
    return _reconnectAttempts < _maxReconnectAttempts;
  }

  /// Get current reconnect attempt number
  int getCurrentReconnectAttempt() {
    return _reconnectAttempts;
  }

  /// Cancel any pending reconnect timer
  void cancelPendingReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    AppLogger().debug('🛑 Cancelled pending reconnect');
  }

  /// Get statistics about socket optimization
  Map<String, dynamic> getStats() {
    return {
      'reconnectAttempts': _reconnectAttempts,
      'maxReconnectAttempts': _maxReconnectAttempts,
      'throttledEvents': _throttleDurations.length,
      'lastEventDataCache': _lastEventData.length,
      'baseReconnectDelay': _baseReconnectDelay,
      'maxReconnectDelay': _maxReconnectDelay,
    };
  }

  /// Clear all socket optimization state
  void clear() {
    AppLogger().info('🧹 Clearing socket optimization state');
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _lastEventTime.clear();
    _lastEventData.clear();
    _throttleDurations.clear();
  }
}
