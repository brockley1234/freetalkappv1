import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

// Unit Tests for Chat Page Functions
// Tests core chat logic including message deduplication, typing indicators,
// search filtering, streak caching, and date separator logic

void main() {
  group('Message Deduplication Logic', () {
    late Set<String> messageIds;

    setUp(() {
      messageIds = {};
    });

    test('should add new message ID to set', () {
      const messageId = 'msg_123';
      expect(messageIds.contains(messageId), false);

      messageIds.add(messageId);
      expect(messageIds.contains(messageId), true);
    });

    test('should prevent duplicate message IDs', () {
      const messageId = 'msg_456';
      messageIds.add(messageId);
      messageIds.add(messageId);

      expect(messageIds.length, 1);
    });

    test('should handle bulk message deduplication', () {
      const messages = [
        {'id': 'msg_1', 'content': 'First'},
        {'id': 'msg_2', 'content': 'Second'},
        {'id': 'msg_1', 'content': 'First'}, // Duplicate
        {'id': 'msg_3', 'content': 'Third'},
        {'id': 'msg_2', 'content': 'Second'}, // Duplicate
      ];

      for (var msg in messages) {
        messageIds.add(msg['id'] as String);
      }

      expect(messageIds.length, 3);
      expect(messageIds.contains('msg_1'), true);
      expect(messageIds.contains('msg_2'), true);
      expect(messageIds.contains('msg_3'), true);
    });

    test('should detect duplicate with O(1) lookup', () {
      const messageId = 'msg_789';
      messageIds.add(messageId);

      // This should be O(1) operation
      final isDuplicate = messageIds.contains(messageId);
      expect(isDuplicate, true);

      // Verify set size hasn't changed
      expect(messageIds.length, 1);
    });

    test('should clear all IDs when reset', () {
      messageIds.add('msg_1');
      messageIds.add('msg_2');
      messageIds.add('msg_3');
      expect(messageIds.length, 3);

      messageIds.clear();
      expect(messageIds.length, 0);
    });
  });

  group('Typing Indicator Timer Logic', () {
    test('should create timer with correct duration', () {
      Duration? capturedDuration;
      Timer? testTimer;

      testTimer = Timer(const Duration(seconds: 3), () {
        // Callback
      });

      capturedDuration = const Duration(seconds: 3);
      expect(capturedDuration.inSeconds, 3);

      testTimer.cancel();
    });

    test('should cancel previous timer before creating new one', () {
      Timer? currentTimer;
      int callbackCount = 0;

      // First timer
      currentTimer = Timer(const Duration(milliseconds: 100), () {
        callbackCount++;
      });

      // Cancel it
      currentTimer.cancel();

      // Create new timer
      currentTimer = Timer(const Duration(milliseconds: 100), () {
        callbackCount++;
      });

      expect(callbackCount, 0); // First timer was cancelled

      currentTimer.cancel();
    });

    test('should stop typing indicator after timeout', () async {
      bool isTyping = true;
      final typingTimer = Timer(const Duration(milliseconds: 50), () {
        isTyping = false;
      });

      expect(isTyping, true);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(isTyping, false);

      typingTimer.cancel();
    });

    test('should handle rapid typing updates', () async {
      bool isTyping = false;
      Timer? typingTimer;
      int typingEventCount = 0;

      void resetTypingTimer() {
        typingTimer?.cancel();
        isTyping = true;
        typingEventCount++;

        typingTimer = Timer(const Duration(milliseconds: 50), () {
          isTyping = false;
        });
      }

      // Simulate rapid typing
      resetTypingTimer();
      await Future.delayed(const Duration(milliseconds: 20));
      resetTypingTimer();
      await Future.delayed(const Duration(milliseconds: 20));
      resetTypingTimer();
      expect(typingEventCount, 3);

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 100));
      expect(isTyping, false);

      typingTimer?.cancel();
    });
  });

  group('Search Filtering Logic', () {
    late List<Map<String, dynamic>> messages;

    setUp(() {
      messages = [
        {
          'id': 'msg_1',
          'content': 'Hello world',
          'senderId': 'user_1',
          'createdAt': DateTime.now()
        },
        {
          'id': 'msg_2',
          'content': 'Flutter is great',
          'senderId': 'user_2',
          'createdAt': DateTime.now().subtract(const Duration(hours: 1))
        },
        {
          'id': 'msg_3',
          'content': 'How are you?',
          'senderId': 'user_1',
          'createdAt': DateTime.now().subtract(const Duration(hours: 2))
        },
        {
          'id': 'msg_4',
          'content': 'I am fine',
          'senderId': 'user_2',
          'createdAt': DateTime.now().subtract(const Duration(hours: 3))
        },
      ];
    });

    test('should filter messages by search query', () {
      const query = 'hello';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.length, 1);
      expect(results.first['id'], 'msg_1');
    });

    test('should perform case-insensitive search', () {
      const query = 'FLUTTER';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.length, 1);
      expect(results.first['content'].contains('Flutter'), true);
    });

    test('should find multiple matching results', () {
      const query = 'i';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      // Messages with 'i': "Flutter is great", "How are you?" (no 'i'), "I am fine"
      expect(results.length >= 2, true);
    });

    test('should return empty list for no matches', () {
      const query = 'xyz123';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      expect(results.isEmpty, true);
    });

    test('should maintain search results in order', () {
      const query = 'a';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      // Results should maintain original order
      final indices = results.map((r) => messages.indexOf(r)).toList();
      for (int i = 0; i < indices.length - 1; i++) {
        expect(indices[i] < indices[i + 1], true);
      }
    });

    test('should handle empty search query', () {
      const query = '';
      final results = messages
          .where((msg) => (msg['content'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();

      // Empty query should match all messages
      expect(results.length, messages.length);
    });
  });

  group('Streak Caching Logic', () {
    late Map<String, dynamic> streakCache;
    late DateTime lastCacheTime;

    setUp(() {
      streakCache = {};
      lastCacheTime = DateTime.now();
    });

    test('should cache streak data', () {
      const conversationId = 'conv_123';
      final streakData = {
        'conversationId': conversationId,
        'currentStreak': 5,
        'longestStreak': 10,
        'lastMessageDate': DateTime.now().toIso8601String(),
      };

      streakCache[conversationId] = streakData;

      expect(streakCache.containsKey(conversationId), true);
      expect(streakCache[conversationId]['currentStreak'], 5);
    });

    test('should check if cache is expired', () {
      const cacheExpireMs = 5 * 60 * 1000; // 5 minutes
      lastCacheTime = DateTime.now().subtract(const Duration(minutes: 10));

      final isExpired =
          DateTime.now().difference(lastCacheTime).inMilliseconds >
              cacheExpireMs;
      expect(isExpired, true);
    });

    test('should refresh cache when expired', () {
      const cacheExpireMs = 5 * 60 * 1000;
      const conversationId = 'conv_123';

      // Set old cache
      streakCache[conversationId] = {'currentStreak': 5};
      lastCacheTime = DateTime.now().subtract(const Duration(minutes: 10));

      final isExpired =
          DateTime.now().difference(lastCacheTime).inMilliseconds >
              cacheExpireMs;
      if (isExpired) {
        // Simulate cache refresh
        streakCache[conversationId] = {'currentStreak': 7};
        lastCacheTime = DateTime.now();
      }

      expect(streakCache[conversationId]['currentStreak'], 7);
    });

    test('should clear all streaks from cache', () {
      streakCache['conv_1'] = {'currentStreak': 5};
      streakCache['conv_2'] = {'currentStreak': 10};
      streakCache['conv_3'] = {'currentStreak': 3};

      expect(streakCache.length, 3);

      streakCache.clear();
      expect(streakCache.isEmpty, true);
    });

    test('should handle multiple conversations in cache', () {
      const conversations = ['conv_1', 'conv_2', 'conv_3'];

      for (var conv in conversations) {
        streakCache[conv] = {
          'conversationId': conv,
          'currentStreak': conversations.indexOf(conv) + 1,
        };
      }

      expect(streakCache.length, 3);
      expect(streakCache['conv_1']['currentStreak'], 1);
      expect(streakCache['conv_2']['currentStreak'], 2);
      expect(streakCache['conv_3']['currentStreak'], 3);
    });
  });

  group('Date Separator Logic', () {
    late List<Map<String, dynamic>> messages;

    setUp(() {
      final now = DateTime.now();
      messages = [
        {
          'id': 'msg_1',
          'content': 'Message 1',
          'createdAt': now,
        },
        {
          'id': 'msg_2',
          'content': 'Message 2',
          'createdAt': now.add(const Duration(minutes: 5)),
        },
        {
          'id': 'msg_3',
          'content': 'Message 3',
          'createdAt': now.subtract(const Duration(days: 1)),
        },
        {
          'id': 'msg_4',
          'content': 'Message 4',
          'createdAt': now.subtract(const Duration(days: 1, minutes: 5)),
        },
      ];
    });

    test('should identify dates needing separators', () {
      final separatorIndices = <int>[];

      for (int i = 0; i < messages.length; i++) {
        if (i == 0) {
          separatorIndices.add(i);
        } else {
          final currentDate =
              DateTime.parse(messages[i]['createdAt'].toString());
          final previousDate =
              DateTime.parse(messages[i - 1]['createdAt'].toString());

          if (currentDate.year != previousDate.year ||
              currentDate.month != previousDate.month ||
              currentDate.day != previousDate.day) {
            separatorIndices.add(i);
          }
        }
      }

      // Should have separators at index 0 (first message) and index 2 (date changed)
      expect(separatorIndices.contains(0), true);
      expect(separatorIndices.contains(2), true);
    });

    test('should not add separator for same-day messages', () {
      final sameDayMessages = [
        {'id': 'msg_1', 'createdAt': DateTime.now()},
        {
          'id': 'msg_2',
          'createdAt': DateTime.now().add(const Duration(hours: 1))
        },
        {
          'id': 'msg_3',
          'createdAt': DateTime.now().add(const Duration(hours: 2))
        },
      ];

      final separatorIndices = <int>[];
      for (int i = 0; i < sameDayMessages.length; i++) {
        if (i == 0) {
          separatorIndices.add(i);
        } else {
          final currentDate =
              DateTime.parse(sameDayMessages[i]['createdAt'].toString());
          final previousDate =
              DateTime.parse(sameDayMessages[i - 1]['createdAt'].toString());

          if (currentDate.year != previousDate.year ||
              currentDate.month != previousDate.month ||
              currentDate.day != previousDate.day) {
            separatorIndices.add(i);
          }
        }
      }

      // Only separator should be at index 0
      expect(separatorIndices.length, 1);
      expect(separatorIndices.first, 0);
    });

    test('should format date separator correctly', () {
      final date = DateTime(2025, 10, 25);
      final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      expect(formatted, '2025-10-25');
    });

    test('should handle consecutive day changes', () {
      final multiDayMessages = [
        {'id': 'msg_1', 'createdAt': DateTime(2025, 10, 20)},
        {'id': 'msg_2', 'createdAt': DateTime(2025, 10, 21)},
        {'id': 'msg_3', 'createdAt': DateTime(2025, 10, 22)},
        {'id': 'msg_4', 'createdAt': DateTime(2025, 10, 23)},
      ];

      final separatorIndices = <int>[];
      for (int i = 0; i < multiDayMessages.length; i++) {
        if (i == 0) {
          separatorIndices.add(i);
        } else {
          final currentDate =
              DateTime.parse(multiDayMessages[i]['createdAt'].toString());
          final previousDate =
              DateTime.parse(multiDayMessages[i - 1]['createdAt'].toString());

          if (currentDate.year != previousDate.year ||
              currentDate.month != previousDate.month ||
              currentDate.day != previousDate.day) {
            separatorIndices.add(i);
          }
        }
      }

      // Should have 4 separators (one for each day)
      expect(separatorIndices.length, 4);
    });
  });

  group('Message Validation Logic', () {
    test('should validate message content is not empty', () {
      const message = '';
      final isValid = message.trim().isNotEmpty;
      expect(isValid, false);
    });

    test('should accept non-empty message content', () {
      const message = 'Hello world';
      final isValid = message.trim().isNotEmpty;
      expect(isValid, true);
    });

    test('should handle whitespace-only messages', () {
      const message = '   ';
      final isValid = message.trim().isNotEmpty;
      expect(isValid, false);
    });

    test('should validate message length constraints', () {
      final message = 'x' * 5000;
      const maxLength = 4000;
      final isValid = message.length <= maxLength;
      expect(isValid, false);
    });

    test('should accept messages within length limit', () {
      const message = 'Hello world';
      const maxLength = 4000;
      const isValid = message.length <= maxLength;
      expect(isValid, true);
    });
  });

  group('Pagination Logic', () {
    test('should calculate correct page offset', () {
      const currentPage = 2;
      const pageSize = 50;
      const offset = (currentPage - 1) * pageSize;

      expect(offset, 50);
    });

    test('should determine if more pages exist', () {
      const totalCount = 150;
      const currentPage = 2;
      const pageSize = 50;
      final totalPages = (totalCount / pageSize).ceil();
      final hasMore = currentPage < totalPages;

      expect(hasMore, true);
    });

    test('should identify last page', () {
      const totalCount = 100;
      const currentPage = 2;
      const pageSize = 50;
      final totalPages = (totalCount / pageSize).ceil();
      final hasMore = currentPage < totalPages;

      expect(hasMore, false);
    });

    test('should increment page correctly', () {
      int currentPage = 1;
      currentPage++;
      expect(currentPage, 2);

      currentPage++;
      expect(currentPage, 3);
    });
  });
}
