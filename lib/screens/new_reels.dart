import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/Stripe/SubscriptionHelper.dart';
import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:beatjerky/screens/create_video_screen_1.dart';
import 'package:beatjerky/utils/app_sizes.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/widgets/shared_comment_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import 'dart:developer';
import '../services/music_service.dart';
import '../notification_services/trigger_notification_services.dart';
import 'view_user_profile_screen.dart';
import 'reel_instagram/reel_camera_capture_screen.dart';
import '../utils/reel_video_spec.dart';

class ReelsScreen extends StatefulWidget {
  final bool showBackButton;

  /// When provided, show this fixed list (e.g. from My Feed grid tap). No All/My Feed tabs.
  final List<QueryDocumentSnapshot>? reelsList;

  /// Initial index when reelsList is provided.
  final int? initialReelIndex;

  const ReelsScreen({
    Key? key,
    this.showBackButton = false,
    this.reelsList,
    this.initialReelIndex,
  }) : super(key: key);

  @override
  _ReelsScreenState createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  Map<String, bool> _likedVideos = {};
  Map<String, int> _likeCounts = {};
  // Prevent multiple rapid like/unlike requests for the same reel
  Map<String, bool> _likeInProgress = {};
  late PreloadPageController _pageController;
  int _currentIndex = 0;
  Map<int, GlobalKey<_VideoPlayerWidgetState>> _videoKeys = {};
  /// When true, upload-options sheet is open or user is in create flow: no feed video should play in background.
  bool _uploadOptionsSheetOpen = false;
  /// 0 = All Feed, 1 = My Feed (only when widget.reelsList == null)
  int _feedTabIndex = 0;

  /// Current reels list used by PageView (so we can record view on page change)
  List<QueryDocumentSnapshot>? _currentReelsDocs;

  final SubscriptionServicefull _subscriptionService =
      SubscriptionServicefull();

