import 'package:flutter/material.dart';

/// Breakpoint constants for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Device type based on screen width
enum DeviceType { mobile, tablet, desktop }

/// Adaptive layout that adjusts based on screen size
/// Provides different layouts for mobile, tablet, and desktop
class AdaptiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget? desktopBody;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const AdaptiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    this.desktopBody,
    this.tabletBreakpoint = Breakpoints.mobile,
    this.desktopBreakpoint = Breakpoints.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint) {
          return desktopBody ?? tabletBody ?? mobileBody;
        } else if (constraints.maxWidth >= tabletBreakpoint) {
          return tabletBody ?? mobileBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}

/// Builder that provides device type
class AdaptiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const AdaptiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = _getDeviceType(constraints.maxWidth);
        return builder(context, deviceType);
      },
    );
  }

  DeviceType _getDeviceType(double width) {
    if (width >= Breakpoints.desktop) {
      return DeviceType.desktop;
    } else if (width >= Breakpoints.mobile) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }
}

/// Responsive value that changes based on screen size
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T getValue(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktop && desktop != null) {
      return desktop!;
    } else if (width >= Breakpoints.mobile && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Adaptive padding that scales with screen size
class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const AdaptivePadding({
    super.key,
    required this.child,
    required this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        EdgeInsets padding;
        if (constraints.maxWidth >= Breakpoints.desktop) {
          padding = desktopPadding ?? tabletPadding ?? mobilePadding;
        } else if (constraints.maxWidth >= Breakpoints.mobile) {
          padding = tabletPadding ?? mobilePadding;
        } else {
          padding = mobilePadding;
        }

        return Padding(
          padding: padding,
          child: child,
        );
      },
    );
  }
}

/// Adaptive grid that changes column count based on screen size
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth >= Breakpoints.desktop) {
          columns = desktopColumns ?? tabletColumns ?? mobileColumns;
        } else if (constraints.maxWidth >= Breakpoints.mobile) {
          columns = tabletColumns ?? mobileColumns;
        } else {
          columns = mobileColumns;
        }

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

/// Constrain maximum width for desktop (prevents content from being too wide)
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool centerAlign;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.centerAlign = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        alignment: centerAlign ? Alignment.center : null,
        child: child,
      ),
    );
  }
}

/// Two-column layout for tablet/desktop with sidebar
class TwoColumnLayout extends StatelessWidget {
  final Widget main;
  final Widget sidebar;
  final double sidebarWidth;
  final double breakpoint;

  const TwoColumnLayout({
    super.key,
    required this.main,
    required this.sidebar,
    this.sidebarWidth = 300,
    this.breakpoint = Breakpoints.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          // Two column layout for tablet/desktop
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(
                width: sidebarWidth,
                child: sidebar,
              ),
            ],
          );
        } else {
          // Single column for mobile
          return main;
        }
      },
    );
  }
}

/// Extension for easy access to responsive values
extension ResponsiveExtension on BuildContext {
  /// Get current device type
  DeviceType get deviceType {
    final width = MediaQuery.of(this).size.width;
    if (width >= Breakpoints.desktop) {
      return DeviceType.desktop;
    } else if (width >= Breakpoints.mobile) {
      return DeviceType.tablet;
    }
    return DeviceType.mobile;
  }

  /// Check if mobile
  bool get isMobile => deviceType == DeviceType.mobile;

  /// Check if tablet
  bool get isTablet => deviceType == DeviceType.tablet;

  /// Check if desktop
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Get responsive value
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (deviceType) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}
