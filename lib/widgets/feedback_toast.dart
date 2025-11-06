import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../config/app_typography.dart';

/// Type of feedback to show user
enum FeedbackType { success, error, warning, info }

/// Enhanced feedback toast with animations and haptics
/// Provides clear visual and tactile feedback for user actions
class FeedbackToast extends StatefulWidget {
  final String message;
  final String? subtitle;
  final FeedbackType type;
  final Duration duration;
  final VoidCallback? onDismiss;
  final bool showHaptic;

  const FeedbackToast({
    super.key,
    required this.message,
    this.subtitle,
    required this.type,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
    this.showHaptic = true,
  });

  /// Show a success toast
  static void showSuccess(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    _show(context, message, FeedbackType.success, subtitle: subtitle);
  }

  /// Show an error toast
  static void showError(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    _show(context, message, FeedbackType.error, subtitle: subtitle);
  }

  /// Show a warning toast
  static void showWarning(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    _show(context, message, FeedbackType.warning, subtitle: subtitle);
  }

  /// Show an info toast
  static void showInfo(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    _show(context, message, FeedbackType.info, subtitle: subtitle);
  }

  static void _show(
    BuildContext context,
    String message,
    FeedbackType type, {
    String? subtitle,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: FeedbackToast(
          message: message,
          subtitle: subtitle,
          type: type,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  State<FeedbackToast> createState() => _FeedbackToastState();
}

class _FeedbackToastState extends State<FeedbackToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Trigger haptic feedback based on type
    if (widget.showHaptic) {
      _triggerHaptic();
    }

    // Setup animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );

    // Start entrance animation
    _slideController.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _slideController.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  void _triggerHaptic() {
    switch (widget.type) {
      case FeedbackType.success:
        HapticFeedback.mediumImpact();
        break;
      case FeedbackType.error:
        HapticFeedback.heavyImpact();
        break;
      case FeedbackType.warning:
        HapticFeedback.lightImpact();
        break;
      case FeedbackType.info:
        HapticFeedback.selectionClick();
        break;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case FeedbackType.success:
        return Icons.check_circle;
      case FeedbackType.error:
        return Icons.error;
      case FeedbackType.warning:
        return Icons.warning;
      case FeedbackType.info:
        return Icons.info;
    }
  }

  Color _getColorForType() {
    switch (widget.type) {
      case FeedbackType.success:
        return AppColors.success;
      case FeedbackType.error:
        return AppColors.error;
      case FeedbackType.warning:
        return AppColors.warning;
      case FeedbackType.info:
        return AppColors.info;
    }
  }

  String _getAccessibilityLabel() {
    switch (widget.type) {
      case FeedbackType.success:
        return 'Success: ${widget.message}';
      case FeedbackType.error:
        return 'Error: ${widget.message}';
      case FeedbackType.warning:
        return 'Warning: ${widget.message}';
      case FeedbackType.info:
        return 'Information: ${widget.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                liveRegion: true,
                label: _getAccessibilityLabel(),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _getColorForType(),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.message,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Dismiss button
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          _slideController.reverse().then((_) {
                            widget.onDismiss?.call();
                          });
                        },
                        tooltip: 'Dismiss',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple snackbar-style toast for quick feedback
class QuickToast {
  /// Show a simple message at the bottom
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
