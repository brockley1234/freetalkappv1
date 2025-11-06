import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/realtime_update_service.dart';
import '../utils/responsive_sizing.dart';
import 'story_reply_item.dart';
import 'story_reply_input_sheet.dart';

class StoryRepliesSection extends StatefulWidget {
  final String storyId;
  final String storyAuthorId;
  final int repliesCount;
  final VoidCallback? onReplyCountChanged;

  const StoryRepliesSection({
    super.key,
    required this.storyId,
    required this.storyAuthorId,
    required this.repliesCount,
    this.onReplyCountChanged,
  });

  @override
  State<StoryRepliesSection> createState() => _StoryRepliesSectionState();
}

class _StoryRepliesSectionState extends State<StoryRepliesSection> {
  List<dynamic> _replies = [];
  bool _isLoadingReplies = false;
  bool _showRepliesSection = false;
  int _currentPage = 1;
  bool _hasMoreReplies = true;
  late ScrollController _scrollController;
  String? _currentUserId;
  final _realtimeService = RealtimeUpdateService();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadCurrentUserId();
    _setupRealtimeListeners();
    // Auto-load replies when widget initializes
    Future.microtask(() {
      if (!_showRepliesSection && widget.repliesCount > 0) {
        _toggleReplies();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
    });
  }

  void _setupRealtimeListeners() {
    // Listen for new replies to this specific story
    _realtimeService.storyNewReply.listen((data) {
      if (!mounted) return;

      final storyId = data['storyId'] as String?;
      debugPrint('💬 Real-time new reply received for story: $storyId, current story: ${widget.storyId}');
      
      if (storyId == widget.storyId) {
        final reply = data['reply'] as Map<String, dynamic>?;
        if (reply != null) {
          setState(() {
            _replies.insert(0, reply);
          });
          debugPrint('✅ New reply added to list, total replies now: ${_replies.length}');
          widget.onReplyCountChanged?.call();
        }
      }
    });

    // Listen for reactions to replies in this story
    _realtimeService.storyReplyReaction.listen((data) {
      if (!mounted) return;

      final storyId = data['storyId'] as String?;
      final replyId = data['replyId'] as String?;
      debugPrint('❤️ Real-time reply reaction: storyId=$storyId, replyId=$replyId');
      
      if (storyId == widget.storyId && replyId != null) {
        final replyIndex = _replies.indexWhere((r) => r['_id'] == replyId);
        if (replyIndex != -1) {
          setState(() {
            // Update the reactions count for the reply
            if (_replies[replyIndex]['reactions'] == null) {
              _replies[replyIndex]['reactions'] = [];
            }
            // The backend already handles the full reaction update
            // Just update the count here
            _replies[replyIndex]['reactionsCount'] = data['reactionsCount'] ?? 0;
          });
          debugPrint('✅ Reply reaction updated: $replyId with count ${data['reactionsCount']}');
        }
      }
    });

    // Listen for deleted replies in this story
    _realtimeService.storyReplyDeleted.listen((deletedReplyId) {
      if (!mounted) return;

      debugPrint('🗑️ Real-time reply deleted: $deletedReplyId');
      final initialLength = _replies.length;
      _replies.removeWhere((r) => r['_id'] == deletedReplyId);
      if (_replies.length < initialLength) {
        setState(() {});
        debugPrint('✅ Reply removed from list, total replies now: ${_replies.length}');
        widget.onReplyCountChanged?.call();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMoreReplies && !_isLoadingReplies) {
        _loadMoreReplies();
      }
    }
  }

  Future<void> _toggleReplies() async {
    if (!_showRepliesSection && _replies.isEmpty) {
      await _loadReplies();
    }
    setState(() => _showRepliesSection = !_showRepliesSection);
  }

  Future<void> _loadReplies({bool refresh = false}) async {
    if (_isLoadingReplies) return;

    setState(() {
      _isLoadingReplies = true;
      if (refresh) {
        _currentPage = 1;
        _replies = [];
      }
    });

    try {
      final result = await ApiService.getStoryReplies(
        widget.storyId,
        page: _currentPage,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final newReplies = result['data']['replies'] ?? [];
        final pagination = result['data']['pagination'] ?? {};

        setState(() {
          if (refresh) {
            _replies = newReplies;
          } else {
            _replies.addAll(newReplies);
          }
          _hasMoreReplies = _currentPage < (pagination['pages'] ?? 1);
        });
      }
    } catch (e) {
      debugPrint('Error loading replies: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReplies = false);
      }
    }
  }

  Future<void> _loadMoreReplies() async {
    if (!_hasMoreReplies || _isLoadingReplies) return;

    setState(() => _currentPage++);
    await _loadReplies();
  }

  Future<void> _deleteReply(String replyId) async {
    try {
      final result = await ApiService.deleteStoryReply(
        widget.storyId,
        replyId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _replies.removeWhere((r) => r['_id'] == replyId);
        });
        widget.onReplyCountChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reply deleted'),
            duration: Duration(milliseconds: 800),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete reply'),
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
    }
  }

