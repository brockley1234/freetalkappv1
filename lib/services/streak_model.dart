/// Model classes for Streak functionality

library streak_model;

class Streak {
  final String id;
  final String userId1;
  final String userId2;
  final int streakCount;
  final DateTime lastMessageDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Streak({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.streakCount,
    required this.lastMessageDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      id: json['_id'] ?? json['id'] ?? '',
      userId1: json['userId1'] ?? '',
      userId2: json['userId2'] ?? '',
      streakCount: json['streakCount'] ?? 0,
      lastMessageDate: json['lastMessageDate'] != null
          ? DateTime.parse(json['lastMessageDate'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId1': userId1,
      'userId2': userId2,
      'streakCount': streakCount,
      'lastMessageDate': lastMessageDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class StreakStatus {
  final String id;
  final String userId1;
  final String userId2;
  final int streakCount;
  final DateTime lastMessageDate;
  final bool isActive;
  final int daysRemaining;

  StreakStatus({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.streakCount,
    required this.lastMessageDate,
    required this.isActive,
    required this.daysRemaining,
  });

  factory StreakStatus.fromJson(Map<String, dynamic> json) {
    return StreakStatus(
      id: json['_id'] ?? json['id'] ?? '',
      userId1: json['userId1'] ?? '',
      userId2: json['userId2'] ?? '',
      streakCount: json['streakCount'] ?? 0,
      lastMessageDate: json['lastMessageDate'] != null
          ? DateTime.parse(json['lastMessageDate'] as String)
          : DateTime.now(),
      isActive: json['isActive'] ?? false,
      daysRemaining: json['daysRemaining'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId1': userId1,
      'userId2': userId2,
      'streakCount': streakCount,
      'lastMessageDate': lastMessageDate.toIso8601String(),
      'isActive': isActive,
      'daysRemaining': daysRemaining,
    };
  }
}

class StreakLeaderboardEntry {
  final String userId;
  final String username;
  final String userAvatar;
  final int longestStreak;
  final int totalStreaks;
  final int rank;

  StreakLeaderboardEntry({
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.longestStreak,
    required this.totalStreaks,
    required this.rank,
  });

  factory StreakLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return StreakLeaderboardEntry(
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Unknown',
      userAvatar: json['userAvatar'] ?? '',
      longestStreak: json['longestStreak'] ?? 0,
      totalStreaks: json['totalStreaks'] ?? 0,
      rank: json['rank'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'longestStreak': longestStreak,
      'totalStreaks': totalStreaks,
      'rank': rank,
    };
  }
}

class UserStreakStats {
  final String userId;
  final int rank;
  final int longestStreak;
  final int totalStreaks;
  final double averageStreakLength;
  final int totalParticipants;

  UserStreakStats({
    required this.userId,
    required this.rank,
    required this.longestStreak,
    required this.totalStreaks,
    required this.averageStreakLength,
    required this.totalParticipants,
  });

  factory UserStreakStats.fromJson(Map<String, dynamic> json) {
    return UserStreakStats(
      userId: json['userId'] ?? '',
      rank: json['rank'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      totalStreaks: json['totalStreaks'] ?? 0,
      averageStreakLength: (json['averageStreakLength'] ?? 0).toDouble(),
      totalParticipants: json['totalParticipants'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'rank': rank,
      'longestStreak': longestStreak,
      'totalStreaks': totalStreaks,
      'averageStreakLength': averageStreakLength,
      'totalParticipants': totalParticipants,
    };
  }
}
