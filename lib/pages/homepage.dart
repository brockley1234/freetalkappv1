import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/cache_service.dart';
import '../services/messaging_service.dart';
import '../services/global_notification_service.dart';
import '../services/realtime_update_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../utils/avatar_utils.dart';
import '../utils/responsive_dimensions.dart';
import '../utils/debounce_helper.dart';
import '../widgets/comments_bottom_sheet_enhanced.dart';
import '../widgets/reaction_picker.dart';
import '../widgets/notification_card.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_carousel_widget.dart';
import '../widgets/post_card.dart';
import '../widgets/post_reactions_viewer.dart';
import '../widgets/post_appearance_animations.dart';
import '../widgets/feed_filter_selector.dart';
import '../widgets/feed_loading_skeleton.dart';
import '../widgets/feed_empty_error_widget.dart';
import '../widgets/animated_name_widget.dart';
import '../l10n/app_localizations.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import 'loginpage.dart';
import 'create_post_page.dart';
import 'post_detail_page.dart';
import 'conversations_page.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';
import 'create_story_page.dart';
import 'story_viewer_page.dart';
import 'profile_settings_page.dart';
import 'profile_visitors_page.dart';
import 'pokes_page.dart';
import 'videos_page.dart';
import 'premium_subscription_page.dart';
import 'saved_posts_page.dart';
import 'events/events_list_page.dart';
import 'jobs/jobs_list_page.dart';
import 'crisis/crisis_response_page.dart';
import 'games/games_list_page.dart';
import 'marketplace/marketplace_listings_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomePage({super.key, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final bool _isLoading = false;
  bool _isLoadingProfile = false;
  bool _isLoadingPosts = false;
  Map<String, dynamic>? _currentUser;
  List<dynamic> _posts = [];
  int _currentPage = 1;
  bool _hasMorePosts = true;
  bool _isSocketConnected = false;
  static const int _maxCachedPosts =
      100; // Limit posts in memory to prevent overflow
  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = false;
  int _unreadNotificationCount = 0;
  int _unreadMessageCount = 0;
  Function(bool)? _connectionStatusListener;
  bool _isUploadingAvatar = false;
  bool _isUploadingFeedBanner = false;
  List<dynamic> _stories = [];
  bool _isLoadingStories = false;

  // Online users count state
  int _onlineUsersCount = 0;
  bool _isLoadingOnlineUsersCount = false;

  // User posts state (for profile page)
  List<dynamic> _userPosts = [];
  bool _isLoadingUserPosts = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _searchedUsers = [];
  List<dynamic> _searchedPosts = [];
  bool _isSearchingUsers = false;
  bool _isSearchingPosts = false;
  Timer? _searchDebounce;

  // Search history state
  List<String> _searchHistory = [];
  static const int _maxSearchHistory = 10;

  // Multi-content search state
  List<dynamic> _searchedVideos = [];
  List<dynamic> _searchedStories = [];
  List<dynamic> _searchedSavedPosts = [];
  bool _isSearchingVideos = false;
  bool _isSearchingStories = false;
  bool _isSearchingSavedPosts = false;

  // Search filters and sorting state
  String _searchSortBy = 'relevance'; // 'relevance', 'date', 'popularity'
  String _searchFilter = 'all'; // 'all', 'people', 'content'
  final List<String> _trendingSearches = ['Flutter', 'Web Development', 'Design', 'Business'];
  final bool _hasMoreSearchResults = true;

  // Suggested users state
  List<dynamic> _suggestedUsers = [];
  bool _isLoadingSuggestedUsers = false;

  // Top users state (for search recommendations)
  List<dynamic> _topUsers = [];
  bool _isLoadingTopUsers = false;
  bool _hasAttemptedTopUsers = false; // Track if we've tried loading top users

  // Top posts state (from followers)
  List<dynamic> _topPosts = [];
  bool _isLoadingTopPosts = false;
  bool _hasAttemptedTopPosts = false; // Track if we've tried loading top posts

  // Profile visitor state
  Map<String, dynamic>? _visitorStats;
  bool _isLoadingVisitorStats = false;

  // Error state for retry mechanism
  bool _hasPostLoadError = false;
  String? _postLoadErrorMessage;

  // Network status tracking
  bool _wasOffline = false;

  // Socket event listeners (store references for proper cleanup)
  Function(dynamic)? _postCreatedListener;
  Function(dynamic)? _postReactedListener;
  Function(dynamic)? _postCommentedListener;
  Function(dynamic)? _notificationNewListener;
  Function(dynamic)? _notificationUnreadCountListener;
  Function(dynamic)? _profileUpdatedListener;
  Function(dynamic)? _storyCreatedListener;
  Function(dynamic)? _storyViewedListener;
  Function(dynamic)? _storyDeletedListener;
  Function(dynamic)? _postDeletedListener;
  Function(dynamic)? _postUpdatedListener;
  Function(dynamic)? _postSharedListener;

  // Delayed task timers for cleanup
  Timer? _delayedNotificationsTimer;
  Timer? _delayedUnreadCountTimer;
  Timer? _delayedUnreadMessageTimer;
  Timer? _delayedStoriesTimer;
  Timer? _delayedSearchHistoryTimer;
  Timer? _delayedWelcomeMessageTimer;
  Timer? _delayedTopPostsTimer;
  Timer? _connectionRestoreRefreshTimer;
  Timer? _profileUpdateRefreshTimer;
  Timer? _delayedSocketRetryTimer;
  Timer? _onlineUsersCountRefreshTimer;

  // Performance: Debounce helpers for batching socket events
  late DebounceHelper _postUpdateDebouncer;
  late DebounceHelper _notificationDebouncer;
  late BatchUpdateHelper _feedUpdateBatcher;

  // Feed filter and sort state
  late FeedFilterType _selectedFeedFilter;
  late FeedSortType _selectedFeedSort;
  @override
  void initState() {
    super.initState();
    // Initialize performance helpers
    _postUpdateDebouncer = DebounceHelper(delayMilliseconds: 150);
    _notificationDebouncer = DebounceHelper(delayMilliseconds: 200);
    _feedUpdateBatcher = BatchUpdateHelper(delayMilliseconds: 100);

    // Initialize feed filter and sort defaults
    _selectedFeedFilter = FeedFilterType.all;
    _selectedFeedSort = FeedSortType.newest;

    // PERFORMANCE: Load critical items first, then defer non-essential loads
    _initializeSocketAndListeners(); // Fire-and-forget, handles its own async
    _loadCachedData(); // Load cached data first for instant display

    // Load essential profile + posts data
    _loadUserProfile();
    _loadPosts();

    // Defer less-critical items to avoid blocking main thread
    _delayedNotificationsTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadNotifications();
    });

    _delayedUnreadCountTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadUnreadCount();
    });

    _delayedUnreadMessageTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _loadUnreadMessageCount();
    });

    _delayedStoriesTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _loadStories();
    });

    _delayedSearchHistoryTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _loadSearchHistory();
    });

    _delayedWelcomeMessageTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _checkAndShowWelcomeMessage();
    });

    // Load top posts and suggested users after UI settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _delayedTopPostsTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _loadTopPosts();
          _loadSuggestedUsers();
        }
      });
    });

    // Load online users count initially and set up periodic refresh
    _loadOnlineUsersCount();
    _onlineUsersCountRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadOnlineUsersCount();
      } else {
        timer.cancel();
      }
    });
  }

  // Check and show welcome message for new users
  Future<void> _checkAndShowWelcomeMessage() async {
    // Wait a bit for the UI to settle and for user data to load
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenWelcome = prefs.getBool('has_seen_welcome_message') ?? false;

      // Only show welcome message if:
      // 1. User hasn't seen it before
      // 2. User has 0 followers (new user)
      // 3. User data is loaded
      if (!hasSeenWelcome && _currentUser != null && mounted) {
        final followersCount = _currentUser!['followersCount'] as int? ?? 0;

        if (followersCount == 0) {
          _showWelcomeDialog();
        }

        // Mark as seen regardless of follower count
        // This ensures it only shows once even if they get/lose followers
        await prefs.setBool('has_seen_welcome_message', true);
      }
    } catch (e) {
      AppLogger.e('Error checking welcome message: $e');
    }
  }

  // Show welcome dialog
  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.waving_hand,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome! 😊',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'re excited to have you here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start by following some users to see their posts in your feed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // Initialize socket connection and setup listeners
  Future<void> _initializeSocketAndListeners() async {
    try {
      final socketService = SocketService();

      await socketService.connect();

      // Don't wait for authentication in initState - can cause timer issues in tests
      // The socket will still be connecting, and we'll use connection status listener instead
      if (!socketService.isConnected) {
        // Schedule a retry if not connected after 1 second
        _delayedSocketRetryTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) {
            // Retry setup
            _setupSocketListeners();
          }
        });
      } else {
        // Socket connected, setup listeners immediately
        if (mounted) {
          _setupSocketListeners();
        }
      }

      // Setup global notification service callback for unread count
      final notificationService = GlobalNotificationService();
      notificationService.onUnreadMessageCountChanged = (increment) {
        if (mounted) {
          setState(() {
            _unreadMessageCount += increment;
            // Ensure count never goes below 0
            if (_unreadMessageCount < 0) {
              _unreadMessageCount = 0;
            }
          });
        }
      };

      // Ensure global services are initialized (safe to call multiple times)
      notificationService.initialize();
      RealtimeUpdateService().initialize();
    } catch (e) {
      AppLogger.e('Error initializing socket and listeners: $e');
    }
  }

  // Load cached data for instant display
  Future<void> _loadCachedData() async {
    final cacheService = CacheService();

    // Load all cached data in parallel for better performance
    final results = await Future.wait<dynamic>([
      cacheService.getCachedPosts(),
      cacheService.getCachedUserProfile(),
      cacheService.getCachedNotifications(),
      cacheService.getCachedStories(),
    ]);

    final cachedPosts = results[0] as List<dynamic>?;
    final cachedUser = results[1] as Map<String, dynamic>?;
    final cachedNotifications = results[2] as List<dynamic>?;
    final cachedStories = results[3] as List<dynamic>?;

    // Batch setState to avoid multiple rebuilds
    if (mounted) {
      setState(() {
        if (cachedPosts != null && cachedPosts.isNotEmpty) {
          _posts = cachedPosts;
        }
        if (cachedUser != null) {
          _currentUser = cachedUser;
        }
        if (cachedNotifications != null) {
          _notifications = cachedNotifications;
        }
        if (cachedStories != null) {
          _stories = cachedStories;
        }
      });
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // Set initial connection status
    setState(() {
      _isSocketConnected = socketService.isConnected;
    });

    // Listen for connection status changes
    _connectionStatusListener = (isConnected) {
      if (mounted) {
        setState(() {
          _isSocketConnected = isConnected;
        });

        // Auto-refresh when coming back online
        if (isConnected && _wasOffline) {
          AppLogger.i('🌐 Connection restored - auto-refreshing feed');
          _wasOffline = false;
          // Refresh posts and notifications when connection is restored
          _connectionRestoreRefreshTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              _refreshPosts();
              _loadNotifications();
            }
          });
        } else if (!isConnected) {
          _wasOffline = true;
          AppLogger.i('🌐 Connection lost - using cached data');
        }
      }
    };
    socketService.addConnectionStatusListener(_connectionStatusListener!);

    // Listen for new posts
    _postCreatedListener = (data) {
      if (mounted && data != null && data['post'] != null) {
        final newPost = data['post'];
        final postId = newPost['_id'];

        setState(() {
          // Check if post already exists in feed before adding (prevent duplicates)
          final existsInFeed = _posts.any((post) => post['_id'] == postId);
          if (!existsInFeed) {
            // Add new post to the top of the feed
            _posts.insert(0, newPost);
          }

          // Add to user posts if it's the current user's post
          if (_currentUser != null) {
            final author = newPost['author'];
            final authorId = author is Map ? author['_id'] : author;
            if (authorId == _currentUser!['_id']) {
              // Check for duplicates in user posts too
              final existsInUserPosts =
                  _userPosts.any((post) => post['_id'] == postId);
              if (!existsInUserPosts) {
                _userPosts.insert(0, newPost);
              }
            }
          }

          // Add to search results if it matches current search query
          if (_searchQuery.isNotEmpty) {
            final postContent =
                newPost['content']?.toString().toLowerCase() ?? '';
            if (postContent.contains(_searchQuery.toLowerCase())) {
              // Check for duplicates in search results too
              final existsInSearch =
                  _searchedPosts.any((post) => post['_id'] == postId);
              if (!existsInSearch) {
                _searchedPosts.insert(0, newPost);
              }
            }
          }
        });
      }
    };
    socketService.on('post:created', _postCreatedListener!);

    // Listen for post reactions
    _postReactedListener = (data) {
      if (mounted && data != null) {
        final postId = data['postId'];
        final postIndex = _posts.indexWhere((post) => post['_id'] == postId);

        if (postIndex != -1) {
          setState(() {
            _posts[postIndex]['reactionsCount'] = data['reactionsCount'];
            _posts[postIndex]['reactionsSummary'] = data['reactionsSummary'];

            // Update user's own reaction in the reactions array
            if (data['userId'] == _currentUser?['_id']) {
              final reactions = List<Map<String, dynamic>>.from(
                _posts[postIndex]['reactions'] ?? [],
              );

              if (data['reactionType'] == null) {
                // Remove reaction
                reactions.removeWhere((r) => r['user'] == data['userId']);
              } else {
                // Find and update or add reaction
                final existingIndex = reactions.indexWhere(
                  (r) => r['user'] == data['userId'],
                );

                if (existingIndex != -1) {
                  reactions[existingIndex]['type'] = data['reactionType'];
                } else {
                  reactions.add({
                    'user': data['userId'],
                    'type': data['reactionType'],
                  });
                }
              }

              _posts[postIndex]['reactions'] = reactions;
            }
          });
        }
      }
    };
    socketService.on('post:reacted', _postReactedListener!);

    // Listen for new comments
    _postCommentedListener = (data) {
      if (mounted && data != null) {
        final postId = data['postId'];
        final postIndex = _posts.indexWhere((post) => post['_id'] == postId);

        if (postIndex != -1) {
          setState(() {
            _posts[postIndex]['commentsCount'] = data['commentsCount'];

            // Add new comment to the comments list if it exists
            if (_posts[postIndex]['comments'] != null) {
              _posts[postIndex]['comments'].add(data['comment']);
            }
          });
        }
      }
    };
    socketService.on('post:commented', _postCommentedListener!);

    // Note: message:new listener is now handled globally by GlobalNotificationService
    // The unread count is updated via the callback set in _initializeSocketAndListeners

    // Listen for new notifications
    _notificationNewListener = (data) {
      if (mounted && data != null && data['notification'] != null) {
        final notification = data['notification'];
        final notificationType = notification['type'] as String?;

        // Batch update - only setState once
        setState(() {
          // Add new notification to the top of the list (except message notifications)
          // Message notifications are handled separately in conversations page
          if (notificationType != 'message') {
            _notifications.insert(0, notification);
          }

          // NOTE: Don't increment count here! The server will send 'notification:unread-count'
          // event immediately after with the accurate count. Incrementing here causes
          // the count to increase briefly and then "jump" to the server value.
          // The 'notification:unread-count' event is the single source of truth.
        });

        // Note: Notification popup is now handled by GlobalNotificationService
        // to avoid duplicate notifications
      }
    };
    socketService.on('notification:new', _notificationNewListener!);

    // Listen for notification unread count updates from server
    _notificationUnreadCountListener = (data) {
      if (mounted && data != null && data['unreadCount'] != null) {
        final unreadCount = data['unreadCount'] as int;
        debugPrint(
            '🔔 Received notification:unread-count update: $unreadCount');

        setState(() {
          _unreadNotificationCount = unreadCount;
        });
      }
    };
    socketService.on(
        'notification:unread-count', _notificationUnreadCountListener!);

    // Listen for shared posts
    _postSharedListener = (data) {
      if (mounted && data != null) {
        final post = data['post'];
        final sharedBy = data['sharedBy'];
        final sharedAt = data['sharedAt'];
        final message = data['message'];

        if (post != null && sharedBy != null) {
          // Add share metadata to the post
          final sharedPost = {
            ...post,
            'isShared': true,
            'sharedBy': sharedBy,
            'sharedAt': sharedAt,
            'shareMessage': message,
          };

          setState(() {
            // Add shared post to the top of the feed
            _posts.insert(0, sharedPost);
          });
        }
      }
    };
    socketService.on('post:shared', _postSharedListener!);

    // Listen for profile updates
    _profileUpdatedListener = (data) {
      if (mounted && data != null && data['user'] != null) {
        final updatedUser = data['user'];
        final updatedUserId = data['userId'];

        setState(() {
          // Merge updated user data with existing data to preserve any fields not included in the update
          _currentUser = {..._currentUser ?? {}, ...updatedUser};

          // Update all posts by this user to reflect new avatar/name
          for (var i = 0; i < _posts.length; i++) {
            final post = _posts[i];
            final author = post['author'];
            if (author != null && author['_id'] == updatedUserId) {
              _posts[i]['author']['avatar'] = updatedUser['avatar'];
              _posts[i]['author']['name'] = updatedUser['name'];
            }
          }

          // Update searched posts if any
          for (var i = 0; i < _searchedPosts.length; i++) {
            final post = _searchedPosts[i];
            final author = post['author'];
            if (author != null && author['_id'] == updatedUserId) {
              _searchedPosts[i]['author']['avatar'] = updatedUser['avatar'];
              _searchedPosts[i]['author']['name'] = updatedUser['name'];
            }
          }

          // Update searched users if any
          for (var i = 0; i < _searchedUsers.length; i++) {
            final user = _searchedUsers[i];
            if (user['_id'] == updatedUserId) {
              _searchedUsers[i]['avatar'] = updatedUser['avatar'];
              _searchedUsers[i]['name'] = updatedUser['name'];
            }
          }
        });

        // Cache the updated profile asynchronously
        CacheService().cacheUserProfile(updatedUser);

        // Force a UI rebuild to ensure image reloads
        _profileUpdateRefreshTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
          }
        });

        // Show success message
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  Text(localizations?.profilePictureUpdated ??
                      'Profile picture updated successfully!'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {}
    };
    socketService.on('user:profile-updated', _profileUpdatedListener!);

    // Listen for follow events
    socketService.on('user:followed', (data) {
      if (mounted && data != null && _currentUser != null) {
        final userId = data['userId'];

        // Update current user's counts if this event is for them
        if (userId == _currentUser!['_id']) {
          setState(() {
            _currentUser!['followersCount'] = data['followersCount'];
            _currentUser!['followingCount'] = data['followingCount'];
          });
          debugPrint(
            '👥 ✅ Updated current user followers: ${data['followersCount']}, following: ${data['followingCount']}',
          );
        }
      }
    });

    // Listen for unfollow events
    socketService.on('user:unfollowed', (data) {
      if (mounted && data != null && _currentUser != null) {
        final userId = data['userId'];

        // Update current user's counts if this event is for them
        if (userId == _currentUser!['_id']) {
          setState(() {
            _currentUser!['followersCount'] = data['followersCount'];
            _currentUser!['followingCount'] = data['followingCount'];
          });
          debugPrint(
            '👥 ✅ Updated current user followers: ${data['followersCount']}, following: ${data['followingCount']}',
          );
        }
      }
    });

    // Listen for new stories
    _storyCreatedListener = (data) {
      if (mounted && data != null) {
        // Reload stories to get updated list
        _loadStories();

        final story = data['story'];
        final author = story?['author'];
        final authorName = author?['name'] ?? 'Someone';

        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.onTertiary),
                const SizedBox(width: 12),
                Expanded(child: Text('$authorName posted a new story')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to story viewer (will be handled by story section)
              },
            ),
          ),
        );
      }
    };
    socketService.on('story:created', _storyCreatedListener!);

    // Listen for story views
    _storyViewedListener = (data) {
      if (mounted && data != null) {
        final storyId = data['storyId'];

        // Update story in list if it's the current user's story
        final storyIndex = _stories.indexWhere((userStories) {
          final stories = userStories['stories'] as List<dynamic>?;
          if (stories != null) {
            return stories.any((story) => story['_id'] == storyId);
          }
          return false;
        });

        if (storyIndex != -1) {
          // Just reload stories to get updated viewer counts
          _loadStories();
        }
      }
    };
    socketService.on('story:viewed', _storyViewedListener!);

    // Listen for story deletions
    _storyDeletedListener = (data) {
      if (mounted && data != null) {
        // Reload stories to remove deleted story
        _loadStories();
      }
    };
    socketService.on('story:deleted', _storyDeletedListener!);

    // Listen for post deletions (real-time update)
    _postDeletedListener = (data) {
      if (mounted && data != null) {
        final postId = data['postId'];

        setState(() {
          // Remove post from main feed
          _posts.removeWhere((post) => post['_id'] == postId);
          // Remove from search results if present
          _searchedPosts.removeWhere((post) => post['_id'] == postId);
          // Remove from user posts if present
          _userPosts.removeWhere((post) => post['_id'] == postId);
        });
      }
    };
    socketService.on('post:deleted', _postDeletedListener!);

    // Listen for post updates (real-time edit sync)
    _postUpdatedListener = (data) {
      if (mounted && data != null) {
        final postId = data['postId'];
        final newContent = data['content'];

        setState(() {
          // Update post in main feed
          final postIndex = _posts.indexWhere((post) => post['_id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex]['content'] = newContent;
            if (data['updatedAt'] != null) {
              _posts[postIndex]['updatedAt'] = data['updatedAt'];
            }
          }

          // Update post in user posts if present
          final userPostIndex = _userPosts.indexWhere(
            (post) => post['_id'] == postId,
          );
          if (userPostIndex != -1) {
            _userPosts[userPostIndex]['content'] = newContent;
            if (data['updatedAt'] != null) {
              _userPosts[userPostIndex]['updatedAt'] = data['updatedAt'];
            }
          }

          // Update in search results if present
          final searchIndex = _searchedPosts.indexWhere(
            (post) => post['_id'] == postId,
          );
          if (searchIndex != -1) {
            _searchedPosts[searchIndex]['content'] = newContent;
            if (data['updatedAt'] != null) {
              _searchedPosts[searchIndex]['updatedAt'] = data['updatedAt'];
            }
          }
        });
      }
    };
    socketService.on('post:updated', _postUpdatedListener!);

    // Listen for block events to remove blocked user's posts from feed
    socketService.on('user:blocked', (data) {
      if (mounted && data != null) {
        final blockedUserId = data['blockedUserId'];
        final blockerId = data['blockerId'];

        setState(() {
          // Remove posts from the blocked user from the feed
          _posts.removeWhere((post) {
            final authorId = post['author']?['_id'];
            return authorId == blockedUserId || authorId == blockerId;
          });

          // Remove from search results too
          _searchedPosts.removeWhere((post) {
            final authorId = post['author']?['_id'];
            return authorId == blockedUserId || authorId == blockerId;
          });
        });
      }
    });

    // Listen for unblock events to potentially show posts again
    socketService.on('user:unblocked', (data) {
      if (mounted && data != null) {
        // Reload posts to show unblocked user's content
        _refreshPosts();
      }
    });
  }

  @override
  @override
  void dispose() {
    // Dispose performance helpers
    _postUpdateDebouncer.dispose();
    _notificationDebouncer.dispose();
    _feedUpdateBatcher.dispose();

    // Dispose controllers and timers
    _searchController.dispose();
    _searchDebounce?.cancel();
    
    // Cancel all delayed task timers
    _delayedNotificationsTimer?.cancel();
    _delayedUnreadCountTimer?.cancel();
    _delayedUnreadMessageTimer?.cancel();
    _delayedStoriesTimer?.cancel();
    _delayedSearchHistoryTimer?.cancel();
    _delayedWelcomeMessageTimer?.cancel();
    _delayedTopPostsTimer?.cancel();
    _connectionRestoreRefreshTimer?.cancel();
    _profileUpdateRefreshTimer?.cancel();
    _delayedSocketRetryTimer?.cancel();
    _onlineUsersCountRefreshTimer?.cancel();

    // Clean up socket listeners - remove only our listeners, not global ones
    final socketService = SocketService();
    if (_postCreatedListener != null) {
      socketService.off('post:created', _postCreatedListener);
    }
    if (_postReactedListener != null) {
      socketService.off('post:reacted', _postReactedListener);
    }
    if (_postCommentedListener != null) {
      socketService.off('post:commented', _postCommentedListener);
    }
    if (_notificationNewListener != null) {
      socketService.off('notification:new', _notificationNewListener);
    }
    if (_notificationUnreadCountListener != null) {
      socketService.off(
          'notification:unread-count', _notificationUnreadCountListener);
    }
    if (_profileUpdatedListener != null) {
      socketService.off('user:profile-updated', _profileUpdatedListener);
    }
    if (_storyCreatedListener != null) {
      socketService.off('story:created', _storyCreatedListener);
    }
    if (_storyViewedListener != null) {
      socketService.off('story:viewed', _storyViewedListener);
    }
    if (_storyDeletedListener != null) {
      socketService.off('story:deleted', _storyDeletedListener);
    }
    if (_postDeletedListener != null) {
      socketService.off('post:deleted', _postDeletedListener);
    }
    if (_postUpdatedListener != null) {
      socketService.off('post:updated', _postUpdatedListener);
    }
    if (_postSharedListener != null) {
      socketService.off('post:shared', _postSharedListener);
    }

    // Clear global notification callback
    GlobalNotificationService().onUnreadMessageCountChanged = null;

    // Remove connection status listener
    if (_connectionStatusListener != null) {
      socketService.removeConnectionStatusListener(_connectionStatusListener!);
    }

    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (_isLoadingPosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      // Convert filter and sort enums to string parameters
      String filterParam = _getFilterString(_selectedFeedFilter);
      String sortParam = _getSortString(_selectedFeedSort);

      final result = await ApiService.getPosts(
        page: _currentPage,
        limit: 10,
        filter: filterParam,
        sort: sortParam,
      );

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> newPosts = result['data']['posts'];
        final pagination = result['data']['pagination'];

        if (mounted) {
          setState(() {
            _posts.addAll(newPosts);

            // Memory management: limit posts in memory to prevent overflow
            if (_posts.length > _maxCachedPosts) {
              // Keep only the most recent posts
              _posts = _posts.sublist(0, _maxCachedPosts);
            }

            _currentPage++;
            _hasMorePosts = pagination['page'] < pagination['pages'];
            _isLoadingPosts = false;
          });
        }

        // Cache posts asynchronously for faster future loads (first page only)
        if (_currentPage == 2) {
          CacheService().cachePosts(newPosts);
        }

        // Prefetch next page in background if there are more posts
        if (_hasMorePosts && _currentPage <= 3) {
          _prefetchNextPage();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPosts = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _hasPostLoadError = true;
          _postLoadErrorMessage = e.toString();
        });
      }
    }
  }

  // Load top posts from user's followers
  Future<void> _loadTopPosts() async {
    if (_isLoadingTopPosts) return;

    setState(() {
      _isLoadingTopPosts = true;
    });

    try {
      final result = await ApiService.getTopFollowerPosts(limit: 5);

      if (result['success'] == true && mounted) {
        final posts = result['data']['posts'] as List;
        setState(() {
          _topPosts = posts;
          _isLoadingTopPosts = false;
          _hasAttemptedTopPosts = true; // Mark as attempted
        });
      } else {
        setState(() {
          _isLoadingTopPosts = false;
          _hasAttemptedTopPosts = true; // Mark as attempted even on failure
        });
      }
    } catch (e) {
      AppLogger.e('Error loading top posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingTopPosts = false;
          _hasAttemptedTopPosts = true; // Mark as attempted even on error
        });
      }
    }
  }

  // Load profile visitor statistics
  Future<void> _loadVisitorStats() async {
    if (_isLoadingVisitorStats) return;

    setState(() {
      _isLoadingVisitorStats = true;
    });

    try {
      final result = await ApiService.getProfileVisitorStats();

      if (result['success'] == true && mounted) {
        setState(() {
          _visitorStats = result['data'];
          _isLoadingVisitorStats = false;
        });
        AppLogger.d('👀 Visitor stats loaded: ${_visitorStats?['stats']}');
      } else {
        setState(() {
          _isLoadingVisitorStats = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading visitor stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingVisitorStats = false;
        });
      }
    }
  }

  // Prefetch next page of posts in the background
  Future<void> _prefetchNextPage() async {
    try {
      AppLogger.d('🔄 Prefetching next page: $_currentPage');
      final result = await ApiService.getPosts(page: _currentPage, limit: 10);

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> prefetchedPosts = result['data']['posts'];
        await CacheService().prefetchPosts(prefetchedPosts);
        AppLogger.d('✅ Prefetched ${prefetchedPosts.length} posts');
      }
    } catch (e) {
      AppLogger.w('⚠️ Prefetch failed (non-critical): $e');
      // Fail silently - prefetching is not critical
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _posts = [];
      _currentPage = 1;
      _hasMorePosts = true;
      _hasPostLoadError = false;
      _postLoadErrorMessage = null;
      _hasAttemptedTopPosts = false; // Reset flag to allow reload
    });
    await Future.wait([
      _loadPosts(),
      _loadTopPosts(), // Also refresh top posts
    ]);
  }

  Future<void> _loadNotifications() async {
    if (_isLoadingNotifications) return;

    setState(() {
      _isLoadingNotifications = true;
    });

    try {
      final result = await ApiService.getNotifications(page: 1, limit: 50)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Request timed out. Please check your connection.'
          };
        },
      );

      if (result['success'] == true && result['data'] != null) {
        final notifications = result['data']['notifications'] ?? [];

        // Sort notifications by createdAt in descending order (newest first)
        if (notifications is List) {
          notifications.sort((a, b) {
            try {
              final aDate = DateTime.parse(a['createdAt'] ?? '');
              final bDate = DateTime.parse(b['createdAt'] ?? '');
              return bDate.compareTo(aDate); // Descending order (newest first)
            } catch (e) {
              return 0; // Keep original order if parsing fails
            }
          });
        }

        if (mounted) {
          setState(() {
            _notifications = notifications;
            _isLoadingNotifications = false;
          });
        }

        // Cache the notifications asynchronously (non-blocking)
        CacheService().cacheNotifications(notifications);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingNotifications = false;
          });

          // Log the error for debugging
          AppLogger.e('Failed to load notifications: ${result['message']}');
          
          // Only show error to user if it's not a generic message
          // This prevents spamming users with error messages on every login
          if (result['message'] != null && 
              !result['message'].toString().contains('Failed to load notifications')) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  result['message'] ?? 'Failed to load notifications',
                ),
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.e('Exception loading notifications: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
        });

        // Only show error for unexpected exceptions
        // Skip showing errors for network issues during initial load
        if (e.toString().contains('SocketException') || 
            e.toString().contains('TimeoutException')) {
          AppLogger.w('Network error loading notifications, will retry later');
        } else {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await ApiService.getUnreadNotificationCount();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _unreadNotificationCount = result['data']['unreadCount'] ?? 0;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading unread notification count: $e');
    }
  }

  Future<void> _loadUnreadMessageCount() async {
    try {
      final result = await MessagingService.getConversations();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _unreadMessageCount = result['data']['totalUnread'] ?? 0;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading unread message count: $e');
    }
  }

  Future<void> _loadStories() async {
    if (_isLoadingStories) return;

    setState(() {
      _isLoadingStories = true;
    });

    try {
      final result = await ApiService.getStories();

      if (result['success'] == true && result['data'] != null) {
        final stories = result['data']['stories'] ?? [];

        if (mounted) {
          setState(() {
            _stories = stories;
            _isLoadingStories = false;
          });
        }

        // Cache stories asynchronously (non-blocking)
        CacheService().cacheStories(stories);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStories = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStories = false;
        });
      }
    }
  }

  Future<void> _loadOnlineUsersCount() async {
    if (_isLoadingOnlineUsersCount) return;

    setState(() {
      _isLoadingOnlineUsersCount = true;
    });

    try {
      final count = await ApiService.getOnlineUsersCount();
      if (mounted) {
        setState(() {
          _onlineUsersCount = count;
          _isLoadingOnlineUsersCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOnlineUsersCount = false;
        });
      }
      AppLogger.e('Error loading online users count: $e');
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchedUsers = [];
        _searchedPosts = [];
        _searchedVideos = [];
        _searchedStories = [];
        _searchedSavedPosts = [];
        _isSearchingUsers = false;
        _isSearchingPosts = false;
        _isSearchingVideos = false;
        _isSearchingStories = false;
        _isSearchingSavedPosts = false;
      });
      // Load suggested users if the user is brand new (not following anyone)
      if ((_currentUser?['followingCount'] ?? 0) == 0 &&
          _suggestedUsers.isEmpty) {
        _loadSuggestedUsers();
      }
      return;
    }

    // Debounce search - wait 300ms after user stops typing for faster response
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _loadSuggestedUsers() async {
    if (_isLoadingSuggestedUsers) return;

    setState(() {
      _isLoadingSuggestedUsers = true;
    });

    try {
      final result = await ApiService.getSuggestedUsers(limit: 5);

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _suggestedUsers = result['data']['users'] ?? [];
          _isLoadingSuggestedUsers = false;
        });
      } else {
        setState(() {
          _isLoadingSuggestedUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingSuggestedUsers = false;
      });
      AppLogger.e('Error loading suggested users: $e');
    }
  }

  Future<void> _loadTopUsers() async {
    if (_isLoadingTopUsers) return;

    setState(() {
      _isLoadingTopUsers = true;
    });

    try {
      final result = await ApiService.getTopUsers(limit: 5);
      AppLogger.d('🔍 Top users API response: ${result['success']}');
      AppLogger.d('📊 Top users data: ${result['data']}');

      if (result['success'] == true && result['data'] != null) {
        final users = result['data']['users'] ?? [];
        AppLogger.d('👥 Loaded ${users.length} top users');
        if (users.isNotEmpty) {
          AppLogger.d('👤 First user: ${users[0]}');
          AppLogger.d('🖼️  Avatar URL: ${users[0]['avatar']}');
        }
        
        setState(() {
          _topUsers = users;
          _isLoadingTopUsers = false;
          _hasAttemptedTopUsers = true; // Mark as attempted
        });
      } else {
        setState(() {
          _isLoadingTopUsers = false;
          _hasAttemptedTopUsers = true; // Mark as attempted even on failure
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTopUsers = false;
        _hasAttemptedTopUsers = true; // Mark as attempted even on error
      });
      AppLogger.e('❌ Error loading top users: $e');
    }
  }

  // Helper methods to convert filter/sort enums to API parameter strings
  String _getFilterString(FeedFilterType filter) {
    switch (filter) {
      case FeedFilterType.all:
        return 'all';
      case FeedFilterType.following:
        return 'following';
      case FeedFilterType.trending:
        return 'trending';
      case FeedFilterType.recent:
        return 'recent';
    }
  }

  String _getSortString(FeedSortType sort) {
    switch (sort) {
      case FeedSortType.newest:
        return 'newest';
      case FeedSortType.mostLiked:
        return 'mostLiked';
      case FeedSortType.mostCommented:
        return 'mostCommented';
      case FeedSortType.trending:
        return 'trending';
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Save to search history
    await _saveSearchToHistory(query.trim());

    setState(() {
      _isSearchingUsers = true;
      _isSearchingPosts = true;
      _isSearchingVideos = true;
      _isSearchingStories = true;
      _isSearchingSavedPosts = true;
    });

    // Search users, posts, videos, stories, and saved posts in parallel
    try {
      final results = await Future.wait([
        ApiService.searchUsers(query: query, limit: 20),
        ApiService.searchPosts(query: query, limit: 20),
        ApiService.searchVideos(query: query, limit: 20),
        ApiService.searchStories(query: query), // Limit fixed at 20 on backend
        ApiService.searchSavedPosts(query: query, limit: 20),
      ]);

      final usersResult = results[0];
      final postsResult = results[1];
      final videosResult = results[2];
      final storiesResult = results[3];
      final savedPostsResult = results[4];

      setState(() {
        _searchedUsers =
            usersResult['success'] == true && usersResult['data'] != null
                ? (usersResult['data']['users'] ?? [])
                : [];
        _searchedPosts =
            postsResult['success'] == true && postsResult['data'] != null
                ? (postsResult['data']['posts'] ?? [])
                : [];
        _searchedVideos =
            videosResult['success'] == true && videosResult['data'] != null
                ? (videosResult['data']['videos'] ?? [])
                : [];
        _searchedStories =
            storiesResult['success'] == true && storiesResult['data'] != null
                ? (storiesResult['data']['stories'] ?? [])
                : [];
        _searchedSavedPosts = savedPostsResult['success'] == true &&
                savedPostsResult['data'] != null
            ? (savedPostsResult['data']['posts'] ?? [])
            : [];
        _isSearchingUsers = false;
        _isSearchingPosts = false;
        _isSearchingVideos = false;
        _isSearchingStories = false;
        _isSearchingSavedPosts = false;
      });
    } catch (e) {
      setState(() {
        _isSearchingUsers = false;
        _isSearchingPosts = false;
        _isSearchingVideos = false;
        _isSearchingStories = false;
        _isSearchingSavedPosts = false;
      });
    }
  }

  // Search History Methods
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      AppLogger.e('Error loading search history: $e');
    }
  }

  Future<void> _saveSearchToHistory(String query) async {
    try {
      // Don't save empty or duplicate (most recent) queries
      if (query.isEmpty ||
          (_searchHistory.isNotEmpty && _searchHistory.first == query)) {
        return;
      }

      // Remove if exists elsewhere in history
      _searchHistory.remove(query);

      // Add to beginning
      _searchHistory.insert(0, query);

      // Keep only last _maxSearchHistory items
      if (_searchHistory.length > _maxSearchHistory) {
        _searchHistory = _searchHistory.sublist(0, _maxSearchHistory);
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);

      setState(() {});
    } catch (e) {
      debugPrint('Error saving search to history: $e');
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
      setState(() {
        _searchHistory = [];
      });
    } catch (e) {
      debugPrint('Error clearing search history: $e');
    }
  }

  void _rerunSearch(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
    await _loadUnreadCount();
  }

  Future<void> _markAllAsRead() async {
    try {
      final result = await ApiService.markAllNotificationsAsRead();
      if (result['success'] == true) {
        setState(() {
          // Create new map instances instead of mutating existing ones
          // This ensures Flutter detects the change and rebuilds the widgets
          _notifications = _notifications.map((notification) {
            return Map<String, dynamic>.from(notification)..['isRead'] = true;
          }).toList();
          _unreadNotificationCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read if unread
    if (notification['isRead'] != true) {
      await ApiService.markNotificationAsRead(notification['_id']);
      setState(() {
        // Find and update the notification in the list with a new map instance
        final index = _notifications.indexWhere(
          (n) => n['_id'] == notification['_id'],
        );
        if (index != -1) {
          _notifications[index] = Map<String, dynamic>.from(_notifications[index])
            ..['isRead'] = true;
        }
        // NOTE: Don't decrement count here! The server will send 'notification:unread-count'
        // event with the updated count. This ensures consistency with server state.
      });
    }

    final notificationType = notification['type'] as String?;

    if (!mounted) return;

    // Handle poke notifications
    if (notificationType == 'poke') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PokesPage()),
      );
      return;
    }

    // Handle club invite notifications (clubs feature removed)
    if (notificationType == 'club_invite') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Club feature is currently disabled'),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        ),
      );
      return;
    }

    // Handle follow notifications - navigate to user profile
    if (notificationType == 'follow') {
      final sender = notification['sender'];
      if (sender != null && sender is Map<String, dynamic>) {
        final senderId = sender['_id'] ?? sender['id'];
        if (senderId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: senderId.toString()),
            ),
          );
          return;
        }
      }
    }

    // Handle video-related notifications
    if (notificationType == 'video_like' ||
        notificationType == 'video_comment' ||
        notificationType == 'video_tag' ||
        notificationType == 'video_comment_reaction') {
      String? videoId;
      if (notification['relatedVideo'] != null) {
        videoId = notification['relatedVideo'] is String
            ? notification['relatedVideo']
            : notification['relatedVideo']['_id'];
      }

      if (videoId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideosPage(initialVideoId: videoId),
          ),
        );
        return;
      }
    }

    // Handle message-related notifications (including story replies)
    if (notificationType == 'message' || notificationType == 'story_reaction') {
      // Get sender information
      final sender = notification['sender'];
      if (sender != null && sender is Map<String, dynamic>) {
        final senderId = sender['_id'] ?? sender['id'];
        if (senderId == null) {
          return;
        }

        try {
          final conversationResult = await ApiService.getOrCreateConversation(
            senderId.toString(),
          );

          if (conversationResult['success'] == true && mounted) {
            final data = conversationResult['data'];
            if (data == null || data is! Map<String, dynamic>) {
              throw Exception('Invalid response data');
            }

            final conversation = data['conversation'];
            if (conversation == null || conversation is! Map<String, dynamic>) {
              throw Exception('Invalid conversation data');
            }

            final conversationId = conversation['_id'];
            // Backend returns otherUser, not otherParticipant
            final otherUser = conversation['otherUser'];

            if (conversationId == null) {
              throw Exception('Conversation ID is missing');
            }

            if (otherUser == null || otherUser is! Map<String, dynamic>) {
              throw Exception('Other user data is missing');
            }

            debugPrint(
              '✅ Navigating to chat: $conversationId with user: ${otherUser['name']}',
            );

            // Navigate to chat page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  conversationId: conversationId,
                  otherUser: otherUser,
                ),
              ),
            );
            return;
          } else {
            debugPrint('❌ API call failed: ${conversationResult['message']}');
            throw Exception(
              conversationResult['message'] ?? 'Failed to get conversation',
            );
          }
        } catch (e) {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Failed to open chat: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
            );
          }
        }
      }
      return;
    }

    // Handle story notifications
    if (notificationType == 'story') {
      final sender = notification['sender'];
      if (sender != null && sender is Map<String, dynamic>) {
        final senderId = sender['_id'] ?? sender['id'];
        if (senderId != null) {
          // Navigate to user profile to view their story
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: senderId.toString()),
            ),
          );
          return;
        }
      }
    }

    // Navigate to the related post if applicable
    if (notification['post'] != null) {
      // Get post ID from notification
      String? postId;
      if (notification['post'] is String) {
        postId = notification['post'];
      } else if (notification['post'] is Map) {
        postId = notification['post']['_id'];
      }

      if (postId != null && mounted) {
        // Navigate to post detail page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(postId: postId!),
          ),
        );
        return;
      }
    }

    // For moderation actions and other types without specific navigation,
    // we've already marked as read, so just do nothing
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final result = await ApiService.deleteNotification(notificationId);
      if (result['success'] == true) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['_id'] == notificationId,
          );
          if (index != -1) {
            _notifications.removeAt(index);
            // NOTE: Don't decrement count here! If the notification was unread,
            // the backend will recalculate and send updated 'notification:unread-count'.
          }
        });
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.clearAllNotifications ??
            'Clear All Notifications'),
        content: Text(
          AppLocalizations.of(context)?.areYouSureClearNotifications ??
              'Are you sure you want to clear all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.clearAll ?? 'Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.deleteAllNotifications();
      if (result['success'] == true) {
        setState(() {
          // Create a new empty list instead of clearing to ensure Flutter detects the change
          _notifications = [];
          _unreadNotificationCount = 0;
        });

        // Clear cached notifications
        final cacheService = CacheService();
        await cacheService.cacheNotifications([]);

        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations?.allNotificationsCleared ??
                  'All notifications cleared'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ??
                    localizations?.errorOccurred ??
                    'Failed to clear notifications',
              ),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final localizations = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(localizations?.errorClearingNotifications ??
                'An error occurred while clearing notifications'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildNotificationIcon(bool isActive) {
    return Stack(
      children: [
        Icon(
          isActive ? Icons.notifications : Icons.notifications_outlined,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadNotificationCount > 99
                    ? '99+'
                    : '$_unreadNotificationCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageIcon(bool isActive) {
    return Stack(
      children: [
        Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline),
        if (_unreadMessageCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showCommentsBottomSheet(String postId, int commentsCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheetEnhanced(
        postId: postId,
        initialCommentsCount: commentsCount,
        onCommentAdded: () {
          // Refresh the post to get updated comment count
          _refreshSinglePost(postId);
        },
      ),
    );
  }

  void _showPostReactionsViewer(
    String postId,
    Map<String, dynamic> reactionsSummary,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Import PostReactionsViewer if not already imported
        return PostReactionsViewer(
          postId: postId,
          reactionsSummary: reactionsSummary,
        );
      },
    );
  }

  void _showShareDialog({
    required String postId,
    required String userName,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Share Post',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            const Divider(),

            // Share via other apps
            ListTile(
              leading: Icon(
                Icons.share,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                  AppLocalizations.of(context)?.shareVia ?? 'Share via...'),
              subtitle: Text(AppLocalizations.of(context)?.sharePostUsingApps ??
                  'Share this post using other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareViaApps(
                  userName: userName,
                  content: content,
                  postId: postId,
                );
              },
            ),

            // Copy link
            ListTile(
              leading: Icon(
                Icons.link,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title:
                  Text(AppLocalizations.of(context)?.copyLink ?? 'Copy Link'),
              subtitle: Text(AppLocalizations.of(context)?.copyPostLink ??
                  'Copy post link to clipboard'),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(postId);
              },
            ),

            // Copy text
            ListTile(
              leading: Icon(
                Icons.content_copy,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title:
                  Text(AppLocalizations.of(context)?.copyText ?? 'Copy Text'),
              subtitle: Text(AppLocalizations.of(context)?.copyPostContent ??
                  'Copy post content to clipboard'),
              onTap: () {
                Navigator.pop(context);
                _copyPostText(content);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareViaApps({
    required String userName,
    required String content,
    required String postId,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final shareText = '''
Check out this post by $userName on FreeTalk:

"$content"

View post: ${ApiService.baseApi}/posts/$postId
      '''
          .trim();

      await Share.share(shareText, subject: 'Post by $userName on FreeTalk');
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                '${localizations?.failedToShare ?? 'Failed to share'}: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  void _copyPostText(String content) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final localizations = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(localizations?.postTextCopiedToClipboard ??
              'Post text copied to clipboard!'),
          duration: const Duration(seconds: 2),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
    }
  }

  // Show quick menu with access to Events and other features
  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Quick Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              const Divider(),

              // Events option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.events ?? 'Events',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    AppLocalizations.of(context)?.discoverAndCreateEvents ??
                        'Discover and create events'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsListPage(),
                    ),
                  );
                },
              ),


              // Games option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sports_esports,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                title: const Text(
                  'Games',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Play & Win'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GamesListPage(),
                    ),
                  );
                },
              ),

              // Saved Posts option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bookmark,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.savedPosts ?? 'Saved Posts',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    AppLocalizations.of(context)?.viewBookmarkedPosts ??
                        'View your bookmarked posts'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedPostsPage(),
                    ),
                  );
                },
              ),

              // Profile Visitors option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.visibility,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.profileVisitors ??
                      'Profile Visitors',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    AppLocalizations.of(context)?.seeWhoViewedProfile ??
                        'See who viewed your profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileVisitorsPage(),
                    ),
                  );
                },
              ),

              // Jobs option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.work,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.jobs ?? 'Jobs',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(AppLocalizations.of(context)?.findAndPostJobs ??
                    'Find and post job opportunities'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JobsListPage(),
                    ),
                  );
                },
              ),

              // Marketplace option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text(
                  'Marketplace',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Buy and sell items'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MarketplaceListingsPage(),
                    ),
                  );
                },
              ),

              // Pokes option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.pokes ?? 'Pokes',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    AppLocalizations.of(context)?.viewPokesReceived ??
                        'View pokes you received'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PokesPage(),
                    ),
                  );
                },
              ),

              // Crisis Response option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.crisisSupport ??
                      'Crisis Response',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    AppLocalizations.of(context)?.getHelpOrOfferSupport ??
                        'Get help or offer support'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CrisisResponsePage(),
                    ),
                  );
                },
              ),

              // Premium Subscription option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.tertiary,
                        Theme.of(context).colorScheme.tertiaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.premium ?? 'Premium',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(AppLocalizations.of(context)?.upgradeToPremium ??
                    'Upgrade to Premium'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumSubscriptionPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Show edit profile dialog
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentUser?['name']);
    final emailController = TextEditingController(text: _currentUser?['email']);
    final bioController = TextEditingController(
      text: _currentUser?['bio'] ?? '',
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final screenSize = MediaQuery.of(dialogContext).size;
          final isSmallScreen = screenSize.width < 600;
          final dialogWidth = isSmallScreen
              ? screenSize.width * 0.9
              : (screenSize.width < 900 ? screenSize.width * 0.7 : 500.0);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.85,
                maxWidth: 600,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: Theme.of(context).primaryColor,
                          size: isSmallScreen ? 24 : 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name Field
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              hintText: 'Enter your name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person_rounded),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                            ),
                            enabled: !isSaving,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Email Field
                          TextField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.email_rounded),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isSaving,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Bio Field
                          TextField(
                            controller: bioController,
                            decoration: InputDecoration(
                              labelText: 'Bio',
                              hintText: 'Tell us about yourself...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.info_rounded),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                              helperText:
                                  '${bioController.text.length}/150 characters',
                              alignLabelWithHint: true,
                            ),
                            maxLines: isSmallScreen ? 3 : 4,
                            maxLength: 150,
                            enabled: !isSaving,
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              setDialogState(() {}); // Update character count
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 24,
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameController.text.trim();
                                  final email = emailController.text.trim();
                                  final bio = bioController.text.trim();

                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Name cannot be empty'),
                                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  if (email.isEmpty || !email.contains('@')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Please enter a valid email'),
                                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);

                                  try {
                                    final result =
                                        await ApiService.updateProfile(
                                      name: name,
                                      email: email,
                                      bio: bio.isEmpty ? '' : bio,
                                    );

                                    if (result['success'] == true && 
                                        result['data'] != null && 
                                        result['data']['user'] != null && 
                                        mounted) {
                                      // Update local user data
                                      setState(() {
                                        _currentUser = result['data']['user'];
                                        // Ensure bio field exists, even if empty
                                        if (_currentUser!['bio'] == null) {
                                          _currentUser!['bio'] = '';
                                        }
                                      });

                                      // Cache the updated profile
                                      CacheService()
                                          .cacheUserProfile(_currentUser!);

                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                                                const SizedBox(width: 8),
                                                const Text(
                                                    'Profile updated successfully!'),
                                              ],
                                            ),
                                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }

                                      // Reload profile to ensure consistency
                                      _loadUserProfile();
                                    } else {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(dialogContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              result['message'] ??
                                                  'Failed to update profile',
                                            ),
                                            backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Error: ${e.toString()}'),
                                          backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 20 : 28,
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 20),
                          label: Text(isSaving ? 'Saving...' : 'Save'),
                        ),
                      ],
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

  Future<void> _refreshSinglePost(String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          final postIndex = _posts.indexWhere((p) => p['_id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex] = result['data']['post'];
          }
        });
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  void _openImageFullscreen(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageFullscreenViewer(
          images: images.map((img) => UrlUtils.getFullImageUrl(img)).toList(),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showPostSettings(BuildContext context, String postId, String authorId) {
    final currentUserId = _currentUser?['_id'];
    final isOwner = currentUserId == authorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Edit option (only for post owner)
            if (isOwner)
              ListTile(
                leading: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title:
                    Text(AppLocalizations.of(context)?.editPost ?? 'Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  _handleEditPost(postId);
                },
              ),

            // Save/Bookmark option
            ListTile(
              leading: Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.tertiary),
              title:
                  Text(AppLocalizations.of(context)?.savePost ?? 'Save Post'),
              onTap: () {
                Navigator.pop(context);
                _handleSavePost(postId);
              },
            ),

            // Share option
            ListTile(
              leading: Icon(Icons.share, color: Theme.of(context).colorScheme.primary),
              title:
                  Text(AppLocalizations.of(context)?.sharePost ?? 'Share Post'),
              onTap: () {
                Navigator.pop(context);
                _handleSharePost(postId);
              },
            ),

            // Copy Link option
            ListTile(
              leading: Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
              title:
                  Text(AppLocalizations.of(context)?.copyLink ?? 'Copy Link'),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(postId);
              },
            ),

            // Report option (only for other users' posts)
            if (!isOwner)
              ListTile(
                leading: Icon(Icons.flag, color: Theme.of(context).colorScheme.tertiary),
                title: Text(
                    AppLocalizations.of(context)?.reportPost ?? 'Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _handleReportPost(postId);
                },
              ),

            // Delete option (only for post owner)
            if (isOwner)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text(
                  AppLocalizations.of(context)?.deletePost ?? 'Delete Post',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost(postId);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPostLink(String postId) async {
    // In a real app, this would be the actual URL
    final postLink = '${AppConfig.webBaseUrl}/post/$postId';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await Clipboard.setData(ClipboardData(text: postLink));

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)?.linkCopiedToClipboard ??
                    'Link copied to clipboard'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                '${localizations?.failedToCopyLink ?? 'Failed to copy link'}: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deletePost ?? 'Delete Post'),
        content: Text(
          AppLocalizations.of(context)?.areYouSureDeletePost ??
              'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleDeletePost(postId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeletePost(String postId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Show loading
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text(AppLocalizations.of(context)?.deletingPost ??
                    'Deleting post...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final result = await ApiService.deletePost(postId);

      // Hide loading snackbar
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();

      if (result['success'] == true) {
        // Remove post from all lists
        setState(() {
          _posts.removeWhere((post) => post['_id'] == postId);
          _userPosts.removeWhere((post) => post['_id'] == postId);
          _searchedPosts.removeWhere((post) => post['_id'] == postId);
        });

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.postDeleted ??
                  'Post deleted successfully'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(result['message'] ??
                  AppLocalizations.of(context)?.deleteFailed ??
                  'Failed to delete post'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.error ?? 'Error'}: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _handleEditPost(String postId) async {
    // Find the post to edit - check both main feed and user posts
    Map<String, dynamic> post = _posts.firstWhere(
      (p) => p['_id'] == postId,
      orElse: () => {},
    );

    // If not in main feed, check user posts (profile page)
    if (post.isEmpty) {
      post = _userPosts.firstWhere((p) => p['_id'] == postId, orElse: () => {});
    }

    // If still not found, check searched posts
    if (post.isEmpty) {
      post = _searchedPosts.firstWhere(
        (p) => p['_id'] == postId,
        orElse: () => {},
      );
    }

    if (post.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post not found'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
      return;
    }

    final TextEditingController editController = TextEditingController(
      text: post['content'] ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.editPost ?? 'Edit Post'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.typeMessage ??
                'What\'s on your mind?',
            border: const OutlineInputBorder(),
          ),
          maxLines: 5,
          maxLength: 5000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isEmpty) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)
                              ?.postContentCannotBeEmpty ??
                          'Post content cannot be empty'),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                  );
                }
                return;
              }

              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              if (dialogContext.mounted) {
                navigator.pop();
              }

              try {
                // Show loading
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(AppLocalizations.of(context)?.updatingPost ??
                              'Updating post...'),
                        ],
                      ),
                      duration: const Duration(seconds: 30),
                    ),
                  );
                }

                final result = await ApiService.editPost(postId, newContent);

                if (!mounted) return;
                scaffoldMessenger.hideCurrentSnackBar();

                if (result['success'] == true) {
                  // Update post in list
                  setState(() {
                    final index = _posts.indexWhere((p) => p['_id'] == postId);
                    if (index != -1) {
                      _posts[index]['content'] = newContent;
                    }

                    // Also update in user posts if present
                    final userPostIndex = _userPosts.indexWhere(
                      (p) => p['_id'] == postId,
                    );
                    if (userPostIndex != -1) {
                      _userPosts[userPostIndex]['content'] = newContent;
                    }
                  });

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)?.postUpdated ??
                          'Post updated successfully'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ??
                            AppLocalizations.of(context)?.updateFailed ??
                            'Failed to update post',
                      ),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.hideCurrentSnackBar();

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        '${AppLocalizations.of(context)?.error ?? 'Error'}: ${e.toString()}'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: Text(AppLocalizations.of(context)?.update ?? 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSavePost(String postId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Show loading
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Saving post...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final result = await ApiService.toggleSavePost(postId);

      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();

      if (result['success'] == true) {
        final saved = result['data']?['saved'] ?? false;

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Text(saved ? 'Post saved' : 'Post removed from saved'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save post'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  Future<void> _handleSharePost(String postId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Post',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.feed, color: Theme.of(context).colorScheme.tertiary),
                title: const Text('Share to Your Feed'),
                subtitle: const Text('All your followers will see this'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePostToFeed(postId);
                },
              ),
              ListTile(
                leading: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                title: const Text('Send to Followers'),
                subtitle: const Text('Share via direct message'),
                onTap: () {
                  Navigator.pop(context);
                  _showFollowerSelectionDialog(postId);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(context);
                  _copyPostLink(postId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePostToFeed(String postId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ApiService.sharePost(
        postId: postId,
        shareType: 'feed',
      );

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        final followerCount = result['data']?['followerCount'] ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post shared to $followerCount followers!'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _showFollowerSelectionDialog(String postId) async {
    try {
      // Get the current user's followers
      final followersResult = await ApiService.getUserFollowers(
        _currentUser?['_id'] ?? '',
      );

      if (!mounted) return;

      final followers = followersResult['data']?['followers'] as List? ?? [];

      if (followers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You have no followers to share with'),
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          ),
        );
        return;
      }

      // Show follower selection dialog
      final selectedFollowers = <String>{};
      final messageController = TextEditingController();

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Send to Followers'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Add a message (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select followers:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: followers.length,
                      itemBuilder: (context, index) {
                        final follower = followers[index];
                        final followerId = follower['_id'] as String;
                        final isSelected = selectedFollowers.contains(
                          followerId,
                        );

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedFollowers.add(followerId);
                              } else {
                                selectedFollowers.remove(followerId);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  follower['name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(follower['email'] ?? ''),
                          secondary: CircleAvatar(
                            backgroundImage: follower['avatar'] != null
                                ? UrlUtils.getAvatarImageProvider(
                                    follower['avatar'])
                                : null,
                            child: follower['avatar'] == null
                                ? Text(follower['name']?[0] ?? '?')
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedFollowers.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _sendPostToFollowers(
                          postId,
                          selectedFollowers.toList(),
                          messageController.text.trim(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text('Send (${selectedFollowers.length})'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load followers: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _sendPostToFollowers(
    String postId,
    List<String> recipients,
    String? message,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ApiService.sharePost(
        postId: postId,
        shareType: 'message',
        recipients: recipients,
        message: message,
      );

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        final recipientCount = result['data']?['recipientCount'] ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post sent to $recipientCount followers!'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send post: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _handleReportPost(String postId) async {
    String? selectedReason;
    final TextEditingController detailsController = TextEditingController();

    final reasons = {
      'spam': 'Spam',
      'harassment': 'Harassment or bullying',
      'hate_speech': 'Hate speech',
      'violence': 'Violence or dangerous content',
      'misinformation': 'False information',
      'inappropriate': 'Inappropriate content',
      'other': 'Other',
    };

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why are you reporting this post?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  onChanged: (value) {
                    setDialogState(() {
                      selectedReason = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: reasons.entries
                        .map(
                          (entry) => RadioListTile<String>(
                            title: Text(entry.value),
                            value: entry.key,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    hintText: 'Tell us more...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedReason == null) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: const Text('Please select a reason'),
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      ),
                    );
                  }
                  return;
                }

                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                if (dialogContext.mounted) {
                  navigator.pop();
                }

                try {
                  // Show loading
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Submitting report...'),
                          ],
                        ),
                        duration: Duration(seconds: 30),
                      ),
                    );
                  }

                  final result = await ApiService.reportPost(
                    postId: postId,
                    reason: selectedReason!,
                    details: detailsController.text.trim().isEmpty
                        ? null
                        : detailsController.text.trim(),
                  );

                  if (!mounted) return;
                  scaffoldMessenger.hideCurrentSnackBar();

                  if (result['success'] == true) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onErrorContainer),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Report submitted. Thank you for helping keep our community safe.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message'] ?? 'Failed to submit report',
                          ),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!mounted) return;
                  scaffoldMessenger.hideCurrentSnackBar();

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    // If user data was passed, use it temporarily while we fetch the complete profile
    if (widget.user != null) {
      setState(() {
        _currentUser = widget.user;
      });
      // Don't return - continue to fetch complete profile with stats
    }

    // Fetch complete profile from API (with stats)
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final result = await ApiService.getCurrentUser();

      if (result['success'] == true && result['data'] != null) {
        final userData = result['data']['user'];

        setState(() {
          _currentUser = userData;
          // Ensure bio field exists, even if null or empty
          if (_currentUser!['bio'] == null) {
            _currentUser!['bio'] = '';
          }
          _isLoadingProfile = false;
        });

        // Cache the user profile asynchronously
        CacheService().cacheUserProfile(userData);
      } else {
        throw Exception('Failed to load user profile');
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });

      // If we can't load the profile, redirect to login
      if (e is ApiException && e.statusCode == 401) {
        await ApiService.clearTokens();
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _loadUserPosts() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoadingUserPosts = true;
    });

    try {
      final userId = _currentUser!['_id'];
      final result = await ApiService.getUserPosts(userId: userId);

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _userPosts = result['data']['posts'] ?? [];
          _isLoadingUserPosts = false;
        });
      } else {
        setState(() {
          _isLoadingUserPosts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUserPosts = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      // Load user posts and visitor stats when opening Profile tab (index 4, was 5)
      if (index == 4) {
        _loadUserPosts();
        _loadVisitorStats();
      }

      // Reset unread message count when opening Messages tab (index 3)
      /*if (index == 3) {
        _unreadMessageCount = 0;
      }*/
    });
  }

  void _navigateToNotifications() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: _buildNotificationsPage(),
        ),
      ),
    ).then((_) {
      // Reset unread count when returning from notifications
      setState(() {
        _unreadNotificationCount = 0;
      });
    });
  }

  // Handle logout
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.logout ?? 'Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Pop the dialog first
              Navigator.pop(context);
              
              try {
                // Disconnect socket first
                SocketService().disconnect();
                
                // Call logout API (this will clear tokens internally)
                await ApiService.logout();
                
                // Clear local storage and cache (additional cleanup)
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // Verify both access and refresh tokens are cleared
                final accessToken = await ApiService.getAccessToken();
                final refreshToken = await ApiService.getRefreshToken();
                if (accessToken != null || refreshToken != null) {
                  AppLogger.w('⚠️ Tokens still exist after logout, forcing clear');
                  await ApiService.clearTokens();
                  // Double-check after forced clear
                  final accessToken2 = await ApiService.getAccessToken();
                  final refreshToken2 = await ApiService.getRefreshToken();
                  if (accessToken2 != null || refreshToken2 != null) {
                    AppLogger.e('❌ CRITICAL: Tokens still exist after forced clear!');
                  }
                }
                
                // Navigate to login page - use State's context after checking mounted
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  this.context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                AppLogger.e('Error during logout: $e');
                
                // Ensure tokens are cleared even on error
                try {
                  await ApiService.clearTokens();
                  await ApiService.clearRememberedCredentials();
                } catch (clearError) {
                  AppLogger.e('Error clearing tokens: $clearError');
                }
                
                // Still navigate to login page even if API call fails
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  this.context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.logout ?? 'Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while fetching user data
    if (_isLoadingProfile || _currentUser == null) {
      return Scaffold(body: _buildProfileLoadingShimmer());
    }
    final List<Widget> pages = [
      _buildFeedPage(),
      VideosPage(
        currentUser: _currentUser,
        key: const ValueKey('videos_page'),
        isVisible: _selectedIndex == 1,
      ),
      _buildSearchPage(),
      const ConversationsPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSocketConnected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isSocketConnected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline)
                      .withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Show refresh button only on home/feed page
          if (_selectedIndex == 0)
            IconButton(
                  icon: _isLoadingPosts
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    )
                  : Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
              onPressed: _isLoadingPosts
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final localizations = AppLocalizations.of(context);
                      final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
                      await _refreshPosts();
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                                const SizedBox(width: 12),
                                Text(localizations?.success ??
                                    'Feed refreshed!'),
                              ],
                            ),
                            backgroundColor: primaryContainerColor,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              tooltip:
                  AppLocalizations.of(context)?.refreshFeed ?? 'Refresh feed',
            ),
          // Logout button - accessible from all pages
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _handleLogout,
            tooltip: AppLocalizations.of(context)?.logout ?? 'Logout',
          ),
          // Notification Bell - accessible from all pages
          IconButton(
            icon: _buildNotificationIcon(false),
            onPressed: _navigateToNotifications,
            tooltip: AppLocalizations.of(context)?.notifications ?? 'Notifications',
          ),
          // Quick Menu button - accessible from all pages
          IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showQuickMenu,
            tooltip: AppLocalizations.of(context)?.quickMenu ?? 'Quick Menu',
          ),
          // Settings button removed from AppBar - now only in profile content area
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)?.home ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library_outlined),
            activeIcon: const Icon(Icons.video_library),
            label: AppLocalizations.of(context)?.videos ?? 'Videos',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: const Icon(Icons.search),
            label: AppLocalizations.of(context)?.search ?? 'Search',
          ),
          BottomNavigationBarItem(
            icon: _buildMessageIcon(false),
            activeIcon: _buildMessageIcon(true),
            label: AppLocalizations.of(context)?.messages ?? 'Messages',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: AppLocalizations.of(context)?.profile ?? 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: CreatePostBottomSheet(currentUser: _currentUser),
                  ),
                );

                // If post was created successfully, refresh the feed
                if (result == true) {
                  _refreshPosts();
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            )
          : null,
    );
  }

  Widget _buildFeedPage() {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context) * 2;
    final iconSize = ResponsiveDimensions.getIconSize(context);
    final captionSize = ResponsiveDimensions.getCaptionFontSize(context);

    return RefreshIndicator(
      onRefresh: () async {
        // Add haptic feedback for better UX
        HapticFeedback.mediumImpact();
        
        // Show visual feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Refreshing feed...'),
                ],
              ),
              duration: Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Perform refresh
        await _refreshPosts();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _posts.isEmpty 
                      ? 'No new posts' 
                      : 'Feed updated! ${_posts.length} posts',
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      color: Theme.of(context).colorScheme.primary,
      displacement: 60, // Pull distance before triggering
      strokeWidth: 3.0, // Thicker progress indicator
      edgeOffset: 0, // Distance from edge
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Feed Banner as SliverAppBar
          _buildFeedBannerAppBar(),
          // Offline indicator banner
          if (!_isSocketConnected)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(padding, spacing * 0.6, padding, 0),
                padding: EdgeInsets.symmetric(
                    horizontal: padding, vertical: spacing * 0.6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(
                      ResponsiveDimensions.getBorderRadius(context)),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      size: iconSize,
                    ),
                    SizedBox(width: spacing * 0.6),
                    Expanded(
                      child: Text(
                        'You\'re offline. Showing cached content.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                          fontSize: captionSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: spacing * 0.6),
                _buildStorySection(),
                SizedBox(height: spacing),
                // Online Users Count Widget
                _buildOnlineUsersCountWidget(),
                SizedBox(height: spacing),
                // Feed Filter and Sort Selector
                FeedFilterSelector(
                  selectedFilter: _selectedFeedFilter,
                  selectedSort: _selectedFeedSort,
                  onFilterChanged: (FeedFilterType newFilter) {
                    setState(() {
                      _selectedFeedFilter = newFilter;
                      _currentPage = 1;
                      _posts.clear();
                      _hasMorePosts = true;
                    });
                    _loadPosts();
                  },
                  onSortChanged: (FeedSortType newSort) {
                    setState(() {
                      _selectedFeedSort = newSort;
                      _currentPage = 1;
                      _posts.clear();
                      _hasMorePosts = true;
                    });
                    _loadPosts();
                  },
                ),
                SizedBox(height: spacing),
                // Suggested To Follow Section
                _buildSuggestedToFollowSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_posts.isEmpty && !_isLoadingPosts)
            SliverFillRemaining(
              hasScrollBody: false,
              child: FeedEmptyWidget(
                title: (_currentUser?['followingCount'] ?? 0) == 0
                    ? 'Your feed is empty'
                    : 'No posts yet',
                message: (_currentUser?['followingCount'] ?? 0) == 0
                    ? 'Follow some users to see their posts here!'
                    : 'Be the first to share something!',
                icon: (_currentUser?['followingCount'] ?? 0) == 0
                    ? Icons.people_outline
                    : Icons.article_outlined,
                actionLabel: (_currentUser?['followingCount'] ?? 0) == 0
                    ? 'Find Users'
                    : null,
                onAction: (_currentUser?['followingCount'] ?? 0) == 0
                    ? () {
                        setState(() {
                          _selectedIndex = 2;
                        });
                        if (_suggestedUsers.isEmpty) {
                          _loadSuggestedUsers();
                        }
                      }
                    : null,
              ),
            ),
          // Error state with retry button
          if (_posts.isEmpty && _hasPostLoadError && !_isLoadingPosts)
            SliverFillRemaining(
              hasScrollBody: false,
              child: FeedErrorWidget(
                icon: Icons.error_outline,
                title: 'Failed to Load Posts',
                message: _postLoadErrorMessage ?? 'An error occurred',
                onRetry: () async {
                  await _refreshPosts();
                },
              ),
            ),
          if (_posts.isEmpty && _isLoadingPosts)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FeedPostSkeleton(
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  childCount: 3,
                ),
              ),
            ),
          // Top posts from followers section (show when loading or when have posts)
          if ((_topPosts.isNotEmpty || _isLoadingTopPosts) && _posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.tertiary,
                                Theme.of(context).colorScheme.tertiaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.trending_up,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Top Posts from People You Follow',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (_isLoadingTopPosts)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Show loading shimmer for top posts or actual top posts
          if (_isLoadingTopPosts && _topPosts.isEmpty && _posts.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveDimensions.getHorizontalPadding(context)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            ResponsiveDimensions.getItemSpacing(context) * 2),
                    child: _buildPostLoadingShimmer(),
                  ),
                  childCount: 2,
                ),
              ),
            ),
          if (_topPosts.isNotEmpty && _posts.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveDimensions.getHorizontalPadding(context)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = _topPosts[index];
                    final postId = post['_id'] ?? '';
                    final author = post['author'] ?? {};
                    final authorId = author['_id'] ?? '';
                    final authorName = author['name'] ?? 'Unknown User';
                    final userAvatar = author['avatar'];
                    final content = post['content'] ?? '';
                    final likes =
                        post['likeCount'] ?? post['reactionsCount'] ?? 0;
                    final comments =
                        post['commentCount'] ?? post['commentsCount'] ?? 0;
                    final createdAt = post['createdAt'];
                    final timeAgo = _formatTimeAgo(createdAt);
                    final reactions = post['reactions'] != null
                        ? List<dynamic>.from(post['reactions'])
                        : [];
                    final reactionsSummary = post['reactionsSummary'] != null
                        ? Map<String, dynamic>.from(post['reactionsSummary'])
                        : <String, dynamic>{};
                    final currentUserId = _currentUser?['_id'];

                    String? userReaction;
                    if (currentUserId != null) {
                      for (var reaction in reactions) {
                        if (reaction['user'] == currentUserId ||
                            (reaction['user'] is Map &&
                                reaction['user']['_id'] == currentUserId)) {
                          userReaction = reaction['type'];
                          break;
                        }
                      }
                    }

                    final images = post['images'] != null
                        ? List<String>.from(post['images'])
                        : null;
                    final videos = post['videos'] != null
                        ? List<String>.from(post['videos'])
                        : null;
                    final taggedUsers = post['taggedUsers'] != null
                        ? List<Map<String, dynamic>>.from(post['taggedUsers'])
                        : null;

                    return Column(
                      children: [
                        Stack(
                          children: [
                            _buildPostCard(
                              postId: postId,
                              authorId: authorId,
                              userName: authorName,
                              userAvatar: userAvatar,
                              timeAgo: timeAgo,
                              content: content,
                              reactionsCount: likes,
                              comments: comments,
                              userReaction: userReaction,
                              reactionsSummary: reactionsSummary,
                              images: images,
                              videos: videos,
                              isShared: post['isShared'] == true,
                              sharedBy: post['sharedBy'],
                              shareMessage: post['shareMessage'],
                              taggedUsers: taggedUsers,
                              authorData: author,
                            ),
                            // Top post badge
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade600,
                                      Colors.orange.shade700,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Top ${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: ResponsiveDimensions.getItemSpacing(context) * 1.5,
                        ),
                      ],
                    );
                  },
                  childCount: _topPosts.length,
                ),
              ),
            ),
          // Divider between top posts and regular feed
          if (_topPosts.isNotEmpty && _posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveDimensions.getHorizontalPadding(context),
                  vertical: ResponsiveDimensions.getItemSpacing(context) * 0.5,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveDimensions.getHorizontalPadding(
                                  context) *
                              0.75),
                      child: Text(
                        'Latest Posts',
                        style: TextStyle(
                          fontSize:
                              ResponsiveDimensions.getBodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_posts.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveDimensions.getHorizontalPadding(context)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // Preemptive loading: start loading next page when 5 items from bottom
                  // Only trigger once per page load to avoid race conditions
                  if (_hasMorePosts &&
                      !_isLoadingPosts &&
                      index == _posts.length - 5 &&
                      index >= 0) {
                    Future.microtask(() => _loadPosts());
                  }

                  if (index < _posts.length) {
                    final post = _posts[index];
                    final postId = post['_id'] ?? '';
                    final author = post['author'] ?? {};
                    final authorId = author['_id'] ?? '';
                    final authorName = author['name'] ?? 'Unknown User';
                    final userAvatar = author['avatar'];

                    final content = post['content'] ?? '';
                    final likes =
                        post['likesCount'] ?? post['reactionsCount'] ?? 0;
                    final comments = post['commentsCount'] ?? 0;
                    final createdAt = post['createdAt'];
                    final timeAgo = _formatTimeAgo(createdAt);

                    // Get reactions and check if current user reacted
                    final reactions = post['reactions'] != null
                        ? List<dynamic>.from(post['reactions'])
                        : [];
                    final reactionsSummary = post['reactionsSummary'] != null
                        ? Map<String, dynamic>.from(post['reactionsSummary'])
                        : <String, dynamic>{};
                    final currentUserId = _currentUser?['_id'];

                    // Find user's reaction
                    String? userReaction;
                    if (currentUserId != null) {
                      for (var reaction in reactions) {
                        if (reaction['user'] == currentUserId ||
                            (reaction['user'] is Map &&
                                reaction['user']['_id'] == currentUserId)) {
                          userReaction = reaction['type'];
                          break;
                        }
                      }
                    }

                    // Backwards compatibility: check old likes array
                    if (userReaction == null && post['likes'] != null) {
                      final likesList = List<dynamic>.from(post['likes']);
                      if (currentUserId != null &&
                          likesList.contains(currentUserId)) {
                        userReaction = 'like';
                      }
                    }

                    // Get images and videos
                    final images = post['images'] != null
                        ? List<String>.from(post['images'])
                        : null;
                    final videos = post['videos'] != null
                        ? List<String>.from(post['videos'])
                        : null;

                    // Extract tagged users
                    final taggedUsers = post['taggedUsers'] != null
                        ? List<Map<String, dynamic>>.from(post['taggedUsers'])
                        : null;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: ResponsiveDimensions.getItemSpacing(context) * 1.5,
                      ),
                      child: _buildPostCard(
                        postId: postId,
                        authorId: authorId,
                        userName: authorName,
                        userAvatar: userAvatar,
                        timeAgo: timeAgo,
                        content: content,
                        reactionsCount: likes,
                        comments: comments,
                        userReaction: userReaction,
                        reactionsSummary: reactionsSummary,
                        images: images,
                        videos: videos,
                        isShared: post['isShared'] == true,
                        sharedBy: post['sharedBy'],
                        shareMessage: post['shareMessage'],
                        taggedUsers: taggedUsers,
                        authorData:
                            author, // Pass author data for verified badge
                      ),
                    );
                  }

                  // Loading more indicator - only show, don't trigger load here
                  // (load is already triggered by preemptive loading above)
                  if (index == _posts.length && _hasMorePosts) {
                    return Padding(
                      padding: EdgeInsets.all(
                          ResponsiveDimensions.getHorizontalPadding(context)),
                      child: _isLoadingPosts
                          ? FeedPostSkeleton(
                              isDark: Theme.of(context).brightness ==
                                  Brightness.dark,
                            )
                          : const SizedBox.shrink(),
                    );
                  }

                  // Show end reached message when no more posts
                  if (index == _posts.length &&
                      !_hasMorePosts &&
                      _posts.isNotEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: FeedEndReachedWidget(),
                    );
                  }

                  return const SizedBox.shrink();
                },
                    childCount: _posts.length +
                        (_hasMorePosts || _posts.isNotEmpty ? 1 : 0)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String? dateString) {
    // Use TimeUtils to format as YYYY/MM/DD HH:MM
    return TimeUtils.formatMessageTimestamp(dateString);
  }

  /// Build avatar widget for homepage posts - handles both network and local asset avatars (for bots)
  Widget _buildHomepageAvatarWidget({
    required String userName,
    required String? userAvatar,
    required Map<String, dynamic>? authorData,
  }) {
    final isBot = authorData?['isBot'] == true;

    if (isBot && userAvatar != null && UrlUtils.isLocalAsset(userAvatar)) {
      // Local asset (like bot avatars) - use Image widget with AssetImage
      return CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: ClipOval(
          child: Image.asset(
            userAvatar,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                userName.isNotEmpty
                    ? userName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join()
                        .toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Network image - use CircleAvatar with NetworkImage
      return CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        backgroundImage: userAvatar != null && userAvatar.isNotEmpty
            ? NetworkImage(UrlUtils.getFullAvatarUrl(userAvatar))
            : null,
        child: userAvatar == null || userAvatar.isEmpty
            ? Text(
                userName.isNotEmpty
                    ? userName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join()
                        .toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
      );
    }
  }

  // Build feed banner as SliverAppBar at the top
  Widget _buildFeedBannerAppBar() {
    final feedBannerUrl = _currentUser?['feedBannerPhoto'];
    final hasPhoto = feedBannerUrl != null && feedBannerUrl.isNotEmpty;
    final bannerHeight = ResponsiveDimensions.getFeedBannerHeight(context);
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final headingSize = ResponsiveDimensions.getHeadingFontSize(context);
    final iconSize = ResponsiveDimensions.getIconSize(context) * 1.2;

    return SliverAppBar(
      expandedHeight: bannerHeight,
      pinned: false,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner photo or gradient placeholder
            if (hasPhoto)
              CachedNetworkImage(
                imageUrl: UrlUtils.getFullImageUrl(feedBannerUrl),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading feed banner: $error');
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: iconSize * 1.5,
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: iconSize * 1.5,
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      ),
                      SizedBox(height: padding * 0.6),
                      Text(
                        'Add your feed banner',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: headingSize * 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
                    Colors.transparent,
                    Theme.of(context).colorScheme.shadow.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // "Home" text overlay at bottom
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Home',
                            style: TextStyle(
                              fontSize: headingSize,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.38),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Container(
                          padding: EdgeInsets.all(padding * 0.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(
                                ResponsiveDimensions.getBorderRadius(context)),
                          ),
                          child: Icon(
                            Icons.home,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: iconSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Edit/Add photo button
            Positioned(
              top: padding * 2.5,
              right: padding,
              child: SafeArea(
                child: _isUploadingFeedBanner
                    ? Container(
                        padding: EdgeInsets.all(padding * 0.6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: iconSize * 0.9,
                          height: iconSize * 0.9,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      )
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _uploadFeedBanner,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 0.8,
                              vertical: padding * 0.5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasPhoto
                                      ? Icons.edit
                                      : Icons.add_photo_alternate,
                                  size: iconSize * 0.75,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: padding * 0.3),
                                Text(
                                  hasPhoto ? 'Change' : 'Add Photo',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize:
                                        ResponsiveDimensions.getBodyFontSize(
                                            context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build feed banner section (visible only to the logged-in user)
  Widget _buildStorySection() {
    final storySize = ResponsiveDimensions.getStoryCircleSize(context);
    final containerHeight =
        storySize + ResponsiveDimensions.getItemSpacing(context) * 5;
    final padding = ResponsiveDimensions.getHorizontalPadding(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.symmetric(
          vertical: padding * 0.875, horizontal: padding * 0.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
            ResponsiveDimensions.getBorderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: containerHeight,
      child: _isLoadingStories
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                final storySize =
                    ResponsiveDimensions.getStoryCircleSize(context);
                final storyNameSize =
                    ResponsiveDimensions.getCaptionFontSize(context);
                final spacing = ResponsiveDimensions.getItemSpacing(context);

                return Padding(
                  padding: EdgeInsets.only(
                      right: spacing, left: index == 0 ? spacing / 2 : 0),
                    child: Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Container(
                          width: storySize,
                          height: storySize,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(height: spacing * 0.5),
                        Container(
                          width: storySize * 0.85,
                          height: storyNameSize * 0.8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stories.length + 1, // +1 for "Your Story"
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Your Story" - Add new story button
                  return _buildYourStoryCircle();
                } else {
                  // User stories
                  final userStory = _stories[index - 1];
                  final author = userStory['author'] as Map<String, dynamic>;
                  final stories = userStory['stories'] as List<dynamic>;
                  final hasUnseen = userStory['hasUnseen'] ?? false;

                  return _buildStoryCircle(
                    userId: author['_id'],
                    name: author['name'],
                    avatarUrl: author['avatar'],
                    hasUnseen: hasUnseen,
                    stories: stories,
                  );
                }
              },
            ),
    );
  }

  Widget _buildYourStoryCircle() {
    final storySize = ResponsiveDimensions.getStoryCircleSize(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);
    final nameSize = ResponsiveDimensions.getCaptionFontSize(context);
    final iconSize = storySize * 0.35;

    return GestureDetector(
      onTap: () async {
        // Navigate to create story page
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateStoryPage()),
        );

        // Reload stories if a story was created
        if (result == true && mounted) {
          _loadStories();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(right: spacing, left: spacing * 0.5),
        child: Column(
          children: [
            Container(
              width: storySize,
              height: storySize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Stack(
                children: [
                  // User avatar
                  ClipOval(
                    child: _currentUser?['avatar'] != null &&
                            _currentUser!['avatar'].toString().isNotEmpty
                        ? Image.network(
                            UrlUtils.getFullAvatarUrl(_currentUser!['avatar']),
                            width: storySize,
                            height: storySize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Text(
                                    _currentUser?['name']?.isNotEmpty == true
                                        ? _currentUser!['name'][0].toUpperCase()
                                        : 'Y',
                                    style: TextStyle(
                                      fontSize: storySize * 0.4,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                _currentUser?['name']?.isNotEmpty == true
                                    ? _currentUser!['name'][0].toUpperCase()
                                    : 'Y',
                                style: TextStyle(
                                  fontSize: storySize * 0.4,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Add button overlay
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: iconSize * 1.2,
                      height: iconSize * 1.2,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: iconSize * 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing * 0.4),
            Text(
              'Your Story',
              style: TextStyle(
                fontSize: nameSize,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCircle({
    required String userId,
    required String name,
    String? avatarUrl,
    required bool hasUnseen,
    required List<dynamic> stories,
  }) {
    final storySize = ResponsiveDimensions.getStoryCircleSize(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);
    final nameSize = ResponsiveDimensions.getCaptionFontSize(context);
    final borderWidth = storySize * 0.05;

    return GestureDetector(
      onTap: () async {
        // Navigate to story viewer
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerPage(
              userStories:
                  stories.map((s) => s as Map<String, dynamic>).toList(),
              initialIndex: 0,
            ),
          ),
        );

        // Reload stories after viewing (to update unseen status)
        if (mounted) {
          _loadStories();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(right: spacing),
        child: Column(
          children: [
            Container(
              width: storySize,
              height: storySize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnseen
                    ? const LinearGradient(
                        colors: [Colors.purple, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !hasUnseen
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), width: borderWidth)
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(storySize * 0.04),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(storySize * 0.025),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              UrlUtils.getFullAvatarUrl(avatarUrl),
                              width: storySize * 0.9,
                              height: storySize * 0.9,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        fontSize: storySize * 0.35,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: storySize * 0.35,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing * 0.4),
            SizedBox(
              width: storySize,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: nameSize,
                  color: Colors.grey.shade700,
                  fontWeight: hasUnseen ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineUsersCountWidget() {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final bodyFontSize = ResponsiveDimensions.getBodyFontSize(context);
    final iconSize = ResponsiveDimensions.getIconSize(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: spacing,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveDimensions.getBorderRadius(context),
        ),
        border: Border.all(
          color: Colors.blue.shade200.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(spacing * 0.6),
            decoration: BoxDecoration(
              color: Colors.green.shade400.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.circle,
              color: Colors.green.shade600,
              size: iconSize * 0.75,
            ),
          ),
          SizedBox(width: spacing),
          if (_isLoadingOnlineUsersCount)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade700,
                    ),
                  ),
                ),
                SizedBox(width: spacing * 0.75),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            )
          else
            Expanded(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(
                      text: '$_onlineUsersCount ',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: _onlineUsersCount == 1
                          ? 'user online'
                          : 'users online',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestedToFollowSection() {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final bodyFontSize = ResponsiveDimensions.getBodyFontSize(context);
    final subheadingFontSize =
        ResponsiveDimensions.getSubheadingFontSize(context);
    final iconSize = ResponsiveDimensions.getIconSize(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding:
                EdgeInsets.only(left: spacing * 0.5, bottom: spacing * 1.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        color: Colors.green.shade700, size: iconSize),
                    SizedBox(width: spacing),
                    Text(
                      'Suggested To Follow',
                      style: TextStyle(
                        fontSize: subheadingFontSize,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (_suggestedUsers.isNotEmpty && !_isLoadingSuggestedUsers)
                  TextButton.icon(
                    onPressed: _loadSuggestedUsers,
                    icon: Icon(Icons.refresh, size: iconSize * 0.75),
                    label: Text('Refresh',
                        style: TextStyle(fontSize: bodyFontSize * 0.85)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: spacing * 0.5),
                    ),
                  ),
              ],
            ),
          ),
          // Loading state
          if (_isLoadingSuggestedUsers && _suggestedUsers.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: spacing),
                    Text(
                      'Loading suggestions...',
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Suggested users list
          else if (_suggestedUsers.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedUsers.length,
                itemBuilder: (context, index) {
                  final user = _suggestedUsers[index];
                  return _buildSuggestedUserCard(user);
                },
              ),
            )
          // Empty state
          else
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                    ResponsiveDimensions.getBorderRadius(context)),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: iconSize * 1.5,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: spacing),
                  Text(
                    'No suggestions right now',
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestedUserCard(Map<String, dynamic> user) {
    final userId = user['_id'] ?? '';
    final userName = user['name'] ?? 'Unknown User';
    final userAvatar = user['avatar'];
    final userBio = user['bio'];
    // Be resilient to backend variations: prefer followersCount, fallback to followers array length
    final dynamic rawFollowersCount = user['followersCount'];
    final int followersCount = rawFollowersCount is int
        ? rawFollowersCount
        : (user['followers'] is List ? (user['followers'] as List).length : 0);
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'U';

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: userId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Avatar section
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: userAvatar == null || userAvatar.toString().isEmpty
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.green.shade300, Colors.blue.shade300],
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.transparent,
                  backgroundImage:
                      userAvatar != null && userAvatar.toString().isNotEmpty
                          ? UrlUtils.getAvatarImageProvider(userAvatar)
                          : null,
                  child: userAvatar == null || userAvatar.toString().isEmpty
                      ? Text(
                          userInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            // User info section
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Name with verification badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Bio or followers
                    if (userBio != null && userBio.toString().isNotEmpty)
                      Text(
                        userBio.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        '$followersCount followers',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
            // Follow button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.followUser(userId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Following $userName!'),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        // Reload suggested users
                        _loadSuggestedUsers();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Failed to follow user'),
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required String authorId,
    required String userName,
    required String? userAvatar,
    required String timeAgo,
    required String content,
    required int reactionsCount,
    required int comments,
    String? userReaction,
    Map<String, dynamic>? reactionsSummary,
    List<String>? images,
    List<String>? videos,
    bool isShared = false,
    Map<String, dynamic>? sharedBy,
    String? shareMessage,
    List<Map<String, dynamic>>? taggedUsers,
    Map<String, dynamic>? authorData, // For verified badge
  }) {
    // Get responsive dimensions
    final itemSpacing = ResponsiveDimensions.getItemSpacing(context);
    final borderRadius = ResponsiveDimensions.getBorderRadius(context);
    final imageHeight = ResponsiveDimensions.getPostImageHeight(context);
    final maxContentWidth = ResponsiveDimensions.getMaxContentWidth(context);
    final cardPadding = ResponsiveDimensions.getCardPadding(context);
    final bodyFontSize = ResponsiveDimensions.getBodyFontSize(context);
    final captionFontSize = ResponsiveDimensions.getCaptionFontSize(context);
    final shadowElevation = ResponsiveDimensions.getShadowElevation(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: shadowElevation * 2,
                offset: Offset(0, shadowElevation),
              ),
            ],
          ),
          child: ScaleBounceAnimation(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            autoStart: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Share attribution banner
                if (isShared && sharedBy != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(itemSpacing),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                      border:
                          Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: ResponsiveDimensions.getIconSize(context),
                        ),
                        SizedBox(width: itemSpacing * 0.67),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${sharedBy['name']} shared this post',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: captionFontSize,
                                ),
                              ),
                              if (shareMessage != null && shareMessage.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: itemSpacing * 0.33),
                                  child: Text(
                                    shareMessage,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                      fontSize: captionFontSize * 0.92,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: cardPadding,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Don't navigate if it's the current user's own post
                          if (authorId != _currentUser?['_id']) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfilePage(userId: authorId),
                              ),
                            );
                          }
                        },
                        child: _buildHomepageAvatarWidget(
                          userName: userName,
                          userAvatar: userAvatar,
                          authorData: authorData,
                        ),
                      ),
                      SizedBox(width: itemSpacing),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Don't navigate if it's the current user's own post
                            if (authorId != _currentUser?['_id']) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UserProfilePage(userId: authorId),
                                ),
                              );
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: ResponsiveDimensions.getSubheadingFontSize(context),
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: itemSpacing * 0.25),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: captionFontSize,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_horiz,
                          size: ResponsiveDimensions.getIconSize(context),
                        ),
                        onPressed: () =>
                            _showPostSettings(context, postId, authorId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(postId: postId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: cardPadding.horizontal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (content.isNotEmpty) ...[
                          Text(
                            content,
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              height: 1.5,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: itemSpacing * 0.67),
                        ],
                        // Tagged users
                        if (taggedUsers != null && taggedUsers.isNotEmpty) ...[
                          Wrap(
                            spacing: itemSpacing * 0.33,
                            runSpacing: itemSpacing * 0.33,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: ResponsiveDimensions.getIconSize(context) * 0.75,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              SizedBox(width: itemSpacing * 0.33),
                              Text(
                                'with ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: captionFontSize,
                                ),
                              ),
                              ...taggedUsers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final user = entry.value;
                                final isLast = index == taggedUsers.length - 1;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UserProfilePage(userId: user['_id']),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '${user['name']}${isLast ? '' : ', '}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: captionFontSize,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          SizedBox(height: itemSpacing * 0.67),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: itemSpacing),

                // Display images if available
                if (images != null && images.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      _openImageFullscreen(context, images, 0);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: images.length == 1
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(borderRadius * 0.5),
                                child: CachedNetworkImage(
                                  imageUrl: UrlUtils.getFullImageUrl(images[0]),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: ResponsiveDimensions.getLargeIconSize(context),
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : PageView.builder(
                                itemCount: images.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      _openImageFullscreen(context, images, index);
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(borderRadius * 0.5),
                                        child: CachedNetworkImage(
                                          imageUrl: UrlUtils.getFullImageUrl(images[index]),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey.shade200,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.blue.shade300,
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: ResponsiveDimensions.getLargeIconSize(context),
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: itemSpacing),
                ],

                // Display videos if available
                if (videos != null && videos.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: cardPadding.horizontal),
                    child: videos.length == 1
                        ? VideoPlayerWidget(
                            videoUrl: UrlUtils.getFullVideoUrl(videos[0]),
                          )
                        : VideoCarouselWidget(
                            videoUrls: videos,
                            onVideoChanged: () {
                              debugPrint('Video changed in carousel');
                            },
                          ),
                  ),
                  SizedBox(height: itemSpacing),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: cardPadding.horizontal),
                  child: Row(
                    children: [
                      if (reactionsCount > 0) ...[
                        Flexible(
                          child: InkWell(
                            onTap: () => _showPostReactionsViewer(
                              postId,
                              reactionsSummary ?? {},
                            ),
                            borderRadius: BorderRadius.circular(borderRadius * 0.75),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: itemSpacing * 0.33,
                                vertical: itemSpacing * 0.17,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildReactionsSummary(reactionsSummary ?? {}),
                                  SizedBox(width: itemSpacing * 0.33),
                                  Text(
                                    '$reactionsCount',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      fontSize: captionFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: itemSpacing),
                      ],
                      if (comments > 0)
                        Flexible(
                          child: Text(
                            '$comments comment${comments > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: captionFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: itemSpacing * 0.5),
                  child: Divider(
                    color: Theme.of(context).dividerColor,
                    height: 1,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cardPadding.horizontal,
                    vertical: itemSpacing * 0.67,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildReactionButton(
                        postId: postId,
                        userReaction: userReaction,
                      ),
                      _buildPostAction(
                        icon: Icons.chat_bubble_outline,
                        label: 'Comment',
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        onTap: () => _showCommentsBottomSheet(postId, comments),
                      ),
                      _buildPostAction(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        onTap: () => _showShareDialog(
                          postId: postId,
                          userName: userName,
                          content: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine what to show based on available width
          final availableWidth = constraints.maxWidth;
          final showTextLabel = availableWidth > 60;
          final usePadding = availableWidth > 40;

          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 8,
                horizontal: usePadding ? 4 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: availableWidth > 40 ? 18 : 16, color: color),
                  if (showTextLabel) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReactionsSummary(Map<String, dynamic> summary) {
    final Map<String, String> reactionEmojis = {
      'like': '👍',
      'celebrate': '🎉',
      'insightful': '💡',
      'funny': '😂',
      'mindblown': '🤯',
      'support': '🤝',
    };

    // Get top 3 reactions
    final List<MapEntry<String, int>> sortedReactions = summary.entries
        .where((e) => e.key != 'total' && (e.value is int) && e.value > 0)
        .map((e) => MapEntry(e.key, e.value as int))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topReactions = sortedReactions.take(3).toList();

    if (topReactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: topReactions.map((reaction) {
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Center(
            child: Text(
              reactionEmojis[reaction.key] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReactionButton({required String postId, String? userReaction}) {
    final Map<String, dynamic> reactionConfig = {
      'like': {'emoji': '👍', 'label': 'Like', 'color': Colors.blue},
      'celebrate': {
        'emoji': '🎉',
        'label': 'Celebrate',
        'color': Colors.purple,
      },
      'insightful': {
        'emoji': '💡',
        'label': 'Insightful',
        'color': Colors.amber.shade800,
      },
      'funny': {'emoji': '😂', 'label': 'Funny', 'color': Colors.orange},
      'mindblown': {
        'emoji': '🤯',
        'label': 'Mindblown',
        'color': Colors.deepPurple,
      },
      'support': {'emoji': '🤝', 'label': 'Support', 'color': Colors.green},
    };

    final hasReaction = userReaction != null;
    final currentConfig = hasReaction ? reactionConfig[userReaction] : null;

    return Flexible(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine what to show based on available width
          final availableWidth = constraints.maxWidth;
          final showTextLabel = availableWidth > 60;
          final usePadding = availableWidth > 40;

          return GestureDetector(
            onTap: () {
              // Tap behavior:
              // - No reaction or different than 'like' => set to 'like'
              // - Already 'like' => remove reaction
              if (userReaction == 'like') {
                _handleReaction(postId, null);
              } else {
                _handleReaction(postId, 'like');
              }
            },
            onLongPress: () {
              // Show reaction picker
              _showReactionPicker(postId, userReaction);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 8,
                horizontal: usePadding ? 4 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasReaction && currentConfig != null) ...[
                    Text(
                      currentConfig['emoji'],
                      style: TextStyle(fontSize: availableWidth > 40 ? 18 : 16),
                    ),
                    if (showTextLabel) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          currentConfig['label'],
                          style: TextStyle(
                            color: currentConfig['color'],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ] else ...[
                    Icon(
                      Icons.thumb_up_outlined,
                      size: availableWidth > 40 ? 18 : 16,
                      color: Colors.grey.shade700,
                    ),
                    if (showTextLabel) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Like',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReactionPicker(String postId, String? currentReaction) {
    ReactionPickerOverlay.show(
      context: context,
      postId: postId,
      currentReaction: currentReaction,
      onReactionSelected: (reactionType) {
        _handleReaction(postId, reactionType);
      },
    );
  }

  Future<void> _handleReaction(String postId, String? reactionType) async {
    final currentUserId = _currentUser?['_id'];
    if (currentUserId == null) return;

    // Find the post
    final postIndex = _posts.indexWhere((p) => p['_id'] == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    final reactions =
        post['reactions'] != null ? List<dynamic>.from(post['reactions']) : [];

    // Find user's current reaction
    final userReactionIndex = reactions.indexWhere(
      (r) =>
          r['user'] == currentUserId ||
          (r['user'] is Map && r['user']['_id'] == currentUserId),
    );

    final String? previousReaction =
        userReactionIndex >= 0 ? reactions[userReactionIndex]['type'] : null;

    // Optimistic update
    setState(() {
      if (reactionType == null) {
        // Remove reaction
        if (userReactionIndex >= 0) {
          final removedType = reactions[userReactionIndex]['type'];
          reactions.removeAt(userReactionIndex);

          // Ensure we're updating the actual post object
          _posts[postIndex]['reactions'] = reactions;
          _posts[postIndex]['reactionsCount'] =
              (post['reactionsCount'] ?? 1) - 1;
          _posts[postIndex]['likesCount'] = (post['likesCount'] ?? 1) - 1;

          // Update reactions summary
          if (post['reactionsSummary'] != null) {
            final summary = Map<String, dynamic>.from(post['reactionsSummary']);
            if (summary[removedType] != null && summary[removedType] > 0) {
              summary[removedType] = summary[removedType] - 1;
            }
            summary['total'] = (summary['total'] ?? 1) - 1;
            _posts[postIndex]['reactionsSummary'] = summary;
          }
        }
      } else {
        // Add or update reaction
        if (userReactionIndex >= 0) {
          // Update existing - change reaction type
          final oldType = reactions[userReactionIndex]['type'];
          reactions[userReactionIndex]['type'] = reactionType;

          // Update reactions summary
          if (post['reactionsSummary'] != null) {
            final summary = Map<String, dynamic>.from(post['reactionsSummary']);
            // Decrease old type
            if (summary[oldType] != null && summary[oldType] > 0) {
              summary[oldType] = summary[oldType] - 1;
            }
            // Increase new type
            summary[reactionType] = (summary[reactionType] ?? 0) + 1;
            _posts[postIndex]['reactionsSummary'] = summary;
          }
        } else {
          // Add new reaction
          reactions.add({
            'user': currentUserId,
            'type': reactionType,
            'createdAt': DateTime.now().toIso8601String(),
          });
          _posts[postIndex]['reactionsCount'] =
              (post['reactionsCount'] ?? 0) + 1;
          _posts[postIndex]['likesCount'] = (post['likesCount'] ?? 0) + 1;

          // Update reactions summary
          final summary = post['reactionsSummary'] != null
              ? Map<String, dynamic>.from(post['reactionsSummary'])
              : {
                  'like': 0,
                  'celebrate': 0,
                  'insightful': 0,
                  'funny': 0,
                  'mindblown': 0,
                  'support': 0,
                  'total': 0,
                };
          summary[reactionType] = (summary[reactionType] ?? 0) + 1;
          summary['total'] = (summary['total'] ?? 0) + 1;
          _posts[postIndex]['reactionsSummary'] = summary;
        }
        _posts[postIndex]['reactions'] = reactions;
      }
    });

    // Call API
    try {
      Map<String, dynamic> result;
      if (reactionType == null) {
        result = await ApiService.removeReaction(postId: postId);
      } else {
        result = await ApiService.addReaction(
          postId: postId,
          reactionType: reactionType,
        );
      }

      if (result['success'] != true) {
        // Revert on failure
        _revertReaction(postIndex, currentUserId, previousReaction);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update reaction'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      _revertReaction(postIndex, currentUserId, previousReaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  void _revertReaction(
    int postIndex,
    String currentUserId,
    String? previousReaction,
  ) {
    setState(() {
      final post = _posts[postIndex];
      final reactions = post['reactions'] != null
          ? List<dynamic>.from(post['reactions'])
          : [];

      if (previousReaction == null) {
        // Remove the added reaction
        reactions.removeWhere(
          (r) =>
              r['user'] == currentUserId ||
              (r['user'] is Map && r['user']['_id'] == currentUserId),
        );
        _posts[postIndex]['reactions'] = reactions;
        _posts[postIndex]['reactionsCount'] = (post['reactionsCount'] ?? 1) - 1;
        _posts[postIndex]['likesCount'] = (post['likesCount'] ?? 1) - 1;
      } else {
        // Restore previous reaction
        final index = reactions.indexWhere(
          (r) =>
              r['user'] == currentUserId ||
              (r['user'] is Map && r['user']['_id'] == currentUserId),
        );
        if (index >= 0) {
          reactions[index]['type'] = previousReaction;
        } else {
          reactions.add({
            'user': currentUserId,
            'type': previousReaction,
            'createdAt': DateTime.now().toIso8601String(),
          });
          _posts[postIndex]['reactionsCount'] =
              (post['reactionsCount'] ?? 0) + 1;
          _posts[postIndex]['likesCount'] = (post['likesCount'] ?? 0) + 1;
        }
        _posts[postIndex]['reactions'] = reactions;
      }

      // Recalculate reactions summary from reactions array
      final summary = {
        'like': 0,
        'celebrate': 0,
        'insightful': 0,
        'funny': 0,
        'mindblown': 0,
        'support': 0,
        'total': reactions.length,
      };

      for (var reaction in reactions) {
        final type = reaction['type'];
        if (summary.containsKey(type)) {
          summary[type] = (summary[type] ?? 0) + 1;
        }
      }

      _posts[postIndex]['reactionsSummary'] = summary;
    });
  }

  Widget _buildSearchPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Detect if we're on mobile (width < 600) or web/tablet
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

        // Responsive values with increased height to prevent overlap
        final expandedHeight = isMobile ? 180.0 : (isTablet ? 200.0 : 220.0);
        final titleFontSize = isMobile ? 24.0 : (isTablet ? 28.0 : 32.0);
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 20.0);
        final searchFieldPadding = isMobile ? 12.0 : 16.0;
        final tabFontSize = isMobile ? 12.0 : 14.0;
        final tabIconSize = isMobile ? 18.0 : 20.0;

        return DefaultTabController(
          length: 5,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: true,
                elevation: 0,
                // Add more spacing at bottom to prevent overlap with tabs
                collapsedHeight: kToolbarHeight + (isMobile ? 8 : 12),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: EdgeInsets.only(
                    left: horizontalPadding,
                    bottom: isMobile ? 60 : 70,
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          isMobile ? 12 : 20,
                          horizontalPadding,
                          isMobile ? 16 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Search',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: isMobile ? 50 : 56,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 25 : 30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: isMobile ? 6 : 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                style: TextStyle(fontSize: isMobile ? 14 : 16),
                                decoration: InputDecoration(
                                  hintText: isMobile
                                      ? 'Search...'
                                      : 'Search users, posts...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.blue.shade600,
                                    size: isMobile ? 20 : 24,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            size: isMobile ? 20 : 24,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 25 : 30),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 25 : 30),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 25 : 30),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                    vertical: searchFieldPadding,
                                  ),
                                ),
                              ),
                            ),
                            // Add spacing to ensure search box doesn't overlap with tabs
                            SizedBox(height: isMobile ? 8 : 12),
                            // Search Filters and Sort Row
                            if (_searchQuery.isNotEmpty)
                              SizedBox(
                                height: isMobile ? 40 : 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    // Sort button
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: PopupMenuButton<String>(
                                        tooltip: 'Sort by',
                                        onSelected: (value) {
                                          setState(() {
                                            _searchSortBy = value;
                                          });
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem<String>(
                                            value: 'relevance',
                                            child: Row(
                                              children: [
                                                Icon(Icons.trending_up,
                                                    size: 18,
                                                    color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Relevance'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'date',
                                            child: Row(
                                              children: [
                                                Icon(Icons.schedule,
                                                    size: 18,
                                                    color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Newest First'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'popularity',
                                            child: Row(
                                              children: [
                                                Icon(Icons.favorite,
                                                    size: 18,
                                                    color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Most Popular'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 10 : 12,
                                            vertical: isMobile ? 6 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.blue.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _searchSortBy == 'relevance'
                                                    ? Icons.trending_up
                                                    : _searchSortBy == 'date'
                                                        ? Icons.schedule
                                                        : Icons.favorite,
                                                size: isMobile ? 16 : 18,
                                                color: Colors.blue.shade600,
                                              ),
                                              SizedBox(width: isMobile ? 4 : 6),
                                              Text(
                                                _searchSortBy == 'relevance'
                                                    ? 'Relevant'
                                                    : _searchSortBy == 'date'
                                                        ? 'Newest'
                                                        : 'Popular',
                                                style: TextStyle(
                                                  fontSize:
                                                      isMobile ? 12 : 13,
                                                  color: Colors.blue.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Filter chips
                                    ...[
                                      ('people', Icons.people_outline, 'People'),
                                      ('content', Icons.article_outlined,
                                          'Content'),
                                      ('media', Icons.image_outlined, 'Media'),
                                    ].map((tuple) {
                                      final (value, icon, label) = tuple;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          selected: _searchFilter == value,
                                          onSelected: (selected) {
                                            setState(() {
                                              _searchFilter =
                                                  selected ? value : 'all';
                                            });
                                          },
                                          label: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 13,
                                              color: _searchFilter == value
                                                  ? Colors.white
                                                  : Colors.blue.shade600,
                                            ),
                                          ),
                                          avatar: Icon(
                                            icon,
                                            size: isMobile ? 14 : 16,
                                            color: _searchFilter == value
                                                ? Colors.white
                                                : Colors.blue.shade600,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          side: BorderSide(
                                            color: _searchFilter == value
                                                ? Colors.blue.shade600
                                                : Colors.blue.shade300,
                                            width: 1.5,
                                          ),
                                          selectedColor: Colors.blue.shade600,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(isMobile ? 56 : 48),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      isScrollable: true,
                      labelColor: Colors.blue.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: Colors.blue.shade700,
                      indicatorWeight: isMobile ? 2 : 3,
                      labelStyle: TextStyle(
                        fontSize: tabFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      tabAlignment:
                          isMobile ? TabAlignment.start : TabAlignment.center,
                      padding:
                          EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.people_outline, size: tabIconSize),
                          text: 'Users',
                          height: isMobile ? 56 : 48,
                        ),
                        Tab(
                          icon: Icon(Icons.article_outlined, size: tabIconSize),
                          text: 'Posts',
                          height: isMobile ? 56 : 48,
                        ),
                        Tab(
                          icon: Icon(Icons.video_library_outlined,
                              size: tabIconSize),
                          text: 'Videos',
                          height: isMobile ? 56 : 48,
                        ),
                        Tab(
                          icon: Icon(Icons.auto_stories_outlined,
                              size: tabIconSize),
                          text: 'Stories',
                          height: isMobile ? 56 : 48,
                        ),
                        Tab(
                          icon: Icon(Icons.bookmark_outline, size: tabIconSize),
                          text: 'Saved',
                          height: isMobile ? 56 : 48,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  children: [
                    // Wrap each tab to keep state and prevent rebuilds
                    KeepAliveWrapper(child: _buildUserSearchResults()),
                    KeepAliveWrapper(child: _buildPostSearchResults()),
                    KeepAliveWrapper(child: _buildVideoSearchResults()),
                    KeepAliveWrapper(child: _buildStorySearchResults()),
                    KeepAliveWrapper(child: _buildSavedPostsSearchResults()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserSearchResults() {
    if (_searchQuery.isEmpty) {
      // Defer loading top users using post-frame callback to prevent blocking UI
      if (!_hasAttemptedTopUsers && !_isLoadingTopUsers) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAttemptedTopUsers && !_isLoadingTopUsers) {
            _loadTopUsers();
          }
        });
      }

      // Show loading indicator while fetching top users
      if (_isLoadingTopUsers && _topUsers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Show top users by follower count
      if (_topUsers.isNotEmpty) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final padding = isMobile ? 12.0 : 16.0;

            return ListView(
              padding: EdgeInsets.all(padding),
              children: [
                // Top Users Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade400,
                              Colors.purple.shade400
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top Users',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Most popular users with the most followers',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Top Users List
                ..._topUsers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  final userId = user['_id'] ?? '';
                  return Padding(
                    key: ValueKey('top-user-$userId'), // Add unique key for top users
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: index == 0
                                  ? [
                                      Colors.amber.shade400,
                                      Colors.amber.shade700
                                    ]
                                  : index == 1
                                      ? [
                                          Colors.grey.shade300,
                                          Colors.grey.shade500
                                        ]
                                      : index == 2
                                          ? [
                                              Colors.orange.shade300,
                                              Colors.orange.shade600
                                            ]
                                          : [
                                              Colors.blue.shade200,
                                              Colors.blue.shade400
                                            ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        // User card
                        Expanded(
                          child: _buildUserSearchCard(user),
                        ),
                      ],
                    ),
                  );
                }),
                // Show search history if available
                if (_searchHistory.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.grey.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _clearSearchHistory,
                          icon: Icon(
                            Icons.clear_all,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
                          label: Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._searchHistory.map((query) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        title:
                            Text(query, style: const TextStyle(fontSize: 14)),
                        trailing: Icon(
                          Icons.north_west,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                        onTap: () => _rerunSearch(query),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      }

      // Fallback empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search for users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find friends and connect',
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearchingUsers) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 5, // Show 5 skeleton loaders
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar skeleton
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text skeleton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Button skeleton
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_searchedUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              // Suggestion chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _trendingSearches.map((search) {
                  return ActionChip(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    onPressed: () {
                      _searchController.text = search;
                      _onSearchChanged(search);
                    },
                    label: Text(
                      'Try: $search',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardPadding = isMobile ? 8.0 : 16.0;
        final avatarRadius = isMobile ? 24.0 : 28.0;
        final titleFontSize = isMobile ? 15.0 : 16.0;
        final subtitleFontSize = isMobile ? 12.0 : 13.0;

        return ListView.builder(
          padding: EdgeInsets.all(cardPadding),
          physics: const BouncingScrollPhysics(), // Smooth iOS-style scrolling
          itemCount: _searchedUsers.length + (_hasMoreSearchResults ? 1 : 0),
          cacheExtent: 500, // Pre-cache items for smoother scrolling
          addAutomaticKeepAlives:
              true, // Keep items alive when scrolled off screen
          addRepaintBoundaries: true, // Optimize repainting
          itemBuilder: (context, index) {
            // Load more indicator at the end
            if (index == _searchedUsers.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading more users...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            final user = _searchedUsers[index];
            final userId = user['_id'] ?? '';
            final userName = user['name'] ?? 'Unknown User';
            final userEmail = user['email'] ?? '';
            final userAvatar = user['avatar'];

            return Card(
              key: ValueKey(userId), // Add unique key based on user ID
              margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
              elevation: isMobile ? 1 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 6 : 8,
                ),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2),
                        blurRadius: isMobile ? 6 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AvatarWithFallback(
                    name: userName,
                    imageUrl: userAvatar,
                    radius: avatarRadius,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16 : 18,
                    ),
                    getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: titleFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Verified badge
                    if (user['isVerified'] == true) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: isMobile ? 14 : 16,
                        color: Colors.blue,
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: subtitleFontSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Follower count
                    if (user['followerCount'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: isMobile ? 12 : 13,
                              color: Colors.blue.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${user['followerCount'] ?? 0} followers',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: subtitleFontSize - 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfilePage(userId: userId),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: isMobile ? 14 : 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(userId: userId),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserSearchCard(Map<String, dynamic> user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final avatarRadius = isMobile ? 24.0 : 28.0;
        final titleFontSize = isMobile ? 15.0 : 16.0;
        final subtitleFontSize = isMobile ? 12.0 : 13.0;

        final userId = user['_id'] ?? '';
        final userName = user['name'] ?? 'Unknown User';
        final userEmail = user['email'] ?? '';
        final userAvatar = user['avatar'];
        final userBio = user['bio'];

        return Card(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          elevation: isMobile ? 1 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 6 : 8,
            ),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: isMobile ? 6 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AvatarWithFallback(
                name: userName,
                imageUrl: userAvatar,
                radius: avatarRadius,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                ),
                getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    userName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: titleFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userBio != null && userBio.toString().isNotEmpty)
                  Text(
                    userBio.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: subtitleFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: subtitleFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: isMobile ? 14 : 16,
                color: Colors.white,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(userId: userId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostSearchResults() {
    if (_searchQuery.isEmpty) {
      // Load top posts if not loaded yet (use post-frame callback to avoid setState during build)
      if (!_hasAttemptedTopPosts && !_isLoadingTopPosts) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAttemptedTopPosts && !_isLoadingTopPosts) {
            _loadTopPosts();
          }
        });
      }

      // Show loading indicator while fetching top posts
      if (_isLoadingTopPosts && _topPosts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Show top posts if available
      if (_topPosts.isNotEmpty) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _topPosts.length + 1, // +1 for header
          itemBuilder: (context, index) {
            // Header
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.blue.shade400,
                                Colors.purple.shade400
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Top Posts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Most engaged posts from people you follow',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Post items
            final postIndex = index - 1;
            final post = _topPosts[postIndex];
            final postId = post['_id'] ?? '';
            final author = post['author'] ?? {};
            final authorId = author['_id'] ?? '';
            final authorName = author['name'] ?? 'Unknown User';
            final userAvatar = author['avatar'];
            final content = post['content'] ?? '';
            final likes = post['likeCount'] ??
                post['likesCount'] ??
                post['reactionsCount'] ??
                0;
            final comments = post['commentCount'] ?? post['commentsCount'] ?? 0;
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
            final currentUserId = _currentUser?['_id'];

            String? userReaction;
            if (currentUserId != null) {
              for (var reaction in reactions) {
                if (reaction['user'] == currentUserId ||
                    (reaction['user'] is Map &&
                        reaction['user']['_id'] == currentUserId)) {
                  userReaction = reaction['type'];
                  break;
                }
              }
            }

            // Get images and videos
            final images = post['images'] != null
                ? List<String>.from(post['images'])
                : null;
            final videos = post['videos'] != null
                ? List<String>.from(post['videos'])
                : null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveDimensions.getItemSpacing(context) * 1.5,
              ),
              child: _buildPostCard(
                postId: postId,
                authorId: authorId,
                userName: authorName,
                userAvatar: userAvatar,
                timeAgo: timeAgo,
                content: content,
                reactionsCount: likes,
                comments: comments,
                userReaction: userReaction,
                reactionsSummary: reactionsSummary,
                images: images,
                videos: videos,
                isShared: post['isReshare'] == true,
                sharedBy: post['reshareCaption'],
                shareMessage: post['reshareCaption'],
              ),
            );
          },
        );
      }

      // Default empty state if no top posts
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No top posts available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow people to see their top posts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearchingPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching posts...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.speaker_notes_off_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No posts found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemCount: _searchedPosts.length,
      itemBuilder: (context, index) {
        final post = _searchedPosts[index];
        final postId = post['_id'] ?? '';
        final author = post['author'] ?? {};
        final authorId = author['_id'] ?? '';
        final authorName = author['name'] ?? 'Unknown User';
        final userAvatar = author['avatar'];
        final content = post['content'] ?? '';
        final likes = post['likesCount'] ?? post['reactionsCount'] ?? 0;
        final comments = post['commentsCount'] ?? 0;
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
        final currentUserId = _currentUser?['_id'];

        String? userReaction;
        if (currentUserId != null) {
          for (var reaction in reactions) {
            if (reaction['user'] == currentUserId ||
                (reaction['user'] is Map &&
                    reaction['user']['_id'] == currentUserId)) {
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

        return Column(
          children: [
            _buildPostCard(
              postId: postId,
              authorId: authorId,
              userName: authorName,
              userAvatar: userAvatar,
              timeAgo: timeAgo,
              content: content,
              reactionsCount: likes,
              comments: comments,
              userReaction: userReaction,
              reactionsSummary: reactionsSummary,
              images: images,
              videos: videos,
              isShared: post['isShared'] == true,
              sharedBy: post['sharedBy'],
              shareMessage: post['shareMessage'],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildVideoSearchResults() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search for videos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find interesting video content',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isSearchingVideos) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching videos...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchedVideos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No videos found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemCount: _searchedVideos.length,
      itemBuilder: (context, index) {
        final video = _searchedVideos[index];
        final title = video['title'] ?? 'Untitled';
        final description = video['description'] ?? '';
        final thumbnail = video['thumbnail'];
        final author = video['author'] ?? {};
        final authorName = author['name'] ?? 'Unknown';
        final views = video['views'] ?? 0;
        final createdAt = video['createdAt'];
        final timeAgo = _formatTimeAgo(createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Navigate to video player page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VideosPage(),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    child: thumbnail != null && thumbnail.toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              UrlUtils.getFullImageUrl(thumbnail),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.video_library,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.video_library,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                  ),
                ),
                // Video Info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$views views',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            ' • $timeAgo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorySearchResults() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search for stories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover recent stories',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isSearchingStories) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching stories...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchedStories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No stories found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchedStories.length,
      itemBuilder: (context, index) {
        final story = _searchedStories[index];
        final author = story['author'] ?? {};
        final authorName = author['name'] ?? 'Unknown';
        final authorAvatar = author['avatar'];
        final mediaUrl = story['mediaUrl'];
        final mediaType = story['mediaType'] ?? 'image';
        final createdAt = story['createdAt'];
        final timeAgo = _formatTimeAgo(createdAt);

        return GestureDetector(
          onTap: () {
            // Navigate to story viewer - show only this story
            final storyList = <Map<String, dynamic>>[
              Map<String, dynamic>.from(story)
            ];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryViewerPage(
                  userStories: storyList,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Story Media Background
                  if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                    Image.network(
                      UrlUtils.getFullImageUrl(mediaUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          child: Icon(
                            mediaType == 'video'
                                ? Icons.video_library
                                : Icons.image,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      child: Icon(
                        Icons.auto_stories,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Author Info
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              backgroundImage: authorAvatar != null &&
                                      authorAvatar.toString().isNotEmpty
                                  ? UrlUtils.getAvatarImageProvider(
                                      authorAvatar)
                                  : null,
                              child: authorAvatar == null ||
                                      authorAvatar.toString().isEmpty
                                  ? Text(
                                      authorName.isNotEmpty
                                          ? authorName[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Play icon for videos
                  if (mediaType == 'video')
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedPostsSearchResults() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search your saved posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find posts you\'ve bookmarked',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isSearchingSavedPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching saved posts...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchedSavedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.bookmark_border_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No saved posts found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemCount: _searchedSavedPosts.length,
      itemBuilder: (context, index) {
        final post = _searchedSavedPosts[index];
        final postId = post['_id'] ?? '';
        final author = post['author'] ?? {};
        final authorId = author['_id'] ?? '';
        final authorName = author['name'] ?? 'Unknown User';
        final userAvatar = author['avatar'];
        final content = post['content'] ?? '';
        final likes = post['likesCount'] ?? post['reactionsCount'] ?? 0;
        final comments = post['commentsCount'] ?? 0;
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
        final currentUserId = _currentUser?['_id'];

        String? userReaction;
        if (currentUserId != null) {
          for (var reaction in reactions) {
            if (reaction['user'] == currentUserId ||
                (reaction['user'] is Map &&
                    reaction['user']['_id'] == currentUserId)) {
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

        return Column(
          children: [
            Stack(
              children: [
                _buildPostCard(
                  postId: postId,
                  authorId: authorId,
                  userName: authorName,
                  userAvatar: userAvatar,
                  timeAgo: timeAgo,
                  content: content,
                  reactionsCount: likes,
                  comments: comments,
                  userReaction: userReaction,
                  reactionsSummary: reactionsSummary,
                  images: images,
                  videos: videos,
                  isShared: post['isShared'] == true,
                  sharedBy: post['sharedBy'],
                  shareMessage: post['shareMessage'],
                ),
                // Saved badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Saved',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildNotificationsPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive breakpoints
        final isDesktop = constraints.maxWidth > 900;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        // Responsive sizing
        final headerHeight = isDesktop ? 100.0 : (isTablet ? 120.0 : 140.0);
        final headerFontSize = isDesktop ? 28.0 : (isTablet ? 30.0 : 32.0);
        final maxContentWidth = isDesktop ? 800.0 : double.infinity;
        final horizontalPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

        if (_isLoadingNotifications && _notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading notifications...',
                  style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                ),
              ],
            ),
          );
        }

        if (_notifications.isEmpty && !_isLoadingNotifications) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: headerHeight,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Container(
                          constraints:
                              BoxConstraints(maxWidth: maxContentWidth),
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 20, horizontalPadding, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade100,
                                Colors.purple.shade100
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: isDesktop ? 80 : 64,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: isDesktop ? 24 : 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 60 : 40),
                          child: Text(
                            'When someone reacts or comments on your posts,\nyou\'ll see it here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.purple.shade400
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _loadNotifications,
                                borderRadius: BorderRadius.circular(30),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Retry',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: headerHeight,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Container(
                          constraints:
                              BoxConstraints(maxWidth: maxContentWidth),
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 20, horizontalPadding, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Notifications',
                                      style: TextStyle(
                                        fontSize: headerFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (_unreadNotificationCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.notifications_active,
                                            size: 16,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$_unreadNotificationCount',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _unreadNotificationCount > 0
                              ? '$_unreadNotificationCount unread'
                              : '${_notifications.length} notifications',
                          style: TextStyle(
                            fontSize: isDesktop ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Flexible(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.teal.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _refreshNotifications,
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.refresh,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Refresh',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_unreadNotificationCount > 0)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade400,
                                          Colors.purple.shade400,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _markAllAsRead,
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.done_all,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Mark all read',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_notifications.isNotEmpty)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _clearAllNotifications,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Clear all',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(top: 8, bottom: isDesktop ? 16 : 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notification = _notifications[index];
                    return Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : (isTablet ? 20 : 12),
                          vertical: 4,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Card(
                            elevation: isDesktop ? 1 : 2,
                            shadowColor: Colors.black.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: NotificationCard(
                              notificationData: notification,
                              onTap: () => _handleNotificationTap(notification),
                              onDismiss: () =>
                                  _deleteNotification(notification['_id']),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: _notifications.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshProfile() async {
    try {
      final result = await ApiService.getCurrentUser();
      if (result['success'] == true && result['data'] != null) {
        final userData = result['data']['user'];

        debugPrint('   New avatar: ${userData['avatar']}');

        setState(() {
          _currentUser = userData;
        });

        // Cache the updated profile
        await CacheService().cacheUserProfile(userData);

        // Also refresh user posts
        await _loadUserPosts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile refreshed'),
              duration: const Duration(seconds: 1),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _handleProfileImageUpload() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Choose Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show uploading state
      setState(() => _isUploadingAvatar = true);

      // Upload image
      final result = await ApiService.uploadProfileAvatar(image);

      setState(() => _isUploadingAvatar = false);

      if (result['success'] == true) {
        debugPrint('   Result data: ${result['data']}');

        // Update will be received via socket, but also update locally
        if (result['data'] != null && result['data']['user'] != null) {
          debugPrint('   Old avatar: ${_currentUser?['avatar']}');
          debugPrint('   New avatar: ${result['data']['user']['avatar']}');

          setState(() {
            _currentUser = result['data']['user'];
          });

          debugPrint(
            '   _currentUser updated! New avatar: ${_currentUser?['avatar']}',
          );

          // Cache the updated profile
          await CacheService().cacheUserProfile(result['data']['user']);

          // Force a UI rebuild after a short delay to ensure image loads
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {});
            }
          });
        } else {}
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to upload image'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  // Upload feed banner photo
  Future<void> _uploadFeedBanner() async {
    try {
      // Show source selector
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show uploading state
      setState(() => _isUploadingFeedBanner = true);

      // Upload image
      final result = await ApiService.uploadFeedBanner(image);

      setState(() => _isUploadingFeedBanner = false);

      if (result['success'] == true) {
        // Update user profile with new feed banner
        if (result['data'] != null && result['data']['user'] != null) {
          setState(() {
            _currentUser = result['data']['user'];
          });

          // Cache the updated profile
          await CacheService().cacheUserProfile(result['data']['user']);

          // Force a UI rebuild
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {});
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Feed banner updated successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to upload banner'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingFeedBanner = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading banner: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Widget _buildProfilePage() {
    return RefreshIndicator(
      onRefresh: () async {
        // Add haptic feedback
        HapticFeedback.mediumImpact();
        
        // Perform refresh
        await _refreshProfile();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Profile updated!'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      color: Colors.white,
      displacement: 60,
      strokeWidth: 3.0,
      child: CustomScrollView(
        slivers: [
          // Modern header with gradient background
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Avatar with modern design
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingAvatar
                            ? null
                            : _handleProfileImageUpload,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _isUploadingAvatar
                                ? Container(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : _currentUser!['avatar'] != null &&
                                        _currentUser!['avatar']
                                            .toString()
                                            .isNotEmpty
                                    ? Image.network(
                                        UrlUtils.getFullAvatarUrl(
                                            _currentUser!['avatar']),
                                        key: ValueKey(
                                          'avatar_${_currentUser!['avatar']}_${DateTime.now().millisecondsSinceEpoch}',
                                        ),
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          debugPrint(
                                            '   Avatar URL: ${UrlUtils.getFullAvatarUrl(_currentUser!['avatar'])}',
                                          );
                                          return Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue,
                                                  Colors.purple,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _currentUser!['name'][0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 40,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue,
                                              Colors.purple
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _currentUser!['name'][0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                      // Camera icon overlay with modern design
                      if (!_isUploadingAvatar)
                        Positioned(
                          right: 0,
                          bottom: 5,
                          child: GestureDetector(
                            onTap: _handleProfileImageUpload,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Name and bio in white text with animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedNameWidget(
                        name: _currentUser!['name'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showEditProfileDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentUser!['bio'] != null &&
                      _currentUser!['bio'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _currentUser!['bio']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Modern stats cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernStatCard(
                                Icons.article,
                                '${_currentUser!['postsCount'] ?? 0}',
                                'Posts',
                                Colors.orange,
                                _showMyPosts,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildModernStatCard(
                                Icons.people,
                                '${_currentUser!['followersCount'] ?? 0}',
                                'Followers',
                                Colors.pink,
                                _showMyFollowers,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildModernStatCard(
                                Icons.person_add,
                                '${_currentUser!['followingCount'] ?? 0}',
                                'Following',
                                Colors.green,
                                _showMyFollowing,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Profile Visitors Card
                        _buildVisitorStatsCard(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // White content area with rounded top
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.visibility_outlined,
                            label: 'Visitors',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfileVisitorsPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            color: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileSettingsPage(
                                    user: _currentUser!,
                                    onEditProfile: () {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Posts section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your Posts',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (_userPosts.isNotEmpty)
                    Text(
                      '${_userPosts.length} ${_userPosts.length == 1 ? 'post' : 'posts'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // User posts with modern loading and empty states
          if (_isLoadingUserPosts)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildPostCardShimmer()),
            )
          else if (_userPosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade50, Colors.purple.shade50],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100, width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.post_add,
                          size: 48,
                          color: Colors.blue.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share your thoughts with the world',
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(
                            () => _selectedIndex = 0,
                          ); // Go to home/feed tab
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Post'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = _userPosts[index];
                  final postId = post['_id'] ?? '';
                  final author = post['author'] ?? {};
                  final authorId = author['_id'] ?? '';
                  final authorName = author['name'] ?? 'Unknown User';
                  final userAvatar = author['avatar'];
                  final content = post['content'] ?? '';
                  final likes =
                      post['likesCount'] ?? post['reactionsCount'] ?? 0;
                  final comments = post['commentsCount'] ?? 0;
                  final createdAt = post['createdAt'];
                  final timeAgo = _formatTimeAgo(createdAt);

                  // Get reactions
                  final reactions = post['reactions'] != null
                      ? List<dynamic>.from(post['reactions'])
                      : [];
                  final reactionsSummary = post['reactionsSummary'] != null
                      ? Map<String, dynamic>.from(post['reactionsSummary'])
                      : <String, dynamic>{};
                  final currentUserId = _currentUser?['_id'];

                  // Find user's reaction
                  String? userReaction;
                  if (currentUserId != null) {
                    for (var reaction in reactions) {
                      if (reaction['user'] == currentUserId ||
                          (reaction['user'] is Map &&
                              reaction['user']['_id'] == currentUserId)) {
                        userReaction = reaction['type'];
                        break;
                      }
                    }
                  }

                  // Get images and videos
                  final images = post['images'] != null
                      ? List<String>.from(post['images'])
                      : null;
                  final videos = post['videos'] != null
                      ? List<String>.from(post['videos'])
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPostCard(
                      postId: postId,
                      authorId: authorId,
                      userName: authorName,
                      userAvatar: userAvatar,
                      timeAgo: timeAgo,
                      content: content,
                      reactionsCount: likes,
                      comments: comments,
                      userReaction: userReaction,
                      reactionsSummary: reactionsSummary,
                      images: images,
                      videos: videos,
                      isShared: post['isShared'] == true,
                      sharedBy: post['sharedBy'],
                      shareMessage: post['shareMessage'],
                    ),
                  );
                }, childCount: _userPosts.length),
              ),
            ),
        ],
      ),
    );
  }

  // Modern stat card widget
  Widget _buildModernStatCard(
    IconData icon,
    String count,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Profile Visitors Stats Card
  Widget _buildVisitorStatsCard() {
    final stats = _visitorStats?['stats'];
    final hasPremiumAccess = _visitorStats?['hasPremiumAccess'] ?? false;
    final recentVisitors = _visitorStats?['recentVisitors'] as List?;

    final weekCount = stats?['thisWeek'] ?? 0;

    return GestureDetector(
      onTap: () {
        if (hasPremiumAccess &&
            recentVisitors != null &&
            recentVisitors.isNotEmpty) {
          _showVisitorsList();
        } else if (!hasPremiumAccess) {
          _showPremiumFeatureDialog('Profile Visitors');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade400, Colors.purple.shade500],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.visibility, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoadingVisitorStats
                        ? 'Loading...'
                        : weekCount > 0
                            ? '$weekCount Profile ${weekCount == 1 ? 'Visitor' : 'Visitors'}'
                            : 'No Visitors Yet',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoadingVisitorStats
                        ? ''
                        : weekCount > 0
                            ? 'Viewed this week'
                            : 'Share your profile to get views',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (hasPremiumAccess &&
                recentVisitors != null &&
                recentVisitors.isNotEmpty) ...[
              const SizedBox(width: 8),
              Stack(
                children: [
                  for (int i = 0;
                      i <
                          (recentVisitors.length > 3
                              ? 3
                              : recentVisitors.length);
                      i++)
                    Padding(
                      padding: EdgeInsets.only(left: i * 20.0),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: recentVisitors[i]['user']?['avatar'] != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                    UrlUtils.getFullAvatarUrl(
                                        recentVisitors[i]['user']['avatar']),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.blue.shade300,
                        ),
                        child: recentVisitors[i]['user']?['avatar'] == null
                            ? Center(
                                child: Text(
                                  (recentVisitors[i]['user']?['name'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ] else if (!hasPremiumAccess)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Action button widget
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show current user's posts
  void _showMyPosts() {
    if (_currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MyPostsBottomSheet(
        userId: _currentUser!['_id'],
        userName: _currentUser!['name'] ?? 'Your',
      ),
    );
  }

  // Show current user's followers
  void _showMyFollowers() {
    if (_currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MyFollowersBottomSheet(
        userId: _currentUser!['_id'],
        userName: _currentUser!['name'] ?? 'Your',
        currentUser: _currentUser!,
      ),
    );
  }

  // Show current user's following
  void _showMyFollowing() {
    if (_currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MyFollowingBottomSheet(
        userId: _currentUser!['_id'],
        userName: _currentUser!['name'] ?? 'You',
        currentUser: _currentUser!,
      ),
    );
  }

  // Show visitors list (premium feature)
  void _showVisitorsList() {
    final recentVisitors = _visitorStats?['recentVisitors'] as List?;
    if (recentVisitors == null || recentVisitors.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Profile Visitors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Visitors list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recentVisitors.length,
                itemBuilder: (context, index) {
                  final visitor = recentVisitors[index];
                  final user = visitor['user'];
                  final lastVisit = visitor['lastVisit'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null
                          ? UrlUtils.getAvatarImageProvider(user['avatar'])
                          : null,
                      child: user['avatar'] == null
                          ? Text(
                              (user['name'] ?? '?')[0].toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Visited ${_formatTimeAgo(lastVisit)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfilePage(userId: user['_id']),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show premium feature dialog
  void _showPremiumFeatureDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$featureName is a premium feature.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'With Premium, you can:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPremiumBenefit('👀 See who viewed your profile'),
                  _buildPremiumBenefit('🚫 Enjoy an ad-free experience'),
                  _buildPremiumBenefit('🎨 Custom themes and colors'),
                  _buildPremiumBenefit('✨ Get a verified badge'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to premium purchase page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumSubscriptionPage(),
                ),
              );
            },
            icon: const Icon(Icons.star),
            label: const Text('Go Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // Shimmer loading widgets
  Widget _buildProfileLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Shimmer.fromColors(
            baseColor: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey[300]!,
            highlightColor: isDark ? Theme.of(context).colorScheme.surface : Colors.grey[100]!,
            child: Column(
              children: [
                // Avatar shimmer
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 16),
                // Name shimmer
                Container(
                  width: 150,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Email shimmer
                Container(
                  width: 200,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),
                // Stats shimmer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    3,
                    (index) => Column(
                      children: [
                        Container(
                          width: 50,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostLoadingShimmer() {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPostCardShimmer(),
        ),
      ),
    );
  }

  Widget _buildPostCardShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey[300]!,
      highlightColor: isDark ? Theme.of(context).colorScheme.surface : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Image placeholder
            Container(width: double.infinity, height: 200, color: Theme.of(context).colorScheme.surfaceContainerHighest),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// My Posts Bottom Sheet Widget
class _MyPostsBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;

  const _MyPostsBottomSheet({required this.userId, required this.userName});

  @override
  State<_MyPostsBottomSheet> createState() => _MyPostsBottomSheetState();
}

class _MyPostsBottomSheetState extends State<_MyPostsBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getUserPosts(
        userId: widget.userId,
        page: 1,
        limit: 50,
      );

      debugPrint('📝 API Result: ${result['success']}');
      debugPrint('📝 API Message: ${result['message']}');
      debugPrint('📝 API Data: ${result['data']}');

      if (result['success'] == true && result['data'] != null) {
        final posts = result['data']['posts'] ?? [];

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      } else {
        debugPrint('📝 Failed to load posts: ${result['message']}');
        setState(() => _isLoading = false);

        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to load posts'),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.userName} Posts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Posts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.post_add_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your first post!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return _buildPostPreview(post);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostPreview(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    final likesCount = post['likesCount'] ?? post['reactionsCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final createdAt = post['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);
    final images =
        post['images'] != null ? List<String>.from(post['images']) : null;
    final hasMedia = images != null && images.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(postId: post['_id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post content
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              // Media indicator
              if (hasMedia) ...[
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(UrlUtils.getFullImageUrl(images[0])),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: images.length > 1
                      ? Container(
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${images.length - 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],

              const SizedBox(height: 8),

              // Stats and time
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.red.shade300),
                  const SizedBox(width: 4),
                  Text(
                    '$likesCount',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: Colors.blue.shade300),
                  const SizedBox(width: 4),
                  Text(
                    '$commentsCount',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(String? dateString) {
    // Use TimeUtils to format as YYYY/MM/DD HH:MM
    return TimeUtils.formatMessageTimestamp(dateString);
  }
}

// My Followers Bottom Sheet Widget
class _MyFollowersBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final Map<String, dynamic> currentUser;

  const _MyFollowersBottomSheet({
    required this.userId,
    required this.userName,
    required this.currentUser,
  });

  @override
  State<_MyFollowersBottomSheet> createState() =>
      _MyFollowersBottomSheetState();
}

class _MyFollowersBottomSheetState extends State<_MyFollowersBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _followers = [];
  final SocketService _socketService = SocketService();
  final Set<String> _followingUserIds =
      {}; // Track which users current user is following
  final Map<String, bool> _actionLoading =
      {}; // Track loading state for each user

  @override
  void initState() {
    super.initState();
    _loadFollowers();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Listen for follow/unfollow events to update the list in real-time
    _socketService.on('user:followed', (data) {
      if (mounted) {
        _loadFollowers(); // Refresh the list
      }
    });

    _socketService.on('user:unfollowed', (data) {
      if (mounted) {
        _loadFollowers(); // Refresh the list
      }
    });
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoading = true);

    try {
      // Load followers
      final followersResult = await ApiService.getUserFollowers(widget.userId);

      // Load current user's following list to check follow status
      final followingResult = await ApiService.getUserFollowing(
        widget.currentUser['_id'],
      );

      if (followersResult['success'] == true &&
          followersResult['data'] != null) {
        final followers = followersResult['data']['followers'] ?? [];

        // Extract IDs of users that current user is following
        if (followingResult['success'] == true &&
            followingResult['data'] != null) {
          final following = followingResult['data']['following'] ?? [];
          _followingUserIds.clear();
          for (var user in following) {
            _followingUserIds.add(user['_id']);
          }
        }

        setState(() {
          _followers = followers;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.userName} Followers',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Followers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _followers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No followers yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _followers.length,
                        itemBuilder: (context, index) {
                          final follower = _followers[index];
                          return _buildUserTile(follower);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['_id'];
    final userName = user['name'] ?? 'Unknown';
    final userEmail = user['email'] ?? '';
    final userAvatar = user['avatar'];
    final userBio = user['bio'] ?? '';
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    final isCurrentUser = userId == widget.currentUser['_id'];
    final isFollowing = _followingUserIds.contains(userId);
    final isLoading = _actionLoading[userId] ?? false;

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: userId),
            ),
          );
        },
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          backgroundImage:
              userAvatar != null && userAvatar.toString().isNotEmpty
                  ? UrlUtils.getAvatarImageProvider(userAvatar)
                  : null,
          child: userAvatar == null || userAvatar.toString().isEmpty
              ? Text(
                  userInitials,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        userBio.isNotEmpty ? userBio : userEmail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrentUser
          ? null
          : _buildFollowButton(userId, isFollowing, isLoading),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: userId),
          ),
        );
      },
    );
  }

  Widget _buildFollowButton(String userId, bool isFollowing, bool isLoading) {
    // This is a follower, so they follow the current user
    // Show "Follow Back" if current user doesn't follow them
    // Show "Following" if current user already follows them

    if (isLoading) {
      return const SizedBox(
        width: 100,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      width: 100,
      height: 32,
      child: OutlinedButton(
        onPressed: () => _handleFollowAction(userId, isFollowing),
        style: OutlinedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.grey.shade200 : Colors.blue,
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
          side: BorderSide(
            color: isFollowing ? Colors.grey.shade400 : Colors.blue,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow Back',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleFollowAction(String userId, bool isFollowing) async {
    setState(() {
      _actionLoading[userId] = true;
    });

    try {
      Map<String, dynamic> result;
      if (isFollowing) {
        result = await ApiService.unfollowUser(userId);
      } else {
        result = await ApiService.followUser(userId);
      }

      if (result['success'] == true) {
        setState(() {
          if (isFollowing) {
            _followingUserIds.remove(userId);
          } else {
            _followingUserIds.add(userId);
          }
          _actionLoading[userId] = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFollowing
                    ? 'Unfollowed successfully'
                    : 'Following successfully',
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _actionLoading[userId] = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Action failed'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _actionLoading[userId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }
}

// My Following Bottom Sheet Widget
class _MyFollowingBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final Map<String, dynamic> currentUser;

  const _MyFollowingBottomSheet({
    required this.userId,
    required this.userName,
    required this.currentUser,
  });

  @override
  State<_MyFollowingBottomSheet> createState() =>
      _MyFollowingBottomSheetState();
}

class _MyFollowingBottomSheetState extends State<_MyFollowingBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _following = [];
  final SocketService _socketService = SocketService();
  final Set<String> _followerUserIds =
      {}; // Track which users follow the current user
  final Map<String, bool> _actionLoading =
      {}; // Track loading state for each user

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Listen for follow/unfollow events to update the list in real-time
    _socketService.on('user:followed', (data) {
      if (mounted) {
        _loadFollowing(); // Refresh the list
      }
    });

    _socketService.on('user:unfollowed', (data) {
      if (mounted) {
        _loadFollowing(); // Refresh the list
      }
    });
  }

  Future<void> _loadFollowing() async {
    setState(() => _isLoading = true);

    try {
      // Load following list
      final followingResult = await ApiService.getUserFollowing(widget.userId);

      // Load current user's followers list to check if they follow back
      final followersResult = await ApiService.getUserFollowers(
        widget.currentUser['_id'],
      );

      if (followingResult['success'] == true &&
          followingResult['data'] != null) {
        final following = followingResult['data']['following'] ?? [];

        // Extract IDs of users that follow the current user back
        if (followersResult['success'] == true &&
            followersResult['data'] != null) {
          final followers = followersResult['data']['followers'] ?? [];
          _followerUserIds.clear();
          for (var user in followers) {
            _followerUserIds.add(user['_id']);
          }
        }

        setState(() {
          _following = following;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.userName} Following',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Following list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _following.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Not following anyone yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _following.length,
                        itemBuilder: (context, index) {
                          final followedUser = _following[index];
                          return _buildUserTile(followedUser);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['_id'];
    final userName = user['name'] ?? 'Unknown';
    final userEmail = user['email'] ?? '';
    final userAvatar = user['avatar'];
    final userBio = user['bio'] ?? '';
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    final isCurrentUser = userId == widget.currentUser['_id'];
    final followsBack = _followerUserIds.contains(userId);
    final isLoading = _actionLoading[userId] ?? false;

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: userId),
            ),
          );
        },
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          backgroundImage:
              userAvatar != null && userAvatar.toString().isNotEmpty
                  ? UrlUtils.getAvatarImageProvider(userAvatar)
                  : null,
          child: userAvatar == null || userAvatar.toString().isEmpty
              ? Text(
                  userInitials,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        userBio.isNotEmpty ? userBio : userEmail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrentUser
          ? null
          : _buildFollowButton(userId, followsBack, isLoading),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: userId),
          ),
        );
      },
    );
  }

  Widget _buildFollowButton(String userId, bool followsBack, bool isLoading) {
    // Current user is following this user
    // Show "Following" button (can unfollow)
    // The button style doesn't change based on followsBack, but you could add an indicator

    if (isLoading) {
      return const SizedBox(
        width: 100,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      width: 100,
      height: 32,
      child: OutlinedButton(
        onPressed: () => _handleUnfollowAction(userId),
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Following',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleUnfollowAction(String userId) async {
    // Show confirmation dialog for unfollow
    final shouldUnfollow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unfollow'),
        content: const Text('Are you sure you want to unfollow this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (shouldUnfollow != true) return;

    setState(() {
      _actionLoading[userId] = true;
    });

    try {
      final result = await ApiService.unfollowUser(userId);

      if (result['success'] == true) {
        setState(() {
          _following.removeWhere((user) => user['_id'] == userId);
          _actionLoading[userId] = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unfollowed successfully'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _actionLoading[userId] = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Action failed'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _actionLoading[userId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }
}

// Keep alive wrapper to prevent tab content from rebuilding
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// Safe image loader with error handling
class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit ?? BoxFit.cover,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('⚠️ Image load error: $imageUrl - $error');
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Icon(
                Icons.person,
                size: (width ?? 40) * 0.6,
                color: Colors.grey.shade400,
              ),
            );
      },
    );
  }
}

// Helper widget for CircleAvatar with error handling
class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? child;

  const SafeAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade300,
        child: child ??
            Icon(Icons.person, size: radius, color: Colors.grey.shade600),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade300,
      child: ClipOval(
        child: SafeNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: child ??
              Icon(Icons.person, size: radius, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

