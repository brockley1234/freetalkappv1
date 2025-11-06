import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'app_logger.dart';

/// Performance monitoring utility for tracking app performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  bool _isMonitoring = kDebugMode; // Only monitor in debug mode
  final _logger = AppLogger();

  // Start tracking an operation
  void startOperation(String operationName) {
    if (!_isMonitoring) return;
    _operationStartTimes[operationName] = DateTime.now();
  }

  // End tracking and log the duration
  void endOperation(String operationName) {
    if (!_isMonitoring) return;

    final startTime = _operationStartTimes[operationName];
    if (startTime == null) {
      _logger.debug(
        'Performance: Operation "$operationName" was never started',
      );
      return;
    }

    final duration = DateTime.now().difference(startTime);

    // Store duration for analytics
    _operationDurations.putIfAbsent(operationName, () => []);
    _operationDurations[operationName]!.add(duration);

    // Log to console (debug level)
    _logger.debug(
      'Performance: $operationName took ${duration.inMilliseconds}ms',
    );

    // Warn if operation is slow (this appears as warning)
    if (duration.inMilliseconds > 1000) {
      _logger.performance('$operationName took ${duration.inMilliseconds}ms');
    }

    _operationStartTimes.remove(operationName);
  }

  // Track a future operation
  Future<T> trackFuture<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName);
      return result;
    } catch (e) {
      endOperation(operationName);
      rethrow;
    }
  }

  // Track a synchronous operation
  T trackSync<T>(String operationName, T Function() operation) {
    startOperation(operationName);
    try {
      final result = operation();
      endOperation(operationName);
      return result;
    } catch (e) {
      endOperation(operationName);
      rethrow;
    }
  }

  // Get average duration for an operation
  Duration? getAverageDuration(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  // Get statistics for an operation
  Map<String, dynamic> getOperationStats(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) {
      return {'count': 0};
    }

    final milliseconds = durations.map((d) => d.inMilliseconds).toList()
      ..sort();
    final count = milliseconds.length;
    final total = milliseconds.reduce((a, b) => a + b);
    final average = total / count;
    final min = milliseconds.first;
    final max = milliseconds.last;
    final median = count % 2 == 0
        ? (milliseconds[count ~/ 2] + milliseconds[count ~/ 2 - 1]) / 2
        : milliseconds[count ~/ 2].toDouble();

    return {
      'count': count,
      'total': total,
      'average': average.round(),
      'min': min,
      'max': max,
      'median': median.round(),
    };
  }

  // Print all operation statistics
  void printAllStats() {
    if (!_isMonitoring) return;

    debugPrint('\n📊 ========== PERFORMANCE STATISTICS ==========');
    for (final operationName in _operationDurations.keys) {
      final stats = getOperationStats(operationName);
      debugPrint('📈 $operationName:');
      debugPrint('   Count: ${stats['count']}');
      debugPrint('   Average: ${stats['average']}ms');
      debugPrint('   Min: ${stats['min']}ms');
      debugPrint('   Max: ${stats['max']}ms');
      debugPrint('   Median: ${stats['median']}ms');
    }
    debugPrint('============================================\n');
  }

  // Clear all tracked data
  void clear() {
    _operationStartTimes.clear();
    _operationDurations.clear();
  }

  // Enable/disable monitoring
  void setMonitoring(bool enabled) {
    _isMonitoring = enabled && kDebugMode;
  }

  // Monitor frame rendering
  void startFrameMonitoring() {
    if (!_isMonitoring) return;

    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        final buildDuration = timing.buildDuration;
        final rasterDuration = timing.rasterDuration;

        // Only report frames that are significantly slow (>50ms = major jank)
        // This reduces noise while still catching real issues
        if (buildDuration.inMilliseconds > 50) {
          _logger.performance('Slow build: ${buildDuration.inMilliseconds}ms');
        }

        if (rasterDuration.inMilliseconds > 50) {
          _logger.performance(
            'Slow raster: ${rasterDuration.inMilliseconds}ms',
          );
        }
      }
    });
  }
}
