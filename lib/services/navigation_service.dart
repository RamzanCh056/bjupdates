import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/New Feed/new_feed.dart';
import '../screens/new_reels.dart';
import '../screens/event_screens/event_screen.dart';
import '../screens/event_screens/event_map_screen.dart';
import '../screens/home1/song_player_screen.dart';
import '../screens/view_user_profile_screen.dart';
import '../screens/notification/notification.dart';
import '../utils/app_toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NavigationService {
  static const String _pendingNavigationKey = 'pending_notification_navigation';

  /// Handle notification navigation based on data payload
  static Future<void> handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      log('🧭 Handling notification navigation with data: $data');
      
      final type = (data['type'] ?? '').toString().toLowerCase();
      final context = navigatorKey.currentContext;
      
      if (context == null) {
        log('⚠️ Navigator context is null, storing navigation for later');
        await _storePendingNavigation(data);
        return;
      }

      // Wait a bit for the app to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      if (type.contains('event')) {
        await _navigateToEvent(context, data);
      } else if (type.contains('song')) {
        await _navigateToSong(context, data);
      } else if (type.contains('reel')) {
        await _navigateToReel(context, data);
      } else if (type.contains('post')) {
        await _navigateToPost(context, data);
      } else if (type.contains('comment') || type.contains('reply')) {
        await _navigateToComment(context, data);
      } else if (type.contains('follow') || type.contains('message')) {
        _navigateToUserProfile(context, data);
      } else if (type.contains('story')) {
        _navigateToUserProfile(context, data);
      } else {
        // Default: navigate to notifications screen
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
      }
    } catch (e) {
      log('❌ Error handling notification navigation: $e');
      final context = navigatorKey.currentContext;
      if (context != null) {
        AppToast.show('Could not open notification', isError: true);
      }
    }
  }

  /// Navigate to event
  static Future<void> _navigateToEvent(BuildContext context, Map<String, dynamic> data) async {
    try {
      final eventId = data['eventId'] ?? data['event_id'];
      if (eventId != null && eventId.toString().isNotEmpty) {
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId.toString())
            .get();
        
        if (eventDoc.exists) {
          final eventData = eventDoc.data()!;
          final latitude = eventData['latitude']?.toDouble();
          final longitude = eventData['longitude']?.toDouble();
          final eventName = eventData['eventName'] ?? 'Event';
          final address = eventData['address'] ?? '';
          
          if (latitude != null && longitude != null) {
            Navigator.of(context).push(
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
      
      // Fallback to events screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EventsScreen()),
      );
    } catch (e) {
      log('Error navigating to event: $e');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EventsScreen()),
      );
    }
  }

  /// Navigate to song
  static Future<void> _navigateToSong(BuildContext context, Map<String, dynamic> data) async {
    try {
      final songId = data['songId'] ?? data['song_id'];
      if (songId != null && songId.toString().isNotEmpty) {
        final songDoc = await FirebaseFirestore.instance
            .collection('songs')
            .doc(songId.toString())
            .get();
        
        if (songDoc.exists) {
          final songData = songDoc.data()!;
          Navigator.of(context).push(
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
      
      // Fallback to feed
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    } catch (e) {
      log('Error navigating to song: $e');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    }
  }

  /// Navigate to specific reel by exact index
  static Future<void> _navigateToReel(BuildContext context, Map<String, dynamic> data) async {
    try {
      final reelId = data['reelId'] ?? data['reel_id'];
      if (reelId != null && reelId.toString().isNotEmpty) {
        log('🎬 Navigating to reel: $reelId');
        
        final reelsSnapshot = await FirebaseFirestore.instance
            .collection('reels')
            .orderBy('timestamp', descending: true)
            .get();
        
        if (reelsSnapshot.docs.isNotEmpty) {
          final docs = reelsSnapshot.docs;
          final reelIndex = docs.indexWhere((doc) => doc.id == reelId.toString());
          
          if (reelIndex >= 0) {
            log('✅ Found reel at exact index: $reelIndex out of ${docs.length} reels');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReelsScreen(
                  showBackButton: true,
                  reelsList: docs,
                  initialReelIndex: reelIndex, // Exact index
                ),
              ),
            );
            return;
          } else {
            log('⚠️ Reel $reelId not found in feed, navigating to first reel');
          }
        } else {
          log('⚠️ No reels found in database');
        }
      }
      
      // Fallback to reels screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReelsScreen(showBackButton: true),
        ),
      );
    } catch (e) {
      log('❌ Error navigating to reel: $e');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReelsScreen(showBackButton: true),
        ),
      );
    }
  }

  /// Navigate to specific post by exact index
  static Future<void> _navigateToPost(BuildContext context, Map<String, dynamic> data) async {
    try {
      final postId = data['postId'] ?? data['post_id'];
      if (postId != null && postId.toString().isNotEmpty) {
        log('📝 Navigating to post: $postId');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewFeedScreen(
              initialPostId: postId.toString(),
            ),
          ),
        );
      } else {
        log('⚠️ No postId provided, navigating to feed');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewFeedScreen()),
        );
      }
    } catch (e) {
      log('❌ Error navigating to post: $e');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    }
  }

  /// Navigate to comment screen
  static Future<void> _navigateToComment(BuildContext context, Map<String, dynamic> data) async {
    try {
      final postId = data['postId'] ?? data['post_id'];
      
      if (postId != null && postId.toString().isNotEmpty) {
        // Navigate to feed first, then open comments
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewFeedScreen(
              initialPostId: postId.toString(),
            ),
          ),
        );
        // Note: Opening comment screen would require additional implementation
        // For now, it navigates to the post
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewFeedScreen()),
        );
      }
    } catch (e) {
      log('Error navigating to comment: $e');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewFeedScreen()),
      );
    }
  }

  /// Navigate to user profile
  static void _navigateToUserProfile(BuildContext context, Map<String, dynamic> data) {
    try {
      final userId = data['fromUserId'] ?? data['from_user_id'] ?? data['userId'];
      if (userId != null && userId.toString().isNotEmpty) {
        openUserProfile(context, userId.toString());
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
      }
    } catch (e) {
      log('Error navigating to user profile: $e');
    }
  }

  /// Store pending navigation data (for terminated state)
  static Future<void> _storePendingNavigation(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingNavigationKey, jsonEncode(data));
      log('💾 Stored pending navigation: $data');
    } catch (e) {
      log('Error storing pending navigation: $e');
    }
  }

  /// Check and handle pending navigation (called on app start)
  static Future<void> checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString(_pendingNavigationKey);
      
      if (pendingData != null) {
        log('📬 Found pending navigation, processing...');
        final data = jsonDecode(pendingData) as Map<String, dynamic>;
        await prefs.remove(_pendingNavigationKey);
        
        // Wait for app to be ready
        await Future.delayed(const Duration(seconds: 2));
        await handleNotificationNavigation(data);
      }
    } catch (e) {
      log('Error checking pending navigation: $e');
    }
  }
}
