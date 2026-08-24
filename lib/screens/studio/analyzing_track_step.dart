import 'dart:async';

import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/services/studio_co_producer_service.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';

class AnalyzingTrackStep extends StatefulWidget {
  final StudioTrackInput input;
  final ValueChanged<StudioTrackAnalysis> onComplete;
  final VoidCallback? onBack;

  const AnalyzingTrackStep({
    super.key,
    required this.input,
    required this.onComplete,
    this.onBack,
  });

  @override
  State<AnalyzingTrackStep> createState() => _AnalyzingTrackStepState();
}

class _AnalyzingTrackStepState extends State<AnalyzingTrackStep>
    with SingleTickerProviderStateMixin {
  StudioTrackAnalysis? _analysis;
  late final AnimationController _pulseController;
  int _revealedCount = 0;
  Timer? _revealTimer;
  bool _failed = false;

  static const _items = <_AnalysisItemData>[
    _AnalysisItemData(
      icon: Icons.music_note_rounded,
      label: 'Genre',
      valueKey: 'genre',
    ),
    _AnalysisItemData(
      icon: Icons.bolt_rounded,
      label: 'BPM',
      valueKey: 'bpm',
    ),
    _AnalysisItemData(
      icon: Icons.music_note_outlined,
      label: 'Key',
      valueKey: 'key',
    ),
    _AnalysisItemData(
      icon: Icons.nightlight_round,
      label: 'Mood',
      valueKey: 'mood',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    unawaited(_runAnalysis());
  }

  Future<void> _runAnalysis() async {
    try {
      final analysis = await StudioCoProducerService.analyze(widget.input);
      if (!mounted) return;
      setState(() => _analysis = analysis);
      _startReveal();
    } catch (error, stackTrace) {
      logDebugException(
        'AnalyzingTrackStep.runAnalysis',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final fallback = StudioTrackAnalysis.fromInput(widget.input);
      setState(() {
        _analysis = fallback;
        _failed = true;
      });
      _startReveal();
    }
  }

  void _startReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      if (!mounted) return;
      if (_revealedCount >= _items.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          final analysis = _analysis;
          if (mounted && analysis != null) widget.onComplete(analysis);
        });
        return;
      }
      setState(() => _revealedCount++);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _valueFor(String key) {
    final analysis = _analysis;
    if (analysis == null) return '…';
    switch (key) {
      case 'genre':
        return analysis.genreLabel;
      case 'bpm':
        return analysis.bpmLabel;
      case 'key':
        return analysis.keyLabel;
      case 'mood':
        return analysis.moodLabel;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final listening = _analysis == null;

    return StudioFlowScaffold(
      title: 'Analyzing...',
      currentStep: 2,
      onBack: widget.onBack,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.05);
                final glow = 0.3 + (_pulseController.value * 0.25);
                final floatY = (_pulseController.value - 0.5) * 6;
                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 156,
                      height: 156,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                StudioFlowTheme.purple.withValues(alpha: glow),
                            blurRadius: 48,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      StudioFlowTheme.purple.withValues(alpha: 0.45),
                      StudioFlowTheme.purpleDark.withValues(alpha: 0.2),
                      const Color(0xFF0B0B0F).withValues(alpha: 0.1),
                    ],
                    stops: const [0.2, 0.65, 1],
                  ),
                  border: Border.all(
                    color: StudioFlowTheme.purple.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFB6C1).withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: listening
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: Colors.white,
                              ),
                            )
                          : const Text('🧠', style: TextStyle(fontSize: 52)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              listening ? 'AI is listening' : 'Analysis complete',
              style: const TextStyle(
                color: StudioFlowTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              listening
                  ? (widget.input.hasAudioFile
                      ? 'Sending your recording to Gemini…'
                      : 'Detecting BPM, key, mood & genre…')
                  : (_failed
                      ? 'Used a smart local estimate'
                      : 'Detected your BPM, key, mood & genre'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StudioFlowTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              final revealed = index < _revealedCount && _analysis != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: revealed ? 1 : 0.4,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    offset: revealed ? Offset.zero : const Offset(0, 0.06),
                    child: _AnalysisResultCard(
                      icon: item.icon,
                      label: item.label,
                      value: revealed ? _valueFor(item.valueKey) : '—',
                      showBadge: revealed,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AnalysisItemData {
  final IconData icon;
  final String label;
  final String valueKey;

  const _AnalysisItemData({
    required this.icon,
    required this.label,
    required this.valueKey,
  });
}

class _AnalysisResultCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showBadge;

  const _AnalysisResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.showBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2229),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Icon(icon, color: StudioFlowTheme.gold, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: StudioFlowTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: StudioFlowTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (showBadge) const StudioDetectedBadge(),
        ],
      ),
    );
  }
}
