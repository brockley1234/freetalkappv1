import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

/// Widget to show connection status indicator
class SocketConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final String? message;

  const SocketConnectionIndicator({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return const SizedBox.shrink(); // Don't show if connected
    }

    Color color;
    String text;
    IconData icon;

    if (isConnecting) {
      color = Colors.orange;
      text = 'Connecting...';
      icon = Icons.sync;
    } else {
      color = Colors.red;
      text = message ?? 'Connection lost';
      icon = Icons.cloud_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: color, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isConnecting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isConnecting)
            TextButton(
              onPressed: () {
                // Can add manual retry action here
              },
              child: Text(
                'Retrying',
                style: TextStyle(color: color, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// Enhanced message delivery status indicator
class MessageDeliveryStatus extends StatelessWidget {
  final String status; // 'sending', 'sent', 'delivered', 'read', 'failed'
  final bool showTimestamp;
  final DateTime? timestamp;

  const MessageDeliveryStatus({
    super.key,
    required this.status,
    this.showTimestamp = false,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case 'sending':
        icon = Icons.schedule;
        color = Colors.grey.shade400;
        tooltip = 'Sending...';
        break;
      case 'sent':
        icon = Icons.check;
        color = Colors.grey.shade400;
        tooltip = 'Sent';
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.grey.shade400;
        tooltip = 'Delivered';
        break;
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        tooltip = 'Read';
        break;
      case 'failed':
        icon = Icons.error_outline;
        color = Colors.red;
        tooltip = 'Failed to send';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          if (showTimestamp && timestamp != null) ...[
            const SizedBox(width: 4),
            Text(
              _formatTime(timestamp!),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    // Format as YYYY/MM/DD HH:MM using TimeUtils
    return TimeUtils.formatMessageTimestamp(time.toIso8601String());
  }
}

/// Typing indicator widget
class TypingIndicator extends StatefulWidget {
  final String userName;

  const TypingIndicator({super.key, required this.userName});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.userName} is typing',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(width: 4),
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final animValue = (_animationController.value * 3 - index).clamp(0.0, 1.0);
    final isActive = animValue > 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.blue : Colors.grey.shade300,
        ),
      ),
    );
  }
}

/// Message reaction widget
class MessageReactionWidget extends StatelessWidget {
  final Map<String, int> reactions; // emoji -> count
  final VoidCallback onAddReaction;
  final VoidCallback? onRemoveReaction;

  const MessageReactionWidget({
    super.key,
    required this.reactions,
    required this.onAddReaction,
    this.onRemoveReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...reactions.entries.map<Widget>((entry) {
          return GestureDetector(
            onTap: onRemoveReaction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: onAddReaction,
          child: Tooltip(
            message: 'Add reaction',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.add, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enhanced message bubble with better styling
class EnhancedMessageBubble extends StatelessWidget {
  final String content;
  final bool isFromMe;
  final DateTime sentAt;
  final String
      deliveryStatus; // 'sending', 'sent', 'delivered', 'read', 'failed'
  final String? mediaUrl;
  final String? mediaType; // 'image', 'video', 'voice', etc.
  final Map<String, int>? reactions;
  final Widget? replyTo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EnhancedMessageBubble({
    super.key,
    required this.content,
    required this.isFromMe,
    required this.sentAt,
    required this.deliveryStatus,
    this.mediaUrl,
    this.mediaType,
    this.reactions,
    this.replyTo,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyTo != null) ...[
              Container(
                margin: EdgeInsets.only(
                  left: isFromMe ? 0 : 12,
                  right: isFromMe ? 12 : 0,
                  bottom: 4,
                ),
                child: replyTo,
              ),
            ],
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFromMe ? Colors.blue.shade400 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: isFromMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mediaUrl != null && mediaType != null)
                    _buildMediaPreview(mediaType!, mediaUrl!)
                  else
                    Text(
                      content,
                      style: TextStyle(
                        color: isFromMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  MessageDeliveryStatus(
                    status: deliveryStatus,
                    showTimestamp: true,
                    timestamp: sentAt,
                  ),
                ],
              ),
            ),
            if (reactions != null && reactions!.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.only(
                  left: isFromMe ? 0 : 12,
                  right: isFromMe ? 12 : 0,
                ),
                child: MessageReactionWidget(
                  reactions: reactions!,
                  onAddReaction: () {},
                  onRemoveReaction: () {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String mediaType, String url) {
    switch (mediaType) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
          ),
        );
      case 'video':
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
          ),
        );
      case 'voice':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic,
                size: 16, color: isFromMe ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Text(
              'Voice message',
              style: TextStyle(
                color: isFromMe ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        );
      case 'gif':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
          ),
        );
      default:
        return Text(
          '📎 $mediaType',
          style: TextStyle(
            color: isFromMe ? Colors.white : Colors.black87,
            fontSize: 12,
          ),
        );
    }
  }
}
