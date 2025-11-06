// Mock implementations for testing chat functionality
// This file provides mock services to test chat features without
// requiring actual backend or socket connections

import 'package:flutter_test/flutter_test.dart';

// Mock for SocketService
class MockSocketService {
  final Map<String, List<Function(dynamic)>> _listeners = {};
  bool _isConnected = true;

  void on(String event, Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void emit(String event, [dynamic data]) {
    if (_listeners.containsKey(event)) {
      for (var callback in _listeners[event]!) {
        callback(data);
      }
    }
  }

  void disconnect() {
    _isConnected = false;
  }

  void connect() {
    _isConnected = true;
  }

  bool isConnected() => _isConnected;

  void removeListener(String event) {
    _listeners.remove(event);
  }

  void removeAllListeners() {
    _listeners.clear();
  }
}

// Mock for API Service
class MockApiService {
  Map<String, dynamic>? _nextResponse;
  Exception? _nextError;

  void setNextResponse(Map<String, dynamic> response) {
    _nextResponse = response;
  }

  void setNextError(Exception error) {
    _nextError = error;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    if (_nextError != null) {
      throw _nextError!;
    }
    return _nextResponse ?? {'success': true, 'data': {}};
  }

  Future<Map<String, dynamic>> post(String endpoint, dynamic data) async {
    if (_nextError != null) {
      throw _nextError!;
    }
    return _nextResponse ?? {'success': true, 'data': data};
  }

  Future<Map<String, dynamic>> put(String endpoint, dynamic data) async {
    if (_nextError != null) {
      throw _nextError!;
    }
    return _nextResponse ?? {'success': true, 'data': data};
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    if (_nextError != null) {
      throw _nextError!;
    }
    return _nextResponse ?? {'success': true};
  }
}

// Mock for Secure Storage Service
class MockSecureStorageService {
  final Map<String, String> _storage = {};

  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  Future<String?> read(String key) async {
    return _storage[key];
  }

  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  void clear() {
    _storage.clear();
  }
}

// Mock for Messaging Service
class MockMessagingService {
  final List<Map<String, dynamic>> _sentMessages = [];

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
  }) async {
    final message = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'content': content,
      'conversationId': conversationId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'replyToId': replyToId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _sentMessages.add(message);
    return {
      'success': true,
      'data': message,
    };
  }

  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    return {
      'success': true,
      'data': {
        'messages': [],
        'pagination': {
          'currentPage': page,
          'totalPages': 1,
          'hasMore': false,
        }
      }
    };
  }

  Future<Map<String, dynamic>> getConversations() async {
    return {
      'success': true,
      'data': {'conversations': []}
    };
  }

  List<Map<String, dynamic>> getSentMessages() => _sentMessages;

  void clear() {
    _sentMessages.clear();
  }
}

// Test helper functions
class TestDataGenerator {
  static Map<String, dynamic> generateMessage({
    String? id,
    String? senderId,
    String? conversationId,
    String content = 'Test message',
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': senderId ?? 'user_123',
      'conversationId': conversationId ?? 'conv_123',
      'content': content,
      'createdAt': createdAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
      'reactions': {},
      'readBy': [],
      'isPinned': false,
      'isDeleted': false,
      'replyTo': null,
    };
  }

  static Map<String, dynamic> generateConversation({
    String? id,
    String? name,
    List<String>? participantIds,
  }) {
    return {
      'id': id ?? 'conv_${DateTime.now().millisecondsSinceEpoch}',
      'name': name ?? 'Test Conversation',
      'participantIds': participantIds ?? ['user_123', 'user_456'],
      'lastMessage': 'Last message in conversation',
      'lastMessageAt': DateTime.now(),
      'unreadCount': 0,
      'isGroup': (participantIds?.length ?? 2) > 2,
      'createdAt': DateTime.now(),
    };
  }

  static Map<String, dynamic> generateUser({
    String? id,
    String? username,
    String? email,
  }) {
    return {
      'id': id ?? 'user_123',
      'username': username ?? 'testuser',
      'email': email ?? 'test@example.com',
      'avatar': 'https://example.com/avatar.jpg',
      'isOnline': true,
      'lastActive': DateTime.now(),
    };
  }
}
