import 'dart:async';
import 'dart:io';

import 'package:beatjerky/model/music_track_model.dart';
import 'package:beatjerky/screens/reel_instagram/reel_studio_sheet.dart';
import 'package:beatjerky/screens/reel_preview_upload_screen.dart';
import 'package:beatjerky/utils/reel_color_adjustments.dart';
import 'package:beatjerky/utils/reel_video_spec.dart';
import 'package:beatjerky/utils/reel_ffmpeg_extract.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/widget/music_browser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// Instagram-style full-screen preview after gallery: tool strip + **Next** (all quick edits on this screen).
class ReelIntermediatePreviewScreen extends StatefulWidget {
  final File videoFile;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Future<String?> Function(
    String videoUrl,
    String description, {
    Map<String, dynamic>? editData,
    String? coverUrl,
  })
  saveToFirestore;

  const ReelIntermediatePreviewScreen({
    Key? key,
    required this.videoFile,
    required this.storage,
    required this.auth,
    required this.firestore,
    required this.saveToFirestore,
  }) : super(key: key);

  @override
  State<ReelIntermediatePreviewScreen> createState() =>
      _ReelIntermediatePreviewScreenState();
}

class _ReelIntermediatePreviewScreenState
    extends State<ReelIntermediatePreviewScreen> {
  late File _file;
  VideoPlayerController? _controller;
  AudioPlayer? _musicPlayer;
  Timer? _pauseMusicDelay;

  MusicTrack? _music;
  double _musicVolume = 0.5;
  double _videoVolume = 1.0;
  bool _muteOriginal = false;

  /// Silences the video file's own audio (camera / clip). Song from Music can still play.
  bool _muteRecordedVideo = false;

  bool _flipHorizontal = false;

  /// Color / tone (preview; saved in [editData] for export pipelines).
  double _adjBrightness = 0.0;
  double _adjContrast = 0.0;
  double _adjSaturation = 0.0;
  double _adjWarmth = 0.0;
  double _adjHighlights = 0.0;
  double _adjShadows = 0.0;
  double _adjFade = 0.0;
  double _adjVignette = 0.0;
  double _adjSharpen = 0.0;

  /// Timeline metadata (export / server can interpret).
  final List<double> _splitPointsMs = [];
  final List<List<double>> _deleteRangesMs = [];
  double _deleteRangeStartMs = 0;
  double _deleteRangeEndMs = 0;

  /// none | chipmunk | deep | robot | echo — full processing on export.
  String _voiceEffect = 'none';
  static const List<String> _voiceEffectIds = [
    'none',
    'chipmunk',
    'deep',
    'robot',
    'echo',
  ];

  String? _extractedAudioPath;
  bool _extractingAudio = false;

  String _filter = 'None';
  static const List<String> _filters = [
    'None',
    'Vintage',
    'Warm',
    'Cool',
    'Cinematic',
    'Black & White',
  ];

  String _textOverlay = '';
  Color _textColor = Colors.white;
  double _textSize = 22.0;
  final TextEditingController _textEditController = TextEditingController();
  bool _textPanelOpen = false;

  final List<Map<String, dynamic>> _stickers = [];
  int? _selectedStickerIndex;

  bool _isPaused = false;

  /// FFmpeg re-encode to reel resolution before opening share/preview.
  bool _compressingForPreview = false;
  double _compressProgress = 0;

  /// Trim window (ms). Applied in preview loop and passed in [editData] like [VideoEditorScreen].
  double _trimStartMs = 0;
  double _trimEndMs = 0;
  double _durationMs = 0;
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// On-frame guides (preview only); stored for future use / consistency.
  String _layoutGuide = 'None';
  static const List<String> _layoutOptions = ['None', 'Grid', 'Safe', 'Thirds'];

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

  @override
  void initState() {
    super.initState();
    _file = widget.videoFile;

    _initPlayer();
  }

  Map<String, dynamic> _composedEditData() {
    final out = <String, dynamic>{};
    out['filter'] = _filter;
    out['caption'] = {
      'text': _textOverlay,
      'color': _textColor.toARGB32(),
      'size': _textSize,
      'fontStyle': 'Default',
    };
    out['stickers'] = List<Map<String, dynamic>>.from(_stickers);
    out['muteRecordedVideo'] = _muteRecordedVideo;
    out['flipHorizontal'] = _flipHorizontal;
    out['voiceEffect'] = _voiceEffect;
    out['splitPointsMs'] = List<double>.from(_splitPointsMs);
    out['deleteRangesMs'] = _deleteRangesMs
        .map((e) => {'start': e[0], 'end': e[1]})
        .toList();
    if (_extractedAudioPath != null)
      out['extractedAudioPath'] = _extractedAudioPath;
    out['adjust'] = {
      'brightness': _adjBrightness,
      'contrast': _adjContrast,
      'saturation': _adjSaturation,
      'warmth': _adjWarmth,
      'highlights': _adjHighlights,
      'shadows': _adjShadows,
      'fade': _adjFade,
      'vignette': _adjVignette,
      'sharpen': _adjSharpen,
    };
    if (_music != null) {
      out['music'] = {
        ..._music!.toMap(),
        'id': _music!.id,
        'musicUrl': _music!.audioUrl,
      };
      out['musicVolume'] = _musicVolume;
      out['muteOriginalVideo'] = _muteOriginal;
      out['videoVolume'] = _muteRecordedVideo
          ? 0.0
          : (_muteOriginal ? 0.0 : _videoVolume);
    } else {
      out.remove('music');
      out['muteOriginalVideo'] = false;
      out['videoVolume'] = _muteRecordedVideo ? 0.0 : _videoVolume;
    }
    out['trimStartMs'] = _trimStartMs;
    out['trimEndMs'] = _trimEndMs;
    out['speed'] = _playbackSpeed;
    out['layoutGuide'] = _layoutGuide;
    return out;
  }

  void _clampTrimToDuration() {
    if (_durationMs <= 0) return;
    _trimStartMs = _trimStartMs.clamp(0.0, _durationMs);
    if (_trimEndMs <= 0 || _trimEndMs > _durationMs) _trimEndMs = _durationMs;
    _trimEndMs = _trimEndMs.clamp(_trimStartMs, _durationMs);
    final maxSpan = ReelVideoSpec.maxDurationSeconds * 1000.0;
    if (_trimEndMs - _trimStartMs > maxSpan) {
      _trimEndMs = (_trimStartMs + maxSpan).clamp(0.0, _durationMs);
    }
    if (_trimEndMs - _trimStartMs < 500 && _durationMs >= 500) {
      _trimEndMs = (_trimStartMs + 500).clamp(0.0, _durationMs);
    }
  }

  void _onVideoControllerUpdate() {
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inMilliseconds.toDouble();
    if (_trimEndMs > _trimStartMs + 32 && pos >= _trimEndMs - 24) {
      c.seekTo(Duration(milliseconds: _trimStartMs.toInt()));
      _musicPlayer?.seek(Duration.zero);
    }
    setState(() {});
  }

  void _applyVolumesToVideo() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_muteRecordedVideo) {
      c.setVolume(0);
      return;
    }
    final hasM = _music != null && _music!.audioUrl.trim().isNotEmpty;
    final vol = (hasM && _muteOriginal) ? 0.0 : _videoVolume;
    c.setVolume(vol.clamp(0.0, 1.0));
  }

  Widget _wrapVideoPreviewLayers(Widget videoChild) {
    Widget w = ReelColorAdjustments.wrapChain(
      videoChild,
      brightnessVal: _adjBrightness,
      contrastV: _adjContrast,
      saturationV: _adjSaturation,
      warmthV: _adjWarmth,
      shadows: _adjShadows,
      highlights: _adjHighlights,
      sharpenV: _adjSharpen,
    );
    final cf = _filterMatrix(_filter);
    if (cf != null) {
      w = ColorFiltered(colorFilter: cf, child: w);
    }
    if (_flipHorizontal) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: w,
      );
    }
    return w;
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

  Future<void> _initPlayer() async {
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    final old = _controller;
    if (old != null) {
      old.removeListener(_onVideoControllerUpdate);
      if (_musicPlayer != null) {
        old.removeListener(_syncMusicWithVideo);
      }
      old.dispose();
    }
    _controller = null;
    await _musicPlayer?.dispose();
    _musicPlayer = null;

    final c = VideoPlayerController.file(_file);
    try {
      await c.initialize();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not play video')));
      }
      c.dispose();
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    _controller = c;
    c.setLooping(true);
    _durationMs = c.value.duration.inMilliseconds.toDouble();
    _deleteRangeStartMs = 0;
    _deleteRangeEndMs = _durationMs;
    _clampTrimToDuration();
    try {
      c.setPlaybackSpeed(_playbackSpeed);
    } catch (_) {}
    c.addListener(_onVideoControllerUpdate);
    _applyVolumesToVideo();
    await c.play();
    _isPaused = false;
    await _setupMusicPlayer();
    if (mounted) setState(() {});
  }

  Future<void> _setupMusicPlayer() async {
    await _musicPlayer?.dispose();
    _musicPlayer = null;
    final c = _controller;
    if (c == null || _music == null) return;
    final url = _music!.audioUrl.trim();
    if (!url.startsWith('http')) return;

    _musicPlayer = AudioPlayer(handleAudioSessionActivation: false);
    try {
      await _musicPlayer!.setUrl(url);
      await _musicPlayer!.setLoopMode(LoopMode.one);
      await _musicPlayer!.setVolume(_musicVolume.clamp(0.0, 1.0));
      c.addListener(_syncMusicWithVideo);
      if (c.value.isPlaying) {
        await _musicPlayer!.play();
      }
    } catch (_) {
      await _musicPlayer?.dispose();
      _musicPlayer = null;
    }
  }

  void _syncMusicWithVideo() {
    if (_musicPlayer == null || _controller == null || !mounted) return;
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    if (_controller!.value.isPlaying) {
      _musicPlayer!.play();
    } else {
      if (_isPaused) {
        _musicPlayer!.pause();
      } else {
        _pauseMusicDelay = Timer(const Duration(milliseconds: 600), () {
          _pauseMusicDelay = null;
          if (!mounted || _controller == null || _musicPlayer == null) return;
          if (!_controller!.value.isPlaying && !_isPaused) {
            _musicPlayer!.pause();
          }
        });
      }
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _musicPlayer?.pause();
      _isPaused = true;
    } else {
      c.play();
      _musicPlayer?.play();
      _isPaused = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pauseMusicDelay?.cancel();
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoControllerUpdate);
      if (_musicPlayer != null) {
        c.removeListener(_syncMusicWithVideo);
      }
    }
    _textEditController.dispose();
    _controller?.dispose();
    _musicPlayer?.dispose();
    super.dispose();
  }

  void _disposeDecoder() {
    _pauseMusicDelay?.cancel();
    _pauseMusicDelay = null;
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onVideoControllerUpdate);
      if (_musicPlayer != null) {
        c.removeListener(_syncMusicWithVideo);
      }
      try {
        c.pause();
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }
    _musicPlayer?.dispose();
    _musicPlayer = null;
  }

  Future<void> _goShare() async {
    if (_compressingForPreview) return;
    _clampTrimToDuration();

    setState(() {
      _compressingForPreview = true;
      _compressProgress = 0;
    });

    File? fileToShare;
    try {
      fileToShare = await compressReelVideoForPreview(
        inputPath: _file.path,
        trimStartMs: _trimStartMs,
        trimEndMs: _trimEndMs,
        totalDurationMs: _durationMs,
        onProgress: (p) {
          if (mounted) {
            setState(() => _compressProgress = p.clamp(0.0, 1.0));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppToast.show('Compression failed: $e', isError: true);
      }
    }

    if (!mounted) return;
    setState(() {
      _compressingForPreview = false;
      _compressProgress = 0;
    });

    if (fileToShare == null) {
      if (mounted) {
        AppToast.show('Could not prepare video. Try again.', isError: true);
      }
      return;
    }

    // Trim is baked into the file; keep metadata consistent for upload/feed.
    final span = (_trimEndMs - _trimStartMs).clamp(1.0, double.infinity);
    _trimStartMs = 0;
    _trimEndMs = span;
    _durationMs = span;
    _file = fileToShare;

    _disposeDecoder();
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final postedReelId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => ReelPreviewUploadScreen(
          videoFile: _file,
          editData: _composedEditData(),
          storage: widget.storage,
          auth: widget.auth,
          firestore: widget.firestore,
          saveToFirestore: widget.saveToFirestore,
          instagramLayout: true,
        ),
      ),
    );
    if (mounted && postedReelId != null && postedReelId.isNotEmpty) {
      Navigator.of(context).pop(postedReelId);
      return;
    }
    if (mounted) await _initPlayer();
  }

  Future<void> _openMusicPicker() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) => MusicBrowserScreen(
          onMusicSelected: (track) async {
            setState(() => _music = track);
            await _setupMusicPlayer();
            _applyVolumesToVideo();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _onToolTap(int index) {
    switch (index) {
      case 0:
        _textEditController.text = _textOverlay;
        setState(() => _textPanelOpen = true);
        break;
      case 1:
        _showStickerSheet();
        break;
      case 2:
        _showMusicSheet();
        break;
      case 3:
        _showSoundSheet();
        break;
      case 4:
        _openStudio(0);
        break;
      case 5:
        _showSegmentSpeedSheet(title: 'Trim & clip');
        break;
      case 6:
        _showLayoutSheet();
        break;
      case 7:
        _showEffectsSheet();
        break;
      default:
        break;
    }
  }

  void _closeTextPanel({bool save = true}) {
    if (save) {
      _textOverlay = _textEditController.text;
    } else {
      _textEditController.text = _textOverlay;
    }
    FocusScope.of(context).unfocus();
    setState(() => _textPanelOpen = false);
  }

  /// Text controls sit **above** the tool strip (in front of the video), not in a modal route.
  Widget _buildTextEditPanel() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: darkCardBackground.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Text on video',
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 22,
                    ),
                    onPressed: () => _closeTextPanel(save: false),
                  ),
                  TextButton(
                    onPressed: () => _closeTextPanel(save: true),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: purpleAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Type below — size and colors apply on the video above.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textEditController,
                autofocus: true,
                style: TextStyle(color: _textColor, fontSize: 16),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add text…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Size',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Expanded(
                    child: Slider(
                      value: _textSize.clamp(14.0, 42.0),
                      min: 14,
                      max: 42,
                      activeColor: purpleAccent,
                      onChanged: (v) => setState(() => _textSize = v),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      Colors.white,
                      Colors.black,
                      purpleAccent,
                      Colors.yellowAccent,
                      Colors.redAccent,
                      Colors.greenAccent,
                    ].map((col) {
                      final sel = _sameColor(_textColor, col);
                      return GestureDetector(
                        onTap: () => setState(() => _textColor = col),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.white24,
                              width: sel ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

  void _showStickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Stickers',
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_stickers.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _stickers.clear();
                            _selectedStickerIndex = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to add. Drag on the video to move. Long-press a sticker to remove.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _stickerEmojis.length,
                    itemBuilder: (_, i) {
                      final e = _stickerEmojis[i];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _stickers.add({
                              'emoji': e,
                              'x': 0.5,
                              'y': 0.45,
                              'scale': 1.0,
                            });
                            _selectedStickerIndex = _stickers.length - 1;
                          });
                        },
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pick a song only. **Audio** tool controls volume, mute, and mix.
  void _showMusicSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Music',
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: purpleAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a song to play over your reel. Open Audio in the toolbar to mute the video or mix song and original sound.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tip: tap Audio for volume and mute.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 4),
                if (_music != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.library_music,
                      color: Colors.white70,
                    ),
                    title: Text(
                      _music!.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _music!.artist,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _openMusicPicker();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  icon: const Icon(Icons.search),
                  label: Text(_music == null ? 'Choose sound' : 'Change sound'),
                ),
                if (_music != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _music = null);
                      _musicPlayer?.dispose();
                      _musicPlayer = null;
                      final c = _controller;
                      if (c != null) {
                        c.removeListener(_syncMusicWithVideo);
                      }
                      _applyVolumesToVideo();
                    },
                    child: const Text(
                      'Remove music',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Volume, mute recorded video, and mix when a song is added.
  void _showSoundSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(context).size.height * 0.88;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Audio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  color: purpleAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Control what you hear in the preview.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Recorded video',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Mute original video sound',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          subtitle: Text(
                            'Turns off audio from your clip (camera / file).',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                          value: _muteRecordedVideo,
                          activeThumbColor: purpleAccent,
                          onChanged: (v) {
                            setModal(() {});
                            setState(() => _muteRecordedVideo = v);
                            _applyVolumesToVideo();
                          },
                        ),
                        if (!_muteRecordedVideo) ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Original volume',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Slider(
                                  value: _videoVolume.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    setModal(() {});
                                    setState(() => _videoVolume = v);
                                    _applyVolumesToVideo();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_music != null) ...[
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 4),
                          const Text(
                            'Song',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.music_note,
                              color: Colors.white70,
                            ),
                            title: Text(
                              _music!.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _music!.artist,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Song volume',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Slider(
                                  value: _musicVolume.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    setModal(() {});
                                    setState(() => _musicVolume = v);
                                    _musicPlayer?.setVolume(v.clamp(0.0, 1.0));
                                  },
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Mute original when song plays',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              'Keeps only the song; hides the video’s recorded sound.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                              ),
                            ),
                            value: _muteOriginal,
                            activeThumbColor: purpleAccent,
                            onChanged: (v) {
                              setModal(() {});
                              setState(() => _muteOriginal = v);
                              _applyVolumesToVideo();
                            },
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Add a song from Music to mix song and original audio.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openStudio(int initialTab) {
    if (_durationMs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the video to load.')),
      );
      return;
    }
    _deleteRangeEndMs = _deleteRangeEndMs.clamp(0.0, _durationMs);
    _deleteRangeStartMs = _deleteRangeStartMs.clamp(0.0, _durationMs);
    showReelStudioBottomSheet(
      context,
      initialTab: initialTab,
      clipTab: _buildStudioClipTab(),
      audioTab: _buildStudioAudioTab(),
      colorTab: _buildStudioColorTab(),
      effectsTab: _buildStudioEffectsTab(),
    );
  }

  Future<void> _replaceVideoFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    if (r == null || r.files.isEmpty || r.files.single.path == null) return;
    setState(() => _file = File(r.files.single.path!));
    await _initPlayer();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video replaced')));
    }
  }

  void _splitAtPlayhead() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final p = c.value.position.inMilliseconds.toDouble();
    setState(() => _splitPointsMs.add(p));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Split marker at ${_formatTimeMs(p)}')),
    );
  }

  void _addDeleteRange() {
    if (_deleteRangeEndMs <= _deleteRangeStartMs + 100) return;
    setState(() {
      _deleteRangesMs.add([_deleteRangeStartMs, _deleteRangeEndMs]);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete range added (export)')),
    );
  }

  Future<void> _extractAudioToM4a() async {
    if (_extractingAudio) return;
    setState(() => _extractingAudio = true);
    try {
      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/reel_extract_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      final ok = await extractReelVideoAudioToM4a(
        videoPath: _file.path,
        outPath: out.path,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _extractedAudioPath = out.path);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(out.path)], text: 'Extracted audio'),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved: ${out.path}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not extract audio')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Extract error: $e')));
      }
    } finally {
      if (mounted) setState(() => _extractingAudio = false);
    }
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    int? divisions,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioClipTab() {
    return StatefulBuilder(
      builder: (context, setModal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Trim the playable range, set speed, mark splits, or swap the file.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Future<void>.delayed(Duration.zero, () {
                  if (mounted) _showSegmentSpeedSheet(title: 'Trim & clip');
                });
              },
              icon: const Icon(
                Icons.movie_filter_outlined,
                color: Colors.white70,
              ),
              label: const Text('Trim, speed & range'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _splitAtPlayhead();
                setModal(() {});
              },
              icon: const Icon(Icons.call_split, size: 20),
              label: const Text('Split at playhead'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                foregroundColor: Colors.white,
              ),
            ),
            if (_splitPointsMs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Markers: ${_splitPointsMs.map((x) => _formatTimeMs(x)).join(", ")}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            const Divider(color: Colors.white24, height: 24),
            const Text(
              'Remove a section (for export)',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            RangeSlider(
              values: RangeValues(
                (_deleteRangeStartMs / _durationMs).clamp(0.0, 1.0),
                (_deleteRangeEndMs / _durationMs).clamp(0.0, 1.0),
              ),
              min: 0,
              max: 1,
              onChanged: (rv) {
                setState(() {
                  _deleteRangeStartMs = rv.start * _durationMs;
                  _deleteRangeEndMs = rv.end * _durationMs;
                });
                setModal(() {});
              },
            ),
            Text(
              '${_formatTimeMs(_deleteRangeStartMs)} – ${_formatTimeMs(_deleteRangeEndMs)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            TextButton.icon(
              onPressed: () {
                _addDeleteRange();
                setModal(() {});
              },
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.orangeAccent,
              ),
              label: const Text('Add this range to delete list'),
            ),
            ..._deleteRangesMs.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return ListTile(
                dense: true,
                title: Text(
                  'Delete ${_formatTimeMs(r[0])} – ${_formatTimeMs(r[1])}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _deleteRangesMs.removeAt(i));
                    setModal(() {});
                  },
                ),
              );
            }),
            const Divider(color: Colors.white24, height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await _replaceVideoFile();
                setModal(() {});
              },
              icon: const Icon(
                Icons.video_library_outlined,
                color: Colors.white70,
              ),
              label: const Text('Replace with another video'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudioAudioTab() {
    return StatefulBuilder(
      builder: (context, setModal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Mute original sound is on the main screen. Here: voice style (export) and extract audio.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Voice style (preview label; full effect on export)',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _voiceEffectIds.map((id) {
                final sel = _voiceEffect == id;
                final label = id == 'none'
                    ? 'None'
                    : '${id[0].toUpperCase()}${id.substring(1)}';
                return _reelSelectableChip(
                  label: label,
                  selected: sel,
                  onTap: () {
                    setState(() => _voiceEffect = id);
                    setModal(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _extractingAudio
                  ? null
                  : () async {
                      await _extractAudioToM4a();
                      setModal(() {});
                    },
              icon: _extractingAudio
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.audio_file_outlined),
              label: Text(
                _extractingAudio
                    ? 'Extracting…'
                    : 'Extract audio to file (AAC)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                foregroundColor: Colors.white,
              ),
            ),
            if (_extractedAudioPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Last extract: $_extractedAudioPath',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStudioColorTab() {
    return StatefulBuilder(
      builder: (context, setModal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tune the picture. Preview updates on the video.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _sliderRow('Brightness', _adjBrightness, -1, 1, 40, (v) {
              setState(() => _adjBrightness = v);
              setModal(() {});
            }),
            _sliderRow('Contrast', _adjContrast, -1, 1, 40, (v) {
              setState(() => _adjContrast = v);
              setModal(() {});
            }),
            _sliderRow('Saturation', _adjSaturation, -1, 1, 40, (v) {
              setState(() => _adjSaturation = v);
              setModal(() {});
            }),
            _sliderRow('Warmth', _adjWarmth, -1, 1, 40, (v) {
              setState(() => _adjWarmth = v);
              setModal(() {});
            }),
            _sliderRow('Highlights', _adjHighlights, -1, 1, 40, (v) {
              setState(() => _adjHighlights = v);
              setModal(() {});
            }),
            _sliderRow('Shadows', _adjShadows, -1, 1, 40, (v) {
              setState(() => _adjShadows = v);
              setModal(() {});
            }),
            _sliderRow('Fade to black', _adjFade, 0, 1, 20, (v) {
              setState(() => _adjFade = v);
              setModal(() {});
            }),
            _sliderRow('Vignette', _adjVignette, 0, 1, 20, (v) {
              setState(() => _adjVignette = v);
              setModal(() {});
            }),
            _sliderRow('Sharpen', _adjSharpen, 0, 1, 20, (v) {
              setState(() => _adjSharpen = v);
              setModal(() {});
            }),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Mirror (flip horizontal)',
                style: TextStyle(color: Colors.white),
              ),
              value: _flipHorizontal,
              activeThumbColor: purpleAccent,
              onChanged: (v) {
                setState(() => _flipHorizontal = v);
                setModal(() {});
              },
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _adjBrightness = 0;
                  _adjContrast = 0;
                  _adjSaturation = 0;
                  _adjWarmth = 0;
                  _adjHighlights = 0;
                  _adjShadows = 0;
                  _adjFade = 0;
                  _adjVignette = 0;
                  _adjSharpen = 0;
                  _flipHorizontal = false;
                });
                setModal(() {});
              },
              child: const Text('Reset color & mirror'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudioEffectsTab() {
    return StatefulBuilder(
      builder: (context, setModal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Looks & film filters.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _filters.map((f) {
                final sel = _filter == f;
                return _reelSelectableChip(
                  label: f,
                  selected: sel,
                  onTap: () {
                    setState(() => _filter = f);
                    setModal(() {});
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeMs(double ms) {
    final d = Duration(milliseconds: ms.clamp(0, double.infinity).round());
    final two = (int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${two(m)}:${two(s)}';
  }

  /// Trim segment + playback speed — same panel for **Clip** and **Trim** tools.
  void _showSegmentSpeedSheet({required String title}) {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _durationMs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the video to finish loading.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(context).size.height * 0.58;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setModal) {
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  color: purpleAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Selected: ${_formatTimeMs(_trimStartMs)} – ${_formatTimeMs(_trimEndMs)} '
                          '(${_formatTimeMs(_trimEndMs - _trimStartMs)} · max ${ReelVideoSpec.maxDurationSeconds}s)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RangeSlider(
                          values: RangeValues(
                            (_trimStartMs / _durationMs).clamp(0.0, 1.0),
                            (_trimEndMs / _durationMs).clamp(0.0, 1.0),
                          ),
                          min: 0,
                          max: 1,
                          labels: RangeLabels(
                            _formatTimeMs(_trimStartMs),
                            _formatTimeMs(_trimEndMs),
                          ),
                          onChanged: (rv) {
                            var start = rv.start * _durationMs;
                            var end = rv.end * _durationMs;
                            final maxSpan =
                                ReelVideoSpec.maxDurationSeconds * 1000.0;
                            if (end - start > maxSpan) {
                              end = start + maxSpan;
                            }
                            if (end - start < 500) {
                              if (start + 500 <= _durationMs) {
                                end = start + 500;
                              } else {
                                start = (end - 500).clamp(0.0, _durationMs);
                              }
                            }
                            setState(() {
                              _trimStartMs = start.clamp(0.0, _durationMs);
                              _trimEndMs = end.clamp(_trimStartMs, _durationMs);
                            });
                            setModal(() {});
                            _controller?.seekTo(
                              Duration(milliseconds: _trimStartMs.toInt()),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Speed',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: _speedOptions.map((s) {
                            final sel = _playbackSpeed == s;
                            return _reelSelectableChip(
                              label: '${s}x',
                              selected: sel,
                              onTap: () async {
                                setState(() => _playbackSpeed = s);
                                setModal(() {});
                                try {
                                  await _controller?.setPlaybackSpeed(s);
                                } catch (_) {}
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            _controller?.seekTo(
                              Duration(milliseconds: _trimStartMs.toInt()),
                            );
                            _musicPlayer?.seek(Duration.zero);
                          },
                          icon: const Icon(
                            Icons.replay,
                            color: Colors.white70,
                            size: 18,
                          ),
                          label: const Text('Jump to clip start'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showLayoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Layout guides',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: purpleAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Helps you align text and stickers. Guides are preview-only on this screen.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _layoutOptions.map((opt) {
                    final sel = _layoutGuide == opt;
                    return _reelSelectableChip(
                      label: opt,
                      selected: sel,
                      onTap: () {
                        setState(() => _layoutGuide = opt);
                        Navigator.pop(ctx);
                      },
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

  void _showEffectsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Effects',
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: purpleAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview updates on the video behind this sheet.',
                  style: TextStyle(
                    color: whiteColor.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _filters.map((f) {
                    final sel = _filter == f;
                    return _reelSelectableChip(
                      label: f,
                      selected: sel,
                      onTap: () {
                        setState(() => _filter = f);
                        Navigator.pop(ctx);
                      },
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

  /// Dark card + light text so filter names stay readable on any system theme.
  Widget _reelSelectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? purpleAccent.withValues(alpha: 0.38)
                : darkCardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? purpleAccent
                  : whiteColor.withValues(alpha: 0.22),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: whiteColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayCaptionText() {
    final t = _textPanelOpen ? _textEditController.text : _textOverlay;
    return Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _textColor,
        fontSize: _textSize,
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
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(_stickers.length, (index) {
            final s = _stickers[index];
            final emoji = s['emoji'] as String? ?? '❤️';
            final x = (s['x'] as num?)?.toDouble() ?? 0.5;
            final y = (s['y'] as num?)?.toDouble() ?? 0.5;
            final scale = (s['scale'] as num?)?.toDouble() ?? 1.0;
            final base = 40.0 * scale;
            final sel = _selectedStickerIndex == index;
            return Positioned(
              left: x * w - base / 2,
              top: y * h - base / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedStickerIndex = index),
                onLongPress: () => setState(() {
                  _stickers.removeAt(index);
                  _selectedStickerIndex = null;
                }),
                onPanUpdate: (d) {
                  setState(() {
                    final cx = (s['x'] as num?)?.toDouble() ?? 0.5;
                    final cy = (s['y'] as num?)?.toDouble() ?? 0.5;
                    s['x'] = (cx + d.delta.dx / w).clamp(0.05, 0.95);
                    s['y'] = (cy + d.delta.dy / h).clamp(0.05, 0.95);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: sel ? purpleAccent : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_textPanelOpen) {
                      FocusScope.of(context).unfocus();
                      return;
                    }
                    _togglePlayPause();
                  },
                  child: Opacity(
                    opacity: (1.0 - _adjFade).clamp(0.04, 1.0),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: _wrapVideoPreviewLayers(
                          VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_layoutGuide != 'None')
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ReelLayoutGuidePainter(_layoutGuide),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: ReelVignetteOverlay(amount: _adjVignette),
                ),
                if (_textPanelOpen || _textOverlay.trim().isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: const Alignment(0, 0.15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _buildOverlayCaptionText(),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(child: _buildStickerOverlay()),
                if (_filter != 'None')
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 52,
                    left: 14,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: purpleAccent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: purpleAccent.withValues(alpha: 0.95),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _filter,
                              style: const TextStyle(
                                color: whiteColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_music != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    child: IgnorePointer(
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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                _music!.title,
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
                  ),
              ],
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: whiteColor, size: 22),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Material(
                    color: purpleAccent,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: _goShare,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Next',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: whiteColor,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: whiteColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: bottom + 16,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                    (_textPanelOpen ? 0.68 : 0.52),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_textPanelOpen) ...[
                      _buildTextEditPanel(),
                      const SizedBox(height: 8),
                    ],
                    _buildToolsHint(),
                    const SizedBox(height: 6),
                    // _buildQuickMuteRow(),
                    const SizedBox(height: 8),
                    Center(
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        color: whiteColor.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _toolStrip(),
                  ],
                ),
              ),
            ),
          ),
          if (_compressingForPreview)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.78),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: purpleAccent,
                            value: _compressProgress > 0 && _compressProgress < 1
                                ? _compressProgress
                                : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Compressing video…',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _compressProgress > 0 && _compressProgress < 1
                              ? '${(_compressProgress * 100).round()}%'
                              : 'Please wait',
                          style: TextStyle(
                            color: whiteColor.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolsHint() {
    return Text(
      'Text, stickers, and effects appear on the video. Tap Next (top right) when ready.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: whiteColor.withValues(alpha: 0.88),
        fontSize: 12,
        height: 1.3,
      ),
    );
  }

  static const List<IconData> _toolIcons = [
    Icons.text_fields,
    Icons.emoji_emotions_outlined,
    Icons.library_music_outlined,
    Icons.graphic_eq,
    Icons.dashboard_customize_outlined,
    Icons.content_cut,
    Icons.grid_view,
    Icons.auto_awesome,
  ];

  static const List<String> _toolLabels = [
    'Text',
    'Stickers',
    'Music',
    'Audio',
    'Studio',
    'Trim',
    'Layout',
    'Effects',
  ];

  Widget _toolStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: darkBackgroundSecondary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purpleAccent.withValues(alpha: 0.25)),
      ),
      child: SizedBox(
        height: 88,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_toolIcons.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onToolTap(i),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 66,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _toolIcons[i],
                            color: purpleAccent.withValues(alpha: 0.95),
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _toolLabels[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: whiteColor.withValues(alpha: 0.92),
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Preview-only frame guides for the intermediate reel screen.
class _ReelLayoutGuidePainter extends CustomPainter {
  _ReelLayoutGuidePainter(this.guide);
  final String guide;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    switch (guide) {
      case 'Grid':
        for (var i = 1; i < 3; i++) {
          final x = size.width * i / 3;
          final y = size.height * i / 3;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 'Safe':
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.07,
            size.height * 0.08,
            size.width * 0.86,
            size.height * 0.72,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(r, paint);
        break;
      case 'Thirds':
        canvas.drawLine(
          Offset(size.width / 3, 0),
          Offset(size.width / 3, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(2 * size.width / 3, 0),
          Offset(2 * size.width / 3, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height / 3),
          Offset(size.width, size.height / 3),
          paint,
        );
        canvas.drawLine(
          Offset(0, 2 * size.height / 3),
          Offset(size.width, 2 * size.height / 3),
          paint,
        );
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ReelLayoutGuidePainter old) =>
      old.guide != guide;
}
