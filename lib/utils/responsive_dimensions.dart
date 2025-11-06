import 'package:flutter/material.dart';

/// Helper class for responsive sizing based on screen dimensions
/// Provides consistent spacing, padding, and sizing across all screen sizes
class ResponsiveDimensions {
  static const double _mediumPhoneWidth = 375;
  static const double _tabletWidth = 768;
  static const double _desktopWidth = 1024;

  /// Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _tabletWidth) {
      return DeviceType.phone;
    } else if (width < _desktopWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get horizontal padding - responsive based on screen width
  static double getHorizontalPadding(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 12.0; // Very small phones
    } else if (width < _tabletWidth) {
      return 16.0; // Phones
    } else if (width < _desktopWidth) {
      return 20.0; // Tablets
    } else {
      return 24.0; // Desktop
    }
  }

  /// Get vertical padding - responsive based on screen height
  static double getVerticalPadding(BuildContext context) {
    final height = getScreenHeight(context);
    if (height < 600) {
      return 8.0;
    } else if (height < 800) {
      return 12.0;
    } else {
      return 16.0;
    }
  }

  /// Get card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final hPad = getHorizontalPadding(context);
    final vPad = getVerticalPadding(context);
    return EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);
  }

  /// Get spacing between items
  static double getItemSpacing(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 8.0;
    } else if (width < _tabletWidth) {
      return 12.0;
    } else {
      return 16.0;
    }
  }

  /// Get font size - responsive based on screen width
  static double getFontSize(
    BuildContext context, {
    double smallPhoneSize = 12,
    double phoneSize = 14,
    double tabletSize = 16,
    double desktopSize = 18,
  }) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return smallPhoneSize;
    } else if (width < _tabletWidth) {
      return phoneSize;
    } else if (width < _desktopWidth) {
      return tabletSize;
    } else {
      return desktopSize;
    }
  }

  /// Get heading font size
  static double getHeadingFontSize(BuildContext context) {
    return getFontSize(
      context,
      smallPhoneSize: 20,
      phoneSize: 24,
      tabletSize: 28,
      desktopSize: 32,
    );
  }

  /// Get subheading font size
  static double getSubheadingFontSize(BuildContext context) {
    return getFontSize(
      context,
      smallPhoneSize: 14,
      phoneSize: 16,
      tabletSize: 18,
      desktopSize: 20,
    );
  }

  /// Get body font size
  static double getBodyFontSize(BuildContext context) {
    return getFontSize(
      context,
      smallPhoneSize: 12,
      phoneSize: 14,
      tabletSize: 15,
      desktopSize: 16,
    );
  }

  /// Get small font size for captions
  static double getCaptionFontSize(BuildContext context) {
    return getFontSize(
      context,
      smallPhoneSize: 10,
      phoneSize: 12,
      tabletSize: 13,
      desktopSize: 14,
    );
  }

  /// Get avatar size - responsive
  static double getAvatarSize(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 40.0;
    } else if (width < _tabletWidth) {
      return 48.0;
    } else {
      return 56.0;
    }
  }

  /// Get small avatar size
  static double getSmallAvatarSize(BuildContext context) {
    return getAvatarSize(context) * 0.6;
  }

  /// Get icon size - responsive
  static double getIconSize(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 20.0;
    } else if (width < _tabletWidth) {
      return 24.0;
    } else {
      return 28.0;
    }
  }

  /// Get large icon size
  static double getLargeIconSize(BuildContext context) {
    return getIconSize(context) * 1.5;
  }

  /// Get border radius - responsive
  static double getBorderRadius(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 8.0;
    } else if (width < _tabletWidth) {
      return 12.0;
    } else {
      return 16.0;
    }
  }

  /// Get card width for layouts
  static double getCardWidth(BuildContext context, {int columns = 1}) {
    final width = getScreenWidth(context);
    final padding = getHorizontalPadding(context);
    final totalPadding = padding * 2;
    final itemSpacing = getItemSpacing(context);
    final totalSpacing = itemSpacing * (columns - 1);

    return (width - totalPadding - totalSpacing) / columns;
  }

  /// Get maximum content width (useful for tablet/desktop)
  static double getMaxContentWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _tabletWidth) {
      return width;
    } else if (width < _desktopWidth) {
      return 720.0;
    } else {
      return 1000.0;
    }
  }

  /// Get responsive list view padding
  static EdgeInsets getListViewPadding(BuildContext context) {
    final hPad = getHorizontalPadding(context);
    return EdgeInsets.symmetric(horizontal: hPad);
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return width * 0.9;
    } else if (width < _tabletWidth) {
      return width * 0.85;
    } else if (width < _desktopWidth) {
      return width * 0.7;
    } else {
      return 500.0;
    }
  }

  /// Get responsive button height
  static double getButtonHeight(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 44.0;
    } else if (width < _tabletWidth) {
      return 48.0;
    } else {
      return 52.0;
    }
  }

  /// Get responsive input field height
  static double getInputFieldHeight(BuildContext context) {
    return getButtonHeight(context);
  }

  /// Get story circle size
  static double getStoryCircleSize(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 60.0;
    } else if (width < _tabletWidth) {
      return 70.0;
    } else {
      return 80.0;
    }
  }

  /// Get post card image height
  static double getPostImageHeight(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 280.0;
    } else if (width < _tabletWidth) {
      return 300.0;
    } else {
      return 400.0;
    }
  }

  /// Get feed banner height
  static double getFeedBannerHeight(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < _mediumPhoneWidth) {
      return 200.0; // Increased from 160
    } else if (width < _tabletWidth) {
      return 240.0; // Increased from 180
    } else {
      return 280.0; // Increased from 220
    }
  }

  /// Get shadow elevation - responsive
  static double getShadowElevation(BuildContext context) {
    final deviceType = getDeviceType(context);
    if (deviceType == DeviceType.phone) {
      return 2.0;
    } else if (deviceType == DeviceType.tablet) {
      return 4.0;
    } else {
      return 6.0;
    }
  }
}

enum DeviceType {
  phone,
  tablet,
  desktop,
}
