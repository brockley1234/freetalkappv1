import 'package:flutter/material.dart';

/// Animated list widget that staggers the appearance of posts
class AnimatedPostList extends StatefulWidget {
  final List<dynamic> posts;
  final Widget Function(BuildContext, int, dynamic) itemBuilder;
  final VoidCallback? onLoadMore;
  final bool isLoading;
  final Duration staggerDelay;
  final Duration animationDuration;

  const AnimatedPostList({
    super.key,
    required this.posts,
    required this.itemBuilder,
    this.onLoadMore,
    this.isLoading = false,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedPostList> createState() => _AnimatedPostListState();
}

class _AnimatedPostListState extends State<AnimatedPostList> {
  late List<GlobalKey<_AnimatedPostItemState>> _itemKeys;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeKeys();
    _scrollController.addListener(_onScroll);
  }

  void _initializeKeys() {
    _itemKeys = List.generate(
      widget.posts.length,
      (index) => GlobalKey<_AnimatedPostItemState>(),
      growable: true,
    );
  }

  @override
  void didUpdateWidget(AnimatedPostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts.length != oldWidget.posts.length) {
      _initializeKeys();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      widget.onLoadMore?.call();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.posts.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.posts.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(
              color: Colors.blue.shade400,
            ),
          );
        }

        return _AnimatedPostItem(
          key: _itemKeys[index],
          index: index,
          staggerDelay: widget.staggerDelay,
          animationDuration: widget.animationDuration,
          child: widget.itemBuilder(context, index, widget.posts[index]),
        );
      },
    );
  }
}

/// Individual animated post item with stagger effect
class _AnimatedPostItem extends StatefulWidget {
  final int index;
  final Duration staggerDelay;
  final Duration animationDuration;
  final Widget child;

  const _AnimatedPostItem({
    super.key,
    required this.index,
    required this.staggerDelay,
    required this.animationDuration,
    required this.child,
  });

  @override
  State<_AnimatedPostItem> createState() => _AnimatedPostItemState();
}

class _AnimatedPostItemState extends State<_AnimatedPostItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Stagger the animation based on index
    Future.delayed(
      widget.staggerDelay * widget.index,
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
