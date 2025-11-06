import 'package:flutter/material.dart';
import 'dart:math' as math;

class ReactionAnimation extends StatefulWidget {
  final String emoji;
  final VoidCallback? onComplete;

  const ReactionAnimation({
    super.key,
    required this.emoji,
    this.onComplete,
  });

  @override
  State<ReactionAnimation> createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<ReactionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late double _horizontalOffset;

  @override
  void initState() {
    super.initState();

    // Random horizontal offset for variety
    _horizontalOffset = (math.Random().nextDouble() - 0.5) * 100;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Float up animation
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -150,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Fade out animation
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    // Scale animation (pop in then shrink)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: _floatAnimation.value,
          left: MediaQuery.of(context).size.width / 2 +
              _horizontalOffset -
              25, // Center with offset
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 50),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget to manage multiple reaction animations
class ReactionAnimationOverlay extends StatefulWidget {
  const ReactionAnimationOverlay({super.key});

  static final GlobalKey<ReactionAnimationOverlayState> globalKey =
      GlobalKey<ReactionAnimationOverlayState>();

  @override
  State<ReactionAnimationOverlay> createState() =>
      ReactionAnimationOverlayState();

  static void show(BuildContext context, String emoji) {
    final state = globalKey.currentState;
    if (state != null) {
      state._addReaction(emoji);
    }
  }
}

class ReactionAnimationOverlayState extends State<ReactionAnimationOverlay> {
  final List<String> _activeReactions = [];
  int _reactionIdCounter = 0;

  void _addReaction(String emoji) {
    setState(() {
      _activeReactions.add('$emoji#$_reactionIdCounter');
      _reactionIdCounter++;
    });
  }

  void _removeReaction(String reactionKey) {
    setState(() {
      _activeReactions.remove(reactionKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _activeReactions.map((reactionKey) {
        final emoji = reactionKey.split('#')[0];
        return ReactionAnimation(
          key: ValueKey(reactionKey),
          emoji: emoji,
          onComplete: () => _removeReaction(reactionKey),
        );
      }).toList(),
    );
  }
}

/// Simple burst animation for reactions
class ReactionBurst extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const ReactionBurst({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<ReactionBurst> createState() => _ReactionBurstState();
}

class _ReactionBurstState extends State<ReactionBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(ReactionBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}
