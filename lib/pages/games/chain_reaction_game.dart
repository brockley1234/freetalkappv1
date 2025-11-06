import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';
import 'games_list_page.dart';

/// Chain Reaction - Addictive pattern-matching game with expanding circles
/// Players must tap circles in the correct sequence to build their chain.
/// Higher chains = exponential score multipliers. Perfect for competitive play!
class ChainReactionGame extends StatefulWidget {
  const ChainReactionGame({super.key});

  @override
  State<ChainReactionGame> createState() => _ChainReactionGameState();
}

class _ChainReactionGameState extends State<ChainReactionGame>
    with TickerProviderStateMixin {
  // Game state
  int score = 0;
  int currentChain = 0;
  int maxChain = 0;
  int round = 1;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  String message = '';
  bool showMessage = false;
  int timeRemaining = 0;
  Timer? gameTimer;
  Timer? spawnTimer;
  int circlesSpawned = 0;
  int correctTaps = 0;
  int missedTaps = 0;
  bool isPaused = false;
  int? countdown;
  Timer? countdownTimer;

  // Circle data
  late List<CircleElement> circles;
  int nextExpectedSequence = 0;
  Random random = Random();

  // Animation controllers
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _powerUpController;
  
  // Power-up system
  int powerUpCount = 0;
  bool speedBoostActive = false;
  bool streakProtectionActive = false;
  bool freezeActive = false;
  Timer? powerUpTimer;
  String activePowerUpMessage = '';

  // Difficulty settings
  final Map<String, Map<String, dynamic>> difficultySettings = {
    'easy': {
      'duration': 60,
      'spawnInterval': 1200, // ms between circle spawns
      'circleSize': 80.0,
      'scorePerHit': 50,
      'chainMultiplier': 1.5,
      'maxCircles': 5,
    },
    'medium': {
      'duration': 90,
      'spawnInterval': 900,
      'circleSize': 70.0,
      'scorePerHit': 100,
      'chainMultiplier': 2.0,
      'maxCircles': 6,
    },
    'hard': {
      'duration': 120,
      'spawnInterval': 600,
      'circleSize': 60.0,
      'scorePerHit': 150,
      'chainMultiplier': 2.5,
      'maxCircles': 7,
    },
  };

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _powerUpController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _powerUpController.dispose();
    gameTimer?.cancel();
    powerUpTimer?.cancel();
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
    timeRemaining = settings['duration'] as int;
    score = 0;
    currentChain = 0;
    maxChain = 0;
    round = 1;
    gameOver = false;
    message = '';
    showMessage = false;
    circles = [];
    nextExpectedSequence = 0;
    circlesSpawned = 0;
    correctTaps = 0;
    missedTaps = 0;
    isPaused = false;
    
    // Reset power-ups
    powerUpCount = 0;
    speedBoostActive = false;
    streakProtectionActive = false;
    freezeActive = false;
    activePowerUpMessage = '';

    _startTimer();
    _startSpawningCircles();
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    setState(() {
      countdown = 3;
      gameOver = false;
      isPaused = false;
      showMessage = false;
      circles = [];
      nextExpectedSequence = 0;
      circlesSpawned = 0;
      correctTaps = 0;
      missedTaps = 0;
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
      if (!mounted || isPaused) return;
      setState(() {
        timeRemaining--;
      });
      if (timeRemaining <= 0) {
        _endGame();
      }
    });
  }

  void _startSpawningCircles() {
    final settings = difficultySettings[difficulty]!;
    final spawnInterval = settings['spawnInterval'] as int;
    final maxCircles = settings['maxCircles'] as int;

    spawnTimer?.cancel();
    spawnTimer = Timer.periodic(Duration(milliseconds: spawnInterval), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }
      if (isPaused) return;
      if (circles.length < maxCircles) {
        _spawnNewCircle();
      }
    });
  }

  void _spawnNewCircle() {
    final settings = difficultySettings[difficulty]!;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    final newCircle = CircleElement(
      id: circlesSpawned,
      color: colors[circlesSpawned % colors.length],
      sequence: nextExpectedSequence,
      x: 50 + random.nextDouble() * 50,
      y: 30 + random.nextDouble() * 60,
      size: settings['circleSize'] as double,
      spawnTime: DateTime.now(),
    );

    setState(() {
      circles.add(newCircle);
      circlesSpawned++;
      nextExpectedSequence++;
    });

    // Animate scale for visual feedback
    _scaleController.forward(from: 0.0);
  }

  void _onCircleTapped(int circleId, CircleElement circle) {
    if (isPaused || countdown != null || gameOver) return;
    // Check if correct sequence
    if (circle.sequence == currentChain) {
      // Correct tap!
      final settings = difficultySettings[difficulty]!;
      final scorePerHit = settings['scorePerHit'] as int;
      final chainMultiplier = settings['chainMultiplier'] as double;

      int points = scorePerHit + (currentChain * 10);
      double multiplier = pow(chainMultiplier, currentChain / 3).toDouble();
      int finalScore = (points * multiplier).toInt();
      
      // Speed boost bonus
      if (speedBoostActive) {
        finalScore = (finalScore * 1.5).toInt();
      }
      
      // Award power-up every 10 chains
      if (currentChain % 10 == 0 && currentChain > 0) {
        powerUpCount++;
      }

      setState(() {
        score += finalScore;
        currentChain++;
        correctTaps++;
        if (currentChain > maxChain) {
          maxChain = currentChain;
        }

        // Remove the tapped circle
        circles.removeWhere((c) => c.id == circleId);

        message = speedBoostActive 
            ? '⚡ +$finalScore (Chain: $currentChain) BOOST!'
            : '+$finalScore (Chain: $currentChain)';
        showMessage = true;
      });

      if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            showMessage = false;
          });
        }
      });
    } else {
      // Wrong tap - check for streak protection
      if (streakProtectionActive) {
        // Streak protection - no penalty, just remove the wrong circle
        setState(() {
          message = '🛡️ Protected!';
          showMessage = true;
          circles.removeWhere((c) => c.id == circleId);
        });
        
        if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              showMessage = false;
            });
          }
        });
      } else {
        // No protection - break chain
        setState(() {
          missedTaps++;
          currentChain = 0;
          message = 'Chain Broken! -50';
          showMessage = true;

          if (score >= 50) {
            score -= 50;
          }

          // Remove all circles and start over
          circles.clear();
          nextExpectedSequence = 0;
        });

        if (GameSettings.hapticsEnabled) HapticFeedback.heavyImpact();

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              showMessage = false;
            });
          }
        });
      }
    }
  }
  
  void _activatePowerUp(String type) {
    setState(() {
      powerUpCount--;
    });
    
    switch (type) {
      case 'speed':
        speedBoostActive = true;
        activePowerUpMessage = '⚡ Speed Boost!';
        powerUpTimer?.cancel();
        powerUpTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              speedBoostActive = false;
              activePowerUpMessage = '';
            });
          }
        });
        break;
      case 'protection':
        streakProtectionActive = true;
        activePowerUpMessage = '🛡️ Streak Protection!';
        powerUpTimer?.cancel();
        powerUpTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) {
            setState(() {
              streakProtectionActive = false;
              activePowerUpMessage = '';
            });
          }
        });
        break;
      case 'freeze':
        freezeActive = true;
        activePowerUpMessage = '❄️ Freeze!';
        powerUpTimer?.cancel();
        powerUpTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              freezeActive = false;
              activePowerUpMessage = '';
            });
          }
        });
        // Temporarily stop circles from spawning
        spawnTimer?.cancel();
        Timer(const Duration(seconds: 8), () {
          if (!gameOver) {
            _startSpawningCircles();
          }
        });
        break;
    }
    
    if (GameSettings.hapticsEnabled) HapticFeedback.selectionClick();
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && activePowerUpMessage.isNotEmpty) {
        setState(() {
          // Keep message for duration
        });
      }
    });
  }

  void _endGame() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    setState(() {
      gameOver = true;
      message = 'Game Over!';
      showMessage = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      await GameService.submitScore(
        'chain_reaction',
        score,
        difficulty,
        statistics: {
          'maxChain': maxChain,
          'correctTaps': correctTaps,
          'missedTaps': missedTaps,
          'accuracy':
              correctTaps > 0 ? (correctTaps / (correctTaps + missedTaps)) : 0,
          'round': round,
        },
      );
      AppLogger().info('✅ Chain Reaction score submitted: $score');
    } catch (e) {
      AppLogger().error('❌ Failed to submit Chain Reaction score', error: e);
    }
  }

  void _resetGame() {
    setState(() {
      gameTimer?.cancel();
      gameOver = false;
      showDifficultyMenu = true;
      _initializeGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('⛓️ Chain Reaction'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            gameTimer?.cancel();
            spawnTimer?.cancel();
            countdownTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!showDifficultyMenu && !gameOver) ...[
            if (powerUpCount > 0)
              PopupMenuButton<String>(
                icon: Badge(
                  label: Text('$powerUpCount'),
                  child: const Icon(Icons.bolt),
                ),
                tooltip: 'Power-ups ($powerUpCount available)',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'speed',
                    child: Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('⚡ Speed Boost (10s)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'protection',
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('🛡️ Streak Protection (15s)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'freeze',
                    child: Row(
                      children: [
                        Icon(Icons.ac_unit, color: Colors.cyan),
                        SizedBox(width: 8),
                        Text('❄️ Freeze (8s)'),
                      ],
                    ),
                  ),
                ],
                onSelected: _activatePowerUp,
              ),
            IconButton(
              tooltip: isPaused ? 'Resume' : 'Pause',
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => isPaused = !isPaused),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
            ),
          ),
          // Main content
          if (showDifficultyMenu)
            _buildDifficultyMenu()
          else if (gameOver)
            _buildGameOverScreen()
          else
            Stack(
              children: [
                _buildGameScreen(),
                if (countdown != null)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Text(
                        '${countdown ?? ''}',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
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
                            onPressed: () => setState(() => isPaused = false),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          // Floating message
          if (showMessage)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveSizing.getPadding(context).left,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveSizing.getSpacing(context,
                        small: 16, medium: 24, large: 32),
                    vertical: ResponsiveSizing.getSpacing(context,
                        small: 8, medium: 12, large: 16),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context),
                    ),
                    border: Border.all(
                      color: Colors.purpleAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 16, medium: 20, large: 24),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final spacing = ResponsiveSizing.getSpacing(context);
    final isSmall = ResponsiveSizing.isSmallScreen(context);

    return SafeArea(
      child: Column(
        children: [
          // Header with stats
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding.left,
              vertical: isSmall ? padding.top / 2 : padding.top,
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              border: const Border(
                bottom: BorderSide(color: Colors.purpleAccent, width: 2),
              ),
            ),
            child: Column(
              children: [
                // Power-up indicator
                if (activePowerUpMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: AnimatedBuilder(
                      animation: _powerUpController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.7 + (_powerUpController.value * 0.3),
                          child: Text(
                            activePowerUpMessage,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                isSmall
                    ? Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatBadge(
                                  'Score', score.toString(), Colors.amber),
                              _buildStatBadge(
                                  'Chain', currentChain.toString(), Colors.green),
                            ],
                          ),
                          SizedBox(height: spacing / 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatBadge(
                                  'Max', maxChain.toString(), Colors.blue),
                              _buildStatBadge(
                                'Time',
                                '${timeRemaining}s',
                                timeRemaining < 10 ? Colors.red : Colors.cyan,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatBadge('Score', score.toString(), Colors.amber),
                          _buildStatBadge(
                              'Chain', currentChain.toString(), Colors.green),
                          _buildStatBadge('Max', maxChain.toString(), Colors.blue),
                          _buildStatBadge(
                            'Time',
                            '${timeRemaining}s',
                            timeRemaining < 10 ? Colors.red : Colors.cyan,
                          ),
                        ],
                      ),
              ],
            ),
          ),
          // Game area with circles
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Tap outside circles to break chain
                setState(() {
                  if (currentChain > 0) {
                    currentChain = 0;
                  }
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Background pattern
                    const Positioned.fill(
                      child: CustomPaint(
                        painter: BackgroundPatternPainter(),
                      ),
                    ),
                    // Circles
                    ...circles.map((circle) {
                      return Positioned(
                        left: screenWidth * (circle.x / 100),
                        top: screenHeight * (circle.y / 100),
                        child: GestureDetector(
                          onTap: () {
                            if (!gameOver) {
                              _onCircleTapped(circle.id, circle);
                            }
                          },
                          child: _buildCircleWidget(circle, screenWidth),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleWidget(CircleElement circle, double screenWidth) {
    final elapsed = DateTime.now().difference(circle.spawnTime).inMilliseconds;
    final fadeOut = max(0.0, 1.0 - (elapsed / 5000.0)); // Fade after 5 seconds
    final textFontSize =
        ResponsiveSizing.getFontSize(context, small: 18, medium: 24, large: 28);
    final borderWidth = ResponsiveSizing.isSmallScreen(context) ? 2.0 : 3.0;

    return Tooltip(
      message: 'Tap #${circle.sequence + 1}',
      child: Transform.scale(
        scale: 1.0 + (sin(elapsed / 200) * 0.1),
        child: Container(
          width: circle.size,
          height: circle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circle.color.withValues(alpha: fadeOut),
            border: Border.all(
              color: Colors.white.withValues(alpha: fadeOut * 0.8),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: circle.color.withValues(alpha: fadeOut * 0.6),
                blurRadius: ResponsiveSizing.getShadowBlur(context) + 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${circle.sequence + 1}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: fadeOut),
                fontSize: textFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    final labelFontSize =
        ResponsiveSizing.getFontSize(context, small: 10, medium: 12, large: 14);
    final valueFontSize =
        ResponsiveSizing.getFontSize(context, small: 14, medium: 18, large: 22);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 6, medium: 8, large: 12);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final isSmall = ResponsiveSizing.isSmallScreen(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isSmall ? 2 : 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: padding / 2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);
    final buttonWidth = ResponsiveSizing.isSmallScreen(context) ? 140.0 : 180.0;
    final titleFontSize =
        ResponsiveSizing.getFontSize(context, small: 28, medium: 36, large: 44);
    final descFontSize =
        ResponsiveSizing.getFontSize(context, small: 12, medium: 14, large: 16);
    final iconSize = ResponsiveSizing.getIconSize(context,
        small: 60, medium: 80, large: 100);

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gamepad,
              size: iconSize,
              color: Colors.deepPurple,
            ),
            SizedBox(height: spacing / 2),
            Text(
              'Chain Reaction',
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing / 3),
            Text(
              'Tap circles in sequence to build your chain!\nHigher chains = bigger scores!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: descFontSize,
              ),
            ),
            SizedBox(height: spacing),
            Text(
              'Select Difficulty',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 16, medium: 18, large: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing),
            Column(
              children: [
                _buildDifficultyButton(
                  'Easy',
                  '60s • Slower pace',
                  Colors.green,
                  buttonWidth,
                  () => _startGame('easy'),
                ),
                SizedBox(height: spacing / 2),
                _buildDifficultyButton(
                  'Medium',
                  '90s • Balanced',
                  Colors.orange,
                  buttonWidth,
                  () => _startGame('medium'),
                ),
                SizedBox(height: spacing / 2),
                _buildDifficultyButton(
                  'Hard',
                  '120s • Fast & Intense',
                  Colors.red,
                  buttonWidth,
                  () => _startGame('hard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String desc,
    Color color,
    double width,
    VoidCallback onTap,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final labelFontSize =
        ResponsiveSizing.getFontSize(context, small: 16, medium: 18, large: 20);
    final descFontSize =
        ResponsiveSizing.getFontSize(context, small: 10, medium: 12, large: 14);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: shadowBlur + 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: padding / 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: descFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final buttonHeight = ResponsiveSizing.getButtonHeight(context);
    final titleFontSize =
        ResponsiveSizing.getFontSize(context, small: 24, medium: 32, large: 40);
    final iconSize = ResponsiveSizing.getIconSize(context,
        small: 60, medium: 80, large: 100);

    return SingleChildScrollView(
      padding: padding,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Icon(
              Icons.check_circle,
              size: iconSize,
              color: Colors.green,
            ),
            SizedBox(height: spacing),
            Text(
              'Game Over!',
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing * 2),
            // Stats cards
            _buildStatCard(
              'Final Score',
              score.toString(),
              Colors.amber,
            ),
            SizedBox(height: spacing),
            _buildStatCard(
              'Max Chain',
              maxChain.toString(),
              Colors.green,
            ),
            SizedBox(height: spacing),
            _buildStatCard(
              'Correct Taps',
              correctTaps.toString(),
              Colors.blue,
            ),
            SizedBox(height: spacing),
            _buildStatCard(
              'Accuracy',
              correctTaps > 0
                  ? '${((correctTaps / (correctTaps + missedTaps)) * 100).toStringAsFixed(1)}%'
                  : '0%',
              Colors.purple,
            ),
            SizedBox(height: spacing * 2),
            // Buttons
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                onPressed: _resetGame,
                child: Text(
                  'Play Again',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back to Games',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final padding =
        ResponsiveSizing.getSpacing(context, small: 8, medium: 12, large: 14);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final labelFontSize =
        ResponsiveSizing.getFontSize(context, small: 14, medium: 16, large: 18);
    final valueFontSize =
        ResponsiveSizing.getFontSize(context, small: 18, medium: 24, large: 28);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: ResponsiveSizing.getShadowBlur(context),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for circle elements
class CircleElement {
  final int id;
  final Color color;
  final int sequence;
  final double x; // Percentage of screen width
  final double y; // Percentage of screen height
  final double size;
  final DateTime spawnTime;

  const CircleElement({
    required this.id,
    required this.color,
    required this.sequence,
    required this.x,
    required this.y,
    required this.size,
    required this.spawnTime,
  });
}

/// Background pattern painter
class BackgroundPatternPainter extends CustomPainter {
  const BackgroundPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const gridSize = 40.0;
    for (var i = 0; i < size.width; i += gridSize.toInt()) {
      canvas.drawLine(
          Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (var i = 0; i < size.height; i += gridSize.toInt()) {
      canvas.drawLine(
          Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPatternPainter oldDelegate) => false;
}
