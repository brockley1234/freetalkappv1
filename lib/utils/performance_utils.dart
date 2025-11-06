import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'app_logger.dart';

/// Comprehensive performance utilities for image optimization, memory management,
/// and render performance monitoring.
class PerformanceUtils {
  static final PerformanceUtils _instance = PerformanceUtils._internal();
  factory PerformanceUtils() => _instance;
  PerformanceUtils._internal();

  final _logger = AppLogger();
  final Map<String, Completer<ui.Image>> _imageCache = {};
  late CacheManager _customCacheManager;
  int _totalBytesLoaded = 0;
  int _totalImagesLoaded = 0;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    try {
      _customCacheManager = CacheManager(
        Config(
          'performance_cache',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
        ),
      );
      _logger.info('✅ PerformanceUtils initialized with custom cache manager');
    } catch (e) {
      _logger.error('❌ Failed to initialize PerformanceUtils', error: e);
    }
  }

  // ============================================================================
  // IMAGE OPTIMIZATION & LAZY LOADING
  // ============================================================================

  /// Load and cache image with optimized memory usage
  /// Returns decoded image with memory-efficient dimensions
  Future<ui.Image> loadOptimizedImage(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
    bool compress = true,
  }) async {
    // Return cached image if available
    if (_imageCache.containsKey(imageUrl)) {
      return _imageCache[imageUrl]!.future;
    }

    final completer = Completer<ui.Image>();
    _imageCache[imageUrl] = completer;

    try {
      // Fetch from cache or network
      final file = await _customCacheManager.getSingleFile(imageUrl);

      // Decode with memory-efficient dimensions
      final bytes = await file.readAsBytes();
      _totalBytesLoaded += bytes.length;
      _totalImagesLoaded++;

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
        allowUpscaling: false,
      );

      final frame = await codec.getNextFrame();
      completer.complete(frame.image);

      _logger.debug(
        '✅ Loaded image: $imageUrl (${(bytes.length / 1024).toStringAsFixed(2)}KB)',
      );
    } catch (e) {
      _logger.error('❌ Failed to load image: $imageUrl', error: e);
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Lazy load image with callback when ready
  void lazyLoadImage(
    String imageUrl, {
    required Function(ui.Image) onSuccess,
    required Function(Object) onError,
    int? maxWidth,
    int? maxHeight,
  }) {
    // Load asynchronously to avoid blocking UI
    loadOptimizedImage(
      imageUrl,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    ).then(onSuccess).catchError(onError);
  }

  /// Compress image file to reduce file size
  /// Returns path to compressed file
  Future<String> compressImage(
    File imageFile, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if needed
      img.Image resized = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resized = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress
      final compressed = img.encodeJpg(resized, quality: quality);
      final originalSize = bytes.length;
      final compressedSize = compressed.length;
      final savings =
          ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);

      _logger.info(
        '🖼️ Image compressed: ${(originalSize / 1024).toStringAsFixed(2)}KB → ${(compressedSize / 1024).toStringAsFixed(2)}KB ($savings% savings)',
      );

      // Save compressed image
      final compressedFile =
          File(imageFile.path.replaceAll('.jpg', '_compressed.jpg'));
      await compressedFile.writeAsBytes(compressed);

      return compressedFile.path;
    } catch (e) {
      _logger.error('❌ Failed to compress image', error: e);
      rethrow;
    }
  }

  /// Clear image memory cache (call when leaving image-heavy screens)
  void clearImageCache() {
    _imageCache.clear();
    _logger.debug('🗑️ Image cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedImages': _imageCache.length,
      'totalBytesLoaded':
          '${(_totalBytesLoaded / 1024 / 1024).toStringAsFixed(2)} MB',
      'totalImagesLoaded': _totalImagesLoaded,
      'averageImageSize': _totalImagesLoaded > 0
          ? '${((_totalBytesLoaded / _totalImagesLoaded) / 1024).toStringAsFixed(2)} KB'
          : '0 KB',
    };
  }

  // ============================================================================
  // MEMORY MANAGEMENT
  // ============================================================================

  /// Monitor memory usage and log warnings if exceeding threshold
  Future<MemoryStatus> checkMemoryUsage({int warnThresholdMB = 200}) async {
    try {
      final info = await _getMemoryInfo();
      final usedMB = info['used'] as int;
      final totalMB = info['total'] as int;
      final percentUsed = (usedMB / totalMB * 100).toStringAsFixed(1);

      final status = MemoryStatus(
        usedMB: usedMB,
        totalMB: totalMB,
        percentUsed: double.parse(percentUsed),
        isWarning: usedMB > warnThresholdMB,
      );

      if (status.isWarning) {
        _logger.warning(
          '⚠️ High memory usage: ${status.usedMB}MB / ${status.totalMB}MB (${status.percentUsed}%)',
        );
      }

      return status;
    } catch (e) {
      _logger.error('❌ Failed to check memory usage', error: e);
      return MemoryStatus(
          usedMB: 0, totalMB: 0, percentUsed: 0, isWarning: false);
    }
  }

  Future<Map<String, int>> _getMemoryInfo() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Try to get actual memory info from system
      // This is a simplified approach - actual values depend on platform
      return {
        'used': 150, // Placeholder
        'total': 512, // Placeholder
      };
    }
    return {'used': 0, 'total': 0};
  }

  // ============================================================================
  // RENDER PERFORMANCE
  // ============================================================================

  /// Measure widget build time
  Future<Duration> measureBuildTime(
    Widget Function() widgetBuilder,
  ) async {
    final stopwatch = Stopwatch()..start();
    widgetBuilder();
    stopwatch.stop();

    _logger.debug('⏱️ Widget build time: ${stopwatch.elapsedMilliseconds}ms');
    return stopwatch.elapsed;
  }

  /// Detect jank (dropped frames) - call periodically in build method
  void detectJank(BuildContext context) {
    if (kDebugMode) {
      SchedulerBinding.instance.addPostFrameCallback((duration) {
        final fps = 1000 / duration.inMilliseconds;
        if (fps < 55) {
          _logger.warning('⚠️ Jank detected: ${fps.toStringAsFixed(1)} FPS');
        }
      });
    }
  }

  /// Batch expensive operations to prevent frame drops
  Future<void> performBatchedOperations(
    List<Future<void> Function()> operations, {
    Duration delayBetweenBatches = const Duration(milliseconds: 50),
  }) async {
    for (int i = 0; i < operations.length; i++) {
      await operations[i]();
      if (i < operations.length - 1) {
        // Allow frame to render before next operation
        await Future.delayed(delayBetweenBatches);
      }
    }
    _logger.debug('✅ Completed ${operations.length} batched operations');
  }

  // ============================================================================
  // PROFILING & MONITORING
  // ============================================================================

  /// Profile a function execution time
  Future<T> profileFunction<T>(
    String functionName,
    Future<T> Function() function,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      _logger.debug(
          '✅ $functionName completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      _logger.error(
        '❌ $functionName failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
      );
      rethrow;
    }
  }

  /// Measure rebuild frequency
  static void measureRebuildFrequency(String widgetName) {
    if (kDebugMode) {
      debugPrint('🔄 Rebuilt: $widgetName');
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  void dispose() {
    _imageCache.clear();
    _totalBytesLoaded = 0;
    _totalImagesLoaded = 0;
    _logger.info('♻️ PerformanceUtils disposed');
  }
}

/// Memory status data class
class MemoryStatus {
  final int usedMB;
  final int totalMB;
  final double percentUsed;
  final bool isWarning;

  MemoryStatus({
    required this.usedMB,
    required this.totalMB,
    required this.percentUsed,
    required this.isWarning,
  });

  @override
  String toString() =>
      'Memory: ${usedMB}MB / ${totalMB}MB (${percentUsed.toStringAsFixed(1)}%)${isWarning ? ' ⚠️' : ''}';
}

/// Lazy load builder widget - simplifies lazy loading in UI
class LazyLoadImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LazyLoadImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LazyLoadImage> createState() => _LazyLoadImageState();
}

class _LazyLoadImageState extends State<LazyLoadImage> {
  late Future<ui.Image> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = PerformanceUtils().loadOptimizedImage(
      widget.imageUrl,
      maxWidth: (widget.width ?? 200).toInt(),
      maxHeight: (widget.height ?? 200).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              );
        }

        if (snapshot.hasError) {
          return widget.errorWidget ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              );
        }

        if (snapshot.hasData) {
          return CustomPaint(
            size: Size(widget.width ?? 200, widget.height ?? 200),
            painter: _ImagePainter(snapshot.data!),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Custom painter for rendering optimized images
class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) => oldDelegate.image != image;
}
