import 'package:flutter/material.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../utils/responsive_sizing.dart';

class StoryReplyItem extends StatefulWidget {
  final Map<String, dynamic> reply;
  final VoidCallback onDelete;
  final Function(String emoji) onReact;
  final bool isStoryAuthor;
  final String? currentUserId;

  const StoryReplyItem({
    super.key,
    required this.reply,
    required this.onDelete,
    required this.onReact,
    required this.isStoryAuthor,
    this.currentUserId,
  });

  @override
  State<StoryReplyItem> createState() => _StoryReplyItemState();
}

class _StoryReplyItemState extends State<StoryReplyItem> {
  bool _showReactionPicker = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final author = widget.reply['author'] as Map<String, dynamic>? ?? {};
    final content = widget.reply['content'] ?? '';
    final reactions = widget.reply['reactions'] ?? [];
    final reactionsCount = widget.reply['reactionsCount'] ?? 0;
    final viewedByAuthor = widget.reply['viewedByAuthor'] ?? false;
    final createdAt = widget.reply['createdAt'];
    final isOwnReply =
        widget.currentUserId != null && author['_id'] == widget.currentUserId;

    // Get responsive sizing
    final responsive = context.responsive;

    DateTime? parsedDate;
    if (createdAt is String) {
      try {
        parsedDate = DateTime.parse(createdAt);
      } catch (e) {
        parsedDate = null;
      }
    }

    final timeAgo = parsedDate != null
        ? TimeUtils.getTimeAgo(parsedDate)
        : 'just now';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.paddingSmall,
        vertical: responsive.paddingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar, name, and time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar - responsive size
              CircleAvatar(
                radius: responsive.avatarXSmall / 2,
                backgroundColor: Colors.grey[300],
                backgroundImage: author['avatar'] != null &&
                        author['avatar'].toString().isNotEmpty
                    ? NetworkImage(
                        UrlUtils.getFullAvatarUrl(author['avatar']),
                      )
                    : null,
                child: author['avatar'] == null ||
                        author['avatar'].toString().isEmpty
                    ? Text(
                        author['name']?.isNotEmpty == true
                            ? author['name'][0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: responsive.fontSmall,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: responsive.paddingSmall),
              // Name, time, and more options
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: responsive.fontBase,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: responsive.fontXSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // More options (delete button)
                    if (isOwnReply || widget.isStoryAuthor)
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteConfirmation();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.paddingSmall),
          // Reply content - responsive font size
          Padding(
            padding: EdgeInsets.only(left: responsive.avatarXSmall + responsive.paddingSmall),
            child: Text(
              content,
              style: TextStyle(fontSize: responsive.fontBase),
            ),
          ),
          SizedBox(height: responsive.paddingSmall),
          // Reactions and action buttons
          Padding(
            padding: EdgeInsets.only(left: responsive.avatarXSmall + responsive.paddingSmall),
            child: Row(
              children: [
                // Reaction count - responsive padding
                if (reactionsCount > 0)
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => _buildReactionsDialog(reactions),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.paddingXSmall,
                        vertical: responsive.paddingXSmall / 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(responsive.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            reactions.isNotEmpty
                                ? reactions[0]['emoji'] ?? '❤️'
                                : '❤️',
                            style: TextStyle(fontSize: responsive.fontSmall),
                          ),
                          SizedBox(width: responsive.paddingXSmall),
                          Text(
                            reactionsCount.toString(),
                            style: TextStyle(
                              fontSize: responsive.fontSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                // React button
                GestureDetector(
                  onTap: _showReactionPicker
                      ? null
                      : () {
                          setState(() => _showReactionPicker = true);
                        },
                  child: Icon(
                    Icons.favorite_border,
                    size: responsive.iconSmall,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Reaction picker (if visible) - responsive emoji size
          if (_showReactionPicker)
            Padding(
              padding: EdgeInsets.only(
                left: responsive.avatarXSmall + responsive.paddingSmall,
                top: responsive.paddingSmall,
              ),
              child: _buildReactionPicker(responsive),
            ),
          // Viewed by author badge
          if (viewedByAuthor && !isOwnReply)
            Padding(
              padding: EdgeInsets.only(
                left: responsive.avatarXSmall + responsive.paddingSmall,
                top: responsive.paddingXSmall,
              ),
              child: Text(
                '✓ Seen by author',
                style: TextStyle(
                  fontSize: responsive.fontXSmall,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionPicker(ResponsiveSize responsive) {
    final emojis = ['❤️', '🔥', '😂', '🙌', '👏', '😮', '💯', '🎉'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(responsive.radiusSmall),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.paddingXSmall,
        vertical: responsive.paddingXSmall / 2,
      ),
      child: Wrap(
        spacing: responsive.paddingXSmall,
        children: emojis
            .map((emoji) => GestureDetector(
                  onTap: () {
                    widget.onReact(emoji);
                    setState(() => _showReactionPicker = false);
                  },
                  child: Text(emoji, style: TextStyle(fontSize: responsive.fontLarge)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildReactionsDialog(List<dynamic> reactions) {
    // Group reactions by emoji
    final reactionMap = <String, List<dynamic>>{};
    for (final reaction in reactions) {
      final emoji = reaction['emoji'] ?? '❤️';
      reactionMap.putIfAbsent(emoji, () => []).add(reaction);
    }

    return AlertDialog(
      title: const Text('Reactions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reactionMap.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(fontSize: context.responsive.fontLarge),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        final responsive = context.responsive;
        return AlertDialog(
          title: const Text('Delete Reply?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isDeleting
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => _isDeleting = true);
                      try {
                        widget.onDelete();
                      } finally {
                        if (mounted) {
                          setState(() => _isDeleting = false);
                        }
                      }
                    },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: _isDeleting
                  ? SizedBox(
                      width: responsive.iconSmall,
                      height: responsive.iconSmall,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
