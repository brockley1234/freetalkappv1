import 'package:flutter/material.dart';

/// Animated widget for displaying user name with elegant fade-in and scale animations
class AnimatedNameWidget extends StatefulWidget {
  final String name;
  final TextStyle? style;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedNameWidget({
    super.key,
    required this.name,
    this.style,
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedNameWidget> createState() => _AnimatedNameWidgetState();
}

class _AnimatedNameWidgetState extends State<AnimatedNameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController, curve: widget.animationCurve),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController, curve: widget.animationCurve),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _animationController, curve: widget.animationCurve),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnimatedNameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      // Reset and replay animation when name changes
      _animationController.reset();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _scaleAnimation,
        _slideAnimation,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Text(
                widget.name,
                style: widget.style ??
                    const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
