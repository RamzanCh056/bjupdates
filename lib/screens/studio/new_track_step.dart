import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class NewTrackStep extends StatefulWidget {
  final ValueChanged<StudioTrackInput> onComplete;
  final VoidCallback? onBack;

  const NewTrackStep({
    super.key,
    required this.onComplete,
    this.onBack,
  });

  @override
  State<NewTrackStep> createState() => _NewTrackStepState();
}

class _NewTrackStepState extends State<NewTrackStep>
    with TickerProviderStateMixin {
  StudioInputMode _mode = StudioInputMode.humSing;
  bool _isRecording = false;
  bool _isStarting = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  final TextEditingController _describeController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  late List<double> _waveHeights;

  @override
  void initState() {
    super.initState();
    _waveHeights = _idleWaveform();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_updateWaveform);
    _waveController.repeat();
  }

  List<double> _idleWaveform() {
    return List<double>.generate(40, (i) {
      final t = i / 40 * math.pi * 3;
      return 0.18 +
          (math.sin(t).abs() * 0.22) +
          (math.cos(t * 0.6).abs() * 0.12);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_recorder.dispose());
    _pulseController.dispose();
    _waveController.dispose();
    _describeController.dispose();
    super.dispose();
  }

  void _updateWaveform() {
    final t = _waveController.value * math.pi * 2;
    setState(() {
      for (var i = 0; i < _waveHeights.length; i++) {
        final phase = t + (i * 0.38);
        if (_isRecording) {
          _waveHeights[i] = 0.14 + (0.5 + math.sin(phase).abs() * 0.42);
        } else {
          final idle = i / _waveHeights.length * math.pi * 3;
          _waveHeights[i] = 0.18 + (math.sin(idle + t * 0.25).abs() * 0.2);
        }
      }
    });
  }

  void _selectMode(StudioInputMode mode) {
    if (_isRecording || _isStarting) return;
    setState(() => _mode = mode);
  }

  Future<void> _toggleRecording() async {
    if (_mode == StudioInputMode.describe || _isStarting) return;
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() => _isStarting = true);
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        AppToast.show(
          'Microphone permission is required to record.',
          isError: true,
        );
        return;
      }

      if (!await _recorder.hasPermission()) {
        AppToast.show(
          'Microphone permission is required to record.',
          isError: true,
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/co_producer_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _elapsed = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (error, stackTrace) {
      logDebugException(
        'NewTrackStep.startRecording',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show('Could not start recording.', isError: true);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final duration = _elapsed;
    var path = _recordingPath;

    try {
      final stoppedPath = await _recorder.stop();
      if (stoppedPath != null && stoppedPath.isNotEmpty) {
        path = stoppedPath;
      }
    } catch (error, stackTrace) {
      logDebugException(
        'NewTrackStep.stopRecording',
        error,
        stackTrace: stackTrace,
      );
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _waveHeights = _idleWaveform();
    });

    if (duration.inSeconds < 2) {
      AppToast.show('Record at least 2 seconds.');
      return;
    }

    widget.onComplete(
      StudioTrackInput(
        mode: _mode,
        recordingDuration: duration,
        audioPath: path,
      ),
    );
  }

  void _continueFromDescribe() {
    final text = _describeController.text.trim();
    if (text.isEmpty) return;
    widget.onComplete(
      StudioTrackInput(
        mode: StudioInputMode.describe,
        description: text,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDescribe = _mode == StudioInputMode.describe;

    return StudioFlowScaffold(
      title: 'New Track',
      currentStep: 1,
      onBack: widget.onBack,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeSelector(
              selected: _mode,
              onSelect: _selectMode,
              enabled: !_isRecording && !_isStarting,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              decoration: BoxDecoration(
                gradient: StudioFlowTheme.heroGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: StudioFlowTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: StudioFlowTheme.purple.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isDescribe
                        ? 'Describe the vibe you want. AI will shape BPM, key, and mood from your words.'
                        : 'Hum, sing, or beatbox your idea. Even 5 seconds is enough. AI will detect your BPM, key, and mood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (isDescribe) ...[
                    TextField(
                      controller: _describeController,
                      maxLines: 4,
                      maxLength: 200,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Something dark and sad like a rainy night...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.32),
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.28),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: const TextStyle(
                          color: StudioFlowTheme.textMuted,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    _PrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _describeController.text.trim().isEmpty
                          ? null
                          : _continueFromDescribe,
                    ),
                  ] else ...[
                    StudioWaveform(
                      heights: _waveHeights,
                      height: 72,
                      color: StudioFlowTheme.purple,
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final glow = _isRecording
                              ? 0.42 + (_pulseController.value * 0.28)
                              : 0.28 + (_pulseController.value * 0.12);
                          return Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: StudioFlowTheme.purple
                                      .withValues(alpha: glow),
                                  blurRadius: 36,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                StudioFlowTheme.purple.withValues(alpha: 0.18),
                            border: Border.all(
                              color: StudioFlowTheme.purple
                                  .withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF12141A),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: _isStarting
                                  ? const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: StudioFlowTheme.silver,
                                      ),
                                    )
                                  : Icon(
                                      _isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      color: StudioFlowTheme.silver,
                                      size: 34,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isRecording
                          ? '${_formatDuration(_elapsed)} · Recording...'
                          : 'Tap to record',
                      style: const TextStyle(
                        color: StudioFlowTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (!isDescribe)
              const StudioFooterTip(
                text:
                    'Try saying "something dark and sad like a rainy night" in Describe mode',
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final StudioInputMode selected;
  final ValueChanged<StudioInputMode> onSelect;
  final bool enabled;

  const _ModeSelector({
    required this.selected,
    required this.onSelect,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: 'Hum / Sing',
            icon: Icons.music_note_rounded,
            selected: selected == StudioInputMode.humSing,
            onTap: enabled ? () => onSelect(StudioInputMode.humSing) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'Beatbox',
            icon: Icons.mic_rounded,
            selected: selected == StudioInputMode.beatbox,
            onTap: enabled ? () => onSelect(StudioInputMode.beatbox) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'Describe',
            icon: Icons.chat_bubble_outline_rounded,
            selected: selected == StudioInputMode.describe,
            onTap: enabled ? () => onSelect(StudioInputMode.describe) : null,
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioFlowTheme.purple : StudioFlowTheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? StudioFlowTheme.purple
                  : const Color(0xFF2A2A35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : StudioFlowTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : StudioFlowTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StudioFlowTheme.purple,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: StudioFlowTheme.purple.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
