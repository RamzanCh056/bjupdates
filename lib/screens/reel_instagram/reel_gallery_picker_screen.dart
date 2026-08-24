import 'dart:io';
import 'dart:typed_data';

import 'package:beatjerky/screens/reel_instagram/reel_intermediate_preview_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/reel_video_spec.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

/// Instagram-style "New post" media picker: dark UI, grid, RECENT gallery, **Reel** mode default.
class ReelGalleryPickerScreen extends StatefulWidget {
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Future<String?> Function(
    String videoUrl,
    String description, {
    Map<String, dynamic>? editData,
    String? coverUrl,
  }) saveToFirestore;

  const ReelGalleryPickerScreen({
    Key? key,
    required this.storage,
    required this.auth,
    required this.firestore,
    required this.saveToFirestore,
  }) : super(key: key);

  @override
  State<ReelGalleryPickerScreen> createState() => _ReelGalleryPickerScreenState();
}

enum _CreateMode { reel }

class _ReelGalleryPickerScreenState extends State<ReelGalleryPickerScreen> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List?> _thumbCache = {};

  bool _loading = true;
  bool _permissionDenied = false;
  List<AssetEntity> _assets = [];
  AssetEntity? _selectedAsset;
  File? _previewFile;
  VideoPlayerController? _previewController;
  _CreateMode _mode = _CreateMode.reel;

  static const Color _igBlue = Color(0xFF0095F6);

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!ps.isAuth) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }

    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        hasAll: true,
        onlyAll: false,
      );
      if (paths.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final recent = paths.first;
      final count = await recent.assetCountAsync;
      final n = count > 120 ? 120 : count;
      final list = await recent.getAssetListPaged(page: 0, size: n);
      if (!mounted) return;
      setState(() {
        _assets = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.show('Could not load gallery: $e', isError: true);
      }
    }
  }

  Future<void> _setPreviewFromAsset(AssetEntity? entity) async {
    _previewController?.dispose();
    _previewController = null;
    _previewFile = null;
    if (entity == null) {
      if (mounted) setState(() {});
      return;
    }
    final f = await entity.originFile;
    if (f == null || !await f.exists()) {
      AppToast.show('Could not open this video', isError: true);
      return;
    }
    final stat = await f.stat();
    if (!ReelVideoSpec.isWithinFileSize(stat.size)) {
      AppToast.show(
        'Video too large (max ${ReelVideoSpec.maxFileSizeBytes ~/ (1024 * 1024)} MB)',
        isError: true,
      );
      return;
    }
    final ext = f.path.toLowerCase().split('.').last;
    if (!ReelVideoSpec.isSupportedFormat(ext)) {
      AppToast.show(
        'Use ${ReelVideoSpec.supportedFormats.join(" or ").toUpperCase()} only',
        isError: true,
      );
      return;
    }
    final c = VideoPlayerController.file(f);
    await c.initialize();
    if (!mounted) {
      c.dispose();
      return;
    }
    _previewFile = f;
    _selectedAsset = entity;
    _previewController = c;
    c.setLooping(true);
    c.play();
    setState(() {});
  }

  Future<void> _openCamera() async {
    try {
      final x = await _picker.pickVideo(source: ImageSource.camera);
      if (x == null) return;
      final f = File(x.path);
      if (!await f.exists()) return;
      final stat = await f.stat();
      if (!ReelVideoSpec.isWithinFileSize(stat.size)) {
        AppToast.show('Video too large', isError: true);
        return;
      }
      await _setPreviewFromFile(f);
    } catch (e) {
      AppToast.show('Camera error: $e', isError: true);
    }
  }

  Future<void> _setPreviewFromFile(File f) async {
    _previewController?.dispose();
    _previewController = null;
    _selectedAsset = null;
    final c = VideoPlayerController.file(f);
    await c.initialize();
    if (!mounted) {
      c.dispose();
      return;
    }
    _previewFile = f;
    _previewController = c;
    c.setLooping(true);
    c.play();
    setState(() {});
  }

  Future<Uint8List?> _thumb(AssetEntity e) async {
    final id = e.id;
    if (_thumbCache.containsKey(id)) return _thumbCache[id];
    final b = await e.thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 80);
    _thumbCache[id] = b;
    return b;
  }

  void _onModeTap(_CreateMode m) {
    setState(() => _mode = m);
  }

  /// Fully release the preview decoder *before* opening the next screen. Stacking two
  /// [VideoPlayer]s triggers Android MediaCodec JNI crashes (BufferInfo / ImageReader).
  void _disposePreviewDecoder() {
    final c = _previewController;
    _previewController = null;
    if (c != null) {
      try {
        c.pause();
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _goNext() async {
    final f = _previewFile;
    if (f == null) return;
    _disposePreviewDecoder();
    if (mounted) setState(() {});
    // Let native ExoPlayer / MediaCodec release before the next route creates another decoder.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final postedReelId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => ReelIntermediatePreviewScreen(
          videoFile: f,
          storage: widget.storage,
          auth: widget.auth,
          firestore: widget.firestore,
          saveToFirestore: widget.saveToFirestore,
        ),
      ),
    );
    if (mounted && postedReelId != null && postedReelId.isNotEmpty) {
      Navigator.of(context).pop(postedReelId);
      return;
    }
    // Restore preview if user pops back from the intermediate screen.
    if (mounted && _previewFile != null && _previewFile!.existsSync()) {
      await _setPreviewFromFile(_previewFile!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'New Reel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _previewFile != null ? () => _goNext() : null,
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: _previewFile != null ? _igBlue : Colors.white24,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const horizontalInset = 32.0;
                  final innerW = (constraints.maxWidth - horizontalInset * 2).clamp(0.0, double.infinity);
                  final ar = ReelVideoSpec.aspectRatio;
                  double previewH = innerW / ar;
                  double previewW = innerW;
                  if (previewH > constraints.maxHeight) {
                    previewH = constraints.maxHeight;
                    previewW = previewH * ar;
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: Container(
                          color: Colors.grey[900],
                          child: _permissionDenied
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Photo library access is needed to pick a reel.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        const SizedBox(height: 16),
                                        TextButton(
                                          onPressed: () async {
                                            await PhotoManager.openSetting();
                                          },
                                          child: const Text('Open settings', style: TextStyle(color: _igBlue)),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _previewController != null && _previewController!.value.isInitialized
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: GestureDetector(
                                        onTap: () {
                                          final c = _previewController!;
                                          if (c.value.isPlaying) {
                                            c.pause();
                                          } else {
                                            c.play();
                                          }
                                          setState(() {});
                                        },
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.cover,
                                              child: SizedBox(
                                                width: _previewController!.value.size.width,
                                                height: _previewController!.value.size.height,
                                                child: VideoPlayer(_previewController!),
                                              ),
                                            ),
                                            Center(
                                              child: Icon(
                                                _previewController!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                                color: Colors.white54,
                                                size: 56,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : _loading
                                      ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                                      : const Center(
                                          child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 64),
                                        ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                    label: const Text('Recents', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => AppToast.show('Drafts coming soon', isError: false),
                    child: const Text('Drafts', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, color: Colors.white70),
                    onPressed: () => AppToast.show('Multi-select coming soon', isError: false),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: _loading && !_permissionDenied
                  ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        childAspectRatio: 1,
                      ),
                      itemCount: 1 + _assets.length,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return GestureDetector(
                            onTap: _openCamera,
                            child: Container(
                              color: Colors.grey[850],
                              child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 40),
                            ),
                          );
                        }
                        final asset = _assets[i - 1];
                        final isSel = _selectedAsset?.id == asset.id;
                        return GestureDetector(
                          onTap: () => _setPreviewFromAsset(asset),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: _thumb(asset),
                                builder: (context, snap) {
                                  if (snap.data == null) {
                                    return Container(color: Colors.grey[850]);
                                  }
                                  return Image.memory(snap.data!, fit: BoxFit.cover);
                                },
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Text(
                                  _formatDurSec(asset.duration),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (isSel)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            _buildModeBar(),
          ],
        ),
      ),
    );
  }

  /// [seconds] from AssetEntity.duration (photo_manager).
  String _formatDurSec(int seconds) {
    final m = seconds ~/ 60;
    final r = seconds % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _buildModeBar() {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeChip('Reel', _CreateMode.reel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, _CreateMode m) {
    final sel = _mode == m;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => _onModeTap(m),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
