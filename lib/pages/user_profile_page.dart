import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/messaging_service.dart';
import '../services/socket_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../widgets/post_card.dart' as post_card;
import '../widgets/poke_dialog.dart';
import '../widgets/animated_profile_picture.dart';
import '../widgets/post_appearance_animations.dart';
import 'chat_page.dart';
import 'post_detail_page.dart';
import 'user_photos_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SocketService _socketService = SocketService();

  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isCreatingConversation = false;
  bool _isFollowLoading = false;
  Map<String, dynamic>? _user;
  List<dynamic> _userPosts = [];
  int _currentPage = 1;
  bool _hasMorePosts = true;
  bool _expandedBio = false;
  bool _isAdmin = false;

  // Tab controller for content filtering
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Store listener callback for cleanup
  Function(dynamic)? _profileUpdateListener;
  Function(dynamic)? _postCreatedListener;
  Function(dynamic)? _postDeletedListener;
  Function(dynamic)? _statusChangedListener;
  Function(dynamic)? _postLikedListener;
  Function(dynamic)? _postUnlikedListener;
  Function(dynamic)? _postCommentedListener;
  Function(dynamic)? _postCommentDeletedListener;

  // Track if app is resumed for data refresh
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _loadUserProfile();
    _checkAdminStatus();
    // Don't load posts immediately - wait for profile to load first
    // Posts will be loaded after profile loads or after following
    _setupSocketListener();
    _recordProfileVisit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      debugPrint('👤 App resumed - refreshing profile data');
      _needsRefresh = false;
      _loadUserProfile();
    }
  }

  Future<void> _recordProfileVisit() async {
    try {
      // Record the profile visit (backend will handle self-visit check)
      await ApiService.recordProfileVisit(widget.userId);
      debugPrint('👀 Profile visit recorded for user ${widget.userId}');
    } catch (e) {
      // Silently fail - visit tracking shouldn't interrupt user experience
      debugPrint('Failed to record profile visit: $e');
    }
  }

  void _setupSocketListener() {
    // Listen for profile updates of this specific user
    _profileUpdateListener = (data) {
      if (mounted && data != null && data['userId'] == widget.userId) {
        debugPrint('👤 Profile update received for user ${widget.userId}');
        final updatedUser = data['user'];

        setState(() {
          _user = updatedUser;
        });

        debugPrint('👤 ✅ User profile updated in real-time');
      }
    };

    _socketService.on('user:profile-updated', _profileUpdateListener!);

    // Listen for follow events
    _socketService.on('user:followed', (data) {
      if (mounted && data != null && data['userId'] == widget.userId) {
        debugPrint('👥 User followed event received for user ${widget.userId}');
        setState(() {
          if (_user != null) {
            _user!['followersCount'] = data['followersCount'];
            _user!['isFollowing'] =
                data['isFollowing'] ?? _user!['isFollowing'];
          }
        });
        debugPrint('👥 ✅ Follower count updated to ${data['followersCount']}');
      }
    });

    // Listen for unfollow events
    _socketService.on('user:unfollowed', (data) {
      if (mounted && data != null && data['userId'] == widget.userId) {
        debugPrint(
          '👥 User unfollowed event received for user ${widget.userId}',
        );
        setState(() {
          if (_user != null) {
            _user!['followersCount'] = data['followersCount'];
            _user!['isFollowing'] =
                data['isFollowing'] ?? _user!['isFollowing'];
          }
        });
        debugPrint('👥 ✅ Follower count updated to ${data['followersCount']}');
      }
    });

    // Listen for block events
    _socketService.on('user:blocked', (data) {
      if (mounted && data != null) {
        final blockedUserId = data['blockedUserId'];
        final blockerId = data['blockerId'];

        // If this user was blocked or if current user blocked someone
        if (blockedUserId == widget.userId || blockerId == widget.userId) {
          debugPrint('🚫 User block event received');

          if (mounted) {
            final scaffoldContext = context;
            // Navigate back since the profile is no longer accessible
            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
              SnackBar(
                content: const Text('This profile is no longer accessible'),
                backgroundColor: Theme.of(scaffoldContext).colorScheme.errorContainer,
                duration: const Duration(seconds: 2),
              ),
            );

            // Navigate back after a short delay - pop until we're back to home screen
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              int popCount = 0;
              Navigator.of(context).popUntil((route) {
                popCount++;
                if (popCount > 10) return true; // Safety limit
                return route
                    .isFirst; // Pop until we reach the first route (home)
              });
            });
          }
        }
      }
    });

    // Listen for unblock events
    _socketService.on('user:unblocked', (data) {
      if (mounted && data != null) {
        final unblockedUserId = data['unblockedUserId'];

        // If this user was unblocked, they might be able to see profile again
        if (unblockedUserId == widget.userId) {
          debugPrint('✅ User unblock event received');

          if (mounted) {
            final scaffoldContext = context;
            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
              SnackBar(
                content: const Text('User has been unblocked'),
                backgroundColor: Theme.of(scaffoldContext).colorScheme.primaryContainer,
                duration: const Duration(seconds: 2),
              ),
            );

            // Reload the profile
            _loadUserProfile();
          }
        }
      }
    });

    // Listen for new posts by this user
    _postCreatedListener = (data) {
      if (mounted && data != null && data['author'] == widget.userId) {
        debugPrint('📝 New post created by user ${widget.userId}');
        final newPost = data['post'];

        setState(() {
          // Add the new post at the beginning of the list
          _userPosts.insert(0, newPost);
          // Update post count if available
          if (_user != null && _user!['postsCount'] != null) {
            _user!['postsCount'] = (_user!['postsCount'] as int) + 1;
          }
        });

        debugPrint('📝 ✅ New post added to profile in real-time');
      }
    };

    _socketService.on('post:created', _postCreatedListener!);

    // Listen for post deletions by this user to keep counts and list in sync
    _postDeletedListener = (data) {
      if (!mounted || data == null) return;
      final authorId = data['authorId']?.toString();
      final postId = data['postId'];
      if (authorId == widget.userId) {
        setState(() {
          _userPosts.removeWhere((p) =>
              (p is Map<String, dynamic>) && (p['_id'] == postId));
          if (_user != null && _user!['postsCount'] != null) {
            final current = (_user!['postsCount'] as int);
            _user!['postsCount'] = current > 0 ? current - 1 : 0;
          }
        });
        debugPrint('🗑️ ✅ Post removed from profile in real-time');
      }
    };
    _socketService.on('post:deleted', _postDeletedListener!);

    // Listen for presence changes for this user (online/offline + lastActive)
    _statusChangedListener = (data) {
      if (!mounted || data == null) return;
      final changedUserId = data['userId']?.toString();
      if (changedUserId == widget.userId) {
        setState(() {
          if (_user != null) {
            _user!['isOnline'] = data['isOnline'] == true;
            if (data['lastActive'] != null) {
              _user!['lastActive'] = data['lastActive'];
            }
          }
        });
        debugPrint('🔔 Presence updated for user ${widget.userId}');
      }
    };
    _socketService.on('user:status-changed', _statusChangedListener!);

    // Listen for post like/unlike to update reactions count in real time
    _postLikedListener = (data) {
      if (!mounted || data == null) return;
      final postId = data['postId']?.toString();
      final likeCount = data['likeCount'] as int?;
      if (postId == null || likeCount == null) return;
      final index = _userPosts.indexWhere((p) =>
          (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
      if (index != -1) {
        setState(() {
          _userPosts[index]['reactionsCount'] = likeCount;
        });
        debugPrint('❤️ Reactions updated for post $postId → $likeCount');
      }
    };
    _socketService.on('post:liked', _postLikedListener!);

    _postUnlikedListener = (data) {
      if (!mounted || data == null) return;
      final postId = data['postId']?.toString();
      final likeCount = data['likeCount'] as int?;
      if (postId == null || likeCount == null) return;
      final index = _userPosts.indexWhere((p) =>
          (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
      if (index != -1) {
        setState(() {
          _userPosts[index]['reactionsCount'] = likeCount;
        });
        debugPrint('💔 Reactions updated for post $postId → $likeCount');
      }
    };
    _socketService.on('post:unliked', _postUnlikedListener!);

    // Listen for comments add/delete to update commentsCount in real time
    _postCommentedListener = (data) {
      if (!mounted || data == null) return;
      final postId = data['postId']?.toString();
      final commentsCount = data['commentsCount'] as int?;
      if (postId == null || commentsCount == null) return;
      final index = _userPosts.indexWhere((p) =>
          (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
      if (index != -1) {
        setState(() {
          _userPosts[index]['commentsCount'] = commentsCount;
        });
        debugPrint('💬 Comments updated for post $postId → $commentsCount');
      }
    };
    _socketService.on('post:commented', _postCommentedListener!);

    _postCommentDeletedListener = (data) {
      if (!mounted || data == null) return;
      final postId = data['postId']?.toString();
      final commentsCount = data['commentsCount'] as int?;
      if (postId == null || commentsCount == null) return;
      final index = _userPosts.indexWhere((p) =>
          (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
      if (index != -1) {
        setState(() {
          _userPosts[index]['commentsCount'] = commentsCount;
        });
        debugPrint('🗑️ Comments updated for post $postId → $commentsCount');
      }
    };
    _socketService.on('post:comment-deleted', _postCommentDeletedListener!);

    // Listen for shares to update shares count on original posts
    _socketService.on('post:shared', (data) {
      if (!mounted || data == null) return;
      try {
        final postData = data['post'] as Map<String, dynamic>?;
        final original = postData?['originalPost'] as Map<String, dynamic>?;
        final originalId = original?['_id']?.toString();
        if (originalId == null) return;
        final index = _userPosts.indexWhere((p) =>
            (p is Map<String, dynamic>) && (p['_id']?.toString() == originalId));
        if (index != -1) {
          setState(() {
            final current = _userPosts[index]['sharesCount'] as int? ??
                (_userPosts[index]['shares'] is List
                    ? (_userPosts[index]['shares'] as List).length
                    : 0);
            _userPosts[index]['sharesCount'] = current + 1;
          });
          debugPrint('🔁 Shares updated for post $originalId');
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    // Remove socket listeners
    if (_profileUpdateListener != null) {
      _socketService.off('user:profile-updated', _profileUpdateListener);
    }
    if (_postCreatedListener != null) {
      _socketService.off('post:created', _postCreatedListener);
    }
    if (_postDeletedListener != null) {
      _socketService.off('post:deleted', _postDeletedListener);
    }
    if (_statusChangedListener != null) {
      _socketService.off('user:status-changed', _statusChangedListener);
    }
    if (_postLikedListener != null) {
      _socketService.off('post:liked', _postLikedListener);
    }
    if (_postUnlikedListener != null) {
      _socketService.off('post:unliked', _postUnlikedListener);
    }
    if (_postCommentedListener != null) {
      _socketService.off('post:commented', _postCommentedListener);
    }
    if (_postCommentDeletedListener != null) {
      _socketService.off('post:comment-deleted', _postCommentDeletedListener);
    }
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getUserById(widget.userId);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _user = result['data']['user'];
          _isLoading = false;
        });

        // Load posts after profile is loaded
        // This ensures we know if we're following the user before trying to load posts
        _loadUserPosts();
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load user profile'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  Future<void> _loadUserPosts() async {
    if (_isLoadingPosts || !_hasMorePosts) return;

    setState(() => _isLoadingPosts = true);

    try {
      final result = await ApiService.getUserPosts(
        userId: widget.userId,
        page: _currentPage,
        limit: 10,
      );

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> newPosts = result['data']['posts'] ?? [];
        final pagination = result['data']['pagination'];

        setState(() {
          _userPosts.addAll(newPosts);
          _currentPage++;
          _hasMorePosts =
              pagination != null && pagination['page'] < pagination['pages'];
          _isLoadingPosts = false;
        });
      } else {
        setState(() => _isLoadingPosts = false);

        // Handle specific error messages (e.g., 403 - need to follow)
        final message = result['message'] ?? '';
        if (message.contains('follow')) {
          debugPrint('🔒 Cannot view posts - not following this user');
          // Don't show error to user - this is expected behavior
          // User will see "Follow to see posts" in the UI
        }
      }
    } catch (e) {
      setState(() => _isLoadingPosts = false);
      debugPrint('Error loading user posts: $e');

      // Check if it's a 403 error (not following)
      if (e.toString().contains('403') || e.toString().contains('follow')) {
        debugPrint('🔒 Cannot view posts - not following this user');
        // Don't show error to user - this is expected behavior
      }
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_user == null || _isFollowLoading) return;

    setState(() => _isFollowLoading = true);

    try {
      final isCurrentlyFollowing = _user!['isFollowing'] ?? false;
      final result = isCurrentlyFollowing
          ? await ApiService.unfollowUser(widget.userId)
          : await ApiService.followUser(widget.userId);

      if (result['success'] == true) {
        setState(() {
          _user!['isFollowing'] = !isCurrentlyFollowing;
          if (isCurrentlyFollowing) {
            _user!['followersCount'] = (_user!['followersCount'] ?? 1) - 1;
          } else {
            _user!['followersCount'] = (_user!['followersCount'] ?? 0) + 1;
          }
          _isFollowLoading = false;
        });

        // If we just followed the user, reload their posts
        // This allows us to now see their posts since we're following them
        if (!isCurrentlyFollowing) {
          debugPrint('👥 Just followed user, reloading their posts...');
          // Reset posts state and reload
          setState(() {
            _userPosts = [];
            _currentPage = 1;
            _hasMorePosts = true;
          });
          _loadUserPosts();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing
                  ? 'Unfollowed ${_user!['name']}'
                  : 'Following ${_user!['name']}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isFollowLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to update follow status',
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      setState(() => _isFollowLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  Future<void> _handleSendMessage() async {
    if (_user == null || _isCreatingConversation) return;

    setState(() => _isCreatingConversation = true);

    try {
      // Get or create conversation with this user
      final result = await MessagingService.getOrCreateConversation(
        widget.userId,
      );

      setState(() => _isCreatingConversation = false);

      if (result['success'] == true && result['data'] != null) {
        final conversation = result['data']['conversation'];
        final conversationId = conversation['_id'];

        // Navigate to chat page
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(conversationId: conversationId, otherUser: _user!),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to start conversation',
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreatingConversation = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  // Handle poke button
  void _handlePoke() {
    if (_user == null) return;

    final userName = _user!['name'] ?? 'User';
    showPokeDialog(context, widget.userId, userName);
  }

  // Show followers list
  void _showFollowersList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowersBottomSheet(
        userId: widget.userId,
        userName: _user!['name'] ?? 'User',
      ),
    );
  }

  // Show following list
  void _showFollowingList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowingBottomSheet(
        userId: widget.userId,
        userName: _user!['name'] ?? 'User',
      ),
    );
  }

  // Show photos
  void _showPhotos() {
    final currentUserId = _user?['_id'];
    final isOwnProfile =
        currentUserId != null && currentUserId == widget.userId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPhotosPage(
          userId: widget.userId,
          userName: _user!['name'] ?? 'User',
          isOwnProfile: isOwnProfile,
        ),
      ),
    );
  }

  // Check if current user is admin
  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await ApiService.checkIsAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  // Show more options menu
  void _showMoreOptions() async {
    final currentUserId = await SecureStorageService().getUserId();
    final isOwnProfile = _user?['_id'] != null && 
        _user!['_id'] == currentUserId;
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Profile Link'),
              onTap: () {
                Navigator.pop(context);
                _copyProfileLink();
              },
            ),
            if (!isOwnProfile) ...[
              ListTile(
                leading: Icon(
                  Icons.block,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Block User',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.report,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Report User',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser();
                },
              ),
            ],
            // Admin moderation options
            if (_isAdmin && !isOwnProfile) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: Text(
                  'Admin Actions',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                enabled: false,
              ),
              if (_user?['isSuspended'] == true)
                ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: const Text('Remove Suspension'),
                  onTap: () {
                    Navigator.pop(context);
                    _unsuspendUser();
                  },
                )
              else
                ListTile(
                  leading: Icon(
                    Icons.pause_circle,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  title: const Text('Suspend User'),
                  onTap: () {
                    Navigator.pop(context);
                    _suspendUser();
                  },
                ),
              if (_user?['isBanned'] == true)
                ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: const Text('Remove Ban'),
                  onTap: () {
                    Navigator.pop(context);
                    _unbanUser();
                  },
                )
              else
                ListTile(
                  leading: Icon(
                    Icons.gavel,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Ban User'),
                  onTap: () {
                    Navigator.pop(context);
                    _banUser();
                  },
                ),
              if (_user?['isMuted'] == true)
                ListTile(
                  leading: Icon(
                    Icons.volume_up,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: const Text('Unmute User'),
                  onTap: () {
                    Navigator.pop(context);
                    _unmuteUser();
                  },
                )
              else
                ListTile(
                  leading: Icon(
                    Icons.volume_off,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  title: const Text('Mute User'),
                  onTap: () {
                    Navigator.pop(context);
                    _muteUser();
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteUser();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    final userName = _user!['name'] ?? 'User';
    Share.share(
      'Check out $userName\'s profile on ReelChat!\nUser ID: ${widget.userId}',
      subject: 'ReelChat Profile',
    );
  }

  void _copyProfileLink() {
    Clipboard.setData(ClipboardData(text: 'ReelChat://user/${widget.userId}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block ${_user!['name']}?\n\n'
          'You won\'t be able to:\n'
          '• See their posts or profile\n'
          '• Message each other\n'
          '• See each other in search results\n\n'
          'They won\'t be notified that you blocked them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleBlockUser();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBlockUser() async {
    try {
      final result = await ApiService.blockUser(widget.userId);

      if (result['success'] == true) {
        if (!mounted) return;
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_user!['name']} has been blocked'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to home - pop until we reach the first route (HomePage)
        // Use a small delay to ensure the snackbar is visible
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;
        // Try to pop until we reach a route that can't be popped (the home screen)
        int popCount = 0;
        Navigator.of(context).popUntil((route) {
          popCount++;
          // If we've popped more than 10 times, something is wrong, stop
          if (popCount > 10) return true;
          // Stop at the first route or when we can't pop anymore
          return route.isFirst;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to block user'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => _ReportUserDialog(
        userId: widget.userId,
        userName: _user!['name'] ?? 'User',
      ),
    );
  }

  // Admin moderation actions
  void _suspendUser() {
    final reasonController = TextEditingController();
    String selectedDuration = '7';
    final scaffoldContext = context;

    showDialog(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: Text('Suspend ${_user!['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This user will not be able to like, comment, create posts/videos, or interact until unsuspended.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for suspension',
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedDuration,
                decoration: const InputDecoration(
                  labelText: 'Duration (days)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 day')),
                  DropdownMenuItem(value: '3', child: Text('3 days')),
                  DropdownMenuItem(value: '7', child: Text('7 days')),
                  DropdownMenuItem(value: '14', child: Text('14 days')),
                  DropdownMenuItem(value: '30', child: Text('30 days')),
                  DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedDuration = value!;
                  });
                },
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a reason'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              final duration = selectedDuration == 'permanent' ? null : int.parse(selectedDuration);
              final result = await ApiService.suspendUser(
                widget.userId,
                reason: reasonController.text.trim(),
                duration: duration,
              );

              if (!mounted) return;
              if (result['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${_user!['name']} has been suspended'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
                _loadUserProfile();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: ${result['message']}'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
              }
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  Future<void> _unsuspendUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Suspension'),
        content: Text('Are you sure you want to remove the suspension for ${_user!['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Suspension'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.unsuspendUser(widget.userId);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_user!['name']} has been unsuspended'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
      _loadUserProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result['message']}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  void _banUser() {
    final reasonController = TextEditingController();
    final scaffoldContext = context;

    showDialog(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: Text('Ban ${_user!['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This user will be permanently banned and will not be able to login until unbanned.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for ban',
                border: OutlineInputBorder(),
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a reason'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              final result = await ApiService.banUser(
                widget.userId,
                reason: reasonController.text.trim(),
              );

              if (!mounted) return;
              if (result['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${_user!['name']} has been banned'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
                _loadUserProfile();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: ${result['message']}'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
              }
            },
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
  }

  Future<void> _unbanUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Ban'),
        content: Text('Are you sure you want to remove the ban for ${_user!['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Ban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.unbanUser(widget.userId);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_user!['name']} has been unbanned'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
      _loadUserProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result['message']}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  void _muteUser() {
    final reasonController = TextEditingController();
    String selectedDuration = '7';
    final scaffoldContext = context;

    showDialog(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: Text('Mute ${_user!['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This user will not be able to create posts or comments until unmuted.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for mute',
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedDuration,
                decoration: const InputDecoration(
                  labelText: 'Duration (days)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 day')),
                  DropdownMenuItem(value: '3', child: Text('3 days')),
                  DropdownMenuItem(value: '7', child: Text('7 days')),
                  DropdownMenuItem(value: '14', child: Text('14 days')),
                  DropdownMenuItem(value: '30', child: Text('30 days')),
                  DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedDuration = value!;
                  });
                },
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a reason'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              final duration = selectedDuration == 'permanent' ? null : int.parse(selectedDuration);
              final result = await ApiService.muteUser(
                widget.userId,
                reason: reasonController.text.trim(),
                duration: duration,
              );

              if (!mounted) return;
              if (result['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${_user!['name']} has been muted'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
                _loadUserProfile();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: ${result['message']}'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
              }
            },
            child: const Text('Mute'),
          ),
        ],
      ),
    );
  }

  Future<void> _unmuteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmute User'),
        content: Text('Are you sure you want to unmute ${_user!['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unmute'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.unmuteUser(widget.userId);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_user!['name']} has been unmuted'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
      _loadUserProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result['message']}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  void _deleteUser() {
    final reasonController = TextEditingController();
    final scaffoldContext = context;

    showDialog(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text('Delete ${_user!['name']}\'s Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WARNING: This action is PERMANENT and cannot be undone!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The user will receive a notification and be immediately logged out. All their data will be deleted.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for deletion (required)',
                border: OutlineInputBorder(),
                hintText: 'Enter reason for account deletion...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a reason for deletion'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              final result = await ApiService.deleteUser(
                widget.userId,
                reason: reasonController.text.trim(),
              );

              if (!mounted) return;
              if (result['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${_user!['name']}\'s account has been deleted'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                    duration: const Duration(seconds: 5),
                  ),
                );
                if (!mounted) return;
                Navigator.of(this.context).pop();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: ${result['message']}'),
                    backgroundColor: Theme.of(this.context).colorScheme.errorContainer,
                  ),
                );
              }
            },
            child: const Text('DELETE ACCOUNT'),
          ),
        ],
      ),
    );
  }

  // Get filtered posts based on selected tab
  List<dynamic> get _filteredPosts {
    if (_selectedTabIndex == 0) {
      // All posts
      return _userPosts;
    } else if (_selectedTabIndex == 1) {
      // Photos only
      return _userPosts.where((post) {
        final images = post['images'];
        return images != null && (images as List).isNotEmpty;
      }).toList();
    } else {
      // Videos only
      return _userPosts.where((post) {
        final videos = post['videos'];
        return videos != null && (videos as List).isNotEmpty;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenWidth < 360;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Profile')),
        body: _buildLoadingShimmer(),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'User not found',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This user may have been deleted or blocked',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_user!['name'] ?? 'User Profile'),
        actions: [
          // Send Message button in app bar
          IconButton(
            icon: _isCreatingConversation
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.message),
            onPressed: _isCreatingConversation ? null : _handleSendMessage,
            tooltip: 'Send Message',
          ),
          // More options menu
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
            tooltip: 'More options',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _userPosts = [];
            _currentPage = 1;
            _hasMorePosts = true;
          });
          await _loadUserProfile();
          await _loadUserPosts();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              _loadUserPosts();
            }
            return false;
          },
          child: ListView(
            children: [
              // Profile Header
              _buildProfileHeader(),

              const SizedBox(height: 16),

              // Quick Action Buttons (Poke, Share, Message) - Enhanced
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : screenWidth * 0.04,
                ),
                child: Row(
                  children: [
                    // Poke Button
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: '👋',
                        label: 'Poke',
                        onPressed: _handlePoke,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                        borderColor: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.025),
                    // Share Button
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onPressed: _shareProfile,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                        borderColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.025),
                    // More Button
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.more_horiz,
                        label: 'More',
                        onPressed: _showMoreOptions,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        textColor: theme.colorScheme.onSurface,
                        borderColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenWidth * 0.06),

              // Tab Bar for filtering posts - Enhanced styling
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : screenWidth * 0.04,
                ),
                padding: EdgeInsets.all(screenWidth * 0.01),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  labelStyle: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'All Posts'),
                    Tab(
                      icon: Icon(Icons.image, size: 20),
                      text: 'Photos',
                    ),
                    Tab(
                      icon: Icon(Icons.ondemand_video, size: 20),
                      text: 'Videos',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // User Posts
              if (_filteredPosts.isEmpty && !_isLoadingPosts)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenWidth * 0.12,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: screenWidth * 0.225,
                          height: screenWidth * 0.225,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _selectedTabIndex == 0
                                ? Icons.post_add
                                : _selectedTabIndex == 1
                                    ? Icons.image_not_supported_outlined
                                    : Icons.video_library_outlined,
                            size: screenWidth * 0.12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.05),
                        Text(
                          _selectedTabIndex == 0
                              ? 'No posts yet'
                              : _selectedTabIndex == 1
                                  ? 'No photos yet'
                                  : 'No videos yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: isSmallScreen ? 16 : screenWidth * 0.048,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.025),
                        Text(
                          '${_user!['name']} hasn\'t shared anything in this category',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: isSmallScreen ? 12 : screenWidth * 0.035,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: screenWidth * 0.07),
                        if (!(_user!['isFollowing'] ?? false))
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primaryContainer,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _handleFollowToggle,
                              icon: Icon(
                                Icons.person_add,
                                size: isSmallScreen ? 16 : screenWidth * 0.05,
                              ),
                              label: Text(
                                'Follow to see more',
                                style: TextStyle(
                                  fontSize: isSmallScreen
                                      ? 12
                                      : screenWidth * 0.0375,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: theme.colorScheme.onPrimary,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen
                                      ? 16
                                      : screenWidth * 0.07,
                                  vertical: isSmallScreen
                                      ? 10
                                      : screenWidth * 0.035,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                ..._filteredPosts.map(
                  (post) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenWidth * 0.02,
                    ),
                    child: _buildPostCard(post),
                  ),
                ),

              // Loading indicator
              if (_isLoadingPosts)
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: const Center(child: CircularProgressIndicator()),
                ),

              SizedBox(height: screenWidth * 0.04),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenWidth < 360;
    final name = _user!['name'] ?? 'Unknown';
    final email = _user!['email'] ?? '';
    final avatar = _user!['avatar'];
    final bio = _user!['bio'];
    final createdAt = _user!['createdAt'];
    final isFollowing = _user!['isFollowing'] ?? false;
    final badges = _user!['badges'] as List<dynamic>? ?? [];

    // Show full bio if expanded, otherwise truncate
    final displayBio = bio != null && bio.toString().isNotEmpty
        ? (_expandedBio
            ? bio.toString()
            : (bio.toString().length > 120
                ? '${bio.toString().substring(0, 120)}...'
                : bio.toString()))
        : null;

    String userInitials = name.isNotEmpty
        ? name.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    // Determine profile background gradient - theme-aware
    final List<Color> gradientColors = [
      theme.colorScheme.primary,
      theme.colorScheme.primaryContainer,
    ];

    // Check if user is premium for special gradient
    final isPremium = _user!['isPremium'] ?? false;
    if (isPremium) {
      gradientColors.setAll(0, [
        theme.colorScheme.tertiary,
        theme.colorScheme.tertiaryContainer,
      ]);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : screenWidth * 0.06,
        isSmallScreen ? 16 : screenWidth * 0.06,
        isSmallScreen ? 16 : screenWidth * 0.06,
        isSmallScreen ? 20 : screenWidth * 0.07,
      ),
      decoration: BoxDecoration(
        image: avatar != null
            ? DecorationImage(
                image: UrlUtils.getAvatarImageProvider(avatar),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  isDark
                      ? theme.colorScheme.shadow.withValues(alpha: 0.6)
                      : theme.colorScheme.shadow.withValues(alpha: 0.5),
                  BlendMode.darken,
                ),
              )
            : null,
        gradient: avatar == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
                stops: const [0.0, 1.0],
              )
            : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Premium Badge (if applicable)
            if (isPremium)
              Container(
                margin: EdgeInsets.only(bottom: screenWidth * 0.025),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenWidth * 0.015,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.tertiary,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: screenWidth * 0.035,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    SizedBox(width: screenWidth * 0.015),
                    Text(
                      'Premium Member',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

            // Animated Avatar with enhanced styling - auto-plays on all devices
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedProfilePicture(
                radius: isSmallScreen
                    ? 60
                    : screenWidth * 0.2,
                imageUrl: avatar != null && avatar.toString().isNotEmpty
                    ? avatar // Pass raw URL - AnimatedProfilePicture handles both local assets and network URLs
                    : null,
                initials: userInitials,
                animationType: AnimationType.combined,
                autoPlay: true,
                onTap: avatar != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                post_card.ImageFullscreenViewer(
                              images: [UrlUtils.getFullAvatarUrl(avatar)],
                              initialIndex: 0,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            SizedBox(height: screenWidth * 0.05),

            // Name with verified badge - improved layout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 20
                          : screenWidth * 0.065,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SizedBox(height: screenWidth * 0.02),

            // Presence: online indicator and last seen
            Builder(builder: (context) {
              final isOnline = (_user!['isOnline'] == true);
              final lastActive = _user!['lastActive']?.toString();
              final presenceText = isOnline
                  ? 'Online'
                  : (lastActive != null && lastActive.isNotEmpty
                      ? TimeUtils.formatLastActive(lastActive)
                      : 'Last seen recently');

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: screenWidth * 0.028,
                    height: screenWidth * 0.028,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    presenceText,
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 12
                          : screenWidth * 0.034,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),

            // Email
            Text(
              email,
              style: TextStyle(
                fontSize: isSmallScreen
                    ? 12
                    : screenWidth * 0.035,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
              ),
            ),

            // Bio with improved styling and expand option
            if (displayBio != null) ...[
              SizedBox(height: screenWidth * 0.035),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                child: Column(
                  children: [
                    Text(
                      displayBio,
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 12
                            : screenWidth * 0.035,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (bio.toString().length > 120)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _expandedBio = !_expandedBio;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.only(top: screenWidth * 0.015),
                          child: Text(
                            _expandedBio ? 'Show less' : 'Show more',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Achievement Badges Section - Enhanced
            if (badges.isNotEmpty) ...[
              SizedBox(height: screenWidth * 0.055),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Wrap(
                      spacing: screenWidth * 0.02,
                      runSpacing: screenWidth * 0.02,
                      children: badges.take(5).map((badge) {
                        final badgeData = badge as Map<String, dynamic>? ?? {};
                        final badgeName = badgeData['name'] ?? 'Badge';
                        final badgeIcon = badgeData['icon'] ?? '🏆';

                        return Tooltip(
                          message: badgeName,
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeIcon,
                              style: TextStyle(fontSize: screenWidth * 0.05),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Enhanced Stats Row
            SizedBox(height: screenWidth * 0.055),
            Container(
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.03,
                horizontal: screenWidth * 0.02,
              ),
              decoration: BoxDecoration(
                // Slightly increase opacity for better readability
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn(
                      'Posts', '${_user!['postsCount'] ?? 0}', null),
                  _buildStatDivider(),
                  _buildStatColumn(
                      'Photos', '${_user!['photosCount'] ?? 0}', _showPhotos),
                  _buildStatDivider(),
                  _buildStatColumn(
                    'Followers',
                    '${_user!['followersCount'] ?? 0}',
                    _showFollowersList,
                  ),
                  _buildStatDivider(),
                  _buildStatColumn(
                    'Following',
                    '${_user!['followingCount'] ?? 0}',
                    _showFollowingList,
                  ),
                ],
              ),
            ),

            // Improved Follow/Message Buttons
            SizedBox(height: screenWidth * 0.06),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Follow/Unfollow Button
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: _isFollowLoading ? null : _handleFollowToggle,
                    icon: _isFollowLoading
                        ? SizedBox(
                            width: screenWidth * 0.045,
                            height: screenWidth * 0.045,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                          )
                        : Icon(
                            isFollowing
                                ? Icons.person_remove
                                : Icons.person_add,
                            size: screenWidth * 0.05,
                          ),
                    label: Text(
                      isFollowing ? 'Unfollow' : 'Follow',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.secondary,
                      foregroundColor: isFollowing
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSecondary,
                      padding:
                          EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isFollowing ? 0 : 2,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                // Message Button
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isCreatingConversation ? null : _handleSendMessage,
                    icon: _isCreatingConversation
                        ? SizedBox(
                            width: screenWidth * 0.045,
                            height: screenWidth * 0.045,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                          )
                        : Icon(Icons.message, size: screenWidth * 0.05),
                    label: Text(
                      'Message',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding:
                          EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),

            // Joined date - improved styling
            if (createdAt != null) ...[
              SizedBox(height: screenWidth * 0.035),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: screenWidth * 0.035,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Text(
                    'Joined ${TimeUtils.formatMessageTimestamp(createdAt)}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final author = post['author'];
    final authorName = author?['name'] ?? 'Unknown';
    final authorAvatar = author?['avatar'];
    final content = post['content'] ?? '';
    final createdAt = post['createdAt'];
    final reactionsCount = post['reactionsCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final sharesCount = post['sharesCount'] ??
        (post['shares'] is List ? (post['shares'] as List).length : null);
    final images =
        post['images'] != null ? List<String>.from(post['images']) : null;
    final videos =
        post['videos'] != null ? List<String>.from(post['videos']) : null;
    final reactionsSummary = post['reactionsSummary'] ?? {};

    String timeAgo =
        createdAt != null ? TimeUtils.formatMessageTimestamp(createdAt) : '';

    // User reaction would need current user ID to determine
    String? userReaction = post['userReaction'] as String?;

    return ScaleBounceAnimation(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      autoStart: true,
      child: post_card.PostCard(
        postId: post['_id'],
        authorId: author?['_id'] ?? '',
        userName: authorName,
        userAvatar: authorAvatar,
        timeAgo: timeAgo,
        content: content,
        reactionsCount: reactionsCount,
        comments: commentsCount,
        userReaction: userReaction,
        reactionsSummary: Map<String, dynamic>.from(reactionsSummary),
        images: images,
        videos: videos,
        authorData: author,
        sharesCount: sharesCount,
        onReactionTap: () => _handleToggleReaction(post['_id']),
        onCommentTap: () {
          // Navigate to post detail for comments
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(postId: post['_id']),
            ),
          );
        },
        onSettingsTap: () {
          // No settings for other users' posts on their profile
        },
        onShareTap: () {
          _handleSharePost(post['_id']);
        },
        onUserTap: null, // Already on user's profile, no need to navigate
      ),
    );
  }

  Future<void> _handleToggleReaction(String postId) async {
    final index = _userPosts.indexWhere((p) =>
        (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
    if (index == -1) return;

    final currentReaction = _userPosts[index]['userReaction'] as String?;
    final currentCount = _userPosts[index]['reactionsCount'] as int? ?? 0;

    // Optimistic update
    setState(() {
      if (currentReaction == null) {
        _userPosts[index]['userReaction'] = 'like';
        _userPosts[index]['reactionsCount'] = currentCount + 1;
      } else {
        _userPosts[index]['userReaction'] = null;
        _userPosts[index]['reactionsCount'] = currentCount > 0 ? currentCount - 1 : 0;
      }
    });

    try {
      if (currentReaction == null) {
        final res = await ApiService.likePost(postId);
        if (res['success'] != true) throw Exception('like failed');
      } else {
        final res = await ApiService.unlikePost(postId);
        if (res['success'] != true) throw Exception('unlike failed');
      }
      // Socket events will reconcile precise likeCount
    } catch (e) {
      // Revert optimistic update on failure
      setState(() {
        if (currentReaction == null) {
          _userPosts[index]['userReaction'] = null;
          _userPosts[index]['reactionsCount'] = currentCount;
        } else {
          _userPosts[index]['userReaction'] = currentReaction;
          _userPosts[index]['reactionsCount'] = currentCount;
        }
      });
    }
  }

  Future<void> _handleSharePost(String postId) async {
    final index = _userPosts.indexWhere((p) =>
        (p is Map<String, dynamic>) && (p['_id']?.toString() == postId));
    if (index == -1) return;

    // Optimistically increment shares count
    final initialShares = _userPosts[index]['sharesCount'] as int? ??
        (_userPosts[index]['shares'] is List
            ? (_userPosts[index]['shares'] as List).length
            : 0);
    setState(() {
      _userPosts[index]['sharesCount'] = initialShares + 1;
    });

    try {
      final res = await ApiService.sharePost(postId: postId, shareType: 'feed');
      if (res['success'] != true) throw Exception('share failed');
      // Socket will notify followers; our author view is already incremented
    } catch (e) {
      // Revert on failure
      setState(() {
        _userPosts[index]['sharesCount'] = initialShares;
      });
    }
  }

  Widget _buildQuickActionButton({
    required dynamic icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isIconString = icon is String;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
        color: backgroundColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isIconString)
                  Text(
                    icon,
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  )
                else
                  Icon(
                    icon as IconData,
                    color: textColor,
                    size: screenWidth * 0.05,
                  ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerHighest,
      highlightColor: isDark
          ? theme.colorScheme.surface
          : theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header shimmer
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar shimmer
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name shimmer
                  Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email shimmer
                  Container(
                    width: 200,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats shimmer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      3,
                      (index) => Column(
                        children: [
                          Container(
                            width: 50,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 60,
                            height: 14,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
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
            const SizedBox(height: 16),
            // Button shimmer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Posts shimmer
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count, VoidCallback? onTap) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    final content = Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8), child: content),
      );
    }

    return content;
  }
}

// Followers Bottom Sheet Widget
class _FollowersBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;

  const _FollowersBottomSheet({required this.userId, required this.userName});

  @override
  State<_FollowersBottomSheet> createState() => _FollowersBottomSheetState();
}

class _FollowersBottomSheetState extends State<_FollowersBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _followers = [];
  final SocketService _socketService = SocketService();

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
      final result = await ApiService.getUserFollowers(widget.userId);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _followers = result['data']['followers'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading followers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: screenHeight * 0.015),
            width: screenWidth * 0.1,
            height: screenHeight * 0.005,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.userName}\'s Followers',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
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
                              size: screenWidth * 0.16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              'No followers yet',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    final userName = user['name'] ?? 'Unknown';
    final userEmail = user['email'] ?? '';
    final userAvatar = user['avatar'];
    final userBio = user['bio'] ?? '';
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: userAvatar != null && userAvatar.toString().isNotEmpty
            ? UrlUtils.getAvatarImageProvider(userAvatar)
            : null,
        child: userAvatar == null || userAvatar.toString().isEmpty
            ? Text(
                userInitials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
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
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: user['_id']),
          ),
        );
      },
    );
  }
}

// Following Bottom Sheet Widget
class _FollowingBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;

  const _FollowingBottomSheet({required this.userId, required this.userName});

  @override
  State<_FollowingBottomSheet> createState() => _FollowingBottomSheetState();
}

class _FollowingBottomSheetState extends State<_FollowingBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _following = [];
  final SocketService _socketService = SocketService();

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
      final result = await ApiService.getUserFollowing(widget.userId);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _following = result['data']['following'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading following: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: screenHeight * 0.015),
            width: screenWidth * 0.1,
            height: screenHeight * 0.005,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.userName} Following',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
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
                              size: screenWidth * 0.16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              'Not following anyone yet',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    final userName = user['name'] ?? 'Unknown';
    final userEmail = user['email'] ?? '';
    final userAvatar = user['avatar'];
    final userBio = user['bio'] ?? '';
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: userAvatar != null && userAvatar.toString().isNotEmpty
            ? UrlUtils.getAvatarImageProvider(userAvatar)
            : null,
        child: userAvatar == null || userAvatar.toString().isEmpty
            ? Text(
                userInitials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
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
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: user['_id']),
          ),
        );
      },
    );
  }
}

