import 'package:flutter/material.dart';
import '../models/streak_model.dart';
import '../utils/url_utils.dart';

/// Display a streak indicator for a conversation
/// Shows the streak count and burn emoji if the streak is active
class StreakIndicator extends StatelessWidget {
  final Streak streak;
  final double? iconSize;
  final bool showLabel;
  final TextStyle? labelStyle;

  const StreakIndicator({
    super.key,
    required this.streak,
    this.iconSize = 20,
    this.showLabel = true,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (streak.streakCount == 0) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: streak.streakMessage,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (streak.isActive)
            Text(
              streak.streakEmoji,
              style: TextStyle(fontSize: iconSize),
            ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              streak.streakCount.toString(),
              style: labelStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: streak.isActive ? Colors.orange : Colors.grey,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detailed streak card widget showing full streak information
class StreakCard extends StatelessWidget {
  final Streak streak;
  final VoidCallback? onTap;
  final bool showActions;

  const StreakCard({
    super.key,
    required this.streak,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user and streak count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // User avatar
                        if (streak.otherUser.avatar != null)
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: UrlUtils.getAvatarImageProvider(
                                streak.otherUser.avatar),
                          )
                        else
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              streak.otherUser.name
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      streak.otherUser.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                streak.streakMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak count with emoji
                  Column(
                    children: [
                      Text(
                        streak.streakEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      Text(
                        streak.streakCount.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Streak stats
              if (streak.longestStreak > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Longest Streak: ${streak.longestStreak}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (streak.isAtRisk)
                        Tooltip(
                          message: 'Send a message to keep your streak alive!',
                          child: Text(
                            '⚠️ At Risk',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[600],
                              fontWeight: FontWeight.w600,
                            ),
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
}

/// Expanded column-style streak card for detailed view
class StreakCardColumn extends StatelessWidget {
  final Streak streak;
  final VoidCallback? onTap;

  const StreakCardColumn({
    super.key,
    required this.streak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large emoji and streak count
              Text(
                streak.streakEmoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                streak.streakCount.toString(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                streak.streakMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // User info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (streak.otherUser.avatar != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: UrlUtils.getAvatarImageProvider(
                          streak.otherUser.avatar),
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        streak.otherUser.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            streak.otherUser.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Longest: ${streak.longestStreak}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status indicator
              if (streak.isAtRisk)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Send a message to keep streak alive!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Streak is active!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w600,
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
}

/// Streak progress indicator showing days remaining in current streak
class StreakProgressBar extends StatelessWidget {
  final StreakStatus streakStatus;
  final double height;
  final Color activeColor;
  final Color inactiveColor;

  const StreakProgressBar({
    super.key,
    required this.streakStatus,
    this.height = 8,
    this.activeColor = Colors.orange,
    this.inactiveColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (23 - (streakStatus.daysSinceUser1Message.clamp(0, 24))) / 24;

    return Tooltip(
      message: streakStatus.riskMessage ?? 'Streak is active',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: inactiveColor.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            streakStatus.willBreakToday ? Colors.red : activeColor,
          ),
        ),
      ),
    );
  }
}

/// Leaderboard entry widget
class LeaderboardStreakTile extends StatelessWidget {
  final StreakLeaderboardEntry entry;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const LeaderboardStreakTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.orange[50] : null,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
            ),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 40,
              child: Text(
                '${entry.rank}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getRankColor(entry.rank),
                ),
              ),
            ),
            // Users info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.user1.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '❤️',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.user2.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Longest: ${entry.longestStreak}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Streak count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.streakCount}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Text(
                  '🔥',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[400]!;
    if (rank == 3) return Colors.brown[300]!;
    return Colors.grey[600]!;
  }
}

/// Empty state widget for when there are no streaks
class NoStreaksPlaceholder extends StatelessWidget {
  final String? message;
  final VoidCallback? onStartMessaging;

  const NoStreaksPlaceholder({
    super.key,
    this.message,
    this.onStartMessaging,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '💬',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No streaks yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start messaging your friends daily to build streaks!',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
          if (onStartMessaging != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onStartMessaging,
              child: const Text('Start Messaging'),
            ),
          ],
        ],
      ),
    );
  }
}
