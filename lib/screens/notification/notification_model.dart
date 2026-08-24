import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationViewModel {
  final String id;
  final String type;
  final String message;
  final String createdAt; // or DateTime
  final bool isRead;
  final String fromUserId;
  final String fromUserName;
  final String? reelId;  // optional
  final String? postId;  // optional
  final String? eventId;  // optional
  final String? songId;  // optional

  NotificationViewModel({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.fromUserId,
    required this.fromUserName,
    this.reelId,
    this.postId,
    this.eventId,
    this.songId,
  });

  factory NotificationViewModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationViewModel(
      id: id,
      type: data['type'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['timestamp'] as Timestamp)
        .toDate()
        .toIso8601String(),
      isRead: data['isRead'] ?? false,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      reelId: data['reelId'],
      postId: data['postId'],
      eventId: data['eventId'],
      songId: data['songId'],
    );
  }
}
