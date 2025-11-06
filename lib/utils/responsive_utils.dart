import 'package:flutter/material.dart';

/// Centralized responsive sizing system for all screen sizes
/// Scales from 320px (small phones) to 1920px+ (desktop)
/// Ensures consistent layout across all devices
class ResponsiveUtils {
  static final ResponsiveUtils _instance = ResponsiveUtils._internal();

  factory ResponsiveUtils() {
    return _instance;
  }

  ResponsiveUtils._internal();

  // ============================================================================
  // SCREEN DIMENSIONS
  // ============================================================================

  /// Get device screen width in logical pixels
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get device screen height in logical pixels
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get device pixel ratio (for high-DPI detection)
  static double devicePixelRatio(BuildContext context) =>
      MediaQuery.of(context).devicePixelRatio;

  /// Get safe area padding (accounts for notches, status bars)
  static EdgeInsets getSafeAreaPadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  // ============================================================================
  // DEVICE TYPE DETECTION
  // ============================================================================

  /// True if device is small phone (width < 400px)
  /// Examples: iPhone SE (375px), older phones
  static bool isSmallPhone(BuildContext context) => screenWidth(context) < 400;

  /// True if device is mobile phone (width 400-599px)
  /// Examples: iPhone 12/13/14 (390px), Pixel 4/5 (412px)
  static bool isMobile(BuildContext context) =>
      screenWidth(context) >= 400 && screenWidth(context) < 600;

  /// True if device is tablet (width 600-1199px)
  /// Examples: iPad Mini (768px), Android tablets
  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= 600 && screenWidth(context) < 1200;

  /// True if device is desktop/web (width >= 1200px)
  /// Examples: Desktop browsers, large tablets
  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1200;

  /// Get current screen size category
  static String getDeviceType(BuildContext context) {
    if (isSmallPhone(context)) return 'small_phone';
    if (isMobile(context)) return 'mobile';
    if (isTablet(context)) return 'tablet';
    return 'desktop';
  }

  // ============================================================================
  // TEXT SCALING
  // ============================================================================

  /// Calculate responsive text scale factor
  /// Small phones: 0.85x, Normal phones: 1.0x, Tablets: 1.2x, Desktop: 1.3x
  static double getTextScale(BuildContext context) {
    final width = screenWidth(context);
    if (width < 400) return 0.85; // Very small phones
    if (width < 600) return 1.0; // Normal phones
    if (width < 1200) return 1.2; // Tablets
    return 1.3; // Desktop
  }

  // ============================================================================
  // RESPONSIVE FONT SIZES (with text scaling)
  // ============================================================================

  /// Large heading font size (H1)
  /// Scales: 27px → 42px depending on screen size
  static double getHeadingSize(BuildContext context) {
    final scale = getTextScale(context);
    return 32 * scale;
  }

  /// Medium heading font size (H2)
  /// Scales: 17px → 24px depending on screen size
  static double getSubheadingSize(BuildContext context) {
    final scale = getTextScale(context);
    return 20 * scale;
  }

  /// Standard body text font size
  /// Scales: 13.6px → 20.8px depending on screen size
  static double getBodySize(BuildContext context) {
    final scale = getTextScale(context);
    return 16 * scale;
  }

  /// Small text font size (captions, hints)
  /// Scales: 11.9px → 18.2px depending on screen size
  static double getSmallSize(BuildContext context) {
    final scale = getTextScale(context);
    return 14 * scale;
  }

  /// Extra small text font size (micro text)
  /// Scales: 8.5px → 13px depending on screen size
  static double getExtraSmallSize(BuildContext context) {
    final scale = getTextScale(context);
    return 10 * scale;
  }

  /// Large title for page headers
  /// Scales: 29.75px → 46.8px depending on screen size
  static double getTitleSize(BuildContext context) {
    final scale = getTextScale(context);
    return 35 * scale;
  }

  // ============================================================================
  // RESPONSIVE SPACING (Padding & Margin)
  // ============================================================================

