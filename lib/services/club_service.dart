import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../utils/app_logger.dart';

/// Service for managing club operations
/// Handles all HTTP requests related to clubs
class ClubService {
  static String get _base => ApiService.baseUrl;

  /// List clubs with optional search, category filter, and pagination
  /// 
  /// Parameters:
  /// - [q]: Search query string
  /// - [category]: Category filter
  /// - [page]: Page number (default: 1)
  /// - [limit]: Items per page (default: 20, max: 50)
  /// - [featured]: Filter for featured clubs only
  static Future<Map<String, dynamic>> listClubs({
    String q = '',
    String category = '',
    int page = 1,
    int limit = 20,
    bool featured = false,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final queryParams = <String, String>{};
        
        if (q.isNotEmpty) queryParams['q'] = q;
        if (category.isNotEmpty) queryParams['category'] = category;
        queryParams['page'] = page.toString();
        queryParams['limit'] = limit.toString();
        if (featured) queryParams['featured'] = 'true';
        
        final uri = Uri.parse('$_base/clubs').replace(queryParameters: queryParams);
        final res = await http.get(uri, headers: headers);
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.listClubs error', error: e);
      return {
        'success': false,
        'message': 'Failed to load clubs: ${e.toString()}'
      };
    }
  }

  /// Get clubs the current user is a member of
  static Future<Map<String, dynamic>> myClubs() async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.get(Uri.parse('$_base/clubs/mine'), headers: headers);
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.myClubs error', error: e);
      return {
        'success': false,
        'message': 'Failed to load your clubs: ${e.toString()}'
      };
    }
  }

  /// Get featured clubs
  static Future<Map<String, dynamic>> featuredClubs({int limit = 10}) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final uri = Uri.parse('$_base/clubs/featured').replace(
          queryParameters: {'limit': limit.toString()}
        );
        final res = await http.get(uri, headers: headers);
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.featuredClubs error', error: e);
      return {
        'success': false,
        'message': 'Failed to load featured clubs: ${e.toString()}'
      };
    }
  }

  /// Get club details by ID
  static Future<Map<String, dynamic>> getClub(String clubId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.get(Uri.parse('$_base/clubs/$clubId'), headers: headers);
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.getClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to load club: ${e.toString()}'
      };
    }
  }

  /// Create a new club
  /// 
  /// Parameters:
  /// - [name]: Club name (required, 3-120 characters)
  /// - [description]: Club description (optional, max 1000 characters)
  /// - [category]: Club category (optional, max 50 characters)
  /// - [privacy]: 'public' or 'private' (default: 'public')
  /// - [tags]: List of tags (optional, max 5 tags)
  /// - [rules]: List of club rules (optional, max 10 rules)
  /// - [avatarImage]: Avatar image URL/path (optional)
  /// - [coverImage]: Cover image URL/path (optional)
  static Future<Map<String, dynamic>> createClub({
    required String name,
    String? description,
    String? category,
    String privacy = 'public',
    List<String>? tags,
    List<String>? rules,
    String? avatarImage,
    String? coverImage,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final body = jsonEncode({
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (category != null && category.isNotEmpty) 'category': category,
          'privacy': privacy,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
          if (rules != null && rules.isNotEmpty) 'rules': rules,
          if (avatarImage != null && avatarImage.isNotEmpty) 'avatarImage': avatarImage,
          if (coverImage != null && coverImage.isNotEmpty) 'coverImage': coverImage,
        });
        final res = await http.post(
          Uri.parse('$_base/clubs'),
          headers: headers,
          body: body,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.createClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to create club: ${e.toString()}'
      };
    }
  }

  /// Update club details (admin only)
  static Future<Map<String, dynamic>> updateClub(
    String clubId, {
    String? name,
    String? description,
    String? category,
    String? privacy,
    List<String>? tags,
    List<String>? rules,
    String? avatarImage,
    String? coverImage,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final body = <String, dynamic>{};
        
        if (name != null) body['name'] = name;
        if (description != null) body['description'] = description;
        if (category != null) body['category'] = category;
        if (privacy != null) body['privacy'] = privacy;
        if (tags != null) body['tags'] = tags;
        if (rules != null) body['rules'] = rules;
        if (avatarImage != null) body['avatarImage'] = avatarImage;
        if (coverImage != null) body['coverImage'] = coverImage;
        
        final res = await http.put(
          Uri.parse('$_base/clubs/$clubId'),
          headers: headers,
          body: jsonEncode(body),
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.updateClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to update club: ${e.toString()}'
      };
    }
  }

  /// Join a club (public clubs) or request to join (private clubs)
  static Future<Map<String, dynamic>> joinClub(String clubId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/join'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.joinClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to join club: ${e.toString()}'
      };
    }
  }

  /// Leave a club
  static Future<Map<String, dynamic>> leaveClub(String clubId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/leave'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.leaveClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to leave club: ${e.toString()}'
      };
    }
  }

  /// List club members
  static Future<Map<String, dynamic>> listMembers(String clubId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.get(
          Uri.parse('$_base/clubs/$clubId/members'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.listMembers error', error: e);
      return {
        'success': false,
        'message': 'Failed to load members: ${e.toString()}'
      };
    }
  }

  /// Approve a join request (admin/moderator only)
  static Future<Map<String, dynamic>> approveRequest(String clubId, String userId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/requests/$userId/approve'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.approveRequest error', error: e);
      return {
        'success': false,
        'message': 'Failed to approve request: ${e.toString()}'
      };
    }
  }

  /// Deny a join request (admin/moderator only)
  static Future<Map<String, dynamic>> denyRequest(String clubId, String userId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/requests/$userId/deny'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.denyRequest error', error: e);
      return {
        'success': false,
        'message': 'Failed to deny request: ${e.toString()}'
      };
    }
  }

  /// Delete/archive a club (admin only)
  static Future<Map<String, dynamic>> deleteClub(String clubId) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.delete(
          Uri.parse('$_base/clubs/$clubId'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.deleteClub error', error: e);
      return {
        'success': false,
        'message': 'Failed to delete club: ${e.toString()}'
      };
    }
  }

  // ==================== CLUB POSTS ====================

  /// List posts in a club
  static Future<Map<String, dynamic>> listPosts(
    String clubId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final queryParams = <String, String>{
          'page': page.toString(),
          'limit': limit.toString(),
        };
        
        final uri = Uri.parse('$_base/clubs/$clubId/posts').replace(queryParameters: queryParams);
        final res = await http.get(uri, headers: headers);
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.listPosts error', error: e);
      return {
        'success': false,
        'message': 'Failed to load posts: ${e.toString()}'
      };
    }
  }

  /// Create a post in a club
  static Future<Map<String, dynamic>> createPost(
    String clubId, {
    required String content,
    List<String>? imagePaths,
    List<String>? videoPaths,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      
      // Create multipart request if there are media files
      final uri = Uri.parse('$_base/clubs/$clubId/posts');
      
      if ((imagePaths != null && imagePaths.isNotEmpty) || 
          (videoPaths != null && videoPaths.isNotEmpty)) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);
        request.fields['content'] = content;
        
        // Add image files
        if (imagePaths != null) {
          for (var path in imagePaths) {
            final file = await http.MultipartFile.fromPath('media', path);
            request.files.add(file);
          }
        }
        
        // Add video files
        if (videoPaths != null) {
          for (var path in videoPaths) {
            final file = await http.MultipartFile.fromPath('media', path);
            request.files.add(file);
          }
        }
        
        final streamedRes = await request.send();
        final res = await http.Response.fromStream(streamedRes);
        
        // Process response manually
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            return jsonDecode(res.body) as Map<String, dynamic>;
          } catch (_) {
            return {'success': true, 'data': {}};
          }
        } else {
          try {
            return jsonDecode(res.body) as Map<String, dynamic>;
          } catch (_) {
            return {'success': false, 'message': 'Request failed with status ${res.statusCode}'};
          }
        }
      } else {
        // Text-only post - use normal authenticated request
        return await ApiService.makeAuthenticated(() async {
          final res = await http.post(
            uri,
            headers: headers,
            body: jsonEncode({'content': content}),
          );
          return res;
        });
      }
    } catch (e) {
      AppLogger.e('ClubService.createPost error', error: e);
      return {
        'success': false,
        'message': 'Failed to create post: ${e.toString()}'
      };
    }
  }

  /// Edit a club post
  static Future<Map<String, dynamic>> editPost(
    String clubId,
    String postId, {
    required String content,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.put(
          Uri.parse('$_base/clubs/$clubId/posts/$postId'),
          headers: headers,
          body: jsonEncode({'content': content}),
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.editPost error', error: e);
      return {
        'success': false,
        'message': 'Failed to edit post: ${e.toString()}'
      };
    }
  }

  /// Delete a club post
  static Future<Map<String, dynamic>> deletePost(
    String clubId,
    String postId,
  ) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.delete(
          Uri.parse('$_base/clubs/$clubId/posts/$postId'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.deletePost error', error: e);
      return {
        'success': false,
        'message': 'Failed to delete post: ${e.toString()}'
      };
    }
  }

  /// Add a comment to a club post
  static Future<Map<String, dynamic>> addComment(
    String clubId,
    String postId, {
    required String content,
  }) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/posts/$postId/comments'),
          headers: headers,
          body: jsonEncode({'content': content}),
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.addComment error', error: e);
      return {
        'success': false,
        'message': 'Failed to add comment: ${e.toString()}'
      };
    }
  }

  /// Delete a comment on a club post
  static Future<Map<String, dynamic>> deleteComment(
    String clubId,
    String postId,
    String commentId,
  ) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.delete(
          Uri.parse('$_base/clubs/$clubId/posts/$postId/comments/$commentId'),
          headers: headers,
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.deleteComment error', error: e);
      return {
        'success': false,
        'message': 'Failed to delete comment: ${e.toString()}'
      };
    }
  }

  // ==================== MEMBER INVITATIONS ====================

  /// Invite users to join a club
  static Future<Map<String, dynamic>> inviteUsers(
    String clubId,
    List<String> userIds,
  ) async {
    try {
      return await ApiService.makeAuthenticated(() async {
        final headers = await ApiService.getAuthHeaders();
        final res = await http.post(
          Uri.parse('$_base/clubs/$clubId/invite'),
          headers: headers,
          body: jsonEncode({'userIds': userIds}),
        );
        return res;
      });
    } catch (e) {
      AppLogger.e('ClubService.inviteUsers error', error: e);
      return {
        'success': false,
        'message': 'Failed to invite users: ${e.toString()}'
      };
    }
  }
}
