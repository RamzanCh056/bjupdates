import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/api_models/user_model/user_model.dart';
import '../model/gamification_models.dart';
import '../services/achievement_service.dart';
import '../shimmer_effect/shimmer_skeleton.dart';
import '../utils/color.dart';
import '../utils/name_utils.dart';
import '../widget/confetti_widget.dart';
import 'home1/song_player_screen.dart';
import 'auth_screen/login_screen.dart';
import 'edit_profile.dart';
import 'new_reels.dart';
import 'profile_photos_feed_screen.dart';
import '../widgets/profile/discover_people_section.dart';
import '../widgets/profile/professional_dashboard_card.dart';


class ProfileScreen extends StatefulWidget {
  /// When null, shows the current user's profile (with Edit profile).
  /// When set, shows that user's profile (same layout, no Edit profile).
  final String? userId;

  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Profile user id: widget.userId for another user, else current user.
  String get _profileUserId => widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  /// True when viewing own profile (Edit profile and avatar picker shown).
  bool get _isOwnProfile => widget.userId == null;

  /// Variables to hold the user's profile data
  String _firstName = '';
  String _lastName = '';
  String? _email;
  String? _profileImage;
  String? _bio;
  bool _isPaid = false;

  bool _isLoading = false;

  // Gamification variables
  int _dailyStreak = 0;
  int _totalPoints = 0;
  int _level = 1;
  List<Achievement> _achievements = [];
  String? _currentBadge;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Method to pick and upload profile image
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        EasyLoading.show(status: 'Uploading image...');
        
        // Upload to Firebase Storage
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');

        final file = File(image.path);
        await storageRef.putFile(file);
        
        // Get download URL
        final downloadURL = await storageRef.getDownloadURL();
        
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('usersData')
            .doc(user.uid)
            .update({'profileImage': downloadURL});
        
        // Update local state
        setState(() {
          _profileImage = downloadURL;
        });
        
