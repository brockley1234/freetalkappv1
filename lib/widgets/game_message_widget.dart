import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';
import '../services/socket_service.dart';
import 'package:intl/intl.dart';
import '../pages/games/multiplayer_tictactoe_game.dart';
import '../pages/games/multiplayer_connect4_game.dart';
import '../pages/games/multiplayer_quickfire_game.dart';

/// Widget to display and interact with game messages in chat
/// Features:
/// - Real-time game status updates via Socket.IO
/// - Smooth animations and transitions
/// - Comprehensive error handling with retry logic
/// - Responsive design for all screen sizes
/// - Haptic feedback on user interactions
/// - Game acceptance/decline/play functionality
/// - Winner announcement and game results display
class GameMessageWidget extends StatefulWidget {
  final Map<String, dynamic> message;
  final Map<String, dynamic>? otherUser;
  final String? currentUserId;
  final Function(String)? onGameComplete;
  final Function()? onRefreshChat;

  const GameMessageWidget({
    super.key,
    required this.message,
    this.otherUser,
    this.currentUserId,
    this.onGameComplete,
    this.onRefreshChat,
  });

  @override
  State<GameMessageWidget> createState() => _GameMessageWidgetState();
}

class _GameMessageWidgetState extends State<GameMessageWidget>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _gameData;
  Map<String, dynamic>? _gameChallenge;
  bool _isLoading = true;
  bool _isResponding = false;
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _scaleAnimController;
  late AnimationController _slideAnimController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _gameData = widget.message['gameData'] ?? {};
    
    // Initialize animation controllers
    _scaleAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleAnimController, curve: Curves.elasticOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnimController, curve: Curves.easeOutCubic));
    
    _loadGameChallenge();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _scaleAnimController.dispose();
    _slideAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadGameChallenge() async {
    if (widget.message['gameChallenge'] == null) {
      debugPrint('❌ [GameMessage] No gameChallenge ID in message: ${widget.message['_id']}');
      debugPrint('🎮 [GameMessage] Attempting fallback: fetching game challenge by messageId...');
      
      // Fallback: Try to fetch by messageId for old messages
      await _loadGameChallengeByMessageId();
      return;
    }

    try {
      final gameChallengeId = widget.message['gameChallenge'];
      debugPrint('🎮 [GameMessage] Loading game challenge: $gameChallengeId');
      
      final token = await SecureStorageService().getAccessToken();
      if (token == null) {
        debugPrint('❌ [GameMessage] No access token found');
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication failed';
            _isLoading = false;
          });
        }
        return;
      }

      final url = '${AppConfig.baseUrl}/game-challenges/$gameChallengeId';
      debugPrint('🎮 [GameMessage] Fetching from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      debugPrint('🎮 [GameMessage] Response status: ${response.statusCode}');
      final bodyPreview = response.body.length > 500 ? response.body.substring(0, 500) : response.body;
      debugPrint('🎮 [GameMessage] Response body: $bodyPreview');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        debugPrint('🎮 [GameMessage] Parsed JSON successfully');
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          if (mounted) {
            setState(() {
              _gameChallenge = jsonData['data'];
              _gameData = widget.message['gameData'] ?? {};
              _isLoading = false;
              _errorMessage = null;
              debugPrint('✅ [GameMessage] Game challenge loaded: ${_gameChallenge!['_id']}');
            });
            // Trigger entry animation
            _scaleAnimController.forward();
            _slideAnimController.forward();
          }
        } else {
          debugPrint('❌ [GameMessage] Invalid response format: success=${jsonData['success']}');
          if (mounted) {
            setState(() {
              _errorMessage = 'Invalid response from server';
              _isLoading = false;
            });
          }
        }
      } else if (response.statusCode == 404) {
        debugPrint('❌ [GameMessage] Game not found (404)');
        if (mounted) {
          setState(() {
            _errorMessage = 'Game not found';
            _isLoading = false;
          });
        }
      } else if (response.statusCode >= 500) {
        debugPrint('❌ [GameMessage] Server error ${response.statusCode}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Server error (${response.statusCode})';
            _isLoading = false;
          });
        }
      } else {
        debugPrint('❌ [GameMessage] HTTP ${response.statusCode}: ${response.body}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load game';
            _isLoading = false;
          });
        }
      }
    } on TimeoutException {
      debugPrint('❌ [GameMessage] Request timeout');
      if (mounted) {
        setState(() {
          _errorMessage = 'Request timed out';
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ [GameMessage] Exception: $e');
      debugPrint('❌ [GameMessage] StackTrace: $st');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load game: ${e.toString().split('\n').first}';
          _isLoading = false;
        });
      }
    }
  }

  /// Fallback method to load game challenge by messageId (for old messages)
  Future<void> _loadGameChallengeByMessageId() async {
    try {
      final messageId = widget.message['_id'];
      if (messageId == null) {
        debugPrint('❌ [GameMessage] Cannot load by messageId: messageId is null');
        if (mounted) {
          setState(() {
            _errorMessage = 'Message ID not found';
            _isLoading = false;
          });
        }
        return;
      }

      final token = await SecureStorageService().getAccessToken();
      if (token == null) {
        debugPrint('❌ [GameMessage] No access token found');
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication failed';
            _isLoading = false;
          });
        }
        return;
      }

      // Query endpoint to find game challenge by messageId
      final url = '${AppConfig.baseUrl}/game-challenges?messageId=$messageId';
      debugPrint('🎮 [GameMessage] Fetching game challenge by messageId from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('🎮 [GameMessage] Fallback response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          // If data is a list, get the first item
          final gameChallenge = jsonData['data'] is List 
            ? (jsonData['data'] as List).isNotEmpty ? jsonData['data'][0] : null
            : jsonData['data'];
          
          if (gameChallenge != null) {
            if (mounted) {
              setState(() {
                _gameChallenge = gameChallenge;
                _gameData = widget.message['gameData'] ?? {};
                _isLoading = false;
                debugPrint('✅ [GameMessage] Game challenge loaded via fallback: ${gameChallenge['_id']}');
              });
            }
            return;
          }
        }
      }

      // Fallback failed
      debugPrint('❌ [GameMessage] Fallback load failed. Status: ${response.statusCode}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load game';
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ [GameMessage] Fallback Exception: $e');
      debugPrint('❌ [GameMessage] Fallback StackTrace: $st');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load game: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    
    // Listen for game updates
    socketService.on('game:accepted', (data) {
      if (data['gameChallenge']['_id'] == widget.message['gameChallenge']) {
        if (mounted) {
          setState(() {
            _gameChallenge = data['gameChallenge'];
            _gameData['status'] = 'accepted';
          });
        }
      }
    });

    socketService.on('game:declined', (data) {
      if (data['gameChallengeId'] == widget.message['gameChallenge']) {
        if (mounted) {
          setState(() {
            _gameData['status'] = 'declined';
          });
        }
      }
    });

    socketService.on('game:finished', (data) {
      if (data['gameChallengeId'] == widget.message['gameChallenge']) {
        if (mounted) {
          setState(() {
            _gameData['status'] = 'completed';
            _gameChallenge = data;
          });
          widget.onGameComplete?.call(data['winner']['_id'] ?? '');
        }
      }
    });

    socketService.on('game:move', (data) {
      if (data['gameChallengeId'] == widget.message['gameChallenge']) {
        if (mounted) {
          setState(() {
            _gameChallenge?['boardState'] = data['boardState'];
            _gameChallenge?['currentTurn'] = data['currentTurn'];
          });
        }
      }
    });
  }

  Future<void> _respondToInvite(bool accept) async {
    if (_gameChallenge == null || _isResponding) {
      debugPrint('❌ [GameMessage] Cannot respond: gameChallenge=${_gameChallenge == null}, responding=$_isResponding');
      return;
    }

    setState(() => _isResponding = true);

    try {
      final token = await SecureStorageService().getAccessToken();
      final endpoint = accept ? 'accept' : 'decline';
      
      if (token == null) {
        debugPrint('❌ [GameMessage] No token for respond request');
        _showError('Authentication failed');
        setState(() => _isResponding = false);
        return;
      }

      final gameChallengeId = _gameChallenge!['_id'];
      debugPrint('🎮 [GameMessage] Responding to game: $gameChallengeId with action: $endpoint');

      final url = '${AppConfig.baseUrl}/game-challenges/$gameChallengeId/$endpoint';
      debugPrint('🎮 [GameMessage] POST to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('🎮 [GameMessage] Response status: ${response.statusCode}');
      debugPrint('🎮 [GameMessage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          if (mounted) {
            setState(() {
              _gameData['status'] = accept ? 'accepted' : 'declined';
              debugPrint('✅ [GameMessage] Successfully $endpoint game');
            });
            widget.onRefreshChat?.call();
          }
        } else {
          debugPrint('❌ [GameMessage] Server error: ${jsonData['message']}');
          _showError('${jsonData['message'] ?? 'Failed to $endpoint game'}');
        }
      } else {
        debugPrint('❌ [GameMessage] HTTP error ${response.statusCode}: ${response.body}');
        _showError('Failed to ${accept ? 'accept' : 'decline'} game (${response.statusCode})');
      }
    } catch (e, st) {
      debugPrint('❌ [GameMessage] Exception: $e');
      debugPrint('❌ [GameMessage] StackTrace: $st');
      _showError('Failed to ${accept ? 'accept' : 'decline'} game');
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isCurrentPlayerInGame() {
    if (_gameChallenge == null) return false;
    return _gameChallenge!['initiator']['_id'] == widget.currentUserId ||
        _gameChallenge!['opponent']['_id'] == widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600;
    
    // Responsive sizing values
    final containerPadding = isSmallScreen ? 10.0 : (isTablet ? 16.0 : 12.0);
    final spacing = isSmallScreen ? 8.0 : 12.0;
    final headerFontSize = isSmallScreen ? 13.0 : 14.0;
    final statusFontSize = isSmallScreen ? 11.0 : 12.0;
    final playerRadius = isSmallScreen ? 18.0 : 20.0;
    final playerNameWidth = isSmallScreen ? 50.0 : 60.0;
    final playerNameFontSize = isSmallScreen ? 10.0 : 12.0;
    final buttonHeight = isSmallScreen ? 36.0 : 40.0;
    final buttonFontSize = isSmallScreen ? 12.0 : 14.0;
    final timestampFontSize = isSmallScreen ? 9.0 : 11.0;
    final playerSpacing = isSmallScreen ? 8.0 : 16.0;
    
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(containerPadding),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          height: isSmallScreen ? 60.0 : 80.0,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: EdgeInsets.all(containerPadding),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[900], fontSize: statusFontSize),
            ),
          ],
        ),
      );
    }

    if (_gameChallenge == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game header
                Row(
                  children: [
                    _getGameIcon(_gameChallenge!['gameType']),
                    SizedBox(width: spacing * 0.75),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGameTitle(_gameChallenge!['gameType']),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: headerFontSize,
                            ),
                          ),
                          Text(
                            _getGameStatus(_gameChallenge!['status']),
                            style: TextStyle(
                              fontSize: statusFontSize,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),

                // Players info - responsive layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPlayerInfo(_gameChallenge!['initiator'], playerRadius, playerNameWidth, playerNameFontSize),
                          SizedBox(width: playerSpacing),
                          Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: playerNameFontSize,
                            ),
                          ),
                          SizedBox(width: playerSpacing),
                          _buildPlayerInfo(_gameChallenge!['opponent'], playerRadius, playerNameWidth, playerNameFontSize),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: spacing),

                // Action buttons or game status
                if (_gameChallenge!['status'] == 'pending' &&
                    _gameChallenge!['opponent']['_id'] == widget.currentUserId)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isResponding ? null : () => _respondToInvite(false),
                          icon: const Icon(Icons.close),
                          label: Text('Decline', style: TextStyle(fontSize: buttonFontSize)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: Size.fromHeight(buttonHeight),
                          ),
                        ),
                      ),
                      SizedBox(width: spacing * 0.75),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isResponding ? null : () => _respondToInvite(true),
                          icon: const Icon(Icons.check),
                          label: Text('Accept', style: TextStyle(fontSize: buttonFontSize)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: Size.fromHeight(buttonHeight),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_gameChallenge!['status'] == 'accepted' ||
                    _gameChallenge!['status'] == 'in-progress')
                  ElevatedButton.icon(
                    onPressed: _isCurrentPlayerInGame() ? () => _openGameScreen() : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Play Game', style: TextStyle(fontSize: buttonFontSize)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      minimumSize: Size.fromHeight(buttonHeight),
                    ),
                  )
                else if (_gameChallenge!['status'] == 'completed')
                  _buildGameResult()
                else if (_gameChallenge!['status'] == 'declined')
                  Center(
                    child: Text(
                      'Game declined',
                      style: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: statusFontSize,
                      ),
                    ),
                  ),

                // Game timestamp
                Padding(
                  padding: EdgeInsets.only(top: spacing * 0.75),
                  child: Text(
                    DateFormat('MMM d, HH:mm').format(
                      DateTime.parse(widget.message['createdAt'].toString()),
                    ),
                    style: TextStyle(fontSize: timestampFontSize, color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(Map<String, dynamic> player, double radius, double width, double fontSize) {
    return Column(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          backgroundImage: player['avatar'] != null && player['avatar']!.isNotEmpty
              ? NetworkImage(player['avatar']!)
              : null,
          child: player['avatar'] == null || player['avatar']!.isEmpty
              ? const Icon(Icons.person)
              : null,
        ),
        SizedBox(height: radius * 0.2),
        SizedBox(
          width: width,
          child: Text(
            player['name'] ?? 'Unknown',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameResult() {
    final isWinner = _gameChallenge!['winner']?['_id'] == widget.currentUserId;
    final isDraw = _gameChallenge!['isDraw'] ?? false;

    String resultText;
    Color resultColor;

    if (isDraw) {
      resultText = "It's a Draw! 🤝";
      resultColor = Colors.amber[600]!;
    } else if (isWinner) {
      resultText = "You Won! 🎉";
      resultColor = Colors.green;
    } else {
      resultText = "You Lost 😞";
      resultColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          resultText,
          style: TextStyle(
            color: resultColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _openGameScreen() async {
    if (_gameChallenge == null) return;

    final gameType = _gameChallenge!['gameType'] ?? 'tic-tac-toe';
    final currentUserId = widget.currentUserId;

    if (currentUserId == null) return;

    // Navigate to the appropriate game screen based on game type
    if (gameType == 'tic-tac-toe') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiplayerTicTacToeGame(
            gameChallengeId: _gameChallenge!['_id'],
            currentUserId: currentUserId,
            gameChallenge: _gameChallenge!,
          ),
        ),
      );
    } else if (gameType == 'connect-4') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiplayerConnect4Game(
            gameChallengeId: _gameChallenge!['_id'],
            currentUserId: currentUserId,
            gameChallenge: _gameChallenge!,
          ),
        ),
      );
    } else if (gameType == 'quick-fire') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiplayerQuickFireGame(
            gameChallengeId: _gameChallenge!['_id'],
            currentUserId: currentUserId,
            gameChallenge: _gameChallenge!,
          ),
        ),
      );
    }
  }

  Icon _getGameIcon(String gameType) {
    switch (gameType) {
      case 'tic-tac-toe':
        return const Icon(Icons.grid_3x3, color: Colors.white, size: 20);
      case 'connect-4':
        return const Icon(Icons.circle, color: Colors.white, size: 20);
      case 'quick-fire':
        return const Icon(Icons.flash_on, color: Colors.white, size: 20);
      default:
        return const Icon(Icons.sports_esports, color: Colors.white, size: 20);
    }
  }

  String _getGameTitle(String gameType) {
    switch (gameType) {
      case 'tic-tac-toe':
        return 'Tic-Tac-Toe';
      case 'connect-4':
        return 'Connect 4';
      case 'quick-fire':
        return 'Quick Fire';
      default:
        return 'Game';
    }
  }

  String _getGameStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for response...';
      case 'accepted':
        return 'Game ready to play';
      case 'in-progress':
        return 'Game in progress';
      case 'completed':
        return 'Game finished';
      case 'declined':
        return 'Game declined';
      default:
        return status;
    }
  }
}

