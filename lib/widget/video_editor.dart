import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../model/music_track_model.dart';
import '../utils/reel_video_spec.dart';
import '../utils/reel_tips.dart';
import 'music_browser.dart';

/// Core editing only: Trim (3–60s), Music, Filters, Text, Stickers (drag/resize),
/// Speed (0.3x–2x), separate video/music volume. No crop/extra effects.
class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final Function(File videoFile, Map<String, dynamic> editData) onVideoEdited;

  const VideoEditorScreen({
    Key? key,
    required this.videoFile,
    required this.onVideoEdited,
  }) : super(key: key);

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _cachedDurationMs = 0;

  // Trim: 3–[ReelVideoSpec.maxDurationSeconds] seconds (single source of truth).
  static const double _minDurationSec = 3;
  static double get _maxDurationSec => ReelVideoSpec.maxDurationSeconds.toDouble();

  double _trimStartMs = 0;
  double _trimEndMs = 0;

  // Speed: 0.3x – 2x
  double _speed = 1.0;
  static const List<double> _speedOptions = [
    0.3,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  // Music & volume
  MusicTrack? _selectedMusic;
  double _musicVolume = 0.5;
  double _videoVolume = 1.0;

  /// When true, original video sound is muted (saved as videoVolume 0 when music is added).
  bool _muteOriginalVideo = false;

  // Filters: Vintage, Warm, Cool, Cinematic, Black & White
  String _selectedFilter = 'None';
  static const List<String> _filters = [
    'None',
    'Vintage',
    'Warm',
    'Cool',
    'Cinematic',
    'Black & White',
  ];

  // Text overlay: text, color, size, font style
  String _textOverlay = '';
  late final TextEditingController _textOverlayController;
  final FocusNode _textFocusNode = FocusNode();
  Color _textColor = Colors.white;
  double _textSize = 18.0;
  String _textFontStyle = 'Default'; // Default, Bold, Italic, Bold + Italic

  // Stickers: emoji, x (0-1), y (0-1), scale; selected index for resize
  final List<Map<String, dynamic>> _stickers = [];
  int? _selectedStickerIndex;
  static const List<String> _stickerEmojis = [
    '❤️',
    '🔥',
    '😂',
    '😍',
    '👍',
    '✨',
    '💯',
    '🎵',
    '⭐',
    '💪',
    '🙌',
    '😎',
    '👏',
    '💕',
    '🌟',
    '😊',
  ];

  int _selectedToolIndex = 0;
  static final List<Map<String, dynamic>> _tabs = [
    {'label': 'Trim', 'icon': Icons.content_cut},
    {'label': 'Speed', 'icon': Icons.speed},
    {'label': 'Music', 'icon': Icons.music_note},
    {'label': 'Filter', 'icon': Icons.filter},
    {'label': 'Text', 'icon': Icons.text_fields},
    {'label': 'Stickers', 'icon': Icons.emoji_emotions},
  ];

  bool _isExporting = false;

  /// 0.0–1.0 during render (from pro_video_editor progress stream).
  double _exportProgress = 0.0;

  /// When true, we disposed the preview to free memory while user is in Music/Filter/Text/Stickers/Speed.
  bool _previewDisposedToSaveMemory = false;

  AudioPlayer? _musicPlayer;

  @override
  void initState() {
    super.initState();
    _textOverlayController = TextEditingController(text: _textOverlay);
    _textFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _initVideo();
  }

  /// Tap video → Text tab + bottom sheet to type (preview updates on video, not a center box).
  void _enterTextMode() {
    if (_isExporting || !_isInitialized || _controller == null) return;
    setState(() => _selectedToolIndex = 4);
    _openTextEditBottomSheet();
  }

  Future<void> _openTextEditBottomSheet() async {
    if (_isExporting || !_isInitialized) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _textFocusNode.requestFocus();
        });
        final sheetH = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: sheetH,
            child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border.all(color: Colors.white12),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Text on video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _textFocusNode.unfocus();
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _buildTextEditingForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Future<void> _initVideo() async {
    if (!mounted) return;
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(widget.videoFile);
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      final durationMs = c.value.duration.inMilliseconds.toDouble();
      _cachedDurationMs = durationMs > 0 ? durationMs : 0;
      _controller = c;
      double endMs = _cachedDurationMs;
      if (endMs > _maxDurationSec * 1000) endMs = _maxDurationSec * 1000;
      if (endMs < _minDurationSec * 1000) endMs = _cachedDurationMs;
      _trimEndMs = endMs;
      setState(() {
        _isInitialized = true;
        _controller!.setLooping(true);
        _controller!.setPlaybackSpeed(_speed);
        _applyVideoVolumeToPreview();
        _controller!.play();
      });
      _controller!.addListener(_onPositionChanged);
      _controller!.addListener(_syncMusicToVideo);
      await _initMusicAndSync();
    } catch (e) {
      c?.dispose();
      if (mounted) AppToast.show('Video load failed', isError: true);
    }
  }

  /// Apply current mute/video volume to the preview controller so original voice is muted when toggle is on.
  void _applyVideoVolumeToPreview() {
    final c = _controller;
    if (c == null) return;
    final vol = (_muteOriginalVideo && _selectedMusic != null)
        ? 0.0
        : _videoVolume;
    c.setVolume(vol.clamp(0.0, 1.0));
  }

  void _syncMusicToVideo() {
    if (!mounted) return;
    final c = _controller;
    if (c == null) return;
    try {
      if (c.value.isPlaying) {
        _musicPlayer?.play();
      } else {
        _musicPlayer?.pause();
      }
    } catch (_) {}
  }

  Future<void> _initMusicAndSync() async {
    if (_selectedMusic == null) return;
    if (!mounted) return;
    try {
      _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();
      final url = _selectedMusic!.audioUrl;
      if (url.isEmpty || (!url.startsWith('http') && !url.startsWith('file'))) {
        if (mounted) AppToast.show('Invalid music URL', isError: true);
        return;
      }
      await _musicPlayer!.setUrl(url);
      await _musicPlayer!.setLoopMode(LoopMode.one);
      await _musicPlayer!.setVolume(_musicVolume);
      if (_controller != null && _controller!.value.isPlaying) {
        await _musicPlayer!.seek(Duration.zero);
        await _musicPlayer!.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) AppToast.show('Could not load music: $e', isError: true);
    }
  }

  void _onPositionChanged() {
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isPlaying) return;
    try {
      final pos = c.value.position.inMilliseconds.toDouble();
      if (pos >= _trimEndMs) {
        c.pause();
        c.seekTo(Duration(milliseconds: _trimStartMs.toInt()));
        _musicPlayer?.seek(Duration.zero);
        _musicPlayer?.play();
        c.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _textOverlayController.dispose();
    final c = _controller;
    if (c != null) {
      c.removeListener(_onPositionChanged);
      c.removeListener(_syncMusicToVideo);
      c.dispose();
      _controller = null;
    }
    _musicPlayer?.dispose();
    _musicPlayer = null;
    super.dispose();
  }

  double get _durationMs => _controller != null
      ? _controller!.value.duration.inMilliseconds.toDouble()
      : _cachedDurationMs;

  void _disposeController() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onPositionChanged);
      c.removeListener(_syncMusicToVideo);
      c.pause();
      c.dispose();
      _controller = null;
    }
    _musicPlayer?.dispose();
    _musicPlayer = null;
  }

  void _onToolTabChanged(int i) {
    final nowTrim = i == 0;
    const musicTabIndex = 2;
    setState(() => _selectedToolIndex = i);

    // Keep video preview alive on all tabs (Trim, Speed, Filter, Text, Stickers, Music) so user sees live preview.
    // On Music tab: pause video to save CPU; keep controller so returning from music browser doesn't re-init.
    if (i == musicTabIndex && _controller != null) {
      _controller!.pause();
      _musicPlayer?.pause();
      setState(() {});
    }

    // When returning to Trim and preview was previously disposed (legacy path), restore it.
    if (nowTrim && _controller == null && _cachedDurationMs > 0) {
      _previewDisposedToSaveMemory = false;
      _initVideo();
    }
  }

  void _selectMusic() async {
    _controller?.pause();
    _musicPlayer?.pause();
    if (mounted) setState(() {});
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MusicBrowserScreen(
          onMusicSelected: (track) {
            if (track != null && mounted)
              setState(() => _selectedMusic = track);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (_selectedMusic == null) return;
    setState(() => _selectedToolIndex = 0);
    final c = _controller;
    if (c == null && _cachedDurationMs > 0) {
      _previewDisposedToSaveMemory = false;
      await _initVideo();
      if (mounted) setState(() {});
      return;
    }
    if (c != null) {
      try {
        c.seekTo(Duration(milliseconds: _trimStartMs.toInt()));
        c.play();
      } catch (_) {}
      if (mounted) setState(() {});
    }
    _initMusicAndSync().then((_) {
      if (!mounted || _musicPlayer == null) return;
      try {
        _musicPlayer!.seek(Duration.zero);
        _musicPlayer!.play();
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  ColorFilter? _filterMatrix(String name) {
    switch (name) {
      case 'Black & White':
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Cinematic':
        return const ColorFilter.matrix([
          0.9,
          0.05,
          0.05,
          0,
          0,
          0.05,
          0.9,
          0.05,
          0,
          0,
          0.05,
          0.05,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      default:
        return null;
    }
  }

  /// Export pipeline: (1) Process edits → (2) Render via pro_video_editor (FFmpeg/native) →
  /// (3) Compressed output (resolution + bitrate) → (4) File ready for upload to backend.
  /// Video rendering runs in background (native); we yield to avoid UI freezing and show progress.
  Future<void> _saveAndNext() async {
    final editData = _buildEditData();
    final hasOverlay = _textOverlay.trim().isNotEmpty || _stickers.isNotEmpty;
    final needExport =
        _trimStartMs > 0 ||
        (_trimEndMs < _cachedDurationMs) ||
        _speed != 1.0 ||
        hasOverlay;

    if (!needExport) {
      _disposeController();
      widget.onVideoEdited(widget.videoFile, editData);
      return;
    }

    _disposeController();
    if (mounted)
      setState(() {
        _isExporting = true;
        _exportProgress = 0;
      });

    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await Future.delayed(Duration.zero);
      if (!mounted) return;

      final out = await Future<File?>(() async {
        return await _exportVideoWithProgress();
      });
      if (out != null && mounted) {
        widget.onVideoEdited(out, editData);
      } else {
        if (mounted) AppToast.show('Export failed', isError: true);
      }
    } catch (e) {
      if (mounted) AppToast.show('Export error: $e', isError: true);
    } finally {
      if (mounted)
        setState(() {
          _isExporting = false;
          _exportProgress = 0;
        });
    }
  }

  Map<String, dynamic> _buildEditData() {
    final musicMap = _selectedMusic == null
        ? null
        : <String, dynamic>{
            ..._selectedMusic!.toMap(),
            'id': _selectedMusic!.id,
            'musicUrl': _selectedMusic!.audioUrl,
          };
    final effectiveVideoVolume = (_muteOriginalVideo && _selectedMusic != null)
        ? 0.0
        : _videoVolume;
    return {
      'music': musicMap,
      'musicVolume': _musicVolume,
      'videoVolume': effectiveVideoVolume,
      'muteOriginalVideo': _selectedMusic != null ? _muteOriginalVideo : false,
      'filter': _selectedFilter,
      'caption': {
        'text': _textOverlay,
        'color': _textColor.value,
        'size': _textSize,
        'fontStyle': _textFontStyle,
      },
      'trimStartMs': _trimStartMs,
      'trimEndMs': _trimEndMs,
      'speed': _speed,
      'stickers': List<Map<String, dynamic>>.from(_stickers),
    };
  }

  /// Renders text overlay + stickers to a transparent PNG at full export size (1080x1920).
  /// Same aspect ratio as frame so no stretching; text and stickers stay inside frame with safe margins.
  Future<Uint8List?> _buildOverlayImageBytes(int width, int height) async {
    final hasText = _textOverlay.trim().isNotEmpty;
    final hasStickers = _stickers.isNotEmpty;
    if (!hasText && !hasStickers) return null;

    await Future.delayed(Duration.zero);

    final w = width.toDouble();
    final h = height.toDouble();
    const double refWidth = 1080.0;
    final scaleW = w / refWidth;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Colors.transparent,
    );

    // Margins so text doesn't touch edges; sticker positions use full frame (0-1) then clamp paint
    const double marginX = 48.0;
    const double marginY = 80.0;
    final safeW = w - 2 * marginX;

    // Draw stickers at normalized 0-1 (same as editor); clamp paint so fully inside frame
    for (final s in _stickers) {
      final emoji = s['emoji'] as String? ?? '❤️';
      final x = ((s['x'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);
      final y = ((s['y'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);
      final scale = (s['scale'] as num?)?.toDouble() ?? 1.0;
      final px = x * w;
      final py = y * h;
      final emojiSize = (96.0 * scale * scaleW).clamp(24.0, 200.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: emojiSize, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final dx = (px - textPainter.width / 2).clamp(0.0, w - textPainter.width);
      final dy = (py - textPainter.height / 2).clamp(
        0.0,
        h - textPainter.height,
      );
      textPainter.paint(canvas, Offset(dx, dy));
    }

    // Draw text at bottom center; keep inside frame
    if (hasText) {
      final fontSize = (_textSize * 4 * scaleW).clamp(14.0, 120.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: _textOverlay,
          style: TextStyle(
            color: _textColor,
            fontSize: fontSize,
            fontWeight: _textBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: _textItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      );
      textPainter.layout(maxWidth: safeW);
      final tx = (w - textPainter.width) / 2.0;
      final ty = (h - textPainter.height - marginY * 2).clamp(
        marginY,
        h - textPainter.height - marginY,
      );
      textPainter.paint(
        canvas,
        Offset(tx.clamp(marginX, w - textPainter.width - marginX), ty),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// Renders final video using pro_video_editor (FFmpeg/native), with compression via resolution + bitrate.
  /// Returns the exported file ready for upload to backend.
  Future<File?> _exportVideoWithProgress() async {
    final startMs = _trimStartMs.toInt().clamp(0, _cachedDurationMs.toInt());
    final endMs = _trimEndMs.toInt().clamp(0, _cachedDurationMs.toInt());
    if (endMs <= startMs) return null;

    final taskId = 'edit-${DateTime.now().millisecondsSinceEpoch}';
    // Spec: 1080x1920 (9:16), compressed via bitrate.
    const int exportWidth = ReelVideoSpec.exportWidth;
    const int exportHeight = ReelVideoSpec.exportHeight;
    const int exportBitrate = ReelVideoSpec.exportBitrate;

    // Build overlay at full export resolution (1080x1920) so text/stickers stay inside frame with no stretching
    if (mounted) setState(() => _exportProgress = 0.05);
    await Future.delayed(Duration.zero);
    final overlayBytes = await _buildOverlayImageBytes(
      exportWidth,
      exportHeight,
    );
    if (mounted) setState(() => _exportProgress = 0.08);
    await Future.delayed(Duration.zero);

    final task = RenderVideoModel(
      id: taskId,
      video: EditorVideo.file(widget.videoFile),
      imageBytes: overlayBytes,
      outputFormat: VideoOutputFormat.mp4,
      enableAudio: true,
      playbackSpeed: _speed,
      startTime: Duration(milliseconds: startMs),
      endTime: Duration(milliseconds: endMs),
      blur: 0,
      bitrate: exportBitrate,
      transform: const ExportTransform(
        flipX: false,
        flipY: false,
        x: 0,
        y: 0,
        width: exportWidth,
        height: exportHeight,
        rotateTurns: 0,
        scaleX: 1.0,
        scaleY: 1.0,
      ),
    );

    StreamSubscription? progressSub;
    progressSub = ProVideoEditor.instance.progressStreamById(taskId).listen((
      data,
    ) {
      if (mounted)
        setState(() => _exportProgress = data.progress.clamp(0.0, 1.0));
    });

    try {
      final bytes = await ProVideoEditor.instance.renderVideo(task);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/edited_$taskId.mp4');
      await f.writeAsBytes(bytes);
      return f;
    } finally {
      await progressSub.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: _isExporting ? Colors.grey : Colors.white,
          ),
          onPressed: _isExporting ? null : () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Step 2 of ${ReelTips.totalSteps}',
              style: TextStyle(
                color: purpleAccent.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_isExporting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _exportProgress > 0 ? _exportProgress : null,
                        color: purpleAccent,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_exportProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _saveAndNext,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildEditorBody(),
          if (_isExporting) _buildExportProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildExportProgressOverlay() {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: purpleAccent.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_file, color: purpleAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Compressing & exporting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please wait…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _exportProgress > 0 ? _exportProgress : null,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      purpleAccent,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(_exportProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorBody() {
    final hasVideo = _isInitialized && _controller != null;

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: hasVideo
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter:
                          _filterMatrix(_selectedFilter) ??
                          const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                    // Tap video (outside center play) → Text tab + keyboard (TikTok-style).
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _enterTextMode,
                      ),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                            _controller!.seekTo(
                              Duration(milliseconds: _trimStartMs.toInt()),
                            );
                          }
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    if (_textOverlay.isNotEmpty)
                      Positioned(
                        bottom: 56,
                        left: 16,
                        right: 16,
                        child: IgnorePointer(
                          child: Center(
                            child: Text(
                              _textOverlay,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: _textSize,
                                fontWeight: _textBold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: _textItalic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    for (int i = 0; i < _stickers.length; i++)
                      _buildDraggableSticker(context, i),
                    if (_selectedMusic != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedMusic!.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : _previewDisposedToSaveMemory
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap Trim to preview',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: purpleAccent),
                ),
        ),
        if (hasVideo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                      _controller!.seekTo(
                        Duration(milliseconds: _trimStartMs.toInt()),
                      );
                    }
                    setState(() {});
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      RangeSlider(
                        values: RangeValues(
                          _trimStartMs / (_durationMs > 0 ? _durationMs : 1),
                          (_trimEndMs / (_durationMs > 0 ? _durationMs : 1))
                              .clamp(0.0, 1.0),
                        ),
                        onChanged: (v) {
                          final dur = _durationMs;
                          if (dur <= 0) return;
                          double start = v.start * dur;
                          double end = v.end * dur;
                          if (end - start < _minDurationSec * 1000) {
                            end = start + _minDurationSec * 1000;
                            if (end > dur) {
                              end = dur;
                              start = (dur - _minDurationSec * 1000).clamp(
                                0.0,
                                dur,
                              );
                            }
                          }
                          if (end - start > _maxDurationSec * 1000) {
                            end = start + _maxDurationSec * 1000;
                          }
                          setState(() {
                            _trimStartMs = start;
                            _trimEndMs = end.clamp(0.0, dur);
                            _controller?.seekTo(
                              Duration(milliseconds: _trimStartMs.toInt()),
                            );
                          });
                        },
                        activeColor: purpleAccent,
                        inactiveColor: Colors.grey[700],
                      ),
                      Text(
                        'Clip: ${(_trimStartMs / 1000).toStringAsFixed(1)}s – ${(_trimEndMs / 1000).toStringAsFixed(1)}s (min 3s, max 60s)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // One-line tip for current tool (Instagram-style algorithm tips)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            _selectedToolIndex < ReelTips.editorToolTips.length
                ? ReelTips.editorToolTips[_selectedToolIndex]
                : ReelTips.step2Subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _tabs.length,
            itemBuilder: (context, i) {
              final tab = _tabs[i];
              final selected = _selectedToolIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: selected ? purpleAccent : Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _onToolTabChanged(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tab['label'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildToolPanel(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableSticker(BuildContext context, int index) {
    final s = _stickers[index];
    double x = (s['x'] as num?)?.toDouble() ?? 0.4;
    double y = (s['y'] as num?)?.toDouble() ?? 0.4;
    double scale = (s['scale'] as num?)?.toDouble() ?? 1.0;
    final selected = _selectedStickerIndex == index;
    final screenSize = MediaQuery.of(context).size;
    final refW = screenSize.width > 0 ? screenSize.width : 300.0;
    final refH = screenSize.height > 0 ? screenSize.height : 400.0;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: Alignment((x - 0.5) * 2, (y - 0.5) * 2),
        child: GestureDetector(
          onTap: () => setState(
            () => _selectedStickerIndex = _selectedStickerIndex == index
                ? null
                : index,
          ),
          onLongPress: () {
            setState(() => _stickers.removeAt(index));
            if (_selectedStickerIndex == index)
              _selectedStickerIndex = null;
            else if (_selectedStickerIndex != null &&
                _selectedStickerIndex! > index) {
              _selectedStickerIndex = _selectedStickerIndex! - 1;
            }
          },
          onPanUpdate: (d) {
            setState(() {
              _stickers[index]['x'] =
                  ((_stickers[index]['x'] as num) + (d.delta.dx / refW)).clamp(
                    0.0,
                    1.0,
                  );
              _stickers[index]['y'] =
                  ((_stickers[index]['y'] as num) + (d.delta.dy / refH)).clamp(
                    0.0,
                    1.0,
                  );
            });
          },
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: purpleAccent, width: 2),
                  )
                : null,
            child: Text(
              s['emoji'] as String? ?? '❤️',
              style: TextStyle(fontSize: 32 * scale),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolPanel() {
    switch (_selectedToolIndex) {
      case 0:
        return _buildTrimPanel();
      case 1:
        return _buildSpeedPanel();
      case 2:
        return _buildMusicPanel();
      case 3:
        return _buildFilterPanel();
      case 4:
        return _buildTextPanel();
      case 5:
        return _buildStickersPanel();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTrimPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trim (3–60 seconds)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use the timeline above. Min 3s, max 60s.',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSpeedPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Speed (0.3x – 2x)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _speedOptions.map((s) {
            final selected = _speed == s;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _speed = s;
                  _controller?.setPlaybackSpeed(s);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? purpleAccent : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${s}x',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMusicPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Music',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedMusic != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: purpleAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMusic!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _selectedMusic!.artist,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _selectedMusic = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('Music', style: TextStyle(color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _musicVolume = (_musicVolume - 0.1).clamp(0.0, 1.0);
                    _musicPlayer?.setVolume(_musicVolume);
                  });
                },
              ),
              Expanded(
                child: Slider(
                  value: _musicVolume,
                  min: 0,
                  max: 1,
                  activeColor: purpleAccent,
                  onChanged: (v) {
                    setState(() {
                      _musicVolume = v;
                      _musicPlayer?.setVolume(v);
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _musicVolume = (_musicVolume + 0.1).clamp(0.0, 1.0);
                    _musicPlayer?.setVolume(_musicVolume);
                  });
                },
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(_musicVolume * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('Video', style: TextStyle(color: Colors.white)),
              ),
              if (_muteOriginalVideo)
                Expanded(
                  child: Text(
                    'Muted',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                )
              else ...[
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(
                      () => _videoVolume = (_videoVolume - 0.1).clamp(0.0, 1.0),
                    );
                    _applyVideoVolumeToPreview();
                  },
                ),
                Expanded(
                  child: Slider(
                    value: _videoVolume,
                    min: 0,
                    max: 1,
                    activeColor: purpleAccent,
                    onChanged: (v) {
                      setState(() => _videoVolume = v);
                      _applyVideoVolumeToPreview();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(
                      () => _videoVolume = (_videoVolume + 0.1).clamp(0.0, 1.0),
                    );
                    _applyVideoVolumeToPreview();
                  },
                ),
              ],
              if (!_muteOriginalVideo)
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(_videoVolume * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Volumes are saved and applied when the reel is played.',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectMusic,
              icon: const Icon(Icons.music_note, color: Colors.white),
              label: const Text(
                'Add music (library or device)',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Filter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_isExporting)
              InkWell(
                onTap: _saveAndNext,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = _filters[i];
              final selected = _selectedFilter == f;
              return _buildFilterThumbnailTile(
                label: f,
                selected: selected,
                onTap: () => setState(() => _selectedFilter = f),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Color> _filterPreviewColors(String name) {
    switch (name) {
      case 'Vintage':
        return [const Color(0xFF7E5A3C), const Color(0xFFC29A62)];
      case 'Warm':
        return [const Color(0xFF6B3B24), const Color(0xFFE08A4A)];
      case 'Cool':
        return [const Color(0xFF1F355C), const Color(0xFF4E88D8)];
      case 'Cinematic':
        return [const Color(0xFF1A1D28), const Color(0xFF5B4050)];
      case 'Black & White':
        return [const Color(0xFF222222), const Color(0xFFBDBDBD)];
      case 'None':
      default:
        return [const Color(0xFF2B2B2B), const Color(0xFF585858)];
    }
  }

  Widget _buildFilterThumbnailTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = _filterPreviewColors(label);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 70,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? purpleAccent : Colors.white12,
                width: selected ? 2.2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: purpleAccent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 20,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 78,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// TikTok-style compact chip above the text field (keyboard / Aa / color).
  Widget _textToolChip({
    IconData? icon,
    String? label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.grey[700] : Colors.grey[800],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }

  bool get _textBold =>
      _textFontStyle == 'Bold' || _textFontStyle == 'Bold + Italic';
  bool get _textItalic =>
      _textFontStyle == 'Italic' || _textFontStyle == 'Bold + Italic';

  /// Shown in the bottom tool strip when "Text" tab is selected (typing is in the sheet).
  Widget _buildTextPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Text is added from the bottom sheet. Tap the video or open the editor — your words show on the video in real time.',
          style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: purpleAccent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _openTextEditBottomSheet,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Add or edit text',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_textOverlay.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Preview: $_textOverlay',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// Full text controls: used only inside [_openTextEditBottomSheet] (updates video preview via setState).
  Widget _buildTextEditingForm() {
    final fontStyles = ['Default', 'Bold', 'Italic', 'Bold + Italic'];
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      purpleAccent,
      Colors.orange,
      Colors.cyan,
      Colors.pink,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _textToolChip(
                icon: Icons.keyboard_rounded,
                selected: _textFocusNode.hasFocus,
                onTap: () => _textFocusNode.requestFocus(),
              ),
              const SizedBox(width: 6),
              _textToolChip(
                label: 'Aa',
                selected: _textFontStyle != 'Default',
                onTap: () {
                  setState(() {
                    _textFontStyle = _textFontStyle == 'Default'
                        ? 'Bold'
                        : 'Default';
                  });
                },
              ),
              const SizedBox(width: 6),
              _textToolChip(
                icon: Icons.color_lens_outlined,
                selected: false,
                onTap: () => _textFocusNode.requestFocus(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textOverlayController,
          focusNode: _textFocusNode,
          autofocus: false,
          onChanged: (v) => setState(() => _textOverlay = v),
          style: const TextStyle(color: Colors.white, fontSize: 17),
          decoration: InputDecoration(
            hintText: 'Type here — appears on your video',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Size ', style: TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: _textSize,
                min: 12,
                max: 32,
                divisions: 10,
                activeColor: purpleAccent,
                onChanged: (v) => setState(() => _textSize = v),
              ),
            ),
            Text(
              '${_textSize.toInt()}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Style',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        Wrap(
          spacing: 8,
          children: fontStyles.map((st) {
            final sel = _textFontStyle == st;
            return GestureDetector(
              onTap: () => setState(() => _textFontStyle = st),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel ? purpleAccent : Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  st,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        const Text(
          'Color',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: colors.map((c) {
            final sel = _textColor == c;
            return GestureDetector(
              onTap: () => setState(() => _textColor = c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: sel
                      ? Border.all(color: purpleAccent, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStickersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stickers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap to add. Drag on video to move. Long-press to remove.',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        if (_selectedStickerIndex != null &&
            _selectedStickerIndex! < _stickers.length) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Size ',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              Expanded(
                child: Slider(
                  value:
                      (_stickers[_selectedStickerIndex!]['scale'] as num?)
                          ?.toDouble() ??
                      1.0,
                  min: 0.5,
                  max: 2.0,
                  activeColor: purpleAccent,
                  onChanged: (v) {
                    setState(
                      () => _stickers[_selectedStickerIndex!]['scale'] = v,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _stickerEmojis
              .map(
                (e) => GestureDetector(
                  onTap: () => setState(
                    () => _stickers.add({
                      'emoji': e,
                      'x': 0.4,
                      'y': 0.4,
                      'scale': 1.0,
                    }),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
