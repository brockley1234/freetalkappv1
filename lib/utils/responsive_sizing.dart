import 'package:flutter/material.dart';

/// Responsive sizing utility for consistent UI across all screen sizes
/// 
/// Usage:
/// ```dart
/// final size = ResponsiveSize(context);
/// Container(
///   width: size.getResponsiveWidth(0.9),  // 90% of screen width
///   padding: EdgeInsets.all(size.padding),
///   child: Text('Hello', style: TextStyle(fontSize: size.fontSize)),
/// )
/// ```
class ResponsiveSize {
  final BuildContext context;
  late final Size _screenSize;
  late final bool _isLandscape;
  late final bool _isTablet;
  late final bool _isSmallPhone;
  late final bool _isLargePhone;

  ResponsiveSize(this.context) {
    _screenSize = MediaQuery.of(context).size;
    _isLandscape = _screenSize.width > _screenSize.height;
    _isTablet = _screenSize.width >= 600;
    _isSmallPhone = _screenSize.width < 380;
    _isLargePhone = _screenSize.width >= 450;
  }

  /// Screen dimensions
  double get screenWidth => _screenSize.width;
  double get screenHeight => _screenSize.height;
  double get statusBarHeight => MediaQuery.of(context).padding.top;
  double get bottomPadding => MediaQuery.of(context).padding.bottom;
  bool get isLandscape => _isLandscape;
  bool get isPortrait => !_isLandscape;
  bool get isTablet => _isTablet;
  bool get isSmallPhone => _isSmallPhone;
  bool get isLargePhone => _isLargePhone;

  /// Get responsive width based on percentage
  /// ```dart
  /// getResponsiveWidth(0.9)  // 90% of screen width
  /// ```
  double getResponsiveWidth(double percentage) {
    return screenWidth * percentage;
  }

  /// Get responsive height based on percentage
  /// ```dart
  /// getResponsiveHeight(0.5)  // 50% of screen height
  /// ```
  double getResponsiveHeight(double percentage) {
    return screenHeight * percentage;
  }

  /// Get responsive dimension that scales with screen size
  /// ```dart
  /// getResponsiveDimension(
  ///   small: 100,    // for phones < 380px
  ///   medium: 120,   // for phones 380-450px
  ///   large: 150,    // for phones > 450px
  ///   tablet: 200,   // for tablets
  /// )
  /// ```
  double getResponsiveDimension({
    double small = 0,
    double medium = 0,
    double large = 0,
    double tablet = 0,
  }) {
    if (_isTablet && tablet > 0) return tablet;
    if (_isLargePhone && large > 0) return large;
    if (!_isSmallPhone && medium > 0) return medium;
    return small > 0 ? small : medium;
  }

  /// Responsive padding/spacing (scales with screen size)
  double get paddingXSmall => getResponsiveDimension(small: 4, medium: 4, large: 4, tablet: 6);
  double get paddingSmall => getResponsiveDimension(small: 8, medium: 8, large: 8, tablet: 12);
  double get paddingMedium => getResponsiveDimension(small: 12, medium: 12, large: 16, tablet: 20);
  double get paddingLarge => getResponsiveDimension(small: 16, medium: 16, large: 20, tablet: 24);
  double get paddingXLarge => getResponsiveDimension(small: 20, medium: 24, large: 28, tablet: 32);
  double get paddingHuge => getResponsiveDimension(small: 32, medium: 40, large: 48, tablet: 56);

  /// Responsive font sizes
  double get fontXSmall => getResponsiveDimension(small: 10, medium: 10, large: 10, tablet: 11);
  double get fontSmall => getResponsiveDimension(small: 12, medium: 12, large: 13, tablet: 14);
  double get fontBase => getResponsiveDimension(small: 14, medium: 14, large: 15, tablet: 16);
  double get fontMedium => getResponsiveDimension(small: 16, medium: 16, large: 17, tablet: 18);
  double get fontLarge => getResponsiveDimension(small: 18, medium: 20, large: 22, tablet: 24);
  double get fontXLarge => getResponsiveDimension(small: 24, medium: 28, large: 32, tablet: 36);
  double get fontHuge => getResponsiveDimension(small: 32, medium: 36, large: 40, tablet: 48);

