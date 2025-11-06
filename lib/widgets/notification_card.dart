import 'package:flutter/material.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../pages/user_profile_page.dart';
import '../pages/videos_page.dart';

class NotificationCard extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notificationData,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.notificationData['type'] as String;
    final isRead = widget.notificationData['isRead'] as bool? ?? false;
    final sender = widget.notificationData['sender'] as Map<String, dynamic>?;
    final createdAt = widget.notificationData['createdAt'] as String?;

    final senderName = sender?['name'] ?? 'Someone';
    final senderAvatar = sender?['avatar'];

    IconData icon;
    Color iconColor;
    String message;

    switch (type) {
      case 'reaction':
        final reactionType = widget.notificationData['reactionType'] as String?;
        icon = Icons.thumb_up;
        iconColor = _getReactionColor(reactionType);
        message = 'reacted ${_getReactionEmoji(reactionType)} to your post';
        break;
      case 'comment':
        icon = Icons.comment;
        iconColor = Colors.blue;
        final commentText =
            widget.notificationData['commentText'] as String? ?? '';
        message =
            'commented on your post${commentText.isNotEmpty ? ': "$commentText"' : ''}';
        break;
      case 'reply':
        icon = Icons.reply;
        iconColor = Colors.green;
        final replyText =
            widget.notificationData['commentText'] as String? ?? '';
        message =
            'replied to your comment${replyText.isNotEmpty ? ': "$replyText"' : ''}';
        break;
      case 'follow':
        icon = Icons.person_add;
        iconColor = Colors.purple;
        message = 'started following you';
        break;
      case 'post_mention':
        icon = Icons.alternate_email;
        iconColor = Colors.orange;
        message = 'mentioned you in a post';
        break;
      case 'tag':
        icon = Icons.local_offer;
        iconColor = Colors.orange;
        message = 'tagged you in a post';
        break;
      case 'message':
        icon = Icons.message;
        iconColor = Colors.teal;
        final messageText = widget.notificationData['message'] as String? ?? '';
        message =
            'sent you a message${messageText.isNotEmpty ? ': "$messageText"' : ''}';
        break;
      case 'story':
        icon = Icons.auto_stories;
        iconColor = Colors.purple;
        message = 'posted a new story';
        break;
      case 'story_reaction':
        icon = Icons.emoji_emotions;
        iconColor = Colors.pink;
        final notifMessage =
            widget.notificationData['message'] as String? ?? '';
        message =
            notifMessage.isNotEmpty ? notifMessage : 'reacted to your story';
        break;
      case 'poke':
        icon = Icons.back_hand;
        iconColor = Colors.deepOrange;
        final pokeMessage = widget.notificationData['message'] as String? ?? '';
        message = pokeMessage.isNotEmpty ? pokeMessage : 'poked you';
        break;
      case 'video_like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        message = 'liked your video';
        break;
      case 'video_comment':
        icon = Icons.comment;
        iconColor = Colors.blue;
        final videoCommentText =
            widget.notificationData['message'] as String? ?? '';
        message = videoCommentText.isNotEmpty 
            ? videoCommentText 
            : 'commented on your video';
        break;
      case 'video_comment_reaction':
        icon = Icons.emoji_emotions;
        iconColor = Colors.pink;
        final reactionType = widget.notificationData['reactionType'] as String?;
        message = 'reacted ${_getReactionEmoji(reactionType)} to your comment on a video';
        break;
      case 'video_tag':
        icon = Icons.local_offer;
        iconColor = Colors.orange;
        message = 'tagged you in a video';
        break;
      case 'club_invite':
        icon = Icons.group_add;
        iconColor = Colors.purple;
        final clubName = widget.notificationData['content'] != null 
            ? (widget.notificationData['content'] as String).split('invited you to join ').last.replaceAll('.', '')
            : 'a club';
        message = 'invited you to join $clubName';
        break;
      case 'club_request_approved':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        final clubName = widget.notificationData['content'] != null 
            ? (widget.notificationData['content'] as String).split('request to join ').last.replaceAll('.', '')
            : 'a club';
        message = 'approved your request to join $clubName';
        break;
      case 'moderation_action':
      case 'report_update':
        icon = Icons.shield;
        iconColor = Colors.red;
        // For moderation actions, use the message directly without sender name prefix
        message = widget.notificationData['message'] as String? ??
            'A moderation action has been taken on your account';
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
        message = 'sent you a notification';
    }

    return Dismissible(
      key: Key(widget.notificationData['_id'] ?? ''),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        widget.onDismiss?.call();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(_isHovered ? -2 : 0, 0, 0),
          child: InkWell(
            onTap: type == 'club_invite' 
                ? null // Don't allow card tap for club invites - use buttons instead
                : () {
                    // Execute the callback if provided
                    widget.onTap?.call();

                    // Navigate to user profile for follow notifications
                    if (type == 'follow' && sender?['_id'] != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfilePage(userId: sender!['_id'] as String),
                        ),
                      );
                    }
                    
                    // Navigate to video for video-related notifications
                    if ((type == 'video_comment' || 
                         type == 'video_comment_reaction' || 
                         type == 'video_like' || 
                         type == 'video_tag') && 
                        widget.notificationData['relatedVideo'] != null) {
                      final videoId = widget.notificationData['relatedVideo'] as String;
                      
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => VideosPage(
                            initialVideoId: videoId,
                          ),
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _isHovered ? Colors.blue.shade200 : Colors.grey.shade200,
                  width: _isHovered ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: type == 'moderation_action' ||
                                type == 'report_update'
                            ? Colors.red.shade100
                            : Colors.grey.shade300,
                        backgroundImage: (type != 'moderation_action' &&
                                    type != 'report_update') &&
                                senderAvatar != null
                            ? UrlUtils.getAvatarImageProvider(senderAvatar)
                            : null,
                        child: (type == 'moderation_action' ||
                                type == 'report_update')
                            ? Icon(
                                Icons.shield,
                                size: 32,
                                color: Colors.red.shade700,
                              )
                            : (senderAvatar == null
                                ? Text(
                                    senderName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: type == 'reaction'
                              ? Text(
                                  _getReactionEmoji(
                                    widget.notificationData['reactionType']
                                        as String?,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                )
                              : Icon(icon, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 60),
                          child: SelectableText.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                              children: type == 'moderation_action' ||
                                      type == 'report_update'
                                  ? [
                                      // For moderation actions, show message directly without sender name
                                      TextSpan(
                                        text: message,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ]
                                  : [
                                      // For other notifications, show sender name + message
                                      TextSpan(
                                        text: senderName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: ' $message'),
                                    ],
                            ),
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt != null
                              // Use TimeUtils for proper local time conversion
                              ? TimeUtils.formatMessageTimestamp(createdAt)
                              : 'Just now',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        // Show action buttons for club invites - below the message for mobile
                        if (type == 'club_invite') ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: ElevatedButton.icon(
                                  onPressed: widget.onTap != null 
                                      ? () async {
                                          // Call the custom handler which should handle accept
                                          widget.onTap?.call();
                                        }
                                      : null,
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Accept', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onDismiss,
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Decline', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Web-friendly delete button (visible on hover) - only show if not club invite
                  if (type != 'club_invite') ...[
                    if (_isHovered)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              size: 20, color: Colors.grey.shade600),
                          onPressed: widget.onDismiss,
                          tooltip: 'Dismiss',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      )
                    else if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getReactionColor(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return Colors.blue;
      case 'celebrate':
        return Colors.purple;
      case 'insightful':
        return Colors.amber;
      case 'funny':
        return Colors.orange;
      case 'mindblown':
        return Colors.deepPurple;
      case 'support':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getReactionEmoji(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return '👍';
      case 'celebrate':
        return '🎉';
      case 'insightful':
        return '💡';
      case 'funny':
        return '😂';
      case 'mindblown':
        return '🤯';
      case 'support':
        return '💪';
      default:
        return '👍';
    }
  }
}
