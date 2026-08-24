import 'package:flutter_dotenv/flutter_dotenv.dart';

class SunoConfig {
  static const String baseUrl = 'https://api.sunoapi.org';
  static const String fileUploadBaseUrl = 'https://sunoapiorg.redpandaai.co';
  static const String generateUrl = '$baseUrl/api/v1/generate';
  static const String uploadCoverUrl = '$baseUrl/api/v1/generate/upload-cover';
  static const String recordInfoUrl = '$baseUrl/api/v1/generate/record-info';
  static const String fileBase64UploadUrl =
      '$fileUploadBaseUrl/api/file-base64-upload';

  static const String missingApiKeyMessage =
      'Suno is not configured. Add SUNO_API_KEY to assets/stripe/.env, then fully restart the app.';

  static bool get isConfigured => resolveApiKey().isNotEmpty;

  static String resolveApiKey() {
    final raw = dotenv.env['SUNO_API_KEY'];
    if (raw == null) {
      return '';
    }
    return raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
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
        'Authorization': 'Bearer $apiKey',
      };
}
