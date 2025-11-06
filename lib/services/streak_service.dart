import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'streak_model.dart';

class StreakService {
  final Logger _logger = Logger('StreakService');
  final String baseUrl;
  final String? token;

  StreakService({
    required this.baseUrl,
    this.token,
  });

  /// Get all streaks for the current user
  Future<List<Streak>> getUserStreaks(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streaks/$userId'),
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
            .map((json) => Streak.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception('Failed to fetch streaks: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching user streaks: $e');
      rethrow;
    }
  }

  /// Get streak between two specific users
  Future<Streak?> getStreakBetweenUsers(String userId1, String userId2) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streaks/between/$userId1/$userId2'),
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
        final data = jsonData['data'];
        if (data != null) {
          return Streak.fromJson(data as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null; // No streak exists
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception('Failed to fetch streak: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching streak between users: $e');
      rethrow;
    }
  }

  /// Get detailed streak status between two users
  Future<StreakStatus?> getStreakStatus(String userId1, String userId2) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streaks/status/$userId1/$userId2'),
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
        final data = jsonData['data'];
        if (data != null) {
          return StreakStatus.fromJson(data as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception(
            'Failed to fetch streak status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching streak status: $e');
      rethrow;
    }
  }

  /// Get global leaderboard of longest streaks
  Future<List<StreakLeaderboardEntry>> getLeaderboard({
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/streaks/leaderboard/global?limit=$limit&skip=$skip',
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
                StreakLeaderboardEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Get user's rank and stats on the leaderboard
  Future<UserStreakStats?> getUserLeaderboardStats(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = token ?? prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('No auth token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/streaks/leaderboard/user/$userId'),
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
        final data = jsonData['data'];
        if (data != null) {
          return UserStreakStats.fromJson(data as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else {
        throw Exception(
            'Failed to fetch user leaderboard stats: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching user leaderboard stats: $e');
      rethrow;
    }
  }

  /// Cache streaks locally for quick access
  Future<void> cacheStreaks(List<Streak> streaks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streaksJson = jsonEncode(
        streaks.map((s) => s.toJson()).toList(),
      );
      await prefs.setString('cached_streaks', streaksJson);
      _logger.info('Cached ${streaks.length} streaks locally');
    } catch (e) {
      _logger.warning('Error caching streaks: $e');
    }
  }

  /// Get cached streaks
  Future<List<Streak>?> getCachedStreaks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_streaks');
      if (cachedJson != null) {
        final List<dynamic> data = jsonDecode(cachedJson);
        return data
            .map((json) => Streak.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting cached streaks: $e');
      return null;
    }
  }

  /// Clear cached streaks
  Future<void> clearCachedStreaks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_streaks');
      _logger.info('Cleared cached streaks');
    } catch (e) {
      _logger.warning('Error clearing cached streaks: $e');
    }
  }
}
