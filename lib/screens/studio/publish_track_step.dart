import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/screens/studio/studio_track_models.dart';
import 'package:beatjerky/screens/studio/track_published_screen.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';

class PublishTrackStep extends StatefulWidget {
  final GeneratedBeat beat;
  final StudioTrackAnalysis analysis;
  final String selectedMood;
  final VoidCallback? onBack;
  final VoidCallback onPublished;

  const PublishTrackStep({
    super.key,
    required this.beat,
    required this.analysis,
    required this.selectedMood,
    this.onBack,
    required this.onPublished,
  });

  @override
  State<PublishTrackStep> createState() => _PublishTrackStepState();
}

class _PublishTrackStepState extends State<PublishTrackStep> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  int _selectedCover = 1;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    final defaultTitle = widget.beat.title.trim().isNotEmpty
        ? widget.beat.title.trim()
        : 'Rainy Night Vibes';
    _titleController = TextEditingController(text: defaultTitle);
    _descriptionController = TextEditingController(
      text: widget.beat.summary.trim(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _meta {
    final genre = widget.analysis.genre.split('/').first.trim();
    final cap = genre.isEmpty
        ? 'Trap'
        : genre[0].toUpperCase() + genre.substring(1);
    return '$cap · ${widget.analysis.bpm} BPM · ${widget.beat.length} · ${widget.selectedMood}';
  }

  String get _genreLabel {
    final genre = widget.analysis.genre.split('/').first.trim();
    if (genre.isEmpty) return 'Dark Trap';
    return genre[0].toUpperCase() + genre.substring(1);
  }

  String _libraryText() {
    final buffer = StringBuffer()
      ..writeln(_titleController.text.trim())
      ..writeln(_meta)
      ..writeln()
      ..writeln(_descriptionController.text.trim());
    if (widget.beat.hasBlueprint) {
      buffer
        ..writeln()
        ..writeln('Blueprint')
        ..writeln(widget.beat.summary)
        ..writeln(widget.beat.arrangement)
        ..writeln(widget.beat.drums)
        ..writeln(widget.beat.bass)
        ..writeln(widget.beat.melody)
        ..writeln(widget.beat.mixNotes);
    }
    return buffer.toString().trim();
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Track'
        : _titleController.text.trim();

    try {
      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'co_producer_track',
          title: title,
          sourceTool: 'AI Co-Producer',
          textContent: _libraryText(),
          metadata: {
            'genre': widget.analysis.genre,
            'bpm': widget.analysis.bpm,
            'key': widget.analysis.key,
            'mood': widget.selectedMood,
            'beatId': widget.beat.id,
            if (widget.beat.previewAudioUrl != null)
              'previewAudioUrl': widget.beat.previewAudioUrl,
          },
        ),
      );

      if (!mounted) return;
      AppToast.show('Saved to your AI library.');
      openTrackPublished(
        context,
        trackTitle: title,
        genre: _genreLabel,
      );
      // Published screen handles returning home; don't pop the stack here.
    } catch (error, stackTrace) {
      logDebugException('PublishTrackStep.publish', error, stackTrace: stackTrace);
      AppToast.show(
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioFlowScaffold(
      title: 'Publish Your Track',
      currentStep: 4,
      onBack: widget.onBack,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '05 · PUBLISH TRACK',
              style: TextStyle(
                color: StudioFlowTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            _TrackSummaryCard(
              title: _titleController.text.isEmpty
                  ? 'Untitled Track'
                  : _titleController.text,
              meta: _meta,
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _titleController,
              hint: 'Track title',
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: _descriptionController,
              hint: 'Add a description... (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            const Text(
              'COVER ART',
              style: TextStyle(
                color: StudioFlowTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CoverOption(
                    type: _CoverOptionType.generateAi,
                    selected: _selectedCover == 0,
                    onTap: () => setState(() => _selectedCover = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CoverOption(
                    type: _CoverOptionType.presetArt,
                    emoji: '🌙',
                    selected: _selectedCover == 1,
                    onTap: () => setState(() => _selectedCover = 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CoverOption(
                    type: _CoverOptionType.upload,
                    selected: _selectedCover == 2,
                    onTap: () => setState(() => _selectedCover = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: StudioFlowTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: StudioFlowTheme.purple.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _publishing ? null : _publish,
                    borderRadius: BorderRadius.circular(27),
                    child: Center(
                      child: _publishing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '🚀 Publish to Feed',
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
          ],
        ),
      ),
    );
  }
}

class _TrackSummaryCard extends StatelessWidget {
  final String title;
  final String meta;

  const _TrackSummaryCard({required this.title, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: StudioFlowTheme.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: StudioFlowTheme.purple.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: const TextStyle(
                        color: StudioFlowTheme.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _StatusBadge(label: 'VOCALS ENHANCED'),
              _StatusBadge(label: 'MIXED'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: StudioFlowTheme.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: StudioFlowTheme.purple.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '✅ $label',
        style: const TextStyle(
          color: StudioFlowTheme.purple,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: StudioFlowTheme.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: StudioFlowTheme.textMuted),
        filled: true,
        fillColor: StudioFlowTheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

enum _CoverOptionType { generateAi, presetArt, upload }

class _CoverOption extends StatelessWidget {
  final _CoverOptionType type;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _CoverOption({
    required this.type,
    this.emoji = '🌙',
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPreset = type == _CoverOptionType.presetArt;
    final isDashed = !isPreset;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isDashed)
              CustomPaint(
                painter: _DashedBorderPainter(
                  radius: 16,
                  color: const Color(0xFF4B5563),
                ),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161920).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: _buildContent()),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: StudioFlowTheme.purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: _buildContent()),
              ),
            if (isPreset && selected)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: StudioFlowTheme.background,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case _CoverOptionType.generateAi:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎨', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                'Generate with AI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        );
      case _CoverOptionType.presetArt:
        return Text(emoji, style: const TextStyle(fontSize: 40));
      case _CoverOptionType.upload:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📷', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              'Upload',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  final Color color;

  const _DashedBorderPainter({
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
      Radius.circular(radius),
    );

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        final extractPath = metric.extractPath(
          distance,
          next.clamp(0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
