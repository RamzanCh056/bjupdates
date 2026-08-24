import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/model/music_track_model.dart';
import 'package:beatjerky/services/music_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class MoodPlaylistTrack {
  final String title;
  final String vibe;
  final String duration;
  final String? genre;
  final String? artist;
  final String? audioUrl;
  final String? coverUrl;
  final String? catalogTrackId;

  const MoodPlaylistTrack({
    required this.title,
    required this.vibe,
    required this.duration,
    this.genre,
    this.artist,
    this.audioUrl,
    this.coverUrl,
    this.catalogTrackId,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  String get subtitle {
    final parts = <String>[];
    if (artist != null && artist!.trim().isNotEmpty) {
      parts.add(artist!.trim());
    } else if (vibe.trim().isNotEmpty) {
      parts.add(vibe.trim());
    }
    if (duration.trim().isNotEmpty) parts.add(duration.trim());
    return parts.join(' · ');
  }

  factory MoodPlaylistTrack.fromJson(Map<String, dynamic> json) {
    return MoodPlaylistTrack(
      title: (json['title'] as String?)?.trim() ?? 'Untitled',
      vibe: (json['vibe'] as String?)?.trim() ?? '',
      duration: (json['duration'] as String?)?.trim() ?? '3:00',
      genre: (json['genre'] as String?)?.trim(),
    );
  }

  MoodPlaylistTrack copyWith({
    String? title,
    String? vibe,
    String? duration,
    String? genre,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    String? catalogTrackId,
  }) {
    return MoodPlaylistTrack(
      title: title ?? this.title,
      vibe: vibe ?? this.vibe,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      catalogTrackId: catalogTrackId ?? this.catalogTrackId,
    );
  }
}

class MoodPlaylistResult {
  final String playlistName;
  final String summary;
  final List<MoodPlaylistTrack> tracks;

  const MoodPlaylistResult({
    required this.playlistName,
    required this.summary,
    required this.tracks,
  });

  MoodPlaylistResult copyWith({
    String? playlistName,
    String? summary,
    List<MoodPlaylistTrack>? tracks,
  }) {
    return MoodPlaylistResult(
      playlistName: playlistName ?? this.playlistName,
      summary: summary ?? this.summary,
      tracks: tracks ?? this.tracks,
    );
  }

  String toLibraryText() {
    final buffer = StringBuffer()
      ..writeln(playlistName)
      ..writeln()
      ..writeln(summary)
      ..writeln()
      ..writeln('Tracks:');
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final artist = t.artist != null && t.artist!.isNotEmpty
          ? ' — ${t.artist}'
          : (t.vibe.isNotEmpty ? ' — ${t.vibe}' : '');
      buffer.writeln('${i + 1}. ${t.title} (${t.duration})$artist');
    }
    return buffer.toString().trim();
  }
}

/// Mood Radio uses the existing OpenAI chat API for DJ recommendations,
/// then matches them to playable [musicTracks] via [MusicService] patterns.
class AiMoodRadioService {
  AiMoodRadioService._();

  static final AudioPlayer _player = AudioPlayer();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _currentUrl;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  static bool get isPlaying => _player.playing;

  /// OpenAI playlist concepts + catalog resolution in one call.
  static Future<MoodPlaylistResult> generatePlaylist(String mood) async {
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    final trimmed = mood.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Describe your mood first.');
    }

    final concepts = await _requestPlaylistConcepts(trimmed);
    final catalog = await _fetchCatalogTracks();
    final resolved = _resolveAgainstCatalog(
      concepts: concepts,
      catalog: catalog,
      mood: trimmed,
    );