  /// Responsive icon sizes
  double get iconXSmall => getResponsiveDimension(small: 12, medium: 14, large: 16, tablet: 18);
  double get iconSmall => getResponsiveDimension(small: 16, medium: 18, large: 20, tablet: 22);
  double get iconMedium => getResponsiveDimension(small: 20, medium: 22, large: 24, tablet: 28);
  double get iconLarge => getResponsiveDimension(small: 24, medium: 28, large: 32, tablet: 36);
  double get iconXLarge => getResponsiveDimension(small: 32, medium: 36, large: 40, tablet: 48);

  /// Responsive button sizes
  double get buttonHeightSmall => getResponsiveDimension(small: 32, medium: 36, large: 40, tablet: 44);
  double get buttonHeightMedium => getResponsiveDimension(small: 40, medium: 44, large: 48, tablet: 52);
  double get buttonHeightLarge => getResponsiveDimension(small: 48, medium: 52, large: 56, tablet: 60);

  /// Responsive radius
  double get radiusSmall => getResponsiveDimension(small: 4, medium: 6, large: 8, tablet: 12);
  double get radiusMedium => getResponsiveDimension(small: 8, medium: 12, large: 12, tablet: 16);
  double get radiusLarge => getResponsiveDimension(small: 12, medium: 16, large: 16, tablet: 20);
  double get radiusXLarge => getResponsiveDimension(small: 16, medium: 20, large: 24, tablet: 28);

  /// Responsive avatar/image sizes
  double get avatarXSmall => getResponsiveDimension(small: 24, medium: 28, large: 32, tablet: 36);
  double get avatarSmall => getResponsiveDimension(small: 32, medium: 36, large: 40, tablet: 44);
  double get avatarMedium => getResponsiveDimension(small: 40, medium: 44, large: 48, tablet: 56);
  double get avatarLarge => getResponsiveDimension(small: 48, medium: 56, large: 64, tablet: 72);

  /// Common responsive EdgeInsets
  EdgeInsets get insetsXSmall => EdgeInsets.all(paddingXSmall);
  EdgeInsets get insetsSmall => EdgeInsets.all(paddingSmall);
  EdgeInsets get insetsMedium => EdgeInsets.all(paddingMedium);
  EdgeInsets get insetsLarge => EdgeInsets.all(paddingLarge);
  EdgeInsets get insetsXLarge => EdgeInsets.all(paddingXLarge);
  EdgeInsets get insetsHuge => EdgeInsets.all(paddingHuge);

  /// Responsive EdgeInsets with different horizontal and vertical
  EdgeInsets getInsetsSymmetric({double? horizontal, double? vertical}) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? paddingMedium,
      vertical: vertical ?? paddingMedium,
    );
  }

  /// Responsive EdgeInsets with different sides
  EdgeInsets getInsetsOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: left > 0 ? left : paddingMedium,
      top: top > 0 ? top : paddingMedium,
      right: right > 0 ? right : paddingMedium,
      bottom: bottom > 0 ? bottom : paddingMedium,
    );
  }

  /// Get aspect ratio height for responsive containers
  double getAspectRatioHeight(double width, double aspectRatio) {
    return width / aspectRatio;
  }

  /// Responsive text styles
  TextStyle getHeading1() => TextStyle(
    fontSize: fontXLarge,
    fontWeight: FontWeight.bold,
  );

  TextStyle getHeading2() => TextStyle(
    fontSize: fontLarge,
    fontWeight: FontWeight.bold,
  );

  TextStyle getHeading3() => TextStyle(
    fontSize: fontMedium,
    fontWeight: FontWeight.w600,
  );

  TextStyle getBodyLarge() => TextStyle(
    fontSize: fontBase,
    fontWeight: FontWeight.normal,
  );

  TextStyle getBodySmall() => TextStyle(
    fontSize: fontSmall,
    fontWeight: FontWeight.normal,
  );

  TextStyle getCaption() => TextStyle(
    fontSize: fontXSmall,
    fontWeight: FontWeight.normal,
    color: Colors.grey[600],
  );
}

/// Extension method for easier access in widgets
extension ResponsiveSizeExtension on BuildContext {
  ResponsiveSize get responsive => ResponsiveSize(this);
}
