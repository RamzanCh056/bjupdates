import 'package:cloud_firestore/cloud_firestore.dart';

/// Participant snapshot stored on a chat document.
class ChatParticipantInfo {
  final String name;
  final String? photo;

  const ChatParticipantInfo({required this.name, this.photo});

  Map<String, dynamic> toMap() => {
        'name': name,
        if (photo != null) 'photo': photo,
      };

  factory ChatParticipantInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ChatParticipantInfo(name: 'User');
    return ChatParticipantInfo(
      name: (map['name'] ?? 'User').toString(),
      photo: map['photo']?.toString(),
    );
  }
}

class ChatLastMessage {
  final String text;
  final String senderId;
  final Timestamp? timestamp;
  final String status;

  const ChatLastMessage({
    required this.text,
    required this.senderId,
    this.timestamp,
    this.status = 'sent',
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderId': senderId,
        'timestamp': timestamp ?? FieldValue.serverTimestamp(),
        'status': status,
      };

  factory ChatLastMessage.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ChatLastMessage(text: '', senderId: '');
    }
    return ChatLastMessage(
      text: (map['text'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      timestamp: map['timestamp'] as Timestamp?,
      status: _readStatus(map),
    );
  }

  static String _readStatus(Map<String, dynamic> map) {
    final status = map['status']?.toString();
    if (status != null && status.isNotEmpty) return status;
    if (map['read'] == true) return 'read';
    return 'sent';
  }
}

/// Inbox row derived from `chats/{chatId}`.
class ChatSummary {
  final String id;
  final List<String> participants;
  final Map<String, ChatParticipantInfo> participantInfo;
  final ChatLastMessage? lastMessage;
  final Timestamp? lastUpdated;

  const ChatSummary({
    required this.id,
    required this.participants,
    required this.participantInfo,
    this.lastMessage,
    this.lastUpdated,
  });

  String peerIdFor(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  ChatParticipantInfo peerInfoFor(String myUid) {
    final peer = peerIdFor(myUid);
    return participantInfo[peer] ?? const ChatParticipantInfo(name: 'User');
  }

  bool isUnreadFor(String myUid) {
    final last = lastMessage;
    if (last == null || last.senderId.isEmpty) return false;
    if (last.senderId == myUid) return false;
    return last.status != 'read';
  }

  factory ChatSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final infoRaw = data['participantInfo'] as Map<String, dynamic>? ?? {};
    final info = <String, ChatParticipantInfo>{};
    for (final entry in infoRaw.entries) {
      info[entry.key] = ChatParticipantInfo.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return ChatSummary(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? const []),
      participantInfo: info,
      lastMessage: ChatLastMessage.fromMap(
        data['lastMessage'] as Map<String, dynamic>?,
      ),
      lastUpdated: data['lastUpdated'] as Timestamp?,
    );
  }
}

enum ChatMessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final Timestamp? timestamp;
  final ChatMessageStatus status;
  final bool isStoryReply;
  final Map<String, dynamic> extra;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.isStoryReply = false,
    this.extra = const {},
  });

  bool get isPending => status == ChatMessageStatus.sending;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      timestamp: data['timestamp'] as Timestamp?,
      status: _statusFromMap(data),
      isStoryReply: data['isStoryReply'] == true,
      extra: Map<String, dynamic>.from(data),
    );
  }

  static ChatMessageStatus _statusFromMap(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    switch (status) {
      case 'read':
        return ChatMessageStatus.read;
      case 'delivered':
        return ChatMessageStatus.delivered;
      case 'sending':
        return ChatMessageStatus.sending;
      default:
        if (data['read'] == true) return ChatMessageStatus.read;
        return ChatMessageStatus.sent;
    }
  }
}
