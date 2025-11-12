import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';
import '../utils/app_logger.dart';

class ReportService {
  final String baseUrl = ApiConfig.baseUrl;
  final _logger = AppLogger();

  Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Report a user
  Future<String> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/report'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('User reported successfully: $userId');
        return data['data']['reportId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to report user');
      }
    } catch (e) {
      _logger.error('Error reporting user: $e');
      rethrow;
    }
  }

  /// Report a post
  Future<String> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/$postId/report'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('Post reported successfully: $postId');
        return data['data']['reportId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to report post');
      }
    } catch (e) {
      _logger.error('Error reporting post: $e');
      rethrow;
    }
  }

  /// Report a video
  Future<String> reportVideo({
    required String videoId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/videos/$videoId/report'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('Video reported successfully: $videoId');
        return data['data']['reportId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to report video');
      }
    } catch (e) {
      _logger.error('Error reporting video: $e');
      rethrow;
    }
  }

  /// Report a club
  Future<String> reportClub({
    required String clubId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/clubs/$clubId/report'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('Club reported successfully: $clubId');
        return data['data']['reportId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to report club');
      }
    } catch (e) {
      _logger.error('Error reporting club: $e');
      rethrow;
    }
  }

  /// Report an event
  Future<String> reportEvent({
    required String eventId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/report'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('Event reported successfully: $eventId');
        return data['data']['reportId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to report event');
      }
    } catch (e) {
      _logger.error('Error reporting event: $e');
      rethrow;
    }
  }

  /// Get available report reasons
  static List<ReportReason> getReportReasons() {
    return [
      ReportReason(
        value: 'spam',
        label: 'Spam',
        description: 'Repetitive or irrelevant content',
      ),
      ReportReason(
        value: 'harassment',
        label: 'Harassment',
        description: 'Bullying or abusive behavior',
      ),
      ReportReason(
        value: 'hate_speech',
        label: 'Hate Speech',
        description: 'Content promoting hatred or discrimination',
      ),
      ReportReason(
        value: 'violence',
        label: 'Violence',
        description: 'Graphic or threatening violent content',
      ),
      ReportReason(
        value: 'misinformation',
        label: 'Misinformation',
        description: 'False or misleading information',
      ),
      ReportReason(
        value: 'inappropriate',
        label: 'Inappropriate Content',
        description: 'Content that violates community guidelines',
      ),
      ReportReason(
        value: 'other',
        label: 'Other',
        description: 'Other reason (please provide details)',
      ),
    ];
  }
}

class ReportReason {
  final String value;
  final String label;
  final String description;

  ReportReason({
    required this.value,
    required this.label,
    required this.description,
  });
}