        EasyLoading.showSuccess('Profile image updated!');
      }
    } catch (e) {
      EasyLoading.showError('Failed to upload image: $e');
      debugPrint('Error uploading image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    _loadProfileData();
    if (_isOwnProfile) _loadGamificationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load gamification data
  Future<void> _loadGamificationData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user's gamification data
      final doc = await FirebaseFirestore.instance
          .collection('userRewards')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _dailyStreak = data['dailyStreak'] ?? 0;
          _totalPoints = data['totalPoints'] ?? 0;
          _level = data['level'] ?? 1;
        });
      }

      // Load achievements
      await _loadAchievements();
      
      // Check daily login
      await _checkDailyLogin();
      
      // Check and unlock achievements
      await AchievementService.checkAndUnlockAchievements(user.uid);
      
      // Check for newly unlocked achievements and show notifications
      await _checkForNewAchievements();
    } catch (e) {
      debugPrint('Error loading gamification data: $e');
    }
  }

  /// Load user achievements
  Future<void> _loadAchievements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize achievements if they don't exist
      await AchievementService.initializeUserAchievements(user.uid);
      
      // Load achievements using the service
      final achievements = await AchievementService.getUserAchievements(user.uid);
      
      setState(() {
        _achievements = achievements;
      });
      
      // Get current badge
      _getCurrentBadge();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Get current achievement badge
  void _getCurrentBadge() {
    if (_achievements.isNotEmpty) {
      // Get the most recent unlocked achievement
      final unlockedAchievements = _achievements.where((a) => a.isUnlocked).toList();
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
          final lastLoginDay = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);
          
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

  /// Show streak reward
  void _showStreakReward(int streak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text(
              'Daily Streak!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Amazing! You\'ve logged in for $streak consecutive days!\n\n+10 points earned! 🔥',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Awesome!',
              style: TextStyle(color: Colors.purple, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Check for newly unlocked achievements and show notifications
  Future<void> _checkForNewAchievements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current achievements
      final currentAchievements = await AchievementService.getUserAchievements(user.uid);
      
      // Find newly unlocked achievements
      for (final achievement in currentAchievements) {
        if (achievement.isUnlocked && 
            achievement.unlockedAt != null &&
            achievement.unlockedAt!.toDate().isAfter(DateTime.now().subtract(Duration(minutes: 5)))) {
          // Show notification for recently unlocked achievement
          _showAchievementUnlocked(achievement);
        }
      }
      
      // Update local achievements
      setState(() {
        _achievements = currentAchievements;
      });
      
      // Update current badge
      _getCurrentBadge();
    } catch (e) {
      debugPrint('Error checking for new achievements: $e');
    }
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
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.amber.shade800, size: 24),
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

  /// Fetch the user's profile data from Firestore and store it locally
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = _profileUserId;
      if (uid.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('usersData').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstName = data['firstName'] ?? '';
          _lastName = data['secondName'] ?? '';
          _email = _isOwnProfile && user != null ? user.email : (data['email'] as String?);
          _profileImage = data['profileImage'] as String?;
          _bio = data['bio'] as String?;
          _isPaid = (data['isPaid'] ?? false) as bool;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _logoutUser() async {
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(UserModelFields.email);
      await prefs.remove(UserModelFields.userId);
      await prefs.remove(UserModelFields.deviceId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen(selectedRole: '',)),
      );
    } catch (e) {
      EasyLoading.showError("Logout failed");
      debugPrint("Logout Error: $e");
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) {
      _loadProfileData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profileUserId.isEmpty) {
      return Scaffold(
        backgroundColor: darkBackgroundPrimary,
        body: Center(
          child: Text(
            'Unable to load profile',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
          ),
        ),
      );
    }
    final myDocRef = FirebaseFirestore.instance.collection('usersData').doc(_profileUserId);
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: Navigator.canPop(context),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? _buildProfileLoadingShimmer(context)
          : _buildUnifiedProfileBody(myDocRef),
    );
  }

  Widget _buildUnifiedProfileBody(DocumentReference myDocRef) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeaderContent(myDocRef),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.grid_on_rounded, size: 26), text: 'Photos'),
                Tab(icon: Icon(Icons.play_circle_outline_rounded, size: 26), text: 'Videos'),
                Tab(icon: Icon(Icons.music_note_rounded, size: 26), text: 'Songs'),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              switch (_tabController.index) {
                case 1:
                  return _buildVideosTabContent();
                case 2:
                  return _buildSongsTabContent();
                case 0:
                default:
                  return _buildPhotosTabContent();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaticGrid({
    required int crossAxisCount,
    required int itemCount,
    required double aspectRatio,
    required Widget Function(int index) itemBuilder,
    double spacing = 2,
  }) {
    if (itemCount <= 0) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < itemCount; i += crossAxisCount) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + crossAxisCount < itemCount ? spacing : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < crossAxisCount; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                Expanded(
                  child: i + j < itemCount
                      ? AspectRatio(
                          aspectRatio: aspectRatio,
                          child: itemBuilder(i + j),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  double _gridHeight(
    BuildContext context, {
    required int itemCount,
    required int crossAxisCount,
    required double aspectRatio,
    double spacing = 2,
  }) {
    if (itemCount <= 0) return 0;

    final width = MediaQuery.sizeOf(context).width;
    final cellWidth = (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final cellHeight = cellWidth / aspectRatio;
    final rowCount = (itemCount + crossAxisCount - 1) ~/ crossAxisCount;
    return rowCount * cellHeight + (rowCount - 1) * spacing;
  }

  Widget _buildProfileHeaderContent(DocumentReference myDocRef) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                // Instagram-style header: avatar left, stats right
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: myDocRef.snapshots(),
                    builder: (context, meSnap) {
                      if (meSnap.connectionState == ConnectionState.waiting) {
                        return _buildProfileHeaderRow(0, 0, 0, 0);
                      }
                      final meData = meSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final followers = List<String>.from(meData['followers'] ?? []);
                      final following = List<String>.from(meData['following'] ?? []);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('songs')
                            .where('userId', isEqualTo: _profileUserId)
                            .snapshots(),
                        builder: (context, songsSnap) {
                          if (songsSnap.connectionState == ConnectionState.waiting) {
                            return _buildProfileHeaderRow(
                              0,
                              followers.length,
                              following.length,
                              0,
                            );
                          }

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('reels')
                                .where('userId', isEqualTo: _profileUserId)
                                .snapshots(),
                            builder: (context, videosSnap) {
                              if (videosSnap.connectionState == ConnectionState.waiting) {
                                return _buildProfileHeaderRow(
                                  0,
                                  followers.length,
                                  following.length,
                                  0,
                                );
                              }
                              final videoDocs = videosSnap.data?.docs ?? [];
                              final videoCount = videoDocs.length.toInt();

                              // Use same source of truth as reels screen: prefer
                              // likedBy.length so total matches what reels show.
                              int totalLikes = 0;
                              for (final doc in videoDocs) {
                                final data = doc.data() as Map<String, dynamic>?;
                                final likedBy = data?['likedBy'];
                                if (likedBy is List && likedBy.isNotEmpty) {
                                  totalLikes += likedBy.length;
                                } else {
                                  final likesField = data?['likes'];
                                  if (likesField is int) {
                                    totalLikes += likesField;
                                  }
                                }
                              }
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .where('userId', isEqualTo: _profileUserId)
                                    .where('type', isEqualTo: 'image')
                                    .snapshots(),
                                builder: (context, postsSnap) {
                                  if (postsSnap.connectionState == ConnectionState.waiting) {
                                    return _buildProfileHeaderRow(
                                      videoCount,
                                      followers.length,
                                      following.length,
                                      totalLikes,
                                    );
                                  }
                                  final imagePostCount = (postsSnap.data?.docs.length ?? 0).toInt();
                                  final totalPostsCount = videoCount + imagePostCount;
                                  return _buildProfileHeaderRow(
                                    totalPostsCount,
                                    followers.length,
                                    following.length,
                                    totalLikes,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                // Name + badges in one row (spaceBetween), then @handle, then bio
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                NameUtils.getDisplayName(_firstName, _lastName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_currentBadge != null || _isPaid) ...[
                              Container(
                                height: 20,
                                width: 1,
                                margin: const EdgeInsets.only(left: 12, right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade400.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.blue.shade400.withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: Colors.blue.shade300, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Verified',
                                            style: TextStyle(
                                              color: Colors.blue.shade300,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_currentBadge != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade600.withValues(alpha: 0.25),
                                            Colors.orange.shade600.withValues(alpha: 0.2),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.amber.shade400.withValues(alpha: 0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.emoji_events_rounded, color: Colors.amber.shade300, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            // 'Achievement · 
                                            '$_currentBadge',
                                            style: TextStyle(
                                              color: Colors.amber.shade200,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (_email != null && _email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${_email!.split('@').first}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        if (_bio != null && _bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _bio!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Edit profile button (only for own profile, Instagram style)
                if (_isOwnProfile) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _editProfile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfessionalDashboardCard(userId: _profileUserId),
                  const DiscoverPeopleSection(),
                ],
      ],
    );
  }

  /// Shimmer placeholder for initial profile load (matches profile layout)
  Widget _buildProfileLoadingShimmer(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: avatar + stats (Instagram style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(
                  height: 88,
                  width: 88,
                  shape: BoxShape.circle,
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: const [
                          Skeleton(height: 18, width: 28),
                          SizedBox(height: 2),
                          Skeleton(height: 13, width: 44),
                        ],
                      ),
                      Column(
                        children: const [
                          Skeleton(height: 18, width: 28),
                          SizedBox(height: 2),
                          Skeleton(height: 13, width: 56),
                        ],
                      ),
                      Column(
                        children: const [
                          Skeleton(height: 18, width: 28),
                          SizedBox(height: 2),
                          Skeleton(height: 13, width: 56),
                        ],
                      ),
                      Column(
                        children: const [
                          Skeleton(height: 18, width: 28),
                          SizedBox(height: 2),
                          Skeleton(height: 13, width: 40),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Name, handle & bio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 16, width: 140),
                SizedBox(height: 2),
                Skeleton(height: 14, width: 100),
                SizedBox(height: 8),
                Skeleton(height: 14, width: double.infinity),
                Skeleton(height: 14, width: 200),
                SizedBox(height: 16),
              ],
            ),
          ),
          // Edit profile button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Skeleton(
              height: 36,
              width: double.infinity,
              shape: BoxShape.rectangle,
            ),
          ),
          const SizedBox(height: 24),
          // Tab bar strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 46,
            child: Row(
              children: const [
                Skeleton(height: 26, width: 70),
                SizedBox(width: 24),
                Skeleton(height: 26, width: 70),
                SizedBox(width: 24),
                Skeleton(height: 26, width: 60),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grid shimmer (3 rows of tiles, same as Photos tab)
          SizedBox(
            height: _gridHeight(
              context,
              itemCount: 9,
              crossAxisCount: 3,
              aspectRatio: 1,
            ),
            child: _buildPhotosGridShimmer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTabContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _profileUserId)
          .where('type', isEqualTo: 'image')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPhotosGridShimmer(context);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: 280,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_rounded,
                    size: 64,
                    color: purpleAccent.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your first photo from the feed',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final profileUserName = NameUtils.getDisplayName(_firstName, _lastName).trim().isEmpty
            ? 'User'
            : NameUtils.getDisplayName(_firstName, _lastName);

        return _buildStaticGrid(
          crossAxisCount: 3,
          itemCount: docs.length,
          aspectRatio: 1,
          itemBuilder: (index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final imageUrl = data['fileUrl'] ?? '';

            if (imageUrl.isEmpty) {
              return Container(
                color: darkBackgroundTertiary,
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 32,
                ),
              );
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePhotosFeedScreen(
                        profileUserId: _profileUserId,
                        profileUserName: profileUserName,
                        profileUserImage: _profileImage,
                        initialPostId: doc.id,
                      ),
                    ),
                  );
                },
                child: ClipRect(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: darkBackgroundTertiary,
                      child: Icon(
                        Icons.image_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 32,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: darkBackgroundTertiary,
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shimmer grid for Photos tab while loading (3 columns, square tiles)
  Widget _buildPhotosGridShimmer(BuildContext context) {
    return _buildStaticGrid(
      crossAxisCount: 3,
      itemCount: 9,
      aspectRatio: 1,
      itemBuilder: (_) => const Skeleton(shape: BoxShape.rectangle),
    );
  }

  /// Shimmer grid for Videos tab while loading (3 columns, aspect ratio 0.75)
  Widget _buildVideosGridShimmer(BuildContext context) {
    return _buildStaticGrid(
      crossAxisCount: 3,
      itemCount: 9,
      aspectRatio: 0.75,
      itemBuilder: (_) => const Skeleton(shape: BoxShape.rectangle),
    );
  }

  Widget _buildVideosTabContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reels')
          .where('userId', isEqualTo: _profileUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideosGridShimmer(context);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: 280,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 64,
                    color: purpleAccent.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No videos yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your first reel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return _buildStaticGrid(
          crossAxisCount: 3,
          itemCount: docs.length,
          aspectRatio: 0.75,
          itemBuilder: (index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final coverUrl = data['coverUrl'] as String? ?? '';
            final videoUrl = data['videoUrl'] as String? ?? '';
            final thumbnailUrl = coverUrl.isNotEmpty ? coverUrl : videoUrl;
            final views = (data['views'] as int?) ?? 0;

            return ClipRRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: darkBackgroundTertiary,
                            child: Icon(
                              Icons.videocam_rounded,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 40,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: darkBackgroundTertiary,
                            child: Icon(
                              Icons.videocam_rounded,
                              color: purpleAccent.withValues(alpha: 0.4),
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: darkBackgroundTertiary,
                          child: Icon(
                            Icons.videocam_rounded,
                            color: purpleAccent.withValues(alpha: 0.4),
                            size: 40,
                          ),
                        ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          views >= 1000000
                              ? '${(views / 1000000).toStringAsFixed(1)}M'
                              : views >= 1000
                                  ? '${(views / 1000).toStringAsFixed(1)}K'
                                  : '$views',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReelsScreen(
                              showBackButton: true,
                              reelsList: docs,
                              initialReelIndex: index,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.zero,
                      splashColor: purpleAccent.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.05),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongsTabContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('songs')
          .where('userId', isEqualTo: _profileUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: 280,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBB86FC).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.music_note_outlined,
                      size: 64,
                      color: Color(0xFFBB86FC),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Songs Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your first song to get started',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        double r(double size) =>
            size * (MediaQuery.of(context).size.width / 375.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(r(16), 0, r(16), r(16)),
          child: Column(
            children: List.generate(docs.length, (index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final song = {
                ...data,
                'id': doc.id,
              };
              final isOwner = song['userId'] == currentUid;

              return Container(
                margin: EdgeInsets.only(bottom: r(12)),
                decoration: BoxDecoration(
                  color: darkBackgroundPrimary,
                  borderRadius: BorderRadius.circular(r(20)),
                  border: Border.all(
                    color: const Color(0xFFBB86FC).withOpacity(0.2),
                    width: r(1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SongPlayerScreen(
                            title: song['title'] ?? '',
                            description: song['description'] ?? '',
                            fileUrl: song['url'] ?? '',
                            coverImage: song['coverImage'] ?? '',
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(r(20)),
                    child: Padding(
                      padding: EdgeInsets.all(r(16)),
                      child: Row(
                        children: [
                          Container(
                            width: r(40),
                            height: r(40),
                            decoration: BoxDecoration(
                              gradient: appGradient,
                              borderRadius: BorderRadius.circular(r(12)),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: r(28),
                              ),
                            ),
                          ),
                          SizedBox(width: r(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        song['title'] ?? 'Unknown Song',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: r(16),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: r(12),
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        SizedBox(width: r(4)),
                                        Text(
                                          (song['year'] ?? '').toString(),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: r(12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: r(6)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: r(14),
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    SizedBox(width: r(4)),
                                    Expanded(
                                      child: Text(
                                        (song['singer'] ?? '').toString(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: r(13),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isOwner) SizedBox(width: r(8)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Instagram-style header row: avatar left, stats (Posts, Followers, Following, Likes) right
  Widget _buildProfileHeaderRow(int postsCount, int followersCount, int followingCount, int totalLikesCount) {
    final avatarStack = Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundImage: _profileImage != null && _profileImage!.isNotEmpty
              ? NetworkImage(_profileImage!)
              : null,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          child: _profileImage == null || _profileImage!.isEmpty
              ? const Icon(Icons.person_rounded, color: Colors.white54, size: 44)
              : null,
        ),
        if (_isPaid)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: darkBackgroundPrimary, width: 2),
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
            ),
          ),
        if (_currentBadge != null)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: darkBackgroundPrimary, width: 2),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 10),
            ),
          ),
        if (_isOwnProfile)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: darkBackgroundTertiary,
                shape: BoxShape.circle,
                border: Border.all(color: darkBackgroundPrimary, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
            ),
          ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar (tap to change photo only for own profile)
        _isOwnProfile
            ? GestureDetector(onTap: _pickAndUploadImage, child: avatarStack)
            : avatarStack,
        const SizedBox(width: 28),
        // Stats (Instagram: numbers top, labels below)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(postsCount.toString(), 'Posts'),
              _buildStatItem(followersCount.toString(), 'Followers'),
              _buildStatItem(followingCount.toString(), 'Following'),
              _buildStatItem(totalLikesCount.toString(), 'Likes'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
