import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class MessagingService {
  static final String baseUrl = '${ApiService.baseUrl}/messages';
  // Get all conversations
  static Future<Map<String, dynamic>> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/conversations?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get or create conversation with a user
  static Future<Map<String, dynamic>> getOrCreateConversation(
    String userId,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/conversation/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = json.decode(response.body);

      // Handle 401 Unauthorized - token expired
      if (response.statusCode == 401) {
        debugPrint('🔐 Got 401 error in getOrCreateConversation, attempting token refresh...');
        // Try to refresh token
        final refreshed = await ApiService.refreshToken();
        if (refreshed) {
          debugPrint('🔐 Token refreshed, retrying getOrCreateConversation...');
          // Retry the request with fresh token
          final newToken = await ApiService.getAccessToken();
          if (newToken != null) {
            final retryResponse = await http.get(
              Uri.parse('$baseUrl/conversation/$userId'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $newToken',
              },
            );
            return json.decode(retryResponse.body);
          }
        } else {
          debugPrint('🔐 Token refresh failed');
          await ApiService.clearTokens();
          return {'success': false, 'message': 'Token expired', 'expired': true};
        }
      }

      return body;
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get messages in a conversation
  static Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$conversationId?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send a message
  static Future<Map<String, dynamic>> sendMessage({
    required String recipient,
    required String content,
    String? replyTo,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {'recipient': recipient, 'content': content};

      if (replyTo != null) {
        body['replyTo'] = replyTo;
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error sending message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send a media message (image or video)
  static Future<Map<String, dynamic>> sendMediaMessage({
    required String recipient,
    required XFile mediaFile,
    String? content,
    String? replyTo,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add recipient
      request.fields['recipient'] = recipient;

      // Add content if provided
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }

      // Add replyTo if provided
      if (replyTo != null) {
        request.fields['replyTo'] = replyTo;
      }

      // Get filename - use XFile.name for web compatibility
      final filename = mediaFile.name;
      final extension =
          path.extension(filename).toLowerCase().replaceAll('.', '');

      // Determine media type from file extension and XFile mimeType
      MediaType? mediaType;

      // Try to use the XFile's mimeType first (works on all platforms)
      if (mediaFile.mimeType != null) {
        final mimeParts = mediaFile.mimeType!.split('/');
        if (mimeParts.length == 2) {
          mediaType = MediaType(mimeParts[0], mimeParts[1]);
        }
      }

      // Fallback to extension-based detection if mimeType not available
      if (mediaType == null) {
        if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
          mediaType = MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          );
        } else if ([
          'mp4',
          'avi',
          'mov',
          'wmv',
          'flv',
          'mkv',
          'webm',
        ].contains(extension)) {
          mediaType = MediaType('video', extension);
        } else if ([
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
        ].contains(extension)) {
          // Document types
          switch (extension) {
            case 'pdf':
              mediaType = MediaType('application', 'pdf');
              break;
            case 'doc':
              mediaType = MediaType('application', 'msword');
              break;
            case 'docx':
              mediaType = MediaType(
                'application',
                'vnd.openxmlformats-officedocument.wordprocessingml.document',
              );
              break;
            case 'xls':
              mediaType = MediaType('application', 'vnd.ms-excel');
              break;
            case 'xlsx':
              mediaType = MediaType(
                'application',
                'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              );
              break;
            case 'ppt':
              mediaType = MediaType('application', 'vnd.ms-powerpoint');
              break;
            case 'pptx':
              mediaType = MediaType(
                'application',
                'vnd.openxmlformats-officedocument.presentationml.presentation',
              );
              break;
            case 'txt':
              mediaType = MediaType('text', 'plain');
              break;
            case 'rtf':
              mediaType = MediaType('application', 'rtf');
              break;
            case 'csv':
              mediaType = MediaType('text', 'csv');
              break;
            case 'zip':
              mediaType = MediaType('application', 'zip');
              break;
            case 'rar':
              mediaType = MediaType('application', 'x-rar-compressed');
              break;
            case '7z':
              mediaType = MediaType('application', 'x-7z-compressed');
              break;
            default:
              mediaType = MediaType('application', 'octet-stream');
          }
        }
      }

      // Read file bytes and add to request
      final bytes = await mediaFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: filename,
        contentType: mediaType,
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error sending media message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send a voice message
  static Future<Map<String, dynamic>> sendVoiceMessage({
    required String recipient,
    required XFile audioFile,
    required int duration,
    String? replyTo,
    List<double>? waveformData,
  }) async {
    try {
      debugPrint('🎤 === Starting voice message send ===');

      final token = await ApiService.getAccessToken();

      if (token == null) {
        debugPrint('🎤 ❌ Not authenticated');
        return {
          'success': false,
          'message': 'Not authenticated. Please log in again.'
        };
      }

      // Validate duration
      if (duration <= 0) {
        debugPrint('🎤 ❌ Invalid duration: $duration');
        return {'success': false, 'message': 'Invalid recording duration.'};
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add recipient
      request.fields['recipient'] = recipient;

      // Add duration
      request.fields['duration'] = duration.toString();

      // Add waveform data if provided
      if (waveformData != null && waveformData.isNotEmpty) {
        request.fields['waveformData'] = json.encode(waveformData);
      }

      // Add replyTo if provided
      if (replyTo != null) {
        request.fields['replyTo'] = replyTo;
      }

      // Get filename - if empty (web blob), generate one
      String filename = audioFile.name;
      if (filename.isEmpty || !filename.contains('.')) {
        // Generate filename with timestamp and .wav extension (default for web)
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filename = 'voice_message_$timestamp.wav';
      }

      // Determine media type based on file extension
      MediaType mediaType;
      final extension = filename.toLowerCase().split('.').last;

      switch (extension) {
        case 'wav':
          mediaType = MediaType('audio', 'x-wav'); // Correct WAV MIME type
          break;
        case 'm4a':
          mediaType = MediaType('audio', 'mp4');
          break;
        case 'aac':
          mediaType = MediaType('audio', 'aac');
          break;
        case 'mp3':
          mediaType = MediaType('audio', 'mpeg');
          break;
        case 'ogg':
          mediaType = MediaType('audio', 'ogg');
          break;
        case 'webm':
          mediaType = MediaType('audio', 'webm');
          break;
        default:
          mediaType = MediaType('audio', 'mp4'); // fallback
      }

      debugPrint(
          '🎤 Sending audio file: $filename (type: ${mediaType.mimeType})');

      // Read file bytes and add to request
      final bytes = await audioFile.readAsBytes();

      final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      debugPrint('🎤 File bytes length: ${bytes.length} (${fileSizeMB}MB)');
      debugPrint('🎤 Duration: $duration seconds');
      debugPrint('🎤 Recipient: $recipient');

      // Check file size (50MB limit)
      if (bytes.length > 50 * 1024 * 1024) {
        debugPrint('🎤 ❌ File too large: ${fileSizeMB}MB (max 50MB)');
        return {
          'success': false,
          'message':
              'Voice message is too large (${fileSizeMB}MB). Maximum size is 50MB.'
        };
      }

      // Check if file is empty
      if (bytes.isEmpty) {
        debugPrint('🎤 ❌ Empty audio file');
        return {
          'success': false,
          'message': 'Audio recording is empty. Please try again.'
        };
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: filename,
        contentType: mediaType,
      );
      request.files.add(multipartFile);

      debugPrint('🎤 Request fields: ${request.fields}');
      debugPrint('🎤 Request files: ${request.files.length}');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Voice message upload timed out');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('🎤 Voice message response status: ${response.statusCode}');
      debugPrint('🎤 Voice message response: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        debugPrint('🎤 ❌ Server error: ${response.statusCode}');
        try {
          final errorBody = json.decode(response.body);
          return {
            'success': false,
            'message': errorBody['message'] ??
                'Failed to send voice message (${response.statusCode})'
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to send voice message (${response.statusCode})'
          };
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('🎤 ❌ Timeout error: $e');
      return {
        'success': false,
        'message':
            'Upload timed out. Please check your connection and try again.'
      };
    } on FormatException catch (e) {
      debugPrint('🎤 ❌ Invalid response format: $e');
      return {
        'success': false,
        'message': 'Invalid server response. Please try again.'
      };
    } catch (e, stackTrace) {
      debugPrint('🎤 ❌ Error sending voice message: $e');
      debugPrint('🎤 ❌ Stack trace: $stackTrace');

      // Check for network-related errors by message content
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('socket') ||
          errorMsg.contains('network') ||
          errorMsg.contains('connection') ||
          errorMsg.contains('failed host lookup')) {
        return {
          'success': false,
          'message': 'Network error. Please check your internet connection.'
        };
      }

      return {
        'success': false,
        'message': 'Failed to send voice message: ${e.toString()}'
      };
    }
  }

  // Mark messages as read
  static Future<Map<String, dynamic>> markAsRead(String conversationId) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/$conversationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error marking as read: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete a message for current user only
  static Future<Map<String, dynamic>> deleteMessageForMe(
    String messageId,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$messageId/for-me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete a message for everyone (only sender)
  static Future<Map<String, dynamic>> deleteMessageForEveryone(
    String messageId,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$messageId/for-everyone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send typing indicator
  static Future<Map<String, dynamic>> sendTypingIndicator(
    String conversationId,
    bool isTyping,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/typing'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'conversationId': conversationId,
          'isTyping': isTyping,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error sending typing indicator: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete a message (backward compatibility)
  static Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Add reaction to a message
  static Future<Map<String, dynamic>> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/$messageId/react'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'emoji': emoji}),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Remove reaction from a message
  static Future<Map<String, dynamic>> removeReaction({
    required String messageId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$messageId/react'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete a conversation
  static Future<Map<String, dynamic>> deleteConversation({
    required String conversationId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/conversation/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Mark conversation as read
  static Future<Map<String, dynamic>> markConversationAsRead(
    String conversationId,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/conversation/$conversationId/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Clear all messages in a conversation for current user
  static Future<Map<String, dynamic>> clearMessagesInConversation({
    required String conversationId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/conversation/$conversationId/clear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Toggle mute status for a conversation
  static Future<Map<String, dynamic>> toggleMuteConversation(
    String conversationId,
  ) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/conversation/$conversationId/mute'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error toggling mute: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Search messages within a conversation
  static Future<Map<String, dynamic>> searchMessages({
    required String conversationId,
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final uri = Uri.parse('$baseUrl/$conversationId/search').replace(
        queryParameters: {
          'query': query,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Pin/unpin a message
  static Future<Map<String, dynamic>> togglePinMessage({
    required String messageId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/$messageId/pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error toggling pin: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get all pinned messages in a conversation
  static Future<Map<String, dynamic>> getPinnedMessages({
    required String conversationId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/conversation/$conversationId/pinned'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching pinned messages: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Export conversation
  static Future<Map<String, dynamic>> exportConversation({
    required String conversationId,
    String format = 'json', // 'json' or 'txt'
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final uri = Uri.parse('$baseUrl/$conversationId/export').replace(
        queryParameters: {'format': format},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Get filename from Content-Disposition header
        String? fileName;
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          final filenameMatch =
              RegExp(r'filename="(.+)"').firstMatch(contentDisposition);
          if (filenameMatch != null) {
            fileName = filenameMatch.group(1);
          }
        }

        return {
          'success': true,
          'data': response.body,
          'fileName': fileName ?? 'conversation_export.$format',
          'contentType': response.headers['content-type'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to export conversation',
        };
      }
    } catch (e) {
      debugPrint('Error exporting conversation: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send AI chat message
  static Future<Map<String, dynamic>> sendAIChatMessage({
    required String botId,
    required String message,
    String? conversationId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {
        'botId': botId,
        'message': message,
      };

      if (conversationId != null && conversationId.isNotEmpty) {
        body['conversationId'] = conversationId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/ai-chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error sending AI chat message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== NEW ENHANCED FEATURES ====================

  // Edit a message
  static Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/$messageId/edit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'content': content}),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error editing message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Forward a message to multiple conversations
  static Future<Map<String, dynamic>> forwardMessage({
    required String messageId,
    required List<String> conversationIds,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/$messageId/forward'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'conversationIds': conversationIds}),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Mark message as delivered
  static Future<Map<String, dynamic>> markAsDelivered({
    required String messageId,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/$messageId/delivered'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error marking message as delivered: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Global search across all conversations
  static Future<Map<String, dynamic>> searchGlobal({
    required String query,
    String? type, // 'text', 'image', 'video', 'document', 'all'
    String? conversationId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final queryParams = {
        'query': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (type != null) {
        queryParams['type'] = type;
      }
      if (conversationId != null) {
        queryParams['conversationId'] = conversationId;
      }
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom;
      }
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo;
      }

      final uri = Uri.parse('$baseUrl/search/global').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error searching globally: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send a text comment to a club discussion
  static Future<Map<String, dynamic>> sendClubComment({
    required String clubId,
    required String discussionId,
    required String content,
  }) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {
        'content': content,
      };

      final response = await http
          .post(
            Uri.parse(
                '${ApiService.baseUrl}/clubs/$clubId/discussions/$discussionId/comments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Comment send timed out'),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        try {
          final errorBody = json.decode(response.body);
          return {
            'success': false,
            'message': errorBody['message'] ?? 'Failed to send comment'
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to send comment (${response.statusCode})'
          };
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Comment send timeout: $e');
      return {
        'success': false,
        'message': 'Upload timed out. Please check your connection.'
      };
    } catch (e) {
      debugPrint('Error sending comment: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
