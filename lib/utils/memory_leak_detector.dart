import 'dart:async';
import '../utils/app_logger.dart';

/// Detects memory leaks by tracking streams, subscriptions, and resource lifecycle.
/// Ensures all streams, subscriptions, controllers, and disposables are properly cleaned up.
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  final _logger = AppLogger();
  final Map<String, TrackedResource> _trackedResources = {};
  bool _isMonitoring = false;
  Timer? _leakCheckTimer;

  // ============================================================================
  // MONITORING & TRACKING
  // ============================================================================

  /// Start memory leak detection
  void startMonitoring() {
    _isMonitoring = true;
    _startPeriodicCheck();
    _logger.info('🔍 Memory leak detection started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _leakCheckTimer?.cancel();
    _logger.info('🔍 Memory leak detection stopped');
  }

  /// Register a stream subscription for tracking
  StreamSubscription<T> trackSubscription<T>(
    StreamSubscription<T> subscription, {
    required String name,
    String? context,
  }) {
    if (!_isMonitoring) return subscription;

    final id = _generateId(name);
    _trackedResources[id] = TrackedResource(
      id: id,
      name: name,
      type: 'StreamSubscription',
      context: context,
      createdAt: DateTime.now(),
    );

    _logger.debug('📌 Tracked StreamSubscription: $name');

    return _SubscriptionWrapper(subscription, id, this);
  }

  /// Register a StreamController for tracking
  StreamController<T> trackStreamController<T>(
    StreamController<T> controller, {
    required String name,
    String? context,
  }) {
    if (!_isMonitoring) return controller;

    final id = _generateId(name);
    _trackedResources[id] = TrackedResource(
      id: id,
      name: name,
      type: 'StreamController',
      context: context,
      createdAt: DateTime.now(),
    );

    _logger.debug('📌 Tracked StreamController: $name');

    // Note: Returns original controller. Disposal must be tracked manually
    // by calling untrackResource() when close() is called.
    return controller;
  }

  /// Register a Timer for tracking
  Timer trackTimer(
    Timer timer, {
    required String name,
    String? context,
  }) {
    if (!_isMonitoring) return timer;

    final id = _generateId(name);
    _trackedResources[id] = TrackedResource(
      id: id,
      name: name,
      type: 'Timer',
      context: context,
      createdAt: DateTime.now(),
    );

    _logger.debug('📌 Tracked Timer: $name');
    return timer;
  }

  /// Register a generic disposable resource
  void trackResource(
    Object resource, {
    required String name,
    required String type,
    String? context,
  }) {
    if (!_isMonitoring) return;

    final id = _generateId(name);
    _trackedResources[id] = TrackedResource(
      id: id,
      name: name,
      type: type,
      context: context,
      createdAt: DateTime.now(),
    );

    _logger.debug('📌 Tracked $type: $name');
  }

  /// Mark a resource as disposed (remove from leak detection)
  void untrackResource(String name) {
    if (!_isMonitoring) return;

    final entriestoRemove = _trackedResources.entries
        .where((e) => e.value.name == name)
        .map((e) => e.key)
        .toList();

    for (final id in entriestoRemove) {
      final resource = _trackedResources.remove(id);
      if (resource != null) {
        final aliveMs =
            DateTime.now().difference(resource.createdAt).inMilliseconds;
        _logger
            .debug('✅ Untracked ${resource.type}: $name (alive ${aliveMs}ms)');
      }
    }
  }

  // ============================================================================
  // LEAK DETECTION & ANALYSIS
  // ============================================================================

  /// Get all currently tracked resources
  Map<String, TrackedResource> getTrackedResources() {
    return Map.unmodifiable(_trackedResources);
  }

  /// Find resources that have been alive for too long
  List<TrackedResource> getLongLivedResources({int maxAgeSeconds = 3600}) {
    final threshold = DateTime.now().subtract(Duration(seconds: maxAgeSeconds));

    return _trackedResources.values
        .where((r) => r.createdAt.isBefore(threshold))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Find potential memory leaks (resources created but never disposed)
  List<String> detectPotentialLeaks() {
    final leaks = <String>[];

    // Resources created more than 1 hour ago are likely leaks
    final longLived = getLongLivedResources(maxAgeSeconds: 3600);

    for (final resource in longLived) {
      leaks.add(
        '🔴 POTENTIAL LEAK: ${resource.type} "${resource.name}" '
        '(created ${_formatDuration(DateTime.now().difference(resource.createdAt))} ago)${resource.context != null ? ' in ${resource.context}' : ''}',
      );
    }

    // Resources that are typically short-lived but are still allocated
    final subscriptions = _trackedResources.values
        .where((r) => r.type == 'StreamSubscription')
        .where((r) => DateTime.now().difference(r.createdAt).inMinutes > 5);

    for (final subscription in subscriptions) {
      leaks.add(
        '🟡 LONG-LIVED: ${subscription.type} "${subscription.name}" '
        '(${_formatDuration(DateTime.now().difference(subscription.createdAt))})${subscription.context != null ? ' in ${subscription.context}' : ''}',
      );
    }

    return leaks;
  }

  /// Print detailed memory report
  void printMemoryReport() {
    _logger.info('═══════════════════════════════════════════════════');
    _logger.info('🧠 MEMORY LEAK DETECTION REPORT');
    _logger.info('═══════════════════════════════════════════════════');

    if (_trackedResources.isEmpty) {
      _logger.info('✅ No resources currently tracked');
    } else {
      _logger
          .info('📊 Currently Tracked Resources: ${_trackedResources.length}');
      _logger.info('');

      // Group by type
      final byType = <String, List<TrackedResource>>{};
      for (final resource in _trackedResources.values) {
        byType.putIfAbsent(resource.type, () => []).add(resource);
      }

      for (final type in byType.keys) {
        final resources = byType[type]!;
        _logger.info('$type (${resources.length}):');
        for (final resource in resources) {
          final age = DateTime.now().difference(resource.createdAt);
          _logger.info(
            '  • ${resource.name} (${_formatDuration(age)})${resource.context != null ? ' - ${resource.context}' : ''}',
          );
        }
        _logger.info('');
      }
    }

    // Detect leaks
    final leaks = detectPotentialLeaks();
    if (leaks.isNotEmpty) {
      _logger.info('⚠️ POTENTIAL MEMORY LEAKS DETECTED:');
      for (final leak in leaks) {
        _logger.info(leak);
      }
    } else {
      _logger.info('✅ No potential memory leaks detected');
    }

    _logger.info('═══════════════════════════════════════════════════');
  }

  // ============================================================================
  // PERIODIC CHECKING
  // ============================================================================

  void _startPeriodicCheck() {
    _leakCheckTimer?.cancel();
    _leakCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        final leaks = detectPotentialLeaks();
        if (leaks.isNotEmpty) {
          _logger.warning('⚠️ ${leaks.length} potential memory leaks detected');
          for (final leak in leaks) {
            _logger.warning(leak);
          }
        }
      },
    );
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  String _generateId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${name}_$timestamp';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  void dispose() {
    _leakCheckTimer?.cancel();
    _trackedResources.clear();
    _isMonitoring = false;
    _logger.info('♻️ MemoryLeakDetector disposed');
  }
}

/// Tracked resource information
class TrackedResource {
  final String id;
  final String name;
  final String type; // StreamSubscription, StreamController, Timer, etc.
  final DateTime createdAt;
  final String? context;
  bool isDisposed = false;

  TrackedResource({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.context,
  });

  Duration get age => DateTime.now().difference(createdAt);

  @override
  String toString() => '$type: $name (${age.inSeconds}s)';
}

/// Wrapper for StreamSubscription to auto-track disposal
class _SubscriptionWrapper<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final String _id;
  final MemoryLeakDetector _detector;
  bool _isCancelled = false;

  _SubscriptionWrapper(this._inner, this._id, this._detector);

  @override
  Future<void> cancel() async {
    if (!_isCancelled) {
      _isCancelled = true;
      _detector.untrackResource(_id);
    }
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();
}
