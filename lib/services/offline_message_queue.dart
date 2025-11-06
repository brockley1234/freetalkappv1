import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMessage {
  final String id;
  final String conversationId;
  final String? recipient;
  final String? content;
  final String? mediaPath;
  final String? mediaType;
  final String? replyTo;
  final DateTime timestamp;
  int retryCount;
  String? errorMessage;

  PendingMessage({
    required this.id,
    required this.conversationId,
    this.recipient,
    this.content,
    this.mediaPath,
    this.mediaType,
    this.replyTo,
    required this.timestamp,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'recipient': recipient,
      'content': content,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
      'replyTo': replyTo,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
    };
  }

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    return PendingMessage(
      id: json['id'],
      conversationId: json['conversationId'],
      recipient: json['recipient'],
      content: json['content'],
      mediaPath: json['mediaPath'],
      mediaType: json['mediaType'],
      replyTo: json['replyTo'],
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
    );
  }
}

class OfflineMessageQueue {
  static final OfflineMessageQueue _instance = OfflineMessageQueue._internal();
  factory OfflineMessageQueue() => _instance;
  OfflineMessageQueue._internal();

  final List<PendingMessage> _queue = [];
  SharedPreferences? _prefs;

  bool _isProcessing = false;
  Timer? _retryTimer;
  final int maxRetries = 5;
  final Duration initialRetryDelay = const Duration(seconds: 5);

  // Stream controller for queue updates
  final StreamController<List<PendingMessage>> _queueController =
      StreamController<List<PendingMessage>>.broadcast();

  Stream<List<PendingMessage>> get queueStream => _queueController.stream;

  List<PendingMessage> get queue => List.unmodifiable(_queue);
  int get queueLength => _queue.length;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadQueue();

    debugPrint(
        '📥 OfflineMessageQueue initialized with ${_queue.length} pending messages');
  }

  /// Add a message to the queue
  Future<String> addToQueue(PendingMessage message) async {
    _queue.add(message);
    await _saveQueue();
    _queueController.add(_queue);

    debugPrint('📥 Added message to queue: ${message.id}');

    // Try to process immediately if online
    if (await _hasConnectivity()) {
      processQueue();
    }

    return message.id;
  }

  /// Process all pending messages in the queue
  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) {
      return;
    }

    if (!await _hasConnectivity()) {
      debugPrint('📡 No connectivity, deferring queue processing');
      return;
    }

    _isProcessing = true;
    debugPrint('📤 Processing message queue (${_queue.length} messages)...');

    while (_queue.isNotEmpty && await _hasConnectivity()) {
      final message = _queue.first;

      try {
        await _sendMessage(message);

        // Success! Remove from queue
        _queue.removeAt(0);
        await _saveQueue();
        _queueController.add(_queue);

        debugPrint('✅ Message ${message.id} sent successfully');
      } catch (e) {
        debugPrint('❌ Failed to send message ${message.id}: $e');

        message.retryCount++;
        message.errorMessage = e.toString();

        if (_shouldRetry(message, e)) {
          // Move to back of queue for retry
          _queue.removeAt(0);
          _queue.add(message);
          await _saveQueue();
          _queueController.add(_queue);

          debugPrint(
              '🔄 Will retry message ${message.id} (attempt ${message.retryCount}/$maxRetries)');

          // Wait before next retry with exponential backoff
          final delay = _getRetryDelay(message.retryCount);
          await Future.delayed(delay);
        } else {
          // Max retries reached or permanent error
          _queue.removeAt(0);
          await _saveQueue();
          _queueController.add(_queue);

          debugPrint('🚫 Permanently failed to send message ${message.id}');
          _notifyFailure(message);
        }
      }
    }

    _isProcessing = false;
    debugPrint('📤 Queue processing complete. Remaining: ${_queue.length}');
  }

  /// Send a single message
  Future<void> _sendMessage(PendingMessage message) async {
    Map<String, dynamic> result;

    if (message.mediaPath != null) {
      // Send media message
      // Note: This is a simplified version. In production, you'd need to handle
      // loading the file from the path
      throw UnimplementedError(
          'Media message sending from queue not yet implemented');
    } else {
      // Send text message
      result = await MessagingService.sendMessage(
        recipient: message.recipient!,
        content: message.content!,
        replyTo: message.replyTo,
      );
    }

    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to send message');
    }
  }

  /// Check if device has connectivity
  Future<bool> _hasConnectivity() async {
    try {
      // Simple connectivity check using socket connection
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('📡 No connectivity: $e');
      return false;
    }
  }

  /// Determine if a message should be retried
  bool _shouldRetry(PendingMessage message, dynamic error) {
    // Don't retry if max retries reached
    if (message.retryCount >= maxRetries) {
      return false;
    }

    // Check for permanent errors (authentication, validation, etc.)
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('authentication') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('validation') ||
        errorStr.contains('blocked')) {
      return false;
    }

    return true;
  }

  /// Get retry delay with exponential backoff
  Duration _getRetryDelay(int retryCount) {
    final multiplier = (1 << retryCount).clamp(1, 32); // 2^retryCount, max 32
    return initialRetryDelay * multiplier;
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      if (_prefs == null) return;
      final jsonQueue = _queue.map((msg) => msg.toJson()).toList();
      await _prefs!.setString('offline_message_queue', json.encode(jsonQueue));
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
    }
  }

  /// Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      if (_prefs == null) return;
      final queueJson = _prefs!.getString('offline_message_queue');
      if (queueJson != null && queueJson.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(queueJson);
        _queue.clear();
        _queue.addAll(jsonList.map((json) => PendingMessage.fromJson(json)));
        _queueController.add(_queue);
        debugPrint('📥 Loaded ${_queue.length} messages from queue');
      }
    } catch (e) {
      debugPrint('❌ Error loading queue: $e');
    }
  }

  /// Remove a specific message from the queue
  Future<void> removeFromQueue(String messageId) async {
    _queue.removeWhere((msg) => msg.id == messageId);
    await _saveQueue();
    _queueController.add(_queue);
    debugPrint('🗑️ Removed message $messageId from queue');
  }

  /// Clear all messages from the queue
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    _queueController.add(_queue);
    debugPrint('🗑️ Cleared message queue');
  }

  /// Notify user of permanent failure
  void _notifyFailure(PendingMessage message) {
    // In a real app, you'd show a notification or UI alert here
    debugPrint(
        '🚨 PERMANENT FAILURE: Message ${message.id} could not be sent after ${message.retryCount} attempts');
    debugPrint('   Error: ${message.errorMessage}');
    debugPrint('   Content: ${message.content}');
  }

  /// Retry a specific failed message
  Future<void> retryMessage(String messageId) async {
    final message = _queue.firstWhere(
      (msg) => msg.id == messageId,
      orElse: () => throw Exception('Message not found in queue'),
    );

    // Reset retry count for manual retry
    message.retryCount = 0;
    message.errorMessage = null;

    await _saveQueue();
    processQueue();
  }

  void dispose() {
    _retryTimer?.cancel();
    _queueController.close();
  }
}