  /// Standard padding value - scales with screen width
  /// Small phones: 8px, Normal phones: 12px, Tablets: 16px, Desktop: 24px
  static double getPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width < 400) return 8.0;
    if (width < 600) return 12.0;
    if (width < 1200) return 16.0;
    return 24.0;
  }

  /// Standard margin value (1.5x padding)
  static double getMargin(BuildContext context) {
    return getPadding(context) * 1.5;
  }

  /// Small spacing (0.5x padding)
  static double getSmallSpacing(BuildContext context) {
    return getPadding(context) * 0.5;
  }

  /// Large spacing (2x padding)
  static double getLargeSpacing(BuildContext context) {
    return getPadding(context) * 2;
  }

  /// Extra large spacing (3x padding)
  static double getExtraLargeSpacing(BuildContext context) {
    return getPadding(context) * 3;
  }

  // ============================================================================
  // RESPONSIVE COMPONENT SIZING
  // ============================================================================

  /// Button height for touch targets
  /// Minimum 48dp per Material guidelines, scales up on larger screens
  /// Scales: 41px → 62px depending on screen size
  static double getButtonHeight(BuildContext context) {
    final scale = getTextScale(context);
    return 48 * scale;
  }

  /// Button width - full screen width on mobile, constrained on desktop
  /// Mobile: 90% screen width, Tablet: 70%, Desktop: 400px fixed
  static double getButtonWidth(BuildContext context) {
    if (isMobile(context) || isSmallPhone(context)) {
      return screenWidth(context) * 0.9;
    } else if (isTablet(context)) {
      return screenWidth(context) * 0.7;
    }
    return 400;
  }

  /// Icon size for standard icons
  /// Scales: 20px → 31px depending on screen size
  static double getIconSize(BuildContext context) {
    final scale = getTextScale(context);
    return 24 * scale;
  }

  /// Large icon size for primary actions
  /// Scales: 41px → 62px depending on screen size
  static double getLargeIconSize(BuildContext context) {
    final scale = getTextScale(context);
    return 48 * scale;
  }

  /// Small icon size for badges, indicators
  /// Scales: 13.6px → 20.8px depending on screen size
  static double getSmallIconSize(BuildContext context) {
    final scale = getTextScale(context);
    return 16 * scale;
  }

  /// Avatar size for user profiles
  /// Scales: 42.5px → 65px depending on screen size
  static double getAvatarSize(BuildContext context) {
    final scale = getTextScale(context);
    return 50 * scale;
  }

  /// Small avatar for message bubbles, lists
  /// Scales: 34px → 52px depending on screen size
  static double getSmallAvatarSize(BuildContext context) {
    final scale = getTextScale(context);
    return 40 * scale;
  }

  // ============================================================================
  // RESPONSIVE IMAGE & MEDIA SIZING
  // ============================================================================

  /// Image height for card images, thumbnails
  /// Small phones: 200px, Normal: 250px, Tablets: 350px, Desktop: 500px
  static double getImageHeight(BuildContext context) {
    final width = screenWidth(context);
    if (width < 400) return 200;
    if (width < 600) return 250;
    if (width < 1200) return 350;
    return 500;
  }

  /// Video thumbnail size
  static double getVideoThumbnailHeight(BuildContext context) {
    return getImageHeight(context) * 0.75;
  }

  /// Profile cover image height
  /// Smaller on phones, larger on desktop
  static double getCoverImageHeight(BuildContext context) {
    return isDesktop(context) ? 400 : 200;
  }

  // ============================================================================
  // RESPONSIVE BORDER & CORNER RADIUS
  // ============================================================================

  /// Border radius for cards, buttons
  /// Scales with padding for visual consistency
  static double getBorderRadius(BuildContext context) {
    return getPadding(context) * 1.5;
  }

  /// Large border radius for rounded cards
  static double getLargeBorderRadius(BuildContext context) {
    return getPadding(context) * 3;
  }

  /// Small border radius for subtle corners
  static double getSmallBorderRadius(BuildContext context) {
    return getPadding(context) * 0.75;
  }

  /// Extra large border radius for modals, large surfaces
  static double getExtraLargeBorderRadius(BuildContext context) {
    return getPadding(context) * 4;
  }

  // ============================================================================
  // RESPONSIVE GRID & LAYOUT
  // ============================================================================

  /// Number of columns for grid layouts
  /// Mobile: 2 columns, Tablet: 3, Desktop: 4
  static int getGridColumns(BuildContext context) {
    if (isSmallPhone(context) || isMobile(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  /// Grid spacing between items
  static double getGridSpacing(BuildContext context) {
    return getPadding(context);
  }

  // ============================================================================
  // RESPONSIVE CARD & LIST SIZING
  // ============================================================================

  /// Max width for content cards (prevents very wide cards on desktop)
  /// Mobile: full width, Desktop: constrained to readable width
  static double getMaxCardWidth(BuildContext context) {
    if (isDesktop(context)) return 600;
    return screenWidth(context) * 0.95;
  }

  /// List item height for standard list tiles
  /// Scales: 55px → 70px depending on screen size
  static double getListItemHeight(BuildContext context) {
    final scale = getTextScale(context);
    return 65 * scale;
  }

  /// Message bubble max width (percent of screen)
  /// Prevents messages from being too wide on desktop
  static double getMessageBubbleMaxWidth(BuildContext context) {
    if (isMobile(context) || isSmallPhone(context)) {
      return screenWidth(context) * 0.85;
    } else if (isTablet(context)) {
      return screenWidth(context) * 0.75;
    }
    return 600;
  }

  // ============================================================================
  // RESPONSIVE DIALOG & MODAL SIZING
  // ============================================================================

  /// Dialog/Modal width
  /// Mobile: full width, Desktop: 500px fixed
  static double getDialogWidth(BuildContext context) {
    if (isDesktop(context)) return 500;
    return screenWidth(context) * 0.95;
  }

  /// Dialog/Modal height (max, will shrink to content)
  static double getDialogMaxHeight(BuildContext context) {
    return screenHeight(context) * 0.8;
  }

  /// Dialog inset (padding from screen edges)
  static double getDialogInset(BuildContext context) {
    return getPadding(context) * 2;
  }

  // ============================================================================
  // RESPONSIVE INPUT FIELD SIZING
  // ============================================================================

  /// Text field height (with padding)
  /// Scales: 44px → 56px depending on screen size
  static double getInputFieldHeight(BuildContext context) {
    final scale = getTextScale(context);
    return 52 * scale;
  }

  /// Input field border width
  static double getInputBorderWidth(BuildContext context) {
    return 1.5;
  }

  // ============================================================================
  // RESPONSIVE TAB & NAV SIZING
  // ============================================================================

  /// Bottom navigation bar height
  static double getBottomNavHeight(BuildContext context) {
    return 70;
  }

  /// Tab height for tab bars
  static double getTabHeight(BuildContext context) {
    final scale = getTextScale(context);
    return 48 * scale;
  }

  /// App bar height
  static double getAppBarHeight(BuildContext context) {
    return kToolbarHeight;
  }

  // ============================================================================
  // RESPONSIVE DIVIDER & LINE SIZING
  // ============================================================================

  /// Divider line thickness
  static double getDividerThickness(BuildContext context) {
    return 1.0;
  }

  /// Divider height (vertical space)
  static double getDividerHeight(BuildContext context) {
    return getSmallSpacing(context);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get responsive layout orientation preference
  /// Useful for determining column/row layouts
  static Axis getPreferredAxis(BuildContext context) {
    return isDesktop(context) ? Axis.horizontal : Axis.vertical;
  }

  /// Check if layout should stack vertically
  static bool shouldStackVertically(BuildContext context) {
    return !isDesktop(context);
  }

  /// Get safe top padding (status bar + notch)
  static double getSafeTopPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get safe bottom padding (home indicator)
  static double getSafeBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Print debugging info about current screen configuration
  static void debugPrintScreenInfo(BuildContext context) {
    final width = screenWidth(context);
    final height = screenHeight(context);
    final pixelRatio = devicePixelRatio(context);
    final deviceType = getDeviceType(context);
    final textScale = getTextScale(context);

    debugPrint('''
╔════════════════════════════════════════════════════╗
║           RESPONSIVE SCREEN INFO DEBUG             ║
╠════════════════════════════════════════════════════╣
║ Width: ${width.toStringAsFixed(1)}px
║ Height: ${height.toStringAsFixed(1)}px
║ Pixel Ratio: ${pixelRatio.toStringAsFixed(2)}x
║ Device Type: $deviceType
║ Text Scale: ${textScale.toStringAsFixed(2)}x
║ Padding: ${getPadding(context).toStringAsFixed(1)}px
║ Button Height: ${getButtonHeight(context).toStringAsFixed(1)}px
║ Body Font: ${getBodySize(context).toStringAsFixed(1)}px
║ Safe Top: ${getSafeTopPadding(context).toStringAsFixed(1)}px
║ Safe Bottom: ${getSafeBottomPadding(context).toStringAsFixed(1)}px
╚════════════════════════════════════════════════════╝
    ''');
  }
}
