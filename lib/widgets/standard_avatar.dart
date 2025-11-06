import 'package:flutter/material.dart';
import '../utils/url_utils.dart';

/// A standardized avatar widget that handles all avatar display cases consistently
/// Supports both network images and local assets (like bot avatars)
class StandardAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String? fallbackName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final VoidCallback? onTap;

  const StandardAvatar({
    super.key,
    this.avatarUrl,
    this.fallbackName,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.onTap,
  });

  @override
  State<StandardAvatar> createState() => _StandardAvatarState();
}

class _StandardAvatarState extends State<StandardAvatar> {
  bool _hasImageError = false;

  @override
  void didUpdateWidget(StandardAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state if avatar URL changes
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _hasImageError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = widget.backgroundColor ?? Colors.grey.shade300;
    final effectiveTextColor = widget.textColor ?? Colors.white;
    final effectiveFontSize = widget.fontSize ?? (widget.radius * 0.8);

    Widget avatarWidget;

    if (widget.avatarUrl != null && UrlUtils.isLocalAsset(widget.avatarUrl)) {
      // Local asset (like bot avatars) - use Image widget with AssetImage
      avatarWidget = Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: effectiveBackgroundColor,
        ),
        child: ClipOval(
          child: Image.asset(
            widget.avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackText(effectiveTextColor, effectiveFontSize);
            },
          ),
        ),
      );
    } else {
      // Network image - use CircleAvatar with NetworkImage and error handling
      final hasAvatarUrl = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && !_hasImageError;
      
      avatarWidget = CircleAvatar(
        radius: widget.radius,
        backgroundColor: effectiveBackgroundColor,
        backgroundImage: hasAvatarUrl
            ? NetworkImage(UrlUtils.getFullAvatarUrl(widget.avatarUrl))
            : null,
        onBackgroundImageError: (exception, stackTrace) {
          // Handle image loading error - set state to show fallback
          if (mounted && !_hasImageError) {
            setState(() {
              _hasImageError = true;
            });
          }
        },
        child: !hasAvatarUrl
            ? _buildFallbackText(effectiveTextColor, effectiveFontSize)
            : null,
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildFallbackText(Color textColor, double fontSize) {
    String initials = '?';
    
    if (widget.fallbackName != null && widget.fallbackName!.isNotEmpty) {
      final words = widget.fallbackName!.trim().split(' ');
      if (words.length >= 2) {
        initials = '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else {
        initials = words[0][0].toUpperCase();
      }
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A specialized avatar widget for club members with online status indicator
class ClubMemberAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? fallbackName;
  final double radius;
  final bool isOnline;
  final VoidCallback? onTap;

  const ClubMemberAvatar({
    super.key,
    this.avatarUrl,
    this.fallbackName,
    this.radius = 24,
    this.isOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StandardAvatar(
          avatarUrl: avatarUrl,
          fallbackName: fallbackName,
          radius: radius,
          onTap: onTap,
        ),
        // Online status indicator
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
