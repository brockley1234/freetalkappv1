import 'package:flutter/foundation.dart';
import 'dart:async';

/// Web-specific performance optimizations
class WebPerformanceOptimizer {
  // Singleton
  static final WebPerformanceOptimizer _instance =
      WebPerformanceOptimizer._internal();

  factory WebPerformanceOptimizer() {
    return _instance;
  }

  WebPerformanceOptimizer._internal();

  // Frame throttling for web
  bool _shouldRender = true;
  Timer? _renderThrottleTimer;
  final int _throttleMs = 50; // ~20fps max on heavy operations

  /// Throttle expensive rendering operations on web
  bool shouldRenderExpensiveWidget() {
    if (!kIsWeb) return true; // Always render on mobile

    if (!_shouldRender) return false;

    _shouldRender = false;
    _renderThrottleTimer?.cancel();
    _renderThrottleTimer = Timer(
      Duration(milliseconds: _throttleMs),
      () => _shouldRender = true,
    );

    return true;
  }

  /// Check if we should render images (throttle parallel loads)
  /// Returns true if we should load this image now, false if we should defer
  static bool shouldLoadImage(int imageIndex, int totalImages) {
    if (!kIsWeb) return true;

    // On web, only load 3-4 images in parallel to avoid network congestion
    const maxParallelImages = 3;
    // Spread remaining images over time
    const delayBetweenBatches = 200; // ms

    return (imageIndex % maxParallelImages == 0) ||
        (DateTime.now().millisecondsSinceEpoch %
                (maxParallelImages * delayBetweenBatches) >
            100);
  }

  /// Disable expensive animations on web (shadows, blur, etc)
  static bool enableExpensiveEffects() {
    return !kIsWeb;
  }

  /// Reduce animation duration on web for snappier UI
  static Duration adjustAnimationDuration(Duration original) {
    if (!kIsWeb) return original;

    // Reduce duration by 40% on web for faster perceived performance
    return Duration(
      milliseconds: (original.inMilliseconds * 0.6).toInt(),
    );
  }

  void dispose() {
    _renderThrottleTimer?.cancel();
  }
}
