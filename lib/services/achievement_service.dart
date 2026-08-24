import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/gamification_models.dart';

class AchievementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Badge thresholds based on total points
  static String _badgeForPoints(int points) {
    if (points >= 500) return 'Month Master';
    if (points >= 300) return 'Popular';
    if (points >= 250) return 'Rising Star';
    if (points >= 200) return 'Content Creator';
    if (points >= 150) return 'Week Warrior';
    if (points >= 100) return 'Musician';
    if (points >= 75) return 'Video Creator';
    if (points >= 50) return 'First Post';
    return 'Influencer'; // fallback or for followers-based achievement
  }

  // Predefined achievements
  static final List<Achievement> defaultAchievements = [
    Achievement(
      id: 'first_post',
      title: 'First Post',
      description: 'Share your first post with the community',
      icon: Icons.photo,
      isUnlocked: false,
      points: 50,
    ),
    Achievement(
      id: 'first_video',
      title: 'Video Creator',
      description: 'Upload your first video',
      icon: Icons.video_library,
      isUnlocked: false,
      points: 75,
    ),
    Achievement(
      id: 'first_song',
      title: 'Musician',
      description: 'Share your first song',
      icon: Icons.music_note,
      isUnlocked: false,
      points: 100,
    ),
    Achievement(
      id: 'first_like',
      title: 'Liked!',
      description: 'Receive your first like',
      icon: Icons.thumb_up,
      isUnlocked: false,
      points: 25,
    ),
    Achievement(
      id: 'ten_posts',
      title: 'Content Creator',
      description: 'Post 10 times',
      icon: Icons.trending_up,
      isUnlocked: false,
      points: 200,
    ),
    Achievement(
      id: 'hundred_likes',
      title: 'Popular',
      description: 'Receive 100 total likes',
      icon: Icons.favorite,
      isUnlocked: false,
      points: 300,
    ),
    Achievement(
      id: 'week_streak',
      title: 'Week Warrior',
      description: 'Login for 7 consecutive days',
      icon: Icons.local_fire_department,
      isUnlocked: false,
      points: 150,
    ),
    Achievement(
      id: 'month_streak',
      title: 'Month Master',
      description: 'Login for 30 consecutive days',
      icon: Icons.workspace_premium,
      isUnlocked: false,
      points: 500,
    ),
    Achievement(
      id: 'first_follower',
      title: 'Influencer',
      description: 'Get your first follower',
      icon: Icons.person_add,
      isUnlocked: false,
      points: 100,
    ),
    Achievement(
      id: 'ten_followers',
      title: 'Rising Star',
      description: 'Reach 10 followers',
      icon: Icons.star,
      isUnlocked: false,
      points: 250,
    ),
  ];

  /// Initialize achievements for a new user
  static Future<void> initializeUserAchievements(String userId) async {
    try {
      print('Initializing achievements for user $userId');
      final userAchievementsRef = _firestore
          .collection('userAchievements')
          .doc(userId)
          .collection('achievements');

      // Check if achievements already exist
      final existingAchievements = await userAchievementsRef.get();
      print('Existing achievements count: ${existingAchievements.docs.length}');
      if (existingAchievements.docs.isNotEmpty) {
        print('Achievements already exist, skipping initialization');
        return;
      }

      // Create default achievements
      print('Creating default achievements');
      final batch = _firestore.batch();
      for (final achievement in defaultAchievements) {
        final docRef = userAchievementsRef.doc(achievement.id);
        batch.set(docRef, achievement.toMap());
        print('Adding achievement: ${achievement.title}');
      }
      await batch.commit();
      print('Achievements initialized successfully');
    } catch (e) {
      print('Error initializing achievements: $e');
    }
  }

  /// Check and unlock achievements based on user actions
  static Future<void> checkAndUnlockAchievements(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user data
      final userData = await _firestore
          .collection('usersData')
          .doc(userId)
          .get();
      if (!userData.exists) return;

      final userDataMap = userData.data()!;
      print('User data keys: ${userDataMap.keys.toList()}');
      print('User data followers field: ${userDataMap['followers']}');

      // Get user's posts count
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      final postsCount = postsQuery.docs.length.toInt();
      print('Found $postsCount posts for user');
      if (postsQuery.docs.isNotEmpty) {
        final firstPost = postsQuery.docs.first.data();
        print('First post keys: ${firstPost.keys.toList()}');
        print('First post likes field: ${firstPost['likes']}');
      }

      // Get user's videos count
      final videosQuery = await _firestore
          .collection('reels')
          .where('userId', isEqualTo: userId)
          .get();
      final videosCount = videosQuery.docs.length.toInt();
      print('Found $videosCount videos for user');
      if (videosQuery.docs.isNotEmpty) {
        final firstVideo = videosQuery.docs.first.data();
        print('First video keys: ${firstVideo.keys.toList()}');
        print('First video likes field: ${firstVideo['likes']}');
      }

      // Get user's songs count
      final songsQuery = await _firestore
          .collection('songs')
          .where('userId', isEqualTo: userId)
          .get();
      final songsCount = songsQuery.docs.length.toInt();
      print('Found $songsCount songs for user');

      // Get total likes received
      int totalLikes = 0;
      print('Checking posts for likes...');
      for (final post in postsQuery.docs) {
        final postData = post.data();
        final likesData = postData['likes'];
        print(
          'Post likes data type: ${likesData.runtimeType}, value: $likesData',
        );
        if (likesData != null && likesData is List) {
          totalLikes += likesData.length;
        }
      }
      print('Checking videos for likes...');
      for (final video in videosQuery.docs) {
        final videoData = video.data();
        final likesData = videoData['likes'];
        print(
          'Video likes data type: ${likesData.runtimeType}, value: $likesData',
        );
        if (likesData != null && likesData is List) {
          totalLikes += likesData.length;
        }
      }
      print('Total likes calculated: $totalLikes');

      // Get followers count
      final followersData = userDataMap['followers'];
      print(
        'Followers data type: ${followersData.runtimeType}, value: $followersData',
      );
      List<String> followers = [];
      if (followersData != null && followersData is List) {
        followers = List<String>.from(followersData);
      }
      final followersCount = followers.length;

      // Get user rewards for streak
      final userRewards = await _firestore
          .collection('userRewards')
          .doc(userId)
          .get();
      final dailyStreak = userRewards.exists
          ? (userRewards.data()?['dailyStreak'] ?? 0)
          : 0;
      print(
        'User rewards exists: ${userRewards.exists}, daily streak: $dailyStreak',
      );
      if (userRewards.exists) {
        print('User rewards data: ${userRewards.data()}');
      }

      // Check each achievement
      print(
        'Checking achievements with: posts=$postsCount, videos=$videosCount, songs=$songsCount, likes=$totalLikes, streak=$dailyStreak, followers=$followersCount',
      );
      await _checkAchievement(userId, 'first_post', postsCount > 0);
      await _checkAchievement(userId, 'first_video', videosCount > 0);
      await _checkAchievement(userId, 'first_song', songsCount > 0);
      await _checkAchievement(userId, 'ten_posts', postsCount >= 10);
      await _checkAchievement(userId, 'hundred_likes', totalLikes >= 100);
      await _checkAchievement(userId, 'week_streak', dailyStreak >= 7);
      await _checkAchievement(userId, 'month_streak', dailyStreak >= 30);
      await _checkAchievement(userId, 'first_follower', followersCount > 0);
      await _checkAchievement(userId, 'ten_followers', followersCount >= 10);

      // Check first like achievement (this should be called when a like is received)
      // await _checkAchievement(userId, 'first_like', totalLikes > 0);
    } catch (e) {
      print('Error checking achievements: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Check and unlock a specific achievement
  static Future<void> _checkAchievement(
    String userId,
    String achievementId,
    bool condition,
  ) async {
    try {
      print('Checking achievement $achievementId with condition: $condition');
      if (!condition) return;

      final achievementRef = _firestore
          .collection('userAchievements')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId);

      final achievementDoc = await achievementRef.get();
      print('Achievement $achievementId exists: ${achievementDoc.exists}');
      if (!achievementDoc.exists) return;

      final achievementData = achievementDoc.data()!;
      print('Achievement $achievementId data: $achievementData');
      if (achievementData['isUnlocked'] == true) {
        print('Achievement $achievementId already unlocked');
        return;
      }

      // Unlock achievement
      print('Unlocking achievement $achievementId');
      await achievementRef.update({
        'isUnlocked': true,
        'unlockedAt': Timestamp.now(),
      });

      // Add points to user rewards
      final points = achievementData['points'] ?? 0;
      print('Adding $points points for achievement $achievementId');
      await _addPointsToUser(userId, points);

      // Update leaderboard
      await updateLeaderboard(userId);
    } catch (e) {
      print('Error checking achievement $achievementId: $e');
    }
  }

  /// Add points to user and update level
  static Future<void> _addPointsToUser(String userId, int points) async {
    try {
      print('Adding $points points to user $userId');
      final userRewardsRef = _firestore.collection('userRewards').doc(userId);

      await userRewardsRef.update({
        'totalPoints': FieldValue.increment(points),
      });

      // Check if level should increase
      final userRewards = await userRewardsRef.get();
      if (userRewards.exists) {
        final currentPoints = userRewards.data()?['totalPoints'] ?? 0;
        final currentLevel = userRewards.data()?['level'] ?? 1;
        final newLevel = (currentPoints ~/ 100) + 1;

        if (newLevel > currentLevel) {
          await userRewardsRef.update({'level': newLevel});
        }
      }
    } catch (e) {
      print('Error adding points: $e');
    }
  }

  /// Update leaderboard
  static Future<void> updateLeaderboard(String userId) async {
    try {
      print('Updating leaderboard for user $userId');
      final userData = await _firestore
          .collection('usersData')
          .doc(userId)
          .get();
      final userRewards = await _firestore
          .collection('userRewards')
          .doc(userId)
          .get();

      print(
        'User data exists: ${userData.exists}, User rewards exists: ${userRewards.exists}',
      );
      if (!userData.exists || !userRewards.exists) return;

      final userDataMap = userData.data()!;
      final userRewardsMap = userRewards.data()!;

      // Try multiple possible name fields to avoid duplicates
      String displayName = '';
      if (userDataMap['firstName'] != null && userDataMap['lastName'] != null) {
        displayName = '${userDataMap['firstName']} ${userDataMap['lastName']}';
      } else if (userDataMap['firstName'] != null &&
          userDataMap['secondName'] != null) {
        displayName =
            '${userDataMap['firstName']} ${userDataMap['secondName']}';
      } else if (userDataMap['firstName'] != null) {
        displayName = userDataMap['firstName'];
      } else if (userDataMap['lastName'] != null) {
        displayName = userDataMap['lastName'];
      } else if (userDataMap['secondName'] != null) {
        displayName = userDataMap['secondName'];
      } else if (userDataMap['name'] != null) {
        displayName = userDataMap['name'];
      } else if (userDataMap['userFirstName'] != null &&
          userDataMap['userSecondName'] != null) {
        displayName =
            '${userDataMap['userFirstName']} ${userDataMap['userSecondName']}';
      } else if (userDataMap['userFirstName'] != null) {
        displayName = userDataMap['userFirstName'];
      } else if (userDataMap['userSecondName'] != null) {
        displayName = userDataMap['userSecondName'];
      } else {
        displayName = 'User ${userId.substring(0, 6)}';
      }

      final totalPoints = userRewardsMap['totalPoints'] ?? 0;
      final profileImage = userDataMap['profileImage'];

      print(
        'Leaderboard data: name=$displayName, points=$totalPoints, image=$profileImage',
      );

      // Use userId as document ID to prevent duplicates
      await _firestore.collection('leaderboard').doc(userId).set({
        'userId': userId,
        'name': displayName.isNotEmpty ? displayName : 'Unknown User',
        'totalPoints': totalPoints,
        'profileImage': profileImage,
        'lastUpdated': Timestamp.now(),
      });
      print('Leaderboard updated successfully');
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }

  /// Check first like achievement (call this when a like is received)
  static Future<void> checkFirstLikeAchievement(String userId) async {
    await _checkAchievement(userId, 'first_like', true);
  }

  /// Get user's achievements
  static Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      print('Getting achievements for user $userId');
      final achievementsSnapshot = await _firestore
          .collection('userAchievements')
          .doc(userId)
          .collection('achievements')
          .get();

      print('Found ${achievementsSnapshot.docs.length} achievements');
      final achievements = achievementsSnapshot.docs
          .map((doc) => Achievement.fromMap(doc.id, doc.data()))
          .toList();
      print(
        'Achievements: ${achievements.map((a) => '${a.title} (${a.isUnlocked ? 'unlocked' : 'locked'})').join(', ')}',
      );
      return achievements;
    } catch (e) {
      print('Error getting user achievements: $e');
      return [];
    }
  }

  static Future<List<LeaderboardEntry>> getLeaderboard() async {
    try {
      print('Getting leaderboard');
      final leaderboardSnapshot = await _firestore
          .collection('leaderboard')
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .get();

      print('Found ${leaderboardSnapshot.docs.length} leaderboard entries');

      // Fetch all userRewards in parallel
      final streakFutures = leaderboardSnapshot.docs.map((doc) {
        return _firestore.collection('userRewards').doc(doc.id).get();
      }).toList();

      final streakDocs = await Future.wait(streakFutures);

      final List<LeaderboardEntry> leaderboard = [];

      for (int i = 0; i < leaderboardSnapshot.docs.length; i++) {
        final doc = leaderboardSnapshot.docs[i];
        final userId = doc.id;
        final data = doc.data();

        final userRewardsDoc = streakDocs[i];
        final dailyStreak = userRewardsDoc.exists
            ? (userRewardsDoc.data()?['dailyStreak'] ?? 0)
            : 0;

        // Determine badge quickly (no Firestore)
        final totalPoints = (data['totalPoints'] ?? 0) as int;
        final currentBadgeTitle = _badgeForPoints(totalPoints);

        // Merge data
        final enhancedData = Map<String, dynamic>.from(data);
        enhancedData['dailyStreak'] = dailyStreak;
        enhancedData['currentBadgeTitle'] = currentBadgeTitle;

        leaderboard.add(LeaderboardEntry.fromMap(userId, enhancedData, i + 1));
      }

      print('Leaderboard ready');
      return leaderboard;
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get leaderboard
  // static Future<List<LeaderboardEntry>> getLeaderboard() async {
  //   try {
  //     print('Getting leaderboard');
  //     final leaderboardSnapshot = await _firestore
  //         .collection('leaderboard')
  //         .orderBy('totalPoints', descending: true)
  //         .limit(10)
  //         .get();

  //     print('Found ${leaderboardSnapshot.docs.length} leaderboard entries');

  //     // Get streak data and current badge for each user
  //     final List<LeaderboardEntry> leaderboard = [];

  //     for (int i = 0; i < leaderboardSnapshot.docs.length; i++) {
  //       final doc = leaderboardSnapshot.docs[i];
  //       final userId = doc.id;
  //       final data = doc.data();

  //       // Get user's streak from userRewards
  //       final userRewardsDoc = await _firestore
  //           .collection('userRewards')
  //           .doc(userId)
  //           .get();

  //       final dailyStreak = userRewardsDoc.exists
  //           ? (userRewardsDoc.data()?['dailyStreak'] ?? 0)
  //           : 0;

  //       // Determine badge by total points thresholds
  //       String? currentBadgeTitle;
  //       try {
  //         final totalPoints = (data['totalPoints'] ?? 0) as int;
  //         currentBadgeTitle = _badgeForPoints(totalPoints);
  //       } catch (_) {}

  //       // Create enhanced data with streak and badge
  //       final enhancedData = Map<String, dynamic>.from(data);
  //       enhancedData['dailyStreak'] = dailyStreak;
  //       if (currentBadgeTitle != null) {
  //         enhancedData['currentBadgeTitle'] = currentBadgeTitle;
  //       }

  //       leaderboard.add(LeaderboardEntry.fromMap(
  //         userId,
  //         enhancedData,
  //         i + 1,
  //       ));
  //     }

  //     print('Leaderboard: ${leaderboard.map((e) => '${e.name} (${e.points} pts, ${e.dailyStreak} streak)').join(', ')}');
  //     return leaderboard;
  //   } catch (e) {
  //     print('Error getting leaderboard: $e');
  //     return [];
  //   }
  // }
}
