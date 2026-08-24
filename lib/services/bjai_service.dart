import 'dart:convert';
import 'dart:developer';

import 'package:beatjerky/config/openai_config.dart';
import 'package:http/http.dart' as http;

class BjaiChatMessage {
  final bool isUser;
  final String text;

  const BjaiChatMessage({required this.isUser, required this.text});
}

class BjaiService {
  static const _systemPrompt =
      'You are BJ AI, a creative music assistant for BeatJerky. '
      'Help artists with songwriting, music production tips, lyrics, beat ideas, '
      'artist branding, and music industry advice. Keep responses concise and creative.';

  Future<String> sendChat(List<BjaiChatMessage> history) async {
    if (!OpenAiConfig.isConfigured) {
      throw BjaiException(OpenAiConfig.missingApiKeyMessage);
    }
    if (history.isEmpty) {
      throw BjaiException('No message to send.');
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      for (final m in history)
        {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        },
    ];

    try {
      final response = await http
          .post(
            Uri.parse(OpenAiConfig.chatCompletionsUrl),
            headers: OpenAiConfig.jsonAuthHeaders,
            body: jsonEncode({
              'model': OpenAiConfig.chatModel,
              'temperature': 0.8,
              'max_tokens': 1024,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 60));

      log('BJ AI chat status=${response.statusCode}');

      if (response.statusCode != 200) {
        throw BjaiException(_parseError(response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw BjaiException('Empty response from AI. Please try again.');
      }
      return content.trim();
    } catch (e) {
      if (e is BjaiException) rethrow;
      log('BJ AI chat error: $e');
      throw BjaiException('Something went wrong, try again.');
    }
  }

  String _parseError(http.Response response) {
    if (response.statusCode == 401) {
      return OpenAiConfig.invalidApiKeyMessage;
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map?;
      final message = error?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        if (message.length > 200) return '${message.substring(0, 197)}...';
        return message;
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}

class BjaiException implements Exception {
  final String message;
  BjaiException(this.message);

  @override
  String toString() => message;
}
