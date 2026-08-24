import 'package:cloud_firestore/cloud_firestore.dart';

class MusicCoachMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime? timestamp;

  const MusicCoachMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory MusicCoachMessage.fromMap(String id, Map<String, dynamic> data) {
    return MusicCoachMessage(
      id: id,
      text: data['text'] as String? ?? '',
      isUser: data['isUser'] as bool? ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
