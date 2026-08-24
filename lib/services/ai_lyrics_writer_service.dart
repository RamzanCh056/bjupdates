import 'dart:convert';
import 'dart:developer';

import 'package:beatjerky/config/openai_config.dart';
import 'package:http/http.dart' as http;

class AiLyricsWriterRequest {
  final String description;
  final String genre;
  final String mood;
  final String structure;
  final String language;
  final double creativity;

  const AiLyricsWriterRequest({
    required this.description,
    required this.genre,
    required this.mood,
    required this.structure,
    required this.language,
    required this.creativity,
  });
}

class AiLyricsWriterService {
  AiLyricsWriterService._();

  static Future<String> generate(AiLyricsWriterRequest request) async {
    if (!OpenAiConfig.isConfigured) {
      throw AiLyricsWriterException(OpenAiConfig.missingApiKeyMessage);
    }

    final description = request.description.trim();
    if (description.isEmpty) {
      throw AiLyricsWriterException('Describe your song before generating.');
    }

    final temperature = (0.3 + request.creativity * 0.9).clamp(0.3, 1.2);

    try {
      final response = await http
          .post(
            Uri.parse(OpenAiConfig.chatCompletionsUrl),
            headers: OpenAiConfig.jsonAuthHeaders,
            body: jsonEncode({
              'model': OpenAiConfig.chatModel,
              'temperature': temperature,
              'max_tokens': 1800,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a professional songwriter for BeatJerky. '
                      'Write original song lyrics only — no commentary before or after. '
                      'Use clear section headers in square brackets like [Verse 1], [Chorus], [Bridge]. '
                      'Match the requested genre, mood, language, and song structure. '
                      'Keep lines singable with strong rhythm and rhyme where appropriate.',
                },
                {
                  'role': 'user',
                  'content':
                      'Write complete song lyrics.\n'
                      'Description: $description\n'
                      'Genre: ${request.genre}\n'
                      'Mood: ${request.mood}\n'
                      'Structure: ${request.structure}\n'
                      'Language: ${request.language}',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 75));

      log('AiLyricsWriter status=${response.statusCode}');

      if (response.statusCode != 200) {
        throw AiLyricsWriterException(_parseError(response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw AiLyricsWriterException(
          'Empty response from AI. Please try again.',
        );
      }
      return content.trim();
    } on AiLyricsWriterException {
      rethrow;
    } catch (error) {
      log('AiLyricsWriter error: $error');
      throw AiLyricsWriterException('Something went wrong, try again.');
    }
  }

  static String _parseError(http.Response response) {
    if (response.statusCode == 401) {
      return OpenAiConfig.isConfigured
          ? OpenAiConfig.invalidApiKeyMessage
          : OpenAiConfig.missingApiKeyMessage;
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (data['error'] as Map?)?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        if (message.length > 200) return '${message.substring(0, 197)}...';
        return message;
      }
    } catch (_) {}
    return 'Lyrics generation failed (${response.statusCode}).';
  }

  static String errorMessage(Object error) {
    if (error is AiLyricsWriterException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class AiLyricsWriterException implements Exception {
  final String message;
  AiLyricsWriterException(this.message);

  @override
  String toString() => message;
}
