import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'reel_video_spec.dart';

/// Extracts audio from [videoPath] to AAC in an M4A container at [outPath].
/// Returns whether FFmpeg reported success (exit code 0).
Future<bool> extractReelVideoAudioToM4a({
  required String videoPath,
  required String outPath,
}) async {
  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-i',
    videoPath,
    '-vn',
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    outPath,
  ]);
  final rc = await session.getReturnCode();
  return rc != null && rc.getValue() == 0;
}

/// H.264 encoder compatible with [ffmpeg_kit_flutter_new_min] (no bundled libx264).
List<String> _h264VideoEncodeArgsK(int brK) {
  if (Platform.isIOS) {
    return [
      '-c:v',
      'h264_videotoolbox',
      '-b:v',
      '${brK}k',
      '-pix_fmt',
      'yuv420p',
    ];
  }
  if (Platform.isAndroid) {
    return [
      '-c:v',
      'h264_mediacodec',
      '-b:v',
      '${brK}k',
    ];
  }
  return [
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-b:v',
    '${brK}k',
    '-maxrate',
    '${brK}k',
    '-bufsize',
    '${brK * 2}k',
  ];
}

/// Re-encodes [inputPath] to reel spec (1080×1920, target bitrate), optionally trimming.
/// Uses hardware encoders on iOS/Android. [onProgress] is 0.0–1.0 when duration is known.
Future<File?> compressReelVideoForPreview({
  required String inputPath,
  required void Function(double progress) onProgress,
  double trimStartMs = 0,
  double? trimEndMs,
  double? totalDurationMs,
}) async {
  final input = File(inputPath);
  if (!await input.exists()) return null;

  final outDir = await getTemporaryDirectory();
  final outPath =
      '${outDir.path}/reel_compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

  final w = ReelVideoSpec.exportWidth;
  final h = ReelVideoSpec.exportHeight;
  final brK = (ReelVideoSpec.exportBitrate / 1000).round();

  final vf =
      'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2';

  final endMs = trimEndMs ?? 0.0;
  final hasTrim = endMs > trimStartMs + 32;
  final totalMs = totalDurationMs ?? 0.0;
  final spanMs = hasTrim ? (endMs - trimStartMs) : (totalMs > 0 ? totalMs : 0.0);

  final args = <String>[
    '-y',
    if (trimStartMs > 32) ...['-ss', '${trimStartMs / 1000.0}'],
    '-i',
    inputPath,
    if (hasTrim) ...['-t', '${(endMs - trimStartMs) / 1000.0}'],
    '-vf',
    vf,
    ..._h264VideoEncodeArgsK(brK),
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-movflags',
    '+faststart',
    outPath,
  ];

  final completer = Completer<bool>();

  await FFmpegKit.executeWithArgumentsAsync(
    args,
    (session) async {
      final rc = await session.getReturnCode();
      final ok = ReturnCode.isSuccess(rc);
      if (!completer.isCompleted) completer.complete(ok);
    },
    null,
    (stats) {
      if (spanMs <= 0) {
        onProgress(0.5);
        return;
      }
      final t = stats.getTime();
      final p = (t / spanMs).clamp(0.0, 1.0);
      onProgress(p);
    },
  );

  final ok = await completer.future;
  onProgress(1.0);
  if (!ok) return null;
  final out = File(outPath);
  if (!await out.exists()) return null;
  return out;
}
