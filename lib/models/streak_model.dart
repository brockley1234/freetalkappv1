/// Dart model for user streaks system
/// Represents a streak between two users messaging each other daily

library streak_model;

class Streak {
  final String id;
  final StreakUser otherUser;
  final int streakCount;
  final int longestStreak;
  final bool isActive;
  final DateTime lastActiveDate;
  final DateTime createdAt;

  Streak({
    required this.id,
    required this.otherUser,
    required this.streakCount,
    required this.longestStreak,
    required this.isActive,
    required this.lastActiveDate,
    required this.createdAt,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      otherUser: StreakUser.fromJson(
        json['otherUser'] as Map<String, dynamic>? ?? {},
      ),
      streakCount: json['streakCount'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String).toLocal()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'otherUser': otherUser.toJson(),
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'isActive': isActive,
      'lastActiveDate': lastActiveDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Streak(id: $id, user: ${otherUser.name}, count: $streakCount, active: $isActive)';

  /// Get the number of days since last message
  int? get daysSinceLastActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastActiveDate.year,
      lastActiveDate.month,
      lastActiveDate.day,
    );
    return today.difference(lastDay).inDays;
  }

  /// Check if streak is at risk (hasn't messaged today)
  bool get isAtRisk {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastActiveDate.year,
      lastActiveDate.month,
      lastActiveDate.day,
    );
    final daysDiff = today.difference(lastDay).inDays;
    return isActive && daysDiff > 0;
  }

  /// Get user-friendly streak message
  String get streakMessage {
    if (streakCount >= 365) {
      return '${(streakCount / 365).toStringAsFixed(1)} year streak! 🔥';
    } else if (streakCount >= 100) {
      return '100+ day streak! 🔥';
    } else if (streakCount >= 30) {
      return '$streakCount day streak! 🔥';
    } else if (streakCount >= 7) {
      return '$streakCount day streak! 🔥';
    } else if (streakCount >= 1) {
      return '$streakCount day streak';
    }
    return 'Start a streak';
  }

  /// Get emoji representation based on streak count
  String get streakEmoji {
    if (streakCount >= 365) return '🔥🔥🔥';
    if (streakCount >= 100) return '🔥🔥';
    if (streakCount >= 30) return '🔥';
    if (streakCount >= 7) return '✨';
    if (streakCount >= 1) return '⭐';
    return '💬';
  }
}

class StreakUser {
  final String id;
  final String name;
  final String? avatar;
  final bool isVerified;

  StreakUser({
    required this.id,
    required this.name,
    this.avatar,
    required this.isVerified,
  });

  factory StreakUser.fromJson(Map<String, dynamic> json) {
    return StreakUser(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown User',
      avatar: json['avatar'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'avatar': avatar,
      'isVerified': isVerified,
    };
  }

  @override
  String toString() =>
      'StreakUser(id: $id, name: $name, verified: $isVerified)';
}

class StreakStatus {
  final int streakCount;
  final int longestStreak;
  final bool isActive;
  final int daysSinceUser1Message;
  final int daysSinceUser2Message;
  final DateTime lastActiveDate;
  final bool willBreakToday;

  StreakStatus({
    required this.streakCount,
    required this.longestStreak,
    required this.isActive,
    required this.daysSinceUser1Message,
    required this.daysSinceUser2Message,
    required this.lastActiveDate,
    required this.willBreakToday,
  });

  factory StreakStatus.fromJson(Map<String, dynamic> json) {
    return StreakStatus(
      streakCount: json['streakCount'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      daysSinceUser1Message: json['daysSinceUser1Message'] as int? ?? 0,
      daysSinceUser2Message: json['daysSinceUser2Message'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String).toLocal()
          : DateTime.now(),
      willBreakToday: json['willBreakToday'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'isActive': isActive,
      'daysSinceUser1Message': daysSinceUser1Message,
      'daysSinceUser2Message': daysSinceUser2Message,
      'lastActiveDate': lastActiveDate.toIso8601String(),
      'willBreakToday': willBreakToday,
    };
  }

  /// Get warning message if streak is at risk
  String? get riskMessage {
    if (!isActive || !willBreakToday) return null;
    if (daysSinceUser1Message > 0 &&
        daysSinceUser1Message == daysSinceUser2Message) {
      return 'Send a message to keep your streak alive! 🔥';
    }
    return null;
  }

  @override
  String toString() =>
      'StreakStatus(count: $streakCount, active: $isActive, willBreak: $willBreakToday)';
}

class StreakLeaderboardEntry {
  final int rank;
  final StreakUser user1;
  final StreakUser user2;
  final int streakCount;
  final int longestStreak;
  final DateTime lastActiveDate;

  StreakLeaderboardEntry({
    required this.rank,
    required this.user1,
    required this.user2,
    required this.streakCount,
    required this.longestStreak,
    required this.lastActiveDate,
  });

  factory StreakLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return StreakLeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      user1: StreakUser.fromJson(
        json['user1'] as Map<String, dynamic>? ?? {},
      ),
      user2: StreakUser.fromJson(
        json['user2'] as Map<String, dynamic>? ?? {},
      ),
      streakCount: json['streakCount'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user1': user1.toJson(),
      'user2': user2.toJson(),
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'StreakLeaderboardEntry(rank: $rank, streak: $streakCount)';
}

class UserStreakStats {
  final int rank;
  final int longestStreak;
  final int activeStreaks;
  final List<StreakSummary> topStreaks;
  final String? message;

  UserStreakStats({
    required this.rank,
    required this.longestStreak,
    required this.activeStreaks,
    required this.topStreaks,
    this.message,
  });

  factory UserStreakStats.fromJson(Map<String, dynamic> json) {
    final topStreaksJson = json['topStreaks'] as List<dynamic>? ?? [];
    final topStreaks = topStreaksJson
        .map((streak) => StreakSummary.fromJson(streak as Map<String, dynamic>))
        .toList();

    return UserStreakStats(
      rank: json['rank'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      activeStreaks: json['activeStreaks'] as int? ?? 0,
      topStreaks: topStreaks,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'longestStreak': longestStreak,
      'activeStreaks': activeStreaks,
      'topStreaks': topStreaks.map((s) => s.toJson()).toList(),
      'message': message,
    };
  }

  @override
  String toString() =>
      'UserStreakStats(rank: $rank, longest: $longestStreak, active: $activeStreaks)';
}

class StreakSummary {
  final int streakCount;
  final int longestStreak;
  final DateTime lastActiveDate;

  StreakSummary({
    required this.streakCount,
    required this.longestStreak,
    required this.lastActiveDate,
  });

  factory StreakSummary.fromJson(Map<String, dynamic> json) {
    return StreakSummary(
      streakCount: json['streakCount'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'StreakSummary(count: $streakCount, longest: $longestStreak)';
}
