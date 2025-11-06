/// Flutter App Image Optimization Configuration
/// Optimizes image loading, caching, and memory usage
library optimized_image_widget;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Singleton instance for custom cache manager
class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();

  factory AppCacheManager() => _instance;
  AppCacheManager._internal();

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'app-image-cache', // Cache key
      stalePeriod: const Duration(days: 7), // Images are valid for 7 days
      maxNrOfCacheObjects: 200, // Maximum 200 images in cache
      fileService: HttpFileService(),
    ),
  );

  CacheManager get instance => _cacheManager;

  /// Clear entire cache
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Clear old cache files
  Future<void> cleanExpiredCache() async {
    await _cacheManager.emptyCache();
  }
}

/// Optimized image loading widget with proper caching
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration fadeInDuration;
  final Widget Function(BuildContext, String, DownloadProgress)?
      progressIndicatorBuilder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.progressIndicatorBuilder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      cacheManager: AppCacheManager().instance,
      progressIndicatorBuilder: progressIndicatorBuilder ??
          (context, url, downloadProgress) {
            return Center(
              child: CircularProgressIndicator(
                value: downloadProgress.progress,
              ),
            );
          },
      errorWidget: errorWidget ??
          (context, url, error) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            );
          },
      // Placeholder while loading
      placeholder: (context, url) {
        return Container(
          color: Colors.grey[200],
          child: const ShimmerLoading(),
        );
      },
    );
  }
}

/// Shimmer loading effect for better UX while loading images
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                _animationController.value - 0.3,
                _animationController.value,
                _animationController.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Performance optimization utilities for image loading
class ImageOptimizationUtils {
  /// Preload images in background for better perceived performance
  static Future<void> preloadImages(List<String> imageUrls) async {
    final cacheManager = AppCacheManager().instance;
    for (final url in imageUrls) {
      try {
        await cacheManager.getSingleFile(url);
      } catch (e) {
        // Image caching error
      }
    }
  }

  /// Get compressed/thumbnail URL for faster loading
  static String getThumbnailUrl(String imageUrl,
      {int width = 200, int height = 200}) {
    // Example: Replace with actual CDN thumbnail generation URL
    // Some CDNs support dynamic sizing: imageUrl + '?w=$width&h=$height&q=80'
    return '$imageUrl?w=$width&h=$height&q=80';
  }
}

/// Memory-efficient list for large image feeds
class OptimizedImageList extends StatefulWidget {
  final List<String> imageUrls;
  final ScrollController? scrollController;
  final void Function(int)? onLoadMore;

  const OptimizedImageList({
    super.key,
    required this.imageUrls,
    this.scrollController,
    this.onLoadMore,
  });

  @override
  State<OptimizedImageList> createState() => _OptimizedImageListState();
}

class _OptimizedImageListState extends State<OptimizedImageList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Load more when scrolling near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      widget.onLoadMore?.call(widget.imageUrls.length);
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        return OptimizedNetworkImage(
          imageUrl: widget.imageUrls[index],
          fit: BoxFit.cover,
        );
      },
    );
  }
}
