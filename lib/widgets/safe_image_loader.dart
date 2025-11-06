import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_utils.dart';

/// Safe image loader that handles 404 errors gracefully without console spam
///
/// This widget wraps image loading with better error handling to prevent
/// 404 errors from cluttering the console while still displaying fallback UI
class SafeImageLoader extends StatelessWidget {
  final String? imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool suppressErrors;

  const SafeImageLoader({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.suppressErrors = true,
  });

  @override
  Widget build(BuildContext context) {
    // If no URL provided, show error widget immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        // Optionally log error silently (not to console)
        if (!suppressErrors) {
          debugPrint('Failed to load image: $url - $error');
        }
        return errorWidget ?? _buildErrorWidget();
      },
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade500,
          size: (height != null && height! < 60) ? 24 : 40,
        ),
      ),
    );
  }
}

/// Safe avatar loader with circular clipping
class SafeAvatarLoader extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? textColor;
  final bool suppressErrors;

  const SafeAvatarLoader({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackText,
    this.backgroundColor,
    this.textColor,
    this.suppressErrors = true,
  });

  @override
  Widget build(BuildContext context) {
    // If no image URL, show fallback immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallbackAvatar();
    }

    // Use UrlUtils to get the appropriate ImageProvider (handles local assets like bot avatars)
    final imageProvider = UrlUtils.getAvatarImageProvider(imageUrl);

    if (UrlUtils.isLocalAsset(imageUrl)) {
      // Local asset - use Image with that provider directly in CircleAvatar
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade300,
        backgroundImage: imageProvider as AssetImage?,
        child: _buildFallbackContent(),
      );
    } else {
      // Network image - use CachedNetworkImageProvider for caching
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade300,
        backgroundImage: imageProvider as NetworkImage?,
        onBackgroundImageError: (exception, stackTrace) {
          // Silently handle error - the CircleAvatar will show backgroundColor
          if (!suppressErrors) {
            debugPrint('Failed to load avatar: $imageUrl');
          }
        },
        child: _buildFallbackContent(),
      );
    }
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _generateColorFromText(fallbackText),
      child: _buildFallbackContent(),
    );
  }

  Widget _buildFallbackContent() {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Text(
        fallbackText!.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: radius,
      color: textColor ?? Colors.white70,
    );
  }

  Color _generateColorFromText(String? text) {
    if (text == null || text.isEmpty) {
      return Colors.grey.shade400;
    }

    // Generate a consistent color based on the text
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.red,
    ];

    final hash = text.codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }
}

/// Safe feed banner loader
class SafeBannerLoader extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final BoxFit fit;
  final bool suppressErrors;
  final Widget? placeholder;
  final VoidCallback? onTap;

  const SafeBannerLoader({
    super.key,
    required this.imageUrl,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.suppressErrors = true,
    this.placeholder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (imageUrl == null || imageUrl!.isEmpty) {
      content = _buildPlaceholder();
    } else {
      content = SafeImageLoader(
        imageUrl: imageUrl,
        height: height,
        width: double.infinity,
        fit: fit,
        suppressErrors: suppressErrors,
        placeholder: placeholder,
        errorWidget: _buildPlaceholder(),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade200,
                Colors.purple.shade200,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add banner photo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
