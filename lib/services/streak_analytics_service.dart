import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

class StreakAnalyticsService {
  final Logger _logger = Logger('StreakAnalyticsService');
  final String baseUrl;
  final String? token;

  StreakAnalyticsService({
    required this.baseUrl,
    this.token,
  });

  /// Get comprehensive streak analytics for current user
  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streak-analytics/$userId'),
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
        return jsonData['data'] ?? {};
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception('Failed to fetch analytics: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching user analytics: $e');
      rethrow;
    }
  }

  /// Get detailed stats with a specific friend
  Future<Map<String, dynamic>?> getFriendStats(String friendId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streak-analytics/friend-stats/$friendId'),
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
        return jsonData['data'];
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception('Failed to fetch friend stats: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching friend stats: $e');
      rethrow;
    }
  }

  /// Calculate streak health percentage (0-100)
  /// Based on active streaks vs total streaks
  int calculateStreakHealth(Map<String, dynamic> analytics) {
    try {
      final totalStreaks = analytics['totalStreaks'] as int? ?? 0;
      final activeStreaks = analytics['activeStreaks'] as int? ?? 0;

      if (totalStreaks == 0) return 0;
      return ((activeStreaks / totalStreaks) * 100).round();
    } catch (e) {
      _logger.warning('Error calculating streak health: $e');
      return 0;
    }
  }

  /// Get rarity distribution (common, rare, epic, legendary)
  Map<String, int> getRarityDistribution(List<Map<String, dynamic>> streaks) {
    int common = 0;
    int rare = 0;
    int epic = 0;
    int legendary = 0;

    for (final streak in streaks) {
      final count = streak['streakCount'] as int? ?? 0;
      if (count >= 365) {
        legendary++;
      } else if (count >= 100) {
        epic++;
      } else if (count >= 30) {
        rare++;
      } else {
        common++;
      }
    }

    return {
      'COMMON': common,
      'RARE': rare,
      'EPIC': epic,
      'LEGENDARY': legendary,
    };
  }

  /// Get trend analysis (improving or declining)
  String getTrendAnalysis(Map<String, dynamic> analytics) {
    try {
      final breakPercentage =
          (analytics['streakBreakPercentage'] as num?)?.toDouble() ?? 0.0;
      final averageLength =
          (analytics['averageStreakLength'] as num?)?.toDouble() ?? 0.0;

      if (breakPercentage > 50) {
        return 'Streaks are breaking frequently. Focus on consistency!';
      } else if (breakPercentage > 25) {
        return 'Some streaks are breaking. Keep pushing!';
      } else if (averageLength > 100) {
        return 'Outstanding! You\'re maintaining very long streaks! 🔥';
      } else if (averageLength > 30) {
        return 'Great work! You\'re building solid streaks! ✨';
      } else {
        return 'Keep building! You\'re on the right track! 💪';
      }
    } catch (e) {
      _logger.warning('Error analyzing trend: $e');
      return 'Keep messaging daily to maintain streaks!';
    }
  }

  /// Cache analytics locally
  Future<void> cacheAnalytics(String userId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyticsJson = jsonEncode(data);
      await prefs.setString('cached_analytics_$userId', analyticsJson);
      _logger.info('Cached analytics for user $userId');
    } catch (e) {
      _logger.warning('Error caching analytics: $e');
    }
  }

  /// Get cached analytics
  Future<Map<String, dynamic>?> getCachedAnalytics(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_analytics_$userId');
      if (cachedJson != null) {
        return jsonDecode(cachedJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting cached analytics: $e');
      return null;
    }
  }

  /// Clear cached analytics
  Future<void> clearCachedAnalytics(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_analytics_$userId');
      _logger.info('Cleared cached analytics for user $userId');
    } catch (e) {
      _logger.warning('Error clearing cached analytics: $e');
    }
  }
}
