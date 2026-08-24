import 'dart:convert';

import 'package:beatjerky/config/suno_config.dart';
import 'package:beatjerky/utils/ai_beat_audio_trim.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:http/http.dart' as http;

class AiBeatAudioGenerationResult {
  final List<int> bytes;
  final String contentType;
  final String? sourceUrl;
  final int durationSeconds;

  const AiBeatAudioGenerationResult({
    required this.bytes,
    required this.contentType,
    required this.durationSeconds,
    this.sourceUrl,
  });
}

class AiBeatAudioGenerator {
  AiBeatAudioGenerator._();

  static const Duration _requestTimeout = Duration(minutes: 6);
  static const Duration _pollInterval = Duration(seconds: 8);
  static const String _callbackPlaceholder = 'https://beatjerky.app/api/suno-callback';
  static const int _maxAttempts = 2;

  static Future<AiBeatAudioGenerationResult> generate({
    required String prompt,
    required String title,
    required String style,
    required int durationSeconds,
    bool instrumental = true,
    double? weirdnessConstraint,
  }) async {
    if (!SunoConfig.isConfigured) {
      throw StateError(SunoConfig.missingApiKeyMessage);
    }

    final trimmedPrompt = prompt.trim();
    final trimmedTitle = _truncate(title.trim().isEmpty ? 'Beat Jerky Track' : title.trim(), 80);
    final trimmedStyle = _truncate(
      style.trim().isEmpty ? 'Instrumental hip hop beat' : style.trim(),
      1000,
    );

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Beat title cannot be empty.');
    }

    final targetDurationSeconds = durationSeconds.clamp(15, 180);
    Object? lastError;
    Object? lastStackTrace;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final useNonCustomMode = attempt > 0;
      try {
        final taskId = await _startGeneration(
          title: trimmedTitle,
          style: trimmedStyle,
          description: trimmedPrompt,
          durationSeconds: targetDurationSeconds,
          useNonCustomMode: useNonCustomMode,
          instrumental: instrumental,
          weirdnessConstraint: weirdnessConstraint,
        );
        final audioUrl = await _waitForAudioUrl(taskId);
        final downloaded = await _downloadAudio(audioUrl);
        final trimmed = await AiBeatAudioTrim.trimToMaxDuration(
          inputBytes: downloaded.bytes,
          maxDurationSeconds: targetDurationSeconds,
        );

        return AiBeatAudioGenerationResult(
          bytes: trimmed.bytes,
          contentType: downloaded.contentType,
          sourceUrl: downloaded.sourceUrl,
          durationSeconds: trimmed.durationSeconds,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        logDebugException(
          'AiBeatAudioGenerator.generate attempt ${attempt + 1}',
          error,
          stackTrace: stackTrace,
        );
        if (attempt < _maxAttempts - 1 &&
            _isRetryableSunoError(error) &&
            !_isTrimOnlyError(error)) {
          continue;
        }
        break;
      }
    }

