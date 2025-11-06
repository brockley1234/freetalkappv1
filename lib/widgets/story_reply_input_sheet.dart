import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';

class StoryReplyInputSheet extends StatefulWidget {
  final String storyId;
  final Function(String)? onReplySubmitted;
  final VoidCallback? onClose;

  const StoryReplyInputSheet({
    super.key,
    required this.storyId,
    this.onReplySubmitted,
    this.onClose,
  });

  @override
  State<StoryReplyInputSheet> createState() => _StoryReplyInputSheetState();
}

class _StoryReplyInputSheetState extends State<StoryReplyInputSheet> {
  late TextEditingController _replyController;
  bool _isSubmitting = false;
  int _characterCount = 0;
  final int _maxCharacters = 500;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _replyController.addListener(_updateCharacterCount);
  }

  @override
  void dispose() {
    _replyController.removeListener(_updateCharacterCount);
    _replyController.dispose();
    super.dispose();
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _replyController.text.length;
    });
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a reply')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Extract mentions (@username)
      final mentionRegex = RegExp(r'@(\w+)');
      final mentions = mentionRegex
          .allMatches(content)
          .map((m) => m.group(1)!)
          .toList();

      final result = await ApiService.createStoryReply(
        storyId: widget.storyId,
        content: content,
        mentions: mentions,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        widget.onReplySubmitted?.call(content);
        _replyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reply posted!'),
            duration: Duration(milliseconds: 800),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to post reply',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final responsive = context.responsive;
    final charCountColor = _characterCount > _maxCharacters * 0.9
        ? Colors.red
        : _characterCount > _maxCharacters * 0.7
            ? Colors.orange
            : Colors.grey[600];

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: keyboardHeight + responsive.paddingMedium,
          left: responsive.paddingMedium,
          right: responsive.paddingMedium,
          top: responsive.paddingMedium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reply to Story',
                  style: TextStyle(
                    fontSize: responsive.fontMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: responsive.iconMedium,
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            SizedBox(height: responsive.paddingMedium),
            // Reply input field
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(responsive.radiusMedium),
              ),
              child: TextField(
                controller: _replyController,
                maxLines: 4,
                minLines: 2,
                maxLength: _maxCharacters,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts... (use @name to mention)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(responsive.paddingMedium),
                  counterText: '', // Hide default counter
                ),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: responsive.fontBase),
              ),
            ),
            SizedBox(height: responsive.paddingSmall),
            // Character counter
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_characterCount/$_maxCharacters',
                  style: TextStyle(
                    fontSize: responsive.fontSmall,
                    color: charCountColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.paddingMedium),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onClose?.call();
                        },
                  child: const Text('Cancel'),
                ),
                SizedBox(width: responsive.paddingSmall),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReply,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: responsive.iconSmall,
                          height: responsive.iconSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.blue.shade700),
                          ),
                        )
                      : Icon(Icons.send, size: responsive.iconSmall),
                  label: Text(
                    _isSubmitting ? 'Posting...' : 'Post',
                    style: TextStyle(fontSize: responsive.fontBase),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.paddingMedium,
                      vertical: responsive.paddingSmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
