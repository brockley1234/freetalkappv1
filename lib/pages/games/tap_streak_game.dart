import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';
import 'games_list_page.dart';

/// Tap Streak - Fast-paced reflex game where players tap to the beat
class TapStreakGame extends StatefulWidget {
  const TapStreakGame({super.key});

  @override
  State<TapStreakGame> createState() => _TapStreakGameState();
}

class _TapStreakGameState extends State<TapStreakGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _tapController;
  late AnimationController _beatProgressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _beatProgress;

  int score = 0;
  int currentStreak = 0;
  int maxStreak = 0;
  int tapsCounter = 0;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  String message = '';
  bool showMessage = false;
  int timeRemaining = 0;
  Timer? gameTimer;
  int beatInterval = 0; // current, may adapt with streak
  int baseBeatInterval = 0; // from difficulty
  int timeSinceLastBeat = 0;
  Timer? beatTimer;
  bool beatActive = false;
  List<int> reactionTimes = [];
  Color beatColor = Colors.blue;
  bool isPaused = false;
  double comboMultiplier = 1.0;
  int? countdown; // 3..2..1 before game starts
  Timer? countdownTimer;
  DateTime? lastBeatAt;

  // Difficulty settings
  final Map<String, Map<String, dynamic>> difficultySettings = {
    'easy': {
      'duration': 30,
      'beatInterval': 1000, // ms between beats
      'beatWindow': 400, // ms tolerance for tap
      'scorePerBeat': 10,
      'streakBonus': 2,
    },
    'medium': {
      'duration': 45,
      'beatInterval': 800,
      'beatWindow': 300,
      'scorePerBeat': 15,
      'streakBonus': 3,
    },
    'hard': {
      'duration': 60,
      'beatInterval': 500,
      'beatWindow': 200,
      'scorePerBeat': 25,
      'streakBonus': 5,
    },
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _beatProgressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _beatProgress = CurvedAnimation(
      parent: _beatProgressController,
      curve: Curves.linear,
    );
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
    baseBeatInterval = settings['beatInterval'] as int;
    beatInterval = baseBeatInterval;
    timeRemaining = settings['duration'] as int;
    score = 0;
    currentStreak = 0;
    maxStreak = 0;
    tapsCounter = 0;
    gameOver = false;
    message = '';
    showMessage = false;
    reactionTimes = [];
    beatColor = Colors.blue;
    beatActive = false;
    isPaused = false;
    lastBeatAt = null;
    comboMultiplier = 1.0;

    _startBeatTimer();
    _startGameTimer();
    _restartBeatProgress();
  }

  void _startCountdown() {
    // 3-second countdown before initializing the game
    countdownTimer?.cancel();
    setState(() {
      countdown = 3;
      gameOver = false;
      showMessage = false;
      isPaused = false;
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

  void _startBeatTimer() {
    beatTimer?.cancel();
    beatTimer = Timer.periodic(Duration(milliseconds: beatInterval), (timer) {
      if (mounted && !gameOver && !isPaused) {
        _triggerBeat();
      }
    });
  }

  void _restartBeatProgress() {
    _beatProgressController.stop();
    _beatProgressController.duration = Duration(milliseconds: beatInterval);
    if (!isPaused && !gameOver) {
      _beatProgressController.forward(from: 0.0);
    }
  }

  void _updateBeatProgressDuration() {
    final wasAnimating = _beatProgressController.isAnimating;
    _beatProgressController.stop();
    _beatProgressController.duration = Duration(milliseconds: beatInterval);
    if (wasAnimating && !isPaused && !gameOver) {
      _beatProgressController.forward(from: 0.0);
    }
  }

  void _startGameTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || isPaused) return;
      setState(() {
        timeRemaining--;
      });
      if (timeRemaining <= 0) {
        timer.cancel();
        _endGame();
      }
    });
  }

  void _triggerBeat() {
    if (mounted) {
      setState(() {
        beatActive = true;
        beatColor = Colors.cyan;
        timeSinceLastBeat = 0;
        lastBeatAt = DateTime.now();
      });

      _pulseController.forward(from: 0.0);
      _restartBeatProgress();

      // Auto-fail if not tapped in time
      Future.delayed(
          Duration(
              milliseconds:
                  difficultySettings[difficulty]!['beatWindow'] as int), () {
        if (mounted && beatActive && !gameOver) {
          setState(() {
            beatActive = false;
            currentStreak = 0;
            message = '❌ Missed!';
            showMessage = true;
            beatColor = Colors.red;
          });

          if (GameSettings.hapticsEnabled) HapticFeedback.selectionClick();

          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              setState(() {
                beatActive = false;
                beatColor = Colors.blue;
                showMessage = false;
              });
            }
          });
        }
      });
    }
  }

  void _onTap() {
    if (!beatActive || gameOver) {
      if (!gameOver) {
        setState(() {
          // Early tap penalty
          if (score > 0) score = max(0, score - 1);
          currentStreak = 0;
          message = '⏰ Too early! -1 point';
          showMessage = true;
          beatColor = Colors.redAccent;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              showMessage = false;
              beatColor = Colors.blue;
            });
          }
        });
      }
      return;
    }

    // Calculate reaction time and score
    final settings = difficultySettings[difficulty]!;
    final beatWindow = settings['beatWindow'] as int;
    final scorePerBeat = settings['scorePerBeat'] as int;
    final streakBonus = settings['streakBonus'] as int;

    // Compute accurate reaction time since beat
    final now = DateTime.now();
    if (lastBeatAt != null) {
      timeSinceLastBeat = now.difference(lastBeatAt!).inMilliseconds;
    }

    // Perfect tap bonus (within first 100ms)
    bool isPerfect = timeSinceLastBeat < 100;
    bool isGood = timeSinceLastBeat < (beatWindow / 2);

    reactionTimes.add(timeSinceLastBeat);
    tapsCounter++;
    currentStreak++;
    maxStreak = max(maxStreak, currentStreak);

    // Adaptive difficulty: speed up slightly every 5 streaks (cap -150ms)
    final int reductionSteps = (currentStreak ~/ 5);
    final int targetInterval = max(baseBeatInterval - (reductionSteps * 25), baseBeatInterval - 150);
    if (targetInterval != beatInterval) {
      beatInterval = targetInterval;
      _startBeatTimer();
      _updateBeatProgressDuration();
    }

    // Combo multiplier scales every 10 streaks
    comboMultiplier = 1.0 + (currentStreak ~/ 10) * 0.2;

    int earnedPoints = (scorePerBeat * comboMultiplier).round();
    if (isPerfect) {
      earnedPoints = (scorePerBeat + (streakBonus * 2)) * comboMultiplier.round();
      message = '🎯 PERFECT! +$earnedPoints points';
      beatColor = Colors.green;
      if (GameSettings.hapticsEnabled) HapticFeedback.heavyImpact();
    } else if (isGood) {
      earnedPoints = ((scorePerBeat + streakBonus) * comboMultiplier).round();
      message = '✓ Good! +$earnedPoints points (Streak: $currentStreak)';
      beatColor = Colors.lightGreen;
      if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();
    } else {
      earnedPoints = (scorePerBeat * comboMultiplier).round();
      message = '✓ Hit! +$earnedPoints points (Streak: $currentStreak)';
      beatColor = Colors.amber;
      if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
    }

    setState(() {
      score += earnedPoints;
      beatActive = false;
      showMessage = true;
    });

    _tapController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          showMessage = false;
          beatColor = Colors.blue;
        });
      }
    });
  }

  void _togglePause() {
    if (gameOver || showDifficultyMenu || countdown != null) return;
    setState(() {
      isPaused = !isPaused;
    });
    if (isPaused) {
      beatTimer?.cancel();
      gameTimer?.cancel();
      beatActive = false;
      _beatProgressController.stop();
    } else {
      // resume timers
      _startBeatTimer();
      _startGameTimer();
      _restartBeatProgress();
    }
  }

  void _endGame() {
    beatTimer?.cancel();
    gameTimer?.cancel();

    if (mounted) {
      setState(() {
        gameOver = true;
      });
      _submitScore();
    }
  }

  Future<void> _submitScore() async {
    try {
      final avgReactionTime = reactionTimes.isEmpty
          ? 0
          : (reactionTimes.reduce((a, b) => a + b) / reactionTimes.length)
              .toInt();

      final statistics = {
        'totalTaps': tapsCounter,
        'maxStreak': maxStreak,
        'avgReactionTime': avgReactionTime,
        'bestReactionTime':
            reactionTimes.isEmpty ? 0 : reactionTimes.reduce(min),
      };

      await GameService.submitScore(
        'tap-streak',
        score,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit tap streak score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      _initializeGame();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    _beatProgressController.dispose();
    beatTimer?.cancel();
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tap Streak'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            beatTimer?.cancel();
            gameTimer?.cancel();
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
                                  backgroundColor: Colors.cyan,
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
                      '⚡ Tap Streak ⚡',
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
                      'Tap to the beat. Build your streak. 🔥',
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
              _buildDifficultyButtonTap(
                'Easy',
                '30s • Slower beats',
                Colors.green,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonTap(
                'Medium',
                '45s • Moderate speed',
                Colors.orange,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonTap(
                'Hard',
                '60s • Ultra fast!',
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
                      '1. Watch for the blue circle to light up cyan\n2. Tap it as quickly as possible\n3. Perfect taps = 2x bonus!\n4. Build your streak to earn more points',
                      style: TextStyle(
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 11, medium: 12, large: 13, xlarge: 13),
                        color: Colors.grey.shade700,
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

  Widget _buildDifficultyButtonTap(
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
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 15, medium: 16, large: 18, xlarge: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
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
                _buildStatCard('Score', score.toString(), Colors.cyan),
                _buildStatCard(
                    'Streak', currentStreak.toString(), Colors.orange),
                _buildStatCard('Time', '${timeRemaining}s',
                    timeRemaining <= 10 ? Colors.red : Colors.purple),
              ],
            ),
            SizedBox(height: spacing * 1.5),

            // Game Message
            if (showMessage)
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 10, medium: 12, large: 14)),
                decoration: BoxDecoration(
                  color: message.contains('PERFECT')
                      ? Colors.green.shade100
                      : message.contains('Good')
                          ? Colors.lightGreen.shade100
                          : message.contains('Missed')
                              ? Colors.red.shade100
                              : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context)),
                  border: Border.all(
                    color: message.contains('PERFECT')
                        ? Colors.green
                        : message.contains('Good')
                            ? Colors.lightGreen
                            : message.contains('Missed')
                                ? Colors.red
                                : Colors.amber,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: message.contains('PERFECT')
                        ? Colors.green
                        : message.contains('Good')
                            ? Colors.lightGreen.shade800
                            : message.contains('Missed')
                                ? Colors.red
                                : Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(height: spacing * 2),
            SizedBox(height: spacing),

            // Main Tap Button
            GestureDetector(
              onTap: _onTap,
              child: ScaleTransition(
                scale: _tapController.drive(Tween<double>(begin: 1, end: 0.95)),
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: AnimatedBuilder(
                          animation: _beatProgress,
                          builder: (context, _) {
                            return CircularProgressIndicator(
                              value: beatActive ? _beatProgress.value : 0,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                beatActive ? Colors.cyan : Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: beatColor,
                      gradient: LinearGradient(
                        colors: [beatColor, beatColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: beatColor.withValues(alpha: 0.5),
                          blurRadius: beatActive ? 30 : 15,
                          spreadRadius: beatActive ? 5 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: Colors.white,
                            size: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            beatActive ? 'TAP!' : 'WAIT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'x${comboMultiplier.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
                ),
              ),
            ),
            SizedBox(height: spacing * 2),

            // Info
            Container(
              padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                  small: 12, medium: 14, large: 16)),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(
                    ResponsiveSizing.getBorderRadius(context)),
              ),
              child: Column(
                children: [
                  Text(
                    'Max Streak: $maxStreak | Taps: $tapsCounter',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 14, large: 16, xlarge: 16),
                    ),
                  ),
                  if (reactionTimes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Avg Reaction: ${(reactionTimes.reduce((a, b) => a + b) / reactionTimes.length).toStringAsFixed(0)}ms',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 10, medium: 11, large: 12, xlarge: 12),
                      ),
                    ),
                  ],
                ],
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

    final avgReactionTime = reactionTimes.isEmpty
        ? 0
        : (reactionTimes.reduce((a, b) => a + b) / reactionTimes.length)
            .toInt();
    final bestReactionTime =
        reactionTimes.isEmpty ? 0 : reactionTimes.reduce(min);

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
                color: Colors.cyan.shade100,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.cyan, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 Game Over! 🎉',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 20, medium: 24, large: 28, xlarge: 32),
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade700,
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
                      color: Colors.cyan.shade700,
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
                _buildStatBox('Max Streak', '$maxStreak', Colors.orange),
                _buildStatBox('Total Taps', '$tapsCounter', Colors.purple),
                _buildStatBox(
                    'Avg Reaction', '${avgReactionTime}ms', Colors.green),
                _buildStatBox(
                    'Best Reaction', '${bestReactionTime}ms', Colors.red),
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
                  backgroundColor: Colors.cyan.shade600,
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
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
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
              color: Colors.grey.shade700,
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
