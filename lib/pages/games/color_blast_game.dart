import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';

/// Color Blast Game - A fast-paced color matching game
///
/// Rules:
/// - Match the target color as fast as possible
/// - Each correct match increases your combo
/// - Miss a match and you lose a life
/// - Game ends when you run out of lives
/// - Higher combos = more points!
///
/// Responsive Design:
/// - All UI elements scale based on screen size using MediaQuery
/// - Optimized for phones from 320px to 900px+ widths
/// - Maintains perfect aspect ratios and touch targets
class ColorBlastGame extends StatefulWidget {
  const ColorBlastGame({super.key});

  @override
  State<ColorBlastGame> createState() => _ColorBlastGameState();
}

class _ColorBlastGameState extends State<ColorBlastGame>
    with SingleTickerProviderStateMixin {
  // Game state
  late List<Color> availableColors;
  late Color targetColor;
  late List<Color> displayColors;
  int score = 0;
  int combo = 0;
  int lives = 3;
  int round = 1;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  bool isProcessing = false;
  Timer? gameTimer;
  int timeRemaining = 30;
  late Stopwatch stopwatch;
  int reactionTime = 0;
  int bestReactionTime = 999999;
  String message = '';
  bool showMessage = false;
  bool isPaused = false;
  int? countdown;
  Timer? countdownTimer;

  // Animation controller
  late AnimationController _scoreAnimController;

  // Difficulty settings
  final Map<String, Map<String, int>> difficultySettings = {
    'easy': {'gridSize': 2, 'colors': 4, 'time': 60},
    'medium': {'gridSize': 3, 'colors': 6, 'time': 45},
    'hard': {'gridSize': 4, 'colors': 8, 'time': 30},
  };

  @override
  void initState() {
    super.initState();
    stopwatch = Stopwatch();
    _scoreAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    gameTimer?.cancel();
    stopwatch.stop();
    super.dispose();
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
    final colorCount = settings['colors']!;

    availableColors = _getColorPalette(colorCount);
    score = 0;
    combo = 0;
    lives = 3;
    round = 1;
    gameOver = false;
    isProcessing = false;
    timeRemaining = settings['time']!;
    bestReactionTime = 999999;
    stopwatch = Stopwatch();
    message = '';
    showMessage = false;
    isPaused = false;

    _generateNewRound();
    _startTimer();
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

  void _startTimer() {
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

  void _generateNewRound() {
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize']!;
    targetColor = availableColors[Random().nextInt(availableColors.length)];

    // Generate grid with random colors
    displayColors = [];
    for (int i = 0; i < gridSize * gridSize; i++) {
      displayColors
          .add(availableColors[Random().nextInt(availableColors.length)]);
    }

    // Ensure target color appears at least once
    if (!displayColors.contains(targetColor)) {
      displayColors[Random().nextInt(displayColors.length)] = targetColor;
    }

    setState(() {});
    stopwatch.reset();
  }

  void _onColorTap(Color color) {
    if (isProcessing || gameOver || isPaused || countdown != null) return;

    if (!stopwatch.isRunning) {
      stopwatch.start();
    }

    isProcessing = true;
    reactionTime = stopwatch.elapsedMilliseconds;

    if (color == targetColor) {
      _correctMatch();
    } else {
      _wrongMatch();
    }
  }

  void _correctMatch() {
    final bonusPoints = max(100 - (reactionTime ~/ 10), 10);
    final comboBonus = combo * 5;
    final totalPoints = bonusPoints + comboBonus;

    if (reactionTime < bestReactionTime) {
      bestReactionTime = reactionTime;
    }

    _scoreAnimController.forward(from: 0);

    setState(() {
      score += totalPoints;
      combo++;
      round++;
      message = '+$totalPoints 🎯';
      showMessage = true;
    });

    // Haptics for positive feedback
    if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !gameOver) {
        _generateNewRound();
        setState(() {
          isProcessing = false;
          showMessage = false;
        });
      }
    });
  }

  void _wrongMatch() {
    setState(() {
      lives--;
      combo = 0;
      message = 'Miss! ❌';
      showMessage = true;
    });

    if (GameSettings.hapticsEnabled) HapticFeedback.heavyImpact();

    if (lives <= 0) {
      _endGame();
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !gameOver) {
          _generateNewRound();
          setState(() {
            isProcessing = false;
            showMessage = false;
          });
        }
      });
    }
  }

  void _endGame() {
    gameTimer?.cancel();
    stopwatch.stop();
    setState(() {
      gameOver = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      await GameService.submitScore(
        'color-blast',
        score,
        difficulty,
        statistics: {
          'lives': lives,
          'combo': combo,
          'round': round,
          'bestReactionTime': bestReactionTime,
        },
      );
    } catch (e) {
      AppLogger().error('Failed to submit Color Blast score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
    });
  }

  void _togglePause() {
    if (gameOver || showDifficultyMenu || countdown != null) return;
    setState(() {
      isPaused = !isPaused;
    });
  }

  List<Color> _getColorPalette(int colorCount) {
    final allColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
      Colors.teal,
      Colors.amber,
    ];
    allColors.shuffle();
    return allColors.take(colorCount).toList();
  }

  /// Get responsive padding based on screen width
  double _getResponsivePadding(Size screenSize) {
    if (screenSize.width < 350) return 8.0;
    if (screenSize.width < 400) return 12.0;
    if (screenSize.width < 600) return 14.0;
    return 16.0;
  }

  /// Get responsive icon size based on screen width
  double _getResponsiveIconSize(Size screenSize, double baseSize) {
    if (screenSize.width < 350) return baseSize * 0.7;
    if (screenSize.width < 400) return baseSize * 0.85;
    if (screenSize.width < 600) return baseSize * 0.95;
    return baseSize;
  }

  /// Get responsive font size based on screen width
  double _getResponsiveFontSize(Size screenSize, double baseSize) {
    if (screenSize.width < 350) return baseSize * 0.8;
    if (screenSize.width < 400) return baseSize * 0.9;
    if (screenSize.width < 600) return baseSize * 0.95;
    return baseSize;
  }

  /// Get responsive spacing between elements
  double _getResponsiveSpacing(Size screenSize) {
    if (screenSize.width < 350) return 12.0;
    if (screenSize.width < 400) return 16.0;
    if (screenSize.width < 600) return 20.0;
    return 24.0;
  }

  /// Get responsive button padding
  EdgeInsets _getResponsiveButtonPadding(Size screenSize) {
    if (screenSize.width < 350) {
      return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0);
    } else if (screenSize.width < 400) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0);
    } else if (screenSize.width < 600) {
      return const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0);
    }
    return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
  }

  /// Get responsive target color display size
  double _getTargetColorSize(Size screenSize) {
    if (screenSize.width < 350) return 70.0;
    if (screenSize.width < 400) return 85.0;
    if (screenSize.width < 600) return 95.0;
    return 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = _getResponsivePadding(screenSize);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Color Blast',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: _getResponsiveFontSize(screenSize, 20),
              ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: _getResponsiveIconSize(screenSize, 24),
          ),
          onPressed: () {
            gameTimer?.cancel();
            countdownTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!showDifficultyMenu && !gameOver)
            IconButton(
              tooltip: isPaused ? 'Resume' : 'Pause',
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
        ],
      ),
      body: SafeArea(
        child: showDifficultyMenu
            ? _buildDifficultyMenu()
            : Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child:
                        gameOver ? _buildGameOverScreen() : _buildGameScreen(),
                  ),
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
                                color: Colors.white,
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
                            const Icon(Icons.pause, size: 64, color: Colors.white),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _togglePause,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDifficultyMenu() {
    final screenSize = MediaQuery.of(context).size;
    final spacing = _getResponsiveSpacing(screenSize);
    final iconSize = _getResponsiveIconSize(screenSize, 64);
    final fontSize = _getResponsiveFontSize(screenSize, 18);

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: _getResponsivePadding(screenSize)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.palette,
                size: iconSize,
                color: Colors.purpleAccent,
              ),
              SizedBox(height: spacing),
              Text(
                'Color Blast',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: _getResponsiveFontSize(screenSize, 28),
                    ),
              ),
              SizedBox(height: spacing * 0.33),
              Text(
                'Tap matching colors as fast as you can!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                      fontSize: _getResponsiveFontSize(screenSize, 14),
                    ),
              ),
              SizedBox(height: spacing * 1.67),
              _buildDifficultyButton(
                'EASY',
                '2x2 Grid • 4 Colors • 60s',
                Colors.green,
                'easy',
                fontSize,
              ),
              SizedBox(height: spacing * 0.5),
              _buildDifficultyButton(
                'MEDIUM',
                '3x3 Grid • 6 Colors • 45s',
                Colors.orange,
                'medium',
                fontSize,
              ),
              SizedBox(height: spacing * 0.5),
              _buildDifficultyButton(
                'HARD',
                '4x4 Grid • 8 Colors • 30s',
                Colors.red,
                'hard',
                fontSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String description,
    Color color,
    String diffValue,
    double responsiveFontSize,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final buttonPadding = _getResponsiveButtonPadding(screenSize);
    final spacing = _getResponsiveSpacing(screenSize);

    return GestureDetector(
      onTap: () => _startGame(diffValue),
      child: Container(
        width: double.infinity,
        padding: buttonPadding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              BorderRadius.circular(_getResponsiveFontSize(screenSize, 12)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: responsiveFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing * 0.17),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: _getResponsiveFontSize(screenSize, 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final screenSize = MediaQuery.of(context).size;
    final settings = difficultySettings[difficulty]!;
    final gridSize = settings['gridSize']!;
    final padding = _getResponsivePadding(screenSize);
    final spacing = _getResponsiveSpacing(screenSize);

    return Column(
      children: [
        // Stats bar - fully responsive
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip('Score', score.toString(), Colors.blue),
              SizedBox(width: padding * 0.5),
              _buildStatChip('Combo', combo.toString(), Colors.purple),
              SizedBox(width: padding * 0.5),
              _buildStatChip('Lives', '❤️ $lives', Colors.red),
              SizedBox(width: padding * 0.5),
              _buildStatChip('Time', '⏱️ $timeRemaining', Colors.orange),
            ],
          ),
        ),
        SizedBox(height: spacing),

        // Combo banner
        if (combo >= 3)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: padding * 0.5,
            ),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              border: Border.all(color: Colors.purpleAccent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Combo x$combo! 🔥',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: _getResponsiveFontSize(screenSize, 16),
              ),
            ),
          ),
        if (combo >= 3) SizedBox(height: spacing * 0.5),

        // Target color display - responsive size
        Column(
          children: [
            Text(
              'Tap this color:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: _getResponsiveFontSize(screenSize, 14),
                  ),
            ),
            SizedBox(height: spacing * 0.5),
            Container(
              width: _getTargetColorSize(screenSize),
              height: _getTargetColorSize(screenSize),
              decoration: BoxDecoration(
                color: targetColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: targetColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onColorTap(targetColor),
                  child: Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: _getResponsiveIconSize(screenSize, 40),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing * 1.33),

        // Color grid - fully responsive
        Expanded(
          child: GridView.count(
            crossAxisCount: gridSize,
            crossAxisSpacing: padding,
            mainAxisSpacing: padding,
            childAspectRatio: 1,
            children: List.generate(
              displayColors.length,
              (index) => _buildColorBox(displayColors[index]),
            ),
          ),
        ),

        // Floating message - responsive font size
        if (showMessage)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding * 1.25,
              vertical: _getResponsiveFontSize(screenSize, 8),
            ),
            decoration: BoxDecoration(
              color: message.contains('✅') || message.contains('+')
                  ? Colors.green
                  : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: _getResponsiveFontSize(screenSize, 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    final screenSize = MediaQuery.of(context).size;
    final spacing = _getResponsiveSpacing(screenSize);
    final iconSize = _getResponsiveIconSize(screenSize, 80);
    final buttonPadding = _getResponsiveButtonPadding(screenSize);

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: _getResponsivePadding(screenSize)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videogame_asset,
                size: iconSize,
                color: Colors.purpleAccent,
              ),
              SizedBox(height: spacing),
              Text(
                'Game Over!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: _getResponsiveFontSize(screenSize, 24),
                    ),
              ),
              SizedBox(height: spacing * 1.33),
              _buildStatCard('Final Score', score.toString(), Colors.blue),
              SizedBox(height: spacing * 0.5),
              _buildStatCard('Max Combo', combo.toString(), Colors.purple),
              SizedBox(height: spacing * 0.5),
              _buildStatCard('Rounds', round.toString(), Colors.orange),
              SizedBox(height: spacing * 0.5),
              _buildStatCard(
                'Best Time',
                '${bestReactionTime}ms',
                Colors.cyan,
              ),
              SizedBox(height: spacing * 1.33),
              ElevatedButton.icon(
                onPressed: _resetGame,
                icon: Icon(
                  Icons.replay,
                  size: _getResponsiveIconSize(screenSize, 20),
                ),
                label: Text(
                  'Play Again',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(screenSize, 16),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: buttonPadding,
                ),
              ),
              SizedBox(height: spacing * 0.5),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.home,
                  size: _getResponsiveIconSize(screenSize, 20),
                ),
                label: Text(
                  'Back to Games',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(screenSize, 16),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: buttonPadding,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorBox(Color color) {
    final screenSize = MediaQuery.of(context).size;
    final borderRadius = _getResponsiveFontSize(screenSize, 8);

    return GestureDetector(
      onTap: () => _onColorTap(color),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onColorTap(color),
            child: Container(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    final screenSize = MediaQuery.of(context).size;
    final padding = _getResponsivePadding(screenSize);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding * 0.67,
        vertical: padding * 0.38,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(screenSize, 10),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(screenSize, 14),
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final screenSize = MediaQuery.of(context).size;
    final padding = _getResponsivePadding(screenSize);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding * 1.5,
        vertical: padding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: _getResponsiveFontSize(screenSize, 16),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: _getResponsiveFontSize(screenSize, 20),
                ),
          ),
        ],
      ),
    );
  }
}
