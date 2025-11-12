import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../utils/url_utils.dart';
import '../../../utils/responsive_dimensions.dart';
import '../widgets/post_card_adapter.dart';
import '../../profile_settings_page.dart';
import '../../../widgets/skeleton_loader.dart';

/// Profile overview tab showing user's profile and posts
class ProfileOverview extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Function(String postId) onPostTap;
  final Function(String userId) onUserTap;
  final Function() onProfileUpdated;

  const ProfileOverview({
    super.key,
    required this.currentUser,
    required this.onPostTap,
    required this.onUserTap,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileOverview> createState() => _ProfileOverviewState();
}

class _ProfileOverviewState extends State<ProfileOverview>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _userPosts = [];
  bool _isLoadingPosts = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    if (_isLoadingPosts) return;

    final userId = widget.currentUser?['_id'];
    if (userId == null) return;

    setState(() {
      _isLoadingPosts = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getUserPosts(userId: userId);
      if (result['success'] == true && mounted) {
        setState(() {
          _userPosts = result['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadUserPosts();
    widget.onProfileUpdated();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          _buildProfileHeader(),
          _buildStatsBar(),
          _buildActionButtons(),
          _buildPostsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final userName = widget.currentUser?['name'] ?? 'User';
    final userAvatar = widget.currentUser?['avatar'];
    final userBio = widget.currentUser?['bio'] ?? '';

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage: userAvatar != null
                  ? CachedNetworkImageProvider(
                      UrlUtils.getFullAvatarUrl(userAvatar),
                    )
                  : null,
              child: userAvatar == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (widget.currentUser?['isVerified'] == true) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.verified,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
            if (userBio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                userBio,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final followersCount = widget.currentUser?['followersCount'] ?? 0;
    final followingCount = widget.currentUser?['followingCount'] ?? 0;
    final postsCount = _userPosts.length;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveDimensions.getHorizontalPadding(context),
          vertical: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Posts', postsCount),
            _buildStatItem('Followers', followersCount),
            _buildStatItem('Following', followingCount),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveDimensions.getHorizontalPadding(context),
          vertical: 8,
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileSettingsPage(
                  user: widget.currentUser,
                  onEditProfile: () {
                    widget.onProfileUpdated();
                    _refresh();
                  },
                ),
              ),
            ).then((_) => _refresh());
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    if (_isLoadingPosts) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveDimensions.getHorizontalPadding(context),
              vertical: ResponsiveDimensions.getItemSpacing(context),
            ),
            child: const PostCardSkeleton(),
          ),
          childCount: 3,
        ),
      );
    }

    if (_hasError) {
      return SliverFillRemaining(
        child: Center(
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
                'Failed to load posts',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserPosts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userPosts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.post_add,
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
                'Start sharing your thoughts!',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = _userPosts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
            );
          },
          childCount: _userPosts.length,
        ),
      ),
    );
  }
}

