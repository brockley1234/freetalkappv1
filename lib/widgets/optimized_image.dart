import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Optimized image widget with caching and placeholder
/// Automatically uses cached_network_image for network images
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool fadeIn;
  final Duration fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.fadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.cover,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: fadeIn ? fadeInDuration : Duration.zero,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Colors.grey.shade300,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 40,
            ),
          ),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Optimized avatar widget with circular clipping and caching
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? textColor;

  const OptimizedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackText,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      // Show fallback avatar with initials
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.blue,
        child: Text(
          _getInitials(fallbackText),
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          // Reduce memory usage with smaller cache size for avatars
          memCacheWidth: (radius * 2 * 2).toInt(),
          memCacheHeight: (radius * 2 * 2).toInt(),
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.blue,
            child: Text(
              _getInitials(fallbackText),
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// Optimized thumbnail image with reduced memory usage
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: fit,
      borderRadius: borderRadius,
      // Reduce memory cache size for thumbnails
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
      ),
    );
  }
}
