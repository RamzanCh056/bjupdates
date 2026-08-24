import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:beatjerky/config/gemini_config.dart';
import 'package:http/http.dart' as http;

class GeminiChatMessage {
  final bool isUser;
  final String text;

  const GeminiChatMessage({required this.isUser, required this.text});

  Map<String, dynamic> toContentJson() => {
        'role': isUser ? 'user' : 'model',
        'parts': [
          {'text': text},
        ],
      };
}

class GeminiImageResult {
  final Uint8List bytes;
  final String mimeType;

  const GeminiImageResult({required this.bytes, required this.mimeType});
}

class _AttemptErrors {
  bool geminiKeyLeaked = false;
  bool googleApiDisabled = false;
  String? lastRaw;
}

class GeminiService {
  Future<String> sendChat(List<GeminiChatMessage> history) async {
    if (!GeminiConfig.isConfigured) {
      throw GeminiException(GeminiConfig.missingApiKeyMessage);
    }
    if (history.isEmpty) {
      throw GeminiException('No message to send.');
    }

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': GeminiConfig.chatSystemPrompt},
        ],
      },
      'contents': history.map((m) => m.toContentJson()).toList(),
      'generationConfig': {
        'maxOutputTokens': 1024,
        'temperature': 0.8,
      },
    };

    final errors = _AttemptErrors();
    for (final auth in GeminiConfig.authAttempts) {
      for (final model in GeminiConfig.chatModelsToTry) {
        try {
          final response = await http
              .post(
                Uri.parse(GeminiConfig.generateContentUrl(
                  model,
                  auth.apiKey,
                  auth.backend,
                )),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 60));

          log(
            'BJ AI chat key=${auth.label} backend=${auth.backend.name} '
            'model=$model status=${response.statusCode}',
          );

          if (response.statusCode != 200) {
            final message = _parseError(response);
            errors.lastRaw = message;
            _classifyError(message, auth.label, errors);
            if (_shouldRetry(message)) continue;
            throw GeminiException(_friendlyError(message, errors));
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractText(data);
          if (text == null || text.trim().isEmpty) {
            errors.lastRaw = 'Empty response';
            continue;
          }
          return text.trim();
        } on GeminiException {
          rethrow;
        } catch (e) {
          errors.lastRaw = e.toString();
          log('BJ AI chat error: $e');
        }
      }
    }

    throw GeminiException(_friendlyError(errors.lastRaw, errors));
  }

  Future<GeminiImageResult> generateImage({
    required String prompt,
    String? style,
  }) async {
    if (!GeminiConfig.isConfigured) {
      throw GeminiException(GeminiConfig.missingApiKeyMessage);
    }

    final styleSuffix = (style != null && style.isNotEmpty)
        ? '. Style: $style. High quality, professional music artwork.'
        : '. High quality, professional music artwork.';

    final fullPrompt =
        'Professional music album cover art, square format, high quality: '
        '$prompt$styleSuffix';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': fullPrompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
      },
    };

    final errors = _AttemptErrors();
    for (final auth in GeminiConfig.authAttempts) {
      for (final model in GeminiConfig.imageModelsToTry) {
        try {
          final response = await http
              .post(
                Uri.parse(GeminiConfig.generateContentUrl(
                  model,
                  auth.apiKey,
                  auth.backend,
                )),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 90));

          if (response.statusCode != 200) {
            final message = _parseError(response);
            errors.lastRaw = message;
            _classifyError(message, auth.label, errors);
            if (_shouldRetry(message)) continue;
            throw GeminiException(_friendlyError(message, errors));
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final image = _extractImage(data);
          if (image == null) {
            errors.lastRaw = 'No image in response';
            continue;
          }
          return image;
        } on GeminiException {
          rethrow;
        } catch (e) {
          errors.lastRaw = e.toString();
        }
      }
    }

    throw GeminiException(_friendlyError(errors.lastRaw, errors));
  }

  void _classifyError(String message, String keyLabel, _AttemptErrors errors) {
    final lower = message.toLowerCase();
    if (keyLabel == 'GEMINI' && lower.contains('leaked')) {
      errors.geminiKeyLeaked = true;
    }
    if (keyLabel == 'GOOGLE' &&
        (lower.contains('service_disabled') ||
            lower.contains('has not been used'))) {
      errors.googleApiDisabled = true;
    }
  }

  bool _shouldRetry(String message) {
    final lower = message.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('does not exist') ||
        lower.contains('leaked') ||
        lower.contains('permission_denied') ||
        lower.contains('unauthenticated') ||
        lower.contains('api keys are not supported') ||
        lower.contains('service_disabled') ||
        lower.contains('invalid api key') ||
        lower.contains('not enabled') ||
        lower.contains('not been used');
  }

  String _friendlyError(String? raw, _AttemptErrors errors) {
    if (errors.geminiKeyLeaked && errors.googleApiDisabled) {
      return 'Your GEMINI_API_KEY is disabled by Google (it was shared publicly).\n\n'
          'Quick fix: open this link on your phone/computer, tap Enable, wait 2 min, restart app:\n'
          'console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=allmyne-7b923\n\n'
          'Or create a new key at aistudio.google.com and update GEMINI_API_KEY in .env';
    }
    if (errors.geminiKeyLeaked) {
      return 'Google disabled your GEMINI_API_KEY (shared publicly). '
          'Create a new key at aistudio.google.com, update .env, restart app.';
    }
    if (errors.googleApiDisabled) {
      return 'Enable Gemini API for your project (1 tap), then restart:\n'
          'console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=allmyne-7b923';
    }

    final lower = (raw ?? '').toLowerCase();
    if (lower.contains('leaked')) {
      return 'Google disabled this API key. Create a new one at aistudio.google.com.';
    }
    if (raw != null && raw.length > 220) return '${raw.substring(0, 217)}...';
    return raw ?? 'Could not connect to AI. Check your internet and restart.';
  }

  String? _extractText(Map<String, dynamic> data) {
    final promptFeedback = data['promptFeedback'] as Map?;
    final blockReason = promptFeedback?['blockReason'];
    if (blockReason != null) {
      throw GeminiException('Request blocked: $blockReason');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final candidate = candidates.first as Map;
    if (candidate['finishReason'] == 'SAFETY') {
      throw GeminiException('Response blocked by safety filters. Try rephrasing.');
    }

    final content = candidate['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return null;

    final buffer = StringBuffer();
    for (final part in parts) {
      final text = (part as Map)['text'] as String?;
      if (text != null && text.isNotEmpty) buffer.write(text);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  GeminiImageResult? _extractImage(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return null;

    for (final part in parts) {
      final inline = (part as Map)['inlineData'] as Map?;
      if (inline == null) continue;
      final b64 = inline['data'] as String?;
      final mime = inline['mimeType'] as String? ?? 'image/png';
      if (b64 == null || b64.isEmpty) continue;
      return GeminiImageResult(bytes: base64Decode(b64), mimeType: mime);
    }
    return null;
  }

  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map?;
      final message = error?['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}
