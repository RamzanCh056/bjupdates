import 'dart:io';

import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/reel_video_spec.dart';
import 'package:beatjerky/utils/reel_tips.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// Preview edited reel before posting: fullscreen preview, play/pause, progress bar, then caption & upload.
class ReelPreviewUploadScreen extends StatefulWidget {
  final File videoFile;
  final Map<String, dynamic>? editData;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Future<String?> Function(
    String videoUrl,
    String description, {
    Map<String, dynamic>? editData,
    String? coverUrl,
  }) saveToFirestore;

  /// Light "New reel" share UI (caption, settings rows, Save draft / Share) like Instagram.
  final bool instagramLayout;

  const ReelPreviewUploadScreen({
    Key? key,
    required this.videoFile,
    this.editData,
    required this.storage,
    required this.auth,
    required this.firestore,
    required this.saveToFirestore,
    this.instagramLayout = false,
  }) : super(key: key);

  @override
  State<ReelPreviewUploadScreen> createState() => _ReelPreviewUploadScreenState();
}

class _ReelPreviewUploadScreenState extends State<ReelPreviewUploadScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  VideoPlayerController? _videoController;
  AudioPlayer? _musicPlayer;
  bool _videoInitialized = false;
  File? _coverFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isFullscreen = false;
  bool _aiLabelEnabled = false;

  /// Share-sheet options (merged into [editData] on upload).
  String _locationText = '';
  String _taggedPeopleText = '';
  String? _customAudioTitle;
  /// Firestore: `everyone` | `followers` | `private`
  String _audience = 'everyone';

  /// Filter matrix for preview (matches reel playback in new_reels).
  static ColorFilter? _filterFromEditData(Map<String, dynamic>? editData) {
    if (editData == null) return null;
    final name = editData['filter'] as String?;
    if (name == null || name == 'None' || name == 'Normal') return null;
    switch (name) {
      case 'Black & White':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Vintage':
      case 'Warm':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 1, 0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.8, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1, 0,
        ]);
      case 'Cinematic':
        return const ColorFilter.matrix([
          0.9, 0.05, 0.05, 0, 0, 0.05, 0.9, 0.05, 0, 0, 0.05, 0.05, 0.9, 0, 0, 0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  bool get _hasMusicInEditData {
    if (widget.editData == null) return false;
    final m = widget.editData!['music'];
    if (m is! Map<String, dynamic>) return false;
    final url = (m['audioUrl'] ?? m['musicUrl'])?.toString().trim();
    return url != null && url.isNotEmpty;
  }

  /// Apply named filter + optional horizontal mirror (preview only).
  /// Caption + stickers are rendered outside this wrapper.
  Widget _wrapVideoWithFilter(Widget child) {
    final cf = _filterFromEditData(widget.editData);
    final flip = widget.editData?['flipHorizontal'] == true;

    Widget w = child;
    if (cf != null) {
      w = ColorFiltered(colorFilter: cf, child: w);
    }
    if (flip) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: w,
      );
    }
    return w;
  }

  /// On-video text from intermediate editor (`caption` in [editData]).
  String get _overlayCaptionText {
    final cap = widget.editData?['caption'];
    if (cap is Map) return (cap['text'] ?? '').toString();
    return '';
  }

  Color get _overlayCaptionColor {
    final cap = widget.editData?['caption'];
    if (cap is Map) {
      final v = cap['color'];
      if (v is int) return Color(v);
    }
    return whiteColor;
  }

  double get _overlayCaptionSize {
    final cap = widget.editData?['caption'];
    if (cap is Map) {
      return ((cap['size'] as num?)?.toDouble() ?? 22.0).clamp(14.0, 42.0);
    }
    return 22.0;
  }

  List<Map<String, dynamic>> get _stickersFromEditData {
    final raw = widget.editData?['stickers'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  bool get _hasEditDataOverlays {
    if (widget.editData == null) return false;
    if (_overlayCaptionText.trim().isNotEmpty) return true;
    return _stickersFromEditData.isNotEmpty;
  }

  /// Text + emoji stickers from editing screen (same layout as intermediate preview).
  Widget _buildEditDataOverlays() {
    if (!_hasEditDataOverlays) return const SizedBox.shrink();
    final capText = _overlayCaptionText.trim();
    final stickers = _stickersFromEditData;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (capText.isNotEmpty)
              Align(
                alignment: const Alignment(0, 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    capText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _overlayCaptionColor,
                      fontSize: _overlayCaptionSize,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.95),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 0,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final s in stickers)
                      _buildStickerFromEditData(s, w, h),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerFromEditData(
    Map<String, dynamic> s,
    double w,
    double h,
  ) {
    final emoji = s['emoji']?.toString() ?? '❤️';
    final x = (s['x'] as num?)?.toDouble() ?? 0.5;
    final y = (s['y'] as num?)?.toDouble() ?? 0.5;
    final scale = (s['scale'] as num?)?.toDouble() ?? 1.0;
    final base = 40.0 * scale;
    return Positioned(
      left: x * w - base / 2,
      top: y * h - base / 2,
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: 36 * scale,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.88),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  double _previewSliderMax(VideoPlayerController c) {
    final ms = c.value.duration.inMilliseconds.toDouble();
    return ms <= 0 ? 1.0 : ms;
  }

  double _previewSliderValue(VideoPlayerController c) {
    final pos = c.value.position.inMilliseconds.toDouble();
    final maxMs = _previewSliderMax(c);
    return pos.clamp(0.0, maxMs);
  }

  @override
  void initState() {
    super.initState();
    // Historically we prefilled the caption input from the on-video overlay caption.
    // (This mirrors the original behavior before the Instagram-like split.)
    final cap = widget.editData?['caption'];
    if (cap is Map && (cap['text'] as String?)?.trim().isNotEmpty == true) {
      _descriptionController.text = (cap['text'] as String).toString().trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), _initVideo);
    });
  }

  Future<void> _initVideo() async {
    if (!mounted) return;
    _videoController?.dispose();
    _videoController = null;
    final c = VideoPlayerController.file(widget.videoFile);
    try {
      await c.initialize();
    } catch (e) {
      c.dispose();
      if (mounted) setState(() => _videoInitialized = false);
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    _videoController = c;
    _videoController!.setLooping(true);
    final editData = widget.editData;
    if (editData != null) {
      final muteOriginal = editData['muteOriginalVideo'] == true;
      final vol = muteOriginal ? 0.0 : (editData['videoVolume'] as num?)?.toDouble();
      _videoController!.setVolume((vol ?? 1.0).clamp(0.0, 1.0));
    }
    _videoController!.addListener(_syncPreviewMusicToVideo);
    await _initPreviewMusic();
    _videoController!.play();
    if (mounted) setState(() => _videoInitialized = true);
  }

  void _syncPreviewMusicToVideo() {
    if (!mounted) return;
    final c = _videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      _musicPlayer?.play();
    } else {
      _musicPlayer?.pause();
    }
  }

  Future<void> _initPreviewMusic() async {
    if (!_hasMusicInEditData || widget.editData == null) return;
    final m = widget.editData!['music'] as Map<String, dynamic>?;
    if (m == null) return;
    final url = (m['audioUrl'] ?? m['musicUrl'])?.toString().trim();
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http') && !url.startsWith('file')) return;
    try {
      _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setUrl(url);
      await _musicPlayer!.setLoopMode(LoopMode.one);
      final vol = (widget.editData!['musicVolume'] as num?)?.toDouble();
      await _musicPlayer!.setVolume((vol ?? 0.5).clamp(0.0, 1.0));
      if (_videoController?.value.isPlaying == true) {
        await _musicPlayer!.seek(Duration.zero);
        await _musicPlayer!.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) debugPrint('Preview music load failed: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_syncPreviewMusicToVideo);
    _videoController?.dispose();
    _videoController = null;
    _musicPlayer?.dispose();
    _musicPlayer = null;
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (x != null && mounted) setState(() => _coverFile = File(x.path));
  }

  /// Drops video decoder + audio player so native MediaCodec buffers are freed
  /// before Firebase reads the file — avoids OOM on ~256MB heaps during upload.
  Future<void> _releaseMediaForUpload() async {
    if (mounted) setState(() => _isFullscreen = false);
    _videoController?.removeListener(_syncPreviewMusicToVideo);
    final vc = _videoController;
    _videoController = null;
    if (vc != null) {
      try {
        await vc.pause();
      } catch (_) {}
      try {
        vc.dispose();
      } catch (_) {}
    }
    final mp = _musicPlayer;
    _musicPlayer = null;
    if (mp != null) {
      try {
        await mp.dispose();
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _videoInitialized = false);
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  /// ReelVideoSpec: max 100 MB, max 60 s (see `lib/utils/reel_video_spec.dart`).
  Future<void> _assertVideoMeetsReelSpec() async {
    final f = widget.videoFile;
    if (!await f.exists()) {
      throw Exception('Video file is missing');
    }
    final stat = await f.stat();
    if (!ReelVideoSpec.isWithinFileSize(stat.size)) {
      throw Exception(
        'Video file is too large (max ${ReelVideoSpec.maxFileSizeBytes ~/ (1024 * 1024)} MB)',
      );
    }
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(f);
      await c.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Could not read video duration'),
      );
      if (!ReelVideoSpec.isWithinMaxDuration(c.value.duration)) {
        throw Exception(
          'Video must be at most ${ReelVideoSpec.maxDurationSeconds} seconds',
        );
      }
    } finally {
      await c?.dispose();
    }
  }

  /// Upload reel to backend: Firebase Storage (video + optional cover) then Firestore (metadata + editData).
  Future<void> _uploadDirect() async {
    if (_isUploading) return;
    final user = widget.auth.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to upload', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await _releaseMediaForUpload();
      if (!mounted) return;

      await _assertVideoMeetsReelSpec();

      setState(() => _uploadProgress = 0.15);
      final videoFileName = "videos/${DateTime.now().millisecondsSinceEpoch}.mp4";
      final ref = widget.storage.ref(videoFileName);
      final uploadTask = ref.putFile(
        widget.videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final total = snapshot.totalBytes;
        final p = total > 0 ? snapshot.bytesTransferred / total : 0.0;
        setState(() => _uploadProgress = 0.15 + p * 0.65);
      });

      await uploadTask;
      final videoUrl = await ref.getDownloadURL();
      setState(() => _uploadProgress = 0.8);

      String? coverUrl;
      if (_coverFile != null) {
        final coverRef = widget.storage.ref(
          "reel_covers/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
        await coverRef.putFile(_coverFile!);
        coverUrl = await coverRef.getDownloadURL();
      }
      setState(() => _uploadProgress = 0.9);

      final newReelId = await widget.saveToFirestore(
        videoUrl,
        _descriptionController.text.trim(),
        editData: _mergedEditDataForUpload(),
        coverUrl: coverUrl,
      );

      if (!mounted) return;
      setState(() {
        _uploadProgress = 1.0;
        _isUploading = false;
      });
      Navigator.of(context).pop(newReelId);
      AppToast.show('Reel uploaded!');
    } catch (e) {
      if (mounted) {
        AppToast.show('Upload failed: $e', isError: true);
        await _initVideo();
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return _buildFullscreenPreview();
    }
    if (widget.instagramLayout) {
      return _buildInstagramShareScaffold();
    }
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview & Post',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              'Step ${ReelTips.totalSteps} of ${ReelTips.totalSteps}',
              style: TextStyle(
                color: purpleAccent.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Preview your reel, then add caption and post',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildPreviewWithControls(),
              const SizedBox(height: 24),
              const Text(
                'Caption',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add caption (optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: darkBackgroundTertiary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.edit_rounded, color: purpleAccent, size: 22),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 20),
              const Text(
                'Cover photo',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _coverFile != null ? null : _pickCover,
                    icon: const Icon(Icons.add_photo_alternate, color: purpleAccent, size: 20),
                    label: Text(_coverFile != null ? 'Added' : 'Add optional', style: const TextStyle(color: purpleAccent)),
                  ),
                  if (_coverFile != null) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _coverFile = null),
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ],
              ),
              if (_coverFile != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_coverFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Uploading...',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                          Text(
                            '${(_uploadProgress * 100).round()}%',
                            style: const TextStyle(color: purpleAccent, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(purpleAccent),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadDirect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('Uploading ${(_uploadProgress * 100).round()}%'),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_rounded, size: 22),
                            SizedBox(width: 10),
                            Text('Upload Reel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewWithControls() {
    const double previewMaxHeight = 320;
    if (!_videoInitialized || _videoController == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: purpleAccent.withOpacity(0.4), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: const SizedBox(
          height: previewMaxHeight,
          child: Center(child: CircularProgressIndicator(color: purpleAccent)),
        ),
      );
    }
    final c = _videoController!;
    // Reels spec: 9:16 (1080x1920). Use fixed ratio so video is never stretched.
    const safeAspectRatio = ReelVideoSpec.aspectRatio;
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final videoHeight = (screenWidth / safeAspectRatio).clamp(0.0, previewMaxHeight);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withOpacity(0.4), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.value.isInitialized) {
            return const SizedBox(height: previewMaxHeight, child: Center(child: CircularProgressIndicator(color: purpleAccent)));
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                  setState(() {});
                },
                onDoubleTap: () => setState(() => _isFullscreen = true),
                child: SizedBox(
                  height: videoHeight,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: screenWidth,
                      height: screenWidth / safeAspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _wrapVideoWithFilter(VideoPlayer(c)),
                          _buildEditDataOverlays(),
                          if (_hasMusicInEditData)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.music_note, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Music', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                            ),
                          ),
                          Container(
                            color: Colors.transparent,
                            child: Center(
                              child: Icon(
                                _videoController!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                color: Colors.white54,
                                size: 64,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 40,
                          ),
                          onPressed: () {
                            if (c.value.isPlaying) {
                              c.pause();
                            } else {
                              c.play();
                            }
                          },
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: purpleAccent,
                              inactiveTrackColor: Colors.grey[700],
                              thumbColor: purpleAccent,
                            ),
                            child: Slider(
                              value: _previewSliderValue(c),
                              min: 0,
                              max: _previewSliderMax(c),
                              onChanged: (v) {
                                c.seekTo(Duration(milliseconds: v.toInt()));
                                _musicPlayer?.seek(Duration.zero);
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${_formatDuration(c.value.position)} / ${_formatDuration(c.value.duration)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _isFullscreen = true),
                      icon: const Icon(Icons.fullscreen, color: purpleAccent, size: 20),
                      label: const Text('Fullscreen preview', style: TextStyle(color: purpleAccent)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFullscreenPreview() {
    if (!_videoInitialized || _videoController == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: purpleAccent)));
    }
    final c = _videoController!;
    // Reels spec: 9:16 (1080x1920). No stretching.
    const safeAr = ReelVideoSpec.aspectRatio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (!c.value.isInitialized) return const Center(child: CircularProgressIndicator(color: purpleAccent));
                return Center(
                  child: AspectRatio(
                    aspectRatio: safeAr,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _wrapVideoWithFilter(VideoPlayer(c)),
                        _buildEditDataOverlays(),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => setState(() => _isFullscreen = false),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(activeTrackColor: purpleAccent, inactiveTrackColor: Colors.grey[600], thumbColor: purpleAccent),
                        child: Slider(
                          value: _previewSliderValue(c),
                          min: 0,
                          max: _previewSliderMax(c),
                          onChanged: (v) {
                            c.seekTo(Duration(milliseconds: v.toInt()));
                            _musicPlayer?.seek(Duration.zero);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: () {
                              if (c.value.isPlaying) {
                                c.pause();
                              } else {
                                c.play();
                              }
                            },
                          ),
                          const SizedBox(width: 24),
                          Text(
                            '${_formatDuration(c.value.position)} / ${_formatDuration(c.value.duration)}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String get _renameAudioSubtitle {
    if (_customAudioTitle != null && _customAudioTitle!.trim().isNotEmpty) {
      return _customAudioTitle!.trim();
    }
    if (!_hasMusicInEditData || widget.editData == null) return 'Original audio';
    final m = widget.editData!['music'];
    if (m is! Map<String, dynamic>) return 'Original audio';
    final t = (m['title'] ?? '').toString().trim();
    return t.isEmpty ? 'Original audio' : t;
  }

  Map<String, dynamic>? _mergedEditDataForUpload() {
    final base = widget.editData != null
        ? Map<String, dynamic>.from(widget.editData!)
        : <String, dynamic>{};
    if (_locationText.trim().isNotEmpty) {
      base['location'] = _locationText.trim();
    }
    if (_taggedPeopleText.trim().isNotEmpty) {
      base['taggedPeople'] = _taggedPeopleText.trim();
    }
    if (_customAudioTitle != null && _customAudioTitle!.trim().isNotEmpty) {
      base['audioDisplayTitle'] = _customAudioTitle!.trim();
    }
    base['audience'] = _audience;
    base['aiContentLabel'] = _aiLabelEnabled;
    return base;
  }

  String _audienceLabel() {
    switch (_audience) {
      case 'private':
        return 'Only me';
      case 'followers':
        return 'Followers';
      default:
        return 'Everyone';
    }
  }

  void _showHashtagPicker() {
    const tags = ['#reel', '#fyp', '#music', '#beatjerky', '#trending', '#viral'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add hashtags to your caption',
                  style: TextStyle(
                    color: whiteColor.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((t) {
                    return Material(
                      color: darkCardBackground,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          final c = _descriptionController;
                          final text = c.text;
                          final sep =
                              text.isEmpty || text.endsWith(' ') ? '' : ' ';
                          c.text = '$text$sep$t ';
                          c.selection = TextSelection.fromPosition(
                            TextPosition(offset: c.text.length),
                          );
                          setState(() {});
                          Navigator.pop(ctx);
                          AppToast.show('Hashtag added', isError: false);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: purpleAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTagPeopleDialog() {
    final tc = TextEditingController(text: _taggedPeopleText);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkCardBackground,
        title: const Text(
          'Tag people',
          style: TextStyle(color: whiteColor, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tc,
          style: const TextStyle(color: whiteColor),
          decoration: InputDecoration(
            hintText: '@username or @friend1 @friend2',
            hintStyle: TextStyle(color: whiteColor.withValues(alpha: 0.45)),
            filled: true,
            fillColor: darkBackgroundTertiary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: whiteColor.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () {
              setState(() => _taggedPeopleText = tc.text.trim());
              Navigator.pop(ctx);
              AppToast.show('People tags saved', isError: false);
            },
            child: const Text('Save', style: TextStyle(color: purpleAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog() {
    final tc = TextEditingController(text: _locationText);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkCardBackground,
        title: const Text(
          'Add location',
          style: TextStyle(color: whiteColor, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tc,
          style: const TextStyle(color: whiteColor),
          decoration: InputDecoration(
            hintText: 'City, venue, or place name',
            hintStyle: TextStyle(color: whiteColor.withValues(alpha: 0.45)),
            filled: true,
            fillColor: darkBackgroundTertiary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: whiteColor.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () {
              setState(() => _locationText = tc.text.trim());
              Navigator.pop(ctx);
              AppToast.show('Location saved', isError: false);
            },
            child: const Text('Save', style: TextStyle(color: purpleAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRenameAudioDialog() {
    if (!_hasMusicInEditData) {
      AppToast.show('No song on this reel', isError: true);
      return;
    }
    final tc = TextEditingController(text: _renameAudioSubtitle);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkCardBackground,
        title: const Text(
          'Rename audio',
          style: TextStyle(color: whiteColor, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tc,
          style: const TextStyle(color: whiteColor),
          decoration: InputDecoration(
            hintText: 'Title shown on your reel',
            hintStyle: TextStyle(color: whiteColor.withValues(alpha: 0.45)),
            filled: true,
            fillColor: darkBackgroundTertiary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: whiteColor.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () {
              setState(() => _customAudioTitle = tc.text.trim());
              Navigator.pop(ctx);
              AppToast.show('Audio title saved', isError: false);
            },
            child: const Text('Save', style: TextStyle(color: purpleAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAudiencePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Who can see this reel?',
                  style: TextStyle(
                    color: whiteColor.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.public, color: purpleAccent),
                title: const Text('Everyone', style: TextStyle(color: whiteColor)),
                subtitle: Text(
                  'Anyone on Beat Jerky',
                  style: TextStyle(color: whiteColor.withValues(alpha: 0.55), fontSize: 12),
                ),
                trailing: _audience == 'everyone'
                    ? const Icon(Icons.check, color: purpleAccent)
                    : null,
                onTap: () {
                  setState(() => _audience = 'everyone');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.people_outline, color: purpleAccent),
                title: const Text('Followers', style: TextStyle(color: whiteColor)),
                subtitle: Text(
                  'People who follow you',
                  style: TextStyle(color: whiteColor.withValues(alpha: 0.55), fontSize: 12),
                ),
                trailing: _audience == 'followers'
                    ? const Icon(Icons.check, color: purpleAccent)
                    : null,
                onTap: () {
                  setState(() => _audience = 'followers');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.lock_outline, color: purpleAccent),
                title: const Text('Only me', style: TextStyle(color: whiteColor)),
                subtitle: Text(
                  'Private on your profile',
                  style: TextStyle(color: whiteColor.withValues(alpha: 0.55), fontSize: 12),
                ),
                trailing: _audience == 'private'
                    ? const Icon(Icons.check, color: purpleAccent)
                    : null,
                onTap: () {
                  setState(() => _audience = 'private');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstagramShareScaffold() {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: whiteColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New reel',
          style: TextStyle(color: whiteColor, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInstagramPreviewHero(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: whiteColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: whiteColor.withValues(alpha: 0.45)),
                      filled: true,
                      fillColor: darkBackgroundTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.edit_rounded, color: purpleAccent, size: 22),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: darkCardBackground,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _showHashtagPicker,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tag, size: 18, color: purpleAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Add hashtags',
                                style: TextStyle(
                                  color: whiteColor.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: whiteColor.withValues(alpha: 0.12)),
                  _igSettingsTile(
                    icon: Icons.person_outline,
                    title: 'Tag people',
                    subtitle: _taggedPeopleText.isEmpty ? null : _taggedPeopleText,
                    onTap: _showTagPeopleDialog,
                  ),
                  _igSettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Add location',
                    subtitle: _locationText.isEmpty ? null : _locationText,
                    onTap: _showLocationDialog,
                  ),
                  _igSettingsTile(
                    icon: Icons.music_note_outlined,
                    title: 'Rename audio',
                    subtitle: _renameAudioSubtitle,
                    onTap: _showRenameAudioDialog,
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined, color: purpleAccent),
                    title: const Text('Add AI label', style: TextStyle(color: whiteColor, fontWeight: FontWeight.w500)),
                    subtitle: Text.rich(
                      TextSpan(
                        style: TextStyle(color: whiteColor.withValues(alpha: 0.55), fontSize: 12),
                        children: [
                          const TextSpan(text: 'We require you to label certain realistic content that\'s made with AI. '),
                          TextSpan(text: 'Learn more', style: TextStyle(color: purpleAccent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: _aiLabelEnabled,
                      activeTrackColor: purpleAccent.withValues(alpha: 0.45),
                      activeThumbColor: whiteColor,
                      onChanged: (v) => setState(() => _aiLabelEnabled = v),
                    ),
                  ),
                  Divider(height: 24, color: whiteColor.withValues(alpha: 0.12)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_outlined, color: purpleAccent),
                    title: const Text('Audience', style: TextStyle(color: whiteColor, fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _audienceLabel(),
                          style: TextStyle(color: whiteColor.withValues(alpha: 0.75), fontSize: 15),
                        ),
                        Icon(Icons.chevron_right, color: whiteColor.withValues(alpha: 0.35)),
                      ],
                    ),
                    onTap: _showAudiencePicker,
                  ),
                ],
              ),
            ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: darkBackgroundTertiary,
                color: purpleAccent,
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading
                          ? null
                          : () {
                              Navigator.pop(context);
                              AppToast.show('Draft saved (local preview only)', isError: false);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purpleAccent,
                        side: const BorderSide(color: purpleAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save draft', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadDirect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleAccent,
                        foregroundColor: whiteColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: whiteColor),
                            )
                          : const Text('Share', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _igSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: purpleAccent),
      title: Text(title, style: const TextStyle(color: whiteColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: whiteColor.withValues(alpha: 0.6), fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: whiteColor.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }

  Widget _buildInstagramPreviewHero() {
    const maxH = 380.0;
    const ar = ReelVideoSpec.aspectRatio;
    if (!_videoInitialized || _videoController == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 280,
          color: darkCardBackground,
          child: const Center(child: CircularProgressIndicator(color: purpleAccent)),
        ),
      );
    }
    final c = _videoController!;
    final w = MediaQuery.of(context).size.width - 32;
    final h = (w / ar).clamp(120.0, maxH);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: purpleAccent.withValues(alpha: 0.45), width: 1.5),
        ),
        child: SizedBox(
          height: h,
          width: double.infinity,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _isFullscreen = true),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: c.value.size.width,
                        height: c.value.size.height,
                        child: _wrapVideoWithFilter(VideoPlayer(c)),
                      ),
                    ),
                  ),
                  _buildEditDataOverlays(),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_outlined, color: purpleAccent.withValues(alpha: 0.95), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Tap video for fullscreen',
                                style: TextStyle(color: whiteColor.withValues(alpha: 0.92), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: c.value.isPlaying ? 'Pause' : 'Play',
                            icon: Icon(
                              c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: whiteColor,
                              size: 44,
                            ),
                            onPressed: () {
                              if (c.value.isPlaying) {
                                c.pause();
                              } else {
                                c.play();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _pickCover,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: whiteColor,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Edit cover'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
