import 'dart:convert';

import 'package:beatjerky/config/suno_config.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;

class SunoDownloadedAudio {
  final List<int> bytes;
  final String contentType;

  const SunoDownloadedAudio({
    required this.bytes,
    required this.contentType,
  });
}

class SunoTaskClient {
  SunoTaskClient._();

  static const Duration _requestTimeout = Duration(minutes: 6);
  static const Duration _pollInterval = Duration(seconds: 8);

  static Future<String> waitForMusicTaskAudioUrl(String taskId) async {
    final deadline = DateTime.now().add(_requestTimeout);
    var successWithoutUrlCount = 0;

    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Suno processing timed out. Try again in a moment.');
      }

      final response = await http
          .get(
            Uri.parse('${SunoConfig.recordInfoUrl}?taskId=$taskId'),
            headers: {'Authorization': 'Bearer ${SunoConfig.apiKey}'},
          )
          .timeout(const Duration(seconds: 30));

      final decoded = decodeSunoApiResponse(response);
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        await Future.delayed(_pollInterval);
        continue;
      }

      final status = (data['status'] as String?)?.toUpperCase();
      if (status == 'SUCCESS' ||
          status == 'FIRST_SUCCESS' ||
          status == 'TEXT_SUCCESS') {
        final audioUrl = extractAudioUrl(data);
        if (audioUrl != null) {
          return audioUrl;
        }
        if (status == 'SUCCESS' || status == 'FIRST_SUCCESS') {
          successWithoutUrlCount++;
          if (successWithoutUrlCount >= 8) {
            throw Exception(
              'Suno finished but no audio URL was returned. Please try again.',
            );
          }
        }
      }

      if (status != null && _isFailureStatus(status)) {
        final errorMessage = data['errorMessage'] as String?;
        throw Exception(
          errorMessage?.trim().isNotEmpty == true
              ? errorMessage!.trim()
              : 'Suno processing failed ($status).',
        );
      }

      await Future.delayed(_pollInterval);
    }
  }

  static bool _isFailureStatus(String status) {
    return status == 'CREATE_TASK_FAILED' ||
        status == 'GENERATE_AUDIO_FAILED' ||
        status == 'CALLBACK_EXCEPTION' ||
        status == 'SENSITIVE_WORD_ERROR';
  }

  static String? extractAudioUrl(Map<String, dynamic> data) {
    final response = data['response'];
    if (response is! Map<String, dynamic>) {
      return null;
    }

    final sunoData = response['sunoData'] ?? response['suno_data'];
    if (sunoData is! List || sunoData.isEmpty) {
      return null;
    }

    for (final track in sunoData) {
      if (track is! Map<String, dynamic>) {
        continue;
      }
      final url = _firstUrl(track, [
        'audioUrl',
        'audio_url',
        'source_audio_url',
        'sourceAudioUrl',
        'streamAudioUrl',
        'stream_audio_url',
      ]);
      if (url != null) {
        return url;
      }
    }
    return null;
  }

  static String? _firstUrl(
    Map<String, dynamic> track,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = track[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static Map<String, dynamic> decodeSunoApiResponse(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Suno request failed (${response.statusCode}). ${response.body}',
      );
    }

    final code = decoded['code'];
    if (response.statusCode != 200 || (code is int && code != 200)) {
      final message = decoded['msg'] as String? ?? response.body;
      if (response.statusCode == 401 || code == 401) {
        throw Exception(
          'Suno rejected the API key. Check SUNO_API_KEY in assets/stripe/.env.',
        );
      }
      if (code == 429) {
        throw Exception('Suno API credits are insufficient. Add credits and try again.');
      }
      if (code == 430 || code == 405) {
        throw Exception('Suno rate limit reached. Wait a few seconds and try again.');
      }
      throw Exception('Suno request failed: $message');
    }

    return decoded;
  }

  static Future<SunoDownloadedAudio> downloadAudio(String outputUrl) async {
    final response = await http
        .get(Uri.parse(outputUrl))
        .timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw Exception(
        'Could not download audio (${response.statusCode}).',
      );
    }

    return SunoDownloadedAudio(
      bytes: response.bodyBytes,
      contentType: response.headers['content-type']?.split(';').first ??
          'audio/mpeg',
    );
  }

  static void logFailure(String label, Object error, [StackTrace? stackTrace]) {
    logDebugException(label, error, stackTrace: stackTrace);
  }
}
