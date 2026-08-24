import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/viral_score_predictor_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

const LinearGradient _metricBarGradient = LinearGradient(
  colors: [Color(0xFF2D6A4F), Color(0xFF72EFDD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class ViralScorePredictorScreen extends StatefulWidget {
  const ViralScorePredictorScreen({super.key});

  @override
  State<ViralScorePredictorScreen> createState() =>
      _ViralScorePredictorScreenState();
}

class _ViralScorePredictorScreenState extends State<ViralScorePredictorScreen> {
  static const int _maxNotesLength = 500;

  final TextEditingController _notesController = TextEditingController();

  UploadedTrackInfo? _uploadedTrack;
  ViralScoreResult? _prediction;
  bool _isUploading = false;
  bool _isPredicting = false;
  bool _isPlaying = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    ViralScorePredictorService.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
    });
  }

  @override
  void dispose() {
    ViralScorePredictorService.stopTrack();
    _notesController.dispose();
    super.dispose();
  }

  void _showInfoDialog() {
    AiToolsInfoDialog.show(
      context,
      title: 'Viral Score Predictor',
      message:
          'AI scores viral potential for Hook, Structure, Originality, and Mix Quality using OpenAI.',
    );
  }

  Future<void> _pickTrack() async {
    if (_isUploading || _isPredicting) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        AppToast.show('Could not read the selected file.', isError: true);
        return;
      }

      setState(() {
        _isUploading = true;
        _prediction = null;
      });
      await ViralScorePredictorService.stopTrack();

      final track = await ViralScorePredictorService.probeLocalTrack(
        fileName: file.name,
        localPath: path,
      );

      if (!mounted) return;
      setState(() {
        _uploadedTrack = track;
        _isPlaying = false;
      });
    } catch (error, stackTrace) {
      logDebugException('ViralScorePredictorScreen.pickTrack', error, stackTrace: stackTrace);
      AppToast.show(ViralScorePredictorService.errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _clearTrack() async {
    await ViralScorePredictorService.stopTrack();
    setState(() {
      _uploadedTrack = null;
      _prediction = null;
      _isPlaying = false;
    });
  }

  Future<void> _predictScore() async {
    final track = _uploadedTrack;
    if (track == null) {
      AppToast.show('Upload a track first.', isError: true);
      return;
    }
    if (_isPredicting) return;

    setState(() => _isPredicting = true);

    try {
      final result = await ViralScorePredictorService.predict(
        track: track,
        trackNotes: _notesController.text,
      );
      if (!mounted) return;
      setState(() => _prediction = result);
      AppToast.show('Viral score ready.');
    } catch (error, stackTrace) {
      logDebugException('ViralScorePredictorScreen.predict', error, stackTrace: stackTrace);
      AppToast.show(ViralScorePredictorService.errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPredicting = false);
      }
    }
  }

  Future<void> _togglePlayback() async {
    final track = _uploadedTrack;
    if (track == null) return;

    try {
      if (_isPlaying) {
        await ViralScorePredictorService.pauseTrack();
        return;
      }
      await ViralScorePredictorService.playTrack(track.localPath);
    } catch (error, stackTrace) {
      logDebugException('ViralScorePredictorScreen.playback', error, stackTrace: stackTrace);
      AppToast.show('Could not play this track.', isError: true);
    }
  }

  Future<void> _saveToLibrary() async {
    final prediction = _prediction;
    final track = _uploadedTrack;
    if (prediction == null || _isSaving) return;

    final buffer = StringBuffer()
      ..writeln('Viral Score: ${prediction.overallScore}/100')
      ..writeln(prediction.verdictLabel)
      ..writeln()
      ..writeln(prediction.summary)
      ..writeln()
      ..writeln('Breakdown:');
    for (final metric in prediction.metrics) {
      buffer.writeln('${metric.label}: ${metric.score}/100');
    }
    buffer.writeln();
    buffer.writeln('Tips:');
    for (final tip in prediction.improvementTips) {
      buffer.writeln('• $tip');
    }

    setState(() => _isSaving = true);
    try {
      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'viral_score',
          title: track?.fileName ?? 'Viral Score Report',
          sourceTool: 'Viral Score Predictor',
          textContent: buffer.toString().trim(),
          metadata: {
            'overallScore': prediction.overallScore,
            'verdict': prediction.verdictLabel,
            'trackName': track?.fileName,
            'notes': _notesController.text.trim(),
          },
        ),
      );
      AppToast.show('Saved to library.');
    } catch (error) {
      AppToast.show(AiLibraryService.errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showImprovementTips() {
    final prediction = _prediction;
    if (prediction == null) {
      AppToast.show('Predict your viral score first.', isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AiToolsTheme.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Improve Your Score',
                  style: TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prediction.summary,
                  style: const TextStyle(
                    color: AiToolsTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ...prediction.improvementTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: AiToolsTheme.purple,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: AiToolsTheme.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _isBusy => _isUploading || _isPredicting;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiToolsScreen(
          title: 'Viral Score Predictor',
          onInfo: _showInfoDialog,
          children: [
            const AiToolsSectionTitle(text: 'Upload your track'),
            const SizedBox(height: 10),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AiToolsTheme.purple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_uploadedTrack != null)
              _UploadedTrackCard(
                fileName: _uploadedTrack!.fileName,
                duration: _uploadedTrack!.durationLabel,
                isPlaying: _isPlaying,
                onClose: _isBusy ? null : _clearTrack,
                onPlayTap: _togglePlayback,
              )
            else
              _UploadTrackPlaceholder(
                onTap: _isBusy ? () {} : _pickTrack,
              ),
            const SizedBox(height: 18),
            const AiToolsSectionTitle(text: 'Track notes (optional)'),
            const SizedBox(height: 8),
            AiToolsTextArea(
              controller: _notesController,
              maxLength: _maxNotesLength,
              maxLines: 3,
              hintText:
                  'Genre, hook idea, target platform (TikTok, Reels), vibe...',
            ),
            const SizedBox(height: 20),
            IgnorePointer(
              ignoring: _isBusy,
              child: Opacity(
                opacity: _isBusy ? 0.7 : 1,
                child: AiToolsPrimaryButton(
                  label: _isPredicting ? 'Analyzing...' : 'Predict Viral Score',
                  icon: Icons.insights_rounded,
                  onPressed: _predictScore,
                ),
              ),
            ),
            if (_prediction != null) ...[
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'Viral Score',
                  style: TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: _ViralScoreGauge(score: _prediction!.overallScore),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _prediction!.verdictLabel,
                  style: const TextStyle(
                    color: Color(0xFFFFC857),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ..._prediction!.metrics.map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _MetricProgressRow(metric: metric),
                ),
              ),
              const SizedBox(height: 8),
              AiToolsPrimaryButton(
                label: 'Improve My Score',
                onPressed: _showImprovementTips,
              ),
              const SizedBox(height: 10),
              AiToolsOutlineButton(
                label: _isSaving ? 'Saving...' : 'Save to Library',
                onPressed: _isSaving ? () {} : _saveToLibrary,
              ),
            ] else ...[
              const SizedBox(height: 28),
              const AiToolsEmptyState(
                message:
                    'Upload a track and tap Predict Viral Score to see your breakdown.',
              ),
            ],
          ],
        ),
        if (_isPredicting)
          const AiToolsGeneratingOverlay(
            title: 'Analyzing viral potential...',
          ),
      ],
    );
  }
}