  @override
  void initState() {
    super.initState();
    _pageController = PreloadPageController();
    if (widget.initialReelIndex != null && widget.initialReelIndex! > 0) {
      _currentIndex = widget.initialReelIndex!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(widget.initialReelIndex!);
        }
      });
    }
    _loadLikedVideos();
  }

  Future<void> _loadLikedVideos() async {
    String userId = _auth.currentUser?.uid ?? "unknown";
    final likedVideos = await _firestore
        .collection('reels')
        .where('likedBy', arrayContains: userId)
        .get();

    setState(() {
      for (var doc in likedVideos.docs) {
        _likedVideos[doc.id] = true;
      }
    });
  }

  Future<void> _toggleLike(String videoId) async {
    String userId = _auth.currentUser?.uid ?? "unknown";

    // If a like/unlike operation is already in-flight for this reel,
    // ignore extra taps so the count can't drift away from 0/1 per user.
    if (_likeInProgress[videoId] == true) return;

    setState(() {
      _likeInProgress[videoId] = true;
    });

    try {
      final reelRef = _firestore.collection('reels').doc(videoId);
      final reelSnapshot = await reelRef.get();

      if (!reelSnapshot.exists) return;

      final reelData = reelSnapshot.data()!;
      final ownerId = reelData['userId'];

      // Always determine like state from the latest data on the server
      // to avoid local desyncs or multiple rapid taps causing bad counts.
      final List<dynamic> likedBy =
          (reelData['likedBy'] as List<dynamic>?) ?? <dynamic>[];
      final bool isLikedOnServer = likedBy.contains(userId);

      if (isLikedOnServer) {
        // Unlike
        await _firestore.collection('reels').doc(videoId).update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likes': FieldValue.increment(-1),
        });
        setState(() {
          _likedVideos[videoId] = false;
        });

        await _deleteReelLikeNotification(
          fromUserId: userId,
          toUserId: ownerId,
          reelId: videoId,
        );
      } else {
        // Like
        await _firestore.collection('reels').doc(videoId).update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likes': FieldValue.increment(1),
        });
        setState(() {
          _likedVideos[videoId] = true;
        });

        // Send notification to reel owner
        await _sendReelLikeNotification(videoId);
      }
    } catch (e) {
      print("Error toggling like: $e");
    } finally {
      if (mounted) {
        setState(() {
          _likeInProgress[videoId] = false;
        });
      } else {
        _likeInProgress[videoId] = false;
      }
    }
  }
  @override
  void dispose() {
    _pageController.dispose();
    _releaseAllReelPlayers();
    super.dispose();
  }

  Future<void> _deleteReelLikeNotification({
    required String fromUserId,
    required String toUserId,
    required String reelId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(toUserId)
          .collection('userNotifications')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('reelId', isEqualTo: reelId)
          .where('type', isEqualTo: 'reel_like')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      log(
        'Deleted reel like notification from $fromUserId to $toUserId on reel $reelId',
      );
    } catch (e) {
      log('Error deleting reel like notification: $e');
    }
  }

  void _showComments(String videoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('reels').doc(videoId).get(),
          builder: (context, reelSnap) {
            final reelOwnerId = reelSnap.hasData
                ? reelSnap.data?.data() as Map<String, dynamic>?
                : null;
            final ownerId = reelOwnerId?['userId'] as String?;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('reels')
                  .doc(videoId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final isLoading = !snapshot.hasData;
                final comments = snapshot.hasData
                    ? snapshot.data!.docs
                          .map(
                            (d) => {
                              'id': d.id,
                              ...d.data() as Map<String, dynamic>,
                            },
                          )
                          .toList()
                    : <Map<String, dynamic>>[];

                return SharedCommentBottomSheet(
                  comments: comments,
                  isLoading: isLoading,
                  postOwnerId: ownerId,
                  fetchUserData: _fetchUserData,
                  onAddComment: (text) async {
                    await _addComment(videoId, text);
                  },
                  onAddReply: (parentCommentId, text) async {
                    await _addComment(
                      videoId,
                      text,
                      parentCommentId: parentCommentId,
                    );
                  },
                  onDeleteComment: (commentId, commentUserId) async {
                    await _deleteComment(videoId, commentId, commentUserId);
                  },
                  onEditComment: (commentId, newText) async {
                    await _editComment(videoId, commentId, newText);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteComment(
    String videoId,
    String commentId,
    String commentUserId,
  ) async {
    final currentUserId = _auth.currentUser?.uid ?? '';

    // Security check - verify the comment belongs to current user
    if (commentUserId != currentUserId) {
      AppToast.show(
        'You don\'t have permission to delete this comment',
        isError: true,
      );
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Comment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Double-check ownership on server side
        final commentDoc = await _firestore
            .collection('reels')
            .doc(videoId)
            .collection('comments')
            .doc(commentId)
            .get();

        if (!commentDoc.exists ||
            commentDoc.data()?['userId'] != currentUserId) {
          AppToast.show(
            'You don\'t have permission to delete this comment',
            isError: true,
          );
          return;
        }

        await _firestore
            .collection('reels')
            .doc(videoId)
            .collection('comments')
            .doc(commentId)
            .delete();

        // Now delete the related notification (if any)
        final reelDoc = await _firestore.collection('reels').doc(videoId).get();
        final reelOwnerId = reelDoc.data()?['userId'];

        if (reelOwnerId != null && reelOwnerId != currentUserId) {
          await _deleteReelCommentNotification(
            fromUserId: currentUserId,
            toUserId: reelOwnerId,
            reelId: videoId,
          );
        }

        AppToast.show('Comment deleted successfully');
      } catch (e) {
        AppToast.show('Error deleting comment: $e', isError: true);
      }
    }
  }

  Future<void> _deleteReelCommentNotification({
    required String fromUserId,
    required String toUserId,
    required String reelId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(toUserId)
          .collection('userNotifications')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('reelId', isEqualTo: reelId)
          .where('type', isEqualTo: 'reel_comment')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      log(
        'Deleted comment notification from $fromUserId to $toUserId on reel $reelId',
      );
    } catch (e) {
      log('Error deleting comment notification: $e');
    }
  }

  Future<void> _addComment(
    String videoId,
    String text, {
    String? parentCommentId,
  }) async {
    String userId = _auth.currentUser?.uid ?? "unknown";
    try {
      await _firestore
          .collection('reels')
          .doc(videoId)
          .collection('comments')
          .add({
            'userId': userId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'parentId': parentCommentId,
          });

      // Send notification to reel owner
      await _sendReelCommentNotification(videoId);

      // Additionally notify the parent comment owner if this is a reply
      if (parentCommentId != null && parentCommentId.isNotEmpty) {
        await _sendReelReplyNotification(
          videoId: videoId,
          parentCommentId: parentCommentId,
        );
      }
    } catch (e) {
      print("Error adding comment: $e");
    }
  }

  Future<void> _sendReelLikeNotification(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get reel data to find the reel owner
      final reelDoc = await _firestore.collection('reels').doc(videoId).get();

      if (!reelDoc.exists) return;

      final reelData = reelDoc.data();
      final reelOwnerId = reelData?['userId'] as String?;

      if (reelOwnerId == null) return;

      // Don't send notification if user is liking their own reel
      if (currentUser.uid == reelOwnerId) return;

      log("reelownerid $reelOwnerId");

      // Get current user's name for the notification
      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      // Get reel owner's FCM token
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(reelOwnerId)
          .get();

      final userData = userSnapshot.data();
      final targetToken = userData?['fcmToken'] as String?;

      if (targetToken != null && targetToken.isNotEmpty) {
        // Send push notification
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: targetToken,
          title: 'New Like on Reel! ❤️',
          body: '$currentUserName liked your reel',
        );
      } else {
        log('No FCM token found for user $reelOwnerId');
      }

      // Save notification to Firestore
      final notificationData = {
        'type': 'reel_like',
        'fromUserId': currentUser.uid,
        'fromUserName': currentUserName,
        'reelId': videoId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$currentUserName liked your reel',
        'isRead': false,
      };

      await _firestore
          .collection('notifications')
          .doc(reelOwnerId)
          .collection('userNotifications')
          .add(notificationData);

      log('Reel like notification sent and saved for $reelOwnerId');
    } catch (e) {
      log('Error sending reel like notification: $e');
    }
  }

  Future<void> _sendReelCommentNotification(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get reel data to find the reel owner
      final reelDoc = await _firestore.collection('reels').doc(videoId).get();

      if (!reelDoc.exists) return;

      final reelData = reelDoc.data();
      final reelOwnerId = reelData?['userId'] as String?;

      if (reelOwnerId == null) return;

      // Don't send notification if user is commenting on their own reel
      if (currentUser.uid == reelOwnerId) return;

      log("reelownerid $reelOwnerId");

      // Get current user's name for the notification
      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      // Get reel owner's FCM token
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(reelOwnerId)
          .get();

      final userData = userSnapshot.data();
      final targetToken = userData?['fcmToken'] as String?;

      if (targetToken != null && targetToken.isNotEmpty) {
        // Send push notification
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: targetToken,
          title: 'New Comment on Reel! 💬',
          body: '$currentUserName commented on your reel',
        );
      } else {
        log('No FCM token found for user $reelOwnerId');
      }
      // Save notification to Firestore
      final notificationData = {
        'type': 'reel_comment',
        'fromUserId': currentUser.uid,
        'fromUserName': currentUserName,
        'reelId': videoId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$currentUserName commented on your reel',
        'isRead': false,
      };

      await _firestore
          .collection('notifications')
          .doc(reelOwnerId)
          .collection('userNotifications')
          .add(notificationData);

      log('Reel comment notification sent and saved for $reelOwnerId');
    } catch (e) {
      log('Error sending reel comment notification: $e');
    }
  }

  Future<void> _sendReelReplyNotification({
    required String videoId,
    required String parentCommentId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final parentDoc = await _firestore
          .collection('reels')
          .doc(videoId)
          .collection('comments')
          .doc(parentCommentId)
          .get();
      if (!parentDoc.exists) return;

      final parentOwnerId = parentDoc.data()?['userId'] as String?;
      if (parentOwnerId == null || parentOwnerId == currentUser.uid) return;

      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      final ownerDoc = await _firestore
          .collection('usersData')
          .doc(parentOwnerId)
          .get();
      final fcmToken = ownerDoc.data()?['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: fcmToken,
          title: 'New reply 💬',
          body: '$currentUserName replied to your comment on a reel',
        );
      }

      await _firestore
          .collection('notifications')
          .doc(parentOwnerId)
          .collection('userNotifications')
          .add({
            'type': 'reel_comment_reply',
            'fromUserId': currentUser.uid,
            'fromUserName': currentUserName,
            'reelId': videoId,
            'parentCommentId': parentCommentId,
            'timestamp': FieldValue.serverTimestamp(),
            'message': '$currentUserName replied to your comment on a reel',
            'isRead': false,
          });
    } catch (e) {
      log('Error sending reel reply notification: $e');
    }
  }

  Future<void> _sendNewReelNotificationToAllUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get current user's name for the notification
      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      // Get all users from usersData collection
      final usersSnapshot = await _firestore.collection('usersData').get();

      final trigger = TriggerNotificationService();
      int notificationCount = 0;

      // Send notification to each user (except current user)
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        // Skip current user
        if (userId == currentUser.uid) continue;

        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            // Send push notification
            await trigger.sendPushNotification(
              token: fcmToken,
              title: 'New Reel Available! 🎬',
              body: '$currentUserName just uploaded a new reel',
            );
          } catch (e) {
            log('Error sending notification to user $userId: $e');
          }
        }
        // Save notification to Firestore
        final notificationData = {
          'type': 'new_reel',
          'fromUserId': currentUser.uid,
          'fromUserName': currentUserName,
          'timestamp': FieldValue.serverTimestamp(),
          'message': '$currentUserName just uploaded a new reel',
          'isRead': false,
        };

        await _firestore
            .collection('notifications')
            .doc(userId)
            .collection('userNotifications')
            .add(notificationData);

        notificationCount++;
      }

      log('New reel notification sent to $notificationCount users');
    } catch (e) {
      log('Error sending new reel notifications: $e');
    }
  }

  /// Pause all feed reels immediately (e.g. when add/upload sheet opens).
  void _pauseAllReelPlayers() {
    for (final key in _videoKeys.values) {
      key.currentState?.pauseVideo();
    }
  }

  /// Release all reel players so only one ExoPlayer is active (editor or preview). Prevents OOM.
  void _releaseAllReelPlayers() {
    for (final key in _videoKeys.values) {
      key.currentState?.releasePlayer();
    }
  }

  /// When muteOriginalVideo is true, original voice must be muted (0). Otherwise use saved videoVolume.
  double? _reelVideoVolume(Map<String, dynamic> data) {
    if (data['muteOriginalVideo'] == true) return 0.0;
    return (data['videoVolume'] as num?)?.toDouble();
  }

  Future<void> _editComment(
    String videoId,
    String commentId,
    String newText,
  ) async {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final trimmedText = newText.trim();
    if (currentUserId.isEmpty || trimmedText.isEmpty) return;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('reels')
          .doc(videoId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists || commentDoc.data()?['userId'] != currentUserId) {
        AppToast.show(
          "You don't have permission to edit this comment",
          isError: true,
        );
        return;
      }

      await commentRef.update({'text': trimmedText});
      AppToast.show('Comment updated');
    } catch (e) {
      AppToast.show('Error updating comment: $e', isError: true);
    }
  }

  void _handleVideoMenuSelection(
    String value,
    Map<String, dynamic> videoData,
    String videoId,
  ) {
    switch (value) {
      case 'edit':
        _showEditVideoDialog(videoData, videoId);
        break;
      case 'delete':
        _showDeleteConfirmation(videoData, videoId);
        break;
      case 'report':
        _showReportOptions(videoData, videoId);
        break;
    }
  }

  void _showEditVideoDialog(Map<String, dynamic> videoData, String videoId) {
    final TextEditingController descriptionController = TextEditingController(
      text: _getVideoDescriptionFromMap(videoData),
    );
    final String? existingCoverUrl = videoData['coverUrl'] as String?;
    // Hold selected cover in a list so StatefulBuilder can update and show it in the dialog
    final List<File?> selectedCover = [null];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFBB86FC).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        title: const Text(
          'Edit cover & caption',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final coverFile = selectedCover[0];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cover photo section
                    Text(
                      'Cover photo',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBB86FC).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: coverFile != null
                              ? Image.file(coverFile, fit: BoxFit.cover)
                              : (existingCoverUrl != null &&
                                    existingCoverUrl.isNotEmpty)
                              ? Image.network(
                                  existingCoverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _editCoverPlaceholder(),
                                )
                              : _editCoverPlaceholder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final XFile? img = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1080,
                              imageQuality: 85,
                            );
                            if (img != null) {
                              selectedCover[0] = File(img.path);
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Color(0xFFBB86FC),
                            size: 20,
                          ),
                          label: Text(
                            coverFile != null
                                ? 'Change cover'
                                : 'Add / Change cover',
                            style: const TextStyle(
                              color: Color(0xFFBB86FC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (coverFile != null)
                          TextButton.icon(
                            onPressed: () {
                              selectedCover[0] = null;
                              setDialogState(() {});
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Caption section
                    Text(
                      'Caption',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0A0E27).withOpacity(0.5),
                            const Color(0xFF16213E).withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFBB86FC).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: descriptionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Caption...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFBB86FC),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> updates = {
                    'description': descriptionController.text.trim(),
                  };

                  final coverFile = selectedCover[0];
                  if (coverFile != null) {
                    final coverFileName =
                        "reel_covers/${_auth.currentUser?.uid ?? 'unknown'}/${DateTime.now().millisecondsSinceEpoch}.jpg";
                    final coverRef = _storage.ref(coverFileName);
                    await coverRef.putFile(coverFile);
                    updates['coverUrl'] = await coverRef.getDownloadURL();
                  }

                  await _firestore
                      .collection('reels')
                      .doc(videoId)
                      .update(updates);
                  Navigator.pop(context);
                  AppToast.show('Cover & caption updated!');
                } catch (e) {
                  AppToast.show('Error updating: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Update',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editCoverPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'No cover',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> videoData, String videoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // Delete from Firestore
                  await _firestore.collection('reels').doc(videoId).delete();

                  // Delete from Storage (optional - you might want to keep the file)
                  // await _storage.refFromURL(videoData['videoUrl']).delete();

                  Navigator.pop(context);
                  AppToast.show('Video deleted successfully!');
                } catch (e) {
                  AppToast.show('Error deleting video: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportOptions(Map<String, dynamic> videoData, String videoId) {
    String selectedReason = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.report_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Report Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please select a reason for reporting:',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text(
                    'Inappropriate content',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  value: 'inappropriate',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  activeColor: const Color(0xFFBB86FC),
                ),
                RadioListTile<String>(
                  title: const Text(
                    'Violence',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  value: 'violence',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  activeColor: const Color(0xFFBB86FC),
                ),
                RadioListTile<String>(
                  title: const Text(
                    'Spam',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  value: 'spam',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  activeColor: const Color(0xFFBB86FC),
                ),
                RadioListTile<String>(
                  title: const Text(
                    'Other',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  value: 'other',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  activeColor: const Color(0xFFBB86FC),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: appGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: selectedReason.isEmpty
                      ? null
                      : () async {
                          try {
                            // Save report to Firestore
                            await _firestore.collection('reports').add({
                              'videoId': videoId,
                              'reportedBy': _auth.currentUser?.uid,
                              'reason': selectedReason,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            Navigator.pop(context);
                            _showReportConfirmation();
                          } catch (e) {
                            AppToast.show(
                              'Error reporting video: $e',
                              isError: true,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReportConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green.withOpacity(0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Report Submitted',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Thank you for your report. We will review it and take appropriate action.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Upload reel to server and save metadata: user_id, reel_id, caption, music_id, video_url, thumbnail_url, duration, created_at.
  /// Returns the new Firestore document id so the feed can scroll to this reel.
  Future<String?> _saveVideoToFirestore(
    String videoUrl,
    String description, {
    Map<String, dynamic>? editData,
    String? coverUrl,
  }) async {
    String userId = _auth.currentUser?.uid ?? "unknown";

    final now = FieldValue.serverTimestamp();
    Map<String, dynamic> videoData = {
      'userId': userId,
      'videoUrl': videoUrl,
      'description': description.isNotEmpty ? description : null,
      'likes': 0,
      'likedBy': <String>[],
      'views': 0,
      'public': true,
      'timestamp': now,
      'createdAt': now,
    };

    if (coverUrl != null && coverUrl.isNotEmpty) {
      videoData['coverUrl'] = coverUrl;
      videoData['thumbnailUrl'] = coverUrl;
    }

    if (editData != null) {
      final trimEndMs = (editData['trimEndMs'] as num?)?.toDouble();
      final trimStartMs = (editData['trimStartMs'] as num?)?.toDouble();
      if (trimEndMs != null && trimStartMs != null && trimEndMs > trimStartMs) {
        videoData['duration'] = ((trimEndMs - trimStartMs) / 1000.0).round();
      }

      if (editData['music'] != null) {
        Map<String, dynamic> musicData = Map<String, dynamic>.from(
          editData['music'] as Map<String, dynamic>,
        );
        String? audioUrl = (musicData['audioUrl'] ?? musicData['musicUrl'])?.toString().trim();
        if (audioUrl != null && audioUrl.isNotEmpty) {
          final isLocalFile = !audioUrl.startsWith('http://') && !audioUrl.startsWith('https://');
          if (isLocalFile) {
            try {
              final file = File(audioUrl);
              if (await file.exists()) {
                final musicFileName =
                    'reel_music/${userId}/${DateTime.now().millisecondsSinceEpoch}.mp3';
                final ref = _storage.ref(musicFileName);
                await ref.putFile(file);
                final downloadUrl = await ref.getDownloadURL();
                audioUrl = downloadUrl;
                musicData['audioUrl'] = downloadUrl;
                musicData['musicUrl'] = downloadUrl;
              }
            } catch (e) {
              debugPrint('Reel: failed to upload local music: $e');
            }
          }
          musicData['audioUrl'] = audioUrl;
          musicData['musicUrl'] = audioUrl;
        }
        videoData['music'] = musicData;
        final musicId = musicData['id']?.toString();
        if (musicId != null && musicId.isNotEmpty) {
          videoData['musicId'] = musicId;
        }
        videoData['musicVolume'] = editData['musicVolume'];
        videoData['videoVolume'] = editData['videoVolume'];
        if (editData['muteOriginalVideo'] == true) {
          videoData['muteOriginalVideo'] = true;
          videoData['videoVolume'] = 0.0;
        }

        if (musicId != null &&
            musicId.isNotEmpty &&
            !musicId.startsWith('temp_') &&
            !musicId.startsWith('uploaded_')) {
          await MusicService.incrementUseCount(musicId);
        }
      }

      if (editData['filter'] != null &&
          editData['filter'] != 'None' &&
          editData['filter'] != 'Normal') {
        videoData['filter'] = editData['filter'];
      }

      if (editData['caption'] != null &&
          editData['caption'] is Map &&
          (editData['caption']['text'] as String?)?.trim().isNotEmpty == true) {
        videoData['caption'] = editData['caption'];
      }

      final stickersRaw = editData['stickers'];
      if (stickersRaw is List && stickersRaw.isNotEmpty) {
        final normalized = <Map<String, dynamic>>[];
        for (final e in stickersRaw) {
          if (e is Map<String, dynamic>) {
            normalized.add(e);
          } else if (e is Map) {
            normalized.add(Map<String, dynamic>.from(e));
          }
        }
        if (normalized.isNotEmpty) {
          videoData['stickers'] = normalized;
        }
      }

      final loc = editData['location']?.toString().trim();
      if (loc != null && loc.isNotEmpty) {
        videoData['location'] = loc;
      }
      final tagged = editData['taggedPeople']?.toString().trim();
      if (tagged != null && tagged.isNotEmpty) {
        videoData['taggedPeople'] = tagged;
      }
      final audioTitle = editData['audioDisplayTitle']?.toString().trim();
      if (audioTitle != null && audioTitle.isNotEmpty) {
        videoData['audioDisplayTitle'] = audioTitle;
      }
      final aud = editData['audience']?.toString();
      if (aud != null && aud.isNotEmpty) {
        videoData['audience'] = aud;
        videoData['public'] = aud != 'private';
      }
      if (editData['aiContentLabel'] == true) {
        videoData['aiContentLabel'] = true;
      }
    }

    try {
      final docRef = await _firestore.collection('reels').add(videoData);
      await docRef.update({'reelId': docRef.id});
      print("Video successfully saved! reelId=${docRef.id}");
      _sendNewReelNotificationToAllUsers();
      return docRef.id;
    } catch (error) {
      print("Error saving video: $error");
      rethrow;
    }
  }

  /// After posting, show All Feed and jump to the new reel once the stream includes it.
  void _focusUploadedReel(String reelId) {
    if (!mounted || reelId.isEmpty) return;
    if (widget.reelsList != null) {
      final idx = widget.reelsList!.indexWhere((d) => d.id == reelId);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(idx);
          setState(() => _currentIndex = idx);
        });
      }
      return;
    }
    setState(() {
      _feedTabIndex = 0;
      _uploadOptionsSheetOpen = false;
    });
    void tryScroll(int attempt) {
      if (!mounted) return;
      final docs = _currentReelsDocs;
      if (docs != null && _pageController.hasClients) {
        final idx = docs.indexWhere((d) => d.id == reelId);
        if (idx >= 0) {
          _pageController.jumpToPage(idx);
          setState(() => _currentIndex = idx);
          return;
        }
      }
      if (attempt < 20) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          tryScroll(attempt + 1);
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll(0));
  }

  List<Map<String, dynamic>>? _stickersListFromReelData(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out.isEmpty ? null : out;
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    DocumentSnapshot userDoc = await _firestore
        .collection('usersData')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // Helper method to build profile image with proper validation
  ImageProvider<Object>? _buildProfileImage(String? profileImg) {
    if (profileImg == null ||
        profileImg.isEmpty ||
        !profileImg.startsWith('http') ||
        profileImg.contains('file:///')) {
      return null;
    }

    try {
      return NetworkImage(profileImg);
    } catch (e) {
      print("Error loading profile image: $e");
      return null;
    }
  }

  // Helper method to determine if profile icon should be shown
  bool _shouldShowProfileIcon(String? profileImg) {
    return profileImg == null ||
        profileImg.isEmpty ||
        !profileImg.startsWith('http') ||
        profileImg.contains('file:///');
  }

  // Helper method to safely get video description
  String _getVideoDescription(dynamic data) {
    try {
      final description = data['description'];
      if (description == null) return '';
      return description.toString().trim();
    } catch (e) {
      print("Error getting video description: $e");
      return '';
    }
  }

  // Helper method to safely get video description from Map
  String _getVideoDescriptionFromMap(Map<String, dynamic> videoData) {
    try {
      final description = videoData['description'];
      if (description == null) return '';
      return description.toString().trim();
    } catch (e) {
      print("Error getting video description from map: $e");
      return '';
    }
  }

  // Helper method to safely check if document has music data
  bool _hasMusicData(dynamic data) {
    try {
      if (data is! Map<String, dynamic>) return false;
      final musicData = data['music'];
      if (musicData == null) return false;
      if (musicData is! Map<String, dynamic>) return false;
      return musicData['title'] != null &&
          musicData['title'].toString().isNotEmpty;
    } catch (e) {
      print("Error checking music data: $e");
      return false;
    }
  }

  // Helper method to safely get music title
  String _getMusicTitle(dynamic data) {
    try {
      if (data is! Map<String, dynamic>) return 'Music';
      final musicData = data['music'];
      if (musicData == null || musicData is! Map<String, dynamic>)
        return 'Music';
      return musicData['title']?.toString() ?? 'Music';
    } catch (e) {
      print("Error getting music title: $e");
      return 'Music';
    }
  }

  /// Record view: others' reels = every time; own reels = once (viewCountedByOwner).
  Future<void> _recordReelView(String reelId, String? ownerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || ownerId == null) return;
    final isOwnReel = ownerId == currentUser.uid;

    if (isOwnReel) {
      try {
        final reelRef = _firestore.collection('reels').doc(reelId);
        final doc = await reelRef.get();
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;
        final alreadyCounted = data['viewCountedByOwner'] == true;
        if (alreadyCounted) return;
        await _firestore.runTransaction((transaction) async {
          transaction.update(reelRef, {
            'views': FieldValue.increment(1),
            'viewCountedByOwner': true,
          });
        });
      } catch (_) {}
      return;
    }

    try {
      await _firestore.collection('reels').doc(reelId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  void _handlePageChanged(int index) {
    print("📱 Page changed to index: $index");

    if (_currentReelsDocs != null && index < _currentReelsDocs!.length) {
      final skipInitialZero =
          widget.initialReelIndex != null &&
          widget.initialReelIndex! > 0 &&
          index == 0 &&
          _currentIndex == 0;
      if (!skipInitialZero) {
        final doc = _currentReelsDocs![index];
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          _recordReelView(doc.id, data['userId'] as String?);
        }
      }
    }

    // Pause previous video
    if (_videoKeys.containsKey(_currentIndex)) {
      final previousVideoKey = _videoKeys[_currentIndex];
      previousVideoKey?.currentState?.pauseVideo();
    }

    // Update current index
    setState(() {
      _currentIndex = index;
    });

    // Play current video
    if (_videoKeys.containsKey(index)) {
      final currentVideoKey = _videoKeys[index];
      currentVideoKey?.currentState?.playVideo();
    }
  }

  /// Reels feed add: opens in-app reel camera (live preview + gallery + record).
  Future<void> _showUploadOptions() async {
    if (kDebugMode) {
      debugPrint('[ReelFeed] add icon → ReelCameraCaptureScreen');
    }
    setState(() => _uploadOptionsSheetOpen = true);
    _pauseAllReelPlayers();
    _releaseAllReelPlayers();

    String? reelId;
    try {
      reelId = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => ReelCameraCaptureScreen(
            storage: _storage,
            auth: _auth,
            firestore: _firestore,
            saveToFirestore: _saveVideoToFirestore,
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _uploadOptionsSheetOpen = false);
      if (reelId != null && reelId.isNotEmpty) {
        _focusUploadedReel(reelId);
      }
    }
  }

  Widget _buildFeedSegment(BuildContext context) {
    final paddingV = responsiveHeight(14, context);
    final dividerW = responsiveWidth(32, context);
    final dividerH = responsiveHeight(16, context);
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(vertical: paddingV),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _feedTabButton(context, 'All Feed', 0),
          SizedBox(
            width: dividerW,
            child: Center(
              child: Container(
                height: dividerH,
                width: 1,
                color: Colors.white24,
              ),
            ),
          ),
          _feedTabButton(context, 'My Feed', 1),
        ],
      ),
    );
  }

  Widget _feedTabButton(BuildContext context, String label, int index) {
    final selected = _feedTabIndex == index;
    final fontSize = responsiveHeight(17, context).clamp(14.0, 22.0);
    final underlineW = responsiveWidth(28, context).clamp(20.0, 40.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _feedTabIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withOpacity(0.5),
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          SizedBox(height: responsiveHeight(6, context)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 2.5,
            width: selected ? underlineW : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyFeedShimmer(BuildContext context) {
    final crossAxisCount = _reelsGridCrossAxisCount(context);
    final spacing = responsiveWidth(6, context);
    final marginH = responsiveWidth(16, context);
    final chipW = responsiveWidth(64, context);
    final chipH = responsiveHeight(48, context);
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[700]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: responsiveHeight(12, context)),
          Container(
            margin: EdgeInsets.fromLTRB(
              marginH,
              responsiveHeight(48, context),
              marginH,
              responsiveHeight(20, context),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (_) => Container(
                  width: chipW,
                  height: chipH,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: marginH,
                vertical: responsiveHeight(12, context),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.75,
              ),
              itemCount: crossAxisCount * 3,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsDashboard(
    BuildContext context,
    List<QueryDocumentSnapshot> allDocs,
    String currentUserId,
  ) {
    final myReels = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['userId'] as String?) == currentUserId;
    }).toList();
    int totalLikes = 0;
    int totalViews = 0;
    for (var doc in myReels) {
      final data = doc.data() as Map<String, dynamic>?;
      final likedBy = data?['likedBy'];
      if (likedBy is List && likedBy.isNotEmpty) {
        totalLikes += likedBy.length;
      } else {
        final likesField = data?['likes'];
        if (likesField is int) totalLikes += likesField;
      }
      totalViews += (data?['views'] as int?) ?? 0;
    }
    final marginH = responsiveWidth(16, context);
    final marginV = responsiveHeight(14, context);
    final topSpace = responsiveHeight(78, context);
    final bottomMargin = responsiveHeight(20, context);
    final padding = responsiveWidth(20, context);
    return Container(
      margin: EdgeInsets.fromLTRB(marginH, topSpace, marginH, bottomMargin),
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 1.1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2847),
            const Color(0xFF1A2847).withOpacity(0.95),
            const Color(0xFF162038),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFBB86FC).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: marginV),
            child: Text(
              'Your insight',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: responsiveHeight(15, context).clamp(13.0, 18.0),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _insightChip(
                context,
                Icons.videocam_rounded,
                '${myReels.length}',
                'Reels',
              ),
              _insightChip(
                context,
                Icons.favorite_rounded,
                '$totalLikes',
                'Likes',
              ),
              _insightChip(
                context,
                Icons.visibility_rounded,
                '$totalViews',
                'Views',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _insightChip(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final iconSize = responsiveWidth(24, context).clamp(20.0, 32.0);
    final valueSize = responsiveHeight(18, context).clamp(16.0, 22.0);
    final labelSize = responsiveHeight(12, context).clamp(11.0, 14.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFBB86FC), size: iconSize),
        SizedBox(height: responsiveHeight(4, context)),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: labelSize,
          ),
        ),
      ],
    );
  }

  Widget _buildMyFeedBody(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Center(
        child: Text(
          'Sign in to see your reels',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: responsiveHeight(16, context),
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reels')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(responsiveWidth(24, context)),
              child: Text(
                'Could not load your reels. Pull down to retry.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: responsiveHeight(16, context),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return _buildMyFeedShimmer(context);
        }
        final rawDocs = snapshot.data!.docs;
        final docs = List<QueryDocumentSnapshot>.from(rawDocs)
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>?)?['timestamp'];
            final bTs = (b.data() as Map<String, dynamic>?)?['timestamp'];
            final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
            final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
            return bMs.compareTo(aMs);
          });
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Upload your first reel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: responsiveHeight(16, context),
              ),
            ),
          );
        }
        final crossAxisCount = _reelsGridCrossAxisCount(context);
        final spacing = responsiveWidth(6, context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: responsiveHeight(12, context)),
            _buildInsightsDashboard(context, docs, userId),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: responsiveWidth(16, context),
                  vertical: responsiveHeight(12, context),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: 0.75,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index];
                  final map = data.data() as Map<String, dynamic>?;
                  final videoUrl = map?['videoUrl'] as String? ?? '';
                  final coverUrl = map?['coverUrl'] as String? ?? '';
                  final thumbnailUrl = coverUrl.isNotEmpty
                      ? coverUrl
                      : videoUrl;
                  final views = (map?['views'] as int?) ?? 0;
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReelsScreen(
                            showBackButton: true,
                            reelsList: docs,
                            initialReelIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: thumbnailUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.videocam_off,
                                      color: Colors.white54,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.videocam_off,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatViewCount(views),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.reelsList != null) {
      return _buildReelsPageView(context, widget.reelsList!);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _feedTabIndex == 0
              ? _buildAllFeedBody(context)
              : _buildMyFeedBody(context),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              color: Colors.transparent,
              child: _buildFeedSegment(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllFeedBody(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reels')
          .where('public', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E27), Color(0xFF16213E)],
              ),
            ),
          );
        }
        // Don't schedule playVideo here — visibility (isVisible) and _handlePageChanged handle play/pause.
        // Repeated callbacks on every stream rebuild caused stuck/repeated pause-play behavior.
        return _buildReelsPageView(context, snapshot.data!.docs);
      },
    );
  }

  int _reelsGridCrossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 900) return 5;
    if (w > 600) return 4;
    return 3;
  }

  /// Safe URL string for Firestore `videoUrl` (avoids null / wrong type).
  String _reelVideoUrlFromData(Map<String, dynamic> data) {
    final v = data['videoUrl'];
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    return s;
  }

  Widget _buildReelMissingVideoPlaceholder() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Missing or invalid video link',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelsPageView(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) {
    _currentReelsDocs = docs;
    final mq = MediaQuery.of(context);
    final rightActionsWidth = responsiveWidth(70, context);
    final overlayPaddingL = responsiveWidth(16, context);
    final overlayPaddingR = responsiveWidth(12, context);
    final overlayPaddingT = responsiveHeight(24, context);
    final overlayPaddingB = responsiveHeight(56, context) + mq.padding.bottom;
    final rightColRight = responsiveWidth(10, context) + mq.padding.right;
    final rightColBottom = responsiveHeight(50, context) + mq.padding.bottom;
    final avatarRadius = responsiveWidth(26, context).clamp(20.0, 36.0);
    final actionIconSize = responsiveWidth(28, context).clamp(24.0, 36.0);
    final actionSpacing = responsiveHeight(14, context);
    final usernameFontSize = responsiveHeight(16, context).clamp(14.0, 20.0);
    final nameFontSize = responsiveHeight(14, context).clamp(12.0, 18.0);
    final descFontSize = responsiveHeight(14, context).clamp(12.0, 16.0);
    final countFontSize = responsiveHeight(13, context).clamp(11.0, 15.0);
    final currentIndex = _currentIndex;
    return PreloadPageView.builder(
      controller: _pageController,
      preloadPagesCount: 1,
      scrollDirection: Axis.vertical,
      itemCount: docs.length,
      onPageChanged: (index) => _handlePageChanged(index),
      itemBuilder: (context, index) {
        if (!_videoKeys.containsKey(index)) {
          _videoKeys[index] = GlobalKey<_VideoPlayerWidgetState>();
        }
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final reelVideoUrl = _reelVideoUrlFromData(data);
        final isInPreloadRange = (index - currentIndex).abs() <= 1;
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchUserData(data['userId'] as String? ?? ''),
          builder: (context, AsyncSnapshot<Map<String, dynamic>?> userSnapshot) {
            return Stack(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: reelVideoUrl.isEmpty
                      ? _buildReelMissingVideoPlaceholder()
                      : VideoPlayerWidget(
                    key: _videoKeys[index]!,
                    videoUrl: reelVideoUrl,
                    isVisible: index == currentIndex && !_uploadOptionsSheetOpen,
                    shouldPreload: isInPreloadRange && !_uploadOptionsSheetOpen,
                    isFirstVideo: index == 0,
                    filter: data['filter'] as String?,
                    caption: (data['caption'] is Map) ? data['caption'] as Map<String, dynamic>? : null,
                    stickers: _stickersListFromReelData(data['stickers']),
                    music: data['music'] is Map ? data['music'] as Map<String, dynamic>? : null,
                    musicVolume: (data['musicVolume'] as num?)?.toDouble(),
                    videoVolume: _reelVideoVolume(data),
                  ),
                ),
                if (userSnapshot.hasData)
                  Positioned(
                    left: 0,
                    right: rightActionsWidth,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        overlayPaddingL,
                        overlayPaddingT,
                        overlayPaddingR,
                        overlayPaddingB,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // Profile image
                              GestureDetector(
                                onTap: () => openUserProfile(
                                  context,
                                  data['userId'] ?? '',
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: appGradient,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    radius: avatarRadius * 0.7,
                                    backgroundImage: _buildProfileImage(
                                      userSnapshot.data!['profileImage'],
                                    ),
                                    backgroundColor: Colors.grey[700],
                                    child:
                                        _shouldShowProfileIcon(
                                          userSnapshot.data!['profileImage'],
                                        )
                                        ? Text(
                                            (userSnapshot.data!['firstName'] ??
                                                    'U')
                                                .toString()
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  avatarRadius * 0.7 * 0.8,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              SizedBox(width: responsiveWidth(10, context)),
                              // Display name only (no @username)
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        userSnapshot.data!['firstName'] ??
                                            'Unknown',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: usernameFontSize,
                                          letterSpacing: 0.2,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 8,
                                              offset: Offset(0, 1),
                                            ),
                                            Shadow(
                                              color: Colors.black45,
                                              blurRadius: 4,
                                              offset: Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if ((userSnapshot.data!['isPaid'] ??
                                            false) ==
                                        true) ...[
                                      SizedBox(
                                        width: responsiveWidth(4, context),
                                      ),
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: const Color(0xFF03DAC6),
                                        size: nameFontSize + 2,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_getVideoDescription(data).isNotEmpty) ...[
                            SizedBox(height: responsiveHeight(8, context)),
                            Text(
                              _getVideoDescription(data),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: descFontSize,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: rightColRight,
                  bottom: rightColBottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // if (userSnapshot.hasData) ...[
                      //   GestureDetector(
                      //     onTap: () => openUserProfile(context, data['userId'] ?? ''),
                      //     child: Container(
                      //       decoration: BoxDecoration(
                      //         shape: BoxShape.circle,
                      //         border: Border.all(color: Colors.black, width: 2),
                      //       ),
                      //       child: CircleAvatar(
                      //         radius: avatarRadius,
                      //         backgroundColor: Colors.grey[800],
                      //         backgroundImage: _buildProfileImage(userSnapshot.data!['profileImage']),
                      //         child: _shouldShowProfileIcon(userSnapshot.data!['profileImage'])
                      //             ? Text(
                      //                 (userSnapshot.data!['firstName'] ?? 'U').substring(0, 1).toUpperCase(),
                      //                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: avatarRadius * 0.85),
                      //               )
                      //             : null,
                      //       ),
                      //     ),
                      //   ),
                      //   SizedBox(height: actionSpacing),
                      // ],
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('reels')
                            .doc(doc.id)
                            .snapshots(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> snap) {
                          if (!snap.hasData || !snap.data!.exists) {
                            return _tiktokActionButton(
                              context,
                              icon: Icons.favorite_border,
                              iconSize: actionIconSize,
                              onTap: () => _toggleLike(doc.id),
                            );
                          }
                          final reelData =
                              snap.data!.data() as Map<String, dynamic>? ?? {};
                          // Prefer counting unique likers from 'likedBy' to avoid
                          // any drift in the numeric 'likes' field from rapid taps.
                          final likesList =
                              (reelData['likedBy'] as List<dynamic>?) ??
                              const <dynamic>[];
                          final likes = likesList.length;
                          final views = (reelData['views'] as int?) ?? 0;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _tiktokActionButton(
                                context,
                                icon: _likedVideos[doc.id] ?? false
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                iconSize: actionIconSize,
                                iconColor: _likedVideos[doc.id] ?? false
                                    ? const Color(0xFFFE2C55)
                                    : Colors.white,
                                count: likes.toString(),
                                countFontSize: countFontSize,
                                onTap: () => _toggleLike(doc.id),
                              ),
                              SizedBox(height: responsiveHeight(4, context)),
                              _tiktokActionButton(
                                context,
                                icon: Icons.visibility_rounded,
                                iconSize: actionIconSize,
                                count: views.toString(),
                                countFontSize: countFontSize,
                                // Views are informational only for now.
                                onTap: () {},
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: responsiveHeight(12, context)),
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('reels')
                            .doc(doc.id)
                            .collection('comments')
                            .snapshots(),
                        builder: (context, AsyncSnapshot<QuerySnapshot> snap) {
                          final commentCount = snap.data?.docs.length ?? 0;
                          return _tiktokActionButton(
                            context,
                            icon: Icons.comment_rounded,
                            iconSize: actionIconSize,
                            count: commentCount.toString(),
                            countFontSize: countFontSize,
                            onTap: () => _showComments(doc.id),
                          );
                        },
                      ),
                      SizedBox(height: responsiveHeight(4, context)),
                      _tiktokActionButton(
                        context,
                        icon: Icons.add_circle_outline,
                        iconSize: actionIconSize,
                        onTap: _showUploadOptions,
                      ),
                      SizedBox(height: responsiveHeight(4, context)),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _buildReelMoreMenu(
                              ctx,
                              data,
                              doc.id,
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: responsiveHeight(4, context),
                          ),
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: actionIconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tiktokActionButton(
    BuildContext context, {
    required IconData icon,
    required double iconSize,
    Color iconColor = Colors.white,
    String? count,
    double? countFontSize,
    required VoidCallback onTap,
  }) {
    final isLikeButton =
        icon == Icons.favorite || icon == Icons.favorite_border;

    // For like buttons, only the icon should toggle like/unlike.
    // Tapping on the numeric like count should NOT change the like state.
    if (isLikeButton) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: responsiveHeight(8, context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            if (count != null && countFontSize != null) ...[
              SizedBox(height: responsiveHeight(2, context)),
              Text(
                count,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: countFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // For all other buttons (comments, views, upload, etc.), keep current
    // behaviour where tapping anywhere on the icon+count area triggers onTap.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: responsiveHeight(8, context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            if (count != null && countFontSize != null) ...[
              SizedBox(height: responsiveHeight(2, context)),
              Text(
                count,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: countFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReelMoreMenu(
    BuildContext context,
    Map<String, dynamic> data,
    String reelId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFFBB86FC).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data['userId'] == _auth.currentUser?.uid) ...[
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue, size: 22),
              title: const Text(
                'Edit Video',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleVideoMenuSelection('edit', data, reelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red, size: 22),
              title: const Text(
                'Delete Video',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleVideoMenuSelection('delete', data, reelId);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange, size: 22),
              title: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleVideoMenuSelection('report', data, reelId);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.showBackButton
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Reels',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
            )
          : null,
      body: Builder(builder: (context) => _buildBody(context)),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isVisible;
  final bool shouldPreload;
  final bool isFirstVideo;
  final String? filter;
  final Map<String, dynamic>? caption;
  /// On-video emoji stickers (same shape as editor / preview: emoji, x, y, scale).
  final List<Map<String, dynamic>>? stickers;
  final Map<String, dynamic>? music;
  final double? musicVolume;
  final double? videoVolume;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.isVisible = true,
    this.shouldPreload = true,
    this.isFirstVideo = false,
    this.filter,
    this.caption,
    this.stickers,
    this.music,
    this.musicVolume,
    this.videoVolume,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  AudioPlayer? _musicPlayer;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showLikeAnimationOverlay = false;
  late AnimationController _likeAnimationController;
  Timer? _initDelayTimer;
  Timer? _pauseMusicDelay; // Debounce: don't pause music on brief video stalls

  @override
  bool get wantKeepAlive => true;

  void _scheduleInitVideo() {
    _initDelayTimer?.cancel();
    // Visible: start loading immediately (0ms). Preload-only: short delay so current reel loads first.
    final delayMs = widget.isVisible ? 0 : 200;
    _initDelayTimer = Timer(Duration(milliseconds: delayMs), () {
      _initDelayTimer = null;
      if (!mounted || _controller != null || _hasError || !widget.shouldPreload) return;
      _initializeVideo();
    });
  }

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    if (widget.shouldPreload) {
      _scheduleInitVideo();
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New URL (e.g. stream refresh or doc update): reload player or stale frames show wrong colors.
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initDelayTimer?.cancel();
      _initDelayTimer = null;
      if (_controller != null) {
        _disposePlayer();
      }
      if (mounted) {
        setState(() {
          _hasError = false;
        });
      }
      if (widget.shouldPreload) {
        _scheduleInitVideo();
      }
      return;
    }

    final preloadChanged = oldWidget.shouldPreload != widget.shouldPreload;
    final visibilityChanged = oldWidget.isVisible != widget.isVisible;

    if (preloadChanged && !widget.shouldPreload) {
      _initDelayTimer?.cancel();
      _initDelayTimer = null;
      if (_controller != null) _disposePlayer();
      return;
    }
    if (preloadChanged && widget.shouldPreload && _controller == null && !_hasError) {
      _scheduleInitVideo();
      return;
    }

    if (visibilityChanged) {
      if (widget.isVisible) {
        _initDelayTimer?.cancel();
        if (_controller == null && !_hasError) {
          _scheduleInitVideo();
        } else if (_controller != null) {
          _controller!.play();
          _musicPlayer?.play();
        }
      } else {
        _initDelayTimer?.cancel();
        _initDelayTimer = null;
        if (_controller != null && !widget.shouldPreload) {
          _disposePlayer();
        } else if (_controller != null) {
          _controller!.pause();
          _musicPlayer?.pause();
        }
      }
    }
  }

  /// Call from ReelsScreen to release this reel's player before opening editor/create video (avoids OOM).
  void releasePlayer() {
    _disposePlayer();
  }

  void _disposePlayer() {
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    final c = _controller;
    if (c != null) {
      c.removeListener(_videoStateListener);
      if (widget.music != null) {
        c.removeListener(_syncMusicWithVideo);
      }
      c.dispose();
      _controller = null;
    }
    _musicPlayer?.dispose();
    _musicPlayer = null;
    if (mounted) setState(() => _isInitialized = false);
  }

  Future<void> _initializeVideo() async {
    if (_controller != null) return;
    try {
      final rawUrl = widget.videoUrl.trim();
      if (rawUrl.isEmpty ||
          !(rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
        throw Exception('Invalid video URL: ${widget.videoUrl}');
      }

      // mixWithOthers: true so video and overlay music can play together without pausing each other
      final c = VideoPlayerController.networkUrl(
        Uri.parse(rawUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      // Assign early to prevent concurrent initializations
      _controller = c;

      await c.initialize().timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          throw Exception('Video failed to load within 35 seconds');
        },
      );

      if (!mounted || _controller != c) {
        // Widget unmounted or player disposed/replaced while initializing
        c.dispose();
        return;
      }

      c.setPlaybackSpeed(1.0);
      c.setLooping(true);
      // Use saved video volume: when user chose "Mute original video" we saved 0; otherwise use saved slider value (or default 1 when no music).
      final hasOverlayMusic = widget.music != null &&
          (widget.music!['audioUrl']?.toString().trim().isNotEmpty == true ||
              widget.music!['musicUrl']?.toString().trim().isNotEmpty == true);
      final videoVol = (widget.videoVolume ?? (hasOverlayMusic ? 0.0 : 1.0)).clamp(0.0, 1.0);
      c.setVolume(videoVol);
      c.addListener(_videoStateListener);

      final musicRaw = widget.music != null
          ? (widget.music!['audioUrl'] ?? widget.music!['musicUrl'])
          : null;
      final audioUrl = musicRaw != null ? musicRaw.toString().trim() : '';
      final isHttpUrl = audioUrl.isNotEmpty && (audioUrl.startsWith('http://') || audioUrl.startsWith('https://'));
      if (isHttpUrl) {
        // handleAudioSessionActivation: false so music does not take audio focus and pause the video
        _musicPlayer = AudioPlayer(handleAudioSessionActivation: false);
        try {
          await _musicPlayer!.setUrl(audioUrl);
          await _musicPlayer!.setLoopMode(LoopMode.one);
          await _musicPlayer!.setVolume((widget.musicVolume ?? 0.5).clamp(0.0, 1.0));
          await _musicPlayer!.seek(Duration.zero);
          
          if (!mounted || _controller != c) {
             _musicPlayer?.dispose();
             _musicPlayer = null;
             c.dispose();
             return;
          }
          
          c.addListener(_syncMusicWithVideo);
        } catch (e) {
          debugPrint('Reel music failed to load: $e');
        }
      }

      if (widget.isVisible) {
        await c.play();
        await _musicPlayer?.play();
      }

      if (mounted && _controller == c) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print("Error initializing video: $e");
      try {
        _controller?.dispose();
      } catch (_) {}
      _controller = null;
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _syncMusicWithVideo() {
    if (_musicPlayer == null || _controller == null || !mounted) return;
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    if (_controller!.value.isPlaying) {
      _musicPlayer!.play();
    } else {
      // User explicitly paused: pause music immediately. Otherwise debounce to avoid pausing on brief stalls/focus blips.
      if (_isPaused) {
        _musicPlayer!.pause();
      } else {
        _pauseMusicDelay = Timer(const Duration(milliseconds: 600), () {
          _pauseMusicDelay = null;
          if (!mounted || _controller == null || _musicPlayer == null) return;
          if (!_controller!.value.isPlaying && !_isPaused) {
            _musicPlayer!.pause();
          }
        });
      }
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || !mounted || _controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _musicPlayer?.pause();
        _isPaused = true;
      } else {
        _controller!.play();
        _musicPlayer?.play();
        _isPaused = false;
      }
    });
  }

  void _seekForward() {
    if (!_isInitialized || !mounted || _controller == null) return;

    final currentPosition = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);

    if (newPosition < duration) {
      _controller!.seekTo(newPosition);
    } else {
      _controller!.seekTo(duration);
    }
  }

  void _seekBackward() {
    if (!_isInitialized || !mounted || _controller == null) return;

    final currentPosition = _controller!.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);

    if (newPosition > Duration.zero) {
      _controller!.seekTo(newPosition);
    } else {
      _controller!.seekTo(Duration.zero);
    }
  }

  void _videoStateListener() {
    if (!mounted || _controller == null) return;

    if (_controller!.value.hasError) {
      print("Video playback error: ${_controller!.value.errorDescription}");
      setState(() {
        _hasError = true;
      });
    }
  }

  void playVideo() {
    if (!mounted || !_isInitialized || _controller == null) return;
    final hasOverlayMusic = widget.music != null &&
        (widget.music!['audioUrl']?.toString().trim().isNotEmpty == true ||
            widget.music!['musicUrl']?.toString().trim().isNotEmpty == true);
    final videoVol = (widget.videoVolume ?? (hasOverlayMusic ? 0.0 : 1.0)).clamp(0.0, 1.0);
    _controller!.setVolume(videoVol);
    _controller!.play();
    _musicPlayer?.play();
    setState(() {
      _isPaused = false;
    });
  }

  void pauseVideo() {
    if (!mounted || !_isInitialized || _controller == null) return;
    _controller!.pause();
    _musicPlayer?.pause();
    setState(() {
      _isPaused = true;
    });
  }

  void _showLikeAnimation() {
    if (!mounted) return;

    setState(() {
      _showLikeAnimationOverlay = true;
    });

    _likeAnimationController.forward().then((_) {
      if (mounted) {
        _likeAnimationController.reset();
        setState(() {
          _showLikeAnimationOverlay = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _initDelayTimer?.cancel();
    _initDelayTimer = null;
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    _controller?.removeListener(_videoStateListener);
    if (widget.music != null) {
      _controller?.removeListener(_syncMusicWithVideo);
    }
    _controller?.dispose();
    _controller = null;
    _musicPlayer?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Widget _buildVideoWithFilter() {
    if (_controller == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }
    final cf = _reelFilterMatrix(widget.filter);
    final child = VideoPlayer(_controller!);
    if (cf != null) {
      return ColorFiltered(colorFilter: cf, child: child);
    }
    return child;
  }

  bool get _hasReelEditOverlays {
    final cap = widget.caption;
    final t = (cap?['text'] ?? '').toString().trim();
    final ss = widget.stickers;
    return t.isNotEmpty || (ss != null && ss.isNotEmpty);
  }

  Widget _buildReelEditOverlays() {
    final cap = widget.caption;
    final capText = (cap?['text'] ?? '').toString().trim();
    Color capColor = Colors.white;
    double capSize = 22;
    if (cap != null) {
      final v = cap['color'];
      if (v is int) capColor = Color(v);
      capSize = ((cap['size'] as num?)?.toDouble() ?? 22.0).clamp(14.0, 42.0);
    }
    final stickers = widget.stickers ?? const <Map<String, dynamic>>[];

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (capText.isNotEmpty)
            Align(
              alignment: const Alignment(0, 0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  capText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: capColor,
                    fontSize: capSize,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.95),
                        blurRadius: 16,
                        offset: const Offset(0, 2),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.9),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 0,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final s in stickers) _buildStickerOverlay(s, w, h),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStickerOverlay(Map<String, dynamic> s, double w, double h) {
    final emoji = s['emoji']?.toString() ?? '❤️';
    final x = (s['x'] as num?)?.toDouble() ?? 0.5;
    final y = (s['y'] as num?)?.toDouble() ?? 0.5;
    final scale = (s['scale'] as num?)?.toDouble() ?? 1.0;
    final base = 40.0 * scale;
    return Positioned(
      left: x * w - base / 2,
      top: y * h - base / 2,
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: 36 * scale,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.88),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  static ColorFilter? _reelFilterMatrix(String? name) {
    if (name == null || name == 'None' || name == 'Normal') return null;
    switch (name) {
      case 'Black & White':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.8, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Cinematic':
        return const ColorFilter.matrix([
          0.9, 0.05, 0.05, 0, 0,
          0.05, 0.9, 0.05, 0, 0,
          0.05, 0.05, 0.9, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              const Text(
                "Failed to load video",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Check your internet connection\nor try again later",
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializeVideo();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: () {
        // Double tap to like
        if (_isInitialized) {
          _showLikeAnimation();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Reels spec: 9:16 — full-bleed like TikTok (cover), black letterbox only if needed.
                    const ar = ReelVideoSpec.aspectRatio;
                    final w = constraints.maxWidth;
                    final slotH = w / ar;
                    return FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: w,
                        height: slotH,
                        child: AspectRatio(
                          aspectRatio: ar,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildVideoWithFilter(),
                              if (_hasReelEditOverlays) _buildReelEditOverlays(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_isInitialized && widget.music != null)
            Positioned(
              top: 50,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        (widget.music!['title'] as String?) ?? 'Music',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isInitialized)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.purple,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading video...",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Video controls overlay
          if (_isPaused && _isInitialized)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFBB86FC).withOpacity(0.5),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Backward button
                  GestureDetector(
                    onTap: _seekBackward,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.replay_10_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Play/Pause button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller?.value.isPlaying == true
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Forward button
                  GestureDetector(
                    onTap: _seekForward,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.forward_10_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Like animation overlay
          if (_showLikeAnimationOverlay)
            Positioned.fill(
              child: Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.2).animate(
                    CurvedAnimation(
                      parent: _likeAnimationController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                      CurvedAnimation(
                        parent: _likeAnimationController,
                        curve: const Interval(0.5, 1.0),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
