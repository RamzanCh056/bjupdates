import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';

class _MoodOption {
  final String label;
  final String emoji;

  const _MoodOption(this.label, this.emoji);
}

const _kMoodOptions = [
  _MoodOption('Dark', '🌙'),
  _MoodOption('Upbeat', '☀️'),
  _MoodOption('Emotional', '💔'),
  _MoodOption('Aggressive', '🔥'),
  _MoodOption('Chill', '💧'),
];

class BeatReadyStep extends StatefulWidget {
  final GeneratedBeat beat;
  final StudioTrackAnalysis analysis;
  final VoidCallback? onBack;
  final void Function(String selectedMood) onRecordVocals;
  final Future<GeneratedBeat> Function()? onRegenerate;

  const BeatReadyStep({
    super.key,
    required this.beat,
    required this.analysis,
    this.onBack,
    required this.onRecordVocals,
    this.onRegenerate,
  });

  @override
  State<BeatReadyStep> createState() => _BeatReadyStepState();
}

class _BeatReadyStepState extends State<BeatReadyStep> {
  late GeneratedBeat _beat;
  late String _selectedMood;
  bool _isPlaying = false;
  bool _isRegenerating = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 2, seconds: 47);
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription? _playerSub;
  final List<double> _waveHeights = List<double>.generate(48, (i) {
    final t = i / 48 * math.pi * 4;
    return 0.2 + math.sin(t).abs() * 0.55 + math.cos(t * 0.7).abs() * 0.2;
  });

  @override
  void initState() {
    super.initState();
    _beat = widget.beat;
    _selectedMood = _defaultMoodFromAnalysis();
    _duration = _beat.targetDuration.inSeconds > 0
        ? _beat.targetDuration
        : const Duration(minutes: 2, seconds: 47);
    _bindPlayer();
    _preparePlayback();
  }

  String _defaultMoodFromAnalysis() {
    final mood = widget.analysis.mood.split('·').first.trim();
    for (final option in _kMoodOptions) {
      if (mood.toLowerCase().contains(option.label.toLowerCase())) {
        return option.label;
      }
    }
    return 'Dark';
  }

  void _bindPlayer() {
    _positionSub = AiBeatGeneratorService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _durationSub = AiBeatGeneratorService.durationStream.listen((dur) {
      if (!mounted || dur == null || dur.inSeconds <= 0) return;
      setState(() => _duration = dur);
    });
    _playerSub = AiBeatGeneratorService.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing &&
            AiBeatGeneratorService.playingBeatId == _beat.id;
      });
    });
  }

  Future<void> _preparePlayback() async {
    if (!_beat.hasPlayableAudio) return;
    try {
      await AiBeatGeneratorService.startBeat(_beat);
      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (error, stackTrace) {
      logDebugException('BeatReadyStep.preparePlayback', error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }

  String get _subtitle {
    final genre = widget.analysis.genre.split('/').first.trim();
    return '${_capitalize(genre)} · ${widget.analysis.bpm} BPM · ${widget.analysis.key}';
  }

  String get _trackMeta {
    final genre = widget.analysis.genre.split('/').first.trim();
    return '${_capitalize(genre)} · ${widget.analysis.bpm} BPM · ${widget.analysis.key}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlayback() async {
    if (!_beat.hasPlayableAudio) {
      if (_beat.hasBlueprint) {
        AppToast.show('Blueprint ready — use Record Vocals / Publish to continue.');
      } else {
        AppToast.show('Beat audio is still processing.');
      }
      return;
    }
    try {
      await AiBeatGeneratorService.playBeat(_beat);
    } catch (error, stackTrace) {
      logDebugException('BeatReadyStep.togglePlayback', error, stackTrace: stackTrace);
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _handleRegen() async {
    if (_isRegenerating || widget.onRegenerate == null) return;
    setState(() => _isRegenerating = true);
    try {
      final newBeat = await widget.onRegenerate!();
      if (!mounted) return;
      setState(() {
        _beat = newBeat;
        _isRegenerating = false;
      });
      if (newBeat.hasPlayableAudio) {
        await _preparePlayback();
      }
      AppToast.show('Beat regenerated.');
    } catch (error, stackTrace) {
      logDebugException('BeatReadyStep.regen', error, stackTrace: stackTrace);
      if (mounted) setState(() => _isRegenerating = false);
      AppToast.show(error.toString(), isError: true);
    }
  }

  double get _progressFraction {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return StudioFlowScaffold(
      title: 'Your Beat is Ready 🎉',
      subtitle: _subtitle,
      currentStep: 3,
      onBack: widget.onBack,
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _RecordVocalsButton(onTap: () => widget.onRecordVocals(_selectedMood)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BeatPlayerCard(
              beat: _beat,
              meta: _trackMeta,
              waveHeights: _waveHeights,
              progress: _progressFraction,
              positionLabel: _formatDuration(_position),
              durationLabel: _formatDuration(_duration),
              isPlaying: _isPlaying,
              isRegenerating: _isRegenerating,
              onTogglePlay: _togglePlayback,
              onRegen: widget.onRegenerate != null ? _handleRegen : null,
            ),
            if (_beat.hasBlueprint) ...[
              const SizedBox(height: 14),
              _BlueprintCard(beat: _beat),
            ],
            const SizedBox(height: 14),
            _AdjustMoodSection(
              selected: _selectedMood,
              onSelected: (mood) => setState(() => _selectedMood = mood),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueprintCard extends StatelessWidget {
  final GeneratedBeat beat;

  const _BlueprintCard({required this.beat});

  @override
  Widget build(BuildContext context) {
    final sections = <MapEntry<String, String>>[
      if (beat.summary.isNotEmpty) MapEntry('Summary', beat.summary),
      if (beat.arrangement.isNotEmpty) MapEntry('Arrangement', beat.arrangement),
      if (beat.drums.isNotEmpty) MapEntry('Drums', beat.drums),
      if (beat.bass.isNotEmpty) MapEntry('Bass', beat.bass),
      if (beat.melody.isNotEmpty) MapEntry('Melody', beat.melody),
      if (beat.mixNotes.isNotEmpty) MapEntry('Mix notes', beat.mixNotes),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AI Beat Blueprint',
                style: TextStyle(
                  color: StudioFlowTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (!beat.hasPlayableAudio)
                Text(
                  'Ready to produce',
                  style: TextStyle(
                    color: StudioFlowTheme.purple.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            beat.title,
            style: const TextStyle(
              color: StudioFlowTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final section in sections.take(3)) ...[
            const SizedBox(height: 12),
            Text(
              section.key,
              style: const TextStyle(
                color: StudioFlowTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BeatPlayerCard extends StatelessWidget {
  final GeneratedBeat beat;
  final String meta;
  final List<double> waveHeights;
  final double progress;
  final String positionLabel;
  final String durationLabel;
  final bool isPlaying;
  final bool isRegenerating;
  final VoidCallback onTogglePlay;
  final VoidCallback? onRegen;

  const _BeatPlayerCard({
    required this.beat,
    required this.meta,
    required this.waveHeights,
    required this.progress,
    required this.positionLabel,
    required this.durationLabel,
    required this.isPlaying,
    required this.isRegenerating,
    required this.onTogglePlay,
    this.onRegen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 148,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  StudioFlowTheme.purple.withValues(alpha: 0.55),
                  StudioFlowTheme.purpleDark.withValues(alpha: 0.35),
                  const Color(0xFF1A1030),
                ],
              ),
            ),
            child: const Center(
              child: Text('🎹', style: TextStyle(fontSize: 56)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beat.title.isNotEmpty
                                ? beat.title
                                : 'AI Generated Beat #1',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StudioFlowTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: const TextStyle(
                              color: StudioFlowTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onRegen != null)
                      Material(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: isRegenerating ? null : onRegen,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isRegenerating)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: StudioFlowTheme.purple,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.refresh_rounded,
                                    size: 15,
                                    color: StudioFlowTheme.textSecondary,
                                  ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Regen',
                                  style: TextStyle(
                                    color: StudioFlowTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProgressWaveform(
                  heights: waveHeights,
                  progress: progress,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      positionLabel,
                      style: const TextStyle(
                        color: StudioFlowTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      durationLabel,
                      style: const TextStyle(
                        color: StudioFlowTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: onTogglePlay,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: StudioFlowTheme.purple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: StudioFlowTheme.purple.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressWaveform extends StatelessWidget {
  final List<double> heights;
  final double progress;

  const _ProgressWaveform({
    required this.heights,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final playheadIndex = (heights.length * progress).floor();

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(heights.length, (index) {
          final played = index <= playheadIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: 44 * heights[index].clamp(0.12, 1.0),
                decoration: BoxDecoration(
                  color: played
                      ? StudioFlowTheme.purple.withValues(alpha: 0.9)
                      : StudioFlowTheme.purple.withValues(alpha: 0.22),
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

class _AdjustMoodSection extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _AdjustMoodSection({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADJUST MOOD',
            style: TextStyle(
              color: StudioFlowTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kMoodOptions.map((option) {
              final isSelected = selected == option.label;
              return GestureDetector(
                onTap: () => onSelected(option.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? StudioFlowTheme.purple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? StudioFlowTheme.purple
                          : const Color(0xFF2A2A35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected
                              ? StudioFlowTheme.purple
                              : StudioFlowTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecordVocalsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordVocalsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            gradient: StudioFlowTheme.buttonGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: StudioFlowTheme.purple.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Your Vocals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sing over this beat — AI will enhance automatically',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