    logDebugException(
      'AiBeatAudioGenerator.generate',
      lastError ?? Exception('Suno beat generation failed.'),
      stackTrace: lastStackTrace is StackTrace ? lastStackTrace : null,
    );
    throw _userFacingError(lastError);
  }

  static Future<String> _startGeneration({
    required String title,
    required String style,
    required String description,
    required int durationSeconds,
    required bool useNonCustomMode,
    required bool instrumental,
    double? weirdnessConstraint,
  }) async {
    final musicalDescription = _buildMusicalDescription(
      style: style,
      description: description,
    );

    final Map<String, dynamic> body = {
      'instrumental': instrumental,
      'model': useNonCustomMode ? 'V4_5' : 'V4_5ALL',
      'callBackUrl': _callbackPlaceholder,
    };

    if (weirdnessConstraint != null) {
      body['weirdnessConstraint'] =
          weirdnessConstraint.clamp(0.0, 1.0).toStringAsFixed(2);
    }

    if (useNonCustomMode) {
      body['customMode'] = false;
      body['prompt'] = _truncate(
        instrumental
            ? 'Instrumental cinematic score. $musicalDescription'
            : musicalDescription,
        500,
      );
    } else if (instrumental) {
      // Instrumental custom mode: style + title only (prompt is for lyrics).
      body['customMode'] = true;
      body['title'] = title;
      body['style'] = _truncate(
        'Instrumental, no vocals. $musicalDescription',
        1000,
      );
    } else {
      // Vocal custom mode: description is lyrics; style is genre/mood only.
      body['customMode'] = true;
      body['title'] = title;
      body['style'] = _truncate(style, 1000);
      body['prompt'] = _truncate(description, 5000);
    }

    final response = await http
        .post(
          Uri.parse(SunoConfig.generateUrl),
          headers: SunoConfig.jsonAuthHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    final decoded = _decodeResponse(response);
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Suno did not return a task id.');
    }

    final taskId = data['taskId'] as String?;
    if (taskId == null || taskId.trim().isEmpty) {
      throw Exception('Suno returned an invalid task id.');
    }

    return taskId.trim();
  }

  static String _buildMusicalDescription({
    required String style,
    required String description,
  }) {
    final parts = <String>[];
    if (style.isNotEmpty) {
      parts.add(style);
    }
    if (description.isNotEmpty && description != style) {
      parts.add(description);
    }
    return parts.join('. ').trim();
  }

  static Future<String> _waitForAudioUrl(String taskId) async {
    final deadline = DateTime.now().add(_requestTimeout);
    var successWithoutUrlCount = 0;

    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Suno beat generation timed out. Try again in a moment.');
      }

      final response = await http
          .get(
            Uri.parse('${SunoConfig.recordInfoUrl}?taskId=$taskId'),
            headers: {'Authorization': 'Bearer ${SunoConfig.apiKey}'},
          )
          .timeout(const Duration(seconds: 30));

      final decoded = _decodeResponse(response);
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        await Future.delayed(_pollInterval);
        continue;
      }

      final status = (data['status'] as String?)?.toUpperCase();
      if (status == 'SUCCESS' ||
          status == 'FIRST_SUCCESS' ||
          status == 'TEXT_SUCCESS') {
        final audioUrl = _extractAudioUrl(data);
        if (audioUrl != null) {
          return audioUrl;
        }
        if (status == 'SUCCESS' || status == 'FIRST_SUCCESS') {
          successWithoutUrlCount++;
          if (successWithoutUrlCount >= 8) {
            throw Exception(
              'Suno finished generating but no audio URL was returned. Please try again.',
            );
          }
        }
      }

      if (status != null && _isFailureStatus(status)) {
        final errorMessage = data['errorMessage'] as String?;
        throw Exception(
          errorMessage?.trim().isNotEmpty == true
              ? errorMessage!.trim()
              : 'Suno beat generation failed ($status).',
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

  static bool _isTrimOnlyError(Object error) {
    return error.toString().toLowerCase().contains('trim beat audio');
  }

  static bool _isRetryableSunoError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('internal error') ||
        message.contains('try again') ||
        message.contains('generate_audio_failed') ||
        message.contains('callback_exception') ||
        message.contains('timed out') ||
        message.contains('too high') ||
        message.contains('rate limit') ||
        message.contains('maintenance');
  }

  static Exception _userFacingError(Object? error) {
    if (error == null) {
      return Exception('Suno beat generation failed. Please try again.');
    }
    if (error is StateError) {
      return Exception(error.message);
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final lower = raw.toLowerCase();
    if (lower.contains('trim beat audio')) {
      return Exception(
        'Beat was created but could not be shortened on this device. Try again or pick a longer length.',
      );
    }
    if (lower.contains('internal error') || lower.contains('try again later')) {
      return Exception(
        'Suno could not finish this beat right now. Wait a moment and tap Generate again.',
      );
    }
    if (lower.contains('sensitive') || lower.contains('prohibited')) {
      return Exception(
        'Suno rejected the beat description. Try simpler words without names or explicit content.',
      );
    }
    if (lower.contains('insufficient credits') || lower.contains('429')) {
      return Exception(
        'Suno API credits are low. Add credits at sunoapi.org and try again.',
      );
    }
    return Exception(raw);
  }

  static String? _extractAudioUrl(Map<String, dynamic> data) {
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
      final url = _firstDownloadableUrl(track) ?? _firstStreamUrl(track);
      if (url != null) {
        return url;
      }
    }

    return null;
  }

  static String? _firstDownloadableUrl(Map<String, dynamic> track) {
    final candidates = [
      track['audioUrl'],
      track['audio_url'],
      track['source_audio_url'],
      track['sourceAudioUrl'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static String? _firstStreamUrl(Map<String, dynamic> track) {
    final candidates = [
      track['streamAudioUrl'],
      track['stream_audio_url'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
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

  static Future<AiBeatAudioGenerationResult> _downloadAudio(
    String outputUrl,
  ) async {
    final response = await http
        .get(Uri.parse(outputUrl))
        .timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw Exception(
        'Could not download generated beat audio (${response.statusCode}).',
      );
    }

    final contentType = response.headers['content-type']?.split(';').first ??
        'audio/mpeg';

    return AiBeatAudioGenerationResult(
      bytes: response.bodyBytes,
      contentType: contentType,
      sourceUrl: outputUrl,
      durationSeconds: 0,
    );
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}
