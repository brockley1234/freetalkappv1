import 'package:flutter/material.dart';

/// Custom page route with smooth slide and fade animation
class PageTransitionRoute extends PageRoute {
  final WidgetBuilder builder;
  final String? title;
  final TransitionType transitionType;
  final Duration duration;

  PageTransitionRoute({
    required this.builder,
    this.title,
    this.transitionType = TransitionType.slideRight,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  bool get opaque => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (transitionType) {
      case TransitionType.slideRight:
        return _buildSlideRightTransition(animation, secondaryAnimation, child);
      case TransitionType.slideLeft:
        return _buildSlideLeftTransition(animation, secondaryAnimation, child);
      case TransitionType.fadeScale:
        return _buildFadeScaleTransition(animation, secondaryAnimation, child);
      case TransitionType.fadeOnly:
        return _buildFadeOnlyTransition(animation, secondaryAnimation, child);
    }
  }

  Widget _buildSlideRightTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildSlideLeftTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildFadeScaleTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  Widget _buildFadeOnlyTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

enum TransitionType {
  slideRight,
  slideLeft,
  fadeScale,
  fadeOnly,
}

/// Helper function for easy navigation with animations
void navigateTo(
  BuildContext context,
  WidgetBuilder pageBuilder, {
  TransitionType transitionType = TransitionType.slideRight,
  Duration duration = const Duration(milliseconds: 300),
}) {
  Navigator.of(context).push(
    PageTransitionRoute(
      builder: pageBuilder,
      transitionType: transitionType,
      duration: duration,
    ),
  );
}

/// Push page and replace current (for login flows)
void navigateReplaceTo(
  BuildContext context,
  WidgetBuilder pageBuilder, {
  TransitionType transitionType = TransitionType.slideRight,
  Duration duration = const Duration(milliseconds: 300),
}) {
  Navigator.of(context).pushReplacement(
    PageTransitionRoute(
      builder: pageBuilder,
      transitionType: transitionType,
      duration: duration,
    ),
  );
}

/// Push page and clear all previous routes (for post-login navigation)
void navigateToAndClearStack(
  BuildContext context,
  WidgetBuilder pageBuilder, {
  TransitionType transitionType = TransitionType.slideRight,
  Duration duration = const Duration(milliseconds: 300),
}) {
  Navigator.of(context).pushAndRemoveUntil(
    PageTransitionRoute(
      builder: pageBuilder,
      transitionType: transitionType,
      duration: duration,
    ),
    (route) => false,
  );
}
