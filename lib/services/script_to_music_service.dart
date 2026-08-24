import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ScriptToMusicTrack {
  final Uint8List audioBytes;
  final String title;
  final String meta;
  final String lengthLabel;
  final int durationSeconds;
  final List<String> genres;
  final List<String> moods;
  final String? sourceUrl;
  final String? scoreGuide;

  const ScriptToMusicTrack({
    required this.audioBytes,
    required this.title,
    required this.meta,
    required this.lengthLabel,
    required this.durationSeconds,
    required this.genres,
    required this.moods,
    this.sourceUrl,
    this.scoreGuide,
  });

  bool get hasAudio => audioBytes.isNotEmpty;
  bool get hasScoreGuide => scoreGuide != null && scoreGuide!.trim().isNotEmpty;
}

class ScriptToMusicService {
  ScriptToMusicService._();

  static final AudioPlayer _player = AudioPlayer();
  static File? _tempAudioFile;
  static int? _playbackCapSeconds;
  static StreamSubscription<Duration>? _positionSubscription;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  static Stream<Duration> get positionStream => _player.positionStream;
  static bool get isPlaying => _player.playing;

  static Future<ScriptToMusicTrack> generate({
    required String script,
    required List<String> genres,
    required List<String> moods,
    required String durationLabel,
    required String tempo,
    required bool instrumental,
    required double creativity,
  }) async {
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    final trimmedScript = script.trim();
    if (trimmedScript.isEmpty) {
      throw ArgumentError('Enter your script before generating music.');
    }
    if (genres.isEmpty || moods.isEmpty) {
      throw ArgumentError('Select at least one genre and one mood.');
    }

    final durationSeconds =
        GeneratedBeat.parseLengthLabelToSeconds(durationLabel);
    final genreLabel = genres.join(', ');
    final moodLabel = moods.join(', ');
    final title = _deriveTitle(trimmedScript);

    try {
      final scoreGuide = await _requestScoreGuide(
        script: trimmedScript,
        genres: genres,
        moods: moods,
        durationLabel: durationLabel,
        tempo: tempo,
        instrumental: instrumental,
        creativity: creativity,
      );

      return ScriptToMusicTrack(
        audioBytes: Uint8List(0),
        title: title,
        meta: '$durationLabel • $genreLabel • $moodLabel',
        lengthLabel: durationLabel,
        durationSeconds: durationSeconds,
        genres: genres,
        moods: moods,
        scoreGuide: scoreGuide,
      );
    } catch (error, stackTrace) {
      logDebugException('ScriptToMusicService.generate', error, stackTrace: stackTrace);
      throw Exception(AiBeatGeneratorService.beatGenerationErrorMessage(error));
    }
  }

  static Future<String> _requestScoreGuide({
    required String script,
    required List<String> genres,
    required List<String> moods,
    required String durationLabel,
    required String tempo,
    required bool instrumental,
    required double creativity,
  }) async {
    final response = await http.post(
      Uri.parse(OpenAiConfig.chatCompletionsUrl),
      headers: OpenAiConfig.jsonAuthHeaders,
      body: jsonEncode({
        'model': OpenAiConfig.chatModel,
        'temperature': (0.4 + creativity * 0.8).clamp(0.4, 1.2),
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a film/TV composer for BeatJerky. Write a detailed cinematic score guide: '
                'cue breakdown with timestamps, instrumentation, dynamics, and emotional arc. '
                'Format with clear section headers. Be production-ready.',
          },
          {
            'role': 'user',
            'content':
                'Script/scene:\n$script\n\nGenres: ${genres.join(', ')}\n'
                'Moods: ${moods.join(', ')}\nDuration: $durationLabel\n'
                'Tempo feel: $tempo\nInstrumental only: $instrumental',
          },
        ],
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw OpenAiConfig.requestException(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Score guide generation returned empty content.');
    }
    return content.trim();
  }

  static Future<void> play(Uint8List bytes, {required int durationSeconds}) async {
    if (bytes.isEmpty) {
      throw StateError('No audio for this score — open the score guide instead.');
    }
    await stop();
    _playbackCapSeconds = durationSeconds > 0 ? durationSeconds : null;

    final tempDir = await getTemporaryDirectory();
    _tempAudioFile = File(
      '${tempDir.path}/script_music_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await _tempAudioFile!.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(_tempAudioFile!.path);

    await _positionSubscription?.cancel();
    _positionSubscription = _player.positionStream.listen((position) {
      final cap = _playbackCapSeconds;
      if (cap == null) return;
      if (position >= Duration(seconds: cap) - const Duration(milliseconds: 80)) {
        _player.pause();
        _player.seek(Duration(seconds: cap));
      }
    });
    await _player.play();
  }

  static Future<void> pause() => _player.pause();

  static Future<void> resume() => _player.play();

  static Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _playbackCapSeconds = null;
    await _player.stop();
    if (_tempAudioFile != null && await _tempAudioFile!.exists()) {
      await _tempAudioFile!.delete();
      _tempAudioFile = null;
    }
  }

  static Future<File> writeShareableFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/script_music_share_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _deriveTitle(String script) {
    final firstLine = script
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Scene Score');
    if (firstLine.length <= 80) {
      return firstLine;
    }
    return '${firstLine.substring(0, 77)}...';
  }

}