  Future<void> _reactToReply(String replyId, String emoji) async {
    try {
      final result = await ApiService.reactToStoryReply(
        widget.storyId,
        replyId,
        emoji,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Update local state
        final replyIndex = _replies.indexWhere((r) => r['_id'] == replyId);
        if (replyIndex != -1) {
          final updatedReply = result['data']['reply'] as Map<String, dynamic>;
          setState(() {
            _replies[replyIndex] = updatedReply;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    // In bottom sheet mode, always show replies expanded
    final isInBottomSheet = _showRepliesSection || widget.repliesCount > 0;

    return Column(
      children: [
        // Only show toggle if we have some replies and not in expanded mode
        if (!isInBottomSheet && widget.repliesCount == 0)
          const SizedBox.shrink(),
        
        // Replies list
        Expanded(
          child: _isLoadingReplies && _replies.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(responsive.paddingMedium),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              : _replies.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(responsive.paddingMedium),
                        child: Text(
                          'No comments yet. Be the first to comment!',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: responsive.fontBase,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: _replies.length +
                          (_hasMoreReplies ? 1 : 0), // +1 for loader
                      itemBuilder: (context, index) {
                        if (index == _replies.length) {
                          // Loading indicator for more replies
                          return Padding(
                            padding: EdgeInsets.all(responsive.paddingSmall),
                            child: Center(
                              child: SizedBox(
                                height: responsive.iconMedium,
                                width: responsive.iconMedium,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }

                        final reply = _replies[index];
                        return StoryReplyItem(
                          key: ValueKey(reply['_id']),
                          reply: reply,
                          onDelete: () =>
                              _deleteReply(reply['_id']),
                          onReact: (emoji) =>
                              _reactToReply(reply['_id'], emoji),
                          isStoryAuthor:
                              _currentUserId == widget.storyAuthorId,
                          currentUserId: _currentUserId,
                        );
                      },
                    ),
        ),
        // Add comment input at the bottom
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
            color: Colors.white,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.paddingMedium,
            vertical: responsive.paddingSmall,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: responsive.fontBase,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(responsive.radiusMedium),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(responsive.radiusMedium),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(responsive.radiusMedium),
                        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: responsive.paddingSmall,
                        vertical: responsive.paddingSmall,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          // Open full comment input sheet
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(responsive.radiusLarge),
                                    topRight: Radius.circular(responsive.radiusLarge),
                                  ),
                                ),
                                child: StoryReplyInputSheet(
                                  storyId: widget.storyId,
                                  onReplySubmitted: (_) {
                                    // Refresh replies list
                                    _loadReplies(refresh: true);
                                    widget.onReplyCountChanged?.call();
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(responsive.paddingSmall),
                          child: Icon(
                            Icons.edit,
                            size: responsive.iconSmall,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    maxLines: 1,
                    readOnly: true, // Make it read-only to open the full input sheet
                    style: TextStyle(fontSize: responsive.fontBase),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
