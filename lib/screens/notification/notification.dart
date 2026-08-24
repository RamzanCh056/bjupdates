import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:beatjerky/screens/New Feed/new_feed.dart';
import 'package:beatjerky/screens/New Feed/comment_screen.dart';
import 'package:beatjerky/screens/event_screens/event_screen.dart';
import 'package:beatjerky/screens/event_screens/event_map_screen.dart';
import 'package:beatjerky/screens/home1/song_player_screen.dart';
import 'package:beatjerky/screens/new_reels.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<NotificationViewModel> newNotifications = [];
  List<NotificationViewModel> pastNotifications = [];
  StreamSubscription? _subscription;
  String? userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser?.uid;
    log("User ID: $userId");
    if (userId != null) {
      _startListeningToNotifications();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _startListeningToNotifications() {
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('userNotifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      List<NotificationViewModel> all = snapshot.docs
          .map((doc) => NotificationViewModel.fromFirestore(
                doc.id,
                doc.data(),
              ))
          .toList();

      setState(() {
        _isLoading = false;
        newNotifications = all.where((n) => !n.isRead).toList();
        pastNotifications = all.where((n) => n.isRead).toList();
      });
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      log('Failed to mark notification as read: $e');
    }
  }

  /// Refresh notifications
  Future<void> _refreshNotifications() async {
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      // The stream will automatically update, but we can force a refresh
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _isLoading = false);
    } catch (e) {
      log('Error refreshing notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    if (userId == null || newNotifications.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var n in newNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(userId)
            .collection('userNotifications')
            .doc(n.id);
        batch.update(docRef, {'isRead': true});
      }
      await batch.commit();
      AppToast.show('All notifications marked as read');
    } catch (e) {
      log('Error marking all notifications as read: $e');
      AppToast.show('Failed to mark all as read', isError: true);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .doc(notificationId)
          .delete();
      log('Notification deleted: $notificationId');
    } catch (e) {
      log('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onPop() {
    if (newNotifications.isNotEmpty) _markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onPop();
      },
      child: Scaffold(
        backgroundColor: darkBackgroundPrimary,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              _onPop();
              Navigator.of(context).pop();
            },
          ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              // padding: const EdgeInsets.all(8),
              // decoration: BoxDecoration(
              //   gradient: const LinearGradient(
              //     colors: [Color(0xFFBB86FC), Color(0xFF6200EE)],
              //   ),
              //   borderRadius: BorderRadius.circular(12),
              // ),
              // child: const Icon(
              //   Icons.notifications_active,
              //   color: Colors.white,
              //   size: 17,
              // ),
            ),
            // const SizedBox(width: 12),
            const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (newNotifications.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${newNotifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          if (newNotifications.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Color(0xFFBB86FC), size: 20),
              label: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFFBB86FC),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(accent),
      ),
    );
  }

  Widget _buildBody(Color accent) {
    if (_isLoading) {
      return _buildNotificationShimmer(context);
    }

    if (newNotifications.isEmpty && pastNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: accent.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'re all caught up',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final bottomPadding = 32.0 + mq.padding.bottom;
    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: accent,
      backgroundColor: darkBackgroundSecondary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomPadding,
        ),
        itemCount: _getTotalItemCount(),
        itemBuilder: (context, index) {
          return _buildItemAtIndex(index);
        },
      ),
    );
  }

  int _getTotalItemCount() {
    int count = 0;
    if (newNotifications.isNotEmpty) {
      count += 2; // Section title + spacing
      count += newNotifications.length;
      count += 1; // Extra spacing
    }
    count += 2; // "Earlier" section title + spacing
    if (pastNotifications.isNotEmpty) {
      count += pastNotifications.length;
    } else {
      count += 1; // Empty state
    }
    return count;
  }

  Widget _buildItemAtIndex(int index) {
    int currentIndex = 0;
    
    // New notifications section
    if (newNotifications.isNotEmpty) {
      if (index == currentIndex) {
        return _buildSectionTitle('New', newNotifications.length);
      }
      currentIndex++;
      
      if (index == currentIndex) {
        return const SizedBox(height: 8);
      }
      currentIndex++;
      
      final newIndex = index - currentIndex;
      if (newIndex >= 0 && newIndex < newNotifications.length) {
        return _buildNotificationItem(newNotifications[newIndex], true);
      }
      currentIndex += newNotifications.length;
      
      if (index == currentIndex) {
        return const SizedBox(height: 24);
      }
      currentIndex++;
    }
    
    // Earlier section title
    if (index == currentIndex) {
      return _buildSectionTitle('Earlier', pastNotifications.length);
    }
    currentIndex++;
    
    if (index == currentIndex) {
      return const SizedBox(height: 8);
    }
    currentIndex++;
    
    // Past notifications or empty state
    if (pastNotifications.isEmpty) {
      if (index == currentIndex) {
        return _buildEmptyState();
      }
    } else {
      final pastIndex = index - currentIndex;
      if (pastIndex >= 0 && pastIndex < pastNotifications.length) {
        return _buildNotificationItem(pastNotifications[pastIndex], false);
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildNotificationShimmer(BuildContext context) {
    final bottomPadding = 32.0 + MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomPadding,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(height: 44, width: 44, shape: BoxShape.circle),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(height: 14, width: double.infinity),
                    const SizedBox(height: 8),
                    Skeleton(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.35,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No earlier notifications',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    if (type.toLowerCase().contains('song')) {
      return Icons.music_note;
    } else if (type.toLowerCase().contains('story') || type.toLowerCase().contains('reply')) {
      return Icons.photo_camera;
    } else if (type.toLowerCase().contains('follow')) {
      return Icons.person_add;
    } else if (type.toLowerCase().contains('message') || type.toLowerCase().contains('chat')) {
      return Icons.chat_bubble;
    } else {
      return Icons.notifications;
    }
  }

  /// Navigate based on notification type
  Future<void> _handleNotificationTap(NotificationViewModel notification, bool isNew) async {
    if (isNew) {
      await _markAsRead(notification.id);
    }

    final type = notification.type.toLowerCase();
    
    try {
      // Navigate based on notification type
      if (type.contains('event')) {
        await _navigateToEvent(notification);
      } else if (type.contains('song')) {
        await _navigateToSong(notification);
      } else if (type.contains('post') || type.contains('reel')) {
        await _navigateToPostOrReel(notification);
      } else if (type.contains('like')) {
        await _navigateToPostOrReel(notification);
      } else if (type.contains('comment') || type.contains('reply')) {
        await _navigateToComment(notification);
      } else if (type.contains('follow') || type.contains('message')) {
        _navigateToUserProfile(notification.fromUserId);
      } else if (type.contains('story')) {
        _navigateToUserProfile(notification.fromUserId);
      } else {
        // Default: navigate to feed screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewFeedScreen()),
        );
      }
    } catch (e) {
      log('Error navigating from notification: $e');
      AppToast.show('Could not open notification content', isError: true);
    }
  }

  /// Navigate to event details
  Future<void> _navigateToEvent(NotificationViewModel notification) async {
    try {
      // If eventId is available, find the event
      if (notification.eventId != null && notification.eventId!.isNotEmpty) {
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(notification.eventId)
            .get();
        
        if (eventDoc.exists) {
          final data = eventDoc.data()!;
          final latitude = data['latitude']?.toDouble();
          final longitude = data['longitude']?.toDouble();
          final eventName = data['eventName'] ?? 'Event';
          final address = data['address'] ?? '';
          
          if (latitude != null && longitude != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventMapScreen(
                  latitude: latitude,
                  longitude: longitude,
                  eventName: eventName,
                  eventAddress: address,
                ),
              ),
            );
            return;
          }
        }
      }
      
      // Fallback: Navigate to events screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EventsScreen()),
      );
    } catch (e) {
      log('Error navigating to event: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EventsScreen()),
      );
    }
  }

  /// Navigate to song player
  Future<void> _navigateToSong(NotificationViewModel notification) async {
    try {
      // If songId is available, find the song
      if (notification.songId != null && notification.songId!.isNotEmpty) {
        final songDoc = await FirebaseFirestore.instance
            .collection('songs')
            .doc(notification.songId)
            .get();
        
        if (songDoc.exists) {
          final data = songDoc.data()!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SongPlayerScreen(
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                fileUrl: data['url'] ?? data['fileUrl'] ?? '',
                coverImage: data['coverImage'] ?? data['coverImageUrl'] ?? '',
              ),
            ),
          );
          return;
        }
      }
      
      // Try to extract song name from message and search
      final message = notification.message;
      final songNameMatch = RegExp(r"'([^']+)'").firstMatch(message);
      if (songNameMatch != null) {
        final songName = songNameMatch.group(1);
        final songsSnapshot = await FirebaseFirestore.instance
            .collection('songs')
            .where('title', isEqualTo: songName)
            .limit(1)
            .get();
        
        if (songsSnapshot.docs.isNotEmpty) {
          final songData = songsSnapshot.docs.first.data();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SongPlayerScreen(
                title: songData['title'] ?? '',
                description: songData['description'] ?? '',
                fileUrl: songData['url'] ?? songData['fileUrl'] ?? '',
                coverImage: songData['coverImage'] ?? songData['coverImageUrl'] ?? '',
              ),
            ),
          );
          return;
        }
      }
      
      // Fallback: Navigate to feed
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    } catch (e) {
      log('Error navigating to song: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    }
  }

  /// Navigate to post or reel in feed
  Future<void> _navigateToPostOrReel(NotificationViewModel notification) async {
    try {
      final type = notification.type.toLowerCase();
      
      // Handle reel navigation
      if (type.contains('reel') && notification.reelId != null && notification.reelId!.isNotEmpty) {
        await _navigateToSpecificReel(notification.reelId!);
        return;
      }
      
      // Handle post navigation - scrolls to exact post index
      if (type.contains('post') && notification.postId != null && notification.postId!.isNotEmpty) {
        log('📝 Navigating to post ${notification.postId} from notification');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewFeedScreen(initialPostId: notification.postId),
          ),
        );
        return;
      }
      
      // Fallback: Navigate to feed screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    } catch (e) {
      log('Error navigating to post/reel: $e');
      AppToast.show('Could not open post/reel', isError: true);
    }
  }

  /// Navigate to a specific reel by ID - finds exact index
  Future<void> _navigateToSpecificReel(String reelId) async {
    try {
      log('🎬 Navigating to reel $reelId from notification');
      
      // Fetch all reels to find the one we want
      final reelsSnapshot = await FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true)
          .get();
      
      if (reelsSnapshot.docs.isEmpty) {
        log('⚠️ No reels found in database');
        AppToast.show('Reel not found', isError: true);
        return;
      }
      
      // Find the exact index of the reel with matching ID
      final docs = reelsSnapshot.docs;
      final reelIndex = docs.indexWhere((doc) => doc.id == reelId);
      
      if (reelIndex == -1) {
        log('⚠️ Reel $reelId not found in feed, navigating to first reel');
        // Navigate to reels screen anyway (at index 0)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelsScreen(
              showBackButton: true,
              reelsList: docs,
              initialReelIndex: 0,
            ),
          ),
        );
        return;
      }
      
      log('✅ Found reel at exact index: $reelIndex out of ${docs.length} reels');
      
      // Navigate to ReelsScreen with the specific reel at the exact found index
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsScreen(
            showBackButton: true,
            reelsList: docs,
            initialReelIndex: reelIndex, // Exact index
          ),
        ),
      );
      
      log('✅ Navigated to reel $reelId at exact index $reelIndex');
    } catch (e) {
      log('❌ Error navigating to specific reel: $e');
      AppToast.show('Error opening reel: $e', isError: true);
      // Fallback: Navigate to reels screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReelsScreen(showBackButton: true),
        ),
      );
    }
  }

  /// Navigate to comment screen
  Future<void> _navigateToComment(NotificationViewModel notification) async {
    try {
      final postId = notification.postId;
      if (postId != null && postId.isNotEmpty) {
        log('💬 Navigating to comment on post $postId');
        // Get post owner ID if available
        String? postOwnerId;
        try {
          final postDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();
          if (postDoc.exists) {
            postOwnerId = postDoc.data()?['userId'];
          }
        } catch (e) {
          log('Error fetching post owner: $e');
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommentScreen(
              postId: postId,
              postOwnerId: postOwnerId,
            ),
          ),
        );
      } else {
        // Fallback to user profile
        _navigateToUserProfile(notification.fromUserId);
      }
    } catch (e) {
      log('Error navigating to comment: $e');
      AppToast.show('Could not open comment', isError: true);
    }
  }

  /// Navigate to user profile
  void _navigateToUserProfile(String userId) {
    openUserProfile(context, userId);
  }

  Widget _buildNotificationItem(
      NotificationViewModel notification, bool isNew) {
    const accent = Color(0xFFBB86FC);
    final icon = _getNotificationIcon(notification.type);
    
    // Format time ago
    String timeAgo = '';
    try {
      final dateTime = DateTime.parse(notification.createdAt);
      timeAgo = timeago.format(dateTime, locale: 'en_short');
    } catch (e) {
      try {
        timeAgo = DateFormat.yMMMd().add_jm().format(
          DateTime.parse(notification.createdAt),
        );
      } catch (_) {
        timeAgo = 'Recently';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification, isNew),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isNew ? accent.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar or icon
              GestureDetector(
                onTap: () => _navigateToUserProfile(notification.fromUserId),
                child: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isNew
                            ? accent.withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: isNew
                            ? Border.all(color: accent.withOpacity(0.3), width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isNew ? accent : Colors.white70,
                        size: 24,
                      ),
                    ),
                    if (isNew)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isNew ? 0.95 : 0.85),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: isNew ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        if (notification.fromUserName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              notification.fromUserName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onPressed: () => _showDeleteConfirmation(notification.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                tooltip: 'Delete notification',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String notificationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkBackgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Notification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this notification?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNotification(notificationId);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
