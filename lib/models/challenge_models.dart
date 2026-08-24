import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeBeat {
  final String title;
  final String fileName;
  final int bpm;
  final String key;
  final String duration;
  final String? audioUrl;
  final String? storagePath;
  final String? sizeLabel;

  const ChallengeBeat({
    this.title = 'Untitled Beat',
    this.fileName = '',
    this.bpm = 0,
    this.key = '',
    this.duration = '',
    this.audioUrl,
    this.storagePath,
    this.sizeLabel,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'title': title,
        'fileName': fileName,
        'bpm': bpm,
        'key': key,
        'duration': duration,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (storagePath != null) 'storagePath': storagePath,
        if (sizeLabel != null) 'sizeLabel': sizeLabel,
      };

  factory ChallengeBeat.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ChallengeBeat();
    return ChallengeBeat(
      title: (map['title'] ?? 'Untitled Beat').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      bpm: (map['bpm'] is num) ? (map['bpm'] as num).toInt() : 0,
      key: (map['key'] ?? '').toString(),
      duration: (map['duration'] ?? '').toString(),
      audioUrl: map['audioUrl']?.toString(),
      storagePath: map['storagePath']?.toString(),
      sizeLabel: map['sizeLabel']?.toString(),
    );
  }

  String get metaLabel {
    final parts = <String>[];
    if (bpm > 0) parts.add('$bpm BPM');
    if (key.isNotEmpty) parts.add(key);
    if (duration.isNotEmpty) parts.add(duration);
    if (sizeLabel != null && sizeLabel!.isNotEmpty) parts.add(sizeLabel!);
    return parts.isEmpty ? 'Audio track' : parts.join(' · ');
  }
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final List<String> hashtags;
  final String creatorId;
  final String creatorName;
  final String? creatorPhoto;
  final String status;
  final bool isOfficial;
  final bool isFeatured;
  final int deadlineDays;
  final Timestamp? endsAt;
  final Timestamp? createdAt;
  final ChallengeBeat beat;
  final String? prizeText;
  final String? sponsorName;
  final int entryCount;
  final int viewCount;
  final List<String> participantIds;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhoto,
    required this.status,
    required this.isOfficial,
    required this.isFeatured,
    required this.deadlineDays,
    this.endsAt,
    this.createdAt,
    required this.beat,
    this.prizeText,
    this.sponsorName,
    required this.entryCount,
    required this.viewCount,
    required this.participantIds,
  });

  String get primaryHashtag =>
      hashtags.isNotEmpty ? hashtags.first : '#BeatChallenge';

  String get hashtagsLabel => hashtags.join(' ');

  String get creatorInitial {
    final n = creatorName.trim();
    if (n.isEmpty) return 'U';
    return n[0].toUpperCase();
  }

  String get entriesLabel {
    if (entryCount >= 1000) {
      final k = entryCount / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K entries';
    }
    return '$entryCount entries';
  }

  String get viewsLabel {
    if (viewCount >= 1000) {
      final k = viewCount / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K Views';
    }
    return '$viewCount Views';
  }

  String get endsInLabel {
    final end = endsAt?.toDate();
    if (end == null) return 'Open';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays >= 1) {
      final hours = diff.inHours % 24;
      return 'Ends in ${diff.inDays}d ${hours}h';
    }
    if (diff.inHours >= 1) return 'Ends in ${diff.inHours}h';
    return 'Ends in ${diff.inMinutes}m';
  }

  String get daysLeftLabel {
    final end = endsAt?.toDate();
    if (end == null) return 'Open';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays >= 1) return '${diff.inDays}d left';
    if (diff.inHours >= 1) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  String get timeAgoLabel {
    final start = createdAt?.toDate();
    if (start == null) return 'just now';
    final diff = DateTime.now().difference(start);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get isEnded {
    final end = endsAt?.toDate();
    return status == 'ended' || (end != null && end.isBefore(DateTime.now()));
  }

  bool isOwnedBy(String? uid) =>
      uid != null && uid.isNotEmpty && creatorId == uid;

  bool hasJoined(String? uid) =>
      uid != null && uid.isNotEmpty && participantIds.contains(uid);

  factory Challenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final tags = (data['hashtags'] is List)
        ? (data['hashtags'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final participants = (data['participantIds'] is List)
        ? (data['participantIds'] as List).map((e) => e.toString()).toList()
        : <String>[];

    Map<String, dynamic>? beatMap;
    final rawBeat = data['beat'];
    if (rawBeat is Map<String, dynamic>) {
      beatMap = rawBeat;
    } else if (rawBeat is Map) {
      beatMap = Map<String, dynamic>.from(rawBeat);
    }

    return Challenge(
      id: doc.id,
      title: (data['title'] ?? 'Untitled Challenge').toString(),
      description: (data['description'] ?? '').toString(),
      hashtags: tags,
      creatorId: (data['creatorId'] ?? '').toString(),
      creatorName: (data['creatorName'] ?? 'User').toString(),
      creatorPhoto: data['creatorPhoto']?.toString(),
      status: (data['status'] ?? 'active').toString(),
      isOfficial: data['isOfficial'] == true,
      isFeatured: data['isFeatured'] == true,
      deadlineDays: (data['deadlineDays'] is num)
          ? (data['deadlineDays'] as num).toInt()
          : 7,
      endsAt: data['endsAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      beat: ChallengeBeat.fromMap(beatMap),
      prizeText: data['prizeText']?.toString(),
      sponsorName: data['sponsorName']?.toString(),
      entryCount:
          (data['entryCount'] is num) ? (data['entryCount'] as num).toInt() : 0,
      viewCount:
          (data['viewCount'] is num) ? (data['viewCount'] as num).toInt() : 0,
      participantIds: participants,
    );
  }
}

class ChallengeEntry {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int durationSec;
  final String status;
  final int views;
  final int likes;
  final int shares;
  final double score;
  final Timestamp? createdAt;
  final String? audioUrl;

  const ChallengeEntry({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.durationSec,
    required this.status,
    required this.views,
    required this.likes,
    required this.shares,
    required this.score,
    this.createdAt,
    this.audioUrl,
  });

  String get initial {
    final n = userName.trim();
    if (n.isEmpty) return 'U';
    return n[0].toUpperCase();
  }

  String get durationLabel {
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ChallengeEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChallengeEntry(
      id: doc.id,
      userId: (data['userId'] ?? doc.id).toString(),
      userName: (data['userName'] ?? 'User').toString(),
      userPhoto: data['userPhoto']?.toString(),
      durationSec: (data['durationSec'] is num)
          ? (data['durationSec'] as num).toInt()
          : 0,
      status: (data['status'] ?? 'ready').toString(),
      views: (data['views'] is num) ? (data['views'] as num).toInt() : 0,
      likes: (data['likes'] is num) ? (data['likes'] as num).toInt() : 0,
      shares: (data['shares'] is num) ? (data['shares'] as num).toInt() : 0,
      score: (data['score'] is num) ? (data['score'] as num).toDouble() : 0,
      createdAt: data['createdAt'] as Timestamp?,
      audioUrl: data['audioUrl']?.toString(),
    );
  }

  static double computeScore({
    required int views,
    required int likes,
    required int shares,
  }) {
    return views * 0.4 + likes * 0.4 + shares * 0.2;
  }
}