class _UploadedTrackCard extends StatelessWidget {
  final String fileName;
  final String duration;
  final bool isPlaying;
  final VoidCallback? onClose;
  final VoidCallback onPlayTap;

  const _UploadedTrackCard({
    required this.fileName,
    required this.duration,
    required this.isPlaying,
    required this.onClose,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AiToolsTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note_rounded,
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
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: AiToolsTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlayTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.close_rounded,
                color: AiToolsTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadTrackPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadTrackPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AiToolsTheme.radiusMd),
        child: AiToolsGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: const Column(
            children: [
              Icon(
                Icons.upload_file_rounded,
                color: AiToolsTheme.textSecondary,
                size: 28,
              ),
              SizedBox(height: 10),
              Text(
                'Tap to upload your track',
                style: TextStyle(
                  color: AiToolsTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViralScoreGauge extends StatelessWidget {
  final int score;

  const _ViralScoreGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 196,
      child: CustomPaint(
        painter: _ViralScoreRingPainter(score: score / 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: AiToolsTheme.textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/100',
                style: TextStyle(
                  color: AiToolsTheme.textSecondary.withValues(alpha: 0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViralScoreRingPainter extends CustomPainter {
  final double score;

  _ViralScoreRingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 14.0;
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = 2 * math.pi * score.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        colors: [
          Color(0xFF4FD1FF),
          Color(0xFF3B5BDB),
          Color(0xFF8AE65C),
          Color(0xFFFFB347),
          Color(0xFF4FD1FF),
        ],
        stops: [0.0, 0.28, 0.55, 0.78, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViralScoreRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}

class _MetricProgressRow extends StatelessWidget {
  final ViralScoreMetric metric;

  const _MetricProgressRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final progress = metric.score / 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                metric.label,
                style: const TextStyle(
                  color: AiToolsTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${metric.score}/100',
              style: const TextStyle(
                color: AiToolsTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: _metricBarGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
