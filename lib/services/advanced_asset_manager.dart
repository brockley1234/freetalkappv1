import 'dart:async';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../utils/app_logger.dart';

/// Advanced asset management with lazy loading, compression, and intelligent caching.
/// Handles images, videos, and other assets with automatic cleanup and memory optimization.
class AdvancedAssetManager {
  static final AdvancedAssetManager _instance =
      AdvancedAssetManager._internal();
  factory AdvancedAssetManager() => _instance;
  AdvancedAssetManager._internal();

  final _logger = AppLogger();
  late CacheManager _cacheManager;
  final Map<String, AssetLoadTask> _activeDownloads = {};
  final Map<String, DateTime> _lastAccessedTime = {};
  final List<String> _loadingQueue = [];
  bool _isProcessingQueue = false;

  // Configuration
  static const int maxConcurrentDownloads = 3;
  static const int cacheExpirationDays = 30;
  static const int maxCacheObjects = 500;
  static const int inactivityThresholdMinutes = 30;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    try {
      _cacheManager = CacheManager(
        Config(
          'advanced_assets_cache',
          stalePeriod: const Duration(days: cacheExpirationDays),
          maxNrOfCacheObjects: maxCacheObjects,
        ),
      );
      _logger.info('✅ AdvancedAssetManager initialized');
      _startCleanupTimer();
    } catch (e) {
      _logger.error('❌ Failed to initialize AdvancedAssetManager', error: e);
    }
  }

  // ============================================================================
  // LAZY LOADING & SMART QUEUEING
  // ============================================================================

  /// Load asset with intelligent queuing to prevent overwhelming network
  Future<File> lazyLoadAsset(
    String assetUrl, {
    bool highPriority = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Return immediately if already downloading
    if (_activeDownloads.containsKey(assetUrl)) {
      _logger.debug('⏳ Asset already loading: $assetUrl');
      return _activeDownloads[assetUrl]!.future;
    }

    // Add to queue
    if (_activeDownloads.length >= maxConcurrentDownloads) {
      _logger.debug(
          '📋 Queuing asset (${_activeDownloads.length}/$maxConcurrentDownloads): $assetUrl');
      if (highPriority) {
        _loadingQueue.insert(0, assetUrl);
      } else {
        _loadingQueue.add(assetUrl);
      }

      final task = AssetLoadTask();
      _activeDownloads[assetUrl] = task;
      _processQueue();
      return task.future.timeout(timeout);
    }

    // Load immediately if slot available
    return _downloadAsset(assetUrl, timeout);
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _loadingQueue.isEmpty) return;

    _isProcessingQueue = true;
    while (_loadingQueue.isNotEmpty &&
        _activeDownloads.length < maxConcurrentDownloads) {
      final assetUrl = _loadingQueue.removeAt(0);
      try {
        await _downloadAsset(assetUrl);
      } catch (e) {
        _logger.error('❌ Failed to process queued asset', error: e);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isProcessingQueue = false;
  }

  Future<File> _downloadAsset(String assetUrl, [Duration? timeout]) async {
    final task = _activeDownloads[assetUrl] ?? AssetLoadTask();
    _activeDownloads[assetUrl] = task;

    try {
      // Fetch from cache or network
      final file = await _cacheManager.getSingleFile(assetUrl);
      _lastAccessedTime[assetUrl] = DateTime.now();

      _logger.debug(
          '✅ Asset loaded: $assetUrl (${await _getFileSizeKB(file)} KB)');
      task.complete(file);
      _activeDownloads.remove(assetUrl);

      return file;
    } catch (e) {
      _logger.error('❌ Failed to download asset: $assetUrl', error: e);
      task.completeError(e);
      _activeDownloads.remove(assetUrl);
      rethrow;
    }
  }

  // ============================================================================
  // IMAGE COMPRESSION & OPTIMIZATION
  // ============================================================================

  /// Compress image with adaptive quality based on target usage
  Future<File> compressImageAdaptive(
    File imageFile, {
    ImageCompressionQuality quality = ImageCompressionQuality.medium,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode image');

      // Determine quality settings based on preset
      final qualityMap = {
        ImageCompressionQuality.low: 60,
        ImageCompressionQuality.medium: 80,
        ImageCompressionQuality.high: 90,
        ImageCompressionQuality.veryHigh: 95,
      };

      final jpgQuality = qualityMap[quality]!;
      final actualMaxWidth = maxWidth ?? 1280;
      final actualMaxHeight = maxHeight ?? 1280;

      // Resize if needed
      img.Image resized = image;
      if (image.width > actualMaxWidth || image.height > actualMaxHeight) {
        resized = img.copyResize(
          image,
          width: actualMaxWidth,
          height: actualMaxHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress
      final compressed = img.encodeJpg(resized, quality: jpgQuality);
      final originalSize = bytes.length;
      final compressedSize = compressed.length;
      final reduction =
          ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);

      _logger.info(
        '🖼️ Image compressed ($quality): ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($reduction% reduction)',
      );

      // Save compressed file
      final compressedFile =
          File('${imageFile.path.split('.').first}_compressed.jpg');
      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      _logger.error('❌ Failed to compress image adaptively', error: e);
      return imageFile; // Return original if compression fails
    }
  }

  /// Generate thumbnail for image preview (ultra-lightweight)
  Future<File> generateThumbnail(
    File imageFile, {
    int size = 150,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode image');

      // Create square thumbnail
      final thumbnail = img.copyResizeCropSquare(image, size: size);
      final compressed = img.encodeJpg(thumbnail, quality: 70);

      _logger
          .debug('🔲 Thumbnail generated: ${_formatBytes(compressed.length)}');

      final thumbnailFile =
          File('${imageFile.path.split('.').first}_thumb.jpg');
      await thumbnailFile.writeAsBytes(compressed);

      return thumbnailFile;
    } catch (e) {
      _logger.error('❌ Failed to generate thumbnail', error: e);
      return imageFile;
    }
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Load multiple assets efficiently with batch processing
  Future<Map<String, File>> batchLoadAssets(
    List<String> assetUrls, {
    bool cancelOnError = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, File>{};
    int completed = 0;

    for (final url in assetUrls) {
      try {
        final file = await lazyLoadAsset(url);
        results[url] = file;
        completed++;
        onProgress?.call(completed, assetUrls.length);
      } catch (e) {
        _logger.warning('⚠️ Failed to load asset in batch: $url');
        if (cancelOnError) {
          throw Exception('Batch load cancelled at $url: $e');
        }
      }
    }

    _logger.info('✅ Batch loaded ${results.length}/${assetUrls.length} assets');
    return results;
  }

  // ============================================================================
  // CACHE MANAGEMENT & CLEANUP
  // ============================================================================

  /// Get current cache size
  Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      return _getDirSize(cacheDir);
    } catch (e) {
      _logger.error('❌ Failed to get cache size', error: e);
      return 0;
    }
  }

  int _getDirSize(Directory dir) {
    int size = 0;
    try {
      if (dir.existsSync()) {
        dir.listSync(recursive: true).forEach((file) {
          if (file is File) {
            size += file.lengthSync();
          }
        });
      }
    } catch (e) {
      _logger.error('❌ Error calculating directory size', error: e);
    }
    return size;
  }

  /// Clear unused assets (not accessed in threshold minutes)
  Future<void> clearUnusedAssets({
    int inactivityMinutes = inactivityThresholdMinutes,
  }) async {
    try {
      final threshold =
          DateTime.now().subtract(Duration(minutes: inactivityMinutes));
      int removedCount = 0;

      final keysToRemove = _lastAccessedTime.entries
          .where((entry) => entry.value.isBefore(threshold))
          .map((entry) => entry.key)
          .toList();

      for (final key in keysToRemove) {
        _lastAccessedTime.remove(key);
        removedCount++;
      }

      if (removedCount > 0) {
        _logger.info('🗑️ Cleared $removedCount unused assets');
      }
    } catch (e) {
      _logger.error('❌ Failed to clear unused assets', error: e);
    }
  }

  /// Manually clear all cache
  Future<void> clearAllCache() async {
    try {
      await _cacheManager.emptyCache();
      _lastAccessedTime.clear();
      _activeDownloads.clear();
      _logger.info('🧹 All cache cleared');
    } catch (e) {
      _logger.error('❌ Failed to clear all cache', error: e);
    }
  }

  /// Monitor cache health and cleanup periodically
  void _startCleanupTimer() {
    Timer.periodic(const Duration(minutes: 15), (_) async {
      await clearUnusedAssets();
      final cacheSize = await getCacheSizeBytes();
      _logger.debug('📊 Cache size: ${_formatBytes(cacheSize)}');
    });
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  Future<String> _getFileSizeKB(File file) async {
    try {
      final size = await file.length();
      return (size / 1024).toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  /// Get detailed cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final cacheSize = await getCacheSizeBytes();
    return {
      'totalSize': _formatBytes(cacheSize),
      'totalSizeBytes': cacheSize,
      'activeDownloads': _activeDownloads.length,
      'queuedAssets': _loadingQueue.length,
      'trackedAssets': _lastAccessedTime.length,
      'maxConcurrentDownloads': maxConcurrentDownloads,
      'maxCacheObjects': maxCacheObjects,
    };
  }

  void dispose() {
    _activeDownloads.clear();
    _lastAccessedTime.clear();
    _loadingQueue.clear();
    _logger.info('♻️ AdvancedAssetManager disposed');
  }
}

/// Asset load task for tracking concurrent downloads
class AssetLoadTask {
  late Completer<File> _completer;

  AssetLoadTask() {
    _completer = Completer<File>();
  }

  Future<File> get future => _completer.future;

  void complete(File file) {
    if (!_completer.isCompleted) {
      _completer.complete(file);
    }
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) {
      _completer.completeError(error);
    }
  }
}

/// Image compression quality presets
enum ImageCompressionQuality {
  low, // 60% JPEG quality - minimal storage
  medium, // 80% JPEG quality - balanced
  high, // 90% JPEG quality - good quality
  veryHigh, // 95% JPEG quality - best quality
}
