import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/ai_tools/ai_now_playing_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class RecentBeatsScreen extends StatefulWidget {
  final bool favoritesOnly;

  const RecentBeatsScreen({
    super.key,
    this.favoritesOnly = false,
  });

  @override
  State<RecentBeatsScreen> createState() => _RecentBeatsScreenState();
}

class _RecentBeatsScreenState extends State<RecentBeatsScreen> {
  String? _playingBeatId;

  @override
  void initState() {
    super.initState();
    AiBeatGeneratorService.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingBeatId = null);
      }
    });
  }

  Future<void> _handlePlay(GeneratedBeat beat) async {
    if (beat.isGenerating) {
      AppToast.show('This beat is still generating.');
      return;
    }
    if (beat.isFailed) {
      _showBeatDetails(beat);
      return;
    }

    final audioUrl = beat.previewAudioUrl?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      _showBeatDetails(beat);
      return;
    }

    try {
      await openAiBeatNowPlaying(context, beat);
      if (!mounted) return;
      setState(() => _playingBeatId = AiBeatGeneratorService.playingBeatId);
    } catch (error, stackTrace) {
      logDebugException('RecentBeatsScreen.playBeat', error, stackTrace: stackTrace);
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _toggleFavorite(GeneratedBeat beat, bool isFavorite) async {
    try {
      await AiBeatGeneratorService.setFavorite(
        beatId: beat.id,
        isFavorite: isFavorite,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'RecentBeatsScreen.toggleFavorite',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _deleteBeat(GeneratedBeat beat) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiToolsTheme.cardElevated,
        title: const Text(
          'Delete beat?',
          style: TextStyle(color: AiToolsTheme.textPrimary),
        ),
        content: Text(
          'Remove "${beat.title}" from your library? This cannot be undone.',
          style: const TextStyle(color: AiToolsTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await AiBeatGeneratorService.deleteBeat(beat.id);
      if (!mounted) return;
      AppToast.show('Beat removed.');
    } catch (error, stackTrace) {
      logDebugException('RecentBeatsScreen.deleteBeat', error, stackTrace: stackTrace);
      AppToast.show(error.toString(), isError: true);
    }
  }

  void _showBeatDetails(GeneratedBeat beat) {
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
                    beat.title,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${beat.bpm} BPM • ${beat.keyLabel} • ${beat.length}',
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (beat.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(
                      title: 'Description',
                      body: beat.description,
                    ),
                  ],
                  if (beat.genres.isNotEmpty || beat.moods.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(
                      title: 'Genre / Mood',
                      body:
                          '${beat.genres.join(', ')} • ${beat.moods.join(', ')}',
                    ),
                  ],
                  if (beat.summary.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(title: 'AI prompt', body: beat.summary),
                  ],
                  if (beat.arrangement.isNotEmpty)
                    _BeatDetailSection(
                      title: 'Arrangement',
                      body: beat.arrangement,
                    ),
                  if (beat.drums.isNotEmpty)
                    _BeatDetailSection(title: 'Drums', body: beat.drums),
                  if (beat.bass.isNotEmpty)
                    _BeatDetailSection(title: 'Bass', body: beat.bass),
                  if (beat.melody.isNotEmpty)
                    _BeatDetailSection(title: 'Melody', body: beat.melody),
                  if (beat.mixNotes.isNotEmpty)
                    _BeatDetailSection(title: 'Mix notes', body: beat.mixNotes),
                  if (beat.errorMessage != null &&
                      beat.errorMessage!.isNotEmpty)
                    _BeatDetailSection(title: 'Error', body: beat.errorMessage!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiToolsTheme.background,
      body: Stack(
        children: [
          const AiToolsAmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                AiToolsTopBar(
                  title: widget.favoritesOnly ? 'Favorite Beats' : 'Recent Beats',
                ),
                Expanded(
                  child: _RecentBeatsList(
                    favoritesOnly: widget.favoritesOnly,
                    previewCount: null,
                    playingBeatId: _playingBeatId,
                    onPlay: _handlePlay,
                    onOpenDetails: _showBeatDetails,
                    onFavoriteChanged: _toggleFavorite,
                    onDelete: _deleteBeat,
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

class _BeatDetailSection extends StatelessWidget {
  final String title;
  final String body;

  const _BeatDetailSection({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AiToolsTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class RecentBeatCard extends StatelessWidget {
  final GeneratedBeat beat;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onOpenDetails;
  final ValueChanged<bool> onFavoriteChanged;
  final VoidCallback? onDelete;

  const RecentBeatCard({
    super.key,
    required this.beat,
    required this.isPlaying,
    required this.onPlay,
    required this.onOpenDetails,
    required this.onFavoriteChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final audioUrl = beat.previewAudioUrl?.trim();
          if (!beat.isGenerating &&
              !beat.isFailed &&
              audioUrl != null &&
              audioUrl.isNotEmpty) {
            onPlay();
            return;
          }
          onOpenDetails();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AiToolsTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AiToolsTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AiToolsTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    beat.isGenerating
                        ? Icons.hourglass_top_rounded
                        : beat.isFailed
                            ? Icons.error_outline_rounded
                            : Icons.music_note_rounded,
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
                        beat.title,
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
                        beat.isFailed
                            ? 'Generation failed'
                            : beat.description.isNotEmpty
                                ? beat.description
                                : '${beat.bpm} BPM • ${beat.keyLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AiToolsTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  beat.length,
                  style: const TextStyle(
                    color: AiToolsTheme.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: isPlaying
                          ? Border.all(color: AiToolsTheme.purple, width: 2)
                          : null,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AiToolsTheme.textSecondary,
                  ),
                  color: AiToolsTheme.cardElevated,
                  onSelected: (value) {
                    if (value == 'favorite') {
                      onFavoriteChanged(!beat.isFavorite);
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(
                        beat.isFavorite
                            ? 'Remove favorite'
                            : 'Add to favorites',
                        style: const TextStyle(color: AiToolsTheme.textPrimary),
                      ),
                    ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiBeatGeneratorScreen extends StatefulWidget {
  const AiBeatGeneratorScreen({super.key});

  @override
  State<AiBeatGeneratorScreen> createState() => _AiBeatGeneratorScreenState();
}

class _AiBeatGeneratorScreenState extends State<AiBeatGeneratorScreen> {
  static const int _maxDescriptionLength = 200;
  static const int _previewBeatCount = 3;
  static const List<String> _genres = [
    'Trap',
    'Drill',
    'Hip Hop',
    'Lo-Fi',
    'R&B',
  ];
  static const List<String> _moods = [
    'Dark',
    'Aggressive',
    'Chill',
    'Happy',
    'Sad',
  ];
  static const List<String> _keys = [
    'C Minor',
    'C Major',
    'D Minor',
    'D Major',
    'E Minor',
    'F Minor',
    'G Minor',
    'A Minor',
  ];
  static const List<String> _lengths = [
    '0:30',
    '1:00',
    '1:30',
    '2:00',
    '3:00',
  ];

  final TextEditingController _descriptionController = TextEditingController();

  final Set<String> _selectedGenres = <String>{};
  final Set<String> _selectedMoods = <String>{};

  double _bpm = 140;
  String _selectedKey = 'C Minor';
  String _selectedLength = '1:30';
  bool _isGenerating = false;
  int _generateProgress = 0;
  Timer? _progressTimer;
  String? _playingBeatId;

  @override
  void initState() {
    super.initState();
    _selectedGenres.add(_genres.first);
    _selectedMoods.add(_moods.first);
    _descriptionController.addListener(() => setState(() {}));
    AiBeatGeneratorService.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingBeatId = null);
      }
    });
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

  void _toggleSelection(Set<String> selected, String value) {
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
  }

  Future<void> _generateBeat() async {
    if (_isGenerating) return;

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      AppToast.show('Describe your beat before generating.', isError: true);
      return;
    }
    if (_selectedGenres.isEmpty || _selectedMoods.isEmpty) {
      AppToast.show('Select at least one genre and one mood.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to generate beats.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generateProgress = 1;
    });
    _startProgressTimer();
    try {
      final result = await AiBeatGeneratorService.generateBeat(
        description: description,
        genres: _selectedGenres.toList(),
        moods: _selectedMoods.toList(),
        bpm: _bpm.round(),
        keyLabel: _selectedKey,
        length: _selectedLength,
      );
      _stopProgressTimer();
      if (!mounted) return;

      setState(() => _generateProgress = 100);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      if (result.usedLocalPromptFallback) {
        AppToast.show(
          'Beat blueprint created with a local fallback. Add a valid OpenAI key for smarter results.',
          isError: true,
        );
      } else if (result.beat.hasPlayableAudio) {
        AppToast.show('${result.beat.title} is ready to play.');
      } else {
        AppToast.show('${result.beat.title} blueprint saved to your library.');
      }
      _showBeatDetails(result.beat);
    } catch (error, stackTrace) {
      _stopProgressTimer();
      logDebugException('AiBeatGeneratorScreen.generateBeat', error, stackTrace: stackTrace);
      AppToast.show(
        AiBeatGeneratorService.beatGenerationErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generateProgress = 0;
        });
      }
    }
  }

  void _openAllRecentBeats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecentBeatsScreen(),
      ),
    );
  }

  void _openFavoriteBeats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to view favorite beats.', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecentBeatsScreen(
          favoritesOnly: true,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(GeneratedBeat beat, bool isFavorite) async {
    try {
      await AiBeatGeneratorService.setFavorite(
        beatId: beat.id,
        isFavorite: isFavorite,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorScreen.toggleFavorite',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _deleteBeat(GeneratedBeat beat) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiToolsTheme.cardElevated,
        title: const Text(
          'Delete beat?',
          style: TextStyle(color: AiToolsTheme.textPrimary),
        ),
        content: Text(
          'Remove "${beat.title}" from your library? This cannot be undone.',
          style: const TextStyle(color: AiToolsTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await AiBeatGeneratorService.deleteBeat(beat.id);
      if (!mounted) return;
      AppToast.show('Beat removed.');
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorScreen.deleteBeat',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _handlePlay(GeneratedBeat beat) async {
    if (beat.isGenerating) {
      AppToast.show('This beat is still generating.');
      return;
    }
    if (beat.isFailed) {
      _showBeatDetails(beat);
      return;
    }

    final audioUrl = beat.previewAudioUrl?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      _showBeatDetails(beat);
      return;
    }

    try {
      await openAiBeatNowPlaying(context, beat);
      if (!mounted) return;
      setState(() => _playingBeatId = AiBeatGeneratorService.playingBeatId);
    } catch (error, stackTrace) {
      logDebugException(
        'AiBeatGeneratorScreen.playBeat',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(error.toString(), isError: true);
    }
  }

  void _showBeatDetails(GeneratedBeat beat) {
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
                    beat.title,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${beat.bpm} BPM • ${beat.keyLabel} • ${beat.length}',
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (beat.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(
                      title: 'Description',
                      body: beat.description,
                    ),
                  ],
                  if (beat.genres.isNotEmpty || beat.moods.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(
                      title: 'Genre / Mood',
                      body:
                          '${beat.genres.join(', ')} • ${beat.moods.join(', ')}',
                    ),
                  ],
                  if (beat.summary.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BeatDetailSection(title: 'AI prompt', body: beat.summary),
                  ],
                  if (beat.arrangement.isNotEmpty)
                    _BeatDetailSection(
                      title: 'Arrangement',
                      body: beat.arrangement,
                    ),
                  if (beat.drums.isNotEmpty)
                    _BeatDetailSection(title: 'Drums', body: beat.drums),
                  if (beat.bass.isNotEmpty)
                    _BeatDetailSection(title: 'Bass', body: beat.bass),
                  if (beat.melody.isNotEmpty)
                    _BeatDetailSection(title: 'Melody', body: beat.melody),
                  if (beat.mixNotes.isNotEmpty)
                    _BeatDetailSection(title: 'Mix notes', body: beat.mixNotes),
                  if (beat.errorMessage != null &&
                      beat.errorMessage!.isNotEmpty)
                    _BeatDetailSection(title: 'Error', body: beat.errorMessage!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        return Stack(
          children: [
            AiToolsScreen(
          title: 'AI Beat Generator',
          topAction: IconButton(
            onPressed: _openFavoriteBeats,
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AiToolsTheme.pink,
            ),
          ),
          children: [
            const AiToolsSectionTitle(text: 'Describe your beat'),
            const SizedBox(height: 10),
            AiToolsTextArea(
              controller: _descriptionController,
              maxLength: _maxDescriptionLength,
              hintText:
                  'Describe the vibe, drums, bass, and energy you want...',
            ),
            const SizedBox(height: 22),
            const AiToolsSectionTitle(text: 'Genre / Mood'),
            const SizedBox(height: 12),
            _buildChipWrap(
              _genres,
              _selectedGenres,
              useGradientWhenSelected: false,
            ),
            const SizedBox(height: 10),
            _buildChipWrap(_moods, _selectedMoods),
            const SizedBox(height: 22),
            _buildBpmRow(),
            const SizedBox(height: 16),
            _buildDropdownRow(
              label: 'Key',
              value: _selectedKey,
              items: _keys,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedKey = value);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdownRow(
              label: 'Length',
              value: _selectedLength,
              items: _lengths,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedLength = value);
              },
            ),
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: _isGenerating,
              child: Opacity(
                opacity: _isGenerating ? 0.7 : 1,
                child: AiToolsPrimaryButton(
                  label: _isGenerating
                      ? 'Creating Beat Blueprint...'
                      : 'Generate Beat',
                  onPressed: _generateBeat,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildRecentBeatsHeader(),
            const SizedBox(height: 12),
            if (user == null)
              const AiToolsEmptyState(
                message:
                    'Sign in to generate beats and sync your recent creations.',
              )
            else
              _RecentBeatsList(
                favoritesOnly: false,
                previewCount: _previewBeatCount,
                showLoadingIndicator: false,
                playingBeatId: _playingBeatId,
                onPlay: _handlePlay,
                onOpenDetails: _showBeatDetails,
                onFavoriteChanged: _toggleFavorite,
                onDelete: _deleteBeat,
              ),
          ],
            ),
            if (_isGenerating)
              AiToolsGeneratingOverlay(
                progress: _generateProgress,
                title: 'Creating your beat blueprint...',
                subtitle: 'Powered by OpenAI',
              ),
          ],
        );
      },
    );
  }

  Widget _buildChipWrap(
    List<String> options,
    Set<String> selected, {
    bool useGradientWhenSelected = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return AiToolsChip(
          label: option,
          isSelected: isSelected,
          useGradientWhenSelected: useGradientWhenSelected,
          onTap: () => _toggleSelection(selected, option),
        );
      }).toList(),
    );
  }

  Widget _buildBpmRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiToolsSectionTitle(text: 'BPM'),
              const SizedBox(height: 10),
              Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AiToolsTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AiToolsTheme.border),
                ),
                child: Text(
                  _bpm.round().toString(),
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AiToolsTheme.purple,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: AiToolsTheme.purple,
              overlayColor: AiToolsTheme.purple.withValues(alpha: 0.16),
              trackHeight: 4,
            ),
            child: Slider(
              min: 60,
              max: 200,
              value: _bpm,
              onChanged: (value) => setState(() => _bpm = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: AiToolsDropdown(
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBeatsHeader() {
    return AiToolsSectionTitle(
      text: 'Recent Beats',
      trailing: TextButton(
        onPressed: _openAllRecentBeats,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'View All',
          style: TextStyle(
            color: AiToolsTheme.purple,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecentBeatsList extends StatelessWidget {
  final bool favoritesOnly;
  final int? previewCount;
  final bool showLoadingIndicator;
  final String? playingBeatId;
  final void Function(GeneratedBeat beat)? onPlay;
  final void Function(GeneratedBeat beat)? onOpenDetails;
  final void Function(GeneratedBeat beat, bool isFavorite)? onFavoriteChanged;
  final void Function(GeneratedBeat beat)? onDelete;

  const _RecentBeatsList({
    required this.favoritesOnly,
    required this.previewCount,
    this.showLoadingIndicator = true,
    this.playingBeatId,
    this.onPlay,
    this.onOpenDetails,
    this.onFavoriteChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GeneratedBeat>>(
      stream: AiBeatGeneratorService.watchUserBeats(
        favoritesOnly: favoritesOnly,
        limit: previewCount == null ? 50 : 20,
      ),
      builder: (context, snapshot) {
        final isWaiting =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

        if (isWaiting) {
          if (!showLoadingIndicator) {
            return const SizedBox.shrink();
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AiToolsTheme.purple,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          logDebugException(
            'AiBeatGeneratorScreen.recentBeatsStream',
            snapshot.error!,
            stackTrace: snapshot.stackTrace,
          );
          return AiToolsEmptyState(
            message: 'Could not load beats. ${snapshot.error}',
          );
        }

        final beats = snapshot.data ?? const <GeneratedBeat>[];
        final visibleBeats = previewCount == null
            ? beats
            : beats.take(previewCount!).toList();

        if (visibleBeats.isEmpty) {
          return AiToolsEmptyState(
            message: favoritesOnly
                ? 'No favorite beats yet. Heart a beat to pin it here.'
                : 'No beats yet. Generate your first beat to see it here.',
          );
        }

        return ListView.separated(
          shrinkWrap: previewCount != null,
          physics: previewCount != null
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: previewCount == null ? AiToolsTheme.screenPadding : EdgeInsets.zero,
          itemCount: visibleBeats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final beat = visibleBeats[index];
            return RecentBeatCard(
              beat: beat,
              isPlaying: playingBeatId == beat.id,
              onPlay: () => onPlay?.call(beat),
              onOpenDetails: () => onOpenDetails?.call(beat),
              onFavoriteChanged: (isFavorite) =>
                  onFavoriteChanged?.call(beat, isFavorite),
              onDelete: onDelete == null ? null : () => onDelete?.call(beat),
            );
          },
        );
      },
    );
  }
}
