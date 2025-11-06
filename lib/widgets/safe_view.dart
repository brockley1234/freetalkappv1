import 'package:flutter/material.dart';

/// Enhanced SafeArea wrapper with additional padding options
/// Handles notches, keyboard, and custom spacing
class SafeView extends StatelessWidget {
  final Widget child;
  final EdgeInsets additionalPadding;
  final bool avoidNotch;
  final bool avoidKeyboard;
  final bool maintainBottomViewPadding;
  final Color? backgroundColor;

  const SafeView({
    super.key,
    required this.child,
    this.additionalPadding = EdgeInsets.zero,
    this.avoidNotch = true,
    this.avoidKeyboard = true,
    this.maintainBottomViewPadding = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = avoidKeyboard ? mediaQuery.viewInsets : EdgeInsets.zero;

    return Container(
      color: backgroundColor,
      child: SafeArea(
        left: true,
        right: true,
        top: avoidNotch,
        bottom: true,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: Padding(
          padding: additionalPadding +
              EdgeInsets.only(
                bottom: viewInsets.bottom,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// Safe area that respects keyboard
class KeyboardAwareView extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool resizeToAvoidBottomInset;

  const KeyboardAwareView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeView(
        avoidKeyboard: true,
        additionalPadding: padding,
        child: child,
      ),
    );
  }
}

/// Bottom sheet safe area
class BottomSheetSafeView extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const BottomSheetSafeView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding +
            EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
        child: child,
      ),
    );
  }
}
