import 'dart:convert';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class ViralScoreMetric {
  final String label;
  final int score;

  const ViralScoreMetric({
    required this.label,
    required this.score,
  });
}

class ViralScoreResult {
  final int overallScore;
  final String verdictLabel;
  final List<ViralScoreMetric> metrics;
  final List<String> improvementTips;
  final String summary;

  const ViralScoreResult({
    required this.overallScore,
    required this.verdictLabel,
    required this.metrics,
    required this.improvementTips,
    required this.summary,
  });
}

class UploadedTrackInfo {
  final String fileName;
  final String localPath;
  final int durationSeconds;

  const UploadedTrackInfo({
    required this.fileName,
    required this.localPath,
    required this.durationSeconds,
  });

  String get durationLabel => ViralScorePredictorService.formatDuration(durationSeconds);
}

class ViralScorePredictorService {
  ViralScorePredictorService._();

  static final AudioPlayer _player = AudioPlayer();

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  static bool get isPlaying => _player.playing;

  static Future<UploadedTrackInfo> probeLocalTrack({
    required String fileName,
    required String localPath,
  }) async {
    final durationSeconds = await _readDurationSeconds(localPath);
    return UploadedTrackInfo(
      fileName: fileName,
      localPath: localPath,
      durationSeconds: durationSeconds,
    );
  }

  static Future<ViralScoreResult> predict({
    required UploadedTrackInfo track,
    String trackNotes = '',
  }) async {
    if (!OpenAiConfig.isConfigured) {
      throw Exception(OpenAiConfig.missingApiKeyMessage);
    }

    return _requestOpenAiPrediction(track: track, trackNotes: trackNotes);
  }

  static Future<ViralScoreResult> _requestOpenAiPrediction({
    required UploadedTrackInfo track,
    required String trackNotes,
  }) async {
    final response = await http.post(
      Uri.parse(OpenAiConfig.chatCompletionsUrl),
      headers: OpenAiConfig.jsonAuthHeaders,
      body: jsonEncode({
        'model': OpenAiConfig.chatModel,
        'temperature': 0.65,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'You are Beat Jerky\'s Viral Score Predictor for music creators. '
                'Estimate short-form and streaming viral potential from track metadata and creator notes. '
                'Return only valid JSON with keys: overallScore (0-100 int), verdictLabel (short phrase with one emoji), '
                'metrics (array of exactly 4 objects with label and score), improvementTips (array of 3-5 strings), '
                'summary (one sentence). '
                'Metric labels must be exactly: Hook, Structure, Originality, Mix Quality. '
                'Each metric score is 0-100 int. Be realistic and constructive.',
          },
          {
            'role': 'user',
            'content':
                'Analyze viral potential.\n'
                'File: ${track.fileName}\n'
                'Duration: ${track.durationLabel} (${track.durationSeconds}s)\n'
                'Creator notes: ${trackNotes.trim().isEmpty ? 'No extra notes provided.' : trackNotes.trim()}',
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw OpenAiConfig.requestException(response);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Viral score prediction returned empty content.');
    }

    final spec = jsonDecode(content) as Map<String, dynamic>;
    return _parsePrediction(spec);
  }

  static ViralScoreResult _parsePrediction(Map<String, dynamic> spec) {
    final overall = (spec['overallScore'] as num?)?.round().clamp(0, 100) ?? 0;
    final verdict = (spec['verdictLabel'] as String?)?.trim();
    final summary = (spec['summary'] as String?)?.trim() ?? '';
    final tipsRaw = spec['improvementTips'];
    final metricsRaw = spec['metrics'];

    final tips = <String>[];
    if (tipsRaw is List) {
      for (final item in tipsRaw) {
        if (item is String && item.trim().isNotEmpty) {
          tips.add(item.trim());
        }
      }
    }

    final metrics = <ViralScoreMetric>[];
    const expectedLabels = ['Hook', 'Structure', 'Originality', 'Mix Quality'];
    if (metricsRaw is List) {
      for (final item in metricsRaw) {
        if (item is! Map<String, dynamic>) continue;
        final label = (item['label'] as String?)?.trim();
        final score = (item['score'] as num?)?.round().clamp(0, 100);
        if (label == null || label.isEmpty || score == null) continue;
        metrics.add(ViralScoreMetric(label: label, score: score));
      }
    }

    for (final label in expectedLabels) {
      if (!metrics.any((m) => m.label == label)) {
        metrics.add(ViralScoreMetric(label: label, score: overall));
      }
    }

    final ordered = expectedLabels
        .map((label) => metrics.firstWhere((m) => m.label == label))
        .toList();

    return ViralScoreResult(
      overallScore: overall > 0 ? overall : _averageMetricScore(ordered),
      verdictLabel: verdict?.isNotEmpty == true
          ? verdict!
          : verdictFromScore(overall > 0 ? overall : _averageMetricScore(ordered)),
      metrics: ordered,
      improvementTips: tips.isEmpty
          ? _defaultTips(ordered)
          : tips.take(5).toList(),
      summary: summary.isEmpty
          ? 'Analysis based on your track details and creator notes.'
          : summary,
    );
  }

  static List<String> _defaultTips(List<ViralScoreMetric> metrics) {
    final weakest = metrics.reduce(
      (a, b) => a.score <= b.score ? a : b,
    );
    return [
      'Strengthen your ${weakest.label.toLowerCase()} — it scores lowest right now.',
      'Open with a hook in the first 1–3 seconds for TikTok and Reels.',
      'Target one platform first (TikTok, Reels, or Shorts) and tailor length.',
      'Add a clear drop or switch at the midpoint to boost replays.',
      'A/B test two intros and post the version with higher retention.',
    ];
  }

  static int _averageMetricScore(List<ViralScoreMetric> metrics) {
    if (metrics.isEmpty) return 50;
    final total = metrics.fold<int>(0, (sum, m) => sum + m.score);
    return (total / metrics.length).round().clamp(0, 100);
  }

  static String verdictFromScore(int score) {
    if (score >= 85) return 'Excellent Viral Potential 🚀';
    if (score >= 70) return 'Good Potential 🔥';
    if (score >= 50) return 'Moderate Potential ✨';
    return 'Needs Work 📈';
  }

  static String formatDuration(int seconds) {
    final safe = seconds.clamp(0, 5999);
    final minutes = safe ~/ 60;
    final remaining = safe % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  static Future<void> playTrack(String localPath) async {
    await _player.stop();
    await _player.setFilePath(localPath);
    await _player.play();
  }

  static Future<void> pauseTrack() => _player.pause();

  static Future<void> stopTrack() => _player.stop();

  static Future<int> _readDurationSeconds(String path) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(path);
      var duration = player.duration;
      if (duration == null || duration == Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 400));
        duration = player.duration;
      }
      final seconds = duration?.inSeconds ?? 0;
      return seconds > 0 ? seconds.clamp(1, 600) : 60;
    } catch (error, stackTrace) {
      logDebugException(
        'ViralScorePredictorService._readDurationSeconds',
        error,
        stackTrace: stackTrace,
      );
      return 60;
    } finally {
      await player.dispose();
    }
  }

  static String errorMessage(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
