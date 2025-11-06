import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';

/// Manages real-time message updates and notifications
/// Provides centralized state management for messaging features
class EnhancedMessageProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  final AppLogger _logger = AppLogger();

  // Message state
  final Map<String, Map<String, dynamic>> _conversationMessages = {};
  final Set<String> _unreadConversations = {};
  final Map<String, bool> _typingUsers = {};
  final Map<String, String?> _userStatus = {};
  int _totalUnreadCount = 0;

  // Notification callbacks
  final List<Function(String, dynamic)> _messageListeners = [];
  final List<Function(String)> _typingListeners = [];
  final List<Function(String, int)> _unreadListeners = [];

  // Getters
  int get totalUnreadCount => _totalUnreadCount;
  bool isUserTyping(String conversationId) =>
      _typingUsers[conversationId] ?? false;
  String? getUserStatus(String userId) => _userStatus[userId];
  int getConversationUnreadCount(String conversationId) {
    // This should return the actual unread count from the conversation
    return _unreadConversations.contains(conversationId) ? 1 : 0;
  }

  EnhancedMessageProvider() {
    _setupSocketListeners();
    _logger.info('🚀 EnhancedMessageProvider initialized');
  }

  void _setupSocketListeners() {
    // Message received
    _socketService.on('message:new', (data) {
      if (data['message'] != null) {
        final message = data['message'];
        final conversationId = message['conversation']?.toString();

        if (conversationId != null) {
          _conversationMessages[conversationId] = message;

          // Notify all listeners
          for (var listener in _messageListeners) {
            try {
              listener(conversationId, message);
            } catch (e) {
              _logger.error('Error in message listener', error: e);
            }
          }
        }
      }
    });

    // Message read receipt
    _socketService.on('message:read', (data) {
      _logger.debug('Message read receipt received');
    });

    // Message delivered receipt
    _socketService.on('message:delivered', (data) {
      _logger.debug('Message delivered receipt received');
    });

    // Typing indicator
    _socketService.on('message:typing', (data) {
      final conversationId = data['conversationId']?.toString();
      if (conversationId != null) {
        _typingUsers[conversationId] = true;
        notifyListeners();

        // Auto-clear after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          _typingUsers.remove(conversationId);
          notifyListeners();
        });

        for (var listener in _typingListeners) {
          try {
            listener(conversationId);
          } catch (e) {
            _logger.error('Error in typing listener', error: e);
          }
        }
      }
    });

    // Stop typing
    _socketService.on('message:stop-typing', (data) {
      final conversationId = data['conversationId']?.toString();
      if (conversationId != null) {
        _typingUsers.remove(conversationId);
        notifyListeners();
      }
    });

    // Unread count update
    _socketService.on('message:unread-count', (data) {
      final conversationId = data['conversationId']?.toString();
      final unreadCount = data['unreadCount'] as int?;

      if (conversationId != null && unreadCount != null) {
        if (unreadCount > 0) {
          _unreadConversations.add(conversationId);
        } else {
          _unreadConversations.remove(conversationId);
        }

        // Update total unread count (from server)
        _totalUnreadCount = data['totalUnreadCount'] as int? ?? 0;

        notifyListeners();

        for (var listener in _unreadListeners) {
          try {
            listener(conversationId, unreadCount);
          } catch (e) {
            _logger.error('Error in unread listener', error: e);
          }
        }
      }
    });

    // User status change
    _socketService.on('user:status-changed', (data) {
      final userId = data['userId']?.toString();
      final isOnline = data['isOnline'] as bool?;

      if (userId != null) {
        _userStatus[userId] = isOnline == true ? 'online' : 'offline';
        notifyListeners();
      }
    });

    _logger.info('✅ Socket listeners configured for EnhancedMessageProvider');
  }

  /// Add a listener for new messages
  void addMessageListener(
      Function(String conversationId, dynamic message) listener) {
    _messageListeners.add(listener);
  }

  /// Remove a message listener
  void removeMessageListener(Function(String, dynamic) listener) {
    _messageListeners.remove(listener);
  }

  /// Add a listener for typing indicators
  void addTypingListener(Function(String conversationId) listener) {
    _typingListeners.add(listener);
  }

  /// Add a listener for unread count changes
  void addUnreadListener(Function(String conversationId, int count) listener) {
    _unreadListeners.add(listener);
  }

  /// Update total unread count
  void updateTotalUnreadCount(int count) {
    _totalUnreadCount = count;
    notifyListeners();
  }

  /// Clear unread for a conversation
  void clearUnreadForConversation(String conversationId) {
    _unreadConversations.remove(conversationId);
    notifyListeners();
  }

  @override
  void dispose() {
    _messageListeners.clear();
    _typingListeners.clear();
    _unreadListeners.clear();
    super.dispose();
  }
}

/// Convenience widget to access EnhancedMessageProvider
class EnhancedMessageConsumer extends StatelessWidget {
  final Widget Function(BuildContext, EnhancedMessageProvider, Widget?) builder;
  final Widget? child;

  const EnhancedMessageConsumer({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedMessageProvider>(
      builder: (context, provider, child) {
        return builder(context, provider, child);
      },
      child: child,
    );
  }
}
