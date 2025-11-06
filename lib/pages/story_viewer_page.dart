import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/time_utils.dart';
import '../utils/responsive_sizing.dart';
import '../widgets/story_reply_input_sheet.dart';
import '../widgets/story_replies_section.dart';
import 'user_profile_page.dart';
import 'story_analytics_page.dart';
import 'story_creative_page.dart';

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> userStories; // Stories from one user
  final int initialIndex;
  final VoidCallback? onComplete;

  const StoryViewerPage({
    super.key,
    required this.userStories,
    this.initialIndex = 0,
    this.onComplete,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  Timer? _progressTimer;
  Timer? _expirationRefreshTimer;  // Timer to refresh expiration display every minute
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPaused = false;
  bool _showReactionPicker = false;
  String? _currentUserReaction;
  int _reactionsCount = 0;
  final _socketService = SocketService();
  String? _currentUserId;
  bool _isOwnStory = false;
  List<dynamic> _viewers = [];
  bool _isLoadingViewers = false;
  final Map<String, dynamic> _storyCache = {}; // In-memory cache for stories during this session

  @override
  void initState() {
    super.initState();
    // Validate that we have stories before accessing
    if (widget.userStories.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = widget.initialIndex.clamp(0, widget.userStories.length - 1);
    }
    _progressController = AnimationController(vsync: this);
    _initializeUser();
    _setupSocketListeners();
    
    // Start timer to refresh expiration display every minute
    _expirationRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {}); // Rebuild to update time remaining display
        }
      },
    );
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    debugPrint('👤 Current user ID: $_currentUserId');
    if (widget.userStories.isNotEmpty) {
      await _loadStory();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _progressTimer?.cancel();
    _expirationRefreshTimer?.cancel();
    _videoController?.dispose();
    _socketService.off('story:reaction', null);
    super.dispose();
  }

  void _setupSocketListeners() {
    // Listen for real-time story reactions
    _socketService.on('story:reaction', (data) {
      debugPrint('📱 Real-time story reaction received: $data');

      final storyId = data['storyId'];
      final currentStoryId = widget.userStories[_currentIndex]['_id'];

      if (storyId == currentStoryId) {
        if (mounted) {
          setState(() {
            _reactionsCount = data['reactionsCount'] ?? _reactionsCount;
            // Update the story data in the list
            widget.userStories[_currentIndex]['reactionsCount'] =
                data['reactionsCount'];
          });

          // Show reaction animation
          _showReactionAnimation(data['reaction']['emoji']);
        }
      }
    });

    // Listen for real-time story replies
    _socketService.on('story:new_reply', (data) {
      debugPrint('💬 New story reply received: $data');

      final storyId = data['storyId'];
      final currentStoryId = widget.userStories[_currentIndex]['_id'];

      if (storyId == currentStoryId) {
        if (mounted) {
          setState(() {
            widget.userStories[_currentIndex]['repliesCount'] =
                data['repliesCount'] ?? (widget.userStories[_currentIndex]['repliesCount'] ?? 0) + 1;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('💬 New reply posted!'),
                duration: Duration(milliseconds: 800),
              ),
            );
          }
        }
      }
    });

    // Listen for reply deletions
    _socketService.on('story:reply_deleted', (data) {
      debugPrint('🗑️ Story reply deleted: $data');

      final storyId = data['storyId'];
      final currentStoryId = widget.userStories[_currentIndex]['_id'];

      if (storyId == currentStoryId) {
        if (mounted) {
          setState(() {
            // Use the count from server if available, otherwise decrement
            widget.userStories[_currentIndex]['repliesCount'] = 
                data['repliesCount'] ?? (widget.userStories[_currentIndex]['repliesCount'] ?? 0) - 1;
          });
        }
      }
    });

    // Listen for reply reactions
    _socketService.on('story:reply_reaction', (data) {
      debugPrint('❤️ Story reply reaction received: $data');
      // Could update UI to show live reaction counts
    });
  }

  void _showReactionAnimation(String emoji) {
    // Show a brief animation/snackbar to indicate reaction received
    debugPrint('❤️ Reaction received: $emoji');

    if (mounted) {
      // Show animated floating emoji
      try {
        final overlay = Overlay.of(context);
        final overlayEntry = OverlayEntry(
          builder: (context) => _FloatingReactionWidget(emoji: emoji),
        );

        overlay.insert(overlayEntry);

        // Remove after animation
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            overlayEntry.remove();
          }
        });
      } catch (e) {
        debugPrint('Error showing reaction animation: $e');
      }
    }
  }

  void _showSuccessReactionFeedback(String emoji) {
    if (mounted) {
      // Visual feedback for successful reaction
      try {
        final overlay = Overlay.of(context);
        final overlayEntry = OverlayEntry(
          builder: (context) => Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.5),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 48)),
                  ),
                );
              },
            ),
          ),
        );

        overlay.insert(overlayEntry);

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            overlayEntry.remove();
          }
        });
      } catch (e) {
        debugPrint('Error showing success reaction feedback: $e');
      }
    }
  }

  Future<void> _loadStory() async {
    if (!mounted) return;

    final story = widget.userStories[_currentIndex];
    final storyId = story['_id'];
    
    // Check cache first to avoid redundant API calls
    if (_storyCache.containsKey(storyId)) {
      debugPrint('💾 Loading story from cache: $storyId');
      final cachedStory = _storyCache[storyId];
      widget.userStories[_currentIndex] = cachedStory;
    }

    // Check if this is the user's own story
    final authorId = story['author']['_id'];
    _isOwnStory = (_currentUserId != null && authorId == _currentUserId);

    debugPrint('📖 Loading story: ${story['_id']}');
    debugPrint('📖 Current user ID: $_currentUserId');
    debugPrint('📖 Story author ID: $authorId');
    debugPrint('📖 Is own story: $_isOwnStory');
    debugPrint('📖 Reactions count: $_reactionsCount');
    debugPrint('📖 User reaction: $_currentUserReaction');

    // Update reactions count and user's reaction from story data + trigger UI rebuild
    if (mounted) {
      setState(() {
        _reactionsCount = story['reactionsCount'] ?? 0;
        _currentUserReaction = story['userReaction'] as String?;
        // This setState call ensures the UI updates when _isOwnStory changes
      });
    }

    // Cache the current story for fast re-access
    _storyCache[storyId] = story;

    // Preload next story for smooth transition
    if (mounted && _currentIndex < widget.userStories.length - 1) {
      _preloadNextStory();
    }

    // Mark story as viewed (non-blocking)
    ApiService.viewStory(story['_id']).then((_) {
      debugPrint('✅ Story ${story['_id']} marked as viewed');
    }).catchError((e) {
      debugPrint('❌ Error marking story as viewed: $e');
    });

    if (story['mediaType'] == 'video') {
      await _loadVideo(story);
    } else {
      _startImageProgress(story);
    }
  }

  void _preloadNextStory() {
    final nextStory = widget.userStories[_currentIndex + 1];

    if (nextStory['mediaType'] == 'image') {
      // Preload next image
      final imageUrl = '${ApiService.baseApi}${nextStory['mediaUrl']}';
      precacheImage(NetworkImage(imageUrl), context);
      debugPrint('🔄 Preloading next story image');
    }
    // Note: Video preloading is more complex and memory-intensive,
    // so we skip it for now to avoid performance issues
  }

  Future<void> _reactToStory(String emoji) async {
    final story = widget.userStories[_currentIndex];

    debugPrint('🔥 Attempting to react to story ${story['_id']} with $emoji');

    try {
      final response = await ApiService.reactToStory(story['_id'], emoji);
      debugPrint('🔥 Reaction response: $response');

      if (response['success'] && mounted) {
        setState(() {
          _currentUserReaction = emoji;
          _reactionsCount =
              response['data']['reactionsCount'] ?? _reactionsCount;
          _showReactionPicker = false;

          // Update the story data in the list
          widget.userStories[_currentIndex]['reactionsCount'] = _reactionsCount;
          widget.userStories[_currentIndex]['userReaction'] = emoji;
        });

        // Show success feedback
        _showSuccessReactionFeedback(emoji);

        debugPrint(
          '✅ Reacted to story with $emoji. New count: $_reactionsCount',
        );
      }
    } catch (e) {
      debugPrint('❌ Error reacting to story: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to react: $e')));
      }
    }
  }

  Future<void> _loadStoryViewers() async {
    final story = widget.userStories[_currentIndex];

    setState(() {
      _isLoadingViewers = true;
    });

    try {
      final response = await ApiService.getStoryViewers(story['_id']);

      if (response['success'] && response['data'] != null) {
        setState(() {
          _viewers = response['data']['viewers'] ?? [];
          _isLoadingViewers = false;
        });
      } else {
        setState(() {
          _isLoadingViewers = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading story viewers: $e');
      setState(() {
        _isLoadingViewers = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final story = widget.userStories[_currentIndex];
    _pauseProgress();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text(
          'This story will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final result = await ApiService.deleteStory(story['_id']);

        if (result['success'] && mounted) {
          // Cache context-based values before using them
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Story deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Remove story from list and navigate
          widget.userStories.removeAt(_currentIndex);

          if (widget.userStories.isEmpty) {
            if (mounted) {
              Navigator.pop(context);
            }
          } else if (_currentIndex >= widget.userStories.length) {
            setState(() {
              _currentIndex = widget.userStories.length - 1;
            });
            _loadStory();
          } else {
            _loadStory();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete story: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      _resumeProgress();
    }
  }

  Future<void> _fixReplyCount() async {
    final story = widget.userStories[_currentIndex];
    
    debugPrint('🔧 Attempting to fix reply count for story ${story['_id']}');

    try {
      final result = await ApiService.fixStoryReplyCount(story['_id']);

      if (result['success'] && mounted) {
        final data = result['data'] as Map<String, dynamic>?;
        final newCount = data?['newCount'] ?? 0;
        final oldCount = data?['oldCount'] ?? 0;

        setState(() {
          widget.userStories[_currentIndex]['repliesCount'] = newCount;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Reply count fixed!\nWas: $oldCount → Now: $newCount',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        debugPrint('✅ Reply count fixed: $oldCount → $newCount');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to fix reply count',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error fixing reply count: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReplyBottomSheet() {
    final story = widget.userStories[_currentIndex];
    final author = story['author'] as Map<String, dynamic>;
    final TextEditingController replyController = TextEditingController();
    bool isSending = false;

    _pauseProgress();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: author['avatar'] != null
                          ? NetworkImage(
                              '${ApiService.baseApi}${author['avatar']}',
                            )
                          : null,
                      child: author['avatar'] == null
                          ? Text(author['name'][0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reply to ${author['name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                        _resumeProgress();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: replyController,
                  autofocus: true,
                  enabled: !isSending,
                  decoration: const InputDecoration(
                    hintText: 'Send a message...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            final message = replyController.text.trim();
                            if (message.isEmpty) return;

                            setModalState(() {
                              isSending = true;
                            });

                            // Cache context and navigator before async operation
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final authorNameCached = author['name'];
                            final currentStory =
                                widget.userStories[_currentIndex];
                            final currentStoryId = currentStory['_id'];

                            try {
                              await _sendMessageToAuthor(
                                author['_id'],
                                message,
                                authorNameCached,
                                currentStoryId,
                              );

                              if (mounted) {
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Message sent to $authorNameCached!',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to send message: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setModalState(() {
                                  isSending = false;
                                });
                                _resumeProgress();
                              }
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(isSending ? 'Sending...' : 'Send'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => _resumeProgress());
  }

  /// Sends a message to the story author
  ///
  /// This implements real-time messaging with the following flow:
  /// 1. Sends message to the backend API
  /// 2. Backend creates the message in the database
  /// 3. Backend emits socket events:
  ///    - 'message:new' to both sender and recipient rooms
  ///    - 'notification:new' to recipient room
  ///    - 'message:unread-count' to recipient room
  /// 4. Real-time updates are handled by socket listeners in the messages page
  /// 5. Push notification is created for the recipient
  ///
  /// The recipient will receive:
  /// - Real-time message in their chat list (if on messages page)
  /// - Notification badge update
  /// - Push notification (if enabled)
  ///
  /// No additional socket listener is needed here since the messages page
  /// and notification system already handle the 'message:new' and
  /// 'notification:new' events.
  Future<void> _sendMessageToAuthor(
    String authorId,
    String message,
    String authorName,
    String storyId,
  ) async {
    debugPrint('📤 Sending message to story author');
    debugPrint('📤 Recipient: $authorName ($authorId)');
    debugPrint('📤 Message: $message');
    debugPrint('📤 Story ID: $storyId');

    try {
      // Send the message via API with story reference
      final response = await ApiService.sendMessage(
        recipientId: authorId,
        content: message,
        storyId: storyId,
      );

      debugPrint('📤 Send message response: $response');

      if (response['success']) {
        debugPrint('✅ Message sent successfully to $authorName');
        debugPrint('✅ Backend will emit socket events for real-time updates');
        debugPrint(
          '✅ Recipient will receive notification and see message in real-time',
        );

        // The backend automatically handles:
        // 1. Creating the message in the database
        // 2. Emitting 'message:new' socket event to both sender and recipient
        // 3. Emitting 'notification:new' socket event to recipient
        // 4. Updating unread message count for recipient
        // 5. Creating push notification for recipient
        //
        // No additional action needed here - existing socket listeners
        // in the messages page will handle real-time UI updates
      } else {
        throw Exception(response['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      debugPrint('❌ Error sending message to author: $e');
      rethrow;
    }
  }

  void _showViewersBottomSheet() async {
    _pauseProgress();

    // Load viewers first, THEN show modal
    await _loadStoryViewers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Viewers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                        _resumeProgress();
                      },
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _isLoadingViewers
                      ? const Center(child: CircularProgressIndicator())
                      : _viewers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.visibility_off,
                                    size: 48,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No views yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your story will appear here once people view it',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _viewers.length,
                              itemBuilder: (context, index) {
                                final viewer = _viewers[index];
                                final user =
                                    viewer['user'] as Map<String, dynamic>;
                                final viewedAt =
                                    DateTime.parse(viewer['viewedAt']);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: user['avatar'] != null
                                        ? NetworkImage(
                                            '${ApiService.baseApi}${user['avatar']}',
                                          )
                                        : null,
                                    child: user['avatar'] == null
                                        ? Text(user['name'][0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(user['name']),
                                  subtitle: Text(
                                      TimeUtils.formatMessageTimestamp(
                                          viewedAt.toIso8601String())),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => _resumeProgress());
  }

  Future<void> _loadVideo(Map<String, dynamic> story) async {
    _videoController?.dispose();

    final videoUrl = '${ApiService.baseApi}${story['mediaUrl']}';
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      _videoController!.play();

      // Start progress for video duration
      final duration = _videoController!.value.duration;
      _startProgress(duration);

      // Listen for video completion
      _videoController!.addListener(() {
        if (mounted &&
            _videoController!.value.position >=
                _videoController!.value.duration) {
          _nextStory();
        }
      });
    } catch (e) {
      debugPrint('Error loading video: $e');
      _nextStory();
    }
  }

  void _startImageProgress(Map<String, dynamic> story) {
    if (!mounted) return;

    setState(() {
      _isVideoInitialized = false;
    });

    final duration = Duration(milliseconds: story['duration'] ?? 5000);
    _startProgress(duration);
  }

  /// Calculate time remaining before story expires (24 hours after creation)
  String _getTimeRemaining(Map<String, dynamic> story) {
    try {
      final createdAt = DateTime.parse(story['createdAt'] as String);
      final expiresAt = createdAt.add(const Duration(hours: 24));
      final now = DateTime.now();

      if (now.isAfter(expiresAt)) {
        return 'Expired';
      }

      final timeRemaining = expiresAt.difference(now);
      final hours = timeRemaining.inHours;
      final minutes = timeRemaining.inMinutes.remainder(60);

      if (hours > 0) {
        return '${hours}h ${minutes}m left';
      } else if (minutes > 0) {
        return '${minutes}m left';
      } else {
        final seconds = timeRemaining.inSeconds.remainder(60);
        return '${seconds}s left';
      }
    } catch (e) {
      debugPrint('⚠️ Error calculating expiration time: $e');
      return 'N/A';
    }
  }

  void _startProgress(Duration duration) {
    _progressController.reset();
    _progressController.duration = duration;
    _progressController.forward();

    _progressTimer?.cancel();
    _progressTimer = Timer(duration, () {
      if (mounted && !_isPaused) {
        _nextStory();
      }
    });
  }

  void _pauseProgress() {
    if (!mounted) return;

    setState(() {
      _isPaused = true;
    });
    _progressController.stop();
    _progressTimer?.cancel();
    _videoController?.pause();
  }

  void _resumeProgress() {
    if (!mounted) return;

    setState(() {
      _isPaused = false;
    });

    if (_videoController != null && _isVideoInitialized) {
      _videoController!.play();
      final remainingDuration =
          _videoController!.value.duration - _videoController!.value.position;
      _progressTimer = Timer(remainingDuration, () {
        if (mounted && !_isPaused) {
          _nextStory();
        }
      });
    } else {
      final remainingDuration = Duration(
        milliseconds: ((_progressController.duration!.inMilliseconds) *
                (1 - _progressController.value))
            .toInt(),
      );
      _progressController.forward();
      _progressTimer = Timer(remainingDuration, () {
        if (mounted && !_isPaused) {
          _nextStory();
        }
      });
    }
  }

  void _showShareOptions() {
    final story = widget.userStories[_currentIndex];
    final storyUrl = 'https://freetalk.site/story/${story['_id']}';
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Story',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Copy Link Option
            _buildShareOption(
              icon: Icons.link,
              label: 'Copy Link',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _copyStoryLink(storyUrl);
              },
            ),
            const SizedBox(height: 12),
            
            // Share to WhatsApp
            _buildShareOption(
              icon: Icons.chat,
              label: 'Share on WhatsApp',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _shareViaWhatsApp(storyUrl);
              },
            ),
            const SizedBox(height: 12),
            
            // Share to Instagram
            _buildShareOption(
              icon: Icons.camera,
              label: 'Share on Instagram',
              color: Colors.pink,
              onTap: () {
                Navigator.pop(context);
                _shareViaInstagram(storyUrl);
              },
            ),
            const SizedBox(height: 12),
            
            // Share to Facebook
            _buildShareOption(
              icon: Icons.facebook,
              label: 'Share on Facebook',
              color: Colors.indigo,
              onTap: () {
                Navigator.pop(context);
                _shareViaFacebook(storyUrl);
              },
            ),
            const SizedBox(height: 16),
            
            // Cancel Button
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _copyStoryLink(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Story link copied!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error copying link: $e');
    }
  }

  Future<void> _shareViaWhatsApp(String url) async {
    try {
      final story = widget.userStories[_currentIndex];
      final message = 'Check out this story from ${story['author']['name']}: $url';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share to WhatsApp: $message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');
    }
  }

  Future<void> _shareViaInstagram(String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open Instagram and share the link manually'),
          backgroundColor: Colors.pink,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing to Instagram: $e');
    }
  }

  Future<void> _shareViaFacebook(String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open Facebook and share the link manually'),
          backgroundColor: Colors.indigo,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing to Facebook: $e');
    }
  }

  void _viewAnalytics() {
    final story = widget.userStories[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryAnalyticsPage(storyId: story['_id']),
      ),
    );
  }

  void _openCreativeTools() {
    final story = widget.userStories[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryCreativePage(storyId: story['_id']),
      ),
    );
  }

  void _addToHighlights() {
    final story = widget.userStories[_currentIndex];
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Highlights'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Collection name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a new collection or add to an existing one',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final collectionName = controller.text.trim();
              if (collectionName.isNotEmpty) {
                Navigator.pop(context);
                await _addStoryToHighlight(story['_id'], collectionName);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStoryToHighlight(String storyId, String collectionName) async {
    try {
      final response = await ApiService.addStoryToHighlight(
        storyId: storyId,
        collectionName: collectionName,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "$collectionName"'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to add to highlight'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCommentsBottomSheet() {
    final story = widget.userStories[_currentIndex];
    final repliesCount = story['repliesCount'] ?? 0;
    _pauseProgress();

    debugPrint('📝 Opening comments sheet for story ${story['_id']}');
    debugPrint('📝 Current replies count: $repliesCount');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              shouldCloseOnMinExtent: true,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Header with dynamic reply count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Comments count - updated from story data
                          ValueListenableBuilder(
                            valueListenable: ValueNotifier(story['repliesCount'] ?? 0),
                            builder: (context, value, child) {
                              return Text(
                                'Comments (${story['repliesCount'] ?? 0})',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                              _resumeProgress();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Comments list with key for proper rebuilding
                    Expanded(
                      child: StoryRepliesSection(
                        key: ValueKey('replies_${story['_id']}'),
                        storyId: story['_id'],
                        storyAuthorId: story['author']['_id'],
                        repliesCount: repliesCount,
                        onReplyCountChanged: () {
                          if (mounted) {
                            // Refresh the parent story data
                            _loadStory();
                            setBottomSheetState(() {
                              debugPrint('✅ Reply count changed, updating comments sheet');
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      debugPrint('📝 Comments sheet closed');
      _resumeProgress();
    });
  }

  void _nextStory() {
    if (!mounted) return;

    if (_currentIndex < widget.userStories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory();
    } else {
      // All stories viewed, exit
      widget.onComplete?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (!mounted) return;

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory();
    }
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -500) {
      // Swipe left - next story
      _nextStory();
    } else if (velocity > 500) {
      // Swipe right - previous story or exit
      if (_currentIndex == 0) {
        Navigator.pop(context);
      } else {
        _previousStory();
      }
    }
  }

  void _handleVerticalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 500) {
      // Swipe down - exit
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard against empty stories
    if (widget.userStories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Stories Available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no stories to view right now',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final story = widget.userStories[_currentIndex];
    final author = story['author'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Handle arrow keys for navigation
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextStory();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousStory();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTapDown: (details) {
            _pauseProgress();
          },
          onTapUp: (details) {
            _resumeProgress();

            // Check if tap is on left or right side
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              _previousStory();
            } else {
              _nextStory();
            }
          },
          onTapCancel: () {
            _resumeProgress();
          },
          onHorizontalDragEnd: _handleHorizontalDrag,
          onVerticalDragEnd: _handleVerticalDrag,
          child: Stack(
            children: [
              // Story content
              Center(
                child: story['mediaType'] == 'video'
                    ? _isVideoInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: Colors.white)
                    : story['mediaType'] == 'text'
                        ? _buildTextStoryContent(story)
                        : Image.network(
                            '${ApiService.baseApi}${story['mediaUrl']}',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 48,
                              ),
                            );
                          },
                        ),
            ),

            // Progress bars with improved styling
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.userStories.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: index < _currentIndex
                            ? Container(color: Colors.white)
                            : index == _currentIndex
                                ? AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (context, child) {
                                      return LinearProgressIndicator(
                                        value: _progressController.value,
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      );
                                    },
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header with user info
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to user profile
                      if (author['_id'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              userId: author['_id'],
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: author['avatar'] != null
                          ? NetworkImage(
                              '${ApiService.baseApi}${author['avatar']}',
                            )
                          : null,
                      child: author['avatar'] == null
                          ? Text(
                              author['name'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to user profile
                        if (author['_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(
                                userId: author['_id'],
                              ),
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  author['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                TimeUtils.formatMessageTimestamp(
                                    story['createdAt']),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '⏱️ ${_getTimeRemaining(story)}',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOwnStory)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation();
                        } else if (value == 'fix-comments') {
                          _fixReplyCount();
                        } else if (value == 'share') {
                          _showShareOptions();
                        } else if (value == 'analytics') {
                          _viewAnalytics();
                        } else if (value == 'creative') {
                          _openCreativeTools();
                        } else if (value == 'highlights') {
                          _addToHighlights();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Share Story',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'analytics',
                          child: Row(
                            children: [
                              Icon(Icons.analytics, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'View Analytics',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'creative',
                          child: Row(
                            children: [
                              Icon(Icons.brush, color: Colors.purple),
                              SizedBox(width: 8),
                              Text(
                                'Creative Tools',
                                style: TextStyle(color: Colors.purple),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'highlights',
                          child: Row(
                            children: [
                              Icon(Icons.collections_bookmark, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Add to Highlights',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'fix-comments',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Fix Comment Count',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete Story',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (!_isOwnStory)
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: _showShareOptions,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Caption
            if (story['caption'] != null && story['caption'].isNotEmpty)
              Positioned(
                bottom: 48,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    story['caption'],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Viewers count (for own stories) - tap to see list
            if (_isOwnStory &&
                story['viewersCount'] != null &&
                story['viewersCount'] > 0)
              Positioned(
                bottom: 16,
                left: 16,
                child: GestureDetector(
                  onTap: _showViewersBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${story['viewersCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          story['viewersCount'] == 1 ? 'view' : 'views',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Reaction and comment buttons (bottom right) - Show for all stories
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                right: 12,
                child: Builder(
                  builder: (context) {
                    final responsive = context.responsive;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show reaction picker if open
                        if (_showReactionPicker)
                          Container(
                            margin: EdgeInsets.only(bottom: responsive.paddingSmall),
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.paddingSmall,
                              vertical: responsive.paddingXSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(responsive.radiusXLarge),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['❤️', '😂', '😮', '😢', '👏', '🔥'].map((emoji) {
                                return GestureDetector(
                                  onTap: () => _reactToStory(emoji),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: responsive.paddingXSmall,
                                    ),
                                    child: Text(
                                      emoji,
                                      style: TextStyle(fontSize: responsive.fontLarge),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Send message button
                        GestureDetector(
                          onTap: () {
                            _showReplyBottomSheet();
                          },
                          child: Container(
                            padding: EdgeInsets.all(responsive.paddingSmall),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: responsive.iconMedium,
                            ),
                          ),
                        ),
                        SizedBox(height: responsive.paddingMedium),
                        // Comments button with count
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                // If there are comments, show them; otherwise show input
                                final repliesCount = widget.userStories[_currentIndex]['repliesCount'] ?? 0;
                                if (repliesCount > 0) {
                                  _showCommentsBottomSheet();
                                } else {
                                  // No comments yet, show add comment input
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
                                          storyId: widget.userStories[_currentIndex]['_id'],
                                          onReplySubmitted: (_) {
                                            // Reload story to get updated reply count
                                            _loadStory();
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(responsive.paddingSmall),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.comment,
                                  color: Colors.white,
                                  size: responsive.iconMedium,
                                ),
                              ),
                            ),
                            // Comments count
                            if ((widget.userStories[_currentIndex]['repliesCount'] ?? 0) > 0)
                              Padding(
                                padding: EdgeInsets.only(top: responsive.paddingXSmall),
                                child: Text(
                                  '${widget.userStories[_currentIndex]['repliesCount']}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: responsive.fontSmall,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: responsive.paddingMedium),
                        // Reaction button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showReactionPicker = !_showReactionPicker;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(responsive.paddingSmall),
                            decoration: BoxDecoration(
                              color: _currentUserReaction != null
                                  ? Colors.pink.withValues(alpha: 0.8)
                                  : Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: _currentUserReaction != null
                                ? Text(
                                    _currentUserReaction!,
                                    style: TextStyle(fontSize: responsive.fontMedium),
                                  )
                                : Icon(
                                    Icons.favorite_border,
                                    color: Colors.white,
                                    size: responsive.iconMedium,
                                  ),
                          ),
                        ),

                        // Reactions count
                        if (_reactionsCount > 0)
                          Padding(
                            padding: EdgeInsets.only(top: responsive.paddingXSmall),
                            child: Text(
                              '$_reactionsCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.fontSmall,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStoryContent(Map<String, dynamic> story) {
    // Parse background color from hex string
    Color backgroundColor = Colors.black;
    try {
      final colorString = story['backgroundColor'] ?? '#000000';
      final hexColor = colorString.replaceAll('#', '');
      backgroundColor = Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      debugPrint('Error parsing background color: $e');
    }

    final textColor =
        backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Builder(
        builder: (context) {
          final responsive = context.responsive;
          return Center(
            child: Padding(
              padding: EdgeInsets.all(responsive.paddingHuge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    story['textContent'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: responsive.fontXLarge,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: textColor.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (story['caption'] != null &&
                      story['caption'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: responsive.paddingXLarge),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.paddingLarge,
                          vertical: responsive.paddingMedium,
                        ),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(responsive.radiusLarge),
                        ),
                        child: Text(
                          story['caption'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: responsive.fontMedium,
                            color: textColor.withValues(alpha: 0.9),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Floating reaction animation widget
class _FloatingReactionWidget extends StatefulWidget {
  final String emoji;

  const _FloatingReactionWidget({required this.emoji});

  @override
  State<_FloatingReactionWidget> createState() =>
      _FloatingReactionWidgetState();
}

class _FloatingReactionWidgetState extends State<_FloatingReactionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _positionAnimation = Tween<double>(
      begin: 0.0,
      end: -150.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 30,
      bottom: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _positionAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(
                    fontSize: 48,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
