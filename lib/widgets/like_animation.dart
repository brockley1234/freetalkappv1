import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Like animation with heart burst and scale effect
class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onPressed;
  final int likeCount;
  final Color likedColor;
  final Color unlikedColor;
  final double iconSize;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.onPressed,
    this.likeCount = 0,
    this.likedColor = Colors.red,
    this.unlikedColor = Colors.grey,
    this.iconSize = 24,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    _bounceAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
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
    return GestureDetector(
      onTap: () {
        if (widget.isLiked) {
          _controller.reverse();
        } else {
          _controller.forward(from: 0);
        }
        widget.onPressed();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Heart burst particles (only show during animation when liking)
          if (widget.isLiked)
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: HeartBurstPainter(
                    progress: _bounceAnimation.value,
                  ),
                  size: Size.square(widget.iconSize * 3),
                );
              },
            ),
          // Main like button
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color:
                      widget.isLiked ? widget.likedColor : widget.unlikedColor,
                  size: widget.iconSize,
                ),
              );
            },
          ),
          // Like count
          if (widget.likeCount > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.likedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.likeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for heart burst effect
class HeartBurstPainter extends CustomPainter {
  final double progress;
  static const particleCount = 8;

  HeartBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = size.width / 2;

    for (int i = 0; i < particleCount; i++) {
      final angle = (2 * math.pi * i) / particleCount;
      final distance = maxDistance * progress;

      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final opacity = 1 - progress;
      final size = 4 * (1 - progress);

      final paint = Paint()
        ..color = Colors.red.withValues(alpha: opacity)
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(x, y), size, paint);
    }
  }

  @override
  bool shouldRepaint(HeartBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Double tap to like overlay animation
class DoubleTapLike extends StatefulWidget {
  final VoidCallback onLike;
  final Widget child;

  const DoubleTapLike({
    super.key,
    required this.onLike,
    required this.child,
  });

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 40,
      ),
    ]).animate(_controller);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    widget.onLike();
    setState(() {
      _showHeart = true;
    });
    _controller.forward(from: 0).then((_) {
      setState(() {
        _showHeart = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_showHeart)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 80,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Animated counter for likes with number change animation
class AnimatedLikeCounter extends StatefulWidget {
  final int count;
  final TextStyle? textStyle;

  const AnimatedLikeCounter({
    super.key,
    required this.count,
    this.textStyle,
  });

  @override
  State<AnimatedLikeCounter> createState() => _AnimatedLikeCounterState();
}

class _AnimatedLikeCounterState extends State<AnimatedLikeCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _previousCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _previousCount = widget.count;
  }

  @override
  void didUpdateWidget(AnimatedLikeCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _previousCount = oldWidget.count;
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
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = 1 - progress;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Old count fade out and slide up
            Transform.translate(
              offset: Offset(0, -20 * progress),
              child: Opacity(
                opacity: opacity,
                child: Text(
                  _previousCount.toString(),
                  style: widget.textStyle,
                ),
              ),
            ),
            // New count fade in and slide up
            Transform.translate(
              offset: Offset(0, 20 * (1 - progress)),
              child: Opacity(
                opacity: progress,
                child: Text(
                  widget.count.toString(),
                  style: widget.textStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
