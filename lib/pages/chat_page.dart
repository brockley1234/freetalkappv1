import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../services/messaging_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../config/app_config.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../utils/responsive_dimensions.dart';
import '../widgets/video_player_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'user_profile_page.dart';
import 'post_detail_page.dart';
import '../widgets/voice_message_widget.dart';
import '../widgets/voice_recorder_widget.dart';
import '../utils/file_download.dart';
import '../widgets/animated_emoji_widget.dart';
import 'marketplace/marketplace_listing_detail_page.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> otherUser;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;
  Map<String, dynamic>? _replyingTo;
  XFile? _selectedMediaFile;
  String? _selectedMediaType; // 'image', 'video', or 'document'
  bool _isRecordingVoice = false; // Track if currently recording voice message

  // Local mutable copy of otherUser for status updates
  late Map<String, dynamic> _otherUser;

  // Emoji picker state
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  // Enhanced features
  bool _showPinnedMessages = false;
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _loadingPinned = false;

  // Store listener callbacks so we can remove them later
  Function(dynamic)? _messageListener;
  Function(dynamic)? _messagesReadListener;
  Function(dynamic)? _typingStartListener;
  Function(dynamic)? _typingStopListener;
  Function(dynamic)? _messageDeletedListener;

  // For scrolling to specific messages
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  AnimationController? _highlightAnimation;

  // For showing timestamp on tap
  String? _showTimestampForMessageId;

  // Search functionality
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  int _currentSearchResultIndex = -1;

  // Message pagination
  int _currentPage = 1;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // Message ID tracking for O(1) duplicate checks
  final Set<String> _messageIds = {};

  // Failed message retry
  final List<Map<String, dynamic>> _failedMessages = [];

  // Streak tracking
  Map<String, dynamic>? _streak;
  bool _isLoadingStreak = false;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of otherUser
    _otherUser = Map<String, dynamic>.from(widget.otherUser);

    _loadCurrentUser();
    _loadMessages();
    _loadStreak();
    _setupSocketListeners();
    _setupScrollListener();
  }

  Future<void> _loadCurrentUser() async {
    final secureStorage = SecureStorageService();
    final userId = await secureStorage.getUserId();
    setState(() {
      _currentUserId = userId;
    });
    debugPrint('💬 Current User ID loaded: $_currentUserId');
  }

  Future<void> _loadStreak() async {
    if (_currentUserId == null || _otherUser['_id'] == null) {
      return;
    }

    setState(() {
      _isLoadingStreak = true;
    });

    try {
      final token = await SecureStorageService().getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/streaks/between/${_currentUserId!}/${_otherUser['_id']}',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _streak = jsonData['data'] as Map<String, dynamic>?;
            _isLoadingStreak = false;
          });

          if (_streak != null) {
            final streakCount = _streak!['streakCount'] ?? 0;
            debugPrint('🔥 Loaded streak: $streakCount days');
          }
        }
      } else if (response.statusCode == 404) {
        // No streak yet
        if (mounted) {
          setState(() {
            _streak = null;
            _isLoadingStreak = false;
          });
        }
      } else {
        throw Exception('Failed to load streak: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error loading streak: $e');
      if (mounted) {
        setState(() {
          _isLoadingStreak = false;
        });
      }
    }
  }

  Future<void> _loadPinnedMessages() async {
    if (widget.conversationId.isEmpty) return;

    setState(() => _loadingPinned = true);

    try {
      final result = await MessagingService.getPinnedMessages(
        conversationId: widget.conversationId,
      );

      if (mounted && result['success'] == true) {
        setState(() {
          _pinnedMessages = List<Map<String, dynamic>>.from(
            result['data']['pinnedMessages'] ?? [],
          );
          _loadingPinned = false;
        });
        debugPrint('📌 Loaded ${_pinnedMessages.length} pinned messages');
      }
    } catch (e) {
      debugPrint('❌ Error loading pinned messages: $e');
      if (mounted) {
        setState(() => _loadingPinned = false);
      }
    }
  }

  void _setupSocketListeners() {
    debugPrint('💬 ========================================');
    debugPrint('💬 CHAT PAGE: Setting up socket listeners');
    debugPrint('💬 Conversation ID: ${widget.conversationId}');
    debugPrint('💬 Socket service connected: ${_socketService.isConnected}');
    debugPrint('💬 ========================================');

    // Create and store the message listener callback
    _messageListener = (data) {
      debugPrint('💬 ========================================');
      debugPrint('💬 CHAT PAGE: MESSAGE RECEIVED VIA SOCKET!');
      debugPrint('💬 Data: $data');
      debugPrint('💬 Data type: ${data.runtimeType}');
      debugPrint('💬 My Conversation ID: ${widget.conversationId}');
      debugPrint(
        '💬 Message Conversation: ${data['message']?['conversation']}',
      );

      if (mounted && data['message'] != null) {
        final message = data['message'];
        final messageConversationId = message['conversation']?.toString();
        final senderId = message['sender']?['_id']?.toString();

        // Check if message belongs to this conversation
        if (messageConversationId == widget.conversationId) {
          debugPrint('💬 ✅ Message belongs to this conversation!');

          // Check if message already exists (avoid duplicates) - O(1) lookup
          final messageId = message['_id']?.toString();
          final exists = messageId != null && _messageIds.contains(messageId);

          if (!exists) {
            setState(() {
              _messages.add(message);
              if (messageId != null) {
                _messageIds.add(messageId);
              }
              debugPrint(
                '💬 ✅ Message added to list. Total messages: ${_messages.length}',
              );
            });
            _scrollToBottom();

            // Mark as read if the message is from the other user
            // (not from current user - this prevents marking our own messages as read)
            if (senderId != null && senderId != _currentUserId) {
              debugPrint('💬 Message is from other user, marking as read');
              _markAsRead();
            } else {
              debugPrint(
                  '💬 Message is from current user, not marking as read');
            }
          } else {
            debugPrint('💬 ⚠️ Message already exists, skipping duplicate');
          }
        } else {
          debugPrint('💬 ⚠️ Message is for different conversation, ignoring');
        }
      }

      debugPrint('💬 ========================================');
    };

    _socketService.on('message:new', _messageListener!);
    debugPrint('💬 ✅ Subscribed to message:new event');

    // Create and store the messages read listener callback
    _messagesReadListener = (data) {
      debugPrint('💬 Messages read event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        setState(() {
          for (var msg in _messages) {
            if (msg['sender']?['_id']?.toString() == _currentUserId) {
              msg['isRead'] = true;
            }
          }
        });
        debugPrint('💬 ✅ Updated messages as read');
      }
    };

    _socketService.on('messages:read', _messagesReadListener!);
    debugPrint('💬 ✅ Subscribed to messages:read event');

    // Typing indicator listeners
    _typingStartListener = (data) {
      debugPrint('⌨️ Typing start event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        setState(() {
          _isOtherUserTyping = true;
        });
        debugPrint('⌨️ ✅ ${data['userName']} is typing...');

        // Auto-scroll to show typing indicator
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    };

    _socketService.on('typing:start', _typingStartListener!);
    debugPrint('💬 ✅ Subscribed to typing:start event');

    _typingStopListener = (data) {
      debugPrint('⌨️ Typing stop event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        setState(() {
          _isOtherUserTyping = false;
        });
        debugPrint('⌨️ ✅ ${data['userName']} stopped typing');
      }
    };

    _socketService.on('typing:stop', _typingStopListener!);
    debugPrint('💬 ✅ Subscribed to typing:stop event');

    // Message deleted listener
    _messageDeletedListener = (data) {
      debugPrint('🗑️ Message deleted event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        final messageId = data['messageId'];
        final content = data['content'];
        final isDeleted = data['isDeleted'];

        setState(() {
          final index = _messages.indexWhere((msg) => msg['_id'] == messageId);
          if (index != -1) {
            _messages[index]['content'] = content;
            _messages[index]['isDeleted'] = isDeleted;
            debugPrint('🗑️ ✅ Updated deleted message in list');
          }
        });
      }
    };

    _socketService.on('message:deleted', _messageDeletedListener!);
    debugPrint('💬 ✅ Subscribed to message:deleted event');

    // Message edited listener
    _socketService.on('message:edited', (data) {
      debugPrint('✏️ Message edited event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        final messageId = data['messageId'];
        final content = data['content'];
        final isEdited = data['isEdited'];
        final lastEditedAt = data['lastEditedAt'];

        setState(() {
          final index = _messages.indexWhere((msg) => msg['_id'] == messageId);
          if (index != -1) {
            _messages[index]['content'] = content;
            _messages[index]['isEdited'] = isEdited;
            _messages[index]['lastEditedAt'] = lastEditedAt;
            debugPrint('✏️ ✅ Updated edited message in list');
          }
        });
      }
    });
    debugPrint('💬 ✅ Subscribed to message:edited event');

    // Message pin toggle listener
    _socketService.on('message:pin-toggled', (data) {
      debugPrint('📌 Message pin toggled event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        final messageId = data['messageId'];
        final isPinned = data['isPinned'];
        final pinnedBy = data['pinnedBy'];
        final pinnedAt = data['pinnedAt'];

        setState(() {
          final index = _messages.indexWhere((msg) => msg['_id'] == messageId);
          if (index != -1) {
            _messages[index]['isPinned'] = isPinned;
            _messages[index]['pinnedBy'] = pinnedBy;
            _messages[index]['pinnedAt'] = pinnedAt;
            debugPrint('📌 ✅ Updated pinned status in list');
          }
        });
      }
    });
    debugPrint('💬 ✅ Subscribed to message:pin-toggled event');

    // Message reaction listeners
    _socketService.on('message:reacted', (data) {
      debugPrint('👍 Message reaction event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        final messageId = data['messageId'];
        final reactions = data['reactions'];

        setState(() {
          final index = _messages.indexWhere((msg) => msg['_id'] == messageId);
          if (index != -1) {
            _messages[index]['reactions'] = reactions;
            debugPrint('👍 ✅ Updated message reactions');
          }
        });
      }
    });
    debugPrint('💬 ✅ Subscribed to message:reacted event');

    _socketService.on('message:unreacted', (data) {
      debugPrint('👎 Message unreaction event received: $data');

      if (mounted &&
          data['conversationId']?.toString() == widget.conversationId) {
        final messageId = data['messageId'];
        final reactions = data['reactions'];

        setState(() {
          final index = _messages.indexWhere((msg) => msg['_id'] == messageId);
          if (index != -1) {
            _messages[index]['reactions'] = reactions;
            debugPrint('👎 ✅ Updated message reactions');
          }
        });
      }
    });
    debugPrint('💬 ✅ Subscribed to message:unreacted event');

    // User status listener
    _socketService.on('user:status-changed', (data) {
      debugPrint('👤 User status changed event received: $data');

      if (mounted && data['userId'] == _otherUser['_id']) {
        setState(() {
          _otherUser['isOnline'] = data['isOnline'];
          _otherUser['lastActive'] = data['lastActive'];
        });
        debugPrint('👤 ✅ Updated user status: isOnline=${data['isOnline']}');
      }
    });
    debugPrint('💬 ✅ Subscribed to user:status-changed event');
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Load more messages when scrolling to top
      if (_scrollController.position.pixels <= 100 &&
          !_isLoadingMore &&
          _hasMoreMessages) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreMessages = true;
    });

    final result = await MessagingService.getMessages(
      widget.conversationId,
      page: _currentPage,
    );

    if (mounted && result['success'] == true) {
      final messages = List<Map<String, dynamic>>.from(
        result['data']['messages'] ?? [],
      );

      // Build message ID set for O(1) lookups
      _messageIds.clear();
      for (var msg in messages) {
        if (msg['_id'] != null) {
          _messageIds.add(msg['_id'].toString());
        }
      }

      setState(() {
        _messages = messages;
        _isLoading = false;

        // Check if there are more messages
        final pagination = result['data']['pagination'];
        if (pagination != null) {
          final currentPage = pagination['page'] ?? 1;
          final totalPages = pagination['pages'] ?? 1;
          _hasMoreMessages = currentPage < totalPages;
        }
      });
      _scrollToBottom(force: true);

      // Mark messages as read after they are loaded and visible
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _markAsRead();
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final result = await MessagingService.getMessages(
      widget.conversationId,
      page: nextPage,
    );

    if (mounted && result['success'] == true) {
      final newMessages = List<Map<String, dynamic>>.from(
        result['data']['messages'] ?? [],
      );

      // Add new message IDs to set
      for (var msg in newMessages) {
        if (msg['_id'] != null) {
          _messageIds.add(msg['_id'].toString());
        }
      }

      setState(() {
        // Insert older messages at the beginning
        _messages.insertAll(0, newMessages);
        _currentPage = nextPage;
        _isLoadingMore = false;

        // Check if there are more messages
        final pagination = result['data']['pagination'];
        if (pagination != null) {
          final currentPage = pagination['page'] ?? 1;
          final totalPages = pagination['pages'] ?? 1;
          _hasMoreMessages = currentPage < totalPages;
        }
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAsRead() async {
    await MessagingService.markAsRead(widget.conversationId);
  }

  void _handleTyping(String text) {
    // Cancel previous timer
    _typingTimer?.cancel();

    // Update UI to reflect text changes (for send button state)
    setState(() {});

    if (text.trim().isNotEmpty) {
      // Start typing if not already
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        MessagingService.sendTypingIndicator(widget.conversationId, true);
        debugPrint('⌨️ Started typing indicator');
      }

      // Set timer to stop typing after 2 seconds of inactivity
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isCurrentlyTyping) {
          _isCurrentlyTyping = false;
          MessagingService.sendTypingIndicator(widget.conversationId, false);
          debugPrint('⌨️ Stopped typing indicator (timeout)');
        }
      });
    } else {
      // Text is empty, stop typing
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        MessagingService.sendTypingIndicator(widget.conversationId, false);
        debugPrint('⌨️ Stopped typing indicator (empty text)');
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    // Check if we have content or media
    if (content.isEmpty && _selectedMediaFile == null) {
      return;
    }
    if (_isSending) {
      return;
    }

    // Stop typing indicator when sending
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      MessagingService.sendTypingIndicator(widget.conversationId, false);
      debugPrint('⌨️ Stopped typing indicator (message sent)');
    }

    setState(() => _isSending = true);

    debugPrint('💬 Sending message: $content');
    debugPrint('💬 Media file: $_selectedMediaFile');
    debugPrint('💬 Replying to: $_replyingTo');

    Map<String, dynamic> result;

    // Check if chatting with AI bot
    final isBot = _otherUser['isBot'] == true;

    if (isBot) {
      // For bots, only allow text messages for now
      if (_selectedMediaFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI bots only support text messages for now'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      // Send AI chat message
      result = await MessagingService.sendAIChatMessage(
        botId: _otherUser['_id'],
        message: content,
        conversationId:
            widget.conversationId.isNotEmpty ? widget.conversationId : null,
      );
    } else {
      // Send media message if media is selected
      if (_selectedMediaFile != null) {
        result = await MessagingService.sendMediaMessage(
          recipient: _otherUser['_id'],
          mediaFile: _selectedMediaFile!,
          content: content.isNotEmpty ? content : null,
          replyTo: _replyingTo?['_id'],
        );
      } else {
        // Send text message
        result = await MessagingService.sendMessage(
          recipient: _otherUser['_id'],
          content: content,
          replyTo: _replyingTo?['_id'],
        );
      }
    }

    if (mounted) {
      if (result['success'] == true) {
        _messageController.clear();

        // Clear reply and media state
        setState(() {
          _replyingTo = null;
          _selectedMediaFile = null;
          _selectedMediaType = null;
        });

        debugPrint('💬 ✅ Message sent successfully');

        // Handle AI chat response (includes both user and bot messages)
        if (isBot && result['data'] != null) {
          final userMessage = result['data']['userMessage'];
          final botMessage = result['data']['botMessage'];

          // Add user message if not already exists
          final userMessageId = userMessage['_id']?.toString();
          final userExists =
              userMessageId != null && _messageIds.contains(userMessageId);

          if (!userExists) {
            setState(() {
              _messages.add(userMessage);
              if (userMessageId != null) {
                _messageIds.add(userMessageId);
              }
            });
          }

          // Add bot message if not already exists
          final botMessageId = botMessage['_id']?.toString();
          final botExists =
              botMessageId != null && _messageIds.contains(botMessageId);

          if (!botExists) {
            setState(() {
              _messages.add(botMessage);
              if (botMessageId != null) {
                _messageIds.add(botMessageId);
              }
            });
          }

          // Update conversation ID if it was empty
          if (widget.conversationId.isEmpty &&
              result['data']['conversation'] != null) {
            // Note: We can't update the widget's conversationId, but messages will still work
            debugPrint(
                '💬 AI chat conversation created: ${result['data']['conversation']['_id']}');
          }

          _scrollToBottom(force: true);
        }
        // Handle regular message response
        else if (result['data'] != null && result['data']['message'] != null) {
          final serverMessage = result['data']['message'];
          final messageId = serverMessage['_id']?.toString();

          // Only add if it doesn't already exist - O(1) lookup
          final exists = messageId != null && _messageIds.contains(messageId);

          if (!exists) {
            setState(() {
              _messages.add(serverMessage);
              if (messageId != null) {
                _messageIds.add(messageId);
              }
              debugPrint('💬 ✅ Message added from API response');
            });
            _scrollToBottom(force: true);
          } else {
            debugPrint('💬 ℹ️ Message already exists (from socket event)');
          }
        }
      } else {
        // Message failed to send - add to failed messages for retry
        if (!mounted) return;

        final failedMessage = {
          'tempId': DateTime.now().millisecondsSinceEpoch.toString(),
          'content': content,
          'recipient': _otherUser['_id'],
          'type': _selectedMediaFile != null ? 'media' : 'text',
          'mediaFile': _selectedMediaFile,
          'replyTo': _replyingTo?['_id'],
          'error': result['message'] ?? 'Failed to send message',
          'timestamp': DateTime.now().toIso8601String(),
        };

        setState(() {
          _failedMessages.add(failedMessage);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to send message'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _retryFailedMessage(failedMessage),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      setState(() => _isSending = false);
    }
  }

  Future<void> _retryFailedMessage(Map<String, dynamic> failedMessage) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _failedMessages.remove(failedMessage);
    });

    Map<String, dynamic> result;

    try {
      if (failedMessage['type'] == 'media') {
        result = await MessagingService.sendMediaMessage(
          recipient: failedMessage['recipient'],
          mediaFile: failedMessage['mediaFile'],
          content: failedMessage['content'],
          replyTo: failedMessage['replyTo'],
        );
      } else {
        result = await MessagingService.sendMessage(
          recipient: failedMessage['recipient'],
          content: failedMessage['content'],
          replyTo: failedMessage['replyTo'],
        );
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Add message from API response
          if (result['data'] != null && result['data']['message'] != null) {
            final serverMessage = result['data']['message'];
            final messageId = serverMessage['_id']?.toString();

            final exists = messageId != null && _messageIds.contains(messageId);

            if (!exists) {
              setState(() {
                _messages.add(serverMessage);
                if (messageId != null) {
                  _messageIds.add(messageId);
                }
              });
              _scrollToBottom(force: true);
            }
          }
        } else {
          // Add back to failed messages
          setState(() {
            _failedMessages.add(failedMessage);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Retry failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failedMessages.add(failedMessage);
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(String audioPath, int duration) async {
    if (_isSending) return;

    setState(() => _isSending = true);

    debugPrint(
        '🎤 Sending voice message: $audioPath, duration: $duration seconds');

    try {
      final xFile = XFile(audioPath);

      final result = await MessagingService.sendVoiceMessage(
        recipient: _otherUser['_id'],
        audioFile: xFile,
        duration: duration,
        replyTo: _replyingTo?['_id'],
      );

      if (mounted) {
        if (result['success'] == true) {
          debugPrint('🎤 ✅ Voice message sent successfully');

          // Clear reply state
          setState(() {
            _replyingTo = null;
            _isRecordingVoice = false;
          });

          // Add message from API response
          if (result['data'] != null && result['data']['message'] != null) {
            final serverMessage = result['data']['message'];
            final messageId = serverMessage['_id']?.toString();

            // Only add if it doesn't already exist - O(1) lookup
            final exists = messageId != null && _messageIds.contains(messageId);

            if (!exists) {
              setState(() {
                _messages.add(serverMessage);
                if (messageId != null) {
                  _messageIds.add(messageId);
                }
              });
              _scrollToBottom(force: true);
            }
          }

          // Delete the temporary audio file (only on mobile)
          if (!kIsWeb) {
            try {
              final file = File(audioPath);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('Failed to delete temp audio file: $e');
            }
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(result['message'] ?? 'Failed to send voice message'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isRecordingVoice = false);
        }
        setState(() => _isSending = false);
      }
    } catch (e) {
      debugPrint('🎤 ❌ Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSending = false;
          _isRecordingVoice = false;
        });
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Only auto-scroll if user is near bottom or forced
        final isNearBottom = _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 100;

        if (force || isNearBottom) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // Search messages
  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchResultIndex = -1;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final result = await MessagingService.searchMessages(
      conversationId: widget.conversationId,
      query: query,
    );

    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(
            result['data']['results'] ?? [],
          );
          _currentSearchResultIndex = _searchResults.isNotEmpty ? 0 : -1;
          _isSearching = false;
        });

        // Navigate to first result
        if (_searchResults.isNotEmpty) {
          _scrollToMessage(_searchResults[0]['_id']);
        }
      } else {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Search failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToNextSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchResultIndex =
          (_currentSearchResultIndex + 1) % _searchResults.length;
    });

    _scrollToMessage(_searchResults[_currentSearchResultIndex]['_id']);
  }

  void _navigateToPreviousSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchResultIndex =
          (_currentSearchResultIndex - 1 + _searchResults.length) %
              _searchResults.length;
    });

    _scrollToMessage(_searchResults[_currentSearchResultIndex]['_id']);
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchResults = [];
        _currentSearchResultIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  // Export conversation
  Future<void> _exportConversation(String format) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                Text('Exporting conversation...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final result = await MessagingService.exportConversation(
        conversationId: widget.conversationId,
        format: format,
      );

      if (!mounted) return;

      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result['success'] == true) {
        // For web, create a download link
        if (kIsWeb) {
          try {
            final fileName = result['fileName'] ?? 'conversation.$format';
            final content = result['data'] as String;
            final bytes = Uint8List.fromList(utf8.encode(content));

            // Use platform-specific download
            FileDownloader.downloadFile(bytes, fileName);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded: $fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } catch (e) {
            debugPrint('Web download error: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // For mobile, save to downloads folder
          final directory = await getApplicationDocumentsDirectory();
          final fileName = result['fileName'] ?? 'conversation.$format';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(result['data']);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to: $filePath'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () {
                  // Open file location
                  // You might want to use a package like open_file
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Conversation'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportConversation('txt');
            },
            child: const Text('Plain Text'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportConversation('json');
            },
            child: const Text('JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getLastActiveText() {
    if (_otherUser['lastActive'] == null) {
      return 'Offline';
    }

    // Use TimeUtils to properly handle UTC to local time conversion
    return TimeUtils.formatLastActive(_otherUser['lastActive']);
  }

  String _formatFullTimestamp(String timestamp) {
    // Use TimeUtils to properly handle UTC to local time conversion
    return TimeUtils.formatFullTimestamp(timestamp);
  }

  // Format message timestamp as YYYY/MM/DD HH:MM
  String _formatMessageTimestamp(String timestamp) {
    return TimeUtils.formatMessageTimestamp(timestamp);
  }

  Future<void> _downloadFile(String mediaUrl, String fileName) async {
    try {
      final url = '${ApiService.baseApi}$mediaUrl';

      if (kIsWeb) {
        // Web: Download file using Blob API
        try {
          // Show downloading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
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
                    Text('Downloading $fileName...'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 30),
              ),
            );
          }

          // Fetch the file
          final response = await http.get(Uri.parse(url));

          if (!mounted) return;

          if (response.statusCode == 200) {
            // Use platform-specific download
            FileDownloader.downloadFile(response.bodyBytes, fileName);

            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded: $fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Download failed: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Web download error: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Mobile/Desktop: Download to device

        // Request storage permission on Android
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission required to download files',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // Show downloading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
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
                  Text('Downloading $fileName...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 30),
            ),
          );
        }

        // Download the file
        final response = await http.get(Uri.parse(url));

        if (!mounted) return;

        if (response.statusCode == 200) {
          // Get downloads directory
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              directory = await getExternalStorageDirectory();
            }
          } else if (Platform.isIOS) {
            directory = await getApplicationDocumentsDirectory();
          } else {
            directory = await getDownloadsDirectory();
          }

          if (directory != null) {
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            if (!mounted) return;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded: $fileName'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () async {
                    final uri = Uri.file(filePath);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ),
            );
          }
        } else {
          throw Exception('Download failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                // Navigate to user profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserProfilePage(userId: _otherUser['_id']),
                  ),
                );
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: ResponsiveDimensions.getAvatarSize(context) / 2.5,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _otherUser['avatar'] != null
                        ? UrlUtils.getAvatarImageProvider(_otherUser['avatar'])
                        : null,
                    child: _otherUser['avatar'] == null
                        ? Text(
                            _otherUser['name']?[0]?.toUpperCase() ?? '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Online status indicator
                  if (_otherUser['isOnline'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: ResponsiveDimensions.getIconSize(context) * 0.6,
                        height: ResponsiveDimensions.getIconSize(context) * 0.6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveDimensions.getItemSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _otherUser['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize:
                                ResponsiveDimensions.getBodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _isOtherUserTyping
                        ? 'typing...'
                        : (_otherUser['isOnline'] == true
                            ? 'Active now'
                            : _getLastActiveText()),
                    style: TextStyle(
                      fontSize:
                          ResponsiveDimensions.getCaptionFontSize(context),
                      color:
                          _isOtherUserTyping ? Colors.blue : Colors.grey[600],
                    ),
                  ),
                  // Streak display
                  if (_streak != null && !_isLoadingStreak)
                    Padding(
                      padding: EdgeInsets.only(
                          top:
                              ResponsiveDimensions.getVerticalPadding(context) /
                                  2),
                      child: Row(
                        children: [
                          Text(
                            '🔥',
                            style: TextStyle(
                                fontSize:
                                    ResponsiveDimensions.getIconSize(context) *
                                        0.65),
                          ),
                          SizedBox(
                              width:
                                  ResponsiveDimensions.getItemSpacing(context) /
                                      3),
                          Text(
                            '${_streak!['streakCount'] ?? 0} day streak',
                            style: TextStyle(
                              fontSize: ResponsiveDimensions.getCaptionFontSize(
                                      context) *
                                  0.85,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_showSearchBar) ...[
            // Pinned messages button (if any exist)
            if (_pinnedMessages.isNotEmpty)
              Tooltip(
                message:
                    '${_pinnedMessages.length} pinned message${_pinnedMessages.length != 1 ? 's' : ''}',
                child: IconButton(
                  icon: Icon(
                    Icons.push_pin,
                    color: _showPinnedMessages ? Colors.red : Colors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPinnedMessages = !_showPinnedMessages;
                    });
                    if (_showPinnedMessages) {
                      _loadPinnedMessages();
                    }
                  },
                  tooltip: 'Pinned messages',
                ),
              ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue),
              onPressed: _toggleSearch,
              tooltip: 'Search messages',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.blue),
              onSelected: (value) {
                if (value == 'export') {
                  _showExportDialog();
                } else if (value == 'info') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserProfilePage(userId: _otherUser['_id']),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download,
                          size:
                              ResponsiveDimensions.getIconSize(context) * 0.9),
                      SizedBox(
                          width: ResponsiveDimensions.getItemSpacing(context)),
                      const Text('Export conversation'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size:
                              ResponsiveDimensions.getIconSize(context) * 0.9),
                      SizedBox(
                          width: ResponsiveDimensions.getItemSpacing(context)),
                      const Text('User info'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Hide emoji picker when tapping outside
          if (_showEmojiPicker) {
            setState(() {
              _showEmojiPicker = false;
            });
          }
        },
        child: Column(
          children: [
            // Pinned messages panel
            if (_showPinnedMessages && _pinnedMessages.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  border: Border(
                    bottom:
                        BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin,
                              size: 20, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Pinned Messages (${_pinnedMessages.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[900],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() => _showPinnedMessages = false);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Pinned messages list
                    SizedBox(
                      height: 100,
                      child: _loadingPinned
                          ? const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pinnedMessages.length,
                              itemBuilder: (context, index) {
                                final msg = _pinnedMessages[index];
                                return GestureDetector(
                                  onTap: () {
                                    // Scroll to pinned message
                                    _scrollToMessage(msg['_id']);
                                    setState(() => _showPinnedMessages = false);
                                  },
                                  child: Container(
                                    width: 160,
                                    margin: const EdgeInsets.only(
                                        left: 12, bottom: 12, top: 12),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.amber
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Message sender
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.blue[100],
                                              child: Text(
                                                msg['sender']?['name']?[0]
                                                        ?.toUpperCase() ??
                                                    '?',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                msg['sender']?['name'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Message content preview
                                        Expanded(
                                          child: Text(
                                            msg['content'] ?? '(No content)',
                                            style:
                                                const TextStyle(fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

            // Search bar
            if (_showSearchBar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search in conversation...',
                          border: InputBorder.none,
                          prefixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _currentSearchResultIndex = -1;
                                      _highlightedMessageId = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          // Debounce search
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_searchController.text == value) {
                              _searchMessages(value);
                            }
                          });
                        },
                        onSubmitted: _searchMessages,
                      ),
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      Text(
                        '${_currentSearchResultIndex + 1}/${_searchResults.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: _navigateToPreviousSearchResult,
                        tooltip: 'Previous result',
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: _navigateToNextSearchResult,
                        tooltip: 'Next result',
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleSearch,
                      tooltip: 'Close search',
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Say hello! 👋',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: (_isLoadingMore ? 1 : 0) +
                              _messages.length +
                              (_isOtherUserTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the top
                            if (_isLoadingMore && index == 0) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            // Adjust index if loading indicator is shown
                            final messageIndex =
                                _isLoadingMore ? index - 1 : index;

                            // Show typing indicator as last item
                            if (messageIndex == _messages.length &&
                                _isOtherUserTyping) {
                              return _buildTypingIndicator();
                            }

                            final message = _messages[messageIndex];
                            final previousMessage = messageIndex > 0
                                ? _messages[messageIndex - 1]
                                : null;
                            final showAvatar =
                                _shouldShowAvatar(message, messageIndex);
                            final showDateSeparator = _shouldShowDateSeparator(
                              message,
                              previousMessage,
                            );
                            final isLastMessage =
                                messageIndex == _messages.length - 1;

                            return Column(
                              children: [
                                if (showDateSeparator)
                                  _buildDateSeparator(message['createdAt']),
                                _buildMessageBubble(
                                  message,
                                  showAvatar,
                                  isLastMessage: isLastMessage,
                                ),
                              ],
                            );
                          },
                        ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  bool _shouldShowAvatar(Map<String, dynamic> message, int index) {
    if (index == _messages.length - 1) return true;

    final nextMessage = _messages[index + 1];
    final currentSenderId = message['sender']?['_id']?.toString();
    final nextSenderId = nextMessage['sender']?['_id']?.toString();

    return currentSenderId != nextSenderId;
  }

  bool _shouldShowDateSeparator(
    Map<String, dynamic> message,
    Map<String, dynamic>? previousMessage,
  ) {
    if (previousMessage == null) return true;

    try {
      // Use TimeUtils to parse to local time for comparison
      final currentDate = TimeUtils.parseToLocal(message['createdAt'] ?? '');
      final previousDate =
          TimeUtils.parseToLocal(previousMessage['createdAt'] ?? '');

      return currentDate.day != previousDate.day ||
          currentDate.month != previousDate.month ||
          currentDate.year != previousDate.year;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateSeparator(String? timestamp) {
    if (timestamp == null) return const SizedBox.shrink();

    try {
      // Use TimeUtils to properly handle UTC to local time conversion
      final dateText = TimeUtils.formatDateSeparator(timestamp);

      if (dateText.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: _otherUser['avatar'] != null
                  ? UrlUtils.getAvatarImageProvider(_otherUser['avatar'])
                  : null,
              child: _otherUser['avatar'] == null
                  ? Text(
                      _otherUser['name']?[0]?.toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    )
                  : null,
            ),
          ),
          // Typing bubble with animated dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const TypingDotsAnimation(),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message, bool isMe) {
    final messageId = message['_id']?.toString() ?? '';
    final content = message['content'] ?? '';
    final messageType = message['type'] ?? 'text';
    final isPinned = message['isPinned'] ?? false;
    // Use TimeUtils to parse to local time
    final createdAt = TimeUtils.parseToLocal(
      message['createdAt'] ?? DateTime.now().toIso8601String(),
    );
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final canDeleteForEveryone = isMe && createdAt.isAfter(oneHourAgo);
    final canEdit = isMe &&
        createdAt.isAfter(oneHourAgo) &&
        messageType == 'text' &&
        content.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_reaction, color: Colors.orange),
                title: const Text('React'),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(messageId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.blue),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingTo = message;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy, color: Colors.grey),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessageToClipboard(content);
                },
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.teal),
                  title: const Text('Edit'),
                  subtitle: const Text('Within 1 hour of sending'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditMessageDialog(message);
                  },
                ),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? Colors.red : Colors.purple,
                ),
                title: Text(isPinned ? 'Unpin' : 'Pin'),
                subtitle: const Text('Pin to top of chat'),
                onTap: () {
                  Navigator.pop(context);
                  _togglePinMessage(messageId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.green),
                title: const Text('Forward'),
                subtitle: const Text('Send to another chat'),
                onTap: () {
                  Navigator.pop(context);
                  _showForwardMessageDialog(messageId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete for me'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(messageId);
                },
              ),
              if (canDeleteForEveryone)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for everyone'),
                  subtitle: const Text(
                    'Can only delete messages within 1 hour',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForEveryone(messageId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Copy message to clipboard
  Future<void> _copyMessageToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Show dialog to edit message
  void _showEditMessageDialog(Map<String, dynamic> message) {
    final messageId = message['_id']?.toString() ?? '';
    final originalContent = message['content'] ?? '';
    final editController = TextEditingController(text: originalContent);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: editController,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Edit your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _editMessage(messageId, editController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Edit message via API
  Future<void> _editMessage(String messageId, String newContent) async {
    if (!mounted) return;

    if (newContent.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newContent.length > 5000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message is too long (max 5000 characters)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await MessagingService.editMessage(
        messageId: messageId,
        content: newContent,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Update the message in the UI
          setState(() {
            final index =
                _messages.indexWhere((msg) => msg['_id'] == messageId);
            if (index != -1) {
              _messages[index]['content'] = newContent;
              _messages[index]['isEdited'] = true;
              _messages[index]['lastEditedAt'] =
                  DateTime.now().toIso8601String();
              debugPrint('✏️ ✅ Message updated locally');
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message edited successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to edit message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error editing message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error editing message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Toggle pin message
  Future<void> _togglePinMessage(String messageId) async {
    try {
      final result = await MessagingService.togglePinMessage(
        messageId: messageId,
      );

      if (mounted) {
        if (result['success'] == true) {
          final isPinned = result['data']['isPinned'] ?? false;

          // Update the message in the UI
          setState(() {
            final index =
                _messages.indexWhere((msg) => msg['_id'] == messageId);
            if (index != -1) {
              _messages[index]['isPinned'] = isPinned;
              _messages[index]['pinnedBy'] = result['data']['pinnedBy'];
              _messages[index]['pinnedAt'] = result['data']['pinnedAt'];
              debugPrint('📌 ✅ Message pinned status updated');
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPinned ? 'Message pinned' : 'Message unpinned'),
              backgroundColor: isPinned ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to pin message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error pinning message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pinning message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show forward message dialog
  void _showForwardMessageDialog(String messageId) {
    if (!mounted) return;

    // Find the message to forward
    Map<String, dynamic>? messageToForward;
    try {
      messageToForward = _messages.firstWhere((msg) => msg['_id'] == messageId);
    } catch (e) {
      // Message not found
      messageToForward = null;
    }

    if (messageToForward == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _ForwardMessageDialog(
        messageId: messageId,
        message: messageToForward!,
        onForward: (conversationIds) async {
          await _handleForwardMessage(messageId, conversationIds);
        },
      ),
    );
  }

  Future<void> _handleForwardMessage(
    String messageId,
    List<String> conversationIds,
  ) async {
    // Forward the message
    final result = await MessagingService.forwardMessage(
      messageId: messageId,
      conversationIds: conversationIds,
    );

    // Guard ALL context usage with single mounted check on this State
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message forwarded to ${conversationIds.length} conversation${conversationIds.length != 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
      debugPrint(
          '➡️ ✅ Message $messageId forwarded to ${conversationIds.length} conversations');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to forward message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '🎉'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'React to message',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: reactions.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _addReaction(messageId, emoji);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: AnimatedEmojiWidget(
                            emoji: emoji,
                            size: 32,
                            animationType: EmojiAnimationType.bounce,
                            animationDuration:
                                const Duration(milliseconds: 600),
                            repeat: true,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final result = await MessagingService.addReaction(
      messageId: messageId,
      emoji: emoji,
    );

    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to add reaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeReaction(String messageId) async {
    final result = await MessagingService.removeReaction(messageId: messageId);

    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to remove reaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReactions(List reactions, String messageId, bool isMe) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji
    final Map<String, List<dynamic>> groupedReactions = {};
    for (var reaction in reactions) {
      final emoji = reaction['emoji'] as String;
      if (!groupedReactions.containsKey(emoji)) {
        groupedReactions[emoji] = [];
      }
      groupedReactions[emoji]!.add(reaction);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      children: groupedReactions.entries.map((entry) {
        final emoji = entry.key;
        final reactionsList = entry.value;
        final count = reactionsList.length;
        final hasUserReacted = reactionsList.any((r) {
          final user = r['user'];
          if (user is String) {
            return user == _currentUserId;
          } else if (user is Map) {
            return user['_id']?.toString() == _currentUserId;
          }
          return false;
        });

        // Build tooltip text showing who reacted
        final reactionUsers = reactionsList.map((r) {
          final user = r['user'];
          if (user is String) {
            return 'User';
          } else if (user is Map) {
            return user['name'] ?? 'Unknown';
          }
          return 'Unknown';
        }).toList();

        final tooltipText = reactionUsers.length > 2
            ? '${reactionUsers.take(2).join(', ')} and ${reactionUsers.length - 2} more'
            : reactionUsers.join(' and ');

        return Tooltip(
          message: '$tooltipText reacted with $emoji',
          showDuration: const Duration(seconds: 3),
          child: GestureDetector(
            onTap: () {
              if (hasUserReacted) {
                _removeReaction(messageId);
              } else {
                _addReaction(messageId, emoji);
              }
            },
            onLongPress: () {
              _showReactionDetails(reactionsList, emoji);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal:
                    ResponsiveDimensions.getHorizontalPadding(context) * 0.6,
                vertical:
                    ResponsiveDimensions.getVerticalPadding(context) * 0.3,
              ),
              decoration: BoxDecoration(
                color: hasUserReacted
                    ? Colors.blue.withValues(alpha: 0.25)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  ResponsiveDimensions.getBorderRadius(context) * 0.8,
                ),
                border: Border.all(
                  color: hasUserReacted
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.25),
                  width: hasUserReacted ? 1.5 : 1,
                ),
                boxShadow: hasUserReacted
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedEmojiWidget(
                    emoji: emoji,
                    size: ResponsiveDimensions.getIconSize(context) * 0.7,
                    animationType: EmojiAnimationType.bounce,
                    animationDuration: const Duration(milliseconds: 600),
                    repeat: true,
                  ),
                  if (count > 1) ...[
                    SizedBox(
                        width:
                            ResponsiveDimensions.getItemSpacing(context) / 2),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize:
                            ResponsiveDimensions.getCaptionFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: hasUserReacted
                            ? Colors.blue[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showReactionDetails(List reactions, String emoji) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedEmojiWidget(
                      emoji: emoji,
                      size: 32,
                      animationType: EmojiAnimationType.bounce,
                      animationDuration: const Duration(milliseconds: 600),
                      repeat: true,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${reactions.length} ${reactions.length == 1 ? 'reaction' : 'reactions'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...reactions.map((reaction) {
                  final user = reaction['user'];
                  String userName = 'Unknown';
                  String? userAvatar;

                  if (user is String) {
                    userName = 'User';
                  } else if (user is Map) {
                    userName = user['name'] ?? 'Unknown';
                    userAvatar = user['avatar'];
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: userAvatar != null
                          ? UrlUtils.getAvatarImageProvider(userAvatar)
                          : null,
                      child: userAvatar == null
                          ? Text(
                              userName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(userName),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessageForMe(String messageId) async {
    final result = await MessagingService.deleteMessageForMe(messageId);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _messages.removeWhere((msg) => msg['_id'] == messageId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMessageForEveryone(String messageId) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'This message will be deleted for everyone in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final result = await MessagingService.deleteMessageForEveryone(messageId);

    if (!mounted) return;

    if (result['success'] == true) {
      // Message will be updated via socket event
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted for everyone'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build avatar circle for message - handles both network and local asset avatars
  Widget _buildAvatarCircle(String? avatarUrl, String? fallbackName) {
    if (avatarUrl != null && UrlUtils.isLocalAsset(avatarUrl)) {
      // Local asset (like bot avatars) - use Image widget with AssetImage
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: ClipOval(
          child: Image.asset(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  (fallbackName != null && fallbackName.isNotEmpty)
                      ? fallbackName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Network image - use CircleAvatar with NetworkImage
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        backgroundImage: avatarUrl != null
            ? NetworkImage(UrlUtils.getFullAvatarUrl(avatarUrl))
            : null,
        child: avatarUrl == null
            ? Text(
                (fallbackName != null && fallbackName.isNotEmpty)
                    ? fallbackName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              )
            : null,
      );
    }
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool showAvatar, {
    bool isLastMessage = false,
  }) {
    final isMe = message['sender']?['_id']?.toString() == _currentUserId;
    final content = message['content'] ?? '';
    final isDeleted = message['isDeleted'] ?? false;
    final timestamp = message['createdAt'];
    final isRead = message['isRead'] ?? false;
    final senderAvatar = message['sender']?['avatar'];
    final senderName = message['sender']?['name'];
    final senderId = message['sender']?['_id']?.toString();
    final messageId = message['_id']?.toString();

    // Create or get the key for this message
    if (messageId != null && !_messageKeys.containsKey(messageId)) {
      _messageKeys[messageId] = GlobalKey();
    }

    final isHighlighted = messageId == _highlightedMessageId;

    return AnimatedContainer(
      key: messageId != null ? _messageKeys[messageId] : null,
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.amber.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for other user's messages
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: showAvatar
                    ? GestureDetector(
                        onTap: () {
                          // Navigate to sender's profile
                          if (senderId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfilePage(userId: senderId),
                              ),
                            );
                          }
                        },
                        child: _buildAvatarCircle(senderAvatar, senderName),
                      )
                    : const SizedBox(
                        width: 32,
                      ), // Placeholder to maintain alignment
              ),

            // Message bubble with swipe-to-reply
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Dismissible(
                    key: Key('${message['_id']?.toString()}_dismissible'),
                    direction: isMe
                        ? DismissDirection.endToStart
                        : DismissDirection.startToEnd,
                    confirmDismiss: (direction) async {
                      // Trigger reply action
                      setState(() {
                        _replyingTo = message;
                      });
                      return false; // Don't actually dismiss, just use the swipe gesture
                    },
                    background: Container(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      padding: EdgeInsets.only(
                        left: isMe ? 0 : 20,
                        right: isMe ? 20 : 0,
                      ),
                      child: Icon(
                        Icons.reply,
                        color: Colors.grey[400],
                        size: 28,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // Toggle timestamp visibility
                        setState(() {
                          if (_showTimestampForMessageId == messageId) {
                            _showTimestampForMessageId = null;
                          } else {
                            _showTimestampForMessageId = messageId;
                          }
                        });
                      },
                      onLongPress: () => _showMessageOptions(message, isMe),
                      child: Container(
                        margin: EdgeInsets.only(
                          left: isMe ? 40 : 0,
                          right: isMe ? 0 : 40,
                          bottom: showAvatar ? 4 : 1,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveDimensions.getHorizontalPadding(
                                  context) *
                              0.9,
                          vertical:
                              ResponsiveDimensions.getVerticalPadding(context) *
                                  0.85,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[600] : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              ResponsiveDimensions.getBorderRadius(context) *
                                  1.5,
                            ),
                            topRight: Radius.circular(
                              ResponsiveDimensions.getBorderRadius(context) *
                                  1.5,
                            ),
                            bottomLeft: Radius.circular(
                              isMe || !showAvatar
                                  ? ResponsiveDimensions.getBorderRadius(
                                          context) *
                                      1.5
                                  : ResponsiveDimensions.getBorderRadius(
                                          context) *
                                      0.3,
                            ),
                            bottomRight: Radius.circular(
                              isMe && showAvatar
                                  ? ResponsiveDimensions.getBorderRadius(
                                          context) *
                                      0.3
                                  : ResponsiveDimensions.getBorderRadius(
                                          context) *
                                      1.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show replied message if exists
                            if (message['replyTo'] != null) ...[
                              _buildReplyReference(message['replyTo'], isMe),
                              SizedBox(
                                  height:
                                      ResponsiveDimensions.getVerticalPadding(
                                              context) /
                                          2),
                            ],

                            // Show media if exists
                            if (message['type'] == 'image' &&
                                message['mediaUrl'] != null) ...[
                              _buildImageMessage(message['mediaUrl'], isMe),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            if (message['type'] == 'video' &&
                                message['mediaUrl'] != null) ...[
                              _buildVideoMessage(message['mediaUrl'], isMe),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            if (message['type'] == 'document' &&
                                message['mediaUrl'] != null) ...[
                              _buildDocumentMessage(message, isMe),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            // Show voice message if exists
                            if (message['type'] == 'voice' &&
                                message['mediaUrl'] != null) ...[
                              VoiceMessageWidget(
                                audioUrl: message['mediaUrl'],
                                duration: message['duration'],
                                isSender: isMe,
                                waveformData: message['waveformData'] != null
                                    ? List<double>.from(message['waveformData'])
                                    : null,
                              ),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            // Show shared story if exists
                            if (message['type'] == 'shared_story' &&
                                message['sharedStory'] != null) ...[
                              _buildSharedStoryMessage(
                                message['sharedStory'],
                                isMe,
                              ),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            // Show shared marketplace item if exists
                            if (message['type'] == 'shared_marketplace' &&
                                message['sharedMarketplaceItem'] != null) ...[
                              _buildSharedMarketplaceMessage(
                                message['sharedMarketplaceItem'],
                                isMe,
                              ),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            // Show shared post if exists
                            if (message['type'] == 'shared_post' &&
                                message['sharedPost'] != null) ...[
                              _buildSharedPostMessage(
                                message['sharedPost'],
                                isMe,
                              ),
                              if (content.isNotEmpty)
                                SizedBox(
                                    height:
                                        ResponsiveDimensions.getVerticalPadding(
                                                context) /
                                            2),
                            ],

                            // Show text content
                            if (content.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDeleted)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.block,
                                        size: 16,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      content,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: ResponsiveDimensions
                                            .getBodyFontSize(context),
                                        fontStyle: isDeleted
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  // Show edited badge
                                  if (message['isEdited'] == true) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(edited)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            // Show timestamp for last message or read status for sender
                            if (showAvatar) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  // Show date/time format for the last message only
                                  if (isLastMessage && timestamp != null)
                                    Text(
                                      // Use TimeUtils to format as YYYY/MM/DD HH:MM
                                      _formatMessageTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  // Show read status for sender
                                  if (isMe) ...[
                                    if (isLastMessage && timestamp != null)
                                      const SizedBox(width: 4),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.check,
                                      size: 14,
                                      color: isRead
                                          ? Colors.lightBlue[100]
                                          : Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ), // Column
                      ), // Container
                    ), // GestureDetector
                  ), // Dismissible
                  // Show reactions
                  if (message['reactions'] != null &&
                      (message['reactions'] as List).isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        left: isMe ? 0 : 12,
                        right: isMe ? 12 : 0,
                      ),
                      child: _buildReactions(
                        message['reactions'],
                        message['_id']?.toString() ?? '',
                        isMe,
                      ),
                    ),

                  // Show timestamp when message is tapped
                  if (_showTimestampForMessageId == messageId &&
                      timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 12,
                        right: 12,
                      ),
                      child: Text(
                        _formatFullTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ], // Column children
              ), // Column
            ), // Flexible
          ], // Row children
        ), // Row
      ), // Padding
    ); // AnimatedContainer
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Failed messages banner
          if (_failedMessages.isNotEmpty) _buildFailedMessagesBanner(),

          // Reply banner
          if (_replyingTo != null) _buildReplyBanner(),

          // Media preview banner
          if (_selectedMediaFile != null) _buildMediaPreview(),

          // Voice recorder widget
          if (_isRecordingVoice)
            VoiceRecorderWidget(
              onRecordingComplete: (audioPath, duration) {
                _sendVoiceMessage(audioPath, duration);
              },
              onCancel: () {
                setState(() {
                  _isRecordingVoice = false;
                });
              },
            ),

          // Message input
          if (!_isRecordingVoice)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Action buttons (camera, gallery, etc.)
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: Colors.blue[600],
                        size: 28,
                      ),
                      onPressed: () {
                        // Show more options (photos, files, etc.)
                        _showMoreOptions();
                      },
                    ),

                    // Text input
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: 120, // Limit max height for multiline
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          onChanged: _handleTyping,
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Aa',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _showEmojiPicker
                                        ? Icons.emoji_emotions
                                        : Icons.emoji_emotions_outlined,
                                    color: _showEmojiPicker
                                        ? Colors.blue
                                        : Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showEmojiPicker = !_showEmojiPicker;
                                      if (_showEmojiPicker) {
                                        _focusNode.unfocus();
                                      } else {
                                        _focusNode.requestFocus();
                                      }
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          maxLines: null,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Voice message button (always visible)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRecordingVoice = true;
                          _showEmojiPicker = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button (always visible)
                    GestureDetector(
                      onTap: (_isSending ||
                              (_messageController.text.trim().isEmpty &&
                                  _selectedMediaFile == null))
                          ? null
                          : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isSending
                              ? Colors.grey
                              : (_messageController.text.trim().isEmpty &&
                                      _selectedMediaFile == null)
                                  ? Colors.grey[400]
                                  : Colors.blue[600],
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (Category? category, Emoji emoji) {
                  _onEmojiSelected(emoji);
                },
                onBackspacePressed: () {
                  _onBackspacePressed();
                },
                config: const Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.emoji.length,
      ),
    );
  }

  void _onBackspacePressed() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.start > 0) {
      final newText = text.substring(0, selection.start - 1) +
          text.substring(selection.start);
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start - 1),
      );
    }
  }

  Widget _buildDocumentMessage(Map<String, dynamic> message, bool isMe) {
    final fileName = message['fileName'] ?? 'Document';
    final fileSize = message['fileSize'];
    final mediaUrl = message['mediaUrl'];

    // Format file size
    String formatFileSize(int? bytes) {
      if (bytes == null) return '';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    // Get file extension and icon
    String getFileExtension(String name) {
      final parts = name.split('.');
      return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
    }

    IconData getFileIcon(String name) {
      final ext = name.split('.').last.toLowerCase();
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow;
        case 'zip':
        case 'rar':
        case '7z':
          return Icons.folder_zip;
        case 'txt':
          return Icons.text_snippet;
        default:
          return Icons.insert_drive_file;
      }
    }

    return GestureDetector(
      onTap: () {
        // Download document
        _downloadFile(mediaUrl, fileName);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // File icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                getFileIcon(fileName),
                color: isMe ? Colors.white : Colors.blue[700],
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        getFileExtension(fileName),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      if (fileSize != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Text(
                          formatFileSize(fileSize),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download icon
            Icon(
              Icons.download,
              color: isMe ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedStoryMessage(Map<String, dynamic> story, bool isMe) {
    final mediaType = story['mediaType'] as String?;
    final mediaUrl = story['mediaUrl'] as String?;
    final textContent = story['textContent'] as String?;
    final backgroundColor = story['backgroundColor'] as String?;
    final author = story['author'] as Map<String, dynamic>?;
    final authorName = author?['name'] ?? 'Someone';

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story preview
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: backgroundColor != null
                  ? Color(
                      int.parse(backgroundColor.substring(1), radix: 16) +
                          0xFF000000,
                    )
                  : Colors.black,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media or text content
                if (mediaType == 'image' && mediaUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Image.network(
                      '${ApiService.baseApi}$mediaUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                else if (mediaType == 'video' && mediaUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          '${ApiService.baseApi}$mediaUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.black),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (mediaType == 'text' && textContent != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        textContent,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Story label overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Story',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Author info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: author?['avatar'] != null
                      ? UrlUtils.getAvatarImageProvider(author!['avatar'])
                      : null,
                  child: author?['avatar'] == null
                      ? Text(
                          authorName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$authorName's story",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostMessage(Map<String, dynamic> post, bool isMe) {
    // Safely extract post data
    final content = post['content'] as String? ?? '';
    final images = post['images'] as List? ?? [];
    final videos = post['videos'] as List? ?? [];
    final author = post['author'] as Map<String, dynamic>?;
    final authorName = author?['name'] ?? 'Someone';
    final createdAt = post['createdAt'] as String?;

    // Handle loading state if post is just an ObjectId string
    if (post.isEmpty || (post.length == 1 && post.containsKey('_id'))) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading post...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300]!,
          width: 1.5,
        ),
        color:
            isMe ? Colors.blue[700]?.withValues(alpha: 0.2) : Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: author?['avatar'] != null
                      ? UrlUtils.getAvatarImageProvider(author!['avatar'])
                      : null,
                  child: author?['avatar'] == null
                      ? Text(
                          authorName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt != null)
                        Text(
                          _formatMessageTimestamp(createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media preview (first image or video)
          if (images.isNotEmpty || videos.isNotEmpty) ...[
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (videos.isNotEmpty)
                      Image.network(
                        '${ApiService.baseApi}${videos[0]}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.video_library,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      Image.network(
                        '${ApiService.baseApi}${images[0]}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    if (videos.isNotEmpty)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Content
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMe ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (content.isNotEmpty &&
                    (images.length > 1 || videos.length > 1))
                  const SizedBox(height: 6),
                if (images.length > 1 || videos.length > 1)
                  Text(
                    '+${(images.length + videos.length) - 1} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Action button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[300]!,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final postId = post['_id'];
                  if (postId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(postId: postId),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post details not available'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  child: Text(
                    'View post',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : Colors.blue[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedMarketplaceMessage(Map<String, dynamic> item, bool isMe) {
    // Safely extract marketplace item data
    final title = item['title'] as String? ?? 'Marketplace Item';
    final images = item['images'] as List? ?? [];
    final price = item['price'] as num? ?? 0;
    final description = item['description'] as String? ?? '';
    final seller = item['seller'] as Map<String, dynamic>?;
    final sellerName = seller?['name'] ?? 'Seller';
    final sellerAvatar = seller?['avatar'] as String?;
    final condition = item['condition'] as String? ?? '';
    final itemId = item['_id']?.toString();

    // Handle loading state if item is just an ObjectId string
    if (item.isEmpty || (item.length == 1 && item.containsKey('_id'))) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading item...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300]!,
          width: 1.5,
        ),
        color: isMe ? Colors.green[700]?.withValues(alpha: 0.2) : Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isMe ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: sellerAvatar != null
                      ? UrlUtils.getAvatarImageProvider(sellerAvatar)
                      : null,
                  child: sellerAvatar == null
                      ? Text(
                          sellerName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketplace Item',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white.withValues(alpha: 0.8) : Colors.grey[700],
                        ),
                      ),
                      Text(
                        sellerName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Item image
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    '${ApiService.baseApi}${images[0]}',
                    fit: BoxFit.cover,
                    height: 180,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey, size: 48),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    ),
                ],
              ),
            ),

          // Item details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.white.withValues(alpha: 0.8) : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.green[700],
                      ),
                    ),
                    if (condition.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          condition.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isMe ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (itemId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MarketplaceListingDetailPage(listingId: itemId),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item details not available'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store, size: 16, color: isMe ? Colors.white : Colors.blue[600]),
                      const SizedBox(width: 6),
                      Text(
                        'View Listing',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyReference(
    Map<String, dynamic> repliedMsg,
    bool isCurrentUserMessage,
  ) {
    final replyContent = repliedMsg['content'] as String? ?? '';
    final replySender = repliedMsg['sender'] as Map<String, dynamic>?;
    final senderName = replySender?['name'] ?? 'Unknown';
    final senderAvatar = replySender?['avatar'] as String?;
    final replyMessageId = repliedMsg['_id']?.toString();
    final replyType = repliedMsg['type'] as String?;

    // Display appropriate content based on message type
    String displayContent;
    IconData? contentIcon;
    if (replyType == 'image') {
      displayContent = 'Image';
      contentIcon = Icons.image;
    } else if (replyType == 'video') {
      displayContent = 'Video';
      contentIcon = Icons.videocam;
    } else if (replyType == 'voice') {
      displayContent = 'Voice Message';
      contentIcon = Icons.mic;
    } else if (replyType == 'document') {
      displayContent = repliedMsg['fileName'] ?? 'Document';
      contentIcon = Icons.attach_file;
    } else if (replyType == 'shared_marketplace') {
      displayContent = repliedMsg['sharedMarketplaceItem']?['title'] ?? 'Marketplace Item';
      contentIcon = Icons.store;
    } else {
      displayContent = replyContent.length > 60
          ? '${replyContent.substring(0, 60)}...'
          : replyContent;
    }

    return GestureDetector(
      onTap: () {
        if (replyMessageId != null) {
          _scrollToMessage(replyMessageId);
          // Highlight the replied message
          setState(() {
            _highlightedMessageId = replyMessageId;
          });
          // Remove highlight after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _highlightedMessageId = null;
              });
            }
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveDimensions.getHorizontalPadding(context) * 0.8,
          vertical: ResponsiveDimensions.getVerticalPadding(context) * 0.6,
        ),
        decoration: BoxDecoration(
          color: isCurrentUserMessage
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(
            ResponsiveDimensions.getBorderRadius(context) * 0.8,
          ),
          border: Border(
            left: BorderSide(
              color: isCurrentUserMessage
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.blue[400]!,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar (optional, small)
            if (senderAvatar != null) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                  UrlUtils.getFullAvatarUrl(senderAvatar),
                ),
                backgroundColor: Colors.grey[300],
              ),
              SizedBox(width: ResponsiveDimensions.getItemSpacing(context) / 2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize:
                          ResponsiveDimensions.getCaptionFontSize(context) *
                              0.95,
                      fontWeight: FontWeight.w700,
                      color: isCurrentUserMessage
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.blue[700],
                    ),
                  ),
                  SizedBox(
                      height:
                          ResponsiveDimensions.getVerticalPadding(context) / 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contentIcon != null) ...[
                        Icon(
                          contentIcon,
                          size: ResponsiveDimensions.getIconSize(context) * 0.7,
                          color: isCurrentUserMessage
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.blue[600],
                        ),
                        SizedBox(
                            width:
                                ResponsiveDimensions.getItemSpacing(context) /
                                    3),
                      ],
                      Flexible(
                        child: Text(
                          displayContent,
                          style: TextStyle(
                            fontSize:
                                ResponsiveDimensions.getBodyFontSize(context) *
                                    0.9,
                            color: isCurrentUserMessage
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.grey[700],
                            fontWeight: replyType != null && replyType != 'text'
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveDimensions.getItemSpacing(context) / 2),
            Icon(
              Icons.arrow_forward_ios,
              size: ResponsiveDimensions.getIconSize(context) * 0.65,
              color: isCurrentUserMessage
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(String mediaUrl, bool isMe) {
    final imageUrl = '${ApiService.baseApi}$mediaUrl';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image type label
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image,
                size: 14,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Image',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () {
                  // Show full screen image
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: InteractiveViewer(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 250,
                    maxHeight: 350,
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[700] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white : Colors.blue[600]!,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Loading image...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ), // Image.network
                ), // Container
              ), // GestureDetector
            ), // ClipRRect
            // Download button overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final fileName =
                        'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    _downloadFile(mediaUrl, fileName);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.download, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ], // Stack children
        ), // Stack
      ], // Column children
    );
  }

  Widget _buildVideoMessage(String mediaUrl, bool isMe) {
    final videoUrl = '${ApiService.baseApi}$mediaUrl';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video type label
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam,
                size: 14,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Video',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () {
              // Navigate to full screen video player
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(videoUrl: videoUrl),
                ),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 350),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Thumbnail or placeholder
                  Container(
                    width: 250,
                    height: 200,
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  // Play button overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  // Tap to play indicator
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tap to play',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // Download button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final fileName =
                              'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
                          _downloadFile(mediaUrl, fileName);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 20,
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

  Widget _buildFailedMessagesBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border(
          left: BorderSide(color: Colors.red[600]!, width: 4),
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_failedMessages.length} message${_failedMessages.length > 1 ? 's' : ''} failed to send',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to retry or dismiss',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Retry all failed messages
              for (var failedMsg in [..._failedMessages]) {
                _retryFailedMessage(failedMsg);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[600],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry All',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _failedMessages.clear();
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    final replyContent = _replyingTo!['content'] as String;
    final replySender = _replyingTo!['sender'] as Map<String, dynamic>?;
    final senderName = replySender?['name'] ?? 'Unknown';
    final isMe = replySender?['_id']?.toString() == _currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          left: BorderSide(color: Colors.blue[600]!, width: 4),
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${isMe ? 'yourself' : senderName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyContent.length > 50
                      ? '${replyContent.substring(0, 50)}...'
                      : replyContent,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          // Media thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey[300],
              child: _selectedMediaType == 'image'
                  ? FutureBuilder<Uint8List>(
                      future: _selectedMediaFile!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image, size: 40);
                            },
                          );
                        } else if (snapshot.hasError) {
                          return const Icon(Icons.broken_image, size: 40);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                      },
                    )
                  : _selectedMediaType == 'video'
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              color: Colors.black87,
                              child: const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        )
                      : Container(
                          color: Colors.blue[50],
                          child: Icon(
                            Icons.insert_drive_file,
                            color: Colors.blue[700],
                            size: 40,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 12),
          // Media info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedMediaType == 'image'
                      ? 'Image selected'
                      : _selectedMediaType == 'video'
                          ? 'Video selected'
                          : 'Document selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (_selectedMediaType == 'document' &&
                    _selectedMediaFile != null)
                  Text(
                    _selectedMediaFile!.name,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Tap send to upload',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _selectedMediaFile = null;
                _selectedMediaType = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      if (!mounted) return;
      // Show media type selection
      final mediaType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Media Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: Text(source == ImageSource.camera
                    ? 'Photo with Filters'
                    : 'Image'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: Text(source == ImageSource.camera
                    ? 'Video with Filters'
                    : 'Video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
            ],
          ),
        ),
      );

      if (mediaType == null || !mounted) return;

      XFile? pickedFile;

      // Use gallery selection - camera filters removed
      final ImagePicker picker = ImagePicker();

      if (mediaType == 'image') {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      } else if (mediaType == 'video') {
        pickedFile = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
      }

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedMediaFile = pickedFile;
          _selectedMediaType = mediaType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'rtf',
          'csv',
          'zip',
          'rar',
          '7z',
        ],
        allowMultiple: false,
        withData: true, // Required for web - loads file bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Convert PlatformFile to XFile for compatibility with existing code
        // Always prioritize bytes to avoid web path access exception
        XFile xFile;
        if (file.bytes != null) {
          // Web and when withData: true - Use bytes with name
          // Map file extensions to proper MIME types
          String? mimeType;
          final ext = file.extension?.toLowerCase();
          switch (ext) {
            case 'pdf':
              mimeType = 'application/pdf';
              break;
            case 'doc':
              mimeType = 'application/msword';
              break;
            case 'docx':
              mimeType =
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            case 'xls':
              mimeType = 'application/vnd.ms-excel';
              break;
            case 'xlsx':
              mimeType =
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
              break;
            case 'ppt':
              mimeType = 'application/vnd.ms-powerpoint';
              break;
            case 'pptx':
              mimeType =
                  'application/vnd.openxmlformats-officedocument.presentationml.presentation';
              break;
            case 'txt':
              mimeType = 'text/plain';
              break;
            case 'rtf':
              mimeType = 'application/rtf';
              break;
            case 'csv':
              mimeType = 'text/csv';
              break;
            case 'zip':
              mimeType = 'application/zip';
              break;
            case 'rar':
              mimeType = 'application/x-rar-compressed';
              break;
            case '7z':
              mimeType = 'application/x-7z-compressed';
              break;
            default:
              mimeType = 'application/octet-stream';
          }

          xFile = XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: mimeType,
          );
        } else {
          // Fallback: Try to use path (mobile/desktop without withData)
          // This should not happen since we use withData: true
          throw Exception('File bytes not available. Please try again.');
        }

        if (!mounted) return;
        setState(() {
          _selectedMediaFile = xFile;
          _selectedMediaType = 'document';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((msg) => msg['_id'] == messageId);

    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message not found in current view'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get the key for this message
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      // Scroll to the message
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      // Highlight the message
      setState(() {
        _highlightedMessageId = messageId;
      });

      // Create highlight animation
      _highlightAnimation?.dispose();
      _highlightAnimation = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _highlightAnimation!.forward().then((_) {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _highlightAnimation?.dispose();
    _searchController.dispose();

    // Remove only our listeners, not the global ones
    if (_messageListener != null) {
      _socketService.off('message:new', _messageListener);
    }
    if (_messagesReadListener != null) {
      _socketService.off('messages:read', _messagesReadListener);
    }
    if (_typingStartListener != null) {
      _socketService.off('typing:start', _typingStartListener);
    }
    if (_typingStopListener != null) {
      _socketService.off('typing:stop', _typingStopListener);
    }
    if (_messageDeletedListener != null) {
      _socketService.off('message:deleted', _messageDeletedListener);
    }

    super.dispose();
  }
}

// Animated typing dots widget
class TypingDotsAnimation extends StatefulWidget {
  const TypingDotsAnimation({super.key});

  @override
  State<TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: 4),
        _buildDot(1),
        const SizedBox(width: 4),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create staggered animation for each dot
        final delay = index * 0.15;
        final value = (_controller.value - delay) % 1.0;

        // Create bounce effect
        final bounce = (1 - (value * 2 - 1).abs());
        final opacity = 0.4 + (0.6 * bounce);

        return Transform.translate(
          offset: Offset(0, -6 * bounce),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Forward message dialog widget
class _ForwardMessageDialog extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> message;
  final Function(List<String>) onForward;

  const _ForwardMessageDialog({
    required this.messageId,
    required this.message,
    required this.onForward,
  });

  @override
  State<_ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<_ForwardMessageDialog> {
  List<Map<String, dynamic>> _conversations = [];
  final Set<String> _selectedConversationIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);

    try {
      final result = await MessagingService.getConversations();

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _conversations = List<Map<String, dynamic>>.from(
              result['data']['conversations'] ?? [],
            );
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(result['message'] ?? 'Failed to load conversations'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredConversations() {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }

    return _conversations.where((conv) {
      final name = conv['participants']
              ?.cast<Map<String, dynamic>>()
              .map((p) => p['name'] as String? ?? '')
              .join(', ')
              .toLowerCase() ??
          '';

      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _forwardMessage() async {
    if (_selectedConversationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one conversation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await widget.onForward(_selectedConversationIds.toList());
  }

  String _getConversationTitle(Map<String, dynamic> conversation) {
    final isGroup = conversation['isGroup'] ?? false;

    if (isGroup) {
      return conversation['groupName'] ?? 'Group Chat';
    } else {
      // Get the other participant's name
      final participants = conversation['participants'] as List? ?? [];
      if (participants.isNotEmpty) {
        return participants[0]['name'] ?? 'Unknown';
      }
      return 'Conversation';
    }
  }

  String _getConversationSubtitle(Map<String, dynamic> conversation) {
    final lastMessage = conversation['lastMessage'];
    if (lastMessage is Map) {
      return (lastMessage['content'] as String?)?.replaceAll('\n', ' ') ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Forward Message',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Conversation list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No conversations found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _getFilteredConversations().length,
                          itemBuilder: (context, index) {
                            final conversation =
                                _getFilteredConversations()[index];
                            final conversationId =
                                conversation['_id'] as String?;
                            final isSelected = conversationId != null &&
                                _selectedConversationIds
                                    .contains(conversationId);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                if (conversationId != null) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedConversationIds
                                          .add(conversationId);
                                    } else {
                                      _selectedConversationIds
                                          .remove(conversationId);
                                    }
                                  });
                                }
                              },
                              title: Text(
                                _getConversationTitle(conversation),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _getConversationSubtitle(conversation),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
            ),
            // Selected count
            if (_selectedConversationIds.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${_selectedConversationIds.length} conversation${_selectedConversationIds.length != 1 ? 's' : ''} selected',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedConversationIds.isEmpty
                        ? null
                        : _forwardMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      'Forward (${_selectedConversationIds.length})',
                      style: TextStyle(
                        color: _selectedConversationIds.isEmpty
                            ? Colors.grey[600]
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