    return resolved;
  }

  static Future<MoodPlaylistResult> _requestPlaylistConcepts(String mood) async {
    final response = await http
        .post(
          Uri.parse(OpenAiConfig.chatCompletionsUrl),
          headers: OpenAiConfig.jsonAuthHeaders,
          body: jsonEncode({
            'model': OpenAiConfig.chatModel,
            'temperature': 0.85,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a DJ for BeatJerky Mood Radio. Recommend a personalized 5-track playlist flow '
                    'for the user\'s mood and music taste. '
                    'Return JSON: playlistName (string), summary (one sentence), tracks (array of 5 objects with '
                    'title, vibe, duration like "3:12", genre like "Hip Hop"/"Trap"/"R&B"/"Pop"/"Electronic"). '
                    'Prefer genres that fit a music catalog. Tracks can be original concepts that describe the feel.',
              },
              {'role': 'user', 'content': 'My mood: $mood'},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    log('AiMoodRadio status=${response.statusCode}');

    if (response.statusCode != 200) {
      throw OpenAiConfig.requestException(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty playlist response.');
    }

    final spec = jsonDecode(content) as Map<String, dynamic>;
    final tracksRaw = spec['tracks'] as List? ?? const [];
    final tracks = tracksRaw
        .whereType<Map>()
        .map((e) => MoodPlaylistTrack.fromJson(Map<String, dynamic>.from(e)))
        .take(5)
        .toList();

    if (tracks.isEmpty) {
      throw Exception('Could not build playlist.');
    }

    return MoodPlaylistResult(
      playlistName:
          (spec['playlistName'] as String?)?.trim() ?? 'Your Mood Mix',
      summary: (spec['summary'] as String?)?.trim() ?? '',
      tracks: tracks,
    );
  }

  static Future<List<MusicTrack>> _fetchCatalogTracks() async {
    try {
      final snapshot = await _firestore
          .collection('musicTracks')
          .orderBy('useCount', descending: true)
          .limit(80)
          .get();
      return snapshot.docs
          .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
          .where((t) => t.audioUrl.trim().isNotEmpty)
          .toList();
    } catch (e) {
      log('AiMoodRadio catalog fetch failed: $e');
      try {
        final snapshot =
            await _firestore.collection('musicTracks').limit(80).get();
        return snapshot.docs
            .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
            .where((t) => t.audioUrl.trim().isNotEmpty)
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static MoodPlaylistResult _resolveAgainstCatalog({
    required MoodPlaylistResult concepts,
    required List<MusicTrack> catalog,
    required String mood,
  }) {
    if (catalog.isEmpty) return concepts;

    final used = <String>{};
    final resolved = <MoodPlaylistTrack>[];

    for (final concept in concepts.tracks) {
      final match = _bestCatalogMatch(
        concept: concept,
        catalog: catalog,
        mood: mood,
        usedIds: used,
      );
      if (match != null) {
        used.add(match.id);
        resolved.add(
          concept.copyWith(
            title: match.title.isNotEmpty ? match.title : concept.title,
            artist: match.artist,
            audioUrl: match.audioUrl,
            coverUrl: match.coverImageUrl,
            duration: match.duration > 0
                ? match.durationFormatted
                : concept.duration,
            catalogTrackId: match.id,
            genre: match.genre.isNotEmpty ? match.genre : concept.genre,
          ),
        );
      } else {
        resolved.add(concept);
      }
    }

    // Fill gaps with unused trending catalog tracks so radio can still stream.
    if (resolved.where((t) => t.hasAudio).length < 3) {
      for (final track in catalog) {
        if (used.contains(track.id)) continue;
        if (resolved.length >= 5 &&
            resolved.every((t) => t.hasAudio)) {
          break;
        }
        final emptySlot = resolved.indexWhere((t) => !t.hasAudio);
        final mapped = MoodPlaylistTrack(
          title: track.title,
          vibe: track.genre.isNotEmpty ? track.genre : 'Catalog pick',
          duration: track.durationFormatted,
          genre: track.genre,
          artist: track.artist,
          audioUrl: track.audioUrl,
          coverUrl: track.coverImageUrl,
          catalogTrackId: track.id,
        );
        if (emptySlot >= 0) {
          resolved[emptySlot] = mapped;
        } else if (resolved.length < 5) {
          resolved.add(mapped);
        } else {
          break;
        }
        used.add(track.id);
      }
    }

    return concepts.copyWith(tracks: resolved);
  }

  static MusicTrack? _bestCatalogMatch({
    required MoodPlaylistTrack concept,
    required List<MusicTrack> catalog,
    required String mood,
    required Set<String> usedIds,
  }) {
    MusicTrack? best;
    var bestScore = 0;

    final needles = <String>{
      ..._tokens(mood),
      ..._tokens(concept.title),
      ..._tokens(concept.vibe),
      ..._tokens(concept.genre ?? ''),
    };

    for (final track in catalog) {
      if (usedIds.contains(track.id)) continue;
      var score = 0;
      final hay = {
        ..._tokens(track.title),
        ..._tokens(track.artist),
        ..._tokens(track.genre),
      };

      for (final n in needles) {
        if (hay.contains(n)) score += 3;
        if (track.genre.toLowerCase().contains(n)) score += 4;
        if (track.title.toLowerCase().contains(n)) score += 2;
      }

      if ((concept.genre ?? '').isNotEmpty &&
          track.genre.toLowerCase() == concept.genre!.toLowerCase()) {
        score += 8;
      }

      if (score > bestScore) {
        bestScore = score;
        best = track;
      }
    }

    // Require a little signal, otherwise leave unmatched for filler pass.
    if (bestScore < 3) return null;
    return best;
  }

  static Set<String> _tokens(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3)
        .toSet();
  }

  static Future<void> playTrack(MoodPlaylistTrack track) async {
    final url = track.audioUrl?.trim();
    if (url == null || url.isEmpty) {
      throw StateError('No playable audio for this track yet.');
    }

    if (_currentUrl == url &&
        !_player.playing &&
        _player.processingState != ProcessingState.idle &&
        _player.processingState != ProcessingState.completed) {
      await _player.play();
      return;
    }

    _currentUrl = url;
    await _player.setUrl(url);
    await _player.play();

    final catalogId = track.catalogTrackId;
    if (catalogId != null && catalogId.isNotEmpty) {
      unawaited(MusicService.incrementUseCount(catalogId));
    }
  }

  static Future<void> pause() => _player.pause();

  static Future<void> resume() => _player.play();

  static Future<void> stop() async {
    _currentUrl = null;
    await _player.stop();
  }

  static Future<void> disposePlayer() async {
    _currentUrl = null;
    await _player.stop();
  }

  static String errorMessage(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.contains('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return raw;
  }
}
