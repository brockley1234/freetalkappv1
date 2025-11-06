import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/time_utils.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/video_player_widget.dart';
import '../config/app_config.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _currentUser;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPost();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _cleanupSocketListeners();
    super.dispose();
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // Listen for new comments on this post
    socketService.socket?.on('post:commented', (data) {
      debugPrint('💬 [PostDetail] Socket: post:commented event received');
      if (mounted && data['postId'] == widget.postId) {
        debugPrint('💬 [PostDetail] Reloading post...');
        _loadPost();
      }
    });

    // Listen for comment replies
    socketService.socket?.on('comment:replied', (data) {
      debugPrint('↩️ [PostDetail] Socket: comment:replied event received');
      if (mounted && data['postId'] == widget.postId) {
        debugPrint('↩️ [PostDetail] Reloading post...');
        _loadPost();
      }
    });

    // Listen for comment reactions
    socketService.socket?.on('comment:reacted', (data) {
      debugPrint('👍 [PostDetail] Socket: comment:reacted event received');
      if (mounted && data['postId'] == widget.postId) {
        debugPrint('👍 [PostDetail] Reloading post...');
        _loadPost();
      }
    });

    socketService.socket?.on('comment:unreacted', (data) {
      debugPrint('👎 [PostDetail] Socket: comment:unreacted event received');
      if (mounted && data['postId'] == widget.postId) {
        debugPrint('👎 [PostDetail] Reloading post...');
        _loadPost();
      }
    });
  }

  void _cleanupSocketListeners() {
    final socketService = SocketService();
    socketService.socket?.off('post:commented');
    socketService.socket?.off('comment:replied');
    socketService.socket?.off('comment:reacted');
    socketService.socket?.off('comment:unreacted');
  }

  Future<void> _loadCurrentUser() async {
    try {
      final result = await ApiService.getCurrentUser();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _currentUser = result['data']['user'];
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getPost(widget.postId);

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _post = result['data']['post'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load post';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPost() async {
    await _loadPost();
  }

  void _showCommentsBottomSheet() {
    if (_post == null) return;

    final commentsCount = _post!['commentsCount'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: widget.postId,
        initialCommentsCount: commentsCount,
        onCommentAdded: () {
          _refreshPost();
        },
      ),
    );
  }

  String _formatTimeAgo(String? dateString) {
    // Use TimeUtils to format as YYYY/MM/DD HH:MM
    return TimeUtils.formatMessageTimestamp(dateString);
  }

  void _showPostOptionsMenu() {
    if (_post == null) return;

    // Check if current user is the post owner
    final currentUserId = _currentUser?['_id'];
    final authorId = _post!['author']?['_id'];
    final isOwner = currentUserId != null && currentUserId == authorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Share option
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share Post'),
              onTap: () {
                Navigator.pop(context);
                _sharePost();
              },
            ),

            // Copy Link option
            ListTile(
              leading: const Icon(Icons.link, color: Colors.green),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink();
              },
            ),

            // Copy Text option
            ListTile(
              leading: const Icon(Icons.content_copy, color: Colors.orange),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                _copyPostText();
              },
            ),

            // Delete option (only for post owner)
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost();
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePost() async {
    if (_post == null) return;

    final author = _post!['author'] ?? {};
    final authorName = author['name'] ?? 'Unknown User';
    final content = _post!['content'] ?? '';

    try {
      final shareText = '''
Check out this post by $authorName on ReelTalk:

"$content"
  
View post: ${ApiService.baseApi}posts/${widget.postId}
      '''
          .trim();

      await Share.share(shareText, subject: 'Post by $authorName on ReelTalk');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyPostLink() async {
    final postLink = '${AppConfig.webBaseUrl}/post/${widget.postId}';

    try {
      await Clipboard.setData(ClipboardData(text: postLink));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Link copied to clipboard'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyPostText() {
    if (_post == null) return;

    final content = _post!['content'] ?? '';
    Clipboard.setData(ClipboardData(text: content));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post text copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDeletePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeletePost() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting post...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final result = await ApiService.deletePost(widget.postId);

      // Hide loading snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Go back to previous screen
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete post'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLike() async {
    if (_post == null) return;

    final reactions = _post!['reactions'] ?? [];
    final hasLiked =
        reactions.isNotEmpty && reactions.any((r) => r['type'] == 'like');

    // Optimistic update
    setState(() {
      if (hasLiked) {
        // Remove like
        _post!['reactions'] =
            (reactions as List).where((r) => r['type'] != 'like').toList();
        _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 1) - 1;
      } else {
        // Add like
        final updatedReactions = List.from(reactions);
        updatedReactions.add({
          'type': 'like',
          'createdAt': DateTime.now().toIso8601String(),
        });
        _post!['reactions'] = updatedReactions;
        _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 0) + 1;
      }
    });

    // Call API
    try {
      Map<String, dynamic> result;
      if (hasLiked) {
        result = await ApiService.removeReaction(postId: widget.postId);
      } else {
        result = await ApiService.addReaction(
          postId: widget.postId,
          reactionType: 'like',
        );
      }

      if (result['success'] == true) {
        // Refresh post to get accurate data
        await _refreshPost();
      } else {
        // Revert on failure
        setState(() {
          if (hasLiked) {
            // Re-add like
            final updatedReactions = List.from(_post!['reactions'] ?? []);
            updatedReactions.add({
              'type': 'like',
              'createdAt': DateTime.now().toIso8601String(),
            });
            _post!['reactions'] = updatedReactions;
            _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 0) + 1;
          } else {
            // Remove like
            _post!['reactions'] = ((_post!['reactions'] ?? []) as List)
                .where((r) => r['type'] != 'like')
                .toList();
            _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 1) - 1;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update reaction'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (hasLiked) {
          // Re-add like
          final updatedReactions = List.from(_post!['reactions'] ?? []);
          updatedReactions.add({
            'type': 'like',
            'createdAt': DateTime.now().toIso8601String(),
          });
          _post!['reactions'] = updatedReactions;
          _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 0) + 1;
        } else {
          // Remove like
          _post!['reactions'] = ((_post!['reactions'] ?? []) as List)
              .where((r) => r['type'] != 'like')
              .toList();
          _post!['reactionsCount'] = (_post!['reactionsCount'] ?? 1) - 1;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Go back',
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 0) {
            Navigator.pop(context);
          }
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _refreshPost, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_post == null) {
      return const Center(child: Text('Post not found'));
    }

    return RefreshIndicator(
      onRefresh: _refreshPost,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            _buildPostContent(),
            _buildPostImages(),
            _buildPostVideos(),
            _buildPostStats(),
            const Divider(height: 1),
            _buildPostActions(),
            const Divider(height: 1),
            _buildCommentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final author = _post!['author'] ?? {};
    final authorName = author['name'] ?? 'Unknown User';
    final userAvatar = authorName.isNotEmpty
        ? authorName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'U';
    final createdAt = _post!['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue,
            child: Text(
              userAvatar,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showPostOptionsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    final content = _post!['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
    );
  }

  Widget _buildPostImages() {
    final images = _post!['images'];
    if (images == null || (images as List).isEmpty) {
      return const SizedBox.shrink();
    }

    final imageList = List<String>.from(images);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 400,
        child: imageList.length == 1
            ? Image.network(
                '${ApiService.baseApi}${imageList[0]}',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  );
                },
              )
            : PageView.builder(
                itemCount: imageList.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    '${ApiService.baseApi}${imageList[index]}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPostVideos() {
    final videos = _post!['videos'];
    if (videos == null || (videos as List).isEmpty) {
      return const SizedBox.shrink();
    }

    final videoList = List<String>.from(videos);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: videoList.map((videoUrl) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VideoPlayerWidget(
              videoUrl: '${ApiService.baseApi}$videoUrl',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostStats() {
    final reactionsCount = _post!['reactionsCount'] ?? 0;
    final commentsCount = _post!['commentsCount'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (reactionsCount > 0) ...[
            Icon(Icons.thumb_up, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              '$reactionsCount',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(width: 16),
          ],
          if (commentsCount > 0)
            Text(
              '$commentsCount comment${commentsCount > 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildPostActions() {
    // Check if current user has reacted
    final reactions = _post!['reactions'] ?? [];
    final currentUserId = _currentUser?['_id'];

    // Check if the current user has liked this post
    final hasLiked = currentUserId != null &&
        reactions.isNotEmpty &&
        reactions.any((r) {
          if (r['type'] != 'like') return false;
          // Handle both cases: reaction['user'] as String ID or as Map with _id
          final userId = r['user'] is Map ? r['user']['_id'] : r['user'];
          return userId == currentUserId;
        });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: 'Like',
            onTap: _handleLike,
            isActive: hasLiked,
          ),
          _buildActionButton(
            icon: Icons.comment_outlined,
            label: 'Comment',
            onTap: _showCommentsBottomSheet,
          ),
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: _sharePost,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? Colors.blue : Colors.grey.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    final comments = _post!['comments'];
    if (comments == null || (comments as List).isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.comment_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'No comments yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to comment!',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final commentsList = List<Map<String, dynamic>>.from(comments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Comments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        ...commentsList.map((comment) => _buildCommentItem(comment)),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final user = comment['user'] ?? {};
    final userName = user['name'] ?? 'Unknown User';
    final userAvatar = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'U';
    final content = comment['content'] ?? '';
    final gifUrl = comment['gif'];
    final createdAt = comment['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue,
            child: Text(
              userAvatar,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          content,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                      if (gifUrl != null && gifUrl.toString().isNotEmpty) ...[
                        if (content.isNotEmpty) const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: gifUrl,
                            width: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 200,
                              height: 150,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 200,
                              height: 150,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
