/// Badge model for user achievements and milestones

library badge_model;

import 'package:flutter/material.dart';

class Badge {
  final String id;
  final String badgeType;
  final String title;
  final String description;
  final String emoji;
  final String color;
  final String rarity;
  final DateTime earnedAt;
  final bool isVisible;
  final BadgeMetadata? metadata;

  Badge({
    required this.id,
    required this.badgeType,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.rarity,
    required this.earnedAt,
    required this.isVisible,
    this.metadata,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      badgeType: json['badgeType'] as String? ?? 'UNKNOWN',
      title: json['display']?['title'] as String? ??
          json['title'] as String? ??
          'Unknown Badge',
      description: json['display']?['description'] as String? ??
          json['description'] as String? ??
          '',
      emoji: json['display']?['emoji'] as String? ??
          json['emoji'] as String? ??
          '🎖️',
      color: json['display']?['color'] as String? ??
          json['color'] as String? ??
          '#999999',
      rarity: json['display']?['rarity'] as String? ??
          json['rarity'] as String? ??
          'COMMON',
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'] as String).toLocal()
          : DateTime.now(),
      isVisible: json['isVisible'] as bool? ?? true,
      metadata: json['metadata'] != null
          ? BadgeMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'badgeType': badgeType,
      'title': title,
      'description': description,
      'emoji': emoji,
      'color': color,
      'rarity': rarity,
      'earnedAt': earnedAt.toIso8601String(),
      'isVisible': isVisible,
      'metadata': metadata?.toJson(),
    };
  }

  /// Get color as Color object
  Color get colorValue {
    try {
      return Color(int.parse('0xFF${color.replaceFirst('#', '')}'));
    } catch (e) {
      return const Color(0xFF999999);
    }
  }

  /// Get rarity level (for sorting/filtering)
  int get rarityLevel {
    switch (rarity) {
      case 'LEGENDARY':
        return 4;
      case 'EPIC':
        return 3;
      case 'RARE':
        return 2;
      case 'COMMON':
      default:
        return 1;
    }
  }

  /// Get earned date formatted (e.g., "Oct 22, 2025")
  String get earnedDateFormatted {
    return '${_monthName(earnedAt.month)} ${earnedAt.day}, ${earnedAt.year}';
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  @override
  String toString() => 'Badge($badgeType, $rarity)';
}

class BadgeMetadata {
  final String? streakId;
  final int? streakCount;
  final String? otherUserId;
  final int? totalStreaks;
  final int? totalMessages;
  final int? totalBadges;

  BadgeMetadata({
    this.streakId,
    this.streakCount,
    this.otherUserId,
    this.totalStreaks,
    this.totalMessages,
    this.totalBadges,
  });

  factory BadgeMetadata.fromJson(Map<String, dynamic> json) {
    return BadgeMetadata(
      streakId: json['streakId'] as String?,
      streakCount: json['streakCount'] as int?,
      otherUserId: json['otherUserId'] as String?,
      totalStreaks: json['totalStreaks'] as int?,
      totalMessages: json['totalMessages'] as int?,
      totalBadges: json['totalBadges'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakId': streakId,
      'streakCount': streakCount,
      'otherUserId': otherUserId,
      'totalStreaks': totalStreaks,
      'totalMessages': totalMessages,
      'totalBadges': totalBadges,
    };
  }
}

class BadgeStats {
  final int totalBadges;
  final int visibleBadges;
  final List<BadgeType> badgesByType;
  final Map<String, int> rarityBreakdown;
  final List<Badge> badges;

  BadgeStats({
    required this.totalBadges,
    required this.visibleBadges,
    required this.badgesByType,
    required this.rarityBreakdown,
    required this.badges,
  });

  factory BadgeStats.fromJson(Map<String, dynamic> json) {
    final badgesJson = json['badges'] as List<dynamic>? ?? [];
    final badges = badgesJson
        .map((b) => Badge.fromJson(b as Map<String, dynamic>))
        .toList();

    final badgesByTypeJson = json['badgesByType'] as List<dynamic>? ?? [];
    final badgesByType = badgesByTypeJson
        .map((b) => BadgeType.fromJson(b as Map<String, dynamic>))
        .toList();

    final rarityBreakdownJson =
        json['rarityBreakdown'] as Map<String, dynamic>? ?? {};
    final rarityBreakdown = rarityBreakdownJson.cast<String, int>();

    return BadgeStats(
      totalBadges: json['totalBadges'] as int? ?? 0,
      visibleBadges: json['visibleBadges'] as int? ?? 0,
      badgesByType: badgesByType,
      rarityBreakdown: rarityBreakdown,
      badges: badges,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBadges': totalBadges,
      'visibleBadges': visibleBadges,
      'badgesByType': badgesByType.map((b) => b.toJson()).toList(),
      'rarityBreakdown': rarityBreakdown,
      'badges': badges.map((b) => b.toJson()).toList(),
    };
  }

  /// Get legend tier (sum of all rarity levels)
  int get legendTier {
    int tier = 0;
    for (final badge in badges) {
      tier += badge.rarityLevel;
    }
    return tier;
  }

  @override
  String toString() =>
      'BadgeStats(total: $totalBadges, visible: $visibleBadges)';
}

class BadgeType {
  final String id;
  final int count;

  BadgeType({required this.id, required this.count});

  factory BadgeType.fromJson(Map<String, dynamic> json) {
    return BadgeType(
      id: json['_id'] as String? ?? 'UNKNOWN',
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'count': count};
  }
}

class BadgeLeaderboardEntry {
  final int rank;
  final String userId;
  final String userName;
  final int totalBadges;
  final int legendaryBadges;
  final int epicBadges;
  final int rarityScore;

  BadgeLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.totalBadges,
    required this.legendaryBadges,
    required this.epicBadges,
    required this.rarityScore,
  });

  factory BadgeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return BadgeLeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      totalBadges: json['totalBadges'] as int? ?? 0,
      legendaryBadges: json['legendaryBadges'] as int? ?? 0,
      epicBadges: json['epicBadges'] as int? ?? 0,
      rarityScore: json['raretyScore'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'userId': userId,
      'userName': userName,
      'totalBadges': totalBadges,
      'legendaryBadges': legendaryBadges,
      'epicBadges': epicBadges,
      'raretyScore': rarityScore,
    };
  }

  @override
  String toString() => 'BadgeLeaderboardEntry(rank: $rank, user: $userName)';
}
