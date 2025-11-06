import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../services/secure_storage_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_logger.dart';

class MultiplayerQuickFireGame extends StatefulWidget {
  final String gameChallengeId;
  final String currentUserId;
  final Map<String, dynamic> gameChallenge;

  const MultiplayerQuickFireGame({
    super.key,
    required this.gameChallengeId,
    required this.currentUserId,
    required this.gameChallenge,
  });

  @override
  State<MultiplayerQuickFireGame> createState() => _MultiplayerQuickFireGameState();
}

class _MultiplayerQuickFireGameState extends State<MultiplayerQuickFireGame> {
  late Map<String, dynamic> _gameChallenge;
  bool _isLoading = false;
  
  int _currentPlayerScore = 0;
  int _opponentScore = 0;
  int _roundsPlayed = 0;
  static const int totalRounds = 5;
  static const int timePerRound = 30;
  int _timeRemaining = timePerRound;
  Timer? _timer;
  
  String _currentWord = '';
  List<String> _scrambledLetters = [];
  bool _isWaitingForOpponent = true;
  String? _selectedAnswer;
  
  final _logger = AppLogger();
  
  // Word list for the game
  final List<String> _words = [
    'FLUTTER', 'CODING', 'PYTHON', 'JAVASCRIPT', 'DESIGN',
    'MOBILE', 'BACKEND', 'FRONTEND', 'DATABASE', 'NETWORK',
    'SOCKET', 'STREAM', 'WIDGET', 'SCAFFOLD', 'BUTTON',
    'ALERT', 'DIALOG', 'SNACKBAR', 'NAVIGATION', 'ANIMATION',
  ];

  @override
  void initState() {
    super.initState();
    _gameChallenge = widget.gameChallenge;
    _setupSocketListeners();
    _initializeRound();
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    
    socketService.on('game:move', (data) {
      if (data['gameChallengeId'] == widget.gameChallengeId && mounted) {
        // Opponent answered
        _processOpponentAnswer(data);
      }
    });

    socketService.on('game:finished', (data) {
      if (data['gameChallengeId'] == widget.gameChallengeId && mounted) {
        _handleGameFinished(data);
      }
    });
  }

  void _initializeRound() {
    _timer?.cancel();
    
    if (_roundsPlayed >= totalRounds) {
      _finishGame();
      return;
    }

    // Pick random word
    _currentWord = _words[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % _words.length];
    _scrambleWord();
    _timeRemaining = timePerRound;
    _selectedAnswer = null;
    _isWaitingForOpponent = false;

    _startTimer();
  }

  void _scrambleWord() {
    final letters = _currentWord.split('');
    letters.shuffle();
    _scrambledLetters = letters;
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;
        });

        if (_timeRemaining <= 0) {
          timer.cancel();
          _timeOut();
        }
      }
    });
  }

  void _timeOut() {
    _timer?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time\'s up!')),
      );
      _nextRound();
    }
  }

  void _submitAnswer(String answer) async {
    _timer?.cancel();
    setState(() => _isLoading = true);

    try {
      final isCorrect = answer.toUpperCase() == _currentWord;
      
      if (isCorrect) {
        setState(() => _currentPlayerScore += (10 + _timeRemaining));
      }

      final token = await SecureStorageService().getAccessToken();

      // Send move to opponent
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/game-challenges/${widget.gameChallengeId}/move'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'moveData': {
            'round': _roundsPlayed + 1,
            'answer': answer,
            'isCorrect': isCorrect,
            'timeUsed': timePerRound - _timeRemaining,
            'score': isCorrect ? (10 + _timeRemaining) : 0,
          },
          'boardState': {
            'rounds': _roundsPlayed + 1,
            'playerScores': {
              widget.currentUserId: _currentPlayerScore,
            }
          }
        }),
      );

      if (mounted) {
        setState(() {
          _selectedAnswer = answer;
          _isWaitingForOpponent = true;
          _isLoading = false;
        });

        // Wait 2 seconds before showing result
        await Future.delayed(const Duration(seconds: 2));
        _nextRound();
      }
    } catch (e) {
      _logger.error('Error submitting answer: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processOpponentAnswer(Map<String, dynamic> data) {
    if (mounted) {
      final opponentScore = ((data['moveData']?['score'] as num?) ?? 0).toInt();
      setState(() {
        _opponentScore += opponentScore;
      });
    }
  }

  void _nextRound() {
    if (mounted) {
      setState(() => _roundsPlayed++);
      _initializeRound();
    }
  }

  void _finishGame() async {
    _timer?.cancel();

    try {
      final token = await SecureStorageService().getAccessToken();
      
      final winnerId = _currentPlayerScore > _opponentScore 
          ? widget.currentUserId 
          : _currentPlayerScore < _opponentScore
              ? _gameChallenge['opponent']['_id']
              : null;

      await http.post(
        Uri.parse('${AppConfig.baseUrl}/game-challenges/${widget.gameChallengeId}/finish'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'winnerId': winnerId,
          'isDraw': _currentPlayerScore == _opponentScore,
        }),
      );

      if (mounted) {
        _showFinalResult();
      }
    } catch (e) {
      _logger.error('Error finishing game: $e');
    }
  }

  void _handleGameFinished(Map<String, dynamic> data) {
    if (mounted) {
      _showFinalResult();
    }
  }

  void _showFinalResult() {
    final isWin = _currentPlayerScore > _opponentScore;
    final isDraw = _currentPlayerScore == _opponentScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isDraw ? '🤝 Draw!' : isWin ? '🎉 You Won!' : '😔 You Lost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Score: $_currentPlayerScore'),
            Text('Opponent Score: $_opponentScore'),
            const SizedBox(height: 8),
            Text(
              isDraw
                  ? 'Great job! It was a close match!'
                  : isWin
                      ? 'Congratulations on your victory!'
                      : 'Better luck next time!',
            ),
          ],
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
        title: const Text('Quick Fire - Word Game'),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Score board
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text('Your Score', style: TextStyle(fontSize: 12)),
                    Text(
                      _currentPlayerScore.toString(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Round $_roundsPlayed/$totalRounds', style: const TextStyle(fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_timeRemaining s',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _timeRemaining <= 5 ? Colors.red : Colors.teal),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Opponent Score', style: TextStyle(fontSize: 12)),
                    Text(
                      _opponentScore.toString(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          
          // Game content
          if (_roundsPlayed < totalRounds)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                    const Text('Unscramble the word:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    // Scrambled letters
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _scrambledLetters.map((letter) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Answer input
                    TextField(
                      enabled: !_isWaitingForOpponent && !_isLoading,
                      onChanged: (value) {
                        setState(() => _selectedAnswer = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Type your answer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 32),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_selectedAnswer?.isEmpty ?? true) || _isWaitingForOpponent || _isLoading
                            ? null
                            : () => _submitAnswer(_selectedAnswer!),
                        icon: const Icon(Icons.check),
                        label: const Text('Submit Answer', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_isWaitingForOpponent)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              'Waiting for opponent...',
                              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Game Over!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Your Final Score: $_currentPlayerScore', style: const TextStyle(fontSize: 18)),
                    Text('Opponent Final Score: $_opponentScore', style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
