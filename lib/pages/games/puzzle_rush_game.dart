import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';
import 'games_list_page.dart';

/// Puzzle Rush - A fast-paced sliding puzzle game
///
/// Rules:
/// - Slide tiles to match the target pattern shown at the top
/// - Each correct pattern gives points
/// - Time decreases as difficulty increases
/// - Combos multiply your points
/// - Race against the clock!
class PuzzleRushGame extends StatefulWidget {
  const PuzzleRushGame({super.key});

  @override
  State<PuzzleRushGame> createState() => _PuzzleRushGameState();
}

class _PuzzleRushGameState extends State<PuzzleRushGame>
    with TickerProviderStateMixin {
  late List<int> tiles;
  late List<int> targetPattern;
  late AnimationController _matchController;
  late AnimationController _tileController;
  late AnimationController _hintController;
  late AnimationController _glowController;

  int score = 0;
  int combo = 0;
  int maxCombo = 0;
  int moves = 0;
  int patternsMatched = 0;
  int timeRemaining = 0;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  bool isProcessing = false;
  Timer? gameTimer;
  String message = '';
  bool showMessage = false;
  int emptyIndex = 0;
  bool isPaused = false;
  int? countdown;
  Timer? countdownTimer;
  
  // New features
  int hintsUsed = 0;
  int hintsAvailable = 3;
  bool showHintGlow = false;
  Map<String, int> bestTimes = {
    'easy': 0,
    'medium': 0,
    'hard': 0,
  };
  int currentBestTime = 0;
  bool soundsEnabled = true;
  int currentPatternStartTime = 0;
  List<int> patternTimes = [];

  final Map<String, Map<String, dynamic>> difficultySettings = {
    'easy': {
      'gridSize': 3, // 3x3 = 9 tiles
      'time': 60,
      'pointsPerMatch': 50,
      'moveBonus': 3,
    },
    'medium': {
      'gridSize': 4, // 4x4 = 16 tiles
      'time': 45,
      'pointsPerMatch': 100,
      'moveBonus': 5,
    },
    'hard': {
      'gridSize': 5, // 5x5 = 25 tiles
      'time': 30,
      'pointsPerMatch': 200,
      'moveBonus': 10,
    },
  };

  @override
  void initState() {
    super.initState();
    _matchController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _tileController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _loadBestTimes();
  }
  
  void _loadBestTimes() {
    // Load from SharedPreferences in a real implementation
    // For now, just initialize
  }
  
  void _saveBestTimes() {
    // Save to SharedPreferences in a real implementation
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      difficulty = selectedDifficulty;
    });
    _startCountdown();
  }

  void _initializeGame() {
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize'] as int;
    final totalTiles = gridSize * gridSize;

    // Create tile list (0 = empty)
    tiles = List.generate(totalTiles - 1, (i) => i + 1);
    tiles.add(0);
    tiles.shuffle();

    emptyIndex = tiles.indexOf(0);
    score = 0;
    combo = 0;
    maxCombo = 0;
    moves = 0;
    patternsMatched = 0;
    timeRemaining = settings['time'] as int;
    gameOver = false;
    isProcessing = false;
    message = '';
    showMessage = false;
    isPaused = false;
    
    // Reset new features
    hintsUsed = 0;
    hintsAvailable = 3;
    showHintGlow = false;
    currentBestTime = bestTimes[difficulty] ?? 0;
    currentPatternStartTime = 0;
    patternTimes = [];

    _generateTargetPattern();
    _startGameTimer();
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    setState(() {
      countdown = 3;
      gameOver = false;
      isPaused = false;
      showMessage = false;
    });
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        countdown = (countdown ?? 1) - 1;
      });
      if ((countdown ?? 0) <= 0) {
        timer.cancel();
        setState(() {
          countdown = null;
        });
        _initializeGame();
      }
    });
  }

  void _generateTargetPattern() {
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize'] as int;
    final totalTiles = gridSize * gridSize;

    // Generate a random pattern to match
    targetPattern = List.generate(totalTiles, (i) => i);
    targetPattern.shuffle();
  }

  void _startGameTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || gameOver || isPaused) return;
      setState(() {
        timeRemaining--;
        if (timeRemaining <= 0) {
          _endGame();
        }
      });
    });
  }

  List<int> _getAdjacentIndices(int index) {
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize'] as int;
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final adjacent = <int>[];

    // Top
    if (row > 0) adjacent.add(index - gridSize);
    // Bottom
    if (row < gridSize - 1) adjacent.add(index + gridSize);
    // Left
    if (col > 0) adjacent.add(index - 1);
    // Right
    if (col < gridSize - 1) adjacent.add(index + 1);

    return adjacent;
  }

  void _slideTile(int tileIndex) {
    if (gameOver || isProcessing || isPaused || countdown != null) return;

    final adjacent = _getAdjacentIndices(emptyIndex);

    if (adjacent.contains(tileIndex)) {
      isProcessing = true;
      _tileController.forward(from: 0);

      setState(() {
        // Swap tile with empty space
        tiles[emptyIndex] = tiles[tileIndex];
        tiles[tileIndex] = 0;
        emptyIndex = tileIndex;
        moves++;
      });

      // Check if pattern matches
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkPatternMatch();
          setState(() {
            isProcessing = false;
          });
        }
      });
      HapticFeedback.selectionClick();
    } else {
      // Invalid move feedback
      HapticFeedback.lightImpact();
    }
  }

  void _checkPatternMatch() {
    // Check if current tile arrangement matches any part of the target
    final settings = difficultySettings[difficulty]!;
    final pointsPerMatch = settings['pointsPerMatch'] as int;
    final moveBonus = settings['moveBonus'] as int;

    // For simplicity, match if tiles are in ascending order (solved state)
    bool isSolved = true;
    final gridSize2 = difficultySettings[difficulty]!['gridSize'] as int;
    final totalTiles = gridSize2 * gridSize2;

    for (int i = 0; i < totalTiles - 1; i++) {
      if (tiles[i] != i + 1) {
        isSolved = false;
        break;
      }
    }

    if (isSolved) {
      _matchController.forward(from: 0);

      final moveEfficiency = max(1, 50 - (moves ~/ 2));
      final comboMultiplier = max(1, combo);
      int points =
          pointsPerMatch + moveEfficiency + (moveBonus * comboMultiplier);
      
      // Calculate pattern time
      final patternTime = currentPatternStartTime - timeRemaining;
      patternTimes.add(patternTime);
      
      // Check for best time
      if (patternTime > 0 && (currentBestTime == 0 || patternTime < currentBestTime)) {
        currentBestTime = patternTime;
        if (soundsEnabled) {
          HapticFeedback.heavyImpact();
        }
      }

      setState(() {
        score += points;
        combo++;
        maxCombo = max(maxCombo, combo);
        patternsMatched++;
        message = '✨ Pattern Match! +$points points (Combo: $combo)';
        showMessage = true;
      });

      if (soundsEnabled) {
        HapticFeedback.mediumImpact();
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !gameOver) {
          setState(() {
            showMessage = false;
            message = '';
          });
          _generateNextRound();
        }
      });
    }
  }

  void _generateNextRound() {
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize'] as int;
    final totalTiles = gridSize * gridSize;

    // Create new shuffled puzzle
    tiles = List.generate(totalTiles - 1, (i) => i + 1);
    tiles.add(0);
    tiles.shuffle();

    // Make sure it's not already solved
    while (true) {
      bool isSolved = true;
      for (int i = 0; i < totalTiles - 1; i++) {
        if (tiles[i] != i + 1) {
          isSolved = false;
          break;
        }
      }
      if (!isSolved) break;
      tiles.shuffle();
    }

    emptyIndex = tiles.indexOf(0);
    moves = 0;
    currentPatternStartTime = timeRemaining;
    _generateTargetPattern();
  }
  
  void _useHint() {
    if (hintsAvailable <= 0 || gameOver || isPaused) return;
    
    setState(() {
      hintsAvailable--;
      hintsUsed++;
      showHintGlow = true;
    });
    
    _hintController.forward(from: 0);
    
    // Highlight the next tile that should be moved
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          showHintGlow = false;
        });
      }
    });
    
    if (soundsEnabled) {
      HapticFeedback.lightImpact();
    }
  }
  
  int _getNextOptimalMove() {
    // Simple heuristic: find a tile that's in the wrong position and adjacent to empty
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != 0 && tiles[i] != i + 1) {
        final adjacent = _getAdjacentIndices(emptyIndex);
        if (adjacent.contains(i)) {
          return i;
        }
      }
    }
    return -1;
  }

  void _endGame() {
    gameTimer?.cancel();
    
    // Save best time if achieved
    if (currentBestTime > 0) {
      if (bestTimes[difficulty] == 0 || currentBestTime < bestTimes[difficulty]!) {
        bestTimes[difficulty] = currentBestTime;
        _saveBestTimes();
      }
    }
    
    setState(() {
      gameOver = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      await GameService.submitScore(
        'puzzle-rush',
        score,
        difficulty,
        statistics: {
          'patternsMatched': patternsMatched,
          'maxCombo': maxCombo,
          'totalMoves': moves,
          'moveEfficiency': patternsMatched > 0
              ? (moves / patternsMatched).toStringAsFixed(1)
              : '0',
          'hintsUsed': hintsUsed,
          'bestPatternTime': currentBestTime,
          'avgPatternTime': patternTimes.isNotEmpty
              ? (patternTimes.reduce((a, b) => a + b) / patternTimes.length).toStringAsFixed(1)
              : '0',
        },
      );
    } catch (e) {
      AppLogger().error('Failed to submit puzzle rush score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
    });
  }

  @override
  void dispose() {
    _matchController.dispose();
    _tileController.dispose();
    _hintController.dispose();
    _glowController.dispose();
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Puzzle Rush'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            gameTimer?.cancel();
            countdownTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!showDifficultyMenu && !gameOver) ...[
            IconButton(
              tooltip: hintsAvailable > 0 ? 'Use Hint ($hintsAvailable left)' : 'No hints available',
              icon: Icon(
                hintsAvailable > 0 ? Icons.lightbulb : Icons.lightbulb_outline,
                color: hintsAvailable > 0 ? Colors.yellow : Colors.grey,
              ),
              onPressed: hintsAvailable > 0 ? _useHint : null,
            ),
            IconButton(
              tooltip: soundsEnabled ? 'Sound On' : 'Sound Off',
              icon: Icon(
                soundsEnabled ? Icons.volume_up : Icons.volume_off,
                color: soundsEnabled ? Colors.white : Colors.grey,
              ),
              onPressed: () => setState(() => soundsEnabled = !soundsEnabled),
            ),
            IconButton(
              tooltip: isPaused ? 'Resume' : 'Pause',
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => isPaused = !isPaused),
            ),
          ],
        ],
      ),
      body: showDifficultyMenu
          ? _buildDifficultyMenu()
          : gameOver
              ? _buildGameOverScreen()
              : Stack(
                  children: [
                    _buildGameScreen(),
                    if (countdown != null)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: Text(
                            '${countdown ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    if (isPaused)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause, 
                                size: 64, 
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => isPaused = false),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Resume'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildDifficultyMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);
    final buttonWidth = ResponsiveSizing.isSmallScreen(context) ? 140.0 : 180.0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: padding,
                child: Column(
                  children: [
                    Text(
                      '🧩 Puzzle Rush 🧩',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveSizing.getFontSize(context,
                                    small: 24,
                                    medium: 28,
                                    large: 32,
                                    xlarge: 36),
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Slide tiles to solve the puzzle. Race against time!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 12, medium: 14, large: 16, xlarge: 16),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              _buildDifficultyButtonPuzzle(
                'Easy',
                '3×3 Grid • 60s',
                Colors.green,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonPuzzle(
                'Medium',
                '4×4 Grid • 45s',
                Colors.blue,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonPuzzle(
                'Hard',
                '5×5 Grid • 30s',
                Colors.red,
                buttonWidth,
              ),
              SizedBox(height: spacing),
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 12, medium: 14, large: 16)),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context)),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      '💡 How to Play',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 12, medium: 13, large: 14, xlarge: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Tap tiles adjacent to the empty space to slide\n2. Arrange tiles in numbered order\n3. Each puzzle solved = more points\n4. Build combos for bonus points!',
                      style: TextStyle(
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 11, medium: 12, large: 13, xlarge: 13),
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButtonPuzzle(
    String label,
    String desc,
    Color color,
    double width,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: width,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: shadowBlur,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 15, medium: 16, large: 18, xlarge: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 10, medium: 11, large: 12, xlarge: 12),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final gridSize = difficultySettings[difficulty]!['gridSize'] as int;

    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Score', score.toString(), Colors.purple),
                _buildStatCard('Combo', combo.toString(), Colors.orange),
                _buildStatCard('Time', '${timeRemaining}s',
                    timeRemaining <= 10 ? Colors.red : Colors.green),
              ],
            ),
            SizedBox(height: spacing),
            
            // Best time display
            if (currentBestTime > 0)
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 6, medium: 8, large: 10)),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context)),
                  border: Border.all(color: Colors.amber.shade700, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Best Time: ${currentBestTime}s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 12, medium: 14, large: 16, xlarge: 16),
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: spacing),

            // Progress Info
            Container(
              padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                  small: 8, medium: 10, large: 12)),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(
                    ResponsiveSizing.getBorderRadius(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Patterns: $patternsMatched',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                    ),
                  ),
                  Text(
                    'Moves: $moves',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                    ),
                  ),
                  Text(
                    'Max Combo: $maxCombo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Message
            if (showMessage)
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 10, medium: 12, large: 14)),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context)),
                  border: Border.all(color: Colors.yellow.shade700),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.yellow.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(height: spacing),
            SizedBox(height: spacing),

            // Puzzle Grid
            _buildPuzzleGrid(gridSize),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleGrid(int gridSize) {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 4, medium: 6, large: 8);

    // Calculate tile size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth -
        (padding.left + padding.right) -
        (spacing * (gridSize - 1));
    final tileSize = availableWidth / gridSize;

    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius:
            BorderRadius.circular(ResponsiveSizing.getBorderRadius(context)),
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridSize,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tiles.length,
        itemBuilder: (context, index) {
          return _buildPuzzleTile(index, tiles[index], tileSize);
        },
      ),
    );
  }

  Widget _buildPuzzleTile(int index, int tileNumber, double size) {
    final isEmptyTile = tileNumber == 0;
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final isHinted = showHintGlow && index == _getNextOptimalMove();

    if (isEmptyTile) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(borderRadius * 0.5),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _slideTile(index),
      child: ScaleTransition(
        scale: _tileController.drive(Tween<double>(begin: 1, end: 0.95)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Colors.blue, Colors.purple, tileNumber / 25) ??
                    Colors.blue,
                Color.lerp(Colors.cyan, Colors.pink, tileNumber / 25) ??
                    Colors.cyan,
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius * 0.5),
            boxShadow: [
              if (isHinted)
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.8),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _slideTile(index),
              borderRadius: BorderRadius.circular(borderRadius * 0.5),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$tileNumber',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 20, medium: 24, large: 28, xlarge: 32),
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (isHinted)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: RotationTransition(
                          turns: _hintController.drive(
                            Tween<double>(begin: 0, end: 1).chain(
                              CurveTween(curve: Curves.easeInOut),
                            ),
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final buttonHeight = ResponsiveSizing.getButtonHeight(context);

    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: spacing * 2),
            Container(
              padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                  small: 14, medium: 18, large: 22)),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 Time\'s Up! 🎉',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 20, medium: 24, large: 28, xlarge: 32),
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing),
                  Text(
                    'Final Score: $score',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 18, medium: 20, large: 22, xlarge: 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: [
                _buildStatBox('Patterns', '$patternsMatched', Colors.orange),
                _buildStatBox('Max Combo', '$maxCombo', Colors.pink),
                _buildStatBox('Total Moves', '$moves', Colors.blue),
                _buildStatBox(
                    'Difficulty', difficulty.toUpperCase(), Colors.green),
                if (currentBestTime > 0)
                  _buildStatBox('Best Time', '${currentBestTime}s ⭐', Colors.amber),
                _buildStatBox('Hints Used', '$hintsUsed', Colors.teal),
              ],
            ),
            SizedBox(height: spacing),

            // Play Again Button
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh),
                label: Text(
                  'Play Again',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing * 0.5),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  'Back to Games',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final theme = Theme.of(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 10, medium: 11, large: 12, xlarge: 12),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 14, medium: 18, large: 20, xlarge: 22),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 12, medium: 14, large: 16);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 11, medium: 12, large: 13, xlarge: 13),
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 16, medium: 18, large: 20, xlarge: 22),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
