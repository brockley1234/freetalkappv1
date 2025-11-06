import 'dart:math';
import 'package:flutter/material.dart';

/// Extension for responsive sizing based on screen dimensions
/// 
/// Usage:
/// ```dart
/// final responsive = context.responsive;
/// Container(
///   width: responsive.width * 0.9,  // 90% of screen width
///   height: responsive.height * 0.5, // 50% of screen height
///   padding: EdgeInsets.all(responsive.padding),
/// )
/// ```
extension ResponsiveSizingExtension on BuildContext {
  /// Get responsive sizing helper for current context
  ResponsiveSizing get responsive => ResponsiveSizing(this);
}

/// Responsive sizing calculator based on screen dimensions
class ResponsiveSizing {
  final BuildContext context;

  ResponsiveSizing(this.context);

  /// Get screen size
  Size get screenSize => MediaQuery.of(context).size;

  /// Get screen width
  double get width => screenSize.width;

  /// Get screen height
  double get height => screenSize.height;

  /// Get device padding (for notches, safe areas)
  EdgeInsets get padding => MediaQuery.of(context).padding;

  /// Get viewInsets (keyboard height, etc.)
  EdgeInsets get viewInsets => MediaQuery.of(context).viewInsets;

  /// Check if device is in landscape mode
  bool get isLandscape => width > height;

  /// Check if device is in portrait mode
  bool get isPortrait => width <= height;

  /// Check if device is a tablet (width > 600)
  bool get isTablet => width > 600;

  /// Check if device is a phone (width <= 600)
  bool get isPhone => width <= 600;

  /// Check if device is a large tablet (width > 900)
  bool get isLargeTablet => width > 900;

  /// Get responsive font size based on screen width
  /// Default multiplier: 1.0 (scale factor)
  double fontSize(double baseSize, {double multiplier = 1.0}) {
    if (isLargeTablet) {
      return baseSize * multiplier * 1.3;
    } else if (isTablet) {
      return baseSize * multiplier * 1.15;
    }
    return baseSize * multiplier;
  }

  /// Get responsive padding/margin based on screen width
  /// Default: 12 for phone, 16 for tablet, 24 for large tablet
  double get paddingXs => isLargeTablet ? 8 : (isTablet ? 6 : 4);

  double get paddingSm => isLargeTablet ? 12 : (isTablet ? 10 : 8);

  double get paddingMd => isLargeTablet ? 24 : (isTablet ? 16 : 12);

  double get paddingLg => isLargeTablet ? 32 : (isTablet ? 24 : 16);

  double get paddingXl => isLargeTablet ? 48 : (isTablet ? 32 : 24);

  /// Get responsive icon size
  double get iconSizeSm => isTablet ? 24 : 20;

  double get iconSizeMd => isTablet ? 32 : 28;

  double get iconSizeLg => isTablet ? 48 : 40;

  // Aliases for widget compatibility
  double get iconSmall => iconSizeSm;
  double get iconMedium => iconSizeMd;
  double get iconLarge => iconSizeLg;

  /// Get responsive font sizes
  double get fontXSmall => fontSize(10);
  double get fontSmall => fontSize(12);
  double get fontMedium => fontSize(14);
  double get fontLarge => fontSize(16);
  double get fontXLarge => fontSize(18);

  /// Get responsive padding values (aliases)
  double get paddingXSmall => paddingXs;
  double get paddingSmall => paddingSm;
  double get paddingMedium => paddingMd;
  double get paddingLarge => paddingLg;
  double get paddingXLarge => paddingXl;

  /// Get responsive border radius
  double get radiusSmall => isTablet ? 8 : 6;
  double get radiusMedium => isTablet ? 12 : 8;
  double get radiusLarge => isTablet ? 16 : 12;

  /// Get responsive widget width (for cards, containers, etc.)
  double cardWidth({
    double? phoneWidth,
    double? tabletWidth,
    double? largeTabletWidth,
  }) {
    if (isLargeTablet) {
      return largeTabletWidth ?? width * 0.8;
    } else if (isTablet) {
      return tabletWidth ?? width * 0.85;
    }
    return phoneWidth ?? width * 0.9;
  }

  /// Get responsive widget height
  double cardHeight({
    double? phoneHeight,
    double? tabletHeight,
    double? largeTabletHeight,
  }) {
    if (isLargeTablet) {
      return largeTabletHeight ?? height * 0.7;
    } else if (isTablet) {
      return tabletHeight ?? height * 0.75;
    }
    return phoneHeight ?? height * 0.8;
  }

  /// Get device pixel ratio
  double get devicePixelRatio => MediaQuery.of(context).devicePixelRatio;

  /// Get text scale factor
  double get textScaleFactor => MediaQuery.of(context).textScaler.scale(1.0);

  /// Get orientation
  Orientation get orientation => MediaQuery.of(context).orientation;

  /// Check if system has requested bold text
  bool get boldText => MediaQuery.of(context).boldText;

  /// Get safe area padding
  EdgeInsets get safeAreaPadding {
    final padding = MediaQuery.of(context).padding;
    return padding;
  }

  /// Get bottom padding accounting for keyboard and system UI
  double get bottomPadding =>
      max(padding.bottom, viewInsets.bottom);

  /// Helper to get responsive grid count
  /// Typically: 1 column on phone, 2 on tablet, 3 on large tablet
  int get gridCrossAxisCount {
    if (isLargeTablet) return 3;
    if (isTablet) return 2;
    return 1;
  }

  /// Helper to get responsive grid child aspect ratio
  double get gridChildAspectRatio {
    if (isLargeTablet) return 1.0;
    if (isTablet) return 1.1;
    return 1.2;
  }

  /// Get max width for content (useful for web/desktop layouts)
  double get maxContentWidth => isLargeTablet ? width * 0.8 : width;

  /// Get max height for content
  double get maxContentHeight => height;
}

/// Convenience getters for responsive sizing
double maxDimension(double value) =>
    value > 100 ? value : double.infinity;

double minDimension(double value) =>
    value < 0 ? 0 : value;
