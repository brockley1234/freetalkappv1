import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A stateful avatar widget that properly handles image loading errors
/// and falls back to showing initials when the image fails to load (404, etc.)
/// 
/// Features:
/// - Enhanced placeholder with icon and gradient background
/// - Shimmer loading animation
/// - Improved error state handling with retry option
/// - Better accessibility and visual hierarchy
/// - Customizable fallback UI appearance
class AvatarWithFallback extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final TextStyle? textStyle;
  final ImageProvider<Object>? Function(String)? getImageProvider;
  final bool showShimmerLoading;
  final bool showIcon;
  final Color? backgroundColor;
  final VoidCallback? onRetry;
  final bool showBorder;
  final double borderWidth;

  const AvatarWithFallback({
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.textStyle,
    this.getImageProvider,
    this.showShimmerLoading = true,
    this.showIcon = true,
    this.backgroundColor,
    this.onRetry,
    this.showBorder = true,
    this.borderWidth = 2.0,
    super.key,
  });

  @override
  State<AvatarWithFallback> createState() => _AvatarWithFallbackState();
}

class _AvatarWithFallbackState extends State<AvatarWithFallback> {
  bool _imageLoadFailed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Reset loading state when imageUrl changes
    _isLoading = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
  }

  @override
  void didUpdateWidget(AvatarWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _imageLoadFailed = false;
        _isLoading = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = AvatarUtils.getInitials(widget.name);
    final backgroundColor =
        widget.backgroundColor ?? AvatarUtils.getColorForName(widget.name);

    // Show shimmer loading state
    if (_isLoading && widget.showShimmerLoading && !_imageLoadFailed) {
      return _buildShimmerPlaceholder(backgroundColor);
    }

    // If image URL is empty or loading failed, show enhanced initials placeholder
    if (widget.imageUrl == null ||
        widget.imageUrl!.isEmpty ||
        _imageLoadFailed ||
        widget.getImageProvider == null) {
      return _buildInitialsPlaceholder(
        initials,
        backgroundColor,
        _imageLoadFailed,
      );
    }

    // Try to load the image with error handling
    return _buildAvatarWithImage(backgroundColor, initials);
  }

  /// Shimmer loading animation
  Widget _buildShimmerPlaceholder(Color backgroundColor) {
    return Shimmer.fromColors(
      baseColor: backgroundColor.withValues(alpha: 0.3),
      highlightColor: backgroundColor.withValues(alpha: 0.6),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: backgroundColor.withValues(alpha: 0.5),
      ),
    );
  }

  /// Enhanced initials placeholder with icon, gradient, and border
  Widget _buildInitialsPlaceholder(
    String initials,
    Color backgroundColor,
    bool isFailed,
  ) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: backgroundColor,
        child: widget.showBorder
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: widget.borderWidth,
                  ),
                ),
                child: _buildInitialsContent(initials, backgroundColor, isFailed),
              )
            : _buildInitialsContent(initials, backgroundColor, isFailed),
      ),
    );
  }

  /// Content inside the placeholder circle (icon + initials or error state)
  Widget _buildInitialsContent(
    String initials,
    Color backgroundColor,
    bool isFailed,
  ) {
    if (isFailed && widget.onRetry != null) {
      // Error state with retry button
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _imageLoadFailed = false;
              _isLoading = true;
            });
            widget.onRetry?.call();
          },
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white.withValues(alpha: 0.7),
                size: widget.radius * 0.6,
              ),
              SizedBox(height: widget.radius * 0.1),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: widget.radius * 0.25,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.showIcon) {
      // Icon + initials combination
      return Stack(
        alignment: Alignment.center,
        children: [
          // Person icon background
          Icon(
            Icons.person,
            size: widget.radius * 1.2,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          // Initials text overlay
          Text(
            initials,
            style: widget.textStyle ??
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.radius * 0.7,
                  letterSpacing: 1.0,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Simple initials without icon
    return Text(
      initials,
      style: widget.textStyle ??
          TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: widget.radius * 0.75,
          ),
      textAlign: TextAlign.center,
    );
  }

  /// Avatar with image and error handling
  Widget _buildAvatarWithImage(Color backgroundColor, String initials) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: backgroundColor,
        backgroundImage: widget.getImageProvider!(widget.imageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint(
            '❌ Avatar image failed to load for ${widget.name}: $exception',
          );
          setState(() {
            _imageLoadFailed = true;
            _isLoading = false;
          });
        },
        child: null,
      ),
    );
  }
}

