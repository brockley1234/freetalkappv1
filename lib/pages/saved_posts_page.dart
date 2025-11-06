import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_appearance_animations.dart';
import 'post_detail_page.dart';
import 'user_profile_page.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _savedPosts = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getSavedPosts(page: 1, limit: 10);

      if (result['success']) {
        setState(() {
          _savedPosts = result['data']['posts'] ?? [];
          _currentPage = result['data']['currentPage'] ?? 1;
          _hasMore = result['data']['hasMore'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to load saved posts'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading saved posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await ApiService.getSavedPosts(
        page: _currentPage + 1,
        limit: 10,
      );

      if (result['success']) {
        setState(() {
          final List<dynamic> newPosts = result['data']['posts'] ?? [];
          _savedPosts.addAll(newPosts);
          _currentPage = result['data']['currentPage'] ?? _currentPage;
          _hasMore = result['data']['hasMore'] ?? false;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _savedPosts.clear();
    });
    await _loadSavedPosts();
  }

  void _handleUnsavePost(String postId) async {
    try {
      final result = await ApiService.toggleSavePost(postId);

      if (result['success']) {
        setState(() {
          _savedPosts.removeWhere((post) => post['_id'] == postId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post removed from saved'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unsave post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPostOptions(BuildContext context, String postId, String authorId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_remove,
                  color: Colors.orange,
                ),
                title: const Text('Remove from Saved'),
                onTap: () {
                  Navigator.pop(context);
                  _handleUnsavePost(postId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(userId: authorId),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Posts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedPosts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _refreshPosts,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _savedPosts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _savedPosts.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final post = _savedPosts[index];
                      final author = post['author'];

                      return ScaleBounceAnimation(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        autoStart: true,
                        child: PostCard(
                          postId: post['_id'] ?? '',
                          authorId: author['_id'] ?? '',
                          userName:
                              author['username'] ?? author['name'] ?? 'Unknown',
                          userAvatar: author['avatar'],
                          timeAgo: _getTimeAgo(post['createdAt']),
                          content: post['content'] ?? '',
                          reactionsCount: post['reactionsCount'] ?? 0,
                          comments: post['commentsCount'] ?? 0,
                          userReaction: post['userReaction'],
                          reactionsSummary: post['reactionsSummary'] ?? {},
                          images: post['images'] != null
                              ? List<String>.from(post['images'])
                              : null,
                          videos: post['videos'] != null
                              ? List<String>.from(post['videos'])
                              : null,
                          onReactionTap: () {
                            // Handle reaction tap
                          },
                          onCommentTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PostDetailPage(postId: post['_id']),
                              ),
                            );
                          },
                          onSettingsTap: () {
                            _showPostOptions(
                                context, post['_id'], author['_id']);
                          },
                          onShareTap: () {
                            // Handle share
                          },
                          onUserTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfilePage(userId: author['_id']),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Saved Posts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts you save will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
