import 'package:flutter/material.dart' hide Badge;
import '../models/badge_model.dart' as badge_model;

/// Display a single badge
class BadgeWidget extends StatelessWidget {
  final badge_model.Badge badge;
  final VoidCallback? onTap;
  final bool showDescription;
  final double size;

  const BadgeWidget({
    super.key,
    required this.badge,
    this.onTap,
    this.showDescription = true,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: badge.colorValue.withValues(alpha: 0.1),
              border: Border.all(
                color: badge.colorValue,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background gradient based on rarity
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        badge.colorValue.withValues(alpha: 0.05),
                        badge.colorValue.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Emoji
                Text(
                  badge.emoji,
                  style: TextStyle(fontSize: size * 0.5),
                ),
              ],
            ),
          ),
          if (showDescription) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: size + 20,
              child: Column(
                children: [
                  const Text(
                    'badge.title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badge.colorValue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge.rarity,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badge.colorValue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge detail card
class BadgeDetailCard extends StatelessWidget {
  final badge_model.Badge badge;
  final VoidCallback? onHide;

  const BadgeDetailCard({
    super.key,
    required this.badge,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large emoji
            Text(
              badge.emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              badge.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badge.colorValue.withValues(alpha: 0.2),
                border: Border.all(color: badge.colorValue),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.rarity,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badge.colorValue,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Earned date
            Text(
              'Earned: ${badge.earnedDateFormatted}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),

            // Hide button
            if (onHide != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onHide,
                  icon: const Icon(Icons.visibility_off),
                  label: const Text('Hide Badge'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Badge collection view
class BadgeCollection extends StatelessWidget {
  final List<badge_model.Badge> badges;
  final VoidCallback? onBadgeTap;
  final int crossAxisCount;
  final bool showEmpty;

  const BadgeCollection({
    super.key,
    required this.badges,
    this.onBadgeTap,
    this.crossAxisCount = 3,
    this.showEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty && showEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🎖️',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'No badges yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reach streak milestones to earn badges!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return BadgeWidget(
          badge: badges[index],
          onTap: onBadgeTap,
          showDescription: false,
        );
      },
    );
  }
}

/// Badge stats summary
class BadgeStats extends StatelessWidget {
  final badge_model.BadgeStats stats;
  final VoidCallback? onViewAll;

  const BadgeStats({
    super.key,
    required this.stats,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _StatBox(
                  label: 'Total',
                  value: stats.totalBadges.toString(),
                  icon: '🏅',
                ),
                _StatBox(
                  label: 'Legendary',
                  value: stats.rarityBreakdown['LEGENDARY']?.toString() ?? '0',
                  icon: '👑',
                ),
                _StatBox(
                  label: 'Epic',
                  value: stats.rarityBreakdown['EPIC']?.toString() ?? '0',
                  icon: '⭐',
                ),
                _StatBox(
                  label: 'Rare',
                  value: stats.rarityBreakdown['RARE']?.toString() ?? '0',
                  icon: '💎',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Badge display
            if (stats.badges.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Recent Badges',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: stats.badges.take(5).length,
                  itemBuilder: (context, index) {
                    final badge = stats.badges[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: BadgeWidget(
                        badge: badge,
                        showDescription: false,
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge leaderboard entry
class BadgeLeaderboardTile extends StatelessWidget {
  final badge_model.BadgeLeaderboardEntry entry;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const BadgeLeaderboardTile({
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
          color: isHighlighted ? Colors.amber[50] : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
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
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.userName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${entry.totalBadges} badges (${entry.legendaryBadges} 👑)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Rarity score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.rarityScore}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(fontSize: 9),
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
