import 'dart:convert';
import 'dart:io';
import 'api_service.dart';
import 'secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class VideoService {
  // Helper method for conditional logging (only in debug mode)
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // Get stored access token from secure storage
  static Future<String?> _getAccessToken() async {
    return await SecureStorageService().getAccessToken();
  }

  // Get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all videos (feed)
  static Future<Map<String, dynamic>> getVideos({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri =
          Uri.parse('${ApiService.videosbaseUrl}?page=$page&limit=$limit');

      _log('📹 Fetching videos: page=$page, limit=$limit');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log(
            '✅ Videos fetched successfully: ${data['data']['videos'].length} videos');
        return {
          'success': true,
          'videos': data['data']['videos'],
          'pagination': data['data']['pagination'],
        };
      } else {
        _log('❌ Failed to fetch videos: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch videos',
        };
      }
    } catch (e) {
      _log('❌ Error fetching videos: $e');
      return {
        'success': false,
        'message': 'Error fetching videos: $e',
      };
    }
  }

  // Get videos by specific user
  static Future<Map<String, dynamic>> getUserVideos(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
          '${ApiService.videosbaseUrl}/user/$userId?page=$page&limit=$limit');

      _log('📹 Fetching user videos: userId=$userId, page=$page');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log(
            '✅ User videos fetched successfully: ${data['data']['videos'].length} videos');
        return {
          'success': true,
          'videos': data['data']['videos'],
          'pagination': data['data']['pagination'],
        };
      } else {
        _log('❌ Failed to fetch user videos: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch user videos',
        };
      }
    } catch (e) {
      _log('❌ Error fetching user videos: $e');
      return {
        'success': false,
        'message': 'Error fetching user videos: $e',
      };
    }
  }

  // Get single video by ID
  static Future<Map<String, dynamic>> getVideo(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId');

      _log('📹 Fetching video: videoId=$videoId');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log('✅ Video fetched successfully');
        return {
          'success': true,
          'video': data['data']['video'],
        };
      } else {
        _log('❌ Failed to fetch video: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch video',
        };
      }
    } catch (e) {
      _log('❌ Error fetching video: $e');
      return {
        'success': false,
        'message': 'Error fetching video: $e',
      };
    }
  }

  // Upload a new video
  static Future<Map<String, dynamic>> uploadVideo({
    File? videoFile,
    XFile? videoXFile,
    required String title,
    String? description,
    List<String>? taggedUsers,
    String visibility = 'public',
    // Audio track parameters
    String? musicTrackId,
    String? audioTitle,
    String? audioArtist,
    String? audioUrl,
    String? audioSource,
    String? audioLicense,
    String? audioExternalId,
    bool originalAudio = true,
    double audioStartTime = 0,
    double? audioDuration,
    int audioVolume = 100,
  }) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      if (videoFile == null && videoXFile == null) {
        return {
          'success': false,
          'message': 'No video file provided',
        };
      }

      final uri = Uri.parse(ApiService.videosbaseUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add video file
      http.MultipartFile multipartFile;

      if (kIsWeb && videoXFile != null) {
        // For web, use XFile
        final bytes = await videoXFile.readAsBytes();
        multipartFile = http.MultipartFile.fromBytes(
          'video',
          bytes,
          filename: videoXFile.name,
          contentType: MediaType('video', 'mp4'),
        );
      } else if (videoFile != null) {
        // For mobile/desktop, use File
        final videoStream = http.ByteStream(videoFile.openRead());
        final videoLength = await videoFile.length();
        multipartFile = http.MultipartFile(
          'video',
          videoStream,
          videoLength,
          filename: videoFile.path.split('/').last,
          contentType: MediaType('video', 'mp4'),
        );
      } else {
        return {
          'success': false,
          'message': 'Invalid video file',
        };
      }

      request.files.add(multipartFile);

      // Add fields
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (taggedUsers != null && taggedUsers.isNotEmpty) {
        request.fields['taggedUsers'] = json.encode(taggedUsers);
      }
      request.fields['visibility'] = visibility;

      // Add audio track fields
      if (musicTrackId != null && musicTrackId.isNotEmpty) {
        request.fields['musicTrackId'] = musicTrackId;
      }
      if (audioTitle != null && audioTitle.isNotEmpty) {
        request.fields['audioTitle'] = audioTitle;
      }
      if (audioArtist != null && audioArtist.isNotEmpty) {
        request.fields['audioArtist'] = audioArtist;
      }
      if (audioUrl != null && audioUrl.isNotEmpty) {
        request.fields['audioUrl'] = audioUrl;
      }
      if (audioSource != null && audioSource.isNotEmpty) {
        request.fields['audioSource'] = audioSource;
      }
      if (audioLicense != null && audioLicense.isNotEmpty) {
        request.fields['audioLicense'] = audioLicense;
      }
      if (audioExternalId != null && audioExternalId.isNotEmpty) {
        request.fields['audioExternalId'] = audioExternalId;
      }
      request.fields['originalAudio'] = originalAudio.toString();
      request.fields['audioStartTime'] = audioStartTime.toString();
      if (audioDuration != null) {
        request.fields['audioDuration'] = audioDuration.toString();
      }
      request.fields['audioVolume'] = audioVolume.toString();

      _log('📹 Uploading video: $title');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _log('✅ Video uploaded successfully');
        return {
          'success': true,
          'video': data['data']['video'],
          'message': 'Video uploaded successfully',
        };
      } else {
        _log('❌ Failed to upload video: ${response.statusCode}');
        _log('❌ Response body: ${response.body}');
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to upload video',
            'error': data['error'],
          };
        } catch (parseError) {
          return {
            'success': false,
            'message': 'Failed to upload video (${response.statusCode})',
            'error': response.body,
          };
        }
      }
    } catch (e) {
      _log('❌ Error uploading video: $e');
      return {
        'success': false,
        'message': 'Error uploading video: $e',
      };
    }
  }

  // Record a video view
  static Future<Map<String, dynamic>> recordView(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId/view');

      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'viewCount': data['data']['viewCount'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to record view',
        };
      }
    } catch (e) {
      _log('❌ Error recording view: $e');
      return {
        'success': false,
        'message': 'Error recording view: $e',
      };
    }
  }

  // Like or unlike a video
  static Future<Map<String, dynamic>> toggleLike(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId/like');

      _log('❤️ Toggling like for video: $videoId');

      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log('✅ Video like toggled: ${data['data']['action']}');
        return {
          'success': true,
          'action': data['data']['action'],
          'likeCount': data['data']['likeCount'],
          'isLiked': data['data']['isLiked'],
        };
      } else {
        _log('❌ Failed to toggle like: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to like video',
        };
      }
    } catch (e) {
      _log('❌ Error toggling like: $e');
      return {
        'success': false,
        'message': 'Error toggling like: $e',
      };
    }
  }

  // Add a comment to a video
  static Future<Map<String, dynamic>> addComment(
    String videoId,
    String text, {
    List<String>? taggedUserIds,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId/comment');

      _log('💬 Adding comment to video: $videoId');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'text': text,
          if (taggedUserIds != null && taggedUserIds.isNotEmpty)
            'taggedUserIds': taggedUserIds,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _log('✅ Comment added successfully');
        return {
          'success': true,
          'comment': data['data']['comment'],
          'commentCount': data['data']['commentCount'],
        };
      } else {
        _log('❌ Failed to add comment: ${response.statusCode}');
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add comment',
        };
      }
    } catch (e) {
      _log('❌ Error adding comment: $e');
      return {
        'success': false,
        'message': 'Error adding comment: $e',
      };
    }
  }

  // Get comments for a video
  static Future<Map<String, dynamic>> getComments(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId/comments');

      _log('💬 Fetching comments for video: $videoId');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log(
            '✅ Comments fetched successfully: ${data['data']['commentCount']} comments');
        return {
          'success': true,
          'comments': data['data']['comments'],
          'commentCount': data['data']['commentCount'],
        };
      } else {
        _log('❌ Failed to fetch comments: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch comments',
        };
      }
    } catch (e) {
      _log('❌ Error fetching comments: $e');
      return {
        'success': false,
        'message': 'Error fetching comments: $e',
      };
    }
  }

  // Delete a comment from a video
  static Future<Map<String, dynamic>> deleteComment(
    String videoId,
    String commentId,
  ) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
          '${ApiService.videosbaseUrl}/$videoId/comments/$commentId');

      _log('🗑️ Deleting comment: $commentId from video: $videoId');

      final response = await http.delete(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log('✅ Comment deleted successfully');
        return {
          'success': true,
          'message': 'Comment deleted successfully',
          'commentCount': data['data']['commentCount'],
        };
      } else {
        _log('❌ Failed to delete comment: ${response.statusCode}');
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete comment',
        };
      }
    } catch (e) {
      _log('❌ Error deleting comment: $e');
      return {
        'success': false,
        'message': 'Error deleting comment: $e',
      };
    }
  }

  // Update a video (title, description)
  static Future<Map<String, dynamic>> updateVideo({
    required String videoId,
    required String title,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId');

      _log('✏️ Updating video: $videoId');

      final response = await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log('✅ Video updated successfully');
        return {
          'success': true,
          'message': 'Video updated successfully',
          'video': data['data']['video'],
        };
      } else {
        _log('❌ Failed to update video: ${response.statusCode}');
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update video',
        };
      }
    } catch (e) {
      _log('❌ Error updating video: $e');
      return {
        'success': false,
        'message': 'Error updating video: $e',
      };
    }
  }

  // Delete a video
  static Future<Map<String, dynamic>> deleteVideo(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId');

      _log('🗑️ Deleting video: $videoId');

      final response = await http.delete(uri, headers: headers);

      if (response.statusCode == 200) {
        _log('✅ Video deleted successfully');
        return {
          'success': true,
          'message': 'Video deleted successfully',
        };
      } else {
        _log('❌ Failed to delete video: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to delete video',
        };
      }
    } catch (e) {
      _log('❌ Error deleting video: $e');
      return {
        'success': false,
        'message': 'Error deleting video: $e',
      };
    }
  }

  // Search users for video search
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
          '${ApiService.baseUrl}/users/search?query=${Uri.encodeComponent(query)}');

      _log('🔍 Searching users: query=$query');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log(
            '✅ User search successful: ${data['data']['users']?.length ?? 0} users found');
        return {
          'success': true,
          'users': data['data']['users'] ?? [],
        };
      } else {
        _log('❌ Failed to search users: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to search users',
          'users': [],
        };
      }
    } catch (e) {
      _log('❌ Error searching users: $e');
      return {
        'success': false,
        'message': 'Error searching users: $e',
        'users': [],
      };
    }
  }

  // Report a video
  static Future<Map<String, dynamic>> reportVideo({
    required String videoId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiService.videosbaseUrl}/$videoId/report');

      _log('🚨 Reporting video: $videoId, reason: $reason');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _log('✅ Video reported successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'Video reported successfully',
        };
      } else {
        _log('❌ Failed to report video: ${response.statusCode}');
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to report video',
        };
      }
    } catch (e) {
      _log('❌ Error reporting video: $e');
      return {
        'success': false,
        'message': 'Error reporting video: $e',
      };
    }
  }
}
