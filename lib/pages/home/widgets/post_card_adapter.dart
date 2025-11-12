import 'package:flutter/material.dart';
import '../../../widgets/post_card.dart';

/// Adapter that converts post data object to PostCard parameters
class PostCardAdapter extends StatelessWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? currentUser;
  final VoidCallback? onPostTap;
  final VoidCallback? onUserTap;
  final VoidCallback? onReactionTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onSettingsTap;

  const PostCardAdapter({
    super.key,
    required this.post,
    this.currentUser,
    this.onPostTap,
    this.onUserTap,
    this.onReactionTap,
    this.onCommentTap,
    this.onShareTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    // Extract post data
    final postId = post['_id'] ?? '';
    final author = post['author'] ?? {};
    final authorId = author['_id'] ?? '';
    final authorName = author['name'] ?? 'Unknown User';
    final userAvatar = author['avatar'];
    final content = post['content'] ?? '';
    final reactionsCount = post['likesCount'] ?? post['reactionsCount'] ?? 0;
    final comments = post['commentsCount'] ?? 0;
    final sharesCount = post['sharesCount'] ?? 0;
    final createdAt = post['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);

    // Get reactions summary
    final reactionsSummary = post['reactionsSummary'] != null
        ? Map<String, dynamic>.from(post['reactionsSummary'])
        : <String, dynamic>{};

    // Find user's reaction
    final reactions = post['reactions'] != null
        ? List<dynamic>.from(post['reactions'])
        : [];
    final currentUserId = currentUser?['_id'];

    String? userReaction;
    if (currentUserId != null) {
      for (var reaction in reactions) {
        if (reaction['user'] == currentUserId ||
            (reaction['user'] is Map && reaction['user']['_id'] == currentUserId)) {
          userReaction = reaction['type'];
          break;
        }
      }
    }

    // Get images and videos
    final images =
        post['images'] != null ? List<String>.from(post['images']) : null;
    final videos =
        post['videos'] != null ? List<String>.from(post['videos']) : null;

    // Extract tagged users
    final taggedUsers = post['taggedUsers'] != null
        ? List<Map<String, dynamic>>.from(post['taggedUsers'])
        : null;

    // Get share info
    final isShared = post['isShared'] == true;
    final sharedBy = post['sharedBy'];
    final shareMessage = post['shareMessage'];

    // Get trending status
    final isTrending = post['isTrending'] == true;

    // Get top comments
    final topComments = post['topComments'] != null
        ? List<Map<String, dynamic>>.from(post['topComments'])
        : null;

    return PostCard(
      postId: postId,
      authorId: authorId,
      userName: authorName,
      userAvatar: userAvatar,
      timeAgo: timeAgo,
      content: content,
      reactionsCount: reactionsCount,
      comments: comments,
      userReaction: userReaction,
      reactionsSummary: reactionsSummary,
      images: images,
      videos: videos,
      onReactionTap: onReactionTap ?? () {},
      onCommentTap: onCommentTap ?? () {},
      onSettingsTap: onSettingsTap ?? () {},
      onShareTap: onShareTap,
      onUserTap: onUserTap,
      isShared: isShared,
      sharedBy: sharedBy,
      shareMessage: shareMessage,
      taggedUsers: taggedUsers,
      authorData: author,
      isTrending: isTrending,
      sharesCount: sharesCount,
      topComments: topComments,
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final DateTime dateTime = DateTime.parse(timestamp.toString());
      final Duration difference = DateTime.now().difference(dateTime);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

