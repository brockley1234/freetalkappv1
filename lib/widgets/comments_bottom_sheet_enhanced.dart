import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import 'mention_comment_input.dart';
import 'mention_text.dart';

class CommentsBottomSheetEnhanced extends StatefulWidget {
  final String postId;
  final int initialCommentsCount;
  final VoidCallback onCommentAdded;

  const CommentsBottomSheetEnhanced({
    super.key,
    required this.postId,
    required this.initialCommentsCount,
    required this.onCommentAdded,
  });

  @override
  State<CommentsBottomSheetEnhanced> createState() =>
      _CommentsBottomSheetEnhancedState();
}

class _CommentsBottomSheetEnhancedState
    extends State<CommentsBottomSheetEnhanced> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _cleanupSocketListeners();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _cleanupSocketListeners() {
    final socketService = SocketService();
    socketService.socket?.off('post:commented');
    socketService.socket?.off('comment:replied');
    socketService.socket?.off('comment:reacted');
    socketService.socket?.off('comment:unreacted');
    socketService.socket?.off('reply:reacted');
    socketService.socket?.off('reply:unreacted');
    socketService.socket?.off('reply:replied');
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // Listen for new comments
    socketService.socket?.on('post:commented', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments();
      }
    });

    // Listen for new replies
    socketService.socket?.on('comment:replied', (data) {
      if (mounted && data['postId'] == widget.postId) {
        // Use .then() instead of await to avoid blocking
        _loadComments().catchError(
          (e) => null,
        );
      }
    });

    // Listen for reactions
    socketService.socket?.on('comment:reacted', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments().catchError(
          (e) => null,
        );
      }
    });

    socketService.socket?.on('comment:unreacted', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments().catchError(
          (e) => null,
        );
      }
    });

    // Listen for reply reactions
    socketService.socket?.on('reply:reacted', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments().catchError(
          (e) => null,
        );
      }
    });

    socketService.socket?.on('reply:unreacted', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments().catchError(
          (e) => null,
        );
      }
    });

    // Listen for nested replies
    socketService.socket?.on('reply:replied', (data) {
      if (mounted && data['postId'] == widget.postId) {
        _loadComments().catchError(
          (e) => null,
        );
      }
    });
  }

  Future<void> _loadComments() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getPost(widget.postId);

      if (result['success'] == true && result['data'] != null) {
        final post = result['data']['post'];
        final comments = post['comments'] ?? [];

        // Debug first comment if any
        if (comments.isNotEmpty) {
          // Comments available
        }

        if (mounted) {
          setState(() {
            _comments = comments;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load comments';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading comments: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitComment(String content, List<Map<String, dynamic>> mentionedUsers, String? gifUrl) async {
    if (content.isEmpty && gifUrl == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare mentioned user IDs
      final mentionedUserIds = mentionedUsers
          .map((u) => u['_id'] as String)
          .toList();

      Map<String, dynamic> result;

      if (_replyingToCommentId != null) {
        // Check if it's a nested reply (contains ":")
        if (_replyingToCommentId!.contains(':')) {
          // Nested reply (reply to a reply)
          final parts = _replyingToCommentId!.split(':');
          final commentId = parts[0];
          final replyId = parts[1];
          debugPrint(
            '📝 Adding nested reply to comment: $commentId, reply: $replyId',
          );
          result = await ApiService.addNestedReply(
            postId: widget.postId,
            commentId: commentId,
            replyId: replyId,
            content: content,
          );
        } else {
          // Regular reply to comment
          result = await ApiService.addCommentReply(
            postId: widget.postId,
            commentId: _replyingToCommentId!,
            content: content,
          );
        }
      } else {
        // Submit as comment with GIF support
        result = await ApiService.addComment(
          postId: widget.postId,
          content: content,
          gif: gifUrl,
          mentionedUserIds: mentionedUserIds.isNotEmpty ? mentionedUserIds : null,
        );
      }

      if (result['success'] == true) {
        _commentController.clear();
        _cancelReply();

        // Don't await _loadComments() here - let the socket event handle it
        // This prevents double-loading and UI freeze
        widget.onCommentAdded();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _replyingToCommentId != null
                    ? 'Reply added!'
                    : 'Comment added!',
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add comment'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _replyToComment(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
    });
    _commentFocusNode.requestFocus();
  }

  void _replyToReply(String commentId, String replyId, String userName) {
    setState(() {
      _replyingToCommentId = '$commentId:$replyId'; // Store both IDs
      _replyingToUserName = userName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
  }

  Future<void> _handleCommentReaction(
    String commentId,
    String? currentReaction,
    String reactionType,
  ) async {
    try {
      if (currentReaction == reactionType) {
        // Remove reaction
        await ApiService.removeCommentReaction(
          postId: widget.postId,
          commentId: commentId,
        );
      } else {
        // Add or update reaction
        await ApiService.reactToComment(
          postId: widget.postId,
          commentId: commentId,
          reactionType: reactionType,
        );
      }
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(String? dateString) {
    // Use TimeUtils to properly handle UTC to local time conversion
    return TimeUtils.formatMessageTimestamp(dateString);
  }

  // Safely extract a displayable user name from various possible shapes
  // of the "user" field (Map, String, List, null).
  String _safeUserName(dynamic user) {
    try {
      if (user == null) {
        return 'Unknown User';
      }
      if (user is String) {
        final s = user.trim();
        return s.isEmpty ? 'Unknown User' : s;
      }
      if (user is Map) {
        final dynamic raw = user['name'] ??
            user['username'] ??
            user['fullName'] ??
            user['displayName'];

        if (raw == null) return 'Unknown User';
        final s = raw.toString().trim();
        return s.isEmpty ? 'Unknown User' : s;
      }
      if (user is List && user.isNotEmpty) {
        // Sometimes APIs accidentally send arrays; pick the first element.
        return _safeUserName(user.first);
      }

      return 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  // Generate initials from a user name safely.
  String _initialsFrom(String name) {
    try {
      final parts =
          name.trim().split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return 'U';
      var initials = '';
      for (final p in parts.take(2)) {
        initials += p.substring(0, 1);
      }
      return initials.isEmpty ? 'U' : initials.toUpperCase();
    } catch (_) {
      return 'U';
    }
  }

  void _showReactionPicker(
    BuildContext context,
    String commentId,
    String? currentReaction,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'React to comment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _reactionButton('👍', 'like', commentId, currentReaction),
                _reactionButton('❤️', 'love', commentId, currentReaction),
                _reactionButton('😂', 'haha', commentId, currentReaction),
                _reactionButton('😮', 'wow', commentId, currentReaction),
                _reactionButton('😢', 'sad', commentId, currentReaction),
                _reactionButton('😡', 'angry', commentId, currentReaction),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReplyReactionPicker(
    BuildContext context,
    String commentId,
    String replyId,
    String? currentReaction,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'React to reply',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _replyReactionButton(
                  '👍',
                  'like',
                  commentId,
                  replyId,
                  currentReaction,
                ),
                _replyReactionButton(
                  '❤️',
                  'love',
                  commentId,
                  replyId,
                  currentReaction,
                ),
                _replyReactionButton(
                  '😂',
                  'haha',
                  commentId,
                  replyId,
                  currentReaction,
                ),
                _replyReactionButton(
                  '😮',
                  'wow',
                  commentId,
                  replyId,
                  currentReaction,
                ),
                _replyReactionButton(
                  '😢',
                  'sad',
                  commentId,
                  replyId,
                  currentReaction,
                ),
                _replyReactionButton(
                  '😡',
                  'angry',
                  commentId,
                  replyId,
                  currentReaction,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionButton(
    String emoji,
    String type,
    String commentId,
    String? currentReaction,
  ) {
    final isSelected = currentReaction == type;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleCommentReaction(commentId, currentReaction, type);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  Widget _replyReactionButton(
    String emoji,
    String type,
    String commentId,
    String replyId,
    String? currentReaction,
  ) {
    final isSelected = currentReaction == type;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleReplyReaction(commentId, replyId, currentReaction, type);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  Future<void> _handleReplyReaction(
    String commentId,
    String replyId,
    String? currentReaction,
    String reactionType,
  ) async {
    try {
      if (currentReaction == reactionType) {
        // Remove reaction
        await ApiService.removeReplyReaction(
          postId: widget.postId,
          commentId: commentId,
          replyId: replyId,
        );
      } else {
        // Add or update reaction
        await ApiService.reactToReply(
          postId: widget.postId,
          commentId: commentId,
          replyId: replyId,
          reactionType: reactionType,
        );
      }
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Comments (${_comments.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadComments,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to comment!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return _buildCommentItem(comment);
                            },
                          ),
          ),

          // Replying indicator
          if (_replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to $_replyingToUserName',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: MentionCommentInput(
              controller: _commentController,
              focusNode: _commentFocusNode,
              isSubmitting: _isSubmitting,
              onSubmit: _submitComment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(dynamic comment) {
    final commentId = comment['_id']?.toString() ?? '';
    final user = comment['user'];
    final userName = _safeUserName(user);
    final userInitials = _initialsFrom(userName);
    final userAvatar = user is Map ? user['avatar'] : null;
    final content = (comment['content'] ?? '').toString();
    // Decode HTML entities in GIF URL (e.g., &#x2F; -> /)
    String? gifUrl = comment['gif']?.toString();
    if (gifUrl != null && gifUrl.isNotEmpty) {
      // Decode HTML entities that might have been encoded
      final originalUrl = gifUrl;
      gifUrl = gifUrl
          .replaceAll('&#x2F;', '/')
          .replaceAll('&#47;', '/')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&#x3D;', '=')
          .replaceAll('&#61;', '=')
          .replaceAll('&#63;', '?')
          .replaceAll('&#38;', '&');
      
      // Debug: log if URL was decoded
      if (originalUrl != gifUrl) {
        debugPrint('🔧 Decoded GIF URL: $originalUrl -> $gifUrl');
      }
      
      // Validate URL format
      if (!gifUrl.startsWith('http://') && !gifUrl.startsWith('https://')) {
        debugPrint('⚠️ Invalid GIF URL format: $gifUrl');
        gifUrl = null;
      }
    }
    final createdAt = comment['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);
    final reactions =
        comment['reactions'] is List ? comment['reactions'] as List : const [];
    final replies =
        comment['replies'] is List ? comment['replies'] as List : const [];

    // Get user's reaction if any
    String? userReaction;
    // You'd need to get current user ID from auth/storage
    // For now, we'll leave it null

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                radius: 18,
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                    ? UrlUtils.getAvatarImageProvider(userAvatar)
                    : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Text(
                        userInitials,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (content.isNotEmpty)
                            MentionText(
                              text: content,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                height: 1.4,
                              ),
                              mentionStyle: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              onMentionTap: (userName) async {
                                // Find user from tagged users if available
                                final taggedUsers =
                                    comment['taggedUsers'] as List?;
                                if (taggedUsers != null) {
                                  final user = taggedUsers.firstWhere(
                                    (u) => u['name'] == userName,
                                    orElse: () => null,
                                  );
                                  if (user != null && user['_id'] != null) {
                                    // Navigate to user profile
                                    Navigator.pushNamed(
                                      context,
                                      '/profile',
                                      arguments: {'userId': user['_id']},
                                    );
                                  }
                                }
                              },
                            ),
                          if (gifUrl != null && gifUrl.isNotEmpty) ...[
                            if (content.isNotEmpty) const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: gifUrl,
                                width: 200,
                                fit: BoxFit.cover,
                                httpHeaders: const {'Accept': 'image/*'},
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint('❌ Error loading GIF: $url, Error: $error');
                                  return Container(
                                    width: 200,
                                    height: 150,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Failed to load',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Row(
                        children: [
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => _showReactionPicker(
                              context,
                              commentId,
                              userReaction,
                            ),
                            child: Text(
                              reactions.isEmpty
                                  ? 'React'
                                  : '${reactions.length} reactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => _replyToComment(commentId, userName),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Display replies
                    if (replies.isNotEmpty)
                      ...replies.map<Widget>(
                        (reply) =>
                            _buildReplyItem(reply, parentCommentId: commentId),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(dynamic reply, {String? parentCommentId}) {
    final replyId = reply['_id']?.toString() ?? '';
    final user = reply['user'];
    final userName = _safeUserName(user);
    final userInitials = _initialsFrom(userName);
    final userAvatar = user is Map ? user['avatar'] : null;
    final content = (reply['content'] ?? '').toString();
    final createdAt = reply['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);
    final reactions =
        reply['reactions'] is List ? reply['reactions'] as List : const [];
    final nestedReplies =
        reply['replies'] is List ? reply['replies'] as List : const [];

    // Get mentioned user name
    final mentionedUser = reply['mentionedUser'];
    final mentionedUserName =
        mentionedUser != null ? _safeUserName(mentionedUser) : null;

    // Get user's reaction if any (would need current user ID)
    String? userReaction;

    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                radius: 14,
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                    ? UrlUtils.getAvatarImageProvider(userAvatar)
                    : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Text(
                        userInitials,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                          const SizedBox(height: 2),
                          MentionText(
                            text: mentionedUserName != null
                                ? '@$mentionedUserName $content'
                                : content,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            mentionStyle: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onMentionTap: (userName) async {
                              final taggedUsers = reply['taggedUsers'] as List?;
                              if (taggedUsers != null) {
                                final user = taggedUsers.firstWhere(
                                  (u) => u['name'] == userName,
                                  orElse: () => null,
                                );
                                if (user != null && user['_id'] != null) {
                                  Navigator.pushNamed(
                                    context,
                                    '/profile',
                                    arguments: {'userId': user['_id']},
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 2),
                      child: Row(
                        children: [
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          if (parentCommentId != null &&
                              replyId.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _showReplyReactionPicker(
                                context,
                                parentCommentId,
                                replyId,
                                userReaction,
                              ),
                              child: Text(
                                reactions.isEmpty
                                    ? 'React'
                                    : '${reactions.length} reactions',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _replyToReply(
                                parentCommentId,
                                replyId,
                                userName,
                              ),
                              child: Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Display nested replies
                    if (nestedReplies.isNotEmpty)
                      ...nestedReplies.map<Widget>(
                        (nestedReply) => _buildNestedReplyItem(nestedReply),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNestedReplyItem(dynamic nestedReply) {
    final user = nestedReply['user'];
    final userName = _safeUserName(user);
    final userInitials = _initialsFrom(userName);
    final userAvatar = user is Map ? user['avatar'] : null;
    final content = (nestedReply['content'] ?? '').toString();
    final createdAt = nestedReply['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);

    // Get mentioned user name
    final mentionedUser = nestedReply['mentionedUser'];
    final mentionedUserName =
        mentionedUser != null ? _safeUserName(mentionedUser) : null;

    return Padding(
      padding: const EdgeInsets.only(left: 22, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            radius: 12,
            backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                ? UrlUtils.getAvatarImageProvider(userAvatar)
                : null,
            child: userAvatar == null || userAvatar.isEmpty
                ? Text(
                    userInitials,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      MentionText(
                        text: mentionedUserName != null
                            ? '@$mentionedUserName $content'
                            : content,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        mentionStyle: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onMentionTap: (userName) async {
                          final taggedUsers =
                              nestedReply['taggedUsers'] as List?;
                          if (taggedUsers != null) {
                            final user = taggedUsers.firstWhere(
                              (u) => u['name'] == userName,
                              orElse: () => null,
                            );
                            if (user != null && user['_id'] != null) {
                              Navigator.pushNamed(
                                context,
                                '/profile',
                                arguments: {'userId': user['_id']},
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                highlightColor: Theme.of(context).colorScheme.surface,
                child: const CircleAvatar(radius: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  highlightColor: Theme.of(context).colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 100,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
