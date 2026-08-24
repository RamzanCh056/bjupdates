import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/script_to_music_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

class ScriptToMusicScreen extends StatefulWidget {
  const ScriptToMusicScreen({super.key});

  @override
  State<ScriptToMusicScreen> createState() => _ScriptToMusicScreenState();
}

class _ScriptToMusicScreenState extends State<ScriptToMusicScreen> {
  static const int _maxScriptLength = 2000;
  static const List<String> _genres = [
    'Cinematic',
    'Orchestral',
    'Electronic',
    'Hip Hop',
  ];
  static const List<String> _moods = [
    'Epic',
    'Dark',
    'Suspense',
    'Emotional',
    'Happy',
  ];
  static const List<String> _durations = ['1:00', '2:00', '3:00', '4:00'];
  static const List<String> _tempos = ['Slow', 'Medium', 'Fast'];

  final TextEditingController _scriptController = TextEditingController();

  final Set<String> _selectedGenres = {'Cinematic'};
  final Set<String> _selectedMoods = {'Epic'};
  String _selectedDuration = '2:00';
  String _selectedTempo = 'Medium';
  double _creativity = 0.75;
  bool _instrumental = true;
  bool _isGenerating = false;
  int _generateProgress = 0;
  Timer? _progressTimer;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isPlaying = false;

  ScriptToMusicTrack? _generatedTrack;

  @override
  void initState() {
    super.initState();
    _scriptController.addListener(() => setState(() {}));
    ScriptToMusicService.playerStateStream.listen((state) {
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
    _progressTimer?.cancel();
    ScriptToMusicService.stop();
    _scriptController.dispose();
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
      title: 'Script to Music',
      message:
          'Turn your script into a cinematic score guide with OpenAI. Choose genre, mood, and duration, then get a production-ready cue breakdown for your scene.',
    );
  }

  void _toggleSelection(Set<String> selected, String value) {
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
  }

  Future<void> _generateMusic() async {
    if (_isGenerating) return;

    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      AppToast.show('Enter your script before generating.', isError: true);
      return;
    }
    if (_selectedGenres.isEmpty || _selectedMoods.isEmpty) {
      AppToast.show('Select at least one genre and one mood.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generateProgress = 1;
    });
    _startProgressTimer();
    await ScriptToMusicService.stop();

    try {
      final track = await ScriptToMusicService.generate(
        script: script,
        genres: _selectedGenres.toList(),
        moods: _selectedMoods.toList(),
        durationLabel: _selectedDuration,
        tempo: _selectedTempo,
        instrumental: _instrumental,
        creativity: _creativity,
      );
      _stopProgressTimer();
      if (!mounted) return;

      setState(() => _generateProgress = 100);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      setState(() {
        _generatedTrack = track;
        _isFavorite = false;
        _isPlaying = false;
        _isGenerating = false;
        _generateProgress = 0;
      });
      AppToast.show('${track.title} score guide is ready.');
    } catch (error, stackTrace) {
      _stopProgressTimer();
      logDebugException('ScriptToMusicScreen.generateMusic', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generateProgress = 0;
        });
        AppToast.show(error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''), isError: true);
      }
    }
  }

  void _showScoreGuide(String guide, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AiToolsTheme.cardElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    guide,
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _togglePlayback() async {
    final track = _generatedTrack;
    if (track == null) return;

    if (!track.hasAudio && track.hasScoreGuide) {
      _showScoreGuide(track.scoreGuide!, track.title);
      return;
    }

    try {
      if (_isPlaying) {
        await ScriptToMusicService.pause();
        return;
      }
      if (ScriptToMusicService.isPlaying) {
        await ScriptToMusicService.resume();
        return;
      }
      await ScriptToMusicService.play(
        track.audioBytes,
        durationSeconds: track.durationSeconds,
      );
    } catch (error, stackTrace) {
      logDebugException('ScriptToMusicScreen.togglePlayback', error, stackTrace: stackTrace);
      AppToast.show('Could not play this track.', isError: true);
    }
  }

  Future<void> _shareTrack() async {
    final track = _generatedTrack;
    if (track == null) return;

    try {
      if (!track.hasAudio && track.hasScoreGuide) {
        await SharePlus.instance.share(
          ShareParams(
            text: track.scoreGuide!,
            subject: track.title,
          ),
        );
        return;
      }

      final file = await ScriptToMusicService.writeShareableFile(track.audioBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: track.title,
        ),
      );
    } catch (error, stackTrace) {
      logDebugException('ScriptToMusicScreen.shareTrack', error, stackTrace: stackTrace);
      AppToast.show('Could not share this track.', isError: true);
    }
  }

  Future<void> _saveToLibrary() async {
    final track = _generatedTrack;
    if (track == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'script_music',
          title: track.title,
          sourceTool: 'Script to Music',
          textContent: track.scoreGuide ?? track.meta,
          audioBytes: track.hasAudio ? track.audioBytes : null,
          audioFileName: track.hasAudio ? '${track.title}.mp3' : null,
          metadata: {
            'genres': track.genres,
            'moods': track.moods,
            'duration': track.lengthLabel,
          },
        ),
      );
      if (mounted) setState(() => _isFavorite = true);
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
          title: 'Script to Music',
          onInfo: _showInfoDialog,
          children: [
            const AiToolsSectionTitle(text: 'Enter your script'),
            const SizedBox(height: 10),
            AiToolsTextArea(
              controller: _scriptController,
              maxLength: _maxScriptLength,
              maxLines: 6,
              hintText:
                  'Describe the scene, emotion, and pacing of your script...',
            ),
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Choose a Genre / Mood'),
            const SizedBox(height: 12),
            _buildChipWrap(_genres, _selectedGenres),
            const SizedBox(height: 10),
            _buildChipWrap(_moods, _selectedMoods),
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Duration'),
            const SizedBox(height: 10),
            AiToolsDropdown(
              value: _selectedDuration,
              items: _durations,
              onChanged: (value) {
                if (_isGenerating || value == null) return;
                setState(() => _selectedDuration = value);
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
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Advanced Settings'),
            const SizedBox(height: 12),
            _AdvancedSettingsCard(
              instrumental: _instrumental,
              tempo: _selectedTempo,
              tempos: _tempos,
              enabled: !_isGenerating,
              onInstrumentalChanged: (value) =>
                  setState(() => _instrumental = value),
              onTempoChanged: (value) {
                if (value == null) return;
                setState(() => _selectedTempo = value);
              },
            ),
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: _isGenerating,
              child: Opacity(
                opacity: _isGenerating ? 0.7 : 1,
                child: AiToolsPrimaryButton(
                  label: _isGenerating
                      ? 'Creating Score Guide...'
                      : 'Generate Score Guide',
                  icon: Icons.music_note_rounded,
                  onPressed: _generateMusic,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const AiToolsSectionTitle(text: 'Generated Score'),
            const SizedBox(height: 10),
            if (_generatedTrack != null)
              _GeneratedTrackCard(
                track: _generatedTrack!,
                isFavorite: _isFavorite,
                isPlaying: _isPlaying,
                onPlayTap: _togglePlayback,
                onFavoriteTap: _saveToLibrary,
                onShareTap: _shareTrack,
              )
            else
              const AiToolsEmptyState(
                message: 'Your score guide will appear here.',
              ),
          ],
        ),
        if (_isGenerating)
          AiToolsGeneratingOverlay(
            progress: _generateProgress,
            title: 'Creating your score guide...',
            subtitle: 'Powered by OpenAI',
          ),
      ],
    );
  }

  Widget _buildChipWrap(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return AiToolsChip(
          label: option,
          isSelected: isSelected,
          onTap: _isGenerating
              ? () {}
              : () => _toggleSelection(selected, option),
        );
      }).toList(),
    );
  }
}

