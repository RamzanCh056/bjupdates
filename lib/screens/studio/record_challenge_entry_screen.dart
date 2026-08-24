import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/models/challenge_models.dart';
import 'package:beatjerky/screens/studio/challenge_leaderboard_screen.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/challenge_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

enum _RecordState { recording, paused, stopped }

class RecordChallengeEntryScreen extends StatefulWidget {
  final String challengeId;

  const RecordChallengeEntryScreen({
    super.key,
    required this.challengeId,
  });

  @override
  State<RecordChallengeEntryScreen> createState() =>
      _RecordChallengeEntryScreenState();
}

class _RecordChallengeEntryScreenState extends State<RecordChallengeEntryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _beatWaveController;
  late final AnimationController _recordWaveController;
  late List<double> _recordWaveHeights;
  late List<double> _beatWaveHeights;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  _RecordState _recordState = _RecordState.stopped;
  bool _isBeatPlaying = false;
  bool _beatLoading = false;
  bool _submitting = false;
  final AudioPlayer _beatPlayer = AudioPlayer();
  String? _loadedBeatUrl;

  bool get _isRecording => _recordState == _RecordState.recording;

  @override
  void initState() {
    super.initState();
    _recordWaveHeights = _generateSymmetricWaveform(16);
    _beatWaveHeights = _generateWaveform(5);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _beatWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_updateBeatWaveform);

    _recordWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addListener(_updateRecordWaveform);

    _setIdleWaveform();
    _setIdleBeatWaveform();
  }

  Future<void> _ensureBeatLoaded(Challenge challenge) async {
    final url = challenge.beat.audioUrl?.trim();
    if (url == null || url.isEmpty) return;
    if (_loadedBeatUrl == url || _beatLoading) return;

    setState(() => _beatLoading = true);
    try {
      await _beatPlayer.setUrl(url);
      await _beatPlayer.setLoopMode(LoopMode.one);
      _loadedBeatUrl = url;
      await _beatPlayer.play();
      if (!mounted) return;
      setState(() {
        _isBeatPlaying = true;
        _beatLoading = false;
      });
      _beatWaveController.repeat();
    } catch (error, stackTrace) {
      logDebugException(
        'RecordChallengeEntry.ensureBeatLoaded',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isBeatPlaying = false;
        _beatLoading = false;
      });
      AppToast.show('Could not play the challenge beat', isError: true);
    }
  }

  Future<void> _submitEntry() async {
    if (_submitting) return;
    if (_elapsed.inSeconds < 1) {
      AppToast.show('Record at least 1 second first');
      return;
    }
    if (_isRecording) _pauseRecording();

    setState(() => _submitting = true);
    try {
      await ChallengeService.submitEntry(
        challengeId: widget.challengeId,
        durationSec: _elapsed.inSeconds,
      );
      if (!mounted) return;
      AppToast.show('Entry submitted! 🎤');
      openChallengeLeaderboard(
        context,
        challengeId: widget.challengeId,
        replace: true,
      );
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startRecording() {
    setState(() => _recordState = _RecordState.recording);
    _pulseController.repeat(reverse: true);
    _recordWaveController.repeat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _pauseRecording() {
    setState(() => _recordState = _RecordState.paused);
    _timer?.cancel();
    _pulseController.stop();
    _recordWaveController.stop();
    _setIdleWaveform();
  }

  void _stopRecording() {
    setState(() => _recordState = _RecordState.stopped);
    _timer?.cancel();
    _pulseController.stop();
    _recordWaveController.stop();
    _setIdleWaveform();
  }

  void _toggleMic() {
    switch (_recordState) {
      case _RecordState.recording:
        _pauseRecording();
      case _RecordState.paused:
        _startRecording();
      case _RecordState.stopped:
        setState(() => _elapsed = Duration.zero);
        _startRecording();
    }
  }

  void _setIdleWaveform() {
    setState(() {
      final half = _recordWaveHeights.length ~/ 2;
      for (var i = 0; i < half; i++) {
        final t = i / half * math.pi * 3;
        final h =
            0.18 + (math.sin(t).abs() * 0.18) + (math.cos(t * 0.6).abs() * 0.1);
        _recordWaveHeights[i] = h;
        _recordWaveHeights[_recordWaveHeights.length - 1 - i] = h;
      }
    });
  }

  String get _statusSuffix {
    switch (_recordState) {
      case _RecordState.recording:
        return ' · Recording...';
      case _RecordState.paused:
        return ' · Paused';
      case _RecordState.stopped:
        return ' · Stopped';
    }
  }

  Future<void> _toggleBeatPlayback() async {
    if (_loadedBeatUrl == null) {
      AppToast.show(
        _beatLoading
            ? 'Loading beat…'
            : 'This challenge has no playable beat yet',
      );
      return;
    }
    try {
      if (_isBeatPlaying) {
        await _beatPlayer.pause();
        if (!mounted) return;
        setState(() => _isBeatPlaying = false);
        _beatWaveController.stop();
        _setIdleBeatWaveform();
      } else {
        await _beatPlayer.play();
        if (!mounted) return;
        setState(() => _isBeatPlaying = true);
        _beatWaveController.repeat();
      }
    } catch (error, stackTrace) {
      logDebugException(
        'RecordChallengeEntry.toggleBeat',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show('Playback failed', isError: true);
    }
  }

  void _setIdleBeatWaveform() {
    setState(() {
      for (var i = 0; i < _beatWaveHeights.length; i++) {
        final t = i / _beatWaveHeights.length * math.pi * 2;
        _beatWaveHeights[i] =
            0.28 + (math.sin(t).abs() * 0.22) + (math.cos(t * 0.5).abs() * 0.1);
      }
    });
  }

  IconData get _micIcon {
    switch (_recordState) {
      case _RecordState.recording:
        return Icons.mic_rounded;
      case _RecordState.paused:
        return Icons.play_arrow_rounded;
      case _RecordState.stopped:
        return Icons.mic_rounded;
    }
  }

  List<double> _generateSymmetricWaveform(int halfCount) {
    final half = List<double>.generate(halfCount, (i) {
      final t = i / halfCount * math.pi * 3;
      return 0.2 + (math.sin(t).abs() * 0.35) + (math.cos(t * 0.7).abs() * 0.2);
    });
    return [...half, ...half.reversed];
  }

  List<double> _generateWaveform(int count) {
    return List<double>.generate(count, (i) {
      final t = i / count * math.pi * 3;
      return 0.2 + (math.sin(t).abs() * 0.35) + (math.cos(t * 0.7).abs() * 0.2);
    });
  }

  void _updateBeatWaveform() {
    if (!_isBeatPlaying) return;
    final t = _beatWaveController.value * math.pi * 2;
    setState(() {
      for (var i = 0; i < _beatWaveHeights.length; i++) {
        final phase = t + (i * 0.55);
        _beatWaveHeights[i] = 0.22 + (0.55 + math.sin(phase).abs() * 0.38);
      }
    });
  }

  void _updateRecordWaveform() {
    if (!_isRecording) return;
    final t = _recordWaveController.value * math.pi * 2;
    final half = _recordWaveHeights.length ~/ 2;
    setState(() {
      for (var i = 0; i < half; i++) {
        final phase = t + (i * 0.42);
        final h = 0.14 + (0.52 + math.sin(phase).abs() * 0.44);
        _recordWaveHeights[i] = h;
        _recordWaveHeights[_recordWaveHeights.length - 1 - i] = h;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _beatWaveController.dispose();
    _recordWaveController.dispose();
    _beatPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: StreamBuilder<Challenge?>(
            stream: ChallengeService.watchChallenge(widget.challengeId),
            builder: (context, snapshot) {
              final challenge = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  challenge == null) {
                return const Center(
                  child: CircularProgressIndicator(color: recntsColor),
                );
              }
              if (challenge == null) {
                return Center(
                  child: TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Challenge not found — Go back'),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_ensureBeatLoaded(challenge));
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                    child: Row(
                      children: [
                        StudioBackButton(
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your Entry',
                            style: TextStyle(
                              color: StudioFlowTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '03 · RECORD ENTRY',
                            style: TextStyle(
                              color: StudioFlowTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ChallengeInfoCard(
                            title: challenge.title,
                            creator: challenge.creatorName,
                            hashtag: challenge.primaryHashtag,
                            entries: challenge.entriesLabel,
                          ),
                          const SizedBox(height: 18),
                          const _SectionCaption(
                            'ORIGINAL BEAT PLAYING IN YOUR EAR',
                          ),
                          const SizedBox(height: 8),
                          _OriginalBeatCard(
                            trackTitle: challenge.beat.title,
                            waveHeights: _beatWaveHeights,
                            isPlaying: _isBeatPlaying,
                            isLoading: _beatLoading,
                            hasAudio: challenge.beat.hasAudio,
                            onTogglePlayback: _toggleBeatPlayback,
                          ),
                          const SizedBox(height: 18),
                          _RecordingCard(
                            waveHeights: _recordWaveHeights,
                            pulseController: _pulseController,
                            elapsedLabel: _formatDuration(_elapsed),
                            statusSuffix: _recordState == _RecordState.stopped &&
                                    _elapsed == Duration.zero
                                ? ' · Tap mic to record'
                                : _statusSuffix,
                            micIcon: _micIcon,
                            isActive: _isRecording,
                            showStop: _recordState != _RecordState.stopped,
                            onMicTap: _toggleMic,
                            onStop: _stopRecording,
                          ),
                          const SizedBox(height: 18),
                          const _HowItWorksBox(),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: buttonGradient,
                          borderRadius: BorderRadius.circular(27),
                          boxShadow: [
                            BoxShadow(
                              color: recntsColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _submitting ? null : _submitEntry,
                            borderRadius: BorderRadius.circular(27),
                            child: Center(
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '🚀 Submit Entry',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
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

class _SectionCaption extends StatelessWidget {
  final String text;

  const _SectionCaption(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ChallengeInfoCard extends StatelessWidget {
  final String title;
  final String creator;
  final String hashtag;
  final String entries;

  const _ChallengeInfoCard({
    required this.title,
    required this.creator,
    required this.hashtag,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recntsColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: recntsColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: recntsColor.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔥', style: TextStyle(fontSize: 11)),
                SizedBox(width: 4),
                Text(
                  'CHALLENGE',
                  style: TextStyle(
                    color: recntsColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'by $creator • $hashtag • $entries',
            style: const TextStyle(
              color: StudioFlowTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginalBeatCard extends StatelessWidget {
  final String trackTitle;
  final List<double> waveHeights;
  final bool isPlaying;
  final bool isLoading;
  final bool hasAudio;
  final VoidCallback onTogglePlayback;

  const _OriginalBeatCard({
    required this.trackTitle,
    required this.waveHeights,
    required this.isPlaying,
    required this.isLoading,
    required this.hasAudio,
    required this.onTogglePlayback,
  });

  String get _statusLabel {
    if (!hasAudio) return 'No beat attached';
    if (isLoading) return 'Loading beat…';
    if (isPlaying) return 'Playing now...';
    return 'Paused · tap to play';
  }

  Color get _statusColor {
    if (!hasAudio) return StudioFlowTheme.textMuted;
    if (isLoading) return recntsColor;
    if (isPlaying) return const Color(0xFF22C55E);
    return StudioFlowTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTogglePlayback,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: recntsColor.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trackTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.play_arrow_rounded,
                          color: _statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _WaveformVisualizer(
                heights: waveHeights,
                maxHeight: 32,
                barWidth: 3.5,
                barGap: 3,
                isActive: isPlaying,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final List<double> waveHeights;
  final AnimationController pulseController;
  final String elapsedLabel;
  final String statusSuffix;
  final IconData micIcon;
  final bool isActive;
  final bool showStop;
  final VoidCallback onMicTap;
  final VoidCallback onStop;

  const _RecordingCard({
    required this.waveHeights,
    required this.pulseController,
    required this.elapsedLabel,
    required this.statusSuffix,
    required this.micIcon,
    required this.isActive,
    required this.showStop,
    required this.onMicTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: recntsColor.withValues(alpha: isActive ? 0.42 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: recntsColor.withValues(alpha: isActive ? 0.06 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'NOW RECORD YOUR VERSION',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 22),
          _RecordingWaveform(
            heights: waveHeights,
            isActive: isActive,
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: onMicTap,
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final pulse = isActive ? pulseController.value : 0.0;
                return SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isActive) ...[
                        Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: recntsColor.withValues(
                                alpha: 0.1 + (pulse * 0.08),
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: recntsColor.withValues(
                                alpha: 0.16 + (pulse * 0.12),
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: recntsColor.withValues(
                              alpha: 0.08 + (pulse * 0.06),
                            ),
                          ),
                        ),
                      ],
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isActive
                              ? buttonGradient
                              : LinearGradient(
                                  colors: [
                                    recntsColor.withValues(alpha: 0.45),
                                    indigoColor.withValues(alpha: 0.45),
                                  ],
                                ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: recntsColor.withValues(
                                      alpha: 0.35 + (pulse * 0.15),
                                    ),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          micIcon,
                          color: StudioFlowTheme.silver,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: elapsedLabel,
                  style: const TextStyle(color: StudioFlowTheme.textPrimary),
                ),
                TextSpan(
                  text: statusSuffix,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          if (showStop) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RecordingControlChip(
                  icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: isActive ? 'Pause' : 'Resume',
                  onTap: onMicTap,
                ),
                const SizedBox(width: 12),
                _RecordingControlChip(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  onTap: onStop,
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingWaveform extends StatelessWidget {
  final List<double> heights;
  final bool isActive;

  const _RecordingWaveform({
    required this.heights,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    const maxHeight = 72.0;
    const barWidth = 4.0;

    return SizedBox(
      height: maxHeight,
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(heights.length, (index) {
          final factor = heights[index].clamp(0.14, 1.0);
          final barHeight = maxHeight * factor;
          final isAccent = index.isEven;

          return Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isAccent
                        ? [
                            recntsColor.withValues(alpha: isActive ? 0.95 : 0.4),
                            StudioFlowTheme.purpleDark.withValues(
                              alpha: isActive ? 0.75 : 0.3,
                            ),
                          ]
                        : [
                            recntsColor.withValues(alpha: isActive ? 0.55 : 0.22),
                            const Color(0xFF3D2A5C).withValues(
                              alpha: isActive ? 0.85 : 0.35,
                            ),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RecordingControlChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _RecordingControlChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : recntsColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformVisualizer extends StatelessWidget {
  final List<double> heights;
  final double maxHeight;
  final double barWidth;
  final double barGap;
  final bool isActive;
  final bool compact;

  const _WaveformVisualizer({
    required this.heights,
    required this.maxHeight,
    required this.barWidth,
    required this.barGap,
    required this.isActive,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final topAlpha = isActive ? 0.95 : 0.35;
    final bottomAlpha = isActive ? 0.42 : 0.15;
    const verticalPadding = 10.0;
    final barMaxHeight = compact
        ? maxHeight
        : maxHeight - (verticalPadding * 2);

    Widget barsRow({required bool expand}) {
      final children = heights.map((factor) {
        final barHeight = barMaxHeight * factor.clamp(0.14, 1.0);
        final bar = Container(
          width: barWidth,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                recntsColor.withValues(alpha: topAlpha),
                recntsColor.withValues(alpha: bottomAlpha),
              ],
            ),
            borderRadius: BorderRadius.circular(barWidth),
          ),
        );

        if (expand) {
          return Expanded(
            child: Align(alignment: Alignment.center, child: bar),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: barGap / 2),
          child: bar,
        );
      }).toList();

      return Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    }

    if (compact) {
      return SizedBox(
        height: maxHeight,
        child: Center(child: barsRow(expand: false)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: maxHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: verticalPadding,
        ),
        color: const Color(0xFF0A0C10),
        child: barsRow(expand: true),
      ),
    );
  }
}

class _HowItWorksBox extends StatelessWidget {
  const _HowItWorksBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: recntsColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                    children: const [
                      TextSpan(
                        text: 'How it works: ',
                        style: TextStyle(
                          color: recntsColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text:
                            'Original beat plays first, then your recording plays after. AI stitches them together automatically before submitting.',
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
}

void openRecordChallengeEntry(
  BuildContext context, {
  required String challengeId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecordChallengeEntryScreen(challengeId: challengeId),
    ),
  );
}
