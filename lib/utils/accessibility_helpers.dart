import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../config/app_theme.dart';

/// Accessibility helpers for WCAG 2.1 Level AA compliance
/// Ensures app is usable for visually impaired users and keyboard navigation
class AccessibilityHelpers {
  // Ensure minimum touch target size (48x48dp per Material Design)
  static const double minTouchTargetSize = 48.0;

  /// Create an accessible icon button with proper size and semantics
  static Widget semanticIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    double size = 24,
    bool enabled = true,
  }) {
    return Semantics(
      enabled: enabled,
      button: true,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: minTouchTargetSize,
                minHeight: minTouchTargetSize,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: size,
                color: enabled
                    ? (color ?? AppColors.textPrimary)
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Create an accessible text button
  static Widget semanticTextButton({
    required String text,
    required VoidCallback onPressed,
    String? semanticLabel,
    bool enabled = true,
    TextStyle? style,
  }) {
    return Semantics(
      enabled: enabled,
      button: true,
      label: semanticLabel ?? text,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: minTouchTargetSize,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: style ??
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.primary : AppColors.textTertiary,
                ),
          ),
        ),
      ),
    );
  }

  /// Get high contrast text style based on device settings
  static TextStyle highContrastText(
    BuildContext context,
    TextStyle baseStyle,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final isHighContrast = mediaQuery.highContrast;

    if (isHighContrast) {
      return baseStyle.copyWith(
        fontWeight: FontWeight.bold,
        color: _ensureContrast(baseStyle.color ?? AppColors.textPrimary),
      );
    }

    return baseStyle;
  }

  /// Ensure color has sufficient contrast
  static Color _ensureContrast(Color color) {
    // If color is too light, make it darker
    final luminance = color.computeLuminance();
    if (luminance > 0.7) {
      return color.withValues(alpha: 0.8);
    }
    return color;
  }

  /// Create a focusable action detector for keyboard navigation
  static Widget createAccessibleButton({
    required VoidCallback onActivate,
    required Widget child,
    String? semanticLabel,
    FocusNode? focusNode,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: FocusableActionDetector(
        focusNode: focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            // Announce focus to screen readers
            SemanticsService.announce(
              semanticLabel ?? 'Button focused',
              TextDirection.ltr,
            );
          }
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onActivate();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  /// Announce message to screen readers
  static void announce(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Create an accessible list tile
  static Widget semanticListTile({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: minTouchTargetSize,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if text size is accessible
  static bool isTextSizeAccessible(double fontSize) {
    return fontSize >= 12.0; // Minimum readable size
  }

  /// Get scaled text size based on accessibility settings
  static double getScaledTextSize(BuildContext context, double baseSize) {
    final textScaler = MediaQuery.textScalerOf(context);

    // Limit max scale to prevent layout breaks
    final scaledSize = textScaler.scale(baseSize);
    final cappedScale = (scaledSize / baseSize).clamp(1.0, 2.0);
    return baseSize * cappedScale;
  }

  /// Create accessible form field
  static Widget accessibleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? errorText,
    bool obscureText = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return Semantics(
      textField: true,
      label: label,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 16), // Minimum readable size
      ),
    );
  }

  /// Wrap content with proper screen reader support
  static Widget screenReaderSupport({
    required Widget child,
    required String label,
    String? hint,
    bool isLiveRegion = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      liveRegion: isLiveRegion,
      child: child,
    );
  }

  /// Create accessible image with alt text
  static Widget accessibleImage({
    required ImageProvider image,
    required String altText,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Semantics(
      image: true,
      label: altText,
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: altText,
      ),
    );
  }

  /// Create accessible loading indicator
  static Widget accessibleLoading({
    String message = 'Loading...',
    double size = 24,
  }) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create accessible badge (for notifications, counts)
  static Widget accessibleBadge({
    required Widget child,
    required int count,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? '$count unread items',
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: child,
      ),
    );
  }

  /// Check if user prefers reduced motion
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get animation duration based on accessibility settings
  static Duration getAnimationDuration(
    BuildContext context, {
    Duration normal = const Duration(milliseconds: 300),
  }) {
    if (prefersReducedMotion(context)) {
      return Duration.zero;
    }
    return normal;
  }
}

/// Extension for easy access to accessibility features
extension AccessibilityExtension on BuildContext {
  /// Check if high contrast mode is enabled
  bool get isHighContrast => MediaQuery.of(this).highContrast;

  /// Check if reduced motion is preferred
  bool get prefersReducedMotion => MediaQuery.of(this).disableAnimations;

  /// Get text scale factor
  double get textScaleFactor => MediaQuery.textScalerOf(this).scale(1.0);

  /// Announce to screen readers
  void announce(String message) {
    AccessibilityHelpers.announce(message);
  }
}
