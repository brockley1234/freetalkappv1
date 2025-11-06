import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Profiles app startup time and identifies performance bottlenecks during initialization.
/// Measures each initialization phase to find blocking operations on the main thread.
class StartupProfiler {
  static final StartupProfiler _instance = StartupProfiler._internal();
  factory StartupProfiler() => _instance;
  StartupProfiler._internal();

  final _logger = AppLogger();
  final Map<String, PhaseMetrics> _phases = {};
  late DateTime _appStartTime;
  DateTime? _firstFrameTime;
  bool _isProfilingEnabled = kDebugMode;

  // Startup phases
  static const String phaseAppStart = 'app_start';
  static const String phaseFirebaseInit = 'firebase_init';
  static const String phaseThemeInit = 'theme_init';
  static const String phaseSocketConnect = 'socket_connect';
  static const String phaseDataLoad = 'data_load';
  static const String phaseUIBuild = 'ui_build';
  static const String phaseFirstFrame = 'first_frame';

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Start app profiling
  void startProfiling() {
    if (!_isProfilingEnabled) return;

    _appStartTime = DateTime.now();
    _phases.clear();
    _recordPhaseStart(phaseAppStart);
    _logger.info('🚀 App startup profiling started');
  }

  /// Enable/disable profiling
  void setProfiling(bool enabled) {
    _isProfilingEnabled = enabled;
  }

  // ============================================================================
  // PHASE TRACKING
  // ============================================================================

  /// Mark the start of an initialization phase
  void markPhaseStart(String phaseName) {
    if (!_isProfilingEnabled) return;
    _recordPhaseStart(phaseName);
  }

  /// Mark the end of an initialization phase and get duration
  Duration markPhaseEnd(String phaseName, {String? description}) {
    if (!_isProfilingEnabled) return Duration.zero;

    if (!_phases.containsKey(phaseName)) {
      _logger.warning('⚠️ Phase $phaseName was not started');
      return Duration.zero;
    }

    final metrics = _phases[phaseName]!;
    metrics.endTime = DateTime.now();
    metrics.duration = metrics.endTime!.difference(metrics.startTime);
    metrics.description = description;

    final durationMs = metrics.duration!.inMilliseconds;
    final severity = _getSeverity(durationMs);

    _logger.info(
      '$severity Phase complete: $phaseName (${durationMs}ms)${description != null ? ' - $description' : ''}',
    );

    return metrics.duration!;
  }

  /// Record that first frame has been rendered
  void markFirstFrame() {
    if (!_isProfilingEnabled) return;

    _firstFrameTime = DateTime.now();
    final totalMs = _firstFrameTime!.difference(_appStartTime).inMilliseconds;
    _logger.info('✅ First frame rendered in ${totalMs}ms');
  }

  void _recordPhaseStart(String phaseName) {
    _phases[phaseName] = PhaseMetrics(
      phaseName: phaseName,
      startTime: DateTime.now(),
    );
  }

  // ============================================================================
  // ANALYSIS & REPORTING
  // ============================================================================

  /// Get metrics for a specific phase
  PhaseMetrics? getPhaseMetrics(String phaseName) {
    return _phases[phaseName];
  }

  /// Get all phase metrics
  Map<String, PhaseMetrics> getAllMetrics() {
    return Map.unmodifiable(_phases);
  }

  /// Get total startup time from app start to first frame
  Duration getTotalStartupTime() {
    if (_firstFrameTime == null) {
      return DateTime.now().difference(_appStartTime);
    }
    return _firstFrameTime!.difference(_appStartTime);
  }

  /// Identify slow phases
  List<PhaseMetrics> getSlowPhases({int thresholdMs = 500}) {
    return _phases.values
        .where((p) =>
            p.duration != null && p.duration!.inMilliseconds > thresholdMs)
        .toList()
      ..sort((a, b) => (b.duration?.inMilliseconds ?? 0)
          .compareTo(a.duration?.inMilliseconds ?? 0));
  }

  /// Get optimization recommendations
  List<String> getRecommendations() {
    final recommendations = <String>[];
    final slowPhases = getSlowPhases(thresholdMs: 300);

    if (slowPhases.isEmpty) {
      recommendations.add('✅ Startup performance is good');
      return recommendations;
    }

    for (final phase in slowPhases) {
      final ms = phase.duration?.inMilliseconds ?? 0;
      final description = phase.description ?? phase.phaseName;

      if (ms > 2000) {
        recommendations.add(
          '🔴 CRITICAL: $description is very slow (${ms}ms). '
          'Consider making this operation async or deferring it.',
        );
      } else if (ms > 1000) {
        recommendations.add(
          '🟠 WARNING: $description is slow (${ms}ms). '
          'Look for synchronous/blocking operations.',
        );
      } else if (ms > 500) {
        recommendations.add(
          '🟡 CAUTION: $description is taking ${ms}ms. '
          'Consider optimization opportunities.',
        );
      }
    }

    // Check if first frame is slow
    final totalMs = getTotalStartupTime().inMilliseconds;
    if (totalMs > 2000) {
      recommendations.add(
        '🔴 Total startup time is ${totalMs}ms. '
        'Users may abandon the app. Consider lazy-loading non-critical features.',
      );
    }

    return recommendations;
  }

