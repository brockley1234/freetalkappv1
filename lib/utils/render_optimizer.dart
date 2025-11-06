import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

/// Detects and prevents unnecessary widget rebuilds that harm performance.
/// Tracks rebuild frequency, identifies problematic patterns, and provides
/// optimization recommendations.
class RenderOptimizer {
  static final RenderOptimizer _instance = RenderOptimizer._internal();
  factory RenderOptimizer() => _instance;
  RenderOptimizer._internal();

  final _logger = AppLogger();
  final Map<String, RebuildInfo> _rebuildStats = {};
  final Map<String, DateTime> _lastRebuildTime = {};
  bool _isMonitoring = false;

  // ============================================================================
  // MONITORING & TRACKING
  // ============================================================================

  /// Start monitoring widget rebuild patterns
  void startMonitoring() {
    _isMonitoring = true;
    _logger.info('📊 Render optimization monitoring started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _logger.info('📊 Render optimization monitoring stopped');
  }

  /// Track a widget rebuild
  void trackRebuild(String widgetName, {Duration? duration}) {
    if (!_isMonitoring) return;

    if (!_rebuildStats.containsKey(widgetName)) {
      _rebuildStats[widgetName] = RebuildInfo(
        widgetName: widgetName,
        rebuildCount: 0,
        lastRebuildTime: DateTime.now(),
        averageRebuildTime: 0,
      );
    }

    final stats = _rebuildStats[widgetName]!;
    final now = DateTime.now();

    // Update statistics
    stats.rebuildCount++;
    stats.lastRebuildTime = now;
    if (duration != null) {
      stats.averageRebuildTime =
          (stats.averageRebuildTime + duration.inMilliseconds) / 2;
    }

    // Check for excessive rebuilds
    if (_lastRebuildTime.containsKey(widgetName)) {
      final lastTime = _lastRebuildTime[widgetName]!;
      final timeSinceLastRebuild = now.difference(lastTime);

      if (timeSinceLastRebuild.inMilliseconds < 16) {
        // Less than 16ms = multiple rebuilds per frame
        stats.excessiveRebuildCount++;

        if (stats.excessiveRebuildCount > 5) {
          _logger.warning(
            '⚠️ Excessive rebuilds detected: $widgetName (${stats.excessiveRebuildCount} times)',
          );
        }
      }
    }

    _lastRebuildTime[widgetName] = now;

    // Log if rebuild is too slow
    if (duration != null && duration.inMilliseconds > 16) {
      _logger.warning(
        '🐌 Slow rebuild: $widgetName (${duration.inMilliseconds}ms)',
      );
    }
  }

  /// Get rebuild statistics for a widget
  RebuildInfo? getStats(String widgetName) {
    return _rebuildStats[widgetName];
  }

  /// Get all rebuild statistics
  Map<String, RebuildInfo> getAllStats() {
    return Map.unmodifiable(_rebuildStats);
  }

  /// Reset statistics
  void resetStats([String? widgetName]) {
    if (widgetName != null) {
      _rebuildStats.remove(widgetName);
      _lastRebuildTime.remove(widgetName);
    } else {
      _rebuildStats.clear();
      _lastRebuildTime.clear();
    }
    _logger.debug('🔄 Rebuild statistics reset');
  }

  /// Get performance recommendations based on rebuild patterns
  List<String> getRecommendations() {
    final recommendations = <String>[];

    for (final entry in _rebuildStats.entries) {
      final stats = entry.value;

      if (stats.rebuildCount > 100 && stats.excessiveRebuildCount > 10) {
        recommendations.add(
          '🔴 ${stats.widgetName}: Very high rebuild frequency (${stats.rebuildCount} rebuilds). '
          'Consider using Provider with .select() to listen only to needed values.',
        );
      } else if (stats.rebuildCount > 50 && stats.excessiveRebuildCount > 5) {
        recommendations.add(
          '🟠 ${stats.widgetName}: High rebuild frequency (${stats.rebuildCount} rebuilds). '
          'Check for unnecessary state changes or context listeners.',
        );
      }

      if (stats.averageRebuildTime > 16) {
        recommendations.add(
          '🟡 ${stats.widgetName}: Slow rebuilds (${stats.averageRebuildTime.toStringAsFixed(1)}ms avg). '
          'Optimize build() method or use const constructors.',
        );
      }
    }

    return recommendations;
  }

  /// Print detailed performance report
  void printPerformanceReport() {
    _logger.info('═══════════════════════════════════════════════════');
    _logger.info('📊 RENDER PERFORMANCE REPORT');
    _logger.info('═══════════════════════════════════════════════════');

    if (_rebuildStats.isEmpty) {
      _logger.info('ℹ️ No rebuild data collected yet');
      return;
    }

    // Sort by rebuild count (highest first)
    final sorted = _rebuildStats.entries.toList()
      ..sort((a, b) => b.value.rebuildCount.compareTo(a.value.rebuildCount));

    for (final entry in sorted) {
      final stats = entry.value;
      final severity = _getSeverity(stats);

      _logger.info(
        '$severity ${stats.widgetName}'
        '\n   Rebuilds: ${stats.rebuildCount} (${stats.excessiveRebuildCount} excessive)'
        '\n   Avg Time: ${stats.averageRebuildTime.toStringAsFixed(1)}ms'
        '\n   Last: ${_formatTime(stats.lastRebuildTime)}',
      );
    }

    _logger.info('═══════════════════════════════════════════════════');

    final recommendations = getRecommendations();
    if (recommendations.isNotEmpty) {
      _logger.info('💡 OPTIMIZATION RECOMMENDATIONS:');
      for (final rec in recommendations) {
        _logger.info(rec);
      }
    } else {
      _logger.info('✅ No problematic rebuild patterns detected');
    }

    _logger.info('═══════════════════════════════════════════════════');
  }

  String _getSeverity(RebuildInfo stats) {
    if (stats.excessiveRebuildCount > 10 || stats.rebuildCount > 100) {
      return '🔴';
    } else if (stats.excessiveRebuildCount > 5 || stats.rebuildCount > 50) {
      return '🟠';
    } else if (stats.averageRebuildTime > 16) {
      return '🟡';
    }
    return '🟢';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 1) {
      return 'just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  void dispose() {
    _rebuildStats.clear();
    _lastRebuildTime.clear();
    _isMonitoring = false;
    _logger.info('♻️ RenderOptimizer disposed');
  }
}

/// Rebuild statistics for a widget
class RebuildInfo {
  final String widgetName;
  int rebuildCount;
  int excessiveRebuildCount = 0;
  DateTime lastRebuildTime;
  double averageRebuildTime;

