import 'dart:convert';

import 'package:beatjerky/config/suno_config.dart';
import 'package:http/http.dart' as http;

class SunoFileUploadService {
  SunoFileUploadService._();

  static const int maxRecommendedBytes = 12 * 1024 * 1024;

  static Future<String> uploadAudioBytes({
    required List<int> bytes,
    required String fileName,
    String mimeType = 'audio/mpeg',
  }) async {
    if (!SunoConfig.isConfigured) {
      throw StateError(SunoConfig.missingApiKeyMessage);
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Audio file is empty.');
    }
    if (bytes.length > maxRecommendedBytes) {
      throw ArgumentError(
        'Audio file is too large. Please use a vocal under 12 MB.',
      );
    }

    final safeName = _sanitizeFileName(fileName);
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final response = await http
        .post(
          Uri.parse(SunoConfig.fileBase64UploadUrl),
          headers: SunoConfig.jsonAuthHeaders,
          body: jsonEncode({
            'base64Data': dataUrl,
            'uploadPath': 'audio/vocals',
            'fileName': safeName,
          }),
        )
        .timeout(const Duration(minutes: 2));

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Suno file upload failed (${response.statusCode}). ${response.body}',
      );
    }

    final success = decoded['success'] == true;
    final code = decoded['code'];
    if (response.statusCode != 200 ||
        (!success && code is int && code != 200)) {
      final message = decoded['msg'] as String? ?? response.body;
      throw Exception('Suno file upload failed: $message');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Suno file upload did not return a download URL.');
    }

    final downloadUrl = data['downloadUrl'] as String?;
    if (downloadUrl == null || downloadUrl.trim().isEmpty) {
      throw Exception('Suno file upload returned an invalid download URL.');
    }

    return downloadUrl.trim();
  }

  static String mimeTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.aac')) {
      return 'audio/aac';
    }
    return 'audio/mpeg';
  }

  static String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'vocal_upload.mp3';
    }
    return trimmed.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  }
}
