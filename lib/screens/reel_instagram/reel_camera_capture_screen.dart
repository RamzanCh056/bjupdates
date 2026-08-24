import 'dart:async';
import 'dart:io';

import 'package:beatjerky/screens/reel_instagram/reel_gallery_picker_screen.dart';
import 'package:beatjerky/screens/reel_instagram/reel_intermediate_preview_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/reel_video_spec.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void _reelCameraLog(String message) {
  if (kDebugMode) {
    debugPrint('[ReelCamera] $message');
  }
}

/// Instagram-style reel capture: **live camera preview** on this route, gallery bottom-left,
/// hold-to-record shutter, flip camera, mode strip (Reel default).
class ReelCameraCaptureScreen extends StatefulWidget {
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

  const ReelCameraCaptureScreen({
    Key? key,
    required this.storage,
    required this.auth,
    required this.firestore,
    required this.saveToFirestore,
  }) : super(key: key);

  @override
  State<ReelCameraCaptureScreen> createState() =>
      _ReelCameraCaptureScreenState();
}

class _ReelCameraCaptureScreenState extends State<ReelCameraCaptureScreen>
    with WidgetsBindingObserver {
  static const List<_PreviewFilter> _filters = [
    _PreviewFilter(
      name: 'Original',
      colors: [Color(0xFF3A3A3A), Color(0xFF1F1F1F)],
    ),
    _PreviewFilter(
      name: 'Warm',
      matrix: _warmMatrix,
      colors: [Color(0xFFFFA94D), Color(0xFF8B3D00)],
    ),
    _PreviewFilter(
      name: 'Cool',
      matrix: _coolMatrix,
      colors: [Color(0xFF4DABF7), Color(0xFF1C4E80)],
    ),
    _PreviewFilter(
      name: 'B&W',
      matrix: _bwMatrix,
      colors: [Color(0xFFADB5BD), Color(0xFF495057)],
    ),
    _PreviewFilter(
      name: 'Vivid',
      matrix: _vividMatrix,
      colors: [Color(0xFFFF6B6B), Color(0xFF6A00F4)],
    ),
    _PreviewFilter(
      name: 'Fade',
      matrix: _fadeMatrix,
      colors: [Color(0xFFF8C4B4), Color(0xFFB7A7C7)],
    ),
    _PreviewFilter(
      name: 'Cinema',
      matrix: _cinemaMatrix,
      colors: [Color(0xFF374151), Color(0xFF111827)],
    ),
  ];

  static const List<double> _warmMatrix = <double>[
    1.06,
    0,
    0,
    0,
    6,
    0,
    1.0,
    0,
    0,
    2,
    0,
    0,
    0.92,
    0,
    -4,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _coolMatrix = <double>[
    0.92,
    0,
    0,
    0,
    -4,
    0,
    1.0,
    0,
    0,
    1,
    0,
    0,
    1.08,
    0,
    8,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _bwMatrix = <double>[
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
  ];
  static const List<double> _vividMatrix = <double>[
    1.15,
    0,
    0,
    0,
    0,
    0,
    1.15,
    0,
    0,
    0,
    0,
    0,
    1.15,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _fadeMatrix = <double>[
    0.92,
    0,
    0,
    0,
    12,
    0,
    0.92,
    0,
    0,
    12,
    0,
    0,
    0.92,
    0,
    12,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _cinemaMatrix = <double>[
    1.08,
    -0.02,
    -0.02,
    0,
    0,
    -0.02,
    1.02,
    -0.02,
    0,
    0,
    -0.02,
    -0.02,
    1.1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  bool _initializing = true;
  String? _initError;

  bool _busy = false;

  /// Updates recording duration label while capturing.
  Timer? _recordingUiTimer;
  Timer? _pendingPauseTimer;
  DateTime? _recordingSegmentStartedAt;
  DateTime? _lastResumeAt;
  Duration _recordedDuration = Duration.zero;

  /// Hold-to-record + optional countdown (0 = none, 3 or 10 seconds).
  bool _shutterHeld = false;
  int _countdownGeneration = 0;
  bool _showCountdownOverlay = false;
  int _countdownShow = 0;
  int _timerDelaySec = 0; // cycles: 0, 3, 10

  bool _showAlignmentGrid = false;
  double _zoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  File? _draftRecordedFile;

  static const List<String> _modes = ['Reel'];
  int _modeIndex = 0; // Reel
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _reelCameraLog('screen opened');
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    _reelCameraLog('dispose');
    WidgetsBinding.instance.removeObserver(this);
    _recordingUiTimer?.cancel();
    _pendingPauseTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _reelCameraLog('app lifecycle: $state');
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_controller?.value.isRecordingVideo == true) {
        _reelCameraLog('pausing — stopping recording');
        unawaited(_stopRecording());
      }
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _initError = null;
    });

    _reelCameraLog('requesting camera permission…');
    final cam = await Permission.camera.request();
    _reelCameraLog('camera permission: $cam');
    if (!cam.isGranted) {
      _reelCameraLog('camera permission denied');
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = 'Camera permission is required to record.';
        });
      }
      return;
    }

    final mic = await Permission.microphone.request();
    _reelCameraLog('microphone permission: $mic');

    try {
      _cameras = await availableCameras();
      _reelCameraLog('availableCameras: ${_cameras.length}');
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _initError = 'No camera found on this device.';
          });
        }
        return;
      }

      final backIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = backIdx >= 0 ? backIdx : 0;
      await _attachCamera(_cameraIndex);
    } catch (e, st) {
      _reelCameraLog('init error: $e\n$st');
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _attachCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return;

    await _controller?.dispose();
    _controller = null;

    final micOk = await Permission.microphone.isGranted;
    _reelCameraLog(
      'attach camera index=$index lens=${_cameras[index].lensDirection} enableAudio=$micOk',
    );

    final c = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: micOk,
    );

    _cameraIndex = index;

    try {
      await c.initialize();
      await c.prepareForVideoRecording();
      _reelCameraLog(
        'camera ready aspectRatio=${c.value.aspectRatio} previewSize=${c.value.previewSize}',
      );
      if (!mounted) {
        await c.dispose();
        return;
      }
      _controller = c;
      _zoomLevel = 1.0;
      try {
        final zMax = await c.getMaxZoomLevel();
        if (mounted) {
          setState(() {
            _maxZoomLevel = zMax.clamp(1.0, 100.0);
          });
        }
        await c.setZoomLevel(1.0);
      } catch (_) {
        if (mounted) setState(() => _maxZoomLevel = 1.0);
      }
      setState(() {
        _initializing = false;
        _initError = null;
      });
    } catch (e, st) {
      _reelCameraLog('attachCamera error: $e\n$st');
      await c.dispose();
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _flipCamera() async {
    if (_busy) return;
    if (_controller?.value.isRecordingVideo == true) return;
    if (_cameras.length < 2) {
      AppToast.show('Only one camera available', isError: false);
      return;
    }
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() => _busy = true);
    try {
      await _attachCamera(next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _beginRecordingClock() {
    _recordingSegmentStartedAt = DateTime.now();
    _lastResumeAt = _recordingSegmentStartedAt;
    _recordingUiTimer?.cancel();
    _recordingUiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final c = _controller;
      if (c != null &&
          c.value.isRecordingVideo &&
          !c.value.isRecordingPaused &&
          _recordingProgress() >= 1) {
        unawaited(_stopRecording());
        return;
      }
      if (mounted) setState(() {});
    });
  }

  void _endRecordingClock() {
    _recordingUiTimer?.cancel();
    _recordingUiTimer = null;
    _recordingSegmentStartedAt = null;
    _recordedDuration = Duration.zero;
  }

  Duration _currentRecordedDuration() {
    final c = _controller;
    final segment = _recordingSegmentStartedAt;
    final active =
        c != null && c.value.isRecordingVideo && !c.value.isRecordingPaused;
    if (segment != null && active) {
      return _recordedDuration + DateTime.now().difference(segment);
    }
    return _recordedDuration;
  }

  String _formatRecordingDuration() {
    final rawMs = _currentRecordedDuration().inMilliseconds;
    final capMs = ReelVideoSpec.maxDurationSeconds * 1000;
    final ms = rawMs > capMs ? capMs : rawMs;
    final totalSec = (ms + 500) ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double _recordingProgress() {
    final elapsedMs = _currentRecordedDuration().inMilliseconds;
    final totalMs = ReelVideoSpec.maxDurationSeconds * 1000;
    if (totalMs <= 0) return 0;
    final p = elapsedMs / totalMs;
    return p.clamp(0.0, 1.0);
  }

  Future<void> _onShutterPointerDown() async {
    if (_busy || _controller == null || !_controller!.value.isInitialized)
      return;
    _pendingPauseTimer?.cancel();
    _pendingPauseTimer = null;
    if (_controller!.value.isRecordingVideo) {
      if (_controller!.value.isRecordingPaused) {
        await _resumeRecording();
      }
      return;
    }
    _shutterHeld = true;
    _countdownGeneration++;
    final token = _countdownGeneration;

    if (_timerDelaySec > 0) {
      if (mounted) {
        setState(() {
          _showCountdownOverlay = true;
          _countdownShow = _timerDelaySec;
        });
      }
      for (int i = _timerDelaySec; i >= 1; i--) {
        if (!mounted || token != _countdownGeneration || !_shutterHeld) {
          if (mounted) {
            setState(() {
              _showCountdownOverlay = false;
              _countdownShow = 0;
            });
          }
          return;
        }
        if (mounted) setState(() => _countdownShow = i);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted || token != _countdownGeneration || !_shutterHeld) {
          if (mounted) {
            setState(() {
              _showCountdownOverlay = false;
              _countdownShow = 0;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _showCountdownOverlay = false;
          _countdownShow = 0;
        });
      }
    }

    if (!_shutterHeld || !mounted) return;
    if (_controller?.value.isRecordingVideo == true) return;
    await _startRecording();
  }

  void _onShutterPointerUp() {
    _shutterHeld = false;
    _countdownGeneration++;
    if (mounted) {
      setState(() {
        _showCountdownOverlay = false;
        _countdownShow = 0;
      });
    }
    _pendingPauseTimer?.cancel();
    _pendingPauseTimer = Timer(const Duration(milliseconds: 140), () {
      unawaited(_pauseRecording());
    });
  }

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) {
      return;
    }
    try {
      await c.startVideoRecording();
      _reelCameraLog('recording started');
      _recordedDuration = Duration.zero;
      _recordingSegmentStartedAt = DateTime.now();
      _beginRecordingClock();
      if (mounted) setState(() {});
    } catch (e, st) {
      _endRecordingClock();
      _reelCameraLog('startRecording error: $e\n$st');
      AppToast.show('Could not start recording: $e', isError: true);
    }
  }

  Future<void> _pauseRecording() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo || c.value.isRecordingPaused)
      return;
    try {
      final resumedAt = _lastResumeAt;
      if (resumedAt != null &&
          DateTime.now().difference(resumedAt).inMilliseconds < 250) {
        return;
      }
      final startedAt = _recordingSegmentStartedAt;
      if (startedAt != null) {
        _recordedDuration += DateTime.now().difference(startedAt);
      }
      await c.pauseVideoRecording();
      _recordingSegmentStartedAt = null;
      if (mounted) setState(() {});
    } catch (e, st) {
      _reelCameraLog('pauseRecording error: $e\n$st');
      AppToast.show('Could not pause recording', isError: true);
    }
  }

  Future<void> _resumeRecording() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo || !c.value.isRecordingPaused)
      return;
    try {
      await c.resumeVideoRecording();
      _recordingSegmentStartedAt = DateTime.now();
      _lastResumeAt = _recordingSegmentStartedAt;
      if (mounted) setState(() {});
    } catch (e, st) {
      _reelCameraLog('resumeRecording error: $e\n$st');
      AppToast.show('Could not resume recording', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return;
    _pendingPauseTimer?.cancel();
    _pendingPauseTimer = null;

    if (!c.value.isRecordingPaused && _recordingSegmentStartedAt != null) {
      _recordedDuration += DateTime.now().difference(
        _recordingSegmentStartedAt!,
      );
    }
    _endRecordingClock();

    try {
      final xfile = await c.stopVideoRecording();
      _reelCameraLog('recording stopped path=${xfile.path}');
      if (!mounted) return;
      await _handleRecordedFile(File(xfile.path));
    } catch (e, st) {
      _reelCameraLog('stopRecording error: $e\n$st');
      AppToast.show('Recording error: $e', isError: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleRecordedFile(File f) async {
    if (!await f.exists()) {
      AppToast.show('Video file missing', isError: true);
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

    if (!mounted) return;
    setState(() => _draftRecordedFile = f);
    AppToast.show('Recording saved. Tap Next to continue.', isError: false);
  }

  Future<void> _openRecordedPreview() async {
    final f = _draftRecordedFile;
    if (f == null) return;
    if (!await f.exists()) {
      if (mounted) {
        setState(() => _draftRecordedFile = null);
      }
      AppToast.show(
        'Recorded video missing. Please record again.',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    final reelId = await Navigator.push<String?>(
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
    if (!mounted) return;
    Navigator.pop(context, reelId);
  }

  Future<void> _onNextTap() async {
    if (_busy) return;
    final c = _controller;
    if (c != null && c.value.isRecordingVideo) {
      await _stopRecording();
    }
    await _openRecordedPreview();
  }

  Future<void> _openGallery() async {
    if (_busy) return;
    _reelCameraLog('open gallery');
    setState(() => _busy = true);
    try {
      if (_controller?.value.isRecordingVideo == true) {
        await _stopRecording();
      }
      if (!mounted) return;
      final reelId = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => ReelGalleryPickerScreen(
            storage: widget.storage,
            auth: widget.auth,
            firestore: widget.firestore,
            saveToFirestore: widget.saveToFirestore,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, reelId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onModeTap(int i) {
    if (i == _modeIndex) return;
    setState(() => _modeIndex = i);
  }

  void _cycleTimerDelay() {
    setState(() {
      if (_timerDelaySec == 0) {
        _timerDelaySec = 3;
      } else if (_timerDelaySec == 3) {
        _timerDelaySec = 10;
      } else {
        _timerDelaySec = 0;
      }
    });
    AppToast.show(
      _timerDelaySec == 0
          ? 'Timer off'
          : 'Timer ${_timerDelaySec}s — hold record to count down',
      isError: false,
    );
  }

  Future<void> _cycleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) return;
    try {
      final m = c.value.flashMode;
      final FlashMode next;
      if (m == FlashMode.off) {
        next = FlashMode.auto;
      } else if (m == FlashMode.auto) {
        next = FlashMode.always;
      } else if (m == FlashMode.always) {
        next = FlashMode.torch;
      } else {
        next = FlashMode.off;
      }
      await c.setFlashMode(next);
      if (mounted) setState(() {});
    } catch (_) {
      AppToast.show('Flash not available for this camera', isError: false);
    }
  }

  Future<void> _applyZoom(double z) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final maxZ = _maxZoomLevel <= 1.0 ? 1.0 : _maxZoomLevel;
    final clamped = z.clamp(1.0, maxZ);
    try {
      await c.setZoomLevel(clamped);
      if (mounted) setState(() => _zoomLevel = clamped);
    } catch (_) {}
  }

  void _showZoomEditor() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_maxZoomLevel <= 1.01) {
      AppToast.show('Zoom not available on this device', isError: false);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zoom',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.zoom_out_rounded,
                          color: Colors.white54,
                        ),
                        Expanded(
                          child: Slider(
                            value: _zoomLevel.clamp(1.0, _maxZoomLevel),
                            min: 1.0,
                            max: _maxZoomLevel,
                            label: '${_zoomLevel.toStringAsFixed(1)}×',
                            onChanged: (v) {
                              setModal(() {});
                              unawaited(_applyZoom(v));
                            },
                          ),
                        ),
                        const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        '${_zoomLevel.toStringAsFixed(1)}×',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _flashIcon(FlashMode m) {
    switch (m) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.highlight_rounded;
    }
  }

  Widget _buildPreview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Container(color: Colors.black);
    }
    final size = MediaQuery.sizeOf(context);
    final ar = c.value.aspectRatio;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width / ar,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterStrip(bool recordingActive) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = i == _filterIndex;
          final filter = _filters[i];
          return GestureDetector(
            onTap: recordingActive
                ? null
                : () => setState(() => _filterIndex = i),
            child: SizedBox(
              width: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: selected ? 54 : 48,
                    height: selected ? 54 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white54,
                        width: selected ? 2.6 : 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: selected ? 0.45 : 0.28,
                          ),
                          blurRadius: selected ? 12 : 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: filter.colors,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: selected ? 22 : 19,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final recordingSession = _controller?.value.isRecordingVideo == true;
    final recordingActive =
        recordingSession && _controller?.value.isRecordingPaused != true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializing)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_initError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _initCamera,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  _filters[_filterIndex].matrix ??
                      const <double>[
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ],
                ),
                child: _buildPreview(),
              ),
            ),
            if (_showAlignmentGrid)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _AlignmentGridPainter()),
                ),
              ),
          ],

          // Top right: cancel / close only (video screen stays clear in the center).
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed:
                          (_busy ||
                              (_draftRecordedFile == null && !recordingSession))
                          ? null
                          : () => unawaited(_onNextTap()),
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color:
                              (_busy ||
                                  (_draftRecordedFile == null &&
                                      !recordingSession))
                              ? Colors.white38
                              : const Color(0xFF0095F6),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      tooltip: recordingSession ? 'Stop recording' : 'Close',
                      onPressed: _busy
                          ? null
                          : () {
                              if (recordingSession) {
                                unawaited(_stopRecording());
                              } else {
                                Navigator.pop(context);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Left sidebar: light (flash), then grid / timer / zoom.
          Positioned(
            left: 8,
            top: mq.padding.top + 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  Opacity(
                    opacity: recordingActive ? 0.35 : 1,
                    child: IgnorePointer(
                      ignoring: recordingActive,
                      child: _sideIcon(
                        _flashIcon(_controller!.value.flashMode),
                        () {
                          if (_busy) return;
                          unawaited(_cycleFlash());
                        },
                      ),
                    ),
                  ),
                if (_controller != null && _controller!.value.isInitialized)
                  const SizedBox(height: 12),
                _sideIcon(
                  _showAlignmentGrid
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  () =>
                      setState(() => _showAlignmentGrid = !_showAlignmentGrid),
                ),
                const SizedBox(height: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _sideIcon(Icons.timer_outlined, _cycleTimerDelay),
                    if (_timerDelaySec > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_timerDelaySec',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sideIcon(Icons.zoom_in_rounded, _showZoomEditor),
              ],
            ),
          ),

          // Bottom dock (Instagram-style): black bar with gallery | shutter | flip, then mode strip.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fade camera preview into the control bar
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 108,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Gallery — fixed left (same screen as recording)
                                SizedBox(
                                  width: 64,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: _buildGalleryDockButton(),
                                  ),
                                ),
                                // Shutter — centered on screen
                                Expanded(
                                  child: Center(
                                    child: Listener(
                                      onPointerDown: (_) {
                                        if (_busy ||
                                            _controller == null ||
                                            !_controller!.value.isInitialized) {
                                          return;
                                        }
                                        unawaited(_onShutterPointerDown());
                                      },
                                      onPointerUp: (_) => _onShutterPointerUp(),
                                      onPointerCancel: (_) =>
                                          _onShutterPointerUp(),
                                      child: SizedBox(
                                        width: 84,
                                        height: 84,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (recordingSession)
                                              SizedBox(
                                                width: 84,
                                                height: 84,
                                                child: CircularProgressIndicator(
                                                  value: _recordingProgress(),
                                                  strokeWidth: 4,
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: 0.22),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.redAccent),
                                                ),
                                              ),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              width: recordingActive ? 72 : 76,
                                              height: recordingActive ? 72 : 76,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: recordingActive
                                                      ? 5
                                                      : 4,
                                                ),
                                                color: recordingActive
                                                    ? Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.3,
                                                          )
                                                    : Colors.transparent,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: recordingActive
                                                      ? 28
                                                      : 58,
                                                  height: recordingActive
                                                      ? 28
                                                      : 58,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Flip — fixed right
                                SizedBox(
                                  width: 76,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _busy ? null : _flipCamera,
                                        borderRadius: BorderRadius.circular(28),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.cameraswitch_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _modes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 22),
                              itemBuilder: (context, i) {
                                final selected = i == _modeIndex;
                                return GestureDetector(
                                  onTap: () => _onModeTap(i),
                                  child: Text(
                                    _modes[i],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal filters aligned with record button area (not at very bottom).
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.padding.bottom + 145,
            child: _buildFilterStrip(recordingActive),
          ),

          if (recordingSession)
            Positioned(
              top: mq.padding.top + 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatRecordingDuration(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        ' / ${ReelVideoSpec.maxDurationSeconds ~/ 60}:${(ReelVideoSpec.maxDurationSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_showCountdownOverlay && _countdownShow > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    '$_countdownShow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.w200,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 24)],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Compact gallery control (bottom-left): thumbnail-style tile + label.
  Widget _buildGalleryDockButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _openGallery,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Open gallery',
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.42),
                      width: 1,
                    ),
                    color: Colors.black.withValues(alpha: 0.45),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.photo_outlined,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Rule-of-thirds overlay for framing (preview only).
class _AlignmentGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final w = size.width / 3;
    final h = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), paint);
      canvas.drawLine(Offset(0, h * i), Offset(size.width, h * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewFilter {
  final String name;
  final List<double>? matrix;
  final List<Color> colors;

  const _PreviewFilter({required this.name, required this.colors, this.matrix});
}
