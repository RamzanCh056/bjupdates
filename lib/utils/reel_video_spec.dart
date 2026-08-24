/// Reel video specifications: max length, resolution, aspect ratio, formats, file size.
///
/// **Video specifications (product)**
/// - Maximum length: [maxDurationSeconds] seconds
/// - Resolution: [exportWidth] × [exportHeight] (9:16)
/// - Aspect ratio: [aspectRatio] (width/height)
/// - Formats: [supportedFormats] (pick / upload)
/// - Max file size: [maxFileSizeBytes] (100 MB)
///
/// **Export pipeline (where implemented)**
/// 1. Process edits — `video_editor.dart` (trim, speed, music, filter, text, stickers).
/// 2. Render final video — `ProVideoEditor.renderVideo` at export resolution/bitrate (native / FFmpeg-backed).
/// 3. Compress — same render step; optional `compressReelVideoForPreview` in `reel_ffmpeg_extract.dart`.
/// 4. Upload — Firebase Storage + Firestore (`create_video_screen`, `reel_preview_upload_screen`, `new_reels`).
///
/// Enforcement: pick (format, size, max recording length), editor trim cap, preview upload checks,
/// `reel_gallery_picker_screen`, reels playback aspect.
class ReelVideoSpec {
  ReelVideoSpec._();

  /// Maximum video length for reels (seconds). Editor trim max must match this.
  static const int maxDurationSeconds = 60;

  /// Export resolution: 1080 x 1920 (9:16 portrait). width/height = 9/16.
  static const int exportWidth = 1080;
  static const int exportHeight = 1920;

  /// Aspect ratio 9:16 (width / height). Matches exportWidth/exportHeight.
  static const double aspectRatio = 9.0 / 16.0;

  /// Supported file formats (lowercase extensions). Only these are accepted when picking/uploading.
  static const List<String> supportedFormats = ['mp4', 'mov'];

  /// Maximum file size in bytes (100 MB). Enforced before opening editor and before init.
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  /// Bitrate for 1080x1920 export (4.5 Mbps).
  static const int exportBitrate = 4500000;

  static bool isSupportedFormat(String extension) {
    return supportedFormats.contains(extension.toLowerCase());
  }

  static bool isWithinFileSize(int bytes) {
    return bytes > 0 && bytes <= maxFileSizeBytes;
  }

  /// True if duration is within (0, maxDurationSeconds], with small tolerance for container rounding.
  static bool isWithinMaxDuration(Duration d) {
    if (d.inMilliseconds <= 0) return false;
    return d.inMilliseconds <= maxDurationSeconds * 1000 + 500;
  }
}
