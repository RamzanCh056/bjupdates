import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAiConfig {
  static const String chatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';

  static const String imageGenerationsUrl =
      'https://api.openai.com/v1/images/generations';

  static const String missingApiKeyMessage =
      'OpenAI is not configured. Add OPENAI_API_KEY to assets/stripe/.env, then stop the app and run it again (hot reload does not reload .env files).';

  static const String invalidApiKeyMessage =
      'OpenAI rejected the API key. Check OPENAI_API_KEY in assets/stripe/.env and restart.';

  static bool get isConfigured => resolveApiKey().isNotEmpty;

  static String resolveApiKey() {
    final raw = dotenv.env['OPENAI_API_KEY'];
    if (raw == null) {
      return '';
    }

    return raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  }

  static String get chatModel {
    final raw = dotenv.env['OPENAI_MODEL'];
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return 'gpt-4o-mini';
  }

  static String get imageModel {
    final raw = dotenv.env['OPENAI_IMAGE_MODEL'];
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return 'dall-e-3';
  }

  static String get apiKey {
    final key = resolveApiKey();
    if (key.isEmpty) {
      throw StateError(missingApiKeyMessage);
    }
    return key;
  }

  static Map<String, String> get jsonAuthHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey}',
      };

  static Exception requestException(http.Response response) {
    if (response.statusCode == 401) {
      if (!isConfigured) {
        return Exception(missingApiKeyMessage);
      }
      return Exception(invalidApiKeyMessage);
    }

    return Exception(
      'OpenAI request failed (${response.statusCode}). ${response.body}',
    );
  }
}
