
import 'package:flutter/material.dart';

import '../../model/api_models/feed_models/single_feed_comments_model.dart';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../notification_services/trigger_notification_services.dart';

class CommentsProvider extends ChangeNotifier{
  List<SingleFeedCommentModel> feedComments=[];

  update(List<SingleFeedCommentModel> comments){
    feedComments.clear();
    feedComments=comments;
    notifyListeners();
  }

}

class CommentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get comments => _comments;

  /// Load comments for a specific post
  Future<void> loadComments(String postId) async {
    _setLoading(true);
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      _comments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['text'] ?? '',
          'userName': data['userName'] ?? 'User',
          'userId': data['userId'] ?? '',
          'timestamp': data['timestamp'],
          'userImage': data['userImage'] ?? '',
          // Parent comment id for replies (null or empty for top-level comments)
          'parentId': data['parentId'],
        };
      }).toList();

      _setLoading(false);
    } catch (e) {
      log('Error loading comments: $e');
      _setError("Failed to load comments");
    }
  }

  /// Add a comment
  Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    _setLoading(true);

    try {
      // Fetch user data for name and image
      final userDoc =
          await _firestore.collection('usersData').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final userProfileImage = userData['profileImage'] ?? user.photoURL ?? '';
      final commenterName = userData['firstName'] ?? user.displayName ?? 'User';

      // Create top-level comment (no parent)
      final commentData = {
        'text': text.trim(),
        'userId': user.uid,
        'userName': commenterName,
        'userImage': userProfileImage,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': null,
      };

      final docRef = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add(commentData);

      // Optimistically add new comment to local list
      _comments.add({
        'id': docRef.id,
        'text': text,
        'userId': user.uid,
        'userName': commenterName,
        'userImage': userProfileImage,
        'timestamp': Timestamp.now(),
        'parentId': null,
      });
      notifyListeners();

      // Send notification to post owner
      await _sendCommentNotification(commenterName, postId);

      _setLoading(false);
    } catch (e) {
      log('Error adding comment: $e');
      _setError("Failed to add comment");
    }
  }

  /// Add a reply to an existing comment
  Future<void> addReply(String postId, String parentCommentId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    _setLoading(true);

    try {
      // Fetch user data for name and image
      final userDoc =
          await _firestore.collection('usersData').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final userProfileImage = userData['profileImage'] ?? user.photoURL ?? '';
      final commenterName = userData['firstName'] ?? user.displayName ?? 'User';

      // Create reply
      final replyData = {
        'text': text.trim(),
        'userId': user.uid,
        'userName': commenterName,
        'userImage': userProfileImage,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': parentCommentId,
      };

      final docRef = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add(replyData);

      // Optimistically add new reply to local list
      _comments.add({
        'id': docRef.id,
        'text': text,
        'userId': user.uid,
        'userName': commenterName,
        'userImage': userProfileImage,
        'timestamp': Timestamp.now(),
        'parentId': parentCommentId,
      });
      notifyListeners();

      // Notify post owner (same as normal comment)
      await _sendCommentNotification(commenterName, postId);

      // Additionally notify the parent comment owner (if different from replier)
      await _sendReplyNotification(
        commenterName: commenterName,
        postId: postId,
        parentCommentId: parentCommentId,
      );

      _setLoading(false);
    } catch (e) {
      log('Error adding reply: $e');
      _setError("Failed to add reply");
    }
  }

  /// Send notification to the user whose comment was replied to
  Future<void> _sendReplyNotification({
    required String commenterName,
    required String postId,
    required String parentCommentId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final parentDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(parentCommentId)
          .get();
      if (!parentDoc.exists) return;

      final parentOwnerId = parentDoc.data()?['userId'] as String?;
      if (parentOwnerId == null || parentOwnerId == currentUser.uid) return;

      final ownerDoc =
          await _firestore.collection('usersData').doc(parentOwnerId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await TriggerNotificationService().sendPushNotification(
          token: fcmToken,
          title: 'New reply 💬',
          body: '$commenterName replied to your comment',
        );
      }

      // Save notification in Firestore
      await _firestore
          .collection('notifications')
          .doc(parentOwnerId)
          .collection('userNotifications')
          .add({
        'type': 'comment_reply',
        'fromUserId': currentUser.uid,
        'fromUserName': commenterName,
        'postId': postId,
        'parentCommentId': parentCommentId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$commenterName replied to your comment',
        'isRead': false,
      });
    } catch (e) {
      log('Error sending reply notification: $e');
    }
  }

  /// Send push notification to post owner
  Future<void> _sendCommentNotification(
      String commenterName, String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postOwnerId = postDoc.data()?['userId'];
      if (postOwnerId == null || postOwnerId == currentUser.uid) return;

      final ownerDoc =
          await _firestore.collection('usersData').doc(postOwnerId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await TriggerNotificationService().sendPushNotification(
          token: fcmToken,
          title: 'New Comment! 💬',
          body: '$commenterName commented on your post',
        );
      }

      // Save notification in Firestore
      await _firestore
          .collection('notifications')
          .doc(postOwnerId)
          .collection('userNotifications')
          .add({
        'type': 'comment',
        'fromUserId': currentUser.uid,
        'fromUserName': commenterName,
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$commenterName commented on your post',
        'isRead': false,
      });
    } catch (e) {
      log('Error sending comment notification: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId, String commentUserId) async {
    final currentUserId = _auth.currentUser?.uid ?? '';

    // Security check - verify the comment belongs to current user
    if (commentUserId != currentUserId) {
      throw Exception('You don\'t have permission to delete this comment');
    }

    try {
      // Double-check ownership on server side
      final commentDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists ||
          commentDoc.data()?['userId'] != currentUserId) {
        throw Exception('You don\'t have permission to delete this comment');
      }

      // Delete the comment
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Also delete all replies to this comment
      final repliesSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .get();

      for (var replyDoc in repliesSnapshot.docs) {
        await replyDoc.reference.delete();
      }

      // Remove from local list
      _comments.removeWhere((c) => c['id'] == commentId || c['parentId'] == commentId);
      notifyListeners();

      // Delete related notifications
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'];

      if (postOwnerId != null && postOwnerId != currentUserId) {
        await _deleteCommentNotification(
          fromUserId: currentUserId,
          toUserId: postOwnerId,
          postId: postId,
        );
      }

      // Also delete reply notifications if this was a reply
      final parentId = commentDoc.data()?['parentId'] as String?;
      if (parentId != null && parentId.isNotEmpty) {
        final parentCommentDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(parentId)
            .get();
        
        if (parentCommentDoc.exists) {
          final parentOwnerId = parentCommentDoc.data()?['userId'] as String?;
          if (parentOwnerId != null && parentOwnerId != currentUserId) {
            await _deleteReplyNotification(
              fromUserId: currentUserId,
              toUserId: parentOwnerId,
              postId: postId,
              parentCommentId: parentId,
            );
          }
        }
      }
    } catch (e) {
      log('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Delete comment notification
  Future<void> _deleteCommentNotification({
    required String fromUserId,
    required String toUserId,
    required String postId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(toUserId)
          .collection('userNotifications')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: 'comment')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      log('Deleted comment notification from $fromUserId to $toUserId on post $postId');
    } catch (e) {
      log('Error deleting comment notification: $e');
    }
  }

  /// Delete reply notification
  Future<void> _deleteReplyNotification({
    required String fromUserId,
    required String toUserId,
    required String postId,
    required String parentCommentId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(toUserId)
          .collection('userNotifications')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('postId', isEqualTo: postId)
          .where('parentCommentId', isEqualTo: parentCommentId)
          .where('type', isEqualTo: 'comment_reply')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      log('Deleted reply notification from $fromUserId to $toUserId on post $postId');
    } catch (e) {
      log('Error deleting reply notification: $e');
    }
  }

  /// Edit an existing comment (only by its owner)
  Future<void> editComment(String postId, String commentId, String newText) async {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final trimmedText = newText.trim();
    if (currentUserId.isEmpty || trimmedText.isEmpty) return;

    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists || commentDoc.data()?['userId'] != currentUserId) {
        throw Exception("You don't have permission to edit this comment");
      }

      await commentRef.update({'text': trimmedText});

      // Update local list
      final index = _comments.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        _comments[index] = {
          ..._comments[index],
          'text': trimmedText,
        };
        notifyListeners();
      }
    } catch (e) {
      log('Error editing comment: $e');
      rethrow;
    }
  }

  void clear() {
    _comments.clear();
    notifyListeners();
  }

}
