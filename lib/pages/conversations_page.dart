import 'package:flutter/material.dart';
import 'dart:async';
import '../services/messaging_service.dart';
import '../services/socket_service.dart';
import '../services/secure_storage_service.dart';
import '../services/global_notification_service.dart';
import '../utils/url_utils.dart';
import '../utils/time_utils.dart';
import '../utils/responsive_dimensions.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';
import 'user_profile_page.dart';
import 'create_group_page.dart';
import 'friend_search_page.dart';
import '../widgets/animated_emoji_widget.dart';
import 'package:flutter/services.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage>
    with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _totalUnread = 0;
  late AnimationController _refreshAnimationController;

  // Search and filtering
  late TextEditingController _searchController;
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Tabs/filters
  String _activeFilter = 'All'; // All, Unread, Groups, Archived

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Multi-select
  bool _isSelectionMode = false;
  final Set<String> _selectedConversationIds = {};

  // Streak cache: userId -> streakCount
  final Map<String, int?> _streakCache = {};
  String? _currentUserId;

  // Socket listeners
  Function(dynamic)? _messageListener;
  Function(dynamic)? _unreadCountListener;

  // Cache expiration times (in seconds)
  static const int _cacheExpirationSeconds = 300; // 5 minutes
  final Map<String, DateTime> _cacheTimestamps = {};

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _loadCurrentUser();
    _loadConversations();
    _setupSocketListeners();

    // Infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreConversations();
      }
    });
  }

  void _onSearchChanged() {
    // Debounce search to reduce rebuilds
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final query = _searchController.text.toLowerCase().trim();
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        _updateFilteredConversations();
      });
    });
  }

  void _updateFilteredConversations() {
    Iterable<Map<String, dynamic>> list = _conversations;

    // Apply tab filter
    switch (_activeFilter) {
      case 'Unread':
        list = list.where((c) => (c['unreadCount'] as int? ?? 0) > 0);
        break;
      case 'Groups':
        list = list.where((c) => (c['isGroup'] as bool? ?? false));
        break;
      case 'Archived':
        list = list.where((c) => (c['isArchived'] as bool? ?? false));
        break;
      default:
        // All
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((conv) {
        final isGroup = conv['isGroup'] as bool? ?? false;
        final displayName = isGroup
            ? (conv['groupName'] as String? ?? 'Group Chat').toLowerCase()
            : (conv['otherUser']?['name'] as String? ?? 'Unknown')
                .toLowerCase();
        return displayName.contains(_searchQuery);
      });
    }

    _filteredConversations = List<Map<String, dynamic>>.from(list);
  }

  Future<void> _loadCurrentUser() async {
    final userId = await SecureStorageService().getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  Future<int?> _loadStreakForUser(String otherUserId) async {
    // Check if cache is still valid
    if (_streakCache.containsKey(otherUserId) &&
        _cacheTimestamps.containsKey(otherUserId)) {
      final cacheTime = _cacheTimestamps[otherUserId]!;
      final now = DateTime.now();
      if (now.difference(cacheTime).inSeconds < _cacheExpirationSeconds) {
        return _streakCache[otherUserId];
      }
    }

    if (_currentUserId == null) {
      return null;
    }

    try {
      final token = await SecureStorageService().getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/streaks/between/$_currentUserId/$otherUserId',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final streak = jsonData['data'];
        final streakCount = streak?['streakCount'] as int? ?? 0;

        // Update cache with timestamp
        _streakCache[otherUserId] = streakCount > 0 ? streakCount : null;
        _cacheTimestamps[otherUserId] = DateTime.now();

        return streakCount > 0 ? streakCount : null;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading streak for $otherUserId: $e');
      return null;
    }
  }

  void _setupSocketListeners() {
    // Listen for new messages - update conversation without full reload
    // to prevent race conditions with unread count updates
    _messageListener = (data) {
      if (mounted && data != null && data['message'] != null) {
        final message = data['message'];
        final conversationId = message['conversation']?.toString();

        if (conversationId != null) {
          setState(() {
            // Find and update the specific conversation
            final index = _conversations.indexWhere(
              (conv) => conv['_id']?.toString() == conversationId,
            );

            if (index != -1) {
              // Update last message and timestamp
              _conversations[index]['lastMessage'] = message;
              _conversations[index]['lastMessageAt'] = message['createdAt'];

              // Move conversation to top of list
              final conv = _conversations.removeAt(index);
              _conversations.insert(0, conv);

              // Update filtered list
              _updateFilteredConversations();

              debugPrint(
                  '💬 Updated conversation $conversationId with new message');
            } else {
              // New conversation - reload to fetch it
              _loadConversations();
            }
          });
        }
      }
    };
    _socketService.on('message:new', _messageListener!);

    // Listen for unread count updates - update specific conversation
    _unreadCountListener = (data) {
      if (mounted && data != null) {
        final conversationId = data['conversationId']?.toString();
        final unreadCount = data['unreadCount'] as int?;

        if (conversationId != null && unreadCount != null) {
          setState(() {
            // Find and update the specific conversation
            final index = _conversations.indexWhere(
              (conv) => conv['_id']?.toString() == conversationId,
            );

            if (index != -1) {
              final oldUnreadCount =
                  _conversations[index]['unreadCount'] as int? ?? 0;
              _conversations[index]['unreadCount'] = unreadCount;

              // Update total unread count
              _totalUnread = _totalUnread - oldUnreadCount + unreadCount;

              // Ensure count never goes below 0
              if (_totalUnread < 0) {
                _totalUnread = 0;
              }
            }
          });
        }
      }
    };
    _socketService.on('message:unread-count', _unreadCountListener!);

    // Listen for user status changes
    _socketService.on('user:status-changed', (data) {
      if (mounted && data != null) {
        final userId = data['userId']?.toString();
        final isOnline = data['isOnline'] as bool?;
        final lastActive = data['lastActive'] as String?;

        if (userId != null) {
          setState(() {
            // Update all conversations with this user
            for (var conversation in _conversations) {
              final otherUser =
                  conversation['otherUser'] as Map<String, dynamic>?;
              if (otherUser != null && otherUser['_id']?.toString() == userId) {
                otherUser['isOnline'] = isOnline ?? false;
                otherUser['lastActive'] = lastActive;
                debugPrint('👤 Updated user $userId status: online=$isOnline');
              }
            }
          });
        }
      }
    });

    // Listen for block events - remove conversation with blocked user immediately
    _socketService.on('user:blocked', (data) {
      debugPrint('🚫 User blocked event in conversations page: $data');
      if (mounted && data != null) {
        final blockedUserId = data['blockedUserId']?.toString();

        if (blockedUserId != null) {
          setState(() {
            // Remove conversations with the blocked user
            _conversations.removeWhere((conversation) {
              final otherUser =
                  conversation['otherUser'] as Map<String, dynamic>?;
              if (otherUser != null &&
                  otherUser['_id']?.toString() == blockedUserId) {
                // Update unread count before removing
                final unreadCount = conversation['unreadCount'] as int? ?? 0;
                _totalUnread = _totalUnread - unreadCount;
                if (_totalUnread < 0) _totalUnread = 0;

                debugPrint(
                  '🚫 Removed conversation with blocked user: ${otherUser['name']}',
                );
                return true;
              }
              return false;
            });
          });
        }
      }
    });

    // Listen for unblock events - reload conversation list
    _socketService.on('user:unblocked', (data) {
      debugPrint('✅ User unblocked event in conversations page: $data');
      if (mounted) {
        // Reload conversations to show any existing conversations with unblocked user
        _loadConversations();
      }
    });

    // Listen for group creation - reload conversation list
    _socketService.on('group:created', (data) {
      debugPrint('👥 New group created: $data');
      if (mounted) {
        _loadConversations();
      }
    });

    // Listen for group updates - update specific conversation
    _socketService.on('group:updated', (data) {
      debugPrint('👥 Group updated: $data');
      if (mounted && data != null) {
        final conversationId = data['conversationId']?.toString();
        final groupName = data['groupName'] as String?;
        final groupDescription = data['groupDescription'] as String?;
        final groupAvatar = data['groupAvatar'] as String?;

        if (conversationId != null) {
          setState(() {
            final index = _conversations.indexWhere(
              (conv) => conv['_id']?.toString() == conversationId,
            );

            if (index != -1) {
              if (groupName != null) {
                _conversations[index]['groupName'] = groupName;
              }
              if (groupDescription != null) {
                _conversations[index]['groupDescription'] = groupDescription;
              }
              if (groupAvatar != null) {
                _conversations[index]['groupAvatar'] = groupAvatar;
              }
              debugPrint('👥 ✅ Updated group info in conversation list');
            }
          });
        }
      }
    });

    // Listen for participants added to group
    _socketService.on('group:participant-added', (data) {
      debugPrint('👥 Participant added to group: $data');
      if (mounted) {
        _loadConversations(); // Reload to get updated participant list
      }
    });

    // Listen for participants removed from group
    _socketService.on('group:participant-removed', (data) {
      debugPrint('👥 Participant removed from group: $data');
      if (mounted) {
        _loadConversations(); // Reload to get updated participant list
      }
    });

    // Listen for being removed from a group
    _socketService.on('group:removed', (data) {
      debugPrint('👥 You were removed from a group: $data');
      if (mounted && data != null) {
        final conversationId = data['conversationId']?.toString();

        if (conversationId != null) {
          setState(() {
            // Remove the group from the conversation list
            _conversations.removeWhere(
              (conv) => conv['_id']?.toString() == conversationId,
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have been removed from a group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Future<void> _loadConversations() async {
    // Start refresh animation if manually triggered
    if (!_isLoading && mounted) {
      setState(() => _isRefreshing = true);
      _refreshAnimationController.repeat();
      // Haptic feedback for refresh
      HapticFeedback.mediumImpact();
    } else {
      setState(() => _isLoading = true);
    }

    // Reset pagination
    _currentPage = 1;
    _hasMore = true;
    final result = await MessagingService.getConversations(
      page: _currentPage,
      limit: _pageSize,
    );

    if (mounted) {
      // Stop animation
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();

      if (result['success'] == true) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(
            result['data']['conversations'] ?? [],
          );
          _updateFilteredConversations();
          _totalUnread = result['data']['totalUnread'] ?? 0;
          _isLoading = false;
          _isRefreshing = false;
          final count = (_conversations).length;
          _hasMore = count >= _pageSize;
        });
        // Haptic feedback for successful refresh
        HapticFeedback.lightImpact();
      } else {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMoreConversations() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    final result = await MessagingService.getConversations(
      page: nextPage,
      limit: _pageSize,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final newItems = List<Map<String, dynamic>>.from(
        result['data']['conversations'] ?? [],
      );
      setState(() {
        _currentPage = nextPage;
        _conversations.addAll(newItems);
        _hasMore = newItems.length >= _pageSize;
        _updateFilteredConversations();
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  void _showNewConversationOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'New Conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.blue),
              title: const Text('Start Conversation'),
              subtitle: const Text('Message a friend'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSelectUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: Colors.purple),
              title: const Text('Create Group'),
              subtitle: const Text('Message multiple people'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCreateGroup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToSelectUser() async {
    // Navigate to user search/selection page
    final selectedUser = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendSearchPage(),
      ),
    );

    if (selectedUser != null && mounted) {
      // Create or navigate to conversation with selected user
      final userId = selectedUser['_id'];
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Invalid user selected')),
          );
        }
        return;
      }

      final result = await MessagingService.getOrCreateConversation(userId);

      if (mounted) {
        if (result['success'] == true) {
          final conversationId = result['data']?['conversationId'];
          if (conversationId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Failed to create conversation')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                conversationId: conversationId,
                otherUser: selectedUser,
              ),
            ),
          ).then((_) => _loadConversations());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showConversationOptions(
    Map<String, dynamic> conversation,
    String displayName,
    bool isGroup,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(
                isGroup ? 'Leave Group' : 'Delete Conversation',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteConversation(conversation, displayName, isGroup);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    Map<String, dynamic> conversation,
    String displayName,
    bool isGroup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGroup ? 'Leave Group' : 'Delete Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGroup
                  ? 'Are you sure you want to leave the group "$displayName"?'
                  : 'Are you sure you want to delete this conversation with $displayName?',
            ),
            const SizedBox(height: 12),
            Text(
              isGroup
                  ? 'You will stop receiving messages from this group. Other members can still see all messages.'
                  : 'This will only delete the conversation for you. $displayName will still have access to all messages.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isGroup ? 'Leave' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Store conversation info before removing from list
      final conversationId = conversation['_id'];
      final conversationName = displayName;
      final unreadForConversation = conversation['unreadCount'] as int? ?? 0;

      // Optimistically remove from UI
      setState(() {
        _conversations.removeWhere((c) => c['_id'] == conversationId);
        _totalUnread -= unreadForConversation;
      });

      // Call API to delete conversation
      final result = await MessagingService.deleteConversation(
        conversationId: conversationId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Notify HomePage about the unread count decrease
        if (unreadForConversation > 0) {
          final notificationService = GlobalNotificationService();
          // Send negative increment to notify parent about the reduction
          notificationService.onUnreadMessageCountChanged
              ?.call(-unreadForConversation);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isGroup
                  ? 'Left group "$conversationName"'
                  : 'Conversation with $conversationName deleted',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // If failed, reload conversations to restore state
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete conversation: ${result['message']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        _loadConversations();
      }
    }
  }

  Future<void> _navigateToCreateGroup() async {
    final newGroup = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    );

    if (newGroup != null && mounted) {
      // Group was created successfully
      debugPrint('📱 Group created: ${newGroup['groupName']}');

      // Reload conversations to show the new group
      await _loadConversations();

      // Navigate to the group chat
      // For groups, we'll use the group info as the "otherUser" for now
      // You may want to create a separate GroupChatPage later
      if (mounted) {
        final conversationId = newGroup['_id'] as String;

        // Create a pseudo user object for the group
        final groupAsUser = {
          '_id': conversationId,
          'name': newGroup['groupName'] ?? 'Group Chat',
          'fullName': newGroup['groupName'] ?? 'Group Chat',
          'avatar': newGroup['groupAvatar'],
          'isGroup': true,
          'participants': newGroup['participants'],
          'admins': newGroup['admins'],
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId,
              otherUser: groupAsUser,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Modern gradient app bar
          SliverAppBar(
            expandedHeight:
                ResponsiveDimensions.getHeadingFontSize(context) * 3.5,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveDimensions.getHorizontalPadding(context),
                      ResponsiveDimensions.getVerticalPadding(context),
                      ResponsiveDimensions.getHorizontalPadding(context),
                      ResponsiveDimensions.getVerticalPadding(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Messages',
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveDimensions.getHeadingFontSize(
                                          context),
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            // Add conversation button
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.surface,
                                size: ResponsiveDimensions.getLargeIconSize(
                                    context),
                              ),
                              onPressed: _showNewConversationOptions,
                              tooltip: 'New conversation',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            SizedBox(
                                width: ResponsiveDimensions.getItemSpacing(
                                        context) /
                                    2),
                            // Refresh button
                            IconButton(
                              icon: RotationTransition(
                                turns: _refreshAnimationController,
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: ResponsiveDimensions.getLargeIconSize(
                                      context),
                                ),
                              ),
                              onPressed: (_isLoading || _isRefreshing)
                                  ? null
                                  : _loadConversations,
                              tooltip: 'Refresh conversations',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            SizedBox(
                                width: ResponsiveDimensions.getItemSpacing(
                                    context)),
                            if (_totalUnread > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveDimensions.getHorizontalPadding(
                                          context),
                                  vertical:
                                      ResponsiveDimensions.getVerticalPadding(
                                              context) /
                                          2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveDimensions.getBorderRadius(
                                        context),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.4),
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
                                      size: ResponsiveDimensions.getIconSize(
                                              context) *
                                          0.8,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    SizedBox(
                                        width:
                                            ResponsiveDimensions.getItemSpacing(
                                                    context) /
                                                3),
                                    Text(
                                      _totalUnread > 99
                                          ? '99+'
                                          : '$_totalUnread',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: ResponsiveDimensions
                                            .getCaptionFontSize(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: ResponsiveDimensions.getVerticalPadding(context)),
                        // Tabs / Filters
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in const ['All', 'Unread', 'Groups', 'Archived'])
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: ResponsiveDimensions.getItemSpacing(context) / 2,
                                  ),
                                  child: ChoiceChip(
                                    selected: _activeFilter == tab,
                                    label: Text(
                                      tab,
                                      style: TextStyle(
                                        color: _activeFilter == tab
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    onSelected: (sel) {
                                      setState(() {
                                        _activeFilter = tab;
                                        _updateFilteredConversations();
                                      });
                                    },
                                  ),
                                ),
                              const Spacer(),
                              // Mark all read
                              if (_totalUnread > 0)
                                TextButton.icon(
                                  onPressed: _markAllAsRead,
                                  icon: const Icon(Icons.mark_email_read, color: Colors.white),
                                  label: Text(
                                    'Mark all read', 
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
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
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveDimensions.getHorizontalPadding(context),
                  ResponsiveDimensions.getVerticalPadding(context) * 1.2,
                  ResponsiveDimensions.getHorizontalPadding(context),
                  ResponsiveDimensions.getVerticalPadding(context),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _updateFilteredConversations();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveDimensions.getBorderRadius(context) * 1.3,
                      ),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveDimensions.getBorderRadius(context) * 1.3,
                      ),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveDimensions.getBorderRadius(context) * 1.3,
                      ),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveDimensions.getHorizontalPadding(context) /
                              1.5,
                      vertical:
                          ResponsiveDimensions.getVerticalPadding(context),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content with white rounded top
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading conversations...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if ((_searchQuery.isEmpty
                  ? _conversations
                  : _filteredConversations)
              .isEmpty)
            SliverFillRemaining(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ResponsiveDimensions.getHorizontalPadding(context) * 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveDimensions.getHorizontalPadding(context) *
                                2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(context).colorScheme.secondaryContainer,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.chat_bubble_outline,
                            size:
                                ResponsiveDimensions.getLargeIconSize(context) *
                                    1.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(
                            height: ResponsiveDimensions.getVerticalPadding(
                                    context) *
                                2),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matches found'
                              : 'No conversations yet',
                          style: TextStyle(
                            fontSize:
                                ResponsiveDimensions.getSubheadingFontSize(
                                    context),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(
                            height: ResponsiveDimensions.getVerticalPadding(
                                context)),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try searching with a different name'
                              : 'Start a new conversation or\ncreate a group to get started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                ResponsiveDimensions.getBodyFontSize(context),
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
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
                    const SizedBox(height: 8),
                    // Conversations Section
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveDimensions.getHorizontalPadding(context),
                        vertical:
                            ResponsiveDimensions.getVerticalPadding(context),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              ResponsiveDimensions.getVerticalPadding(context),
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                ResponsiveDimensions.getBorderRadius(context),
                              ),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: Theme.of(context).colorScheme.secondary,
                              size: ResponsiveDimensions.getIconSize(context),
                            ),
                          ),
                          SizedBox(
                              width:
                                  ResponsiveDimensions.getItemSpacing(context)),
                          Text(
                            'Conversations',
                            style: TextStyle(
                              fontSize:
                                  ResponsiveDimensions.getSubheadingFontSize(
                                      context),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: Column(
                        children: [
                          ...(_searchQuery.isEmpty
                                  ? _conversations
                                  : _filteredConversations)
                              .map(_buildConversationTile),
                          if (_isLoadingMore)
                            Padding(
                              padding: EdgeInsets.all(
                                ResponsiveDimensions.getHorizontalPadding(context),
                              ),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                          if (!_hasMore && (_conversations.isNotEmpty))
                            Padding(
                              padding: EdgeInsets.all(
                                ResponsiveDimensions.getHorizontalPadding(context),
                              ),
                              child: Center(
                                child: Text(
                                  'No more conversations',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _showBulkActions,
              icon: const Icon(Icons.build),
              label: Text('${_selectedConversationIds.length} selected'),
            )
          : null,
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final isGroup = conversation['isGroup'] as bool? ?? false;
    final otherUser = conversation['otherUser'] as Map<String, dynamic>?;
    final lastMessage = conversation['lastMessage'] as Map<String, dynamic>?;
    final unreadCount = conversation['unreadCount'] as int? ?? 0;
    final isOnline = otherUser?['isOnline'] as bool? ?? false;
    final lastActive = otherUser?['lastActive'] as String?;

    // For groups, use group info instead of otherUser
    final displayName = isGroup
        ? (conversation['groupName'] as String? ?? 'Group Chat')
        : (otherUser?['name'] as String? ?? 'Unknown');

    final displayAvatar = isGroup
        ? conversation['groupAvatar'] as String?
        : otherUser?['avatar'] as String?;

    if (!isGroup && otherUser == null) return const SizedBox.shrink();

    final conversationIdStr = conversation['_id'].toString();
    final isSelected = _selectedConversationIds.contains(conversationIdStr);
    return Dismissible(
      key: Key(conversation['_id'].toString()),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.blue,
        child: const Icon(Icons.mark_email_read, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Mark read/unread toggle
          final currentlyUnread = (conversation['unreadCount'] as int? ?? 0) > 0;
          if (currentlyUnread) {
            await _markConversationAsRead(conversation);
            return false; // Do not remove tile
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Already read')),
            );
            return false;
          }
        }
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isGroup ? 'Leave Group' : 'Delete Conversation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGroup
                      ? 'Are you sure you want to leave the group "$displayName"?'
                      : 'Are you sure you want to delete this conversation with $displayName?',
                ),
                const SizedBox(height: 12),
                Text(
                  isGroup
                      ? 'You will stop receiving messages from this group. Other members can still see all messages.'
                      : 'This will only delete the conversation for you. $displayName will still have access to all messages.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  isGroup ? 'Leave' : 'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        // Store conversation info before removing from list
        final conversationId = conversation['_id'];
        final conversationName = displayName;
        final unreadForConversation = unreadCount;

        // Optimistically remove from UI
        setState(() {
          _conversations.removeWhere((c) => c['_id'] == conversationId);
          _totalUnread -= unreadForConversation;
        });

        // Call API to delete conversation
        final result = await MessagingService.deleteConversation(
          conversationId: conversationId,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isGroup
                    ? 'Left group "$conversationName"'
                    : 'Conversation with $conversationName deleted',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // If failed, reload conversations to restore state
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete conversation: ${result['message']}',
              ),
              backgroundColor: Colors.red,
            ),
          );
          _loadConversations();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveDimensions.getHorizontalPadding(context),
          vertical: ResponsiveDimensions.getVerticalPadding(context) / 2,
        ),
        decoration: BoxDecoration(
          color: unreadCount > 0
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(
            ResponsiveDimensions.getBorderRadius(context) * 1.3,
          ),
          border: Border.all(
            color: unreadCount > 0
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: unreadCount > 0 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: unreadCount > 0
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: unreadCount > 0 ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ResponsiveDimensions.getBorderRadius(context) * 1.3,
          ),
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedConversationIds.add(conversationIdStr);
              });
            } else {
              _showConversationOptions(conversation, displayName, isGroup);
            }
          },
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedConversationIds.remove(conversationIdStr);
                  if (_selectedConversationIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedConversationIds.add(conversationIdStr);
                }
              });
              return;
            }
            // Prepare the user/group data for ChatPage
            final chatUser = isGroup
                ? {
                    '_id': conversation['_id'],
                    'name': displayName,
                    'fullName': displayName,
                    'avatar': displayAvatar,
                    'isGroup': true,
                    'participants': conversation['participants'],
                    'admins': conversation['admins'],
                  }
                : otherUser!;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  conversationId: conversation['_id'],
                  otherUser: chatUser,
                ),
              ),
            ).then((_) => _loadConversations());
          },
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveDimensions.getHorizontalPadding(context),
            ),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: EdgeInsets.only(
                      right: ResponsiveDimensions.getItemSpacing(context) / 2,
                    ),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedConversationIds.add(conversationIdStr);
                          } else {
                            _selectedConversationIds.remove(conversationIdStr);
                            if (_selectedConversationIds.isEmpty) {
                              _isSelectionMode = false;
                            }
                          }
                        });
                      },
                    ),
                  ),
                // Avatar
                GestureDetector(
                  onTap: isGroup
                      ? null
                      : () {
                          // Navigate to user profile (not available for groups)
                          if (otherUser != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfilePage(userId: otherUser['_id']),
                              ),
                            );
                          }
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isGroup
                          ? LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: (isGroup
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius:
                              ResponsiveDimensions.getAvatarSize(context) / 2,
                          backgroundImage: displayAvatar != null
                              ? NetworkImage(
                                  UrlUtils.getFullAvatarUrl(displayAvatar),
                                )
                              : null,
                          backgroundColor: isGroup
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: displayAvatar == null
                              ? Icon(
                                  isGroup ? Icons.group : Icons.person,
                                  size: ResponsiveDimensions.getAvatarSize(
                                          context) /
                                      2 *
                                      0.6,
                                  color: isGroup
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        // Online status indicator (only for 1-on-1 chats)
                        if (!isGroup && isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: ResponsiveDimensions.getIconSize(context) *
                                  0.7,
                              height:
                                  ResponsiveDimensions.getIconSize(context) *
                                      0.7,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveDimensions.getItemSpacing(context)),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isGroup)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    ResponsiveDimensions.getHorizontalPadding(
                                            context) /
                                        3,
                                vertical:
                                    ResponsiveDimensions.getVerticalPadding(
                                            context) /
                                        3,
                              ),
                              margin: EdgeInsets.only(
                                right: ResponsiveDimensions.getItemSpacing(
                                    context),
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveDimensions.getBorderRadius(
                                          context) *
                                      0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group,
                                    size: ResponsiveDimensions.getIconSize(
                                            context) *
                                        0.6,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  SizedBox(
                                      width:
                                          ResponsiveDimensions.getItemSpacing(
                                                  context) /
                                              4),
                                  Text(
                                    'Group',
                                    style: TextStyle(
                                      fontSize: ResponsiveDimensions
                                              .getCaptionFontSize(context) *
                                          0.85,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize:
                                          ResponsiveDimensions.getBodyFontSize(
                                              context),
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Streak indicator for 1-on-1 chats
                                if (!isGroup)
                                  FutureBuilder<int?>(
                                    future: _loadStreakForUser(
                                        otherUser?['_id'] ?? ''),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data != null &&
                                          snapshot.data! > 0) {
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            left: ResponsiveDimensions
                                                    .getItemSpacing(context) /
                                                2,
                                          ),
                                          child: Tooltip(
                                            message:
                                                '${snapshot.data} day streak!',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AnimatedEmojiWidget(
                                                  emoji: '🔥',
                                                  size: ResponsiveDimensions
                                                          .getIconSize(
                                                              context) *
                                                      0.6,
                                                  animationType:
                                                      EmojiAnimationType.pulse,
                                                  repeat: true,
                                                  animationDuration:
                                                      const Duration(
                                                          milliseconds: 1000),
                                                ),
                                                SizedBox(
                                                    width: ResponsiveDimensions
                                                            .getItemSpacing(
                                                                context) /
                                                        4),
                                                Text(
                                                  '${snapshot.data}',
                                                  style: TextStyle(
                                                    fontSize: ResponsiveDimensions
                                                            .getCaptionFontSize(
                                                                context) *
                                                        0.9,
                                                    color: Theme.of(context).colorScheme.tertiary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height:
                              ResponsiveDimensions.getVerticalPadding(context) /
                                  2),
                      _buildLastMessagePreview(
                        lastMessage,
                        unreadCount,
                        isOnline,
                        lastActive,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ResponsiveDimensions.getItemSpacing(context)),
                // Time and badge
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (conversation['lastMessageAt'] != null)
                      Text(
                        TimeUtils.formatMessageTimestamp(
                          conversation['lastMessageAt']?.toString(),
                        ),
                        style: TextStyle(
                          fontSize:
                              ResponsiveDimensions.getCaptionFontSize(context) *
                                  0.9,
                          color: unreadCount > 0
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    if (unreadCount > 0) ...[
                      SizedBox(
                          height:
                              ResponsiveDimensions.getVerticalPadding(context) *
                                  0.75),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveDimensions.getHorizontalPadding(
                                  context) /
                              2,
                          vertical:
                              ResponsiveDimensions.getVerticalPadding(context) /
                                  2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveDimensions.getBorderRadius(context) * 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: ResponsiveDimensions.getCaptionFontSize(
                                    context) *
                                0.9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(
                    width: ResponsiveDimensions.getItemSpacing(context) / 2),
                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: ResponsiveDimensions.getIconSize(context),
                  ),
                  onPressed: () {
                    _confirmDeleteConversation(
                        conversation, displayName, isGroup);
                  },
                  tooltip: isGroup ? 'Leave Group' : 'Delete Conversation',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth:
                        ResponsiveDimensions.getButtonHeight(context) * 0.75,
                    minHeight:
                        ResponsiveDimensions.getButtonHeight(context) * 0.75,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose animation controller
    _refreshAnimationController.dispose();

    // Dispose search controller
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();

    // Remove only our listeners, not the global ones
    if (_messageListener != null) {
      _socketService.off('message:new', _messageListener);
    }
    if (_unreadCountListener != null) {
      _socketService.off('message:unread-count', _unreadCountListener);
    }
    super.dispose();
  }

  Widget _buildLastMessagePreview(
    Map<String, dynamic>? lastMessage,
    int unreadCount,
    bool isOnline,
    String? lastActive,
  ) {
    // Build the main message preview
    Widget messageWidget;

    if (lastMessage == null) {
      messageWidget = Text(
        'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      );
    } else {
      final messageType = lastMessage['type'] as String?;
      String displayText;
      IconData? icon;
      String? emoji;

      // Check if it's a media message
      if (messageType == 'image') {
        displayText = 'Image';
        emoji = '📷';
        icon = Icons.image;
      } else if (messageType == 'video') {
        displayText = 'Video';
        emoji = '🎥';
        icon = Icons.videocam;
      } else if (messageType == 'document') {
        displayText = '${lastMessage['fileName'] ?? 'Document'}';
        emoji = '📄';
        icon = Icons.insert_drive_file;
      } else if (messageType == 'shared_story') {
        displayText = 'Story';
        emoji = '✨';
        icon = Icons.auto_awesome;
      } else {
        // Regular text message
        displayText = lastMessage['content'] ?? 'No messages yet';
      }

      messageWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            AnimatedEmojiWidget(
              emoji: emoji,
              size: ResponsiveDimensions.getIconSize(context) * 0.8,
              animationType: EmojiAnimationType.scaleAndFade,
              animationDuration: const Duration(milliseconds: 600),
            ),
            SizedBox(width: ResponsiveDimensions.getItemSpacing(context) / 2),
          ],
          if (icon != null && emoji == null) ...[
            Container(
              padding: EdgeInsets.all(
                ResponsiveDimensions.getVerticalPadding(context) / 2,
              ),
              decoration: BoxDecoration(
                color: unreadCount > 0
                    ? Colors.blue.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(
                  ResponsiveDimensions.getBorderRadius(context) * 0.6,
                ),
              ),
              child: Icon(
                icon,
                size: ResponsiveDimensions.getIconSize(context) * 0.65,
                color: unreadCount > 0
                    ? Colors.blue.shade600
                    : Colors.grey.shade600,
              ),
            ),
            SizedBox(width: ResponsiveDimensions.getItemSpacing(context) / 1.5),
          ],
          Expanded(
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ResponsiveDimensions.getBodyFontSize(context) * 0.9,
                fontWeight:
                    unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      );
    }

    // Add online/last active status if user is offline
    if (!isOnline && lastActive != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          messageWidget,
          SizedBox(
              height: ResponsiveDimensions.getVerticalPadding(context) / 2),
          Row(
            children: [
              Container(
                width: ResponsiveDimensions.getIconSize(context) * 0.3,
                height: ResponsiveDimensions.getIconSize(context) * 0.3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ResponsiveDimensions.getItemSpacing(context) / 2),
              Text(
                _getLastActiveText(lastActive),
                style: TextStyle(
                  fontSize:
                      ResponsiveDimensions.getCaptionFontSize(context) * 0.85,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return messageWidget;
  }

  String _getLastActiveText(String lastActiveStr) {
    try {
      final lastActiveDate = DateTime.parse(lastActiveStr);
      final now = DateTime.now();
      final difference = now.difference(lastActiveDate);

      if (difference.inMinutes < 1) {
        return 'Active just now';
      } else if (difference.inMinutes < 60) {
        return 'Active ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Active ${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Active yesterday';
      } else if (difference.inDays < 7) {
        return 'Active ${difference.inDays}d ago';
      } else {
        return 'Active ${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _markAllAsRead() async {
    if (_totalUnread == 0) return;
    final unreadConversations = _conversations
        .where((c) => (c['unreadCount'] as int? ?? 0) > 0)
        .toList();
    for (final conv in unreadConversations) {
      await _markConversationAsRead(conv);
    }
    if (mounted) {
      setState(() {
        _totalUnread = 0;
        for (var c in _conversations) {
          c['unreadCount'] = 0;
        }
        _updateFilteredConversations();
      });
    }
  }

  Future<void> _markConversationAsRead(Map<String, dynamic> conversation) async {
    final convId = conversation['_id']?.toString();
    if (convId == null) return;
    final unreadForConversation = conversation['unreadCount'] as int? ?? 0;
    if (unreadForConversation == 0) return;
    final result = await MessagingService.markConversationAsRead(convId);
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          conversation['unreadCount'] = 0;
          _totalUnread -= unreadForConversation;
          if (_totalUnread < 0) _totalUnread = 0;
        });
        // Notify parent counters
        final notificationService = GlobalNotificationService();
        notificationService.onUnreadMessageCountChanged
            ?.call(-unreadForConversation);
      }
    }
  }

  void _showBulkActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mark_email_read, color: Colors.blue),
                title: const Text('Mark selected as read'),
                onTap: () async {
                  Navigator.pop(context);
                  final selected = _conversations
                      .where((c) => _selectedConversationIds.contains(c['_id'].toString()));
                  for (final c in selected) {
                    await _markConversationAsRead(c);
                  }
                  if (mounted) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedConversationIds.clear();
                      _updateFilteredConversations();
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_off, color: Colors.orange),
                title: const Text('Mute selected'),
                onTap: () async {
                  Navigator.pop(context);
                  // Backend endpoint may be unavailable; attempt best-effort
                  for (final id in _selectedConversationIds) {
                    await MessagingService.toggleMuteConversation(id);
                  }
              if (!mounted) return;
              setState(() {
                _isSelectionMode = false;
                _selectedConversationIds.clear();
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mute toggled for selected')),
              );
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.purple),
                title: const Text('Archive selected'),
                onTap: () async {
                  Navigator.pop(context);
                  // Requires backend toggle archive endpoint
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Archive not available yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete/Leave selected'),
                onTap: () async {
                  Navigator.pop(context);
                  final toDelete = _conversations
                      .where((c) => _selectedConversationIds.contains(c['_id'].toString()))
                      .toList();
                  for (final c in toDelete) {
                    await MessagingService.deleteConversation(
                      conversationId: c['_id'],
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _conversations.removeWhere(
                        (c) => _selectedConversationIds.contains(c['_id'].toString()),
                      );
                      _isSelectionMode = false;
                      _selectedConversationIds.clear();
                      _updateFilteredConversations();
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