class _AdvancedSettingsCard extends StatelessWidget {
  final bool instrumental;
  final String tempo;
  final List<String> tempos;
  final bool enabled;
  final ValueChanged<bool> onInstrumentalChanged;
  final ValueChanged<String?> onTempoChanged;

  const _AdvancedSettingsCard({
    required this.instrumental,
    required this.tempo,
    required this.tempos,
    required this.enabled,
    required this.onInstrumentalChanged,
    required this.onTempoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Instrumental',
                  style: TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: instrumental,
                onChanged: enabled ? onInstrumentalChanged : null,
                activeThumbColor: Colors.white,
                activeTrackColor: AiToolsTheme.purple,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tempo',
                  style: TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: AiToolsDropdown(
                  value: tempo,
                  items: tempos,
                  onChanged: (value) {
                    if (!enabled) return;
                    onTempoChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneratedTrackCard extends StatelessWidget {
  final ScriptToMusicTrack track;
  final bool isFavorite;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onShareTap;

  const _GeneratedTrackCard({
    required this.track,
    required this.isFavorite,
    required this.isPlaying,
    required this.onPlayTap,
    required this.onFavoriteTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGuideOnly = !track.hasAudio && track.hasScoreGuide;

    return AiToolsGlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackThumbnail(
                genres: track.genres,
                moods: track.moods,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuideOnly ? 'OpenAI score guide' : track.meta,
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
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGuideOnly
                        ? Icons.article_outlined
                        : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    color: Colors.black,
                    size: isGuideOnly ? 20 : 24,
                  ),
                ),
              ),
            ],
          ),
          if (isGuideOnly && track.scoreGuide != null) ...[
            const SizedBox(height: 12),
            Text(
              track.scoreGuide!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onPlayTap,
              child: const Text('View full score guide'),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: AiToolsWaveform(
                    heights: kAiToolsWaveformHeights,
                    height: 28,
                    color: Color(0xFFB8B8B8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  track.lengthLabel,
                  style: const TextStyle(
                    color: AiToolsTheme.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? AiToolsTheme.pink : Colors.white,
                ),
              ),
              IconButton(
                onPressed: onShareTap,
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: AiToolsTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackThumbnail extends StatelessWidget {
  final List<String> genres;
  final List<String> moods;

  const _TrackThumbnail({
    required this.genres,
    required this.moods,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(genres, moods);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.9),
                const Color(0xFF1A1030),
              ],
            ),
          ),
          child: const Icon(
            Icons.movie_filter_rounded,
            color: Colors.white70,
            size: 28,
          ),
        ),
      ),
    );
  }

  Color _accentColor(List<String> genres, List<String> moods) {
    if (moods.contains('Dark') || moods.contains('Suspense')) {
      return const Color(0xFF4A1F7A);
    }
    if (moods.contains('Happy') || moods.contains('Epic')) {
      return const Color(0xFF7A3A1F);
    }
    if (genres.contains('Electronic')) {
      return const Color(0xFF1F4A7A);
    }
    return const Color(0xFF3A2A5A);
  }
}
