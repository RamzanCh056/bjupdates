import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/gamification_models.dart';
import '../services/achievement_service.dart';

class TopPerformersScreen extends StatefulWidget {
  final String? currentUserName;

  const TopPerformersScreen({Key? key, this.currentUserName}) : super(key: key);

  @override
  State<TopPerformersScreen> createState() => _TopPerformersScreenState();
}

class _TopPerformersScreenState extends State<TopPerformersScreen> {
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final list = await AchievementService.getLeaderboard();
      setState(() {
        _leaderboard = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      setState(() => _isLoading = false);
    }
  }

  String _displayName(LeaderboardEntry entry) {
    if (_currentUid != null && entry.userId == _currentUid) {
      final name = widget.currentUserName;
      return (name != null && name.isNotEmpty) ? name : 'You';
    }
    return entry.name;
  }

  bool _isCurrentUser(LeaderboardEntry entry) {
    return _currentUid != null && entry.userId == _currentUid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
        ),
        title: const Text(
          'Top Performers',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(purpleAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading leaderboard…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _leaderboard.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.leaderboard_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No rankings yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to earn points!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  color: purpleAccent,
                  backgroundColor: darkBackgroundTertiary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = _leaderboard[index];
                      return _LeaderboardTile(
                        index: index,
                        entry: entry,
                        displayName: _displayName(entry),
                        isCurrentUser: _isCurrentUser(entry),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;
  final String displayName;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.index,
    required this.entry,
    required this.displayName,
    required this.isCurrentUser,
  });

  Widget _rankBadge(int index, int rank) {
    final isTopThree = index < 3;
    final medalColors = [
      Colors.amber,
      Colors.grey.shade400,
      Colors.brown.shade400,
    ];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: isTopThree
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  medalColors[index].withValues(alpha: 0.9),
                  medalColors[index].withValues(alpha: 0.7),
                ],
              )
            : null,
        color: isTopThree ? null : purpleAccent.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isTopThree ? medalColors[index] : purpleAccent).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: isTopThree
            ? Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28)
            : Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = index < 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: isTopThree
            ? LinearGradient(
                colors: [
                  Colors.amber.shade700.withValues(alpha: 0.9),
                  Colors.orange.shade800.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isTopThree ? null : darkBackgroundTertiary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? purpleAccent.withValues(alpha: 0.6)
              : (isTopThree
                  ? Colors.amber.withValues(alpha: 0.4)
                  : purpleAccent.withValues(alpha: 0.2)),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          if (isTopThree)
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          _rankBadge(index, entry.rank),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => openUserProfile(context, entry.userId),
            child: CircleAvatar(
              radius: 24,
              backgroundImage: entry.profileImage != null && entry.profileImage!.isNotEmpty
                  ? NetworkImage(entry.profileImage!)
                  : null,
              backgroundColor: Colors.grey.shade700,
              child: entry.profileImage == null || entry.profileImage!.isEmpty
                  ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: purpleAccent.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${entry.points} pts',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade600, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.dailyStreak}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry.currentBadgeTitle != null && entry.currentBadgeTitle!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade600, Colors.orange.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              entry.currentBadgeTitle!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
