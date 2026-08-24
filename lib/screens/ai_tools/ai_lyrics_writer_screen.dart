import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/ai_lyrics_writer_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AiLyricsWriterScreen extends StatefulWidget {
  const AiLyricsWriterScreen({super.key});

  @override
  State<AiLyricsWriterScreen> createState() => _AiLyricsWriterScreenState();
}

class _AiLyricsWriterScreenState extends State<AiLyricsWriterScreen> {
  static const int _maxDescriptionLength = 200;
  static const List<String> _genres = [
    'Rap',
    'Pop',
    'R&B',
    'Rock',
    'EDM',
  ];
  static const List<String> _moods = [
    'Motivational',
    'Chill',
    'Happy',
    'Sad',
    'Dark',
  ];
  static const List<String> _structures = [
    'Verse - Chorus - Verse - Chorus - Bridge - Chorus',
    'Verse - Chorus - Verse - Chorus',
    'Intro - Verse - Chorus - Bridge - Chorus',
    'Verse - Pre-Chorus - Chorus',
  ];
  static const List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'Hindi',
    'Portuguese',
  ];

  final TextEditingController _descriptionController = TextEditingController();

  String _selectedGenre = 'Rap';
  String _selectedMood = 'Motivational';
  String _selectedStructure = _structures.first;
  String _selectedLanguage = 'English';
  double _creativity = 0.7;
  bool _hasGeneratedLyrics = false;
  bool _isGenerating = false;
  int _generateProgress = 0;
  String _generatedLyrics = '';
  Timer? _progressTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_generateProgress < 92) {
          _generateProgress = (_generateProgress + 1 + math.Random().nextInt(2))
              .clamp(1, 92);
        }
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _showInfoDialog() {
    AiToolsInfoDialog.show(
      context,
      title: 'AI Lyrics Writer',
      message:
          'Describe your song, choose genre and mood, then generate structured lyrics powered by OpenAI.',
    );
  }

  Future<void> _generateLyrics() async {
    if (_isGenerating) return;

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      AppToast.show('Describe your song before generating.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generateProgress = 1;
      _hasGeneratedLyrics = false;
      _generatedLyrics = '';
    });
    _startProgressTimer();

    try {
      final lyrics = await AiLyricsWriterService.generate(
        AiLyricsWriterRequest(
          description: description,
          genre: _selectedGenre,
          mood: _selectedMood,
          structure: _selectedStructure,
          language: _selectedLanguage,
          creativity: _creativity,
        ),
      );

      _stopProgressTimer();
      if (!mounted) return;

      setState(() => _generateProgress = 100);
      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;
      setState(() {
        _hasGeneratedLyrics = true;
        _generatedLyrics = lyrics;
        _isGenerating = false;
      });
      AppToast.show('Lyrics generated.');
    } catch (error, stackTrace) {
      _stopProgressTimer();
      logDebugException('AiLyricsWriterScreen.generate', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generateProgress = 0;
        });
      }
      AppToast.show(AiLyricsWriterService.errorMessage(error), isError: true);
    }
  }

  Future<void> _copyLyrics() async {
    await Clipboard.setData(ClipboardData(text: _generatedLyrics));
    AppToast.show('Lyrics copied to clipboard.');
  }

  Future<void> _shareLyrics() async {
    await Share.share(_generatedLyrics, subject: 'Song lyrics from BJ AI');
  }

  Future<void> _saveToLibrary() async {
    if (!_hasGeneratedLyrics || _isSaving) return;

    final description = _descriptionController.text.trim();
    final title = description.isEmpty
        ? 'Song Lyrics'
        : (description.length > 48 ? '${description.substring(0, 45)}...' : description);

    setState(() => _isSaving = true);
    try {
      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'lyrics',
          title: title,
          sourceTool: 'AI Lyrics Writer',
          textContent: _generatedLyrics,
          metadata: {
            'genre': _selectedGenre,
            'mood': _selectedMood,
            'structure': _selectedStructure,
            'language': _selectedLanguage,
            'description': description,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiToolsScreen(
          title: 'AI Lyrics Writer',
          onInfo: _showInfoDialog,
          children: [
            const AiToolsSectionTitle(text: 'Describe your song'),
            const SizedBox(height: 10),
            AiToolsTextArea(
              controller: _descriptionController,
              maxLength: _maxDescriptionLength,
              hintText: 'Describe the story, mood, and message of your song...',
            ),
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Choose a Genre / Mood'),
            const SizedBox(height: 12),
            _buildGenreWrap(),
            const SizedBox(height: 10),
            _buildMoodWrap(),
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Song Structure'),
            const SizedBox(height: 10),
            AiToolsDropdown(
              value: _selectedStructure,
              items: _structures,
              onChanged: (value) {
                if (value == null || _isGenerating) return;
                setState(() => _selectedStructure = value);
              },
            ),
            const SizedBox(height: 16),
            const AiToolsSectionTitle(text: 'Language'),
            const SizedBox(height: 10),
            AiToolsDropdown(
              value: _selectedLanguage,
              items: _languages,
              onChanged: (value) {
                if (value == null || _isGenerating) return;
                setState(() => _selectedLanguage = value);
              },
            ),
            const SizedBox(height: 16),
            AiToolsSlider(
              label: 'Creativity',
              value: _creativity,
              onChanged: (value) {
                if (_isGenerating) return;
                setState(() => _creativity = value);
              },
            ),
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: _isGenerating,
              child: Opacity(
                opacity: _isGenerating ? 0.7 : 1,
                child: AiToolsPrimaryButton(
                  label: _isGenerating ? 'Generating...' : 'Generate Lyrics',
                  onPressed: _generateLyrics,
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (_hasGeneratedLyrics) ...[
              AiToolsSectionTitle(
                text: 'Generated Lyrics',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _copyLyrics,
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AiToolsTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: _shareLyrics,
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: AiToolsTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GeneratedLyricsCard(lyrics: _generatedLyrics),
              const SizedBox(height: 16),
              AiToolsOutlineButton(
                label: _isSaving ? 'Saving...' : 'Save to Library',
                onPressed: _isSaving ? () {} : _saveToLibrary,
              ),
            ],
          ],
        ),
        if (_isGenerating)
          _LyricsProgressOverlay(progress: _generateProgress),
      ],
    );
  }

  Widget _buildGenreWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genres.map((genre) {
        return AiToolsChip(
          label: genre,
          isSelected: _selectedGenre == genre,
          useGradientWhenSelected: false,
          onTap: _isGenerating ? () {} : () => setState(() => _selectedGenre = genre),
        );
      }).toList(),
    );
  }

  Widget _buildMoodWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _moods.map((mood) {
        return AiToolsChip(
          label: mood,
          isSelected: _selectedMood == mood,
          onTap: _isGenerating ? () {} : () => setState(() => _selectedMood = mood),
        );
      }).toList(),
    );
  }
}

class _LyricsProgressOverlay extends StatelessWidget {
  final int progress;

  const _LyricsProgressOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = (progress / 100).clamp(0.0, 1.0);

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$progress%',
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 240,
                      height: 6,
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: const Color(0x33FFFFFF),
                        color: AiToolsTheme.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Writing your lyrics...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

class _GeneratedLyricsCard extends StatelessWidget {
  final String lyrics;

  const _GeneratedLyricsCard({required this.lyrics});

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Stack(
        children: [
          const Positioned.fill(
            child: _LyricsBackdrop(),
          ),
          SelectableText(
            lyrics,
            style: TextStyle(
              color: AiToolsTheme.textPrimary.withValues(alpha: 0.82),
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsBackdrop extends StatelessWidget {
  const _LyricsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(220, 220),
        painter: _MandalaPainter(),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, size.width * 0.34, paint);
    canvas.drawCircle(center, size.width * 0.24, paint);
    canvas.drawCircle(center, size.width * 0.14, paint);

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dx = math.cos(angle) * size.width * 0.34;
      final dy = math.sin(angle) * size.width * 0.34;
      canvas.drawLine(center, center + Offset(dx, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
