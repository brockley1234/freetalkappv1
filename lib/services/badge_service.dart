import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/badge_model.dart';

class BadgeService {
  final Logger _logger = Logger('BadgeService');
  final String baseUrl;
  final String? token;

  BadgeService({
    required this.baseUrl,
    this.token,
  });

  /// Get all visible badges for a user
  Future<List<Badge>> getUserBadges(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/badges/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];
        return data
            .map((json) => Badge.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch badges: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching user badges: $e');
      rethrow;
    }
  }

  /// Get all badges (including hidden) for current user
  Future<List<Badge>> getPrivateBadges(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/badges/$userId/private'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];
        return data
            .map((json) => Badge.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception(
            'Failed to fetch private badges: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching private badges: $e');
      rethrow;
    }
  }

  /// Get badge statistics for a user
  Future<BadgeStats?> getBadgeStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/badges/stats/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'];
        if (data != null) {
          return BadgeStats.fromJson(data as Map<String, dynamic>);
        }
        return null;
      } else {
        throw Exception('Failed to fetch badge stats: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching badge stats: $e');
      rethrow;
    }
  }

  /// Toggle badge visibility
  Future<void> toggleBadgeVisibility(String userId, String badgeType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/badges/toggle/$userId/$badgeType'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        _logger.info('Badge visibility toggled: $badgeType');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Badge not found');
      } else {
        throw Exception('Failed to toggle badge: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error toggling badge visibility: $e');
      rethrow;
    }
  }

  /// Get badge leaderboard (users with rarest badges)
  Future<List<BadgeLeaderboardEntry>> getBadgeLeaderboard({
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/badges/leaderboard/rarest?limit=$limit&skip=$skip',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];
        return data
            .map((json) =>
                BadgeLeaderboardEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Failed to fetch badge leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching badge leaderboard: $e');
      rethrow;
    }
  }

  /// Cache badges locally
  Future<void> cacheBadges(List<Badge> badges) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final badgesJson = jsonEncode(
        badges.map((b) => b.toJson()).toList(),
      );
      await prefs.setString('cached_badges', badgesJson);
      _logger.info('Cached ${badges.length} badges locally');
    } catch (e) {
      _logger.warning('Error caching badges: $e');
    }
  }

  /// Get cached badges
  Future<List<Badge>?> getCachedBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_badges');
      if (cachedJson != null) {
        final List<dynamic> data = jsonDecode(cachedJson);
        return data
            .map((json) => Badge.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting cached badges: $e');
      return null;
    }
  }

  /// Clear cached badges
  Future<void> clearCachedBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_badges');
      _logger.info('Cleared cached badges');
    } catch (e) {
      _logger.warning('Error clearing cached badges: $e');
    }
  }
}
