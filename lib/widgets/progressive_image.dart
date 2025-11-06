import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Progressive image loading with blur-up effect
/// Displays low-res placeholder while high-res image loads for better UX
class ProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final String? placeholderUrl; // Optional low-res preview
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Widget? errorWidget;
  final bool showLoadingIndicator;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.placeholderUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppBorderRadius.md),
    ),
    this.errorWidget,
    this.showLoadingIndicator = true,
  });

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        height: widget.height,
        width: widget.width,
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Placeholder (blurred low-res) if provided
            if (widget.placeholderUrl != null && !_imageLoaded)
              _buildPlaceholder(),

            // Layer 2: Main high-res image
            FadeTransition(
              opacity: _fadeAnimation,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: widget.fit,
                placeholder: (context, url) {
                  if (!widget.showLoadingIndicator) {
                    return Container();
                  }
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
                imageBuilder: (context, imageProvider) {
                  // Trigger fade-in when image loads
                  if (!_imageLoaded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _imageLoaded = true);
                        _fadeController.forward();
                      }
                    });
                  }
                  return Image(
                    image: imageProvider,
                    fit: widget.fit,
                  );
                },
                errorWidget: (context, url, error) {
                  return widget.errorWidget ?? _buildErrorWidget(isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.placeholderUrl!,
          fit: widget.fit,
          placeholder: (context, url) => Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceVariant
                : AppColors.surfaceVariant,
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceVariant
                : AppColors.surfaceVariant,
          ),
        ),
        // Blur effect on placeholder
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 40,
              color: isDark
                  ? AppColors.textInverse.withValues(alpha: 0.5)
                  : AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Image unavailable',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textInverse.withValues(alpha: 0.5)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized image for avatars (circular)
class ProgressiveAvatar extends StatelessWidget {
  final String imageUrl;
  final String? placeholderUrl;
  final double size;
  final Widget? errorWidget;

  const ProgressiveAvatar({
    super.key,
    required this.imageUrl,
    this.placeholderUrl,
    required this.size,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: ProgressiveImage(
        imageUrl: imageUrl,
        placeholderUrl: placeholderUrl,
        height: size,
        width: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        errorWidget: errorWidget ??
            Container(
              width: size,
              height: size,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant,
              child: Icon(
                Icons.person,
                size: size * 0.5,
                color: AppColors.textTertiary,
              ),
            ),
      ),
    );
  }
}

/// Hero image for full-screen viewing
class ProgressiveHeroImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final VoidCallback? onTap;

  const ProgressiveHeroImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: GestureDetector(
        onTap: onTap,
        child: ProgressiveImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}

/// Grid image with consistent sizing
class ProgressiveGridImage extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const ProgressiveGridImage({
    super.key,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: ProgressiveImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),
    );
  }
}
