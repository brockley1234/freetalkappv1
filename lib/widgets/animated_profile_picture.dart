import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated profile picture with multiple animation options
class AnimatedProfilePicture extends StatefulWidget {
  final String? imageUrl;
  final String? initials;
  final double radius;
  final VoidCallback? onTap;
  final AnimationType animationType;
  final bool autoPlay;

  const AnimatedProfilePicture({
    super.key,
    this.imageUrl,
    this.initials,
    this.radius = 80,
    this.onTap,
    this.animationType = AnimationType.scale,
    this.autoPlay = true,
  });

  @override
  State<AnimatedProfilePicture> createState() => _AnimatedProfilePictureState();
}

enum AnimationType {
  scale, // Pulse/scale animation
  rotate, // Rotating glow effect
  glow, // Glowing border animation
  float, // Floating/levitation effect
  combined, // All effects combined (subtle)
}

class _AnimatedProfilePictureState extends State<AnimatedProfilePicture>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _glowController;
  late AnimationController _floatController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Scale animation (pulse effect)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_scaleController);

    // Rotate animation (continuous rotation)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _rotateAnimation =
        Tween<double>(begin: 0, end: 1).animate(_rotateController);

    // Glow animation (border glow effect)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_glowController);

    // Float animation (vertical floating effect)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _floatAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 8, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_floatController);

    if (widget.autoPlay) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    switch (widget.animationType) {
      case AnimationType.scale:
        _scaleController.repeat();
        break;
      case AnimationType.rotate:
        _rotateController.repeat();
        break;
      case AnimationType.glow:
        _glowController.repeat();
        break;
      case AnimationType.float:
        _floatController.repeat();
        break;
      case AnimationType.combined:
        _scaleController.repeat();
        _rotateController.repeat();
        _glowController.repeat();
        _floatController.repeat();
        break;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the image provider based on the URL type
    ImageProvider? imageProvider;
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      // Check if it's a local asset (for bot avatars)
      if (widget.imageUrl!.startsWith('assets/')) {
        imageProvider = AssetImage(widget.imageUrl!);
      } else {
        // Network URL
        imageProvider = NetworkImage(widget.imageUrl!);
      }
    }

    Widget avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.white,
        backgroundImage: imageProvider,
        child: widget.initials != null && imageProvider == null
            ? Text(
                widget.initials!,
                style: TextStyle(
                  fontSize: widget.radius * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              )
            : null,
      ),
    );

    // Wrap with animations based on type
    avatar = _buildAnimatedWrapper(avatar);

    // Add tap functionality
    if (widget.onTap != null) {
      avatar = GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildAnimatedWrapper(Widget child) {
    switch (widget.animationType) {
      case AnimationType.scale:
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, _) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
        );

      case AnimationType.rotate:
        return AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, _) {
            return Transform.rotate(
              angle: _rotateAnimation.value * 2 * math.pi,
              child: _buildGlowContainer(child, 2),
            );
          },
        );

      case AnimationType.glow:
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, _) {
            return _buildGlowContainer(child, _glowAnimation.value);
          },
        );

      case AnimationType.float:
        return AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, -_floatAnimation.value),
              child: child,
            );
          },
        );

      case AnimationType.combined:
        return AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _floatAnimation,
            _glowAnimation,
          ]),
          builder: (context, _) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.translate(
                offset: Offset(0, -_floatAnimation.value),
                child: _buildGlowContainer(child, _glowAnimation.value * 0.5),
              ),
            );
          },
        );
    }
  }

  Widget _buildGlowContainer(Widget child, double glowIntensity) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glowing border
        Container(
          width: widget.radius * 2 + 12,
          height: widget.radius * 2 + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: glowIntensity * 0.6),
                blurRadius: 20 * glowIntensity,
                spreadRadius: 8 * glowIntensity,
              ),
              BoxShadow(
                color: Colors.cyan.withValues(alpha: glowIntensity * 0.3),
                blurRadius: 10 * glowIntensity,
                spreadRadius: 4 * glowIntensity,
              ),
            ],
          ),
        ),
        // Avatar
        child,
      ],
    );
  }
}

/// Animated profile picture with enhanced interactive effects
class InteractiveAnimatedProfilePicture extends StatefulWidget {
  final String? imageUrl;
  final String? initials;
  final double radius;
  final VoidCallback? onTap;

  const InteractiveAnimatedProfilePicture({
    super.key,
    this.imageUrl,
    this.initials,
    this.radius = 80,
    this.onTap,
  });

  /// Use AnimatedProfilePicture instead for auto-play on all devices
  @Deprecated(
      'Use AnimatedProfilePicture with autoPlay=true instead. This widget only animates on hover (web).')
  static Widget deprecated() => const SizedBox.shrink();

  @override
  State<InteractiveAnimatedProfilePicture> createState() =>
      _InteractiveAnimatedProfilePictureState();
}

class _InteractiveAnimatedProfilePictureState
    extends State<InteractiveAnimatedProfilePicture>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Auto-play subtle animation
    _playSubtleAnimation();
  }

  void _playSubtleAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isHovered) {
        _controller.forward(from: 0).then((_) {
          if (mounted && !_isHovered) {
            Future.delayed(const Duration(seconds: 4), () {
              _playSubtleAnimation();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _rotateAnimation]),
          builder: (context, _) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(_rotateAnimation.value * 0.3),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(
                          alpha: 0.2 + (_scaleAnimation.value - 1.0) * 0.4,
                        ),
                        blurRadius: 15 + (_scaleAnimation.value - 1.0) * 10,
                        offset: const Offset(0, 8),
                      ),
                      if (_isHovered)
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: widget.radius,
                    backgroundColor: Colors.white,
                    backgroundImage: _getImageProvider(),
                    child: widget.initials != null &&
                            (widget.imageUrl == null ||
                                widget.imageUrl!.isEmpty)
                        ? Text(
                            widget.initials!,
                            style: TextStyle(
                              fontSize: widget.radius * 0.6,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return null;
    }
    // Check if it's a local asset (for bot avatars)
    if (widget.imageUrl!.startsWith('assets/')) {
      return AssetImage(widget.imageUrl!);
    } else {
      // Network URL
      return NetworkImage(widget.imageUrl!);
    }
  }
}

/// Animated profile picture with loading skeleton
class AnimatedProfilePictureWithSkeleton extends StatefulWidget {
  final String? imageUrl;
  final String? initials;
  final double radius;
  final bool isLoading;
  final VoidCallback? onTap;

  const AnimatedProfilePictureWithSkeleton({
    super.key,
    this.imageUrl,
    this.initials,
    this.radius = 80,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<AnimatedProfilePictureWithSkeleton> createState() =>
      _AnimatedProfilePictureWithSkeletonState();
}

class _AnimatedProfilePictureWithSkeletonState
    extends State<AnimatedProfilePictureWithSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.linear));

    if (widget.isLoading) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedProfilePictureWithSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _shimmerController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, _) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade100,
                  Colors.grey.shade300,
                ],
                stops: [
                  _shimmerAnimation.value - 1,
                  _shimmerAnimation.value,
                  _shimmerAnimation.value + 1,
                ],
              ).createShader(bounds);
            },
            child: Container(
              width: widget.radius * 2,
              height: widget.radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedProfilePicture(
        imageUrl: widget.imageUrl,
        initials: widget.initials,
        radius: widget.radius,
        animationType: AnimationType.combined,
      ),
    );
  }
}
