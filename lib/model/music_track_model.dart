class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String coverImageUrl;
  final int duration; // in seconds
  final String genre;
  final int useCount;
  final bool isTrending;
  final DateTime uploadedAt;
  final String uploadedBy;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.coverImageUrl,
    required this.duration,
    required this.genre,
    this.useCount = 0,
    this.isTrending = false,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory MusicTrack.fromMap(String id, Map<String, dynamic> map) {
    return MusicTrack(
      id: id,
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      coverImageUrl: map['coverImageUrl'] ?? '',
      duration: map['duration'] ?? 0,
      genre: map['genre'] ?? '',
      useCount: map['useCount'] ?? 0,
      isTrending: map['isTrending'] ?? false,
      uploadedAt: map['uploadedAt']?.toDate() ?? DateTime.now(),
      uploadedBy: map['uploadedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'coverImageUrl': coverImageUrl,
      'duration': duration,
      'genre': genre,
      'useCount': useCount,
      'isTrending': isTrending,
      'uploadedAt': uploadedAt,
      'uploadedBy': uploadedBy,
    };
  }

  String get durationFormatted {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PostWithMusic {
  final String? musicTrackId;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicUrl;
  final double? musicStartTime; // Start time in seconds for the clip
  final double? musicVolume; // Volume level (0.0 to 1.0)
  final double? musicClipDuration; // Duration of selected clip in seconds

  PostWithMusic({
    this.musicTrackId,
    this.musicTitle,
    this.musicArtist,
    this.musicUrl,
    this.musicStartTime = 0.0,
    this.musicVolume = 0.5,
    this.musicClipDuration,
  });

  factory PostWithMusic.fromMap(Map<String, dynamic> map) {
    return PostWithMusic(
      // Accept multiple key variants
      musicTrackId: map['musicTrackId'] ?? map['musicId'],
      musicTitle: map['musicTitle'] ?? map['title'],
      musicArtist: map['musicArtist'] ?? map['artist'],
      musicUrl: map['musicUrl'] ?? map['audioUrl'],
      musicStartTime: map['musicStartTime']?.toDouble() ?? 0.0,
      musicVolume: map['musicVolume']?.toDouble() ?? 0.5,
      musicClipDuration: (map['musicClipDuration'] ?? map['clipDuration'])?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'musicTrackId': musicTrackId,
      'musicTitle': musicTitle,
      'musicArtist': musicArtist,
      'musicUrl': musicUrl,
      'musicStartTime': musicStartTime,
      'musicVolume': musicVolume,
      'musicClipDuration': musicClipDuration,
    };
  }
}

