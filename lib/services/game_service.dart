import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class GameSettings {
  GameSettings._();
  static bool hapticsEnabled = true;
}

class GameScore {
  final String gameName;
  final int score;
  final String difficulty;
  final Map<String, dynamic>? statistics;

  GameScore({
    required this.gameName,
    required this.score,
    required this.difficulty,
    this.statistics,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameName': gameName,
      'score': score,
      'difficulty': difficulty,
      'statistics': statistics ?? {},
    };
  }
}

class GameLeaderboardEntry {
  final int rank;
  final String name;
  final String? profilePictureUrl;
  final int highScore;
  final String difficulty;
  final DateTime playedAt;

  GameLeaderboardEntry({
    required this.rank,
    required this.name,
    this.profilePictureUrl,
    required this.highScore,
    required this.difficulty,
    required this.playedAt,
  });

  factory GameLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GameLeaderboardEntry(
      rank: json['rank'] as int,
      name: json['name'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      highScore: json['highScore'] as int,
      difficulty: json['difficulty'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }
}

class GameService {
  static final GameService _instance = GameService._internal();

  factory GameService() {
    return _instance;
  }

  GameService._internal();

  /// Submit a game score to the backend
  static Future<bool> submitScore(
    String gameName,
    int score,
    String difficulty, {
    Map<String, dynamic>? statistics,
  }) async {
    try {
      final gameScore = GameScore(
        gameName: gameName,
        score: score,
        difficulty: difficulty,
        statistics: statistics,
      );

      final token = await ApiService.getAccessToken();
      if (token == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/games/scores'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(gameScore.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get leaderboard for a specific game
  static Future<List<GameLeaderboardEntry>> getLeaderboard(
    String gameName, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/games/leaderboard/$gameName?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final leaderboardData = data['data']['leaderboard'] as List;
          return leaderboardData
              .map((entry) =>
                  GameLeaderboardEntry.fromJson(entry as Map<String, dynamic>))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get current user's rank for a game
  static Future<({int? rank, int highScore, bool hasPlayed})> getUserRank(
      String gameName) async {
    try {
      final token = await ApiService.getAccessToken();
      if (token == null) {
        return (rank: null, highScore: 0, hasPlayed: false);
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/games/my-rank/$gameName'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final rankData = data['data'];
          return (
            rank: rankData['rank'] as int?,
            highScore: rankData['highScore'] as int,
            hasPlayed: rankData['hasPlayed'] as bool,
          );
        }
      }

      return (rank: null, highScore: 0, hasPlayed: false);
    } catch (e) {
      return (rank: null, highScore: 0, hasPlayed: false);
    }
  }

  /// Get current user's score history for a game
  static Future<List<int>> getUserScores(
    String gameName, {
    int limit = 10,
  }) async {
    try {
      final token = await ApiService.getAccessToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/games/my-scores/$gameName?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final scoresData = data['data']['scores'] as List;
          return scoresData.map((score) => score['score'] as int).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get game statistics
  static Future<
      ({
        int totalGames,
        double averageScore,
        int highestScore,
        int uniquePlayers
      })> getGameStats(String gameName) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/games/stats/$gameName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final stats = data['data']['stats'];
          return (
            totalGames: stats['totalGames'] as int,
            averageScore: (stats['averageScore'] as num).toDouble(),
            highestScore: stats['highestScore'] as int,
            uniquePlayers: stats['uniquePlayers'] as int,
          );
        }
      }

      return (
        totalGames: 0,
        averageScore: 0.0,
        highestScore: 0,
        uniquePlayers: 0
      );
    } catch (e) {
      return (
        totalGames: 0,
        averageScore: 0.0,
        highestScore: 0,
        uniquePlayers: 0
      );
    }
  }
}
