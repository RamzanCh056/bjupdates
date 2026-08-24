import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AiBackend { googleAi, vertexExpress }

class GeminiConfig {
  static const String missingApiKeyMessage =
      'AI API key missing. Add GEMINI_API_KEY to .env and fully restart the app.';

  static const String chatSystemPrompt =
      'You are BJ AI, a creative music assistant. Help artists with songwriting, '
      'music production tips, lyrics, beat ideas, artist branding, and music industry '
      'advice. Keep responses concise and creative.';

  static const _defaultChatModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  static const _defaultImageModels = [
    'gemini-2.5-flash-image-preview',
    'gemini-2.0-flash-preview-image-generation',
  ];

  static bool get isConfigured =>
      _resolve('GEMINI_API_KEY').isNotEmpty ||
      _resolve('GOOGLE_API_KEY').isNotEmpty;

  static String _resolve(String key, {String fallback = ''}) {
    final raw = dotenv.env[key];
    if (raw == null || raw.trim().isEmpty) return fallback;
    return raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  }

  static List<String> _parsePriority(String key, List<String> defaults) {
    final raw = _resolve(key);
    if (raw.isEmpty) return defaults;
    final parsed = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.startsWith('gemini'))
        .toList();
    return parsed.isEmpty ? defaults : parsed;
  }

  static String get geminiApiKey => _resolve('GEMINI_API_KEY');
  static String get googleApiKey => _resolve('GOOGLE_API_KEY');

  static String get aiProvider =>
      _resolve('AI_PROVIDER', fallback: 'gemini').toLowerCase();

  static String get vertexRegion =>
      _resolve('VERTEX_REGION', fallback: 'us-central1');

  static String get gcpProjectId => _resolve('GCP_PROJECT_ID');

  static String get chatModel {
    final fromEnv = _resolve('GEMINI_MODEL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _resolve('VERTEX_GEMINI_MODEL', fallback: _defaultChatModels.first);
  }

  static String get imageModel {
    final fromEnv = _resolve('GEMINI_IMAGE_MODEL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _resolve('VERTEX_IMAGEN_MODEL', fallback: _defaultImageModels.first);
  }

  static List<String> get chatModelsToTry {
    final priority = _parsePriority('VERTEX_GEMINI_PRIORITY', _defaultChatModels);
    final preferred = chatModel;
    return [preferred, ...priority.where((m) => m != preferred)];
  }

  static List<String> get imageModelsToTry {
    final priority =
        _parsePriority('VERTEX_IMAGEN_PRIORITY', _defaultImageModels);
    final preferred = imageModel;
    return [preferred, ...priority.where((m) => m != preferred)];
  }

  /// GOOGLE key first (enable API once in console), then GEMINI key.
  static List<({String apiKey, AiBackend backend, String label})>
      get authAttempts {
    final attempts = <({String apiKey, AiBackend backend, String label})>[];
    final gemini = geminiApiKey;
    final google = googleApiKey;

    void add(String key, String label) {
      if (key.isEmpty) return;
      attempts.add((apiKey: key, backend: AiBackend.googleAi, label: label));
      attempts.add((apiKey: key, backend: AiBackend.vertexExpress, label: label));
    }

    if (google.isNotEmpty) add(google, 'GOOGLE');
    if (gemini.isNotEmpty && gemini != google) add(gemini, 'GEMINI');

    return attempts;
  }

  static String generateContentUrl(
    String model,
    String apiKey,
    AiBackend backend,
  ) {
    switch (backend) {
      case AiBackend.googleAi:
        return 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
      case AiBackend.vertexExpress:
        return 'https://aiplatform.googleapis.com/v1/publishers/google/models/$model:generateContent?key=$apiKey';
    }
  }
}
