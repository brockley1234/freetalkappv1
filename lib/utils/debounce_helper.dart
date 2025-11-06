import 'dart:async';

/// Helper class to debounce function calls and batch state updates
class DebounceHelper {
  Timer? _debounceTimer;
  final int delayMilliseconds;
  late Function() _callback;

  DebounceHelper({this.delayMilliseconds = 100});

  /// Call this with your callback function
  void debounce(Function() callback) {
    _callback = callback;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      _callback.call();
    });
  }

  /// Cancel any pending debounced calls
  void cancel() {
    _debounceTimer?.cancel();
  }

  /// Dispose when done
  void dispose() {
    cancel();
  }
}

/// Batch updates helper - collect multiple updates and apply them once
class BatchUpdateHelper {
  final Map<String, dynamic> _pendingUpdates = {};
  Timer? _batchTimer;
  final int delayMilliseconds;
  late Function(Map<String, dynamic>) _onBatchReady;

  BatchUpdateHelper({this.delayMilliseconds = 50});

  /// Queue an update to be batched
  void queueUpdate(String key, dynamic value) {
    _pendingUpdates[key] = value;
    _resetBatchTimer();
  }

  /// Set callback to be called when batch is ready
  void onBatchReady(Function(Map<String, dynamic>) callback) {
    _onBatchReady = callback;
  }

  void _resetBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (_pendingUpdates.isNotEmpty) {
        _onBatchReady(_pendingUpdates);
        _pendingUpdates.clear();
      }
    });
  }

  void dispose() {
    _batchTimer?.cancel();
    _pendingUpdates.clear();
  }
}

/// Throttle helper - execute at most once per time interval
class ThrottleHelper {
  late Function() _callback;
  Timer? _throttleTimer;
  final int intervalMilliseconds;
  bool _hasCallPending = false;

  ThrottleHelper({this.intervalMilliseconds = 1000});

  void throttle(Function() callback) {
    _callback = callback;

    if (_throttleTimer == null) {
      // First call - execute immediately
      _callback.call();
      _throttleTimer = Timer(Duration(milliseconds: intervalMilliseconds), () {
        _throttleTimer = null;
        if (_hasCallPending) {
          _hasCallPending = false;
          throttle(_callback);
        }
      });
    } else {
      // Subsequent calls - mark for pending execution
      _hasCallPending = true;
    }
  }

  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _hasCallPending = false;
  }
}
