import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_logger.dart';

class MultiplayerConnect4Game extends StatefulWidget {
  final String gameChallengeId;
  final String currentUserId;
  final Map<String, dynamic> gameChallenge;

  const MultiplayerConnect4Game({
    super.key,
    required this.gameChallengeId,
    required this.currentUserId,
    required this.gameChallenge,
  });

  @override
  State<MultiplayerConnect4Game> createState() => _MultiplayerConnect4GameState();
}

class _MultiplayerConnect4GameState extends State<MultiplayerConnect4Game> {
  late List<String?> boardState;
  static const int columns = 7;
  static const int rows = 6;
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
      boardState = List<String?>.filled(columns * rows, null);
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

  String _getPlayerColor(String userId) {
    // Get initiator ID - handle both string and object formats
    final initiatorId = _gameChallenge['initiator'] is String
        ? _gameChallenge['initiator']
        : _gameChallenge['initiator']['_id'];
    
    return initiatorId == userId ? 'R' : 'Y';
  }

  int? _getRowForColumn(int col) {
    for (int row = rows - 1; row >= 0; row--) {
      if (boardState[row * columns + col] == null) {
        return row;
      }
    }
    return null;
  }

  void _onColumnTap(int col) {
    if (!_isCurrentPlayerTurn() || _gameOver || _isLoading) {
      return;
    }

    final row = _getRowForColumn(col);
    if (row == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Column is full')),
      );
      return;
    }

    _makeMove(row, col);
  }

  Future<void> _makeMove(int row, int col) async {
    setState(() => _isLoading = true);

    try {
      final color = _getPlayerColor(widget.currentUserId);

      // Create new board state with the move
      final newBoardState = List<String?>.from(boardState);
      newBoardState[row * columns + col] = color;

      // Use ApiService for automatic token refresh on 401
      final result = await ApiService.makeGameMove(
        gameChallengeId: widget.gameChallengeId,
        moveData: {'row': row, 'col': col, 'color': color},
        boardState: newBoardState,
      );

      if (result['success'] == true) {
        // Backend accepted the move - NOW update the local board
        final updatedBoardState = result['data']['boardState'];
        final updatedCurrentTurn = result['data']['currentTurn'];
        
        if (mounted) {
          setState(() {
            boardState = List<String?>.from(updatedBoardState);
            // Update currentTurn regardless of format (handles both String and Map)
            _gameChallenge['currentTurn'] = updatedCurrentTurn;
          });
        }
      } else {
        throw Exception(result['message'] ?? 'Move rejected by server');
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
                  ? 'Congratulations, you won Connect 4!'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect 4'),
        backgroundColor: Colors.indigo,
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
                      Colors.red,
                      _gameChallenge['initiator']['_id'] == widget.currentUserId,
                      _gameChallenge['currentTurn']?['_id'] == _gameChallenge['initiator']['_id'],
                    ),
                    const Text('VS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildPlayerCard(
                      _gameChallenge['opponent'],
                      Colors.yellow,
                      _gameChallenge['opponent']['_id'] == widget.currentUserId,
                      _gameChallenge['currentTurn']?['_id'] == _gameChallenge['opponent']['_id'],
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
          // Column buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(columns, (index) {
                return GestureDetector(
                  onTap: _isCurrentPlayerTurn() && !_gameOver ? () => _onColumnTap(index) : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Game board
          Expanded(
            child: Center(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                itemCount: columns * rows,
                itemBuilder: (context, index) {
                  final piece = boardState[index];
                  
                  Color pieceColor = Colors.grey[300]!;
                  if (piece == 'R') pieceColor = Colors.red;
                  if (piece == 'Y') pieceColor = Colors.yellow;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo[700]!),
                    ),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: pieceColor,
                          shape: BoxShape.circle,
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
    Color color,
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
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isTurn ? Border.all(color: Colors.green, width: 2) : null,
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