  /// Print detailed startup report
  void printStartupReport() {
    _logger.info('═══════════════════════════════════════════════════');
    _logger.info('🚀 APP STARTUP REPORT');
    _logger.info('═══════════════════════════════════════════════════');

    if (_phases.isEmpty) {
      _logger.info('ℹ️ No startup data collected');
      return;
    }

    // Print phases in order
    final sortedPhases = _phases.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    int phaseNumber = 1;
    for (final phase in sortedPhases) {
      if (phase.duration == null) {
        _logger.info(
          '⏳ Phase $phaseNumber (incomplete): ${phase.phaseName}',
        );
        continue;
      }

      final severity = _getSeverity(phase.duration!.inMilliseconds);
      final desc = phase.description != null ? ' - ${phase.description}' : '';

      _logger.info(
        '$severity Phase $phaseNumber: ${phase.phaseName} (${phase.duration!.inMilliseconds}ms)$desc',
      );
      phaseNumber++;
    }

    _logger.info('');

    // Summary
    final totalMs = getTotalStartupTime().inMilliseconds;
    final totalSeverity = _getSeverity(totalMs);
    _logger.info('$totalSeverity TOTAL STARTUP TIME: ${totalMs}ms');

    if (_firstFrameTime != null) {
      _logger.info(
          'First frame: ${_firstFrameTime!.difference(_appStartTime).inMilliseconds}ms');
    }

    _logger.info('═══════════════════════════════════════════════════');

    // Recommendations
    final recommendations = getRecommendations();
    _logger.info('💡 RECOMMENDATIONS:');
    for (final rec in recommendations) {
      _logger.info(rec);
    }

    _logger.info('═══════════════════════════════════════════════════');
  }

  /// Get detailed performance breakdown (% of total startup time)
  void printPerformanceBreakdown() {
    final totalMs = getTotalStartupTime().inMilliseconds.toDouble();

    _logger.info('═══════════════════════════════════════════════════');
    _logger.info('📊 STARTUP TIME BREAKDOWN');
    _logger.info('═══════════════════════════════════════════════════');

    final sortedPhases = _phases.values
        .where((p) => p.duration != null)
        .toList()
      ..sort((a, b) => (b.duration?.inMilliseconds ?? 0)
          .compareTo(a.duration?.inMilliseconds ?? 0));

    for (final phase in sortedPhases) {
      if (phase.duration == null) continue;

      final ms = phase.duration!.inMilliseconds;
      final percent =
          totalMs > 0 ? ((ms / totalMs) * 100).toStringAsFixed(1) : '0.0';
      final bar = _progressBar(ms / totalMs, 30);

      _logger.info(
        '${phase.phaseName.padRight(20)} $bar $percent% (${ms}ms)',
      );
    }

    _logger.info('═══════════════════════════════════════════════════');
  }

  String _getSeverity(int milliseconds) {
    if (milliseconds > 2000) return '🔴';
    if (milliseconds > 1000) return '🟠';
    if (milliseconds > 500) return '🟡';
    return '🟢';
  }

  String _progressBar(double fraction, int width) {
    final filled = (fraction * width).toInt();
    final empty = width - filled;
    return '[${('█' * filled)}${('░' * empty)}]';
  }

  // ============================================================================
  // MEMORY PROFILING
  // ============================================================================

  /// Helper to run a function and measure its execution time
  Future<T> measureAsync<T>(
    String label,
    Future<T> Function() function,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await function();
    } finally {
      stopwatch.stop();
      _logger.debug('⏱️ $label: ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Helper to run a sync function and measure execution time
  T measureSync<T>(
    String label,
    T Function() function,
  ) {
    final stopwatch = Stopwatch()..start();
    try {
      return function();
    } finally {
      stopwatch.stop();
      _logger.debug('⏱️ $label: ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  void dispose() {
    _phases.clear();
    _logger.info('♻️ StartupProfiler disposed');
  }
}

/// Metrics for a single startup phase
class PhaseMetrics {
  final String phaseName;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  String? description;

  PhaseMetrics({
    required this.phaseName,
    required this.startTime,
  });

  bool get isComplete => duration != null;

  @override
  String toString() =>
      '$phaseName: ${duration?.inMilliseconds ?? 0}ms${description != null ? ' ($description)' : ''}';
}

/// Profiling guard - ensures phase is marked complete even on error
class ProfiledOperation {
  final StartupProfiler profiler;
  final String phaseName;
  final String? description;

  ProfiledOperation(
    this.profiler,
    this.phaseName, {
    this.description,
  }) {
    profiler.markPhaseStart(phaseName);
  }

  void complete() {
    profiler.markPhaseEnd(phaseName, description: description);
  }

  Future<T> runAsync<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } finally {
      complete();
    }
  }

  T runSync<T>(T Function() operation) {
    try {
      return operation();
    } finally {
      complete();
    }
  }
}
