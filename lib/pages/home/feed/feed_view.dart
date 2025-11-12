import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/feed_controller.dart';
import '../../../widgets/feed_filter_selector.dart';
import '../../../utils/responsive_dimensions.dart';
import '../widgets/feed_header.dart';
import '../widgets/stories_bar.dart';
import '../widgets/post_card_adapter.dart';
import '../../../widgets/skeleton_loader.dart';

/// Main feed view displaying posts
class FeedView extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final List<dynamic> stories;
  final Function() onCreatePost;
  final Function(String postId) onPostTap;
  final Function(String userId) onUserTap;

  const FeedView({
    super.key,
    required this.currentUser,
    required this.stories,
    required this.onCreatePost,
    required this.onPostTap,
    required this.onUserTap,
  });

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more posts when scrolling near the bottom
      context.read<FeedController>().loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedController>(
      builder: (context, feedController, child) {
        return RefreshIndicator(
          onRefresh: () => feedController.refresh(),
          backgroundColor: Theme.of(context).colorScheme.surface,
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App bar with banner
              _buildAppBar(),
              
              // Stories bar
              if (widget.stories.isNotEmpty)
                SliverToBoxAdapter(
                  child: StoriesBar(
                    stories: widget.stories,
                    currentUserId: widget.currentUser?['_id'],
                  ),
                ),
              
              // Feed filter and sort
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveDimensions.getHorizontalPadding(context),
                    vertical: 12,
                  ),
                  child: FeedFilterSelector(
                    selectedFilter: feedController.selectedFilter,
                    selectedSort: feedController.selectedSort,
                    onFilterChanged: (filter) => feedController.setFilter(filter),
                    onSortChanged: (sort) => feedController.setSort(sort),
                  ),
                ),
              ),
              
              // Create post prompt
              SliverToBoxAdapter(
                child: _buildCreatePostPrompt(),
              ),
              
              // Feed content
              _buildFeedContent(feedController),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: ResponsiveDimensions.getFeedBannerHeight(context),
      floating: false,
      pinned: true,
      flexibleSpace: FeedHeader(
        currentUser: widget.currentUser,
      ),
    );
  }

  Widget _buildCreatePostPrompt() {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: widget.onCreatePost,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.currentUser?['avatar'] != null
                      ? NetworkImage(widget.currentUser!['avatar'])
                      : null,
                  child: widget.currentUser?['avatar'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'What\'s on your mind?',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.image,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedContent(FeedController feedController) {
    // Error state
    if (feedController.hasError && feedController.posts.isEmpty) {
      return SliverFillRemaining(
        child: _buildErrorState(
          message: feedController.errorMessage ?? 'Failed to load posts',
          onRetry: () => feedController.refresh(),
        ),
      );
    }

    // Loading state (initial load)
    if (feedController.isLoading && feedController.posts.isEmpty) {
      return SliverFillRemaining(
        child: _buildLoadingState(),
      );
    }

    // Empty state
    if (feedController.posts.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    // Posts list
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Show loading indicator at the bottom
          if (index == feedController.posts.length) {
            if (feedController.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (!feedController.hasMore) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'You\'ve reached the end!',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final post = feedController.posts[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index % 3) * 100),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: ResponsiveDimensions.getHorizontalPadding(context),
                right: ResponsiveDimensions.getHorizontalPadding(context),
                bottom: ResponsiveDimensions.getItemSpacing(context) * 1.5,
              ),
              child: PostCardAdapter(
                post: post,
                currentUser: widget.currentUser,
                onPostTap: () => widget.onPostTap(post['_id']),
                onUserTap: () {
                  final author = post['author'];
                  if (author != null && author['_id'] != null) {
                    widget.onUserTap(author['_id']);
                  }
                },
              ),
            ),
          );
        },
        childCount: feedController.posts.length +
            1, // +1 for loading indicator or end message
      ),
    );
  }

  Widget _buildLoadingState() {
    // Show skeleton loaders for better perceived performance
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveDimensions.getHorizontalPadding(context),
                vertical: ResponsiveDimensions.getItemSpacing(context),
              ),
              child: const PostCardSkeleton(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState({required String message, required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow some users to see their posts!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

