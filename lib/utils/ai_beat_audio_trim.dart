import 'dart:io';

import 'package:beatjerky/utils/debug_log.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AiBeatAudioTrimResult {
  final List<int> bytes;
  final int durationSeconds;
  final bool wasTrimmed;

  const AiBeatAudioTrimResult({
    required this.bytes,
    required this.durationSeconds,
    this.wasTrimmed = false,
  });
}

class AiBeatAudioTrim {
  AiBeatAudioTrim._();

  static Future<AiBeatAudioTrimResult> trimToMaxDuration({
    required List<int> inputBytes,
    required int maxDurationSeconds,
  }) async {
    if (maxDurationSeconds <= 0 || inputBytes.isEmpty) {
      return AiBeatAudioTrimResult(
        bytes: inputBytes,
        durationSeconds: maxDurationSeconds,
      );
    }

    File? inputFile;
    File? outputFile;
    try {
      final extension = _detectAudioExtension(inputBytes);
      final tempDir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      inputFile = File('${tempDir.path}/beat_in_$stamp.$extension');
      outputFile = File('${tempDir.path}/beat_out_$stamp.$extension');

      await inputFile.writeAsBytes(inputBytes, flush: true);

      final inputDuration = await _probeDurationSeconds(inputFile.path);
      if (inputDuration != null && inputDuration <= maxDurationSeconds) {
        return AiBeatAudioTrimResult(
          bytes: inputBytes,
          durationSeconds: inputDuration,
        );
      }

      final trimmedPath = await _runTrimStrategies(
        inputPath: inputFile.path,
        outputPath: outputFile.path,
        maxDurationSeconds: maxDurationSeconds,
      );

      if (trimmedPath != null) {
        final trimmedBytes = await File(trimmedPath).readAsBytes();
        final outputDuration =
            await _probeDurationSeconds(trimmedPath) ?? maxDurationSeconds;

        return AiBeatAudioTrimResult(
          bytes: trimmedBytes,
          durationSeconds: outputDuration.clamp(1, maxDurationSeconds),
          wasTrimmed: true,
        );
      }

      // FFmpeg trim unavailable — keep full file; playback/UI cap selected length.
      logDebugException(
        'AiBeatAudioTrim.trimToMaxDuration fallback',
        Exception(
          'FFmpeg trim failed; using full audio with ${maxDurationSeconds}s playback cap.',
        ),
      );

      final fallbackDuration = inputDuration ?? maxDurationSeconds;
      return AiBeatAudioTrimResult(
        bytes: inputBytes,
        durationSeconds: maxDurationSeconds.clamp(1, fallbackDuration),
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatAudioTrim.trimToMaxDuration',
        error,
        stackTrace: stackTrace,
      );

      return AiBeatAudioTrimResult(
        bytes: inputBytes,
        durationSeconds: maxDurationSeconds,
      );
    } finally {
      if (inputFile != null && await inputFile.exists()) {
        await inputFile.delete();
      }
      if (outputFile != null && await outputFile.exists()) {
        await outputFile.delete();
      }
    }
  }

  /// Tries stream-copy trim first (works with ffmpeg_kit min — no libmp3lame).
  static Future<String?> _runTrimStrategies({
    required String inputPath,
    required String outputPath,
    required int maxDurationSeconds,
  }) async {
    final strategies = <List<String>>[
      [
        '-y',
        '-i',
        inputPath,
        '-t',
        '$maxDurationSeconds',
        '-c',
        'copy',
        outputPath,
      ],
      [
        '-y',
        '-ss',
        '0',
        '-i',
        inputPath,
        '-t',
        '$maxDurationSeconds',
        '-vn',
        '-acodec',
        'copy',
        outputPath,
      ],
      [
        '-y',
        '-i',
        inputPath,
        '-t',
        '$maxDurationSeconds',
        outputPath,
      ],
    ];

    for (final args in strategies) {
      final output = await _executeFfmpeg(args);
      if (output != null) {
        return output;
      }
      final outFile = File(outputPath);
      if (await outFile.exists()) {
        await outFile.delete();
      }
    }

    return null;
  }

  static Future<String?> _executeFfmpeg(List<String> args) async {
    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        logDebugException(
          'AiBeatAudioTrim._executeFfmpeg',
          Exception('FFmpeg failed (${returnCode?.getValue()}): $logs'),
        );
        return null;
      }

      final outputPath = args.last;
      final outFile = File(outputPath);
      if (!await outFile.exists()) {
        return null;
      }

      final size = await outFile.length();
      if (size < 1024) {
        return null;
      }

      return outputPath;
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatAudioTrim._executeFfmpeg',
        error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static String _detectAudioExtension(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return 'mp3';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return 'mp3';
    }
    if (bytes.length >= 8) {
      final signature = String.fromCharCodes(bytes.sublist(4, 8));
      if (signature == 'ftyp') {
        return 'm4a';
      }
    }
    if (bytes.length >= 4) {
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      if (riff == 'RIFF') {
        return 'wav';
      }
    }
    return 'mp3';
  }

  static Future<int?> _probeDurationSeconds(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      final duration = info?.getDuration();
      if (duration == null) {
        return null;
      }
      final seconds = double.tryParse(duration);
      if (seconds == null) {
        return null;
      }
      return seconds.ceil().clamp(1, 600);
    } catch (_) {
      return null;
    }
  }
}
