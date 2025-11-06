import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'socket_service.dart';
import '../config/app_router.dart';
import '../utils/url_utils.dart';
import '../pages/post_detail_page.dart';
import '../pages/user_profile_page.dart';
import '../pages/videos_page.dart';
import '../utils/app_logger.dart';

class GlobalNotificationService {
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal() {
    // Initialize keys in constructor to ensure they're created properly
    _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
    // Use the app's root navigator key managed by GoRouter for global navigation
    _navigatorKey = rootNavigatorKey;
  }

  final _logger = AppLogger();

  late final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;
  late final GlobalKey<NavigatorState> _navigatorKey;

  // Public getters for the keys
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey =>
      _scaffoldMessengerKey;
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // Callback to update unread message count
  Function(int)? onUnreadMessageCountChanged;

  // Store listener references
  Function(dynamic)? _messageListener;
  Function(dynamic)? _unreadCountListener;
  Function(dynamic)? _notificationListener;
  bool _isInitialized = false;
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  void initialize() {
    // Prevent multiple initializations
    if (_isInitialized) {
      return;
    }

    final socketService = SocketService();

    // Add connection status listener to re-initialize when socket reconnects
    socketService.addConnectionStatusListener(_handleSocketConnectionChange);

    // Create and store the listener callback for new messages
    _messageListener = (data) {
      _logger.debug(
        'New message event received - UI will be updated by ChatPage listener',
      );
      // NOTE: message:new event is used ONLY for updating chat UI in real-time
      // DO NOT show notification popup here - that's handled by notification:new event
    };

    // Create listener for unread count updates
    _unreadCountListener = (data) {
      _logger.debug('message:unread-count event received');

      if (data != null && data['increment'] != null) {
        final increment = data['increment'] as int;
        _logger.debug('Updating unread count by: $increment');

        // Notify listeners to update unread count
        if (onUnreadMessageCountChanged != null) {
          onUnreadMessageCountChanged!(increment);
        }
      }
    };

    socketService.on('message:new', _messageListener!);
    socketService.on('message:unread-count', _unreadCountListener!);

    // Add club-related socket listeners
    _setupClubSocketListeners(socketService);

    // Create listener for notification events (this shows the actual popup)
    _notificationListener = (data) {
      try {
        _logger.debug('Notification event received');

        if (data == null) {
          _logger.debug('Notification data is null');
          return;
        }

        // Handle both data structures:
        // 1. { notification: {...} } - wrapped format
        // 2. { type: '...', sender: {...}, ... } - flat format
        Map<String, dynamic>? notification;

        if (data['notification'] != null) {
          // Wrapped format
          notification = data['notification'] as Map<String, dynamic>;
        } else if (data['type'] != null) {
          // Flat format (from some endpoints)
          notification = data as Map<String, dynamic>;
        } else {
          _logger.debug('Unrecognized notification data structure');
          return;
        }

        final type = notification['type'] as String?;
        final sender = notification['sender'] as Map<String, dynamic>?;
        final senderName = sender?['name'] ?? 'Someone';

        _logger.debug('Notification type: $type from $senderName');

        // Don't show notification if it's null type
        if (type == null) {
          _logger.debug('Notification type is null, skipping');
          return;
        }

        // Show popup for all notification types
        if (type == 'message') {
          final content = notification['message'] as String? ?? '';
          _showMessageNotification(sender, senderName, content);
        } else if (type == 'message_reaction') {
          final content = notification['message'] as String? ??
              '$senderName reacted to your message';
          _showGeneralNotification(
            sender,
            content,
          );
        } else if (type == 'message_edited') {
          final content = notification['message'] as String? ??
              '$senderName edited a message';
          _showGeneralNotification(
            sender,
            content,
          );
        } else if (type == 'message_deleted') {
          final content = notification['message'] as String? ??
              '$senderName deleted a message';
          _showGeneralNotification(
            sender,
            content,
          );
        } else if (type == 'message_pinned') {
          final content = notification['message'] as String? ??
              '$senderName pinned a message';
          _showGeneralNotification(
            sender,
            content,
          );
        } else {
          // Show notification for other types (comment, reaction, etc.)
          // Prefer backend-provided message when available for precise context
          String message = (notification['message'] as String?) ?? '';
          String? postId;
          String? userId;
          String? videoId;

          switch (type) {
            case 'tag':
              message = message.isNotEmpty ? message : '$senderName tagged you in a post';
              postId = _extractId(notification['post']);
              break;
            case 'video_tag':
              message = message.isNotEmpty ? message : '$senderName tagged you in a video';
              videoId = _extractId(notification['relatedVideo'] ?? notification['video']);
              break;
            case 'reaction':
              final reactionType = notification['reactionType'] ?? 'reacted';
              final reactionEmoji = _getReactionEmoji(reactionType);
              message = '$senderName reacted $reactionEmoji to your post';
              postId = _extractId(notification['post']);
              break;
            case 'comment':
              message = message.isNotEmpty ? message : '$senderName commented on your post';
              postId = _extractId(notification['post']);
              break;
            case 'comment_reaction':
              final reactionType = notification['reactionType'] ?? 'reacted';
              final reactionEmoji = _getReactionEmoji(reactionType);
              message = '$senderName reacted $reactionEmoji to your comment';
              postId = _extractId(notification['post']);
              break;
            case 'reply':
              message = '$senderName replied to your comment';
              postId = _extractId(notification['post']);
              break;
            case 'reaction_reply':
              message = '$senderName replied to a comment on your post';
              postId = _extractId(notification['post']);
              break;
            case 'follow':
              message = '$senderName started following you';
              userId = _extractId(sender?['_id']);
              break;
            case 'story':
              message = '$senderName posted a new story';
              break;
            case 'story_reaction':
              message = '$senderName reacted to your story';
              break;
            case 'story_reply':
              message = '$senderName replied to your story';
              break;
            case 'post_share':
              message = '$senderName reshared your post';
              postId = _extractId(notification['post']);
              break;
            case 'video_like':
              message = '$senderName liked your video';
              break;
            case 'video_comment':
              message = message.isNotEmpty ? message : '$senderName commented on your video';
              break;
            case 'video_reply':
              message = message.isNotEmpty ? message : '$senderName replied to your video comment';
              break;
            case 'video_comment_reaction':
              final reactionType = notification['reactionType'] ?? 'reacted';
              final reactionEmoji = _getReactionEmoji(reactionType);
              message = '$senderName reacted $reactionEmoji to your video comment';
              break;
            case 'video_comment_tag':
              message = message.isNotEmpty ? message : '$senderName mentioned you in a video comment';
              videoId = _extractId(notification['relatedVideo'] ?? notification['video']);
              break;
            case 'photo_comment':
              message = '$senderName commented on your photo';
              break;
            case 'photo_reaction':
              final reactionType = notification['reactionType'] ?? 'reacted';
              final reactionEmoji = _getReactionEmoji(reactionType);
              message = '$senderName reacted $reactionEmoji to your photo';
              break;
            case 'photo_comment_reaction':
              final reactionType = notification['reactionType'] ?? 'reacted';
              final reactionEmoji = _getReactionEmoji(reactionType);
              message = '$senderName reacted $reactionEmoji to your photo comment';
              break;
            case 'photo_comment_reply':
              message = '$senderName replied to your photo comment';
              break;
            case 'photo_tag':
              message = '$senderName tagged you in a photo';
              break;
            case 'poke':
              // Use the backend message directly as it already includes emoji
              final pokeType = notification['pokeType'] as String? ?? 'poke';
              final pokeEmojis = {
                'slap': '👋💥',
                'kiss': '💋😘',
                'hug': '🤗💕',
                'wave': '👋😊',
              };
              final emoji = pokeEmojis[pokeType] ?? '👋';
              message = notification['message'] ?? '$senderName poked you!';
              // Show poke notification using the dedicated method for better UI
              _showPokeNotification(sender, senderName, message, emoji);
              return; // Early return to avoid calling _showGeneralNotification

            case 'game':
              final gameType = notification['gameData']?['gameType'] as String? ?? 'game';
              final gameTypeDisplay = gameType.replaceAll('-', ' ').split(' ').map((word) {
                return word[0].toUpperCase() + word.substring(1);
              }).join(' ');
              message = '$senderName invited you to play $gameTypeDisplay';
              break;

            // Club-related notifications
            case 'club_join_request':
              final clubName = notification['clubName'] as String? ?? 'a club';
              message = '$senderName wants to join $clubName';
              break;
            case 'club_request_approved':
              final clubName = notification['clubName'] as String? ?? 'the club';
              message = 'Your request to join $clubName was approved';
              break;
            case 'club_request_rejected':
              final clubName = notification['clubName'] as String? ?? 'the club';
              message = 'Your request to join $clubName was declined';
              break;
            case 'club_invite':
              final clubName = notification['clubName'] as String? ?? 'a club';
              message = '$senderName invited you to join $clubName';
              break;
            case 'club_member_joined':
              final clubName = notification['clubName'] as String? ?? 'the club';
              message = '$senderName joined $clubName';
              break;
            case 'club_member_left':
              final clubName = notification['clubName'] as String? ?? 'the club';
              message = '$senderName left $clubName';
              break;
            case 'club_removed':
              final clubName = notification['clubName'] as String? ?? 'the club';
              message = 'You were removed from $clubName';
              break;
            case 'club_post':
              final clubName = notification['clubName'] as String? ?? 'a club';
              message = '$senderName posted in $clubName';
              break;

            default:
              // Use message from backend if available
              message = notification['message'] ??
                  'New notification from $senderName';
          }

          _showGeneralNotification(
            sender,
            message,
            postId: postId,
            userId: userId,
            videoId: videoId,
          );
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Error processing notification:new event',
          error: e,
          stackTrace: stackTrace,
        );
      }
    };

    socketService.on('notification:new', _notificationListener!);
    _logger.debug('Notification listener registered');

    // Add dedicated listener for poke events
    socketService.on('poke:received', (data) {
      try {
        if (data != null &&
            data['poke'] != null &&
            data['notification'] != null) {
          final poke = data['poke'] as Map<String, dynamic>;
          final notification = data['notification'] as Map<String, dynamic>;
          final sender = poke['sender'] as Map<String, dynamic>?;
          final senderName = sender?['name'] ?? 'Someone';
          final pokeType = poke['pokeType'] as String? ?? 'poke';

          final pokeEmojis = {
            'slap': '👋💥',
            'kiss': '💋😘',
            'hug': '🤗💕',
            'wave': '👋😊',
          };
          final emoji = pokeEmojis[pokeType] ?? '👋';
          final message =
              notification['message'] as String? ?? '$senderName poked you!';

          _showPokeNotification(sender, senderName, message, emoji);
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Error processing poke:received event',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });

    // Add listener for account deletion events
    socketService.on('account_deleted', (data) {
      try {
        _logger.info('Account deleted event received');

        final message = data?['message'] as String? ??
            'Your account has been deleted by an administrator.';

        // Show a critical notification
        _showAccountDeletedNotification(message);

        // After a short delay, log out the user
        Future.delayed(const Duration(seconds: 3), () async {
          await _handleAccountDeletion();
        });
      } catch (e, stackTrace) {
        _logger.error(
          'Error processing account_deleted event',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });

    // Add listener for account banned events
    socketService.on('account_banned', (data) {
      try {
        _logger.info('Account banned event received');

        final message = data?['message'] as String? ??
            data?['reason'] as String? ??
            'Your account has been permanently banned by an administrator.';

        // Show a critical notification
        _showAccountBannedNotification(message);

        // After a short delay, log out the user
        Future.delayed(const Duration(seconds: 3), () async {
          await _handleAccountDeletion();
        });
      } catch (e, stackTrace) {
        _logger.error(
          'Error processing account_banned event',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });

    // Add listener for account suspended events
    socketService.on('account_suspended', (data) {
      try {
        _logger.info('Account suspended event received');

        final message = data?['message'] as String? ??
            data?['reason'] as String? ??
            'Your account has been suspended by an administrator.';

        // Show a warning notification
        _showAccountSuspendedNotification(message);

        // After a short delay, log out the user
        Future.delayed(const Duration(seconds: 3), () async {
          await _handleAccountDeletion();
        });
      } catch (e, stackTrace) {
        _logger.error(
          'Error processing account_suspended event',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });

    _isInitialized = true;
    _logger.debug('GlobalNotificationService initialized');
  }

  // Handle socket connection status changes
  void _handleSocketConnectionChange(bool isConnected) {
    _logger.info('🔔 Socket connection status changed: $isConnected');

    if (isConnected && _isInitialized) {
      _logger.info('🔔 Socket reconnected, re-registering listeners...');
      // Listeners are automatically re-registered by SocketService._reRegisterListeners()
      // But we log it here for visibility
      _logger.info('🔔 Notification listeners should be active again');
    } else if (!isConnected) {
      _logger.warning('🔔 Socket disconnected, notifications may be delayed');
    }
  }

  // Setup club-related socket listeners
  void _setupClubSocketListeners(SocketService socketService) {
    // Club join request received by admins
    socketService.on('club:join-request', (data) {
      _logger.debug('Club join request received: $data');
      // This will be handled by the notification system
    });

    // Club request approved
    socketService.on('club:request-approved', (data) {
      _logger.debug('Club request approved: $data');
      // This will be handled by the notification system
    });

    // Club request rejected
    socketService.on('club:request-rejected', (data) {
      _logger.debug('Club request rejected: $data');
      // This will be handled by the notification system
    });

    // Club invite received
    socketService.on('club:invited', (data) {
      _logger.debug('Club invite received: $data');
      // This will be handled by the notification system
    });

    // Member joined club
    socketService.on('club:member-joined', (data) {
      _logger.debug('Club member joined: $data');
      // This will be handled by the notification system
    });

    // Member left club
    socketService.on('club:member-left', (data) {
      _logger.debug('Club member left: $data');
      // This will be handled by the notification system
    });

    // Member removed from club
    socketService.on('club:removed', (data) {
      _logger.debug('Club member removed: $data');
      // This will be handled by the notification system
    });

    // New club post/discussion
    socketService.on('club:new-discussion', (data) {
      _logger.debug('Club new discussion: $data');
      // This will be handled by the notification system
    });
  }

  // Helper method to get reaction emoji
  String _getReactionEmoji(String reactionType) {
    final reactionEmojis = {
      'like': '👍',
      'celebrate': '🎉',
      'support': '💪',
      'insightful': '💡',
      'funny': '😂',
      'mindblown': '🤯',
      'love': '❤️',
      'heart': '❤️',
    };
    return reactionEmojis[reactionType.toLowerCase()] ?? '👍';
  }

  // Helper method to safely extract ID from various types
  String? _extractId(dynamic value) {
    if (value == null) return null;

    // If it's already a String, return it
    if (value is String) return value;

    // If it's a number (int), convert to String
    if (value is int) return value.toString();

    // If it's a Map with '_id' field, extract that
    if (value is Map<String, dynamic>) {
      final id = value['_id'];
      if (id is String) return id;
      if (id is int) return id.toString();
    }

    // Last resort: try to convert to String
    return value.toString();
  }

  void _showMessageNotification(
    Map<String, dynamic>? sender,
    String senderName,
    String content,
  ) {
    try {
      _showOverlayBanner(
        leading: CircleAvatar(
          radius: 16,
          backgroundImage: sender?['avatar'] != null
              ? UrlUtils.getAvatarImageProvider(sender!['avatar'])
              : null,
          child: sender?['avatar'] == null
              ? Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                )
              : null,
        ),
        title: senderName,
        subtitle: content,
        icon: Icons.message,
      );
    } catch (e, stackTrace) {
      _logger.error(
        '❌ Error showing message notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _showPokeNotification(
    Map<String, dynamic>? sender,
    String senderName,
    String message,
    String emoji,
  ) {
    final senderId = sender?['_id'] as String?;

    _showOverlayBanner(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.purple.shade300,
        backgroundImage: sender?['avatar'] != null
            ? UrlUtils.getAvatarImageProvider(sender!['avatar'])
            : null,
        child: sender?['avatar'] == null
            ? Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              )
            : null,
      ),
      title: '$emoji Poke!',
      subtitle: message,
      icon: Icons.pan_tool,
      userId: senderId,
    );
  }

  void _showGeneralNotification(
    Map<String, dynamic>? sender,
    String message, {
    String? postId,
    String? userId,
    String? videoId,
  }) {
    _showOverlayBanner(
      leading: const Icon(Icons.notifications_active, color: Colors.white),
      title: 'Notification',
      subtitle: message,
      icon: Icons.notifications,
      postId: postId,
      userId: userId,
      videoId: videoId,
    );
  }

  void _showOverlayBanner({
    required Widget leading,
    required String title,
    required String subtitle,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
    String? postId,
    String? userId,
    String? videoId,
  }) {
    final navigatorState = navigatorKey.currentState;
    final navigatorContext = navigatorKey.currentContext;

    if (navigatorState == null || navigatorContext == null) {
      _logger.debug('Navigator not ready, trying fallback SnackBar');
      try {
        _fallbackSnackBar(title: title, subtitle: subtitle, leading: leading);
        return;
      } catch (e) {
        _logger.debug('Fallback also failed: $e');
        return;
      }
    }

    try {
      // Clean up existing overlay
      _overlayTimer?.cancel();
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (e) {
      _logger.debug('Error cleaning up existing overlay: $e');
    }

    // Safely get MediaQuery data
    double topPadding = 0;
    try {
      final mediaQuery = MediaQuery.maybeOf(navigatorContext);
      topPadding = mediaQuery?.padding.top ?? 0;
    } catch (e) {
      _logger.debug('Error getting MediaQuery: $e');
    }

    try {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      tween: Tween<double>(begin: -1.0, end: 0.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, value * 100),
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          _hideOverlayBanner();
                          if (postId != null) {
                            _navigateToPost(postId);
                          } else if (videoId != null) {
                            _navigateToVideo(videoId);
                          } else if (userId != null) {
                            _navigateToUserProfile(userId);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade800,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          margin: EdgeInsets.only(top: topPadding > 0 ? 0 : 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              leading,
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle.length > 120
                                          ? '${subtitle.substring(0, 120)}...'
                                          : subtitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => _hideOverlayBanner(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      final overlayState = navigatorState.overlay;
      if (overlayState == null) {
        _logger.debug('OverlayState not found, falling back to SnackBar');
        _fallbackSnackBar(title: title, subtitle: subtitle, leading: leading);
        return;
      }

      overlayState.insert(_overlayEntry!);

      _overlayTimer = Timer(duration, () {
        _hideOverlayBanner();
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Error showing overlay banner notification',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        _fallbackSnackBar(title: title, subtitle: subtitle, leading: leading);
      } catch (fallbackError) {
        _logger.error('Fallback also failed', error: fallbackError);
      }
    }
  }

  void _hideOverlayBanner() {
    try {
      _overlayTimer?.cancel();
      _overlayTimer = null;
    } catch (e) {
      _logger.debug('Error canceling overlay timer: $e');
    }

    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (e) {
      _logger.debug('Error removing overlay entry: $e');
    }
  }

  void _fallbackSnackBar({
    required String title,
    required String subtitle,
    required Widget leading,
  }) {
    _logger.info('🔔 Attempting fallback SnackBar');
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      _logger.warning('💬 ❌ ScaffoldMessenger not available for fallback');
      return;
    }

    try {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 60, left: 12, right: 12),
          backgroundColor: Colors.blue.shade700,
          content: Row(
            children: [
              SizedBox(width: 32, height: 32, child: leading),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.length > 80
                          ? '${subtitle.substring(0, 80)}...'
                          : subtitle,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      _logger.info('🔔 ✅ Fallback SnackBar displayed');
    } catch (e, stackTrace) {
      _logger.error(
        '❌ Error showing fallback SnackBar',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _navigateToPost(String postId) {
    final navigatorState = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    if (navigatorState != null && context != null) {
      debugPrint('📍 Navigating to post: $postId');

      try {
        // Use a Future to ensure the navigation happens after the overlay is dismissed
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigatorState.mounted) {
            // Navigate using MaterialPageRoute
            final route = MaterialPageRoute(
              builder: (context) => PostDetailPage(postId: postId),
            );
            navigatorState.push(route);
          }
        });
      } catch (e) {
        debugPrint('❌ Error navigating to post: $e');
      }
    } else {
      debugPrint('❌ Navigator not available for post navigation');
    }
  }

  void _navigateToUserProfile(String userId) {
    final navigatorState = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    if (navigatorState != null && context != null) {
      debugPrint('📍 Navigating to user profile: $userId');

      try {
        // Use a Future to ensure the navigation happens after the overlay is dismissed
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigatorState.mounted) {
            // Navigate to user profile page
            final route = MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: userId),
            );
            navigatorState.push(route);
          }
        });
      } catch (e) {
        debugPrint('❌ Error navigating to user profile: $e');
      }
    } else {
      debugPrint('❌ Navigator not available for user profile navigation');
    }
  }

  void _navigateToVideo(String videoId) {
    final navigatorState = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    if (navigatorState != null && context != null) {
      debugPrint('📍 Navigating to video: $videoId');

      try {
        // Use a Future to ensure the navigation happens after the overlay is dismissed
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigatorState.mounted) {
            // Navigate to videos page with initial video ID
            final route = MaterialPageRoute(
              builder: (context) => VideosPage(initialVideoId: videoId),
            );
            navigatorState.push(route);
          }
        });
      } catch (e) {
        debugPrint('❌ Error navigating to video: $e');
      }
    } else {
      debugPrint('❌ Navigator not available for video navigation');
    }
  }

  // Note: Removed setActiveConversation as notifications are now only shown
  // via notification:new event which is already filtered by the backend/chat page

  void showNotification({
    required String title,
    required String message,
    String? postId,
    String? userId,
  }) {
    _showGeneralNotification(null, message, postId: postId, userId: userId);
  }

  // Show account deletion notification
  void _showAccountDeletedNotification(String message) {
    _logger.info('🚨 Showing account deletion notification');

    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        // Show a critical dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Account Deleted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will be logged out shortly.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleAccountDeletion();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error showing account deletion dialog',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  // Show account banned notification
  void _showAccountBannedNotification(String message) {
    _logger.info('🚫 Showing account banned notification');

    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        // Show a critical dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Account Banned'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will be logged out shortly.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleAccountDeletion();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error showing account banned dialog',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  // Show account suspended notification
  void _showAccountSuspendedNotification(String message) {
    _logger.info('⚠️ Showing account suspended notification');

    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        // Show a warning dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 32),
                SizedBox(width: 12),
                Text('Account Suspended'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will be logged out shortly. Please contact support if you believe this is an error.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleAccountDeletion();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error showing account suspended dialog',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  // Handle account deletion (logout and navigate to login)
  Future<void> _handleAccountDeletion() async {
    try {
      _logger.info('🚨 Handling account deletion - logging out user');

      // Import required services
      final prefs = await SharedPreferences.getInstance();

      // Clear all user data
      await prefs.clear();

      // Disconnect socket
      final socketService = SocketService();
      socketService.disconnect();

      // Navigate to login screen
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // Clear all routes and navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }

      _logger.info('🚨 User logged out due to account deletion');
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling account deletion',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    final socketService = SocketService();

    // Remove connection status listener
    socketService.removeConnectionStatusListener(_handleSocketConnectionChange);

    if (_messageListener != null) {
      socketService.off('message:new', _messageListener);
      _messageListener = null;
    }

    if (_unreadCountListener != null) {
      socketService.off('message:unread-count', _unreadCountListener);
      _unreadCountListener = null;
    }

    if (_notificationListener != null) {
      socketService.off('notification:new', _notificationListener);
      _notificationListener = null;
    }
    _hideOverlayBanner();

    _isInitialized = false;
    onUnreadMessageCountChanged = null;
  }
}
