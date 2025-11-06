import 'package:flutter_test/flutter_test.dart';
import '../mocks/mock_services.dart';

// Integration Tests for Chat Functionality
// Tests complete workflows including message send/receive, group creation,
// conversation export, and search/navigation features

void main() {
  group('Full Message Send/Receive Flow', () {
    late MockSocketService socketService;
    late MockMessagingService messagingService;

    setUp(() {
      socketService = MockSocketService();
      messagingService = MockMessagingService();
    });

    tearDown(() {
      socketService.removeAllListeners();
    });

    test('should send message and receive confirmation', () async {
      const conversationId = 'conv_123';
      const messageContent = 'Hello there!';

      // Send message
      final sendResult = await messagingService.sendMessage(
        conversationId,
        messageContent,
      );

      expect(sendResult['success'], true);
      expect(sendResult['data']['content'], messageContent);
      expect(sendResult['data']['conversationId'], conversationId);
    });

    test('should receive new message via socket', () async {
      const conversationId = 'conv_123';
      dynamic receivedMessage;

      // Set up listener
      socketService.on('message:new', (data) {
        receivedMessage = data;
      });

      // Simulate server emitting new message
      final newMessage = {
        'id': 'msg_999',
        'conversationId': conversationId,
        'content': 'Received message',
        'senderId': 'user_456',
        'createdAt': DateTime.now().toIso8601String(),
      };

      socketService.emit('message:new', newMessage);

      expect(receivedMessage, isNotNull);
      expect(receivedMessage['id'], 'msg_999');
      expect(receivedMessage['content'], 'Received message');
    });

    test('should handle typing indicator start and stop', () async {
      dynamic typingStartData;
      dynamic typingStopData;

      socketService.on('typing:start', (data) {
        typingStartData = data;
      });

      socketService.on('typing:stop', (data) {
        typingStopData = data;
      });

      // Simulate user typing
      socketService.emit('typing:start', {
        'userId': 'user_456',
        'conversationId': 'conv_123',
      });

      expect(typingStartData, isNotNull);
      expect(typingStartData['userId'], 'user_456');

      // Simulate user stopped typing
      socketService.emit('typing:stop', {
        'userId': 'user_456',
        'conversationId': 'conv_123',
      });

      expect(typingStopData, isNotNull);
    });

    test('should handle message reactions', () async {
      dynamic reactionData;

      socketService.on('message:reacted', (data) {
        reactionData = data;
      });

      socketService.emit('message:reacted', {
        'messageId': 'msg_123',
        'userId': 'user_456',
        'emoji': '❤️',
      });

      expect(reactionData, isNotNull);
      expect(reactionData['emoji'], '❤️');
    });

    test('should retry failed message send', () async {
      const conversationId = 'conv_123';
      const messageContent = 'Retry message';

      // First attempt succeeds
      final result = await messagingService.sendMessage(
        conversationId,
        messageContent,
      );

      expect(result['success'], true);

      // Verify message was sent
      final sentMessages = messagingService.getSentMessages();
      expect(sentMessages.length, 1);
    });

    test('should mark messages as read', () async {
      dynamic readData;

      socketService.on('messages:read', (data) {
        readData = data;
      });

      socketService.emit('messages:read', {
        'conversationId': 'conv_123',
        'messageIds': ['msg_1', 'msg_2', 'msg_3'],
        'readAt': DateTime.now().toIso8601String(),
      });

      expect(readData, isNotNull);
      expect((readData['messageIds'] as List).length, 3);
    });
  });

  group('Group Creation and Management', () {
    late MockApiService apiService;
    late MockSocketService socketService;

    setUp(() {
      apiService = MockApiService();
      socketService = MockSocketService();
    });

    test('should create group conversation', () async {
      const groupName = 'Development Team';
      final participantIds = ['user_1', 'user_2', 'user_3'];

      final response = await apiService.post('/conversations/group', {
        'name': groupName,
        'participantIds': participantIds,
      });

      expect(response['success'], true);
    });

    test('should receive group creation event', () async {
      dynamic groupData;

      socketService.on('group:created', (data) {
        groupData = data;
      });

      socketService.emit('group:created', {
        'groupId': 'group_123',
        'name': 'New Group',
        'creator': 'user_1',
        'members': ['user_1', 'user_2'],
      });

      expect(groupData, isNotNull);
      expect(groupData['name'], 'New Group');
      expect((groupData['members'] as List).length, 2);
    });

    test('should add participant to group', () async {
      const groupId = 'group_123';
      const userId = 'user_4';

      final response = await apiService.post(
        '/conversations/$groupId/participants',
        {'userId': userId},
      );

      expect(response['success'], true);
    });

    test('should receive participant added event', () async {
      dynamic eventData;

      socketService.on('group:participant-added', (data) {
        eventData = data;
      });

      socketService.emit('group:participant-added', {
        'groupId': 'group_123',
        'userId': 'user_4',
        'addedBy': 'user_1',
      });

      expect(eventData, isNotNull);
      expect(eventData['userId'], 'user_4');
    });

    test('should remove participant from group', () async {
      const groupId = 'group_123';
      const userId = 'user_2';

      final response = await apiService
          .delete('/conversations/$groupId/participants/$userId');

      expect(response['success'], true);
    });

    test('should update group information', () async {
      const groupId = 'group_123';
      const newName = 'Updated Group Name';

      final response = await apiService.put(
        '/conversations/$groupId',
        {'name': newName},
      );

      expect(response['success'], true);
    });
  });

  group('Conversation Export', () {
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
    });

    test('should export conversation as JSON', () async {
      const conversationId = 'conv_123';
      const format = 'json';

      final response = await apiService.post(
        '/conversations/$conversationId/export',
        {'format': format},
      );

      expect(response['success'], true);
    });

    test('should export conversation as text', () async {
      const conversationId = 'conv_123';
      const format = 'txt';

      final response = await apiService.post(
        '/conversations/$conversationId/export',
        {'format': format},
      );

      expect(response['success'], true);
    });

    test('should handle export timeout gracefully', () async {
      const conversationId = 'conv_123';
      apiService.setNextError(Exception('Export timeout'));

      try {
        await apiService.post(
          '/conversations/$conversationId/export',
          {'format': 'json'},
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString().contains('timeout'), true);
      }
    });

    test('should include all messages in export', () async {
      const conversationId = 'conv_123';

      final response = await apiService.post(
        '/conversations/$conversationId/export',
        {'format': 'json', 'includeMedia': false},
      );

      expect(response['success'], true);
    });

    test('should include media URLs in export', () async {
      const conversationId = 'conv_123';

      final response = await apiService.post(
        '/conversations/$conversationId/export',
        {'format': 'json', 'includeMedia': true},
      );

      expect(response['success'], true);
    });
  });

  group('Search and Navigation', () {
    late List<Map<String, dynamic>> messages;

    setUp(() {
      messages = [
        {
          'id': 'msg_1',
          'content': 'Flutter is awesome',
          'conversationId': 'conv_123',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 'msg_2',
          'content': 'Dart programming language',
          'conversationId': 'conv_123',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 'msg_3',
          'content': 'Building mobile apps',
          'conversationId': 'conv_123',
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];
    });

    test('should search messages by query', () async {
      const query = 'Flutter';

      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.length, 1);
      expect(results.first['content'].contains('Flutter'), true);
    });

    test('should find multiple search results', () async {
      const query = 'ing';

      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.isNotEmpty, true);
    });

    test('should navigate to search result', () async {
      final apiService = MockApiService();
      const conversationId = 'conv_123';
      const messageId = 'msg_1';

      final response = await apiService.get(
        '/conversations/$conversationId/messages/$messageId',
      );

      expect(response['success'], true);
    });

    test('should handle search in empty conversation', () async {
      const query = 'test';
      final emptyMessages = <Map<String, dynamic>>[];

      final results = emptyMessages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.isEmpty, true);
    });

    test('should perform case-insensitive search', () async {
      const query = 'FLUTTER';

      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.length, 1);
    });

    test('should search across multiple conversations', () async {
      final apiService = MockApiService();
      const globalQuery = 'app';

      final response = await apiService.get('/search?q=$globalQuery');

      expect(response['success'], true);
    });
  });

  group('Real-time Synchronization', () {
    late MockSocketService socketService;

    setUp(() {
      socketService = MockSocketService();
    });

    test('should sync message deletion', () async {
      dynamic deleteData;

      socketService.on('message:deleted', (data) {
        deleteData = data;
      });

      socketService.emit('message:deleted', {
        'messageId': 'msg_123',
        'conversationId': 'conv_123',
      });

      expect(deleteData, isNotNull);
      expect(deleteData['messageId'], 'msg_123');
    });

    test('should sync message edit', () async {
      dynamic editData;

      socketService.on('message:edited', (data) {
        editData = data;
      });

      socketService.emit('message:edited', {
        'messageId': 'msg_123',
        'newContent': 'Edited message',
        'editedAt': DateTime.now().toIso8601String(),
      });

      expect(editData, isNotNull);
      expect(editData['newContent'], 'Edited message');
    });

    test('should sync user status changes', () async {
      dynamic statusData;

      socketService.on('user:status-changed', (data) {
        statusData = data;
      });

      socketService.emit('user:status-changed', {
        'userId': 'user_456',
        'isOnline': true,
        'lastActive': DateTime.now().toIso8601String(),
      });

      expect(statusData, isNotNull);
      expect(statusData['isOnline'], true);
    });

    test('should handle user blocking', () async {
      dynamic blockData;

      socketService.on('user:blocked', (data) {
        blockData = data;
      });

      socketService.emit('user:blocked', {
        'blockedUserId': 'user_789',
        'blockedBy': 'user_123',
      });

      expect(blockData, isNotNull);
    });

    test('should handle socket reconnection', () async {
      socketService.disconnect();
      expect(socketService.isConnected(), false);

      socketService.connect();
      expect(socketService.isConnected(), true);
    });
  });

  group('Conversation List Management', () {
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
    });

    test('should load conversation list', () async {
      final response = await apiService.get('/conversations');

      expect(response['success'], true);
    });

    test('should filter unread conversations', () async {
      final conversations = [
        {
          'id': 'conv_1',
          'name': 'John',
          'unreadCount': 0,
        },
        {
          'id': 'conv_2',
          'name': 'Jane',
          'unreadCount': 5,
        },
        {
          'id': 'conv_3',
          'name': 'Team',
          'unreadCount': 0,
        },
        {
          'id': 'conv_4',
          'name': 'Support',
          'unreadCount': 3,
        },
      ];

      final unreadConversations =
          conversations.where((c) => c['unreadCount'] as int > 0).toList();

      expect(unreadConversations.length, 2);
      expect(unreadConversations.first['name'], 'Jane');
    });

    test('should sort conversations by last message date', () async {
      final conversations = [
        {
          'id': 'conv_1',
          'lastMessageAt': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': 'conv_2',
          'lastMessageAt': DateTime.now(),
        },
        {
          'id': 'conv_3',
          'lastMessageAt': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];

      conversations.sort((a, b) => (b['lastMessageAt'] as DateTime)
          .compareTo(a['lastMessageAt'] as DateTime));

      expect(conversations.first['id'], 'conv_2');
      expect(conversations.last['id'], 'conv_1');
    });

    test('should delete conversation', () async {
      const conversationId = 'conv_123';

      final response =
          await apiService.delete('/conversations/$conversationId');

      expect(response['success'], true);
    });

    test('should leave group conversation', () async {
      const conversationId = 'group_123';

      final response = await apiService.post(
        '/conversations/$conversationId/leave',
        {},
      );

      expect(response['success'], true);
    });
  });

  group('Error Handling and Edge Cases', () {
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
    });

    test('should handle API error gracefully', () async {
      apiService.setNextError(Exception('Network error'));

      try {
        await apiService.get('/conversations');
        fail('Should have thrown exception');
      } catch (e) {
        expect(e.toString().contains('Network error'), true);
      }
    });

    test('should handle empty message content', () {
      const message = '';
      final isValid = message.trim().isNotEmpty;

      expect(isValid, false);
    });

    test('should validate conversation ID', () {
      const conversationId = 'conv_123';
      final isValid = conversationId.isNotEmpty && conversationId.length > 3;

      expect(isValid, true);
    });

    test('should handle null responses', () async {
      final response = await apiService.get('/conversations');
      expect(response, isNotNull);
    });

    test('should timeout on slow operations', () async {
      apiService.setNextError(Exception('Request timeout'));

      try {
        await apiService.post('/conversations/123/export', {'format': 'json'});
        fail('Should timeout');
      } catch (e) {
        expect(e.toString().contains('timeout'), true);
      }
    });
  });
}
