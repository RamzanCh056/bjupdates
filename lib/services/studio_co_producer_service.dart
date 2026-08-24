import 'dart:convert';
import 'dart:io';

import 'package:beatjerky/config/gemini_config.dart';
import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/services/gemini_service.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;

/// Co-Producer analysis using existing Gemini / OpenAI configs.
class StudioCoProducerService {
  StudioCoProducerService._();

  static Future<StudioTrackAnalysis> analyze(StudioTrackInput input) async {
    try {
      if (input.hasAudioFile) {
        return await _analyzeAudio(input);
      }
      if (input.hasDescription) {
        return await _analyzeText(input);
      }
    } catch (error, stackTrace) {
      logDebugException(
        'StudioCoProducerService.analyze',
        error,
        stackTrace: stackTrace,
      );
    }
    return StudioTrackAnalysis.fromInput(input);
  }

  static Future<StudioTrackAnalysis> _analyzeText(StudioTrackInput input) async {
    final prompt =
        'You are BeatJerky AI Co-Producer. Analyze this music idea and return ONLY JSON:\n'
        '{"genre":"Trap / R&B","bpm":92,"key":"C Minor","mood":"Dark · Melancholic"}\n'
        'Rules: bpm integer 60-180, key like "C Minor" or "G Major", '
        'genre short (use / if hybrid), mood two words joined by ·.\n'
        'Mode: ${input.mode.name}\n'
        'Idea: ${input.description}';

    if (GeminiConfig.isConfigured) {
      try {
        final text = await GeminiService().sendChat([
          GeminiChatMessage(isUser: true, text: prompt),
        ]);
        final parsed = _parseAnalysisJson(text);
        if (parsed != null) return parsed;
      } catch (error, stackTrace) {
        logDebugException(
          'StudioCoProducerService.analyzeText.gemini',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    if (OpenAiConfig.isConfigured) {
      final parsed = await _openAiJsonAnalysis(prompt);
      if (parsed != null) return parsed;
    }

    return StudioTrackAnalysis.fromInput(input);
  }

  static Future<StudioTrackAnalysis> _analyzeAudio(StudioTrackInput input) async {
    final path = input.audioPath!;
    final file = File(path);
    if (!await file.exists()) {
      return StudioTrackAnalysis.fromInput(input);
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return StudioTrackAnalysis.fromInput(input);
    }

    final mime = _mimeForPath(path);
    final b64 = base64Encode(bytes);
    final prompt =
        'You are BeatJerky AI Co-Producer listening to a ${input.mode.name} recording '
        '(${input.recordingDuration.inSeconds}s). Detect musical intent and return ONLY JSON:\n'
        '{"genre":"Trap / R&B","bpm":92,"key":"C Minor","mood":"Dark · Melancholic"}\n'
        'Rules: bpm integer 60-180, key like "C Minor", genre short, mood two words with ·.';

    if (GeminiConfig.isConfigured) {
      try {
        final text = await _geminiWithInlineAudio(
          prompt: prompt,
          mimeType: mime,
          base64Data: b64,
        );
        final parsed = _parseAnalysisJson(text);
        if (parsed != null) return parsed;
      } catch (error, stackTrace) {
        logDebugException(
          'StudioCoProducerService.analyzeAudio.gemini',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    // No multimodal OpenAI path here — fall back with recording context.
    final fallbackPrompt =
        '$prompt\nUser recorded a ${input.mode.name} idea for '
        '${input.recordingDuration.inSeconds} seconds. Infer a plausible analysis.';
    if (OpenAiConfig.isConfigured) {
      final parsed = await _openAiJsonAnalysis(fallbackPrompt);
      if (parsed != null) return parsed;
    }

    return StudioTrackAnalysis.fromInput(input);
  }

  static Future<String> _geminiWithInlineAudio({
    required String prompt,
    required String mimeType,
    required String base64Data,
  }) async {
    if (!GeminiConfig.isConfigured) {
      throw StateError(GeminiConfig.missingApiKeyMessage);
    }

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Data,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 512,
        'temperature': 0.4,
      },
    };

    Object? lastError;
    for (final auth in GeminiConfig.authAttempts) {
      for (final model in GeminiConfig.chatModelsToTry) {
        try {
          final response = await http
              .post(
                Uri.parse(
                  GeminiConfig.generateContentUrl(
                    model,
                    auth.apiKey,
                    auth.backend,
                  ),
                ),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 90));

          if (response.statusCode != 200) {
            lastError = 'Gemini ${response.statusCode}: ${response.body}';
            continue;
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List? ?? const [];
          if (candidates.isEmpty) continue;
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List? ?? const [];
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map && part['text'] is String) {
              buffer.write(part['text']);
            }
          }
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        } catch (e) {
          lastError = e;
        }
      }
    }

    throw StateError(lastError?.toString() ?? 'Gemini audio analysis failed.');
  }

  static Future<StudioTrackAnalysis?> _openAiJsonAnalysis(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(OpenAiConfig.chatCompletionsUrl),
            headers: OpenAiConfig.jsonAuthHeaders,
            body: jsonEncode({
              'model': OpenAiConfig.chatModel,
              'temperature': 0.5,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Return only JSON with keys genre, bpm, key, mood for BeatJerky Co-Producer.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content == null) return null;
      return _parseAnalysisJson(content);
    } catch (error, stackTrace) {
      logDebugException(
        'StudioCoProducerService.openAi',
        error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static StudioTrackAnalysis? _parseAnalysisJson(String raw) {
    try {
      var text = raw.trim();
      final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
      final match = fence.firstMatch(text);
      if (match != null) {
        text = match.group(1)!.trim();
      }
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        text = text.substring(start, end + 1);
      }

      final map = jsonDecode(text) as Map<String, dynamic>;
      final bpmRaw = map['bpm'];
      final bpm = bpmRaw is num
          ? bpmRaw.toInt()
          : int.tryParse(bpmRaw?.toString() ?? '') ?? 92;

      return StudioTrackAnalysis(
        genre: (map['genre'] ?? 'Trap / R&B').toString().trim(),
        bpm: bpm.clamp(60, 180),
        key: (map['key'] ?? 'C Minor').toString().trim(),
        mood: (map['mood'] ?? 'Dark · Melancholic').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mp4';
  }
}
