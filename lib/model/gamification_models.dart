import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final Timestamp? unlockedAt;
  final int points;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.points,
  });

  factory Achievement.fromMap(String id, Map<String, dynamic> map) {
    return Achievement(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: _getIconFromString(map['icon'] ?? 'star'),
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedAt: map['unlockedAt'],
      points: map['points'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'icon': icon.codePoint.toString(),
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt,
      'points': points,
    };
  }

  static IconData _getIconFromString(String iconString) {
    switch (iconString) {
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'thumb_up':
        return Icons.thumb_up;
      case 'music_note':
        return Icons.music_note;
      case 'video_library':
        return Icons.video_library;
      case 'photo':
        return Icons.photo;
      case 'trending_up':
        return Icons.trending_up;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final int points;
  final int rank;
  final String? profileImage;
  final int dailyStreak;
  final String? currentBadgeTitle;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.points,
    required this.rank,
    this.profileImage,
    required this.dailyStreak,
    this.currentBadgeTitle,
  });

  factory LeaderboardEntry.fromMap(String id, Map<String, dynamic> map, int rank) {
    return LeaderboardEntry(
      userId: id,
      name: map['name'] ?? 'Unknown User',
      points: map['totalPoints'] ?? 0,
      rank: rank,
      profileImage: map['profileImage'],
      dailyStreak: map['dailyStreak'] ?? 0,
      currentBadgeTitle: map['currentBadgeTitle'],
    );
  }

  factory LeaderboardEntry.fromCache(Map<String, dynamic> map) {
  return LeaderboardEntry(
    userId: map['userId'] ?? '',
    name: map['name'] ?? 'Unknown User',
    points: map['totalPoints'] ?? 0,
    rank: map['rank'] ?? 0,
    profileImage: map['profileImage'],
    dailyStreak: map['dailyStreak'] ?? 0,
    currentBadgeTitle: map['currentBadgeTitle'],
  );
}

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalPoints': points,
      'profileImage': profileImage,
      'dailyStreak': dailyStreak,
      'currentBadgeTitle': currentBadgeTitle,
    };
  }
}

class UserRewards {
  final String userId;
  final int dailyStreak;
  final int totalPoints;
  final int level;
  final DateTime lastLogin;
  final List<String> unlockedAchievements;

  UserRewards({
    required this.userId,
    required this.dailyStreak,
    required this.totalPoints,
    required this.level,
    required this.lastLogin,
    required this.unlockedAchievements,
  });

  factory UserRewards.fromMap(String id, Map<String, dynamic> map) {
    return UserRewards(
      userId: id,
      dailyStreak: map['dailyStreak'] ?? 0,
      totalPoints: map['totalPoints'] ?? 0,
      level: map['level'] ?? 1,
      lastLogin: (map['lastLogin'] as Timestamp).toDate(),
      unlockedAchievements: List<String>.from(map['unlockedAchievements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyStreak': dailyStreak,
      'totalPoints': totalPoints,
      'level': level,
      'lastLogin': Timestamp.fromDate(lastLogin),
      'unlockedAchievements': unlockedAchievements,
    };
  }
}