  RebuildInfo({
    required this.widgetName,
    required this.rebuildCount,
    required this.lastRebuildTime,
    required this.averageRebuildTime,
  });

  @override
  String toString() =>
      '$widgetName: $rebuildCount rebuilds (avg ${averageRebuildTime.toStringAsFixed(1)}ms)';
}

/// Mixin for tracking widget rebuilds
mixin RenderTracking<T extends StatefulWidget> on State<T> {
  final _renderOptimizer = RenderOptimizer();
  late Stopwatch _buildStopwatch;

  void initRenderTracking(String widgetName) {
    _renderOptimizer.startMonitoring();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    _buildStopwatch = Stopwatch()..start();
    super.didUpdateWidget(oldWidget);
  }

  void trackBuildTime() {
    if (_buildStopwatch.isRunning) {
      _buildStopwatch.stop();
      _renderOptimizer.trackRebuild(
        runtimeType.toString(),
        duration: _buildStopwatch.elapsed,
      );
    }
  }

  void printRenderReport() {
    _renderOptimizer.printPerformanceReport();
  }
}

/// Provider mixin for selective rebuilding
mixin SelectiveNotifier on ChangeNotifier {
  final _subscribers = <Function(), ValueNotifier<int>>{};
  int _changeCounter = 0;

  /// Register a selective listener that only rebuilds on specific data changes
  void addSelectiveListener(Function() selector, Function() callback) {
    final lastValue = ValueNotifier(_changeCounter);
    _subscribers[selector] = lastValue;
    lastValue.addListener(() {
      callback();
    });
  }

  /// Call only when specific data actually changes
  void notifySelectiveListeners(Function() changedDataCheck) {
    _changeCounter++;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final listener in _subscribers.values) {
      listener.dispose();
    }
    _subscribers.clear();
    super.dispose();
  }
}

/// Wrapper widget to prevent unnecessary rebuilds of child
class RebuildPreventer extends StatelessWidget {
  final Widget child;
  final Key? childKey;

  const RebuildPreventer({
    super.key,
    required this.child,
    this.childKey,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  /// Use this to build child without parent rebuilds
  static Widget wrap(Widget child) {
    return RebuildPreventer(child: child);
  }
}

/// Detects when a widget rebuilds too frequently
class RebuildDetector extends StatefulWidget {
  final Widget child;
  final String identifier;
  final Duration threshold;
  final Function(int count)? onExcessiveRebuild;

  const RebuildDetector({
    super.key,
    required this.child,
    required this.identifier,
    this.threshold = const Duration(milliseconds: 100),
    this.onExcessiveRebuild,
  });

  @override
  State<RebuildDetector> createState() => _RebuildDetectorState();
}

class _RebuildDetectorState extends State<RebuildDetector> {
  int _rebuildCount = 0;
  DateTime? _firstRebuildTime;
  final _renderOptimizer = RenderOptimizer();

  @override
  void didUpdateWidget(covariant Widget oldWidget) {
    if (oldWidget is! RebuildDetector) {
      super.didUpdateWidget(oldWidget as RebuildDetector);
      return;
    }

    super.didUpdateWidget(oldWidget);

    final now = DateTime.now();
    _firstRebuildTime ??= now;

    _rebuildCount++;

    final timeSinceFirst = now.difference(_firstRebuildTime!);
    if (timeSinceFirst > widget.threshold) {
      // Time window expired, reset
      _rebuildCount = 0;
      _firstRebuildTime = null;
    }

    _renderOptimizer.trackRebuild(widget.identifier);
    widget.onExcessiveRebuild?.call(_rebuildCount);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