/// Utility functions for avatar and profile picture handling
class AvatarUtils {
  /// Generate initials from a name string
  ///
  /// Takes up to 2 first letters of each word and returns them in uppercase.
  /// Example: "John Doe" -> "JD", "Jane" -> "J", "" -> "?"
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    return name
        .split(' ')
        .where((n) => n.isNotEmpty)
        .map((n) => n[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  /// Get a color based on the name's hash
  ///
  /// This ensures consistent colors for the same name across the app.
  /// Colors are carefully selected for good contrast and visual appeal.
  static Color getColorForName(String name) {
    if (name.isEmpty) return Colors.grey.shade400;

    // Generate a hash from the name
    int hash = name.hashCode;

    // Define a list of vibrant, accessible avatar colors with high contrast
    const List<Color> avatarColors = [
      Color(0xFF6366f1), // Indigo - vibrant and professional
      Color(0xFF06b6d4), // Cyan - bright and energetic
      Color(0xFF10b981), // Emerald - calming and trustworthy
      Color(0xFFf59e0b), // Amber - warm and friendly
      Color(0xFFef4444), // Red - bold and confident
      Color(0xFF8b5cf6), // Violet - creative and unique
      Color(0xFFec4899), // Pink - modern and playful
      Color(0xFF3b82f6), // Blue - calm and professional
      Color(0xFF14b8a6), // Teal - balanced and modern
      Color(0xFFd97706), // Orange - energetic and optimistic
    ];

    // Use the hash to pick a color
    return avatarColors[hash.abs() % avatarColors.length];
  }

  /// Get a complementary gradient for use as background
  ///
  /// Returns a gradient pair that complements the avatar color
  static List<Color> getGradientForName(String name) {
    final baseColor = getColorForName(name);
    return [
      baseColor,
      baseColor.withValues(alpha: 0.7),
    ];
  }

  /// Get contrasting text color for the given background color
  ///
  /// Ensures good readability of text on the avatar background
  static Color getContrastingTextColor(Color backgroundColor) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Build an enhanced avatar widget with improved fallback
  ///
  /// Uses AvatarWithFallback for better UX with:
  /// - Shimmer loading animation
  /// - Icon + initials placeholder
  /// - Error state with retry option
  /// - Better visual hierarchy
  static Widget buildAvatarWidget({
    required String name,
    String? imageUrl,
    double radius = 24,
    TextStyle? textStyle,
    ImageProvider<Object>? Function(String)? getImageProvider,
    bool showIcon = true,
    bool showShimmerLoading = true,
    VoidCallback? onRetry,
  }) {
    return AvatarWithFallback(
      name: name,
      imageUrl: imageUrl,
      radius: radius,
      textStyle: textStyle,
      getImageProvider: getImageProvider,
      showIcon: showIcon,
      showShimmerLoading: showShimmerLoading,
      onRetry: onRetry,
    );
  }

  /// Build a simple avatar widget (legacy support)
  ///
  /// This is the old implementation. Consider using buildAvatarWidget() instead
  /// for better UX with loading states and error handling.
  @Deprecated('Use buildAvatarWidget() instead for better UX with loading states and error handling')
  static Widget buildSimpleAvatarWidget({
    required String name,
    String? imageUrl,
    double radius = 24,
    TextStyle? textStyle,
    ImageProvider<Object>? Function(String)? getImageProvider,
  }) {
    final initials = getInitials(name);
    final backgroundColor = getColorForName(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage:
          imageUrl != null && imageUrl.isNotEmpty && getImageProvider != null
              ? getImageProvider(imageUrl)
              : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? Text(
              initials,
              style: textStyle ??
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.75,
                  ),
            )
          : null,
    );
  }
}
