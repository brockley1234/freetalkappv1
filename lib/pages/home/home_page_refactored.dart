import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/cache_service.dart';
import '../../services/global_notification_service.dart';
import '../../services/realtime_update_service.dart';
import '../../utils/app_logger.dart';
import '../loginpage.dart';
import '../post_detail_page.dart';
import '../conversations_page.dart';
import '../user_profile_page.dart';
import '../videos_page.dart';
import '../marketplace/marketplace_listings_page.dart';
import '../create_post_page.dart';
import 'controllers/feed_controller.dart';
import 'feed/feed_view.dart';
import 'search/search_view.dart';
import 'notifications/notifications_view.dart';
import 'profile/profile_overview.dart';

/// Refactored HomePage with modular components
/// This replaces the massive 11,680 line homepage.dart with a clean, maintainable structure
class HomePageRefactored extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomePageRefactored({super.key, this.user});

  @override
  State<HomePageRefactored> createState() => _HomePageRefactoredState();
}

class _HomePageRefactoredState extends State<HomePageRefactored> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentUser;
  List<dynamic> _stories = [];
  int _unreadNotificationCount = 0;
  int _unreadMessageCount = 0;
  bool _isSocketConnected = false;

  // Controllers
  late FeedController _feedController;

  // Socket listeners
  Function(dynamic)? _notificationListener;
  Function(dynamic)? _unreadCountListener;
  Function(bool)? _connectionStatusListener;

  // Timers for cleanup
  Timer? _storiesTimer;
  Timer? _unreadCountTimer;
  Timer? _unreadMessageTimer;

  @override
  void initState() {
    super.initState();
    _feedController = FeedController();
    _initializeApp();
  }

  @override
  void dispose() {
    _cleanupSocketListeners();
    _storiesTimer?.cancel();
    _unreadCountTimer?.cancel();
    _unreadMessageTimer?.cancel();
    _feedController.dispose();
    super.dispose();
  }

  /// Initialize app: load data, setup socket, etc.
  Future<void> _initializeApp() async {
    await _initializeSocket();
    await _loadCachedData();
    await _loadUserProfile();
    await _feedController.initialize();
    
    // Defer non-critical loads
    _storiesTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadStories();
    });
    
    _unreadCountTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _loadUnreadCounts();
    });
  }

  /// Initialize socket connection
  Future<void> _initializeSocket() async {
    try {
      final socketService = SocketService();
      await socketService.connect();

      setState(() {
        _isSocketConnected = socketService.isConnected;
      });

      _setupSocketListeners();

      // Initialize global services
      GlobalNotificationService().initialize();
      RealtimeUpdateService().initialize();
    } catch (e) {
      AppLogger.e('Error initializing socket: $e');
    }
  }

  /// Setup socket listeners
  void _setupSocketListeners() {
    final socketService = SocketService();

    // Connection status
    _connectionStatusListener = (isConnected) {
      if (mounted) {
        setState(() {
          _isSocketConnected = isConnected;
        });
      }
    };
    socketService.addConnectionStatusListener(_connectionStatusListener!);

    // Notifications
    _notificationListener = (data) {
      if (mounted && data != null) {
        setState(() {
          _unreadNotificationCount++;
        });
      }
    };
    socketService.on('notification:new', _notificationListener!);

    // Unread count
    _unreadCountListener = (data) {
      if (mounted && data != null && data['count'] != null) {
        setState(() {
          _unreadNotificationCount = data['count'];
        });
      }
    };
    socketService.on('notification:unread_count', _unreadCountListener!);

    // Setup message count callback
    GlobalNotificationService().onUnreadMessageCountChanged = (increment) {
      if (mounted) {
        setState(() {
          _unreadMessageCount += increment;
          if (_unreadMessageCount < 0) _unreadMessageCount = 0;
        });
      }
    };
  }

  /// Cleanup socket listeners
  void _cleanupSocketListeners() {
    final socketService = SocketService();

    if (_notificationListener != null) {
      socketService.off('notification:new', _notificationListener);
    }
    if (_unreadCountListener != null) {
      socketService.off('notification:unread_count', _unreadCountListener);
    }
    if (_connectionStatusListener != null) {
      socketService.removeConnectionStatusListener(_connectionStatusListener!);
    }

    GlobalNotificationService().onUnreadMessageCountChanged = null;
  }

  /// Load cached data
  Future<void> _loadCachedData() async {
    try {
      final cacheService = CacheService();
      final cachedUser = await cacheService.getCachedUserProfile();
      final cachedStories = await cacheService.getCachedStories();

      if (mounted) {
        setState(() {
          if (cachedUser != null) _currentUser = cachedUser;
          if (cachedStories != null) _stories = cachedStories;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading cached data: $e');
    }
  }

  /// Load user profile
  Future<void> _loadUserProfile() async {
    try {
      final result = await ApiService.getCurrentUser();
      if (result['success'] == true && mounted) {
        setState(() {
          _currentUser = result['data'];
        });

        // Cache profile
        final cacheService = CacheService();
        await cacheService.cacheUserProfile(_currentUser!);
      }
    } catch (e) {
      AppLogger.e('Error loading user profile: $e');
    }
  }

  /// Load stories
  Future<void> _loadStories() async {
    try {
      final result = await ApiService.getStories();
      if (result['success'] == true && mounted) {
        setState(() {
          _stories = result['data'] ?? [];
        });

        // Cache stories
        final cacheService = CacheService();
        await cacheService.cacheStories(_stories);
      }
    } catch (e) {
      AppLogger.e('Error loading stories: $e');
    }
  }

  /// Load unread counts
  Future<void> _loadUnreadCounts() async {
    try {
      // Load notification count
      final notificationResult = await ApiService.getUnreadNotificationCount();
      if (notificationResult['success'] == true && mounted) {
        setState(() {
          _unreadNotificationCount = notificationResult['data'] ?? 0;
        });
      }

      // Load message count  
      final messageResult = await ApiService.getUnreadCount();
      if (messageResult['success'] == true && mounted) {
        setState(() {
          _unreadMessageCount = messageResult['data']?['unreadMessagesCount'] ?? 0;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading unread counts: $e');
    }
  }

  /// Handle logout
  Future<void> _logout() async {
    try {
      await ApiService.logout();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      AppLogger.e('Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _feedController,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: _selectedIndex == 0 ? _buildFAB() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_getAppBarTitle()),
      actions: [
        // Connection status indicator
        if (!_isSocketConnected)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.cloud_off,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        
        // Messages icon
        IconButton(
          icon: Badge(
            isLabelVisible: _unreadMessageCount > 0,
            label: Text('$_unreadMessageCount'),
            child: const Icon(Icons.message),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConversationsPage(),
              ),
            );
          },
        ),
        
        // Menu
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'videos':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VideosPage(),
                  ),
                );
                break;
              case 'marketplace':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MarketplaceListingsPage(),
                  ),
                );
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'videos',
              child: Row(
                children: [
                  Icon(Icons.video_library),
                  SizedBox(width: 12),
                  Text('Videos'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'marketplace',
              child: Row(
                children: [
                  Icon(Icons.shopping_bag),
                  SizedBox(width: 12),
                  Text('Marketplace'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 12),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Feed';
      case 1:
        return 'Search';
      case 2:
        return 'Notifications';
      case 3:
        return 'Profile';
      default:
        return 'ReelTalk';
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return FeedView(
          currentUser: _currentUser,
          stories: _stories,
          onCreatePost: _navigateToCreatePost,
          onPostTap: _navigateToPostDetail,
          onUserTap: _navigateToUserProfile,
        );
      case 1:
        return SearchView(
          currentUser: _currentUser,
          onUserTap: _navigateToUserProfile,
          onPostTap: _navigateToPostDetail,
        );
      case 2:
        return NotificationsView(
          currentUser: _currentUser,
          onUserTap: _navigateToUserProfile,
          onPostTap: _navigateToPostDetail,
        );
      case 3:
        return ProfileOverview(
          currentUser: _currentUser,
          onPostTap: _navigateToPostDetail,
          onUserTap: _navigateToUserProfile,
          onProfileUpdated: _loadUserProfile,
        );
      default:
        return const Center(child: Text('Unknown page'));
    }
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
        
        // Clear notification count when viewing notifications
        if (index == 2) {
          setState(() {
            _unreadNotificationCount = 0;
          });
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _unreadNotificationCount > 0,
            label: Text('$_unreadNotificationCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: _unreadNotificationCount > 0,
            label: Text('$_unreadNotificationCount'),
            child: const Icon(Icons.notifications),
          ),
          label: 'Notifications',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget? _buildFAB() {
    return FloatingActionButton(
      onPressed: _navigateToCreatePost,
      child: const Icon(Icons.add),
    );
  }

  // Navigation methods
  void _navigateToCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostBottomSheet(
        currentUser: _currentUser,
      ),
    ).then((_) {
      // Refresh feed after creating a post
      _feedController.refresh();
    });
  }

  void _navigateToPostDetail(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(postId: postId),
      ),
    );
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }
}

