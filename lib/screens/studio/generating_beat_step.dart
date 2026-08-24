import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GeneratingBeatStep extends StatefulWidget {
  final StudioTrackInput input;
  final StudioTrackAnalysis analysis;
  final ValueChanged<GeneratedBeat> onComplete;
  final VoidCallback? onBack;

  const GeneratingBeatStep({
    super.key,
    required this.input,
    required this.analysis,
    required this.onComplete,
    this.onBack,
  });

  @override
  State<GeneratingBeatStep> createState() => _GeneratingBeatStepState();
}

class _GeneratingBeatStepState extends State<GeneratingBeatStep> {
  int _progress = 0;
  Timer? _progressTimer;

  String get _description {
    final custom = widget.input.description?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return 'Create a ${widget.analysis.mood.toLowerCase()} ${widget.analysis.genre} beat '
        'at ${widget.analysis.bpm} BPM in ${widget.analysis.key}.';
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 92) {
          _progress = (_progress + 1 + math.Random().nextInt(2)).clamp(1, 92);
        }
      });
    });
  }

  Future<void> _generate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to generate beats.', isError: true);
      widget.onBack?.call();
      return;
    }

    setState(() => _progress = 1);
    _startProgress();

    try {
      final genres = widget.analysis.genre
          .split('/')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final moods = widget.analysis.mood
          .split('·')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final result = await AiBeatGeneratorService.generateBeat(
        description: _description,
        genres: genres.isEmpty ? ['Trap'] : genres,
        moods: moods.isEmpty ? ['Dark'] : moods,
        bpm: widget.analysis.bpm,
        keyLabel: widget.analysis.key,
        length: '2:47',
      );

      _progressTimer?.cancel();
      if (!mounted) return;
      setState(() => _progress = 100);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      widget.onComplete(result.beat);
    } catch (error, stackTrace) {
      _progressTimer?.cancel();
      logDebugException('GeneratingBeatStep.generate', error, stackTrace: stackTrace);
      AppToast.show(
        AiBeatGeneratorService.beatGenerationErrorMessage(error),
        isError: true,
      );
      if (mounted) widget.onBack?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioFlowScaffold(
      title: 'Generating...',
      currentStep: 3,
      showBack: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_progress%',
                style: const TextStyle(
                  color: StudioFlowTheme.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_progress / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: StudioFlowTheme.purple,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Building your professional beat...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: StudioFlowTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
