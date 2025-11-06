import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../services/secure_storage_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_logger.dart';

class MultiplayerTicTacToeGame extends StatefulWidget {
  final String gameChallengeId;
  final String currentUserId;
  final Map<String, dynamic> gameChallenge;

  const MultiplayerTicTacToeGame({
    super.key,
    required this.gameChallengeId,
    required this.currentUserId,
    required this.gameChallenge,
  });

  @override
  State<MultiplayerTicTacToeGame> createState() => _MultiplayerTicTacToeGameState();
}

class _MultiplayerTicTacToeGameState extends State<MultiplayerTicTacToeGame> {
  late List<String?> boardState;
  bool _isLoading = false;
  bool _gameOver = false;
  String? _winner;
  bool _isDraw = false;
  late Map<String, dynamic> _gameChallenge;
  final _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _gameChallenge = widget.gameChallenge;
    _initializeBoard();
    _setupSocketListeners();
  }

  void _initializeBoard() {
    if (_gameChallenge['boardState'] != null) {
      boardState = List<String?>.from(_gameChallenge['boardState']);
    } else {
      boardState = List<String?>.filled(9, null);
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    
    socketService.on('game:move', (data) {
      if (data['gameChallengeId'] == widget.gameChallengeId && mounted) {
        setState(() {
          boardState = List<String?>.from(data['boardState']);
          _gameChallenge['currentTurn'] = data['currentTurn'];
        });
      }
    });

    socketService.on('game:finished', (data) {
      if (data['gameChallengeId'] == widget.gameChallengeId && mounted) {
        setState(() {
          _gameOver = true;
          _winner = data['winner']?['_id'];
          _isDraw = data['isDraw'] ?? false;
        });
        _showGameResult();
      }
    });
  }

  bool _isCurrentPlayerTurn() {
    // Get current turn ID - handle both string and object formats
    final currentTurnId = _gameChallenge['currentTurn'] is String 
        ? _gameChallenge['currentTurn']
        : _gameChallenge['currentTurn']?['_id'];
    
    return currentTurnId == widget.currentUserId;
  }

  String _getPlayerSymbol(String userId) {
    // Get initiator ID - handle both string and object formats
    final initiatorId = _gameChallenge['initiator'] is String
        ? _gameChallenge['initiator']
        : _gameChallenge['initiator']['_id'];
    
    return initiatorId == userId ? 'X' : 'O';
  }

  void _onTap(int index) {
    if (!_isCurrentPlayerTurn() || _gameOver || boardState[index] != null || _isLoading) {
      return;
    }

    _makeMove(index);
  }

  Future<void> _makeMove(int index) async {
    setState(() => _isLoading = true);

    try {
      final symbol = _getPlayerSymbol(widget.currentUserId);
      final token = await SecureStorageService().getAccessToken();
      
      if (token == null) {
        throw Exception('No authentication token');
      }

      // Send move to backend FIRST - don't update UI until backend confirms
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/game-challenges/${widget.gameChallengeId}/move'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'moveData': {'position': index, 'symbol': symbol},
          'boardState': List<String?>.from(boardState)
            ..replaceRange(index, index + 1, [symbol]),
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          // Backend accepted the move - NOW update the local board
          final updatedBoardState = jsonResponse['data']['boardState'];
          
          if (mounted) {
            setState(() {
              boardState = List<String?>.from(updatedBoardState);
              _gameChallenge['currentTurn'] = jsonResponse['data']['currentTurn'];
            });
          }
        } else {
          throw Exception(jsonResponse['message'] ?? 'Move rejected by server');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _logger.error('Error making move: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Move failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGameResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isDraw ? '🤝 Draw!' : _winner == widget.currentUserId ? '🎉 You Won!' : '😔 You Lost'),
        content: Text(
          _isDraw
              ? "It's a tie! Well played!"
              : _winner == widget.currentUserId
                  ? 'Congratulations, you won the game!'
                  : 'Better luck next time!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Chat'),
          ),
        ],
      ),
    );
  }

  bool _isPlayerTurn(Map<String, dynamic> player) {
    final playerId = player['_id'] is String ? player['_id'] : player['_id'].toString();
    final currentTurnId = _gameChallenge['currentTurn'] is String 
        ? _gameChallenge['currentTurn']
        : _gameChallenge['currentTurn']?['_id'];
    
    return currentTurnId == playerId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic-Tac-Toe'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Player info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPlayerCard(
                      _gameChallenge['initiator'],
                      'X',
                      _gameChallenge['initiator']['_id'] == widget.currentUserId,
                      _isPlayerTurn(_gameChallenge['initiator']),
                    ),
                    const Text('VS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildPlayerCard(
                      _gameChallenge['opponent'],
                      'O',
                      _gameChallenge['opponent']['_id'] == widget.currentUserId,
                      _isPlayerTurn(_gameChallenge['opponent']),
                    ),
                  ],
                ),
                if (!_isCurrentPlayerTurn() && !_gameOver)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Waiting for opponent...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Game board
          Expanded(
            child: Center(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                itemCount: 9,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _onTap(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: Center(
                        child: Text(
                          boardState[index] ?? '',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
    Map<String, dynamic> player,
    String symbol,
    bool isCurrentPlayer,
    bool isTurn,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage: NetworkImage(player['avatar'] ?? ''),
          child: player['avatar'] == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(height: 8),
        Text(
          player['name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Symbol: $symbol',
          style: TextStyle(
            color: isTurn ? Colors.green : Colors.grey,
            fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (isCurrentPlayer)
          const Text(
            '(You)',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
