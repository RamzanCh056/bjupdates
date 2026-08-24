import 'package:cloud_firestore/cloud_firestore.dart';

class GeneratedBeat {
  final String id;
  final String userId;
  final String title;
  final String description;
  final List<String> genres;
  final List<String> moods;
  final int bpm;
  final String keyLabel;
  final String length;
  final int durationSeconds;
  final String status;
  final bool isFavorite;
  final String summary;
  final String arrangement;
  final String drums;
  final String bass;
  final String melody;
  final String mixNotes;
  final String? previewAudioUrl;
  final String? errorMessage;
  final DateTime? createdAt;

  const GeneratedBeat({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.genres,
    required this.moods,
    required this.bpm,
    required this.keyLabel,
    required this.length,
    this.durationSeconds = 0,
    required this.status,
    this.isFavorite = false,
    this.summary = '',
    this.arrangement = '',
    this.drums = '',
    this.bass = '',
    this.melody = '',
    this.mixNotes = '',
    this.previewAudioUrl,
    this.errorMessage,
    this.createdAt,
  });

  bool get isGenerating => status == 'generating';
  bool get isFailed => status == 'failed';
  bool get isCompleted => status == 'completed';

  bool get hasPlayableAudio {
    final url = previewAudioUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get hasBlueprint {
    return summary.isNotEmpty ||
        arrangement.isNotEmpty ||
        drums.isNotEmpty ||
        bass.isNotEmpty ||
        melody.isNotEmpty;
  }

  bool get isLibraryReady => isCompleted && (hasPlayableAudio || hasBlueprint);

  Duration get targetDuration {
    if (durationSeconds > 0) {
      return Duration(seconds: durationSeconds);
    }
    return parseLengthLabel(length);
  }

  static Duration parseLengthLabel(String length) {
    final parts = length.split(':');
    if (parts.length != 2) {
      return const Duration(seconds: 30);
    }
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return Duration(minutes: minutes, seconds: seconds);
  }

  static int parseLengthLabelToSeconds(String length) {
    return parseLengthLabel(length).inSeconds;
  }

  GeneratedBeat copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    List<String>? genres,
    List<String>? moods,
    int? bpm,
    String? keyLabel,
    String? length,
    int? durationSeconds,
    String? status,
    bool? isFavorite,
    String? summary,
    String? arrangement,
    String? drums,
    String? bass,
    String? melody,
    String? mixNotes,
    String? previewAudioUrl,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return GeneratedBeat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      moods: moods ?? this.moods,
      bpm: bpm ?? this.bpm,
      keyLabel: keyLabel ?? this.keyLabel,
      length: length ?? this.length,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      summary: summary ?? this.summary,
      arrangement: arrangement ?? this.arrangement,
      drums: drums ?? this.drums,
      bass: bass ?? this.bass,
      melody: melody ?? this.melody,
      mixNotes: mixNotes ?? this.mixNotes,
      previewAudioUrl: previewAudioUrl ?? this.previewAudioUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'genres': genres,
      'moods': moods,
      'bpm': bpm,
      'keyLabel': keyLabel,
      'length': length,
      'durationSeconds': durationSeconds,
      'status': status,
      'isFavorite': isFavorite,
      'summary': summary,
      'arrangement': arrangement,
      'drums': drums,
      'bass': bass,
      'melody': melody,
      'mixNotes': mixNotes,
      'previewAudioUrl': previewAudioUrl,
      'errorMessage': errorMessage,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory GeneratedBeat.fromMap(String id, Map<String, dynamic> data) {
    return GeneratedBeat(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled Beat',
      description: data['description'] as String? ?? '',
      genres: (data['genres'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      moods: (data['moods'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      bpm: (data['bpm'] as num?)?.toInt() ?? 120,
      keyLabel: data['keyLabel'] as String? ?? 'C Minor',
      length: data['length'] as String? ?? '1:30',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'completed',
      isFavorite: data['isFavorite'] as bool? ?? false,
      summary: data['summary'] as String? ?? '',
      arrangement: data['arrangement'] as String? ?? '',
      drums: data['drums'] as String? ?? '',
      bass: data['bass'] as String? ?? '',
      melody: data['melody'] as String? ?? '',
      mixNotes: data['mixNotes'] as String? ?? '',
      previewAudioUrl: data['previewAudioUrl'] as String?,
      errorMessage: data['errorMessage'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
