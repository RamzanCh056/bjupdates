import 'package:beatjerky/screens/achievements_screen.dart';
import 'package:beatjerky/screens/premium_plans/membership_history_screen.dart';

import 'package:beatjerky/screens/top_performers_screen.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../model/gamification_models.dart';
import '../services/achievement_service.dart';
import '../widget/confetti_widget.dart';
import 'settings_screen.dart';
import 'view_user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  // Gamification variables
  int _dailyStreak = 0;
  int _totalPoints = 0;
  int _level = 1;
  List<Achievement> _achievements = [];
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;

  // User profile variables
  String _userName = '';
  String _userEmail = '';
  String? _profileImage;
  bool _isPaid = false;
  String? _currentBadge;
  String _paidPlan = "";
  DateTime? _planStartDate;
  DateTime? _planEndDate;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _streakController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _streakController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadGamificationData();

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(Duration(milliseconds: 200));
    _slideController.forward();

    await Future.delayed(Duration(milliseconds: 200));
    _scaleController.forward();

    await Future.delayed(Duration(milliseconds: 300));
    _streakController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  Widget _buildLeaderboardShimmer() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E27),
            Color(0xFF16213E),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Shimmer.fromColors(
          baseColor: darkBackgroundPrimary.withOpacity(0.7),
          highlightColor: darkAppBarBackground.withOpacity(0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Profile card placeholder
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 18,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Streak card placeholder
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 24,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Points/Level card placeholder
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 44,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Container(
                          height: 44,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Option card placeholders
              ...List.generate(2, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: 130,
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadGamificationData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Start everything in parallel
      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('userRewards')
            .doc(user.uid)
            .get(),
        FirebaseFirestore.instance.collection('usersData').doc(user.uid).get(),
        AchievementService.getUserAchievements(user.uid),
        AchievementService.getLeaderboard(),
      ]);

      final rewardsDoc = futures[0] as DocumentSnapshot;
      final userDoc = futures[1] as DocumentSnapshot;
      final achievements = futures[2] as List<Achievement>;
      final leaderboard = futures[3] as List<LeaderboardEntry>;

      final rewardsData = rewardsDoc.data() as Map<String, dynamic>? ?? {};
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      setState(() {
        // Rewards
        _dailyStreak = rewardsData['dailyStreak'] ?? 0;
        _totalPoints = rewardsData['totalPoints'] ?? 0;
        _level = rewardsData['level'] ?? 1;

        // Profile
        _isPaid = userData['isPaid'] ?? false;
        _profileImage = userData['profileImage'];
        _userEmail = userData['email'] ?? user.email ?? '';
        _paidPlan = userData['paidPlan'] ?? "";
        _planStartDate = (userData['planStartDate'] as Timestamp?)?.toDate();
        _planEndDate = (userData['planEndDate'] as Timestamp?)?.toDate();

        // Handle multiple name fields gracefully
        _userName = userData['firstName'] ?? userData['name'] ?? 'User';

        // Achievements & Leaderboard
        _achievements = achievements;
        _leaderboard = leaderboard;
      });

      _getCurrentBadge();

      // Run these AFTER UI is ready (so it doesn’t block)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkDailyLogin();
        await AchievementService.checkAndUnlockAchievements(user.uid);
        await _checkForNewAchievements();
      });

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading gamification data: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int value,
    required int animDuration,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: value.toDouble()),
          duration: Duration(milliseconds: animDuration),
          builder: (context, val, child) {
            return Text(
              '${val.toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Get current achievement badge
  void _getCurrentBadge() {
    if (_achievements.isNotEmpty) {
      // Get the most recent unlocked achievement
      final unlockedAchievements = _achievements
          .where((a) => a.isUnlocked)
          .toList();
      if (unlockedAchievements.isNotEmpty) {
        // Sort by points to get the highest achievement
        unlockedAchievements.sort((a, b) => b.points.compareTo(a.points));
        setState(() {
          _currentBadge = unlockedAchievements.first.title;
        });
      }
    }
  }

  /// Check daily login and update streak
  Future<void> _checkDailyLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final doc = await FirebaseFirestore.instance
          .collection('userRewards')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final lastLogin = data['lastLogin'];

        if (lastLogin != null) {
          final lastLoginDate = (lastLogin as Timestamp).toDate();
          final lastLoginDay = DateTime(
            lastLoginDate.year,
            lastLoginDate.month,
            lastLoginDate.day,
          );

          if (today.difference(lastLoginDay).inDays == 1) {
            // Consecutive day
            final newStreak = (data['dailyStreak'] ?? 0) + 1;
            final newPoints = (data['totalPoints'] ?? 0) + 10;

            await FirebaseFirestore.instance
                .collection('userRewards')
                .doc(user.uid)
                .update({
                  'dailyStreak': newStreak,
                  'totalPoints': newPoints,
                  'lastLogin': Timestamp.now(),
                });

            setState(() {
              _dailyStreak = newStreak;
              _totalPoints = newPoints;
            });

            _showStreakReward(newStreak);
          } else if (today.difference(lastLoginDay).inDays > 1) {
            // Streak broken
            await FirebaseFirestore.instance
                .collection('userRewards')
                .doc(user.uid)
                .update({
                  'dailyStreak': 1,
                  'totalPoints': (data['totalPoints'] ?? 0) + 10,
                  'lastLogin': Timestamp.now(),
                });

            setState(() {
              _dailyStreak = 1;
              _totalPoints = (data['totalPoints'] ?? 0) + 10;
            });
          }
        } else {
          // First time login
          await FirebaseFirestore.instance
              .collection('userRewards')
              .doc(user.uid)
              .set({
                'dailyStreak': 1,
                'totalPoints': 10,
                'lastLogin': Timestamp.now(),
                'level': 1,
              });

          setState(() {
            _dailyStreak = 1;
            _totalPoints = 10;
          });
        }
      } else {
        // Create new user rewards document
        await FirebaseFirestore.instance
            .collection('userRewards')
            .doc(user.uid)
            .set({
              'dailyStreak': 1,
              'totalPoints': 10,
              'lastLogin': Timestamp.now(),
              'level': 1,
            });

        setState(() {
          _dailyStreak = 1;
          _totalPoints = 10;
        });
      }
    } catch (e) {
      debugPrint('Error checking daily login: $e');
    }
  }

  /// Check for newly unlocked achievements and show notifications
  Future<void> _checkForNewAchievements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current achievements
      final currentAchievements = await AchievementService.getUserAchievements(
        user.uid,
      );

      // Find newly unlocked achievements
      for (final achievement in currentAchievements) {
        if (achievement.isUnlocked &&
            achievement.unlockedAt != null &&
            achievement.unlockedAt!.toDate().isAfter(
              DateTime.now().subtract(Duration(minutes: 5)),
            )) {
          // Show notification for recently unlocked achievement
          _showAchievementUnlocked(achievement);
        }
      }

      // Update local achievements
      setState(() {
        _achievements = currentAchievements;
      });
    } catch (e) {
      debugPrint('Error checking for new achievements: $e');
    }
  }

  /// Show streak reward
  void _showStreakReward(int streak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.orange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade600,
                    Colors.red.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Daily Streak!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Amazing! You\'ve logged in for $streak consecutive days!\n\n+10 points earned! 🔥',
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade600,
                  Colors.red.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Awesome!',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show achievement unlocked notification
  void _showAchievementUnlocked(Achievement achievement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        children: [
          // Confetti background
          ConfettiWidget(isActive: true),

          // Achievement dialog
          Center(
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebration animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              achievement.icon,
                              color: Colors.amber.shade800,
                              size: 80,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 25),

                    // Achievement title with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 600),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              'Achievement Unlocked!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 15),

                    // Achievement name
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              achievement.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),

                    // Achievement description
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 1000),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              achievement.description,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 25),

                    // Points earned with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 1200),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber.shade800,
                                  size: 24,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '+${achievement.points} Points!',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Auto-close after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
       
        title: const Text(
          "Leaderboard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Container(
          //   margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
          //   decoration: BoxDecoration(
          //     color: Colors.amber.withValues(alpha: 0.15),
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          //   ),
          //   child: IconButton(
          //     icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 22),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(builder: (_) => const AchievementsScreen()),
          //       );
          //     },
          //     tooltip: 'Achievements',
          //   ),
          // ),
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLeaderboardShimmer()
          : FadeTransition(
              opacity: _fadeController,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    FadeTransition(
                      opacity: _fadeController,
                      child: Container(
                     
                        padding: const EdgeInsets.all(20),
                        
                        child: Row(
                          children: [
                            // Profile Picture with Badges (tap to open profile)
                            GestureDetector(
                              onTap: () {
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) openUserProfile(context, uid);
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: appGradient,
                                    ),
                                    padding: const EdgeInsets.all(2.5),
                                    child: _profileImage != null &&
                                          _profileImage!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            _profileImage!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const CircleAvatar(
                                              radius: 30,
                                              backgroundColor: Colors.grey,
                                              child: Icon(
                                                Icons.person_rounded,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.grey,
                                          child: Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                ),
                                // Blue Tick Badge
                                if (_isPaid)
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.verified,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                // Achievement Badge - positioned to not hide picture
                                if (_currentBadge != null)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade600,
                                            Colors.orange.shade600,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.emoji_events,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            ),
                            SizedBox(width: 16),
                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName.isNotEmpty ? _userName : 'User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  if (_userEmail.isNotEmpty)
                                    Text(
                                      '@${_userEmail.split('@').first}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                    ),
                                  if (_currentBadge != null) ...[
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade600,
                                            Colors.orange.shade600,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.emoji_events,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            _currentBadge!,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Add Verified User text for paid users
                                  if (_isPaid) ...[
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade600,
                                            Colors.blue.shade800,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Verified User',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Container(
                              decoration: BoxDecoration(
                                gradient: appGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFBB86FC).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                              onTap: () {
                                if (_isPaid) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MembershipHistoryScreen(),
                                    ),
                                  );
                                } else {
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) =>
                                  //         PremiumSubscriptionScreen(),
                                  //   ),
                                  // );
                                }
                              },
                                  borderRadius: BorderRadius.circular(30),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                child: Icon(
                                      Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Daily Streak Card
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _slideController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.deepOrange.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Streak',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: _dailyStreak.toDouble()),
                                    duration: const Duration(milliseconds: 1500),
                                    builder: (context, value, child) {
                                      return Text(
                                        '${value.toInt()} days',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    'Keep it going! 🔥',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Points and Level Card
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _scaleController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: purpleAccent.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatChip(
                                  icon: Icons.stars_rounded,
                                  label: 'Points',
                                  value: _totalPoints,
                                  animDuration: 1500,
                                ),
                                Container(
                                  width: 1,
                                  height: 44,
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                _buildStatChip(
                                  icon: Icons.arrow_upward_rounded,
                                  label: 'Level',
                                  value: _level,
                                  animDuration: 1000,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0.0,
                                  end: (_totalPoints % 100) / 100,
                                ),
                                duration: const Duration(milliseconds: 1800),
                                builder: (context, value, child) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_totalPoints % 100}/100 to next level',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Option: Achievements (navigates to full screen)
                    FadeTransition(
                      opacity: _fadeController,
                      child: _BuildOptionCard(
                        icon: Icons.emoji_events_rounded,
                        title: 'Achievements',
                        subtitle: '${_achievements.where((a) => a.isUnlocked).length} of ${_achievements.length} badges unlocked',
                        gradient: darkAppBarBackground,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Option: Top Performers (navigates to full screen)
                    FadeTransition(
                      opacity: _fadeController,
                      child: _BuildOptionCard(
                        icon: Icons.leaderboard_rounded,
                        title: 'Top Performers',
                        subtitle: _leaderboard.isEmpty
                            ? 'See who\'s on top'
                            : 'View full leaderboard',
                        gradient: darkAppBarBackground,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopPerformersScreen(currentUserName: _userName),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BuildOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color gradient;
  final VoidCallback onTap;

  const _BuildOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
            color: gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

