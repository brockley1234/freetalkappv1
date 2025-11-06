import 'package:flutter/material.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../utils/avatar_utils.dart';

/// Search and filter options for conversations
class ConversationFilter {
  final String query;
  final bool unreadOnly;
  final bool groupOnly;

  ConversationFilter({
    this.query = '',
    this.unreadOnly = false,
    this.groupOnly = false,
  });

  /// Apply filter to conversations list
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> conversations) {
    return conversations.where((conv) {
      // Filter by unread
      if (unreadOnly && (conv['unreadCount'] ?? 0) == 0) return false;

      // Filter by group
      if (groupOnly && conv['isGroup'] != true) return false;

      // Filter by search query
      if (query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        final name = (conv['groupName'] ?? conv['otherUser']?['name'] ?? '')
            .toString()
            .toLowerCase();
        final lastMessage =
            (conv['lastMessage']?['content'] ?? '').toString().toLowerCase();

        return name.contains(searchLower) || lastMessage.contains(searchLower);
      }

      return true;
    }).toList();
  }
}

/// Enhanced conversation tile with swipe actions
class EnhancedConversationTile extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final VoidCallback? onMute;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final bool isPinned;
  final bool isMuted;

  const EnhancedConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onMute,
    this.onPin,
    this.onDelete,
    this.isPinned = false,
    this.isMuted = false,
  });

  @override
  State<EnhancedConversationTile> createState() =>
      _EnhancedConversationTileState();
}

class _EnhancedConversationTileState extends State<EnhancedConversationTile> {
  @override
  Widget build(BuildContext context) {
    final isGroup = widget.conversation['isGroup'] == true;
    final groupName = widget.conversation['groupName'] as String?;
    final otherUser = widget.conversation['otherUser'] as Map<String, dynamic>?;
    final displayName = isGroup ? groupName : otherUser?['name'] ?? 'Unknown';
    final avatar =
        isGroup ? widget.conversation['groupAvatar'] : otherUser?['avatar'];
    final isOnline = (otherUser?['isOnline'] ?? false) as bool;
    final unreadCount = (widget.conversation['unreadCount'] ?? 0) as int;

    return Dismissible(
      key: Key(widget.conversation['_id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        widget.onDelete?.call();
      },
      child: Stack(
        children: [
          // Mute/Pin action buttons (swipe background)
          Container(
            color: Colors.grey.shade100,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onMute != null)
                  _ActionButton(
                    icon: widget.isMuted
                        ? Icons.notifications_off
                        : Icons.notifications,
                    onPressed: widget.onMute!,
                    label: widget.isMuted ? 'Unmute' : 'Mute',
                    color: Colors.orange,
                  ),
                const SizedBox(width: 8),
                if (widget.onPin != null)
                  _ActionButton(
                    icon: widget.isPinned
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                    onPressed: widget.onPin!,
                    label: widget.isPinned ? 'Unpin' : 'Pin',
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
          // Main conversation tile
          Material(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: _ConversationAvatar(
                avatar: avatar,
                isOnline: isOnline && !isGroup,
                displayName: displayName ?? 'Unknown',
                radius: 24,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (widget.isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.bookmark,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                  ],
                  if (widget.isMuted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.volume_off,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  _MessagePreview(
                    conversation: widget.conversation,
                    isGroup: isGroup,
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.conversation['lastMessageAt']),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          unreadCount > 0 ? Colors.blue : Colors.grey.shade600,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: widget.onTap,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    return TimeUtils.formatMessageTimestamp(timestamp?.toString());
  }
}

/// Action button for swipe actions
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String label;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// Conversation avatar with online indicator
class _ConversationAvatar extends StatelessWidget {
  final String? avatar;
  final bool isOnline;
  final String displayName;
  final double radius;

  const _ConversationAvatar({
    required this.avatar,
    required this.isOnline,
    required this.displayName,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AvatarWithFallback(
          name: displayName,
          imageUrl: avatar,
          radius: radius,
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Message preview widget
class _MessagePreview extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final bool isGroup;

  const _MessagePreview({
    required this.conversation,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation['lastMessage'] as Map<String, dynamic>?;
    final unreadCount = (conversation['unreadCount'] ?? 0) as int;

    if (lastMessage == null) {
      return Text(
        'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }

    String preview = '';
    if (lastMessage['type'] == 'image') {
      preview = '📷 Image';
    } else if (lastMessage['type'] == 'video') {
      preview = '🎬 Video';
    } else if (lastMessage['type'] == 'voice') {
      preview = '🎤 Voice message';
    } else if (lastMessage['replyTo'] != null) {
      preview = '↩️ ${lastMessage['content'] ?? 'Reply'}';
    } else {
      preview = lastMessage['content'] ?? 'No content';
    }

    if (isGroup && lastMessage['sender'] != null) {
      final senderName = lastMessage['sender']['name'] ?? 'Someone';
      preview = '$senderName: $preview';
    }

    return Text(
      preview,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
        fontSize: 13,
        fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }
}
