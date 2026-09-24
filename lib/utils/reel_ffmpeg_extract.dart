import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'reel_video_spec.dart';

// Diagnostic tag — filter logcat with:  adb logcat | grep REELFF
const String _kTag = '[REELFF]';

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
      // MediaCodec's H.264 encoder is unreliable with B-frames on many devices.
      '-bf',
      '0',
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

/// Rounds [v] up to the nearest multiple of 16. Android H.264 MediaCodec
/// encoders on many chipsets reject a width/height that is not 16-aligned
/// (1080 % 16 == 8) — the primary cause of "Could not prepare video" on
/// specific devices. 16-aligned dimensions are accepted by hardware encoders
/// universally, so this is safe for every device.
int _align16(int v) => (v + 15) & ~15;

/// Probe the input and append codec / resolution / audio to [log] so we can see
/// exactly what a failing device fed the encoder. Never throws.
Future<void> _probeInto(String path, void Function(String) log) async {
  try {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      log('PROBE: no media information');
      return;
    }
    log(
      'PROBE format=${info.getFormat()} duration=${info.getDuration()} '
      'size=${info.getSize()} bitrate=${info.getBitrate()}',
    );
    for (final s in info.getStreams()) {
      log(
        'PROBE stream type=${s.getType()} codec=${s.getCodec()} '
        'w=${s.getWidth()} h=${s.getHeight()} '
        'bitrate=${s.getBitrate()} sampleRate=${s.getSampleRate()}',
      );
    }
  } catch (e) {
    log('PROBE failed: $e');
  }
}

/// Re-encodes [inputPath] to reel spec (16-aligned target, target bitrate),
/// optionally trimming. Uses hardware encoders on iOS/Android with a software
/// MPEG-4 fallback on Android. [onProgress] is 0.0–1.0 when duration is known.
///
/// If every encode attempt fails, [onFailure] is invoked with a full diagnostic
/// report (probe + args + ffmpeg logs) so the caller can persist it. The
/// function still returns null in that case (unchanged contract).
Future<File?> compressReelVideoForPreview({
  required String inputPath,
  required void Function(double progress) onProgress,
  double trimStartMs = 0,
  double? trimEndMs,
  double? totalDurationMs,
  void Function(String report)? onFailure,
}) async {
  final report = StringBuffer();
  void log(String m) {
    // ignore: avoid_print
    print('$_kTag $m');
    report.writeln(m);
  }

  log('===== compress START =====');
  log(
    'platform=${Platform.operatingSystem} input=$inputPath '
    'trimStartMs=$trimStartMs trimEndMs=$trimEndMs totalMs=$totalDurationMs',
  );

  final input = File(inputPath);
  final inputExists = await input.exists();
  final inputSize = inputExists ? await input.length() : -1;
  log('input.exists=$inputExists sizeBytes=$inputSize');
  if (!inputExists) {
    log('ABORT: input file missing');
    onFailure?.call(report.toString());
    return null;
  }

  await _probeInto(inputPath, log);

  final outDir = await getTemporaryDirectory();
  final outPath =
      '${outDir.path}/reel_compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

  final w = _align16(ReelVideoSpec.exportWidth); // 1080 -> 1088
  final h = _align16(ReelVideoSpec.exportHeight); // 1920 -> 1920
  final brK = (ReelVideoSpec.exportBitrate / 1000).round();
  log('exportW=$w exportH=$h bitrateK=$brK (w%16=${w % 16} h%16=${h % 16})');

  final vf =
      'scale=$w:$h:force_original_aspect_ratio=decrease,'
      'pad=$w:$h:(ow-iw)/2:(oh-ih)/2';

  final endMs = trimEndMs ?? 0.0;
  final hasTrim = endMs > trimStartMs + 32;
  final totalMs = totalDurationMs ?? 0.0;
  final spanMs = hasTrim
      ? (endMs - trimStartMs)
      : (totalMs > 0 ? totalMs : 0.0);
  log('hasTrim=$hasTrim spanMs=$spanMs vf=$vf');

  List<String> buildArgs(List<String> venc, String vfilter) => <String>[
    '-y',
    if (trimStartMs > 32) ...['-ss', '${trimStartMs / 1000.0}'],
    '-i',
    inputPath,
    if (hasTrim) ...['-t', '${(endMs - trimStartMs) / 1000.0}'],
    '-vf',
    vfilter,
    ...venc,
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-movflags',
    '+faststart',
    outPath,
  ];

  Future<bool> runEncode(String label, List<String> args) async {
    log('[$label] ARGS: ${args.join(' ')}');
    final completer = Completer<bool>();
    final started = DateTime.now();
    // Capture ffmpeg log lines via the callback — session.getAllLogsAsString()
    // is often empty in async mode, so we buffer them ourselves.
    final logBuf = StringBuffer();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        final ok = ReturnCode.isSuccess(rc);
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        log('[$label] DONE ok=$ok rc=${rc?.getValue()} elapsedMs=$elapsed');
        final logs = logBuf.toString().trim();
        // Full ffmpeg output always goes into the report; only echo it to the
        // console when the attempt failed (keeps normal runs quiet).
        report.writeln('[$label] LOGS>>>');
        report.writeln(logs);
        report.writeln('[$label] <<<LOGS');
        if (!ok) {
          // ignore: avoid_print
          print('$_kTag [$label] LOGS>>>\n$logs\n$_kTag [$label] <<<LOGS');
          final failStack = await session.getFailStackTrace();
          log('[$label] failStack=$failStack');
        }
        if (!completer.isCompleted) completer.complete(ok);
      },
      (l) {
        logBuf.writeln(l.getMessage());
      },
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
    return completer.future;
  }

  // Primary path: hardware encoder (h264_mediacodec / videotoolbox), with a
  // yuv420p input so MediaCodec gets a format it accepts.
  log('attempting PRIMARY (hardware) encode…');
  var ok = await runEncode(
    'primary',
    buildArgs(_h264VideoEncodeArgsK(brK), '$vf,format=yuv420p'),
  );
  log('PRIMARY result ok=$ok');

  // Fallback (Android): some devices' MediaCodec H.264 encoder fails outright.
  // Retry with the software MPEG-4 encoder bundled in this min FFmpeg build so
  // the export still completes (libx264 is GPL and not available here).
  if (!ok && Platform.isAndroid) {
    log('PRIMARY failed -> FALLBACK software mpeg4…');
    ok = await runEncode(
      'fallback-mpeg4',
      buildArgs(const ['-c:v', 'mpeg4', '-q:v', '4'], vf),
    );
    log('FALLBACK result ok=$ok');
  }

  onProgress(1.0);

  if (ok) {
    final out = File(outPath);
    final outExists = await out.exists();
    final outSize = outExists ? await out.length() : -1;
    log('out.exists=$outExists sizeBytes=$outSize');
    if (outExists && outSize > 0) {
      log('===== END SUCCESS -> $outPath ($outSize bytes) =====');
      return out;
    }
    log('encode reported success but output is missing/empty');
  }

  log('===== END FAILURE: all encode attempts failed =====');
  onFailure?.call(report.toString());
  return null;
}
