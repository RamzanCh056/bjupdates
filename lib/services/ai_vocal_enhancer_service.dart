import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class VocalEnhancerSettings {
  final bool removeNoise;
  final bool pitchCorrection;
  final bool autoTune;
  final bool improveClarity;
  final bool studioQuality;

  const VocalEnhancerSettings({
    required this.removeNoise,
    required this.pitchCorrection,
    required this.autoTune,
    required this.improveClarity,
    required this.studioQuality,
  });
}

class UploadedVocalFile {
  final String fileName;
  final String localPath;
  final int durationSeconds;

  const UploadedVocalFile({
    required this.fileName,
    required this.localPath,
    required this.durationSeconds,
  });

  String get durationLabel =>
      AiVocalEnhancerService.formatLengthLabel(durationSeconds);
}

class EnhancedVocalResult {
  final Uint8List audioBytes;
  final String fileName;
  final int durationSeconds;
  final String? coachingGuide;

  const EnhancedVocalResult({
    required this.audioBytes,
    required this.fileName,
    required this.durationSeconds,
    this.coachingGuide,
  });

  bool get isGuideOnly => coachingGuide != null && audioBytes.isEmpty;

  String get durationLabel =>
      AiVocalEnhancerService.formatLengthLabel(durationSeconds);
}

class AiVocalEnhancerService {
  AiVocalEnhancerService._();

  static const int _maxUploadSeconds = 480;

  static final AudioPlayer _rawPlayer = AudioPlayer();
  static final AudioPlayer _enhancedPlayer = AudioPlayer();
  static StreamSubscription<Duration>? _enhancedPositionSub;
  static int? _enhancedCapSeconds;
  static File? _enhancedTempFile;

  static Stream<PlayerState> get rawPlayerStateStream =>
      _rawPlayer.playerStateStream;
  static Stream<PlayerState> get enhancedPlayerStateStream =>
      _enhancedPlayer.playerStateStream;
  static bool get isRawPlaying => _rawPlayer.playing;
  static bool get isEnhancedPlaying => _enhancedPlayer.playing;

  static Future<UploadedVocalFile> probeLocalVocal({
    required String fileName,
    required String localPath,
  }) async {
    final durationSeconds = await _readLocalDurationSeconds(localPath);
    return UploadedVocalFile(
      fileName: fileName,
      localPath: localPath,
      durationSeconds: durationSeconds,
    );
  }

  static Future<EnhancedVocalResult> enhanceVocal({
    required UploadedVocalFile uploaded,
    required VocalEnhancerSettings settings,
  }) async {
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    final guide = await _requestVocalCoachingGuide(
      fileName: uploaded.fileName,
      durationSeconds: uploaded.durationSeconds,
      settings: settings,
    );

    final baseName = uploaded.fileName.contains('.')
        ? uploaded.fileName.substring(0, uploaded.fileName.lastIndexOf('.'))
        : uploaded.fileName;

    return EnhancedVocalResult(
      audioBytes: Uint8List(0),
      fileName: '${baseName}_Coaching',
      durationSeconds: uploaded.durationSeconds,
      coachingGuide: guide,
    );
  }

  static Future<String> _requestVocalCoachingGuide({
    required String fileName,
    required int durationSeconds,
    required VocalEnhancerSettings settings,
  }) async {
    final response = await http.post(
      Uri.parse(OpenAiConfig.chatCompletionsUrl),
      headers: OpenAiConfig.jsonAuthHeaders,
      body: jsonEncode({
        'model': OpenAiConfig.chatModel,
        'temperature': 0.65,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a vocal production coach for BeatJerky. Give practical step-by-step '
                'enhancement advice for mixing and polishing vocals in a DAW. Include EQ, compression, '
                'de-ess, reverb, pitch, and tuning tips based on the requested settings.',
          },
          {
            'role': 'user',
            'content':
                'Vocal file: $fileName (${formatLengthLabel(durationSeconds)})\n'
                'Remove noise: ${settings.removeNoise}\n'
                'Pitch correction: ${settings.pitchCorrection}\n'
                'Auto-tune: ${settings.autoTune}\n'
                'Improve clarity: ${settings.improveClarity}\n'
                'Studio quality: ${settings.studioQuality}',
          },
        ],
      }),
    ).timeout(const Duration(seconds: 75));

    if (response.statusCode != 200) {
      throw OpenAiConfig.requestException(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Vocal coaching returned empty content.');
    }
    return content.trim();
  }

  static Future<void> playRaw(String localPath) async {
    await stopEnhanced();
    await _rawPlayer.stop();
    await _rawPlayer.setFilePath(localPath);
    await _rawPlayer.play();
  }

  static Future<void> pauseRaw() => _rawPlayer.pause();

  static Future<void> playEnhanced(
    Uint8List bytes, {
    required int durationSeconds,
  }) async {
    await stopEnhanced();
    await _rawPlayer.pause();

    _enhancedCapSeconds = durationSeconds > 0 ? durationSeconds : null;
    final tempDir = await getTemporaryDirectory();
    _enhancedTempFile = File(
      '${tempDir.path}/enhanced_vocal_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await _enhancedTempFile!.writeAsBytes(bytes, flush: true);
    await _enhancedPlayer.setFilePath(_enhancedTempFile!.path);

    await _enhancedPositionSub?.cancel();
    _enhancedPositionSub = _enhancedPlayer.positionStream.listen((position) {
      final cap = _enhancedCapSeconds;
      if (cap == null) return;
      if (position >= Duration(seconds: cap) - const Duration(milliseconds: 80)) {
        _enhancedPlayer.pause();
        _enhancedPlayer.seek(Duration(seconds: cap));
      }
    });
    await _enhancedPlayer.play();
  }

  static Future<void> pauseEnhanced() => _enhancedPlayer.pause();

  static Future<void> resumeEnhanced() => _enhancedPlayer.play();

  static bool get hasEnhancedLoaded =>
      _enhancedTempFile != null && _enhancedTempFile!.existsSync();

  static Future<void> stopEnhanced() async {
    await _enhancedPositionSub?.cancel();
    _enhancedPositionSub = null;
    _enhancedCapSeconds = null;
    await _enhancedPlayer.stop();
    if (_enhancedTempFile != null && await _enhancedTempFile!.exists()) {
      await _enhancedTempFile!.delete();
      _enhancedTempFile = null;
    }
  }

  static Future<void> stopAll() async {
    await stopEnhanced();
    await _rawPlayer.stop();
  }

  static Future<File> writeShareableFile(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = fileName.trim().isEmpty ? 'enhanced_vocal.mp3' : fileName;
    final file = File('${tempDir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String errorMessage(Object error) {
    return AiBeatGeneratorService.beatGenerationErrorMessage(error);
  }

  static Future<int> _readLocalDurationSeconds(String path) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(path);
      var duration = player.duration;
      if (duration == null || duration == Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 400));
        duration = player.duration;
      }
      final seconds = duration?.inSeconds ?? 0;
      return seconds > 0 ? seconds.clamp(1, _maxUploadSeconds) : 60;
    } catch (error, stackTrace) {
      logDebugException(
        'AiVocalEnhancerService._readLocalDurationSeconds',
        error,
        stackTrace: stackTrace,
      );
      return 60;
    } finally {
      await player.dispose();
    }
  }

  static String formatLengthLabel(int seconds) {
    final safe = seconds.clamp(0, 5999);
    final minutes = safe ~/ 60;
    final remaining = safe % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

}
