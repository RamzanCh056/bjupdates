import 'dart:convert';
import 'dart:developer';

import 'package:beatjerky/config/openai_config.dart';
import 'package:http/http.dart' as http;

class StemAnalysisResult {
  final String trackName;
  final String summary;
  final List<String> stemNotes;
  final String mixingTips;

  const StemAnalysisResult({
    required this.trackName,
    required this.summary,
    required this.stemNotes,
    required this.mixingTips,
  });

  String toLibraryText() {
    final buffer = StringBuffer()
      ..writeln('Track: $trackName')
      ..writeln()
      ..writeln(summary)
      ..writeln()
      ..writeln('Stem breakdown:');
    for (final note in stemNotes) {
      buffer.writeln('• $note');
    }
    buffer
      ..writeln()
      ..writeln('Mixing tips:')
      ..writeln(mixingTips);
    return buffer.toString().trim();
  }
}

class StemSplitterService {
  StemSplitterService._();

  static Future<StemAnalysisResult> analyzeTrack({
    required String fileName,
    required int durationSeconds,
    required List<String> selectedStems,
    required String quality,
    required String format,
  }) async {
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    if (selectedStems.isEmpty) {
      throw ArgumentError('Select at least one stem.');
    }

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationLabel = '$minutes:${seconds.toString().padLeft(2, '0')}';

    final response = await http
        .post(
          Uri.parse(OpenAiConfig.chatCompletionsUrl),
          headers: OpenAiConfig.jsonAuthHeaders,
          body: jsonEncode({
            'model': OpenAiConfig.chatModel,
            'temperature': 0.6,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a stem separation expert for BeatJerky. Analyze track metadata and explain how to isolate requested stems. '
                    'Return JSON: summary (string), stemNotes (array of strings, one per requested stem with extraction tips), '
                    'mixingTips (string). Be practical for independent artists.',
              },
              {
                'role': 'user',
                'content':
                    'Track: $fileName\nDuration: $durationLabel\n'
                    'Stems requested: ${selectedStems.join(', ')}\n'
                    'Quality: $quality\nFormat: $format',
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    log('StemSplitter analyze status=${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Stem analysis failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty analysis response.');
    }

    final spec = jsonDecode(content) as Map<String, dynamic>;
    final notesRaw = spec['stemNotes'] as List? ?? const [];

    return StemAnalysisResult(
      trackName: fileName,
      summary: (spec['summary'] as String?)?.trim() ?? 'Stem analysis complete.',
      stemNotes: notesRaw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      mixingTips: (spec['mixingTips'] as String?)?.trim() ?? '',
    );
  }
}
