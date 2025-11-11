import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/url_utils.dart';

class FeedErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String title;

  const FeedErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.title = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const FeedEmptyWidget({
    super.key,
    this.title = 'No posts yet',
    this.message = 'Start following users to see their posts in your feed',
    this.icon = Icons.explore_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onAction != null && actionLabel != null)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.person_add),
                  label: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedEndReachedWidget extends StatefulWidget {
  const FeedEndReachedWidget({super.key});

  @override
  State<FeedEndReachedWidget> createState() => _FeedEndReachedWidgetState();
}

class _FeedEndReachedWidgetState extends State<FeedEndReachedWidget> {
  List<dynamic> _suggestedUsers = [];
  bool _isLoading = false;
  final Map<String, bool> _followingState = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getSuggestedUsers(limit: 5);

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        
        // Safely extract users list with multiple fallbacks
        List<dynamic> users = [];
        if (data is Map) {
          if (data.containsKey('users') && data['users'] != null) {
            if (data['users'] is List) {
              users = (data['users'] as List)
                  .whereType<dynamic>()
                  .toList();
            }
          }
        } else if (data is List) {
          // If data itself is a list of users
          users = data.whereType<dynamic>().toList();
        }
        
        setState(() {
          _suggestedUsers = users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(String userId, bool isCurrentlyFollowing) async {
    try {
      setState(() {
        _followingState[userId] = !isCurrentlyFollowing;
      });

      if (isCurrentlyFollowing) {
        await ApiService.unfollowUser(userId);
      } else {
        await ApiService.followUser(userId);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _followingState[userId] = isCurrentlyFollowing;
      });
      debugPrint('Error toggling follow: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'ve reached the end',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow more users to see their posts',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              // Suggested Users Section
              if (_isLoading)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_suggestedUsers.isNotEmpty)
                Column(
                  children: [
                    Text(
                      'Suggested Users',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _suggestedUsers[index];
                        
                        // Null safety check
                        if (user == null) {
                          return const SizedBox.shrink();
                        }
                        
                        final userId = user['_id'] ?? '';
                        final isFollowing = _followingState[userId] ?? 
                            (user['isFollowing'] ?? false);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  backgroundImage: (user['avatar'] is String && 
                                          (user['avatar'] as String).isNotEmpty)
                                      ? NetworkImage(
                                          UrlUtils.getFullAvatarUrl(
                                            user['avatar'] as String,
                                          ),
                                        )
                                      : null,
                                  child: (user['avatar'] == null ||
                                          (user['avatar'] is! String) ||
                                          ((user['avatar'] as String).isEmpty))
                                      ? Text(
                                          ((user['name'] ?? 'U') as String)
                                              .split(' ')
                                              .map((n) => n.isNotEmpty ? n[0] : '')
                                              .where((c) => c.isNotEmpty)
                                              .take(2)
                                              .join()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // User Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['name'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${user['username'] ?? 'unknown'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${user['followersCount'] ?? 0} followers',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Follow Button
                                FilledButton(
                                  onPressed: userId.isNotEmpty
                                      ? () => _toggleFollow(userId, isFollowing)
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : Theme.of(context).colorScheme.primary,
                                    foregroundColor: isFollowing
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No more suggested users available',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
