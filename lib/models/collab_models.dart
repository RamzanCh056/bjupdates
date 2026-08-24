import 'package:cloud_firestore/cloud_firestore.dart';

class CollabParticipantInfo {
  final String name;
  final String? photo;
  final String role;
  final String recordingStatus; // waiting | recording | done

  const CollabParticipantInfo({
    required this.name,
    this.photo,
    this.role = 'Artist',
    this.recordingStatus = 'waiting',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        if (photo != null) 'photo': photo,
        'role': role,
        'recordingStatus': recordingStatus,
      };

  factory CollabParticipantInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const CollabParticipantInfo(name: 'User');
    }
    return CollabParticipantInfo(
      name: (map['name'] ?? 'User').toString(),
      photo: map['photo']?.toString(),
      role: (map['role'] ?? 'Artist').toString(),
      recordingStatus: (map['recordingStatus'] ?? 'waiting').toString(),
    );
  }

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }
}

class CollabBackingTrack {
  final String title;
  final int bpm;
  final String key;
  final String duration;
  final String? audioUrl;

  const CollabBackingTrack({
    this.title = 'Dark Trap',
    this.bpm = 92,
    this.key = 'C Minor',
    this.duration = '2:47',
    this.audioUrl,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'bpm': bpm,
        'key': key,
        'duration': duration,
        if (audioUrl != null) 'audioUrl': audioUrl,
      };

  factory CollabBackingTrack.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CollabBackingTrack();
    return CollabBackingTrack(
      title: (map['title'] ?? 'Dark Trap').toString(),
      bpm: (map['bpm'] is num) ? (map['bpm'] as num).toInt() : 92,
      key: (map['key'] ?? 'C Minor').toString(),
      duration: (map['duration'] ?? '2:47').toString(),
      audioUrl: map['audioUrl']?.toString(),
    );
  }

  String get primaryLabel => '$title — $bpm BPM';
  String get metaLabel => '$key · $duration';
}

class CollabRoom {
  final String id;
  final String code;
  final String hostId;
  final String status; // waiting | prep | recording | mixing | closed
  final int phase; // 1 prep, 2 record, 3 mix
  final List<String> participants;
  final Map<String, CollabParticipantInfo> participantInfo;
  final CollabBackingTrack backingTrack;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const CollabRoom({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.phase,
    required this.participants,
    required this.participantInfo,
    required this.backingTrack,
    this.createdAt,
    this.updatedAt,
  });

  bool get isFull => participants.length >= 2;
  bool get isRecording => phase >= 2 || status == 'recording';
  bool get isPrep => phase == 1;

  CollabParticipantInfo? infoFor(String uid) => participantInfo[uid];

  String? peerIdFor(String myUid) {
    for (final id in participants) {
      if (id != myUid) return id;
    }
    return null;
  }

  String displayTitle(String myUid) {
    final peerId = peerIdFor(myUid);
    if (peerId != null) {
      final peer = participantInfo[peerId];
      if (peer != null && peer.name.isNotEmpty) {
        return 'Collab with ${peer.name}';
      }
    }
    return 'Room $code';
  }

  String statusSubtitle(String myUid) {
    final ago = _relativeTime(updatedAt?.toDate() ?? createdAt?.toDate());
    if (status == 'recording' || phase == 2) {
      return '🔴 Recording · Room $code · $ago';
    }
    if (participants.length < 2) {
      return '⏳ Waiting for guest · Room $code · $ago';
    }
    return '🟢 Active · Room $code · $ago';
  }

  factory CollabRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawInfo = data['participantInfo'];
    final info = <String, CollabParticipantInfo>{};
    if (rawInfo is Map) {
      rawInfo.forEach((key, value) {
        info[key.toString()] = CollabParticipantInfo.fromMap(
          value is Map<String, dynamic>
              ? value
              : Map<String, dynamic>.from(value as Map),
        );
      });
    }

    final participants = (data['participants'] is List)
        ? (data['participants'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return CollabRoom(
      id: doc.id,
      code: (data['code'] ?? doc.id).toString(),
      hostId: (data['hostId'] ?? '').toString(),
      status: (data['status'] ?? 'prep').toString(),
      phase: (data['phase'] is num) ? (data['phase'] as num).toInt() : 1,
      participants: participants,
      participantInfo: info,
      backingTrack: CollabBackingTrack.fromMap(
        data['backingTrack'] is Map<String, dynamic>
            ? data['backingTrack'] as Map<String, dynamic>
            : data['backingTrack'] is Map
                ? Map<String, dynamic>.from(data['backingTrack'] as Map)
                : null,
      ),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  static String _relativeTime(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class CollabMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final Timestamp? timestamp;
  final String type; // chat | system

  const CollabMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.timestamp,
    this.type = 'chat',
  });

  factory CollabMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CollabMessage(
      id: doc.id,
      text: (data['text'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? 'User').toString(),
      timestamp: data['timestamp'] as Timestamp?,
      type: (data['type'] ?? 'chat').toString(),
    );
  }
}
