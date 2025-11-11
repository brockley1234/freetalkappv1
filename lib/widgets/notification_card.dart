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
        iconColor = Theme.of(context).colorScheme.primary;
        final commentText =
            widget.notificationData['commentText'] as String? ?? '';
        message =
            'commented on your post${commentText.isNotEmpty ? ': "$commentText"' : ''}';
        break;
      case 'reply':
        icon = Icons.reply;
        iconColor = Theme.of(context).colorScheme.secondary;
        final replyText =
            widget.notificationData['commentText'] as String? ?? '';
        message =
            'replied to your comment${replyText.isNotEmpty ? ': "$replyText"' : ''}';
        break;
      case 'follow':
        icon = Icons.person_add;
        iconColor = Theme.of(context).colorScheme.tertiary;
        message = 'started following you';
        break;
      case 'post_mention':
        icon = Icons.alternate_email;
        iconColor = Theme.of(context).colorScheme.tertiary;
        message = 'mentioned you in a post';
        break;
      case 'tag':
        icon = Icons.local_offer;
        iconColor = Theme.of(context).colorScheme.tertiary;
        message = 'tagged you in a post';
        break;
      case 'message':
        icon = Icons.message;
        iconColor = Theme.of(context).colorScheme.secondary;
        final messageText = widget.notificationData['message'] as String? ?? '';
        message =
            'sent you a message${messageText.isNotEmpty ? ': "$messageText"' : ''}';
        break;
      case 'story':
        icon = Icons.auto_stories;
        iconColor = Theme.of(context).colorScheme.tertiary;
        message = 'posted a new story';
        break;
      case 'story_reaction':
        icon = Icons.emoji_emotions;
        iconColor = Theme.of(context).colorScheme.primary;
        final notifMessage =
            widget.notificationData['message'] as String? ?? '';
        message =
            notifMessage.isNotEmpty ? notifMessage : 'reacted to your story';
        break;
      case 'poke':
        icon = Icons.back_hand;
        iconColor = Theme.of(context).colorScheme.tertiary;
        final pokeMessage = widget.notificationData['message'] as String? ?? '';
        message = pokeMessage.isNotEmpty ? pokeMessage : 'poked you';
        break;
      case 'video_like':
        icon = Icons.favorite;
        iconColor = Theme.of(context).colorScheme.error;
        message = 'liked your video';
        break;
      case 'video_comment':
        icon = Icons.comment;
        iconColor = Theme.of(context).colorScheme.primary;
        final videoCommentText =
            widget.notificationData['message'] as String? ?? '';
        message = videoCommentText.isNotEmpty 
            ? videoCommentText 
            : 'commented on your video';
        break;
      case 'video_comment_reaction':
        icon = Icons.emoji_emotions;
        iconColor = Theme.of(context).colorScheme.primary;
        final reactionType = widget.notificationData['reactionType'] as String?;
        message = 'reacted ${_getReactionEmoji(reactionType)} to your comment on a video';
        break;
      case 'video_tag':
        icon = Icons.local_offer;
        iconColor = Theme.of(context).colorScheme.tertiary;
        message = 'tagged you in a video';
        break;
      case 'club_invite':
        icon = Icons.group_add;
        iconColor = Theme.of(context).colorScheme.tertiary;
        final clubName = widget.notificationData['content'] != null 
            ? (widget.notificationData['content'] as String).split('invited you to join ').last.replaceAll('.', '')
            : 'a club';
        message = 'invited you to join $clubName';
        break;
      case 'club_request_approved':
        icon = Icons.check_circle;
        iconColor = Theme.of(context).colorScheme.secondary;
        final clubName = widget.notificationData['content'] != null 
            ? (widget.notificationData['content'] as String).split('request to join ').last.replaceAll('.', '')
            : 'a club';
        message = 'approved your request to join $clubName';
        break;
      case 'moderation_action':
      case 'report_update':
        icon = Icons.shield;
        iconColor = Theme.of(context).colorScheme.error;
        // For moderation actions, use the message directly without sender name prefix
        message = widget.notificationData['message'] as String? ??
            'A moderation action has been taken on your account';
        break;
      default:
        icon = Icons.notifications;
        iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
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
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onError,
        ),
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
                color: isRead
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              )
                            : (senderAvatar == null
                                ? Text(
                                    senderName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
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
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: type == 'reaction'
                              ? Text(
                                  _getReactionEmoji(
                                    widget.notificationData['reactionType']
                                        as String?,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                )
                              : Icon(
                                  icon,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
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
                                    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                          icon: Icon(
                            Icons.close,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
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
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    switch (reactionType) {
      case 'like':
        return theme.colorScheme.primary;
      case 'celebrate':
        return theme.colorScheme.tertiary;
      case 'insightful':
        return theme.colorScheme.tertiary;
      case 'funny':
        return theme.colorScheme.tertiary;
      case 'mindblown':
        return theme.colorScheme.tertiary;
      case 'support':
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
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
