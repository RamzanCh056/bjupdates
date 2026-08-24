import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/studio/analyzing_track_step.dart';
import 'package:beatjerky/screens/studio/beat_ready_step.dart';
import 'package:beatjerky/screens/studio/generating_beat_step.dart';
import 'package:beatjerky/screens/studio/new_track_step.dart';
import 'package:beatjerky/screens/studio/publish_track_step.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:flutter/material.dart';

enum _CoProducerStep { newTrack, analyzing, generating, beatReady, publish }

class CoProducerFlowScreen extends StatefulWidget {
  const CoProducerFlowScreen({super.key});

  @override
  State<CoProducerFlowScreen> createState() => _CoProducerFlowScreenState();
}

class _CoProducerFlowScreenState extends State<CoProducerFlowScreen> {
  _CoProducerStep _step = _CoProducerStep.newTrack;
  StudioTrackInput? _input;
  StudioTrackAnalysis? _analysis;
  GeneratedBeat? _beat;
  String _selectedMood = 'Dark';

  void _goBack() {
    switch (_step) {
      case _CoProducerStep.newTrack:
        Navigator.maybePop(context);
      case _CoProducerStep.analyzing:
        setState(() => _step = _CoProducerStep.newTrack);
      case _CoProducerStep.generating:
        setState(() => _step = _CoProducerStep.analyzing);
      case _CoProducerStep.beatReady:
        setState(() => _step = _CoProducerStep.analyzing);
      case _CoProducerStep.publish:
        setState(() => _step = _CoProducerStep.beatReady);
    }
  }

  Future<GeneratedBeat> _regenerateBeat() async {
    final input = _input!;
    final analysis = _analysis!;
    final custom = input.description?.trim();
    final description = custom != null && custom.isNotEmpty
        ? custom
        : 'Create a ${analysis.mood.toLowerCase()} ${analysis.genre} beat '
            'at ${analysis.bpm} BPM in ${analysis.key}.';

    final genres = analysis.genre
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final moods = analysis.mood
        .split('·')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = await AiBeatGeneratorService.generateBeat(
      description: description,
      genres: genres.isEmpty ? ['Trap'] : genres,
      moods: moods.isEmpty ? ['Dark'] : moods,
      bpm: analysis.bpm,
      keyLabel: analysis.key,
      length: '2:47',
    );
    return result.beat;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _CoProducerStep.newTrack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: switch (_step) {
        _CoProducerStep.newTrack => NewTrackStep(
            onBack: _goBack,
            onComplete: (input) {
              setState(() {
                _input = input;
                _step = _CoProducerStep.analyzing;
              });
            },
          ),
        _CoProducerStep.analyzing => AnalyzingTrackStep(
            input: _input!,
            onBack: _goBack,
            onComplete: (analysis) {
              setState(() {
                _analysis = analysis;
                _step = _CoProducerStep.generating;
              });
            },
          ),
        _CoProducerStep.generating => GeneratingBeatStep(
            input: _input!,
            analysis: _analysis!,
            onBack: _goBack,
            onComplete: (beat) {
              setState(() {
                _beat = beat;
                _step = _CoProducerStep.beatReady;
              });
            },
          ),
        _CoProducerStep.beatReady => BeatReadyStep(
            beat: _beat!,
            analysis: _analysis!,
            onBack: _goBack,
            onRegenerate: _regenerateBeat,
            onRecordVocals: (mood) {
              setState(() {
                _selectedMood = mood;
                _step = _CoProducerStep.publish;
              });
            },
          ),
        _CoProducerStep.publish => PublishTrackStep(
            beat: _beat!,
            analysis: _analysis!,
            selectedMood: _selectedMood,
            onBack: _goBack,
            onPublished: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
      },
    );
  }
}
