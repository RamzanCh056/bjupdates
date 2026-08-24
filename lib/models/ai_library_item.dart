import 'package:cloud_firestore/cloud_firestore.dart';

class AiLibraryItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String sourceTool;
  final String? textContent;
  final String? audioUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isFavorite;

  const AiLibraryItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.sourceTool,
    this.textContent,
    this.audioUrl,
    this.metadata = const {},
    required this.createdAt,
    this.isFavorite = false,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasText => textContent != null && textContent!.trim().isNotEmpty;

  String get typeLabel {
    switch (type) {
      case 'lyrics':
        return 'Lyrics';
      case 'viral_score':
        return 'Viral Score';
      case 'vocal':
        return 'Vocal';
      case 'script_music':
        return 'Score';
      case 'stem':
        return 'Stems';
      case 'mood_playlist':
        return 'Playlist';
      case 'beat':
        return 'Beat';
      default:
        return 'AI';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'sourceTool': sourceTool,
      'textContent': textContent,
      'audioUrl': audioUrl,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'isFavorite': isFavorite,
    };
  }

  factory AiLibraryItem.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String userId,
  }) {
    final created = data['createdAt'];
    return AiLibraryItem(
      id: id,
      userId: userId,
      type: data['type'] as String? ?? 'unknown',
      title: data['title'] as String? ?? 'Untitled',
      sourceTool: data['sourceTool'] as String? ?? '',
      textContent: data['textContent'] as String?,
      audioUrl: data['audioUrl'] as String?,
      metadata: Map<String, dynamic>.from(
        data['metadata'] as Map? ?? const {},
      ),
      createdAt: created is Timestamp
          ? created.toDate()
          : DateTime.tryParse('$created') ?? DateTime.now(),
      isFavorite: data['isFavorite'] as bool? ?? false,
    );
  }

  AiLibraryItem copyWith({
    bool? isFavorite,
    String? audioUrl,
  }) {
    return AiLibraryItem(
      id: id,
      userId: userId,
      type: type,
      title: title,
      sourceTool: sourceTool,
      textContent: textContent,
      audioUrl: audioUrl ?? this.audioUrl,
      metadata: metadata,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