// Report User Dialog Widget
class _ReportUserDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const _ReportUserDialog({
    required this.userId,
    required this.userName,
  });

  @override
  State<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<_ReportUserDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, String> _reportReasons = {
    'spam': 'Spam',
    'harassment': 'Harassment or Bullying',
    'hate_speech': 'Hate Speech',
    'inappropriate_content': 'Inappropriate Content',
    'fake_account': 'Fake Account',
    'impersonation': 'Impersonation',
    'other': 'Other',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a reason for reporting'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.reportUser(
        widget.userId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (!mounted) return;

      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ??
                  'Report submitted successfully. Our team will review it shortly.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit report'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);

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
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report ${widget.userName}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this user?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Report reasons list
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (value) {
                if (!_isSubmitting && value != null) {
                  setState(() => _selectedReason = value);
                }
              },
              child: Column(
                children: _reportReasons.entries.map((entry) {
                  return ListTile(
                    leading: Radio<String>(
                      value: entry.key,
                    ),
                    title: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: _isSubmitting
                        ? null
                        : () {
                            setState(() => _selectedReason = entry.key);
                          },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Additional details
            const Text(
              'Additional details (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Provide more information about your report...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),
            Text(
              'Your report will be reviewed by our team. False reports may result in account restrictions.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onError,
                    ),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
