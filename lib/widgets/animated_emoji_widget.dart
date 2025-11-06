import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A widget that displays emojis with smooth animations.
/// Supports scale and opacity animations with customizable parameters.
class AnimatedEmojiWidget extends StatefulWidget {
  /// The emoji to display
  final String emoji;

  /// The size of the emoji
  final double size;

  /// Duration of the animation
  final Duration animationDuration;

  /// Type of animation to apply
  final EmojiAnimationType animationType;

  /// Whether to repeat the animation
  final bool repeat;

  /// Curve used for the animation
  final Curve curve;

  /// Optional tooltip to display on hover
  final String? tooltip;

  /// Optional callback when animation completes
  final VoidCallback? onAnimationComplete;

  const AnimatedEmojiWidget({
    super.key,
    required this.emoji,
    this.size = 16.0,
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationType = EmojiAnimationType.scaleAndFade,
    this.repeat = false,
    this.curve = Curves.elasticOut,
    this.tooltip,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedEmojiWidget> createState() => _AnimatedEmojiWidgetState();
}

enum EmojiAnimationType {
  /// Simple scale animation
  scale,

  /// Fade in/out animation
  fade,

  /// Combined scale and fade animation
  scaleAndFade,

  /// Pulse animation (continuous scale)
  pulse,

  /// Bounce animation
  bounce,

  /// Rotate animation
  rotate,

  /// Float animation (up and down)
  float,
}

class _AnimatedEmojiWidgetState extends State<AnimatedEmojiWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Set up the appropriate animation curve and values
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: widget.curve),
    );

    // Handle animation completion
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();

        if (widget.repeat) {
          _animationController.repeat();
        }
      }
    });

    // Start the animation
    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnimatedEmojiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart animation if key properties changed
    if (oldWidget.emoji != widget.emoji ||
        oldWidget.animationType != widget.animationType ||
        oldWidget.animationDuration != widget.animationDuration) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget emojiWidget = Text(
      widget.emoji,
      style: TextStyle(fontSize: widget.size),
    );

    // Wrap with appropriate animation based on type
    switch (widget.animationType) {
      case EmojiAnimationType.scale:
        emojiWidget = ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(_animation),
          child: emojiWidget,
        );
        break;

      case EmojiAnimationType.fade:
        emojiWidget = FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_animation),
          child: emojiWidget,
        );
        break;

      case EmojiAnimationType.scaleAndFade:
        emojiWidget = ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(_animation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_animation),
            child: emojiWidget,
          ),
        );
        break;

      case EmojiAnimationType.pulse:
        emojiWidget = ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.2).animate(_animation),
          child: emojiWidget,
        );
        break;

      case EmojiAnimationType.bounce:
        emojiWidget = AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Create a bouncy effect using sine curve
            final bounceValue =
                (math.sin(_animation.value * 2 * math.pi) * 0.1);
            return Transform.translate(
              offset: Offset(0, bounceValue * 10),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(_animation),
                child: child,
              ),
            );
          },
          child: emojiWidget,
        );
        break;

      case EmojiAnimationType.rotate:
        emojiWidget = RotationTransition(
          turns: Tween<double>(begin: 0.0, end: 1.0).animate(_animation),
          child: emojiWidget,
        );
        break;

      case EmojiAnimationType.float:
        emojiWidget = AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Create a floating effect
            final floatValue = math.sin(_animation.value * 2 * math.pi) * 0.15;
            return Transform.translate(
              offset: Offset(0, floatValue * -8),
              child: child,
            );
          },
          child: emojiWidget,
        );
        break;
    }

    // Wrap with tooltip if provided
    if (widget.tooltip != null) {
      emojiWidget = Tooltip(
        message: widget.tooltip!,
        child: emojiWidget,
      );
    }

    return emojiWidget;
  }
}
