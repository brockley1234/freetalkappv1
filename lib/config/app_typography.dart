import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Typography system with clear hierarchy for better readability
/// All text styles follow Material Design 3 guidelines with custom tweaks
class AppTypography {
  // ============ DISPLAY STYLES (Hero sections, banners) ============

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // ============ HEADLINE STYLES (Page titles, section headers) ============

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // ============ TITLE STYLES (Card headers, dialogs) ============

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // ============ BODY STYLES (Main content, paragraphs) ============

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5, // Better readability with increased line height
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // ============ LABEL STYLES (Buttons, badges, tags) ============

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // ============ CAPTION & HELPER TEXT ============

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0, // More letter spacing for small uppercase text
    height: 1.3,
    color: AppColors.textSecondary,
  );

  // ============ SPECIALIZED STYLES ============

  /// For timestamps, metadata (e.g., "2 hours ago")
  static const TextStyle timestamp = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  /// For user mentions (@username)
  static const TextStyle mention = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.primary,
  );

  /// For hashtags (#trending)
  static const TextStyle hashtag = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.primary,
  );

  /// For error messages
  static const TextStyle error = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.error,
  );

  /// For success messages
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.success,
  );

  // ============ DARK MODE VARIANTS ============

  /// Get text style with appropriate color for dark mode
  static TextStyle forDarkMode(TextStyle style) {
    return style.copyWith(
      color: style.color == AppColors.textPrimary
          ? AppColors.textInverse
          : style.color == AppColors.textSecondary
              ? AppColors.textInverse.withValues(alpha: 0.7)
              : style.color == AppColors.textTertiary
                  ? AppColors.textInverse.withValues(alpha: 0.5)
                  : style.color,
    );
  }

  // ============ HELPER METHODS ============

  /// Apply text style with theme awareness
  static TextStyle applyStyle({
    required TextStyle style,
    required bool isDarkMode,
    Color? customColor,
  }) {
    if (customColor != null) {
      return style.copyWith(color: customColor);
    }
    return isDarkMode ? forDarkMode(style) : style;
  }

  /// Create text style with specific weight override
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Create text style with specific color override
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Create text style with specific size override
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }
}

/// Extension for easy access to typography with theme awareness
extension TypographyExtension on BuildContext {
  /// Get typography adjusted for current theme
  TextStyle getTypography(TextStyle baseStyle) {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return AppTypography.applyStyle(
      style: baseStyle,
      isDarkMode: isDark,
    );
  }
}
