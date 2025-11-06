import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';

/// Displays game history and win/loss stats between two users
class GameHistoryWidget extends StatefulWidget {
  final String userId;
  final String otherUserId;
  final Function()? onRefresh;

  const GameHistoryWidget({
    super.key,
    required this.userId,
    required this.otherUserId,
    this.onRefresh,
  });

  @override
  State<GameHistoryWidget> createState() => _GameHistoryWidgetState();
}

class _GameHistoryWidgetState extends State<GameHistoryWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentGames = [];

  @override
  void initState() {
    super.initState();
    _loadGameStats();
  }

  Future<void> _loadGameStats() async {
    try {
      final token = await SecureStorageService().getAccessToken();
      if (token == null) {
        debugPrint('❌ [GameHistory] No access token found');
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication failed';
            _isLoading = false;
          });
        }
        return;
      }

      final url =
          '${AppConfig.baseUrl}/game-challenges/stats/${widget.otherUserId}';
      debugPrint('🎮 [GameHistory] Fetching stats from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );

      debugPrint('🎮 [GameHistory] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          if (mounted) {
            setState(() {
              _stats = jsonData['data']['stats'];
              _recentGames = List<Map<String, dynamic>>.from(
                jsonData['data']['recentGames'] ?? [],
              );
              _isLoading = false;
              _errorMessage = null;
              debugPrint('✅ [GameHistory] Stats loaded successfully');
            });
          }
        } else {
          debugPrint('❌ [GameHistory] Invalid response format');
          if (mounted) {
            setState(() {
              _errorMessage = 'Invalid response from server';
              _isLoading = false;
            });
          }
        }
      } else {
        debugPrint('❌ [GameHistory] HTTP ${response.statusCode}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load stats';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [GameHistory] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stats: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadGameStats();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_stats == null) {
      return const Center(
        child: Text('No game data available'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats summary
            _buildStatsSummary(),
            const SizedBox(height: 24),

            // Game breakdown by type
            if (_stats!['byGameType'] != null)
              _buildGameTypeBreakdown(),
            const SizedBox(height: 24),

            // Recent games
            if (_recentGames.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Recent Games',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildRecentGamesList(),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No games played yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final totalWins = _stats!['totalWins'] ?? 0;
    final totalLosses = _stats!['totalLosses'] ?? 0;
    final totalDraws = _stats!['totalDraws'] ?? 0;
    final totalGames = totalWins + totalLosses + totalDraws;
    final winRate = totalGames > 0 ? (totalWins / totalGames * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Head to Head Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Wins', totalWins, Colors.green),
              _buildStatCard('Draws', totalDraws, Colors.amber),
              _buildStatCard('Losses', totalLosses, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Win Rate: $winRate%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGameTypeBreakdown() {
    final byGameType = _stats!['byGameType'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Games by Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...(byGameType.entries.map((entry) {
          final gameType = entry.key;
          final data = entry.value as Map<String, dynamic>;
          final wins = data['wins'] ?? 0;
          final losses = data['losses'] ?? 0;
          final draws = data['draws'] ?? 0;
          final total = wins + losses + draws;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGameTitle(gameType),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$total games played',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          _buildMiniStat('W: $wins', Colors.green),
                          const SizedBox(width: 8),
                          _buildMiniStat('D: $draws', Colors.amber),
                          const SizedBox(width: 8),
                          _buildMiniStat('L: $losses', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildMiniStat(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRecentGamesList() {
    return Column(
      children: _recentGames.take(5).map((game) {
        final winnerId = game['winner']?['_id'];
        final isDraw = game['isDraw'] ?? false;
        final completedAt = game['completedAt'];

        String resultText = '';
        Color resultColor = Colors.grey;

        if (isDraw) {
          resultText = 'Draw';
          resultColor = Colors.amber;
        } else if (winnerId == widget.userId) {
          resultText = 'Won';
          resultColor = Colors.green;
        } else if (winnerId != null) {
          resultText = 'Lost';
          resultColor = Colors.red;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGameTitle(game['gameType'] ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (completedAt != null)
                        Text(
                          _formatDate(completedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getGameTitle(String gameType) {
    switch (gameType) {
      case 'tic-tac-toe':
        return '🎯 Tic-Tac-Toe';
      case 'connect-4':
        return '🔴 Connect 4';
      case 'quick-fire':
        return '⚡ Quick Fire';
      default:
        return '🎮 Game';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}
