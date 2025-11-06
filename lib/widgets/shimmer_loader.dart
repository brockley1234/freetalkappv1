import 'package:flutter/material.dart';

/// Shimmer loading skeleton animation
class ShimmerLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoader({
    super.key,
    required this.child,
    required this.isLoading,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton card placeholder for posts
class PostSkeletonLoader extends StatelessWidget {
  const PostSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header (avatar + name + time)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 100,
                        color: const Color(0xFFE0E0E0),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 60,
                        color: const Color(0xFFE0E0E0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Container(
              height: 14,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: double.infinity,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 200,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 12),
            // Image placeholder
            Container(
              height: 200,
              width: double.infinity,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 12),
            // Action buttons
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  height: 10,
                  width: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                  width: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                  width: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for message list
class MessageSkeletonLoader extends StatelessWidget {
  const MessageSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      isLoading: true,
      child: Column(
        children: List.generate(
          5,
          (index) {
            final isFromMe = index % 2 == 0;
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment:
                    isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isFromMe)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    height: 40,
                    width: 150,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  if (isFromMe) const SizedBox(width: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Generic container skeleton
class ContainerSkeleton extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ContainerSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      isLoading: true,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
