import 'dart:async';
import 'dart:convert';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class BeatGenerationResult {
  final GeneratedBeat beat;
  final bool usedLocalPromptFallback;

  const BeatGenerationResult({
    required this.beat,
    required this.usedLocalPromptFallback,
  });
}

class AiBeatGeneratorService {
  AiBeatGeneratorService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final AudioPlayer _player = AudioPlayer();
  static String? _playingBeatId;
  static int? _playingTargetSeconds;
  static StreamSubscription<Duration>? _positionSubscription;

  static CollectionReference<Map<String, dynamic>> _beatsCollection(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_generated_beats');
  }

  static Stream<List<GeneratedBeat>> watchUserBeats({
    int limit = 20,
    bool favoritesOnly = false,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(const []);
    }

    // Fetch extra docs because failed/generating entries are filtered out client-side.
    final fetchLimit = favoritesOnly ? 100 : (limit * 4).clamp(limit, 80);

    Query<Map<String, dynamic>> query = _beatsCollection(userId);
    if (favoritesOnly) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(fetchLimit)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => GeneratedBeat.fromMap(doc.id, doc.data()))
                .where((beat) => beat.isLibraryReady)
                .take(limit)
                .toList();
          } catch (error, stackTrace) {
            logDebugException(
              'AiBeatGeneratorService.watchUserBeats parse',
              error,
              stackTrace: stackTrace,
            );
            rethrow;
          }
        })
        .handleError((Object error, StackTrace stackTrace) {
          logDebugException(
            'AiBeatGeneratorService.watchUserBeats stream',
            error,
            stackTrace: stackTrace,
          );
        });
  }

  static Future<BeatGenerationResult> generateBeat({
    required String description,
    required List<String> genres,
    required List<String> moods,
    required int bpm,
    required String keyLabel,
    required String length,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to generate beats.');
    }

    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('Describe your beat before generating.');
    }
    if (genres.isEmpty || moods.isEmpty) {
      throw ArgumentError('Select at least one genre and one mood.');
    }
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    final targetDurationSeconds = GeneratedBeat.parseLengthLabelToSeconds(length);

    final docRef = _beatsCollection(user.uid).doc();
    final pendingBeat = GeneratedBeat(
      id: docRef.id,
      userId: user.uid,
      title: 'Generating beat...',
      description: trimmedDescription,
      genres: genres,
      moods: moods,
      bpm: bpm,
      keyLabel: keyLabel,
      length: length,
      durationSeconds: targetDurationSeconds,
      status: 'generating',
      createdAt: DateTime.now(),
    );

    await docRef.set(pendingBeat.toMap());

    try {
      Map<String, String> blueprint;
      var usedLocalPromptFallback = false;

      try {
        blueprint = await _requestBeatBlueprint(
          description: trimmedDescription,
          genres: genres,
          moods: moods,
          bpm: bpm,
          keyLabel: keyLabel,
          length: length,
        );
      } catch (error, stackTrace) {
        logDebugException(
          'AiBeatGeneratorService.generateBeat openai',
          error,
          stackTrace: stackTrace,
        );
        blueprint = _buildFallbackBlueprint(
          description: trimmedDescription,
          genres: genres,
          moods: moods,
          bpm: bpm,
          keyLabel: keyLabel,
          length: length,
        );
        usedLocalPromptFallback = true;
      }

      final completedBeat = pendingBeat.copyWith(
        title: blueprint['title'] ?? 'Custom Beat',
        summary: blueprint['summary'] ?? trimmedDescription,
        arrangement: blueprint['arrangement'] ?? '',
        drums: blueprint['drums'] ?? '',
        bass: blueprint['bass'] ?? '',
        melody: blueprint['melody'] ?? '',
        mixNotes: blueprint['mixNotes'] ?? '',
        length: length,
        durationSeconds: targetDurationSeconds,
        status: 'completed',
      );

      await docRef.update({
        'title': completedBeat.title,
        'summary': completedBeat.summary,
        'length': completedBeat.length,
        'durationSeconds': completedBeat.durationSeconds,
        'arrangement': completedBeat.arrangement,
        'drums': completedBeat.drums,
        'bass': completedBeat.bass,
        'melody': completedBeat.melody,
        'mixNotes': completedBeat.mixNotes,
        'status': 'completed',
        'previewAudioUrl': null,
        'generationSource': usedLocalPromptFallback ? 'local_fallback' : 'openai',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return BeatGenerationResult(
        beat: completedBeat,
        usedLocalPromptFallback: usedLocalPromptFallback,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.generateBeat',
        error,
        stackTrace: stackTrace,
      );
      await _removePendingBeat(
        userId: user.uid,
        beatId: docRef.id,
      );
      throw Exception(beatGenerationErrorMessage(error));
    }
  }

  static String beatGenerationErrorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? error.toString();
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.trim().isEmpty) {
      return 'Could not generate beat blueprint. Please try again.';
    }
    return raw;
  }

  static Future<void> _removePendingBeat({
    required String userId,
    required String beatId,
  }) async {
    try {
      try {
        await _storage.ref('ai_generated_beats/$userId/$beatId.mp3').delete();
      } catch (error, stackTrace) {
        logDebugException(
          'AiBeatGeneratorService._removePendingBeat storage',
          error,
          stackTrace: stackTrace,
        );
      }
      await _beatsCollection(userId).doc(beatId).delete();
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService._removePendingBeat',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> setFavorite({
    required String beatId,
    required bool isFavorite,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Please sign in to update favorites.');
    }

    try {
      await _beatsCollection(userId).doc(beatId).update({
        'isFavorite': isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.setFavorite',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> deleteBeat(String beatId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Please sign in to delete beats.');
    }

    try {
      final docRef = _beatsCollection(userId).doc(beatId);
      final snapshot = await docRef.get();
      final data = snapshot.data();

      if (data != null) {
        final previewAudioUrl = data['previewAudioUrl'] as String?;
        if (previewAudioUrl != null && previewAudioUrl.trim().isNotEmpty) {
          try {
            await _storage.refFromURL(previewAudioUrl.trim()).delete();
          } catch (error, stackTrace) {
            logDebugException(
              'AiBeatGeneratorService.deleteBeat storage',
              error,
              stackTrace: stackTrace,
            );
          }
        } else {
          try {
            await _storage.ref('ai_generated_beats/$userId/$beatId.mp3').delete();
          } catch (error, stackTrace) {
            logDebugException(
              'AiBeatGeneratorService.deleteBeat storage fallback',
              error,
              stackTrace: stackTrace,
            );
          }
        }
      }

      await docRef.delete();
      if (_playingBeatId == beatId) {
        await stopPlayback();
      }
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.deleteBeat',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String? get playingBeatId => _playingBeatId;

  static bool get isPlaying => _player.playing;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  static Stream<Duration> get positionStream => _player.positionStream;

  static Stream<Duration?> get durationStream => _player.durationStream;

  static Future<void> playBeat(GeneratedBeat beat) async {
    final audioUrl = beat.previewAudioUrl?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      throw StateError('No generated beat audio is available yet.');
    }

    try {
      if (_playingBeatId == beat.id && _player.playing) {
        await _player.pause();
        return;
      }

      await _loadAndPlay(
        beat.id,
        audioUrl,
        targetDurationSeconds: beat.targetDuration.inSeconds,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.playBeat',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> startBeat(GeneratedBeat beat) async {
    final audioUrl = beat.previewAudioUrl?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      throw StateError('No generated beat audio is available yet.');
    }

    try {
      if (_playingBeatId == beat.id) {
        if (!_player.playing) {
          await _player.play();
        }
        return;
      }

      await _loadAndPlay(
        beat.id,
        audioUrl,
        targetDurationSeconds: beat.targetDuration.inSeconds,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.startBeat',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  static Future<void> seek(Duration position) async {
    await _player.seek(_clampPosition(position));
  }

  static Future<void> seekRelative(Duration offset) async {
    await _player.seek(_clampPosition(_player.position + offset));
  }

  static Duration _clampPosition(Duration position) {
    var target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    }

    final cap = _playbackCapDuration();
    if (cap != null && target > cap) {
      target = cap;
    }

    final fileDuration = _player.duration;
    if (fileDuration != null &&
        fileDuration > Duration.zero &&
        target > fileDuration) {
      target = fileDuration;
    }

    return target;
  }

  static Duration? _playbackCapDuration() {
    final seconds = _playingTargetSeconds;
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  static Future<void> _loadAndPlay(
    String beatId,
    String audioUrl, {
    required int targetDurationSeconds,
  }) async {
    await _positionSubscription?.cancel();
    _playingTargetSeconds =
        targetDurationSeconds > 0 ? targetDurationSeconds : null;

    await _player.stop();
    await _player.setUrl(audioUrl);
    _playingBeatId = beatId;

    _positionSubscription = _player.positionStream.listen((position) {
      final cap = _playbackCapDuration();
      if (cap == null) {
        return;
      }
      if (position >= cap - const Duration(milliseconds: 80)) {
        _player.pause();
        _player.seek(cap);
      }
    });

    await _player.play();
  }

  static Future<void> stopPlayback() async {
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _playingTargetSeconds = null;
      await _player.stop();
      _playingBeatId = null;
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService.stopPlayback',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, String>> _requestBeatBlueprint({
    required String description,
    required List<String> genres,
    required List<String> moods,
    required int bpm,
    required String keyLabel,
    required String length,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(OpenAiConfig.chatCompletionsUrl),
        headers: OpenAiConfig.jsonAuthHeaders,
        body: jsonEncode({
          'model': OpenAiConfig.chatModel,
          'temperature': 0.75,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are Beat Jerky\'s AI beat producer. Return only valid JSON with keys: '
                  'title, summary (2 sentences), arrangement (section-by-section structure), '
                  'drums (kick, snare, hats, patterns), bass (sound and pattern notes), '
                  'melody (chords, lead, hooks), mixNotes (EQ, sidechain, space). '
                  'Be specific and actionable for a producer building this beat in a DAW.',
            },
            {
              'role': 'user',
              'content':
                  'Create a full beat blueprint.\nDescription: $description\n'
                  'Genres: ${genres.join(', ')}\nMoods: ${moods.join(', ')}\n'
                  'BPM: $bpm\nKey: $keyLabel\nLength: $length',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw OpenAiConfig.requestException(response);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw Exception('Beat blueprint generation returned an empty response.');
      }

      final spec = jsonDecode(content) as Map<String, dynamic>;
      final title = (spec['title'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        throw Exception('Beat blueprint returned invalid JSON.');
      }

      return {
        'title': title,
        'summary': (spec['summary'] as String?)?.trim() ?? '',
        'arrangement': (spec['arrangement'] as String?)?.trim() ?? '',
        'drums': (spec['drums'] as String?)?.trim() ?? '',
        'bass': (spec['bass'] as String?)?.trim() ?? '',
        'melody': (spec['melody'] as String?)?.trim() ?? '',
        'mixNotes': (spec['mixNotes'] as String?)?.trim() ?? '',
      };
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorService._requestBeatBlueprint',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Map<String, String> _buildFallbackBlueprint({
    required String description,
    required List<String> genres,
    required List<String> moods,
    required int bpm,
    required String keyLabel,
    required String length,
  }) {
    final genreLabel = genres.join(' / ');
    final moodLabel = moods.join(' / ');

    return {
      'title': '$genreLabel $moodLabel Beat',
      'summary':
          'Instrumental $genreLabel beat at $bpm BPM in $keyLabel. $description',
      'arrangement':
          'Intro (4 bars) → Verse (16 bars) → Chorus (8 bars) → Verse → Chorus → Outro (4 bars). Total target: $length.',
      'drums':
          'Hard $bpm kick on 1 and 3, snare on 2 and 4, rolling hi-hats with triplet fills every 8 bars.',
      'bass':
          'Sub bass following root notes in $keyLabel, sidechained to kick, simple two-note pattern.',
      'melody':
          'Dark $moodLabel lead synth with sparse chord stabs, catchy 4-bar hook in the chorus.',
      'mixNotes':
          'High-pass non-bass elements at 100Hz, glue compression on drums, wide reverb on melody, limiter at -1dB.',
    };
  }
}
