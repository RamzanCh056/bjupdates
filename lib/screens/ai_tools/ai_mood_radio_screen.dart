import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_library_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/ai_mood_radio_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AiMoodRadioScreen extends StatefulWidget {
  const AiMoodRadioScreen({super.key});

  @override
  State<AiMoodRadioScreen> createState() => _AiMoodRadioScreenState();
}

class _AiMoodRadioScreenState extends State<AiMoodRadioScreen> {
  static const int _maxMoodLength = 100;

  final TextEditingController _moodController = TextEditingController();

  MoodPlaylistResult? _playlist;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isGenerating = false;
  int _generateProgress = 0;
  Timer? _progressTimer;
  StreamSubscription<PlayerState>? _playerSub;

  MoodPlaylistTrack? get _currentTrack {
    final playlist = _playlist;
    if (playlist == null || playlist.tracks.isEmpty) return null;
    if (_currentIndex < 0 || _currentIndex >= playlist.tracks.length) {
      return null;
    }
    return playlist.tracks[_currentIndex];
  }

  List<({int index, MoodPlaylistTrack track})> get _upNextEntries {
    final playlist = _playlist;
    if (playlist == null) return const [];
    return [
      for (var i = 0; i < playlist.tracks.length; i++)
        if (i != _currentIndex) (index: i, track: playlist.tracks[i]),
    ];
  }

  @override
  void initState() {
    super.initState();
    _moodController.addListener(() => setState(() {}));
    _playerSub = AiMoodRadioService.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      if (playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
      if (state.processingState == ProcessingState.completed) {
        unawaited(_playNextTrack());
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _playerSub?.cancel();
    unawaited(AiMoodRadioService.disposePlayer());
    _moodController.dispose();
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
          _generateProgress =
              (_generateProgress + 1 + math.Random().nextInt(2)).clamp(1, 92);
        }
      });
    });
  }

  Future<void> _generatePlaylist() async {
    if (_isGenerating) return;
    final mood = _moodController.text.trim();
    if (mood.isEmpty) {
      AppToast.show('Describe your mood first.', isError: true);
      return;
    }

    await AiMoodRadioService.stop();

    setState(() {
      _isGenerating = true;
      _generateProgress = 1;
      _playlist = null;
      _currentIndex = 0;
      _isPlaying = false;
    });
    _startProgressTimer();

    try {
      final playlist = await AiMoodRadioService.generatePlaylist(mood);
      _progressTimer?.cancel();
      if (!mounted) return;

      setState(() => _generateProgress = 100);
      await Future.delayed(const Duration(milliseconds: 250));

      try {
        await AiLibraryService.save(
          AiLibrarySaveRequest(
            type: 'mood_playlist',
            title: playlist.playlistName,
            sourceTool: 'AI Mood Radio',
            textContent: playlist.toLibraryText(),
            metadata: {
              'mood': mood,
              'trackCount': playlist.tracks.length,
              'playableCount':
                  playlist.tracks.where((t) => t.hasAudio).length,
            },
          ),
        );
      } catch (error, stackTrace) {
        logDebugException(
          'AiMoodRadioScreen.saveLibrary',
          error,
          stackTrace: stackTrace,
        );
      }

      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _isGenerating = false;
        _generateProgress = 0;
      });

      final playable = playlist.tracks.where((t) => t.hasAudio).length;
      if (playable == 0) {
        AppToast.show(
          'Playlist ready — no catalog audio matched yet. Add musicTracks to stream.',
        );
      } else {
        AppToast.show('Playlist ready — $playable playable tracks.');
        final firstPlayable = playlist.tracks.indexWhere((t) => t.hasAudio);
        if (firstPlayable >= 0) {
          setState(() => _currentIndex = firstPlayable);
          await AiMoodRadioService.playTrack(playlist.tracks[firstPlayable]);
        }
      }
    } catch (error, stackTrace) {
      _progressTimer?.cancel();
      logDebugException(
        'AiMoodRadioScreen.generate',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generateProgress = 0;
      });
      AppToast.show(AiMoodRadioService.errorMessage(error), isError: true);
    }
  }

  Future<void> _togglePlayback() async {
    final track = _currentTrack;
    if (track == null) return;

    try {
      if (_isPlaying) {
        await AiMoodRadioService.pause();
        return;
      }
      if (!track.hasAudio) {
        AppToast.show('This slot has no catalog audio — pick another track.');
        return;
      }
      if (AiMoodRadioService.isPlaying) {
        await AiMoodRadioService.resume();
      } else {
        await AiMoodRadioService.playTrack(track);
      }
    } catch (error, stackTrace) {
      logDebugException(
        'AiMoodRadioScreen.togglePlayback',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(AiMoodRadioService.errorMessage(error), isError: true);
    }
  }

  Future<void> _selectTrackAt(int index) async {
    final playlist = _playlist;
    if (playlist == null ||
        index < 0 ||
        index >= playlist.tracks.length) {
      return;
    }

    final track = playlist.tracks[index];
    if (!track.hasAudio) {
      AppToast.show('No streamable audio for that track.');
      return;
    }

    await AiMoodRadioService.stop();
    setState(() {
      _currentIndex = index;
      _isPlaying = false;
    });
    try {
      await AiMoodRadioService.playTrack(track);
    } catch (error, stackTrace) {
      logDebugException(
        'AiMoodRadioScreen.selectTrack',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show(AiMoodRadioService.errorMessage(error), isError: true);
    }
  }

  Future<void> _playNextTrack() async {
    final playlist = _playlist;
    if (playlist == null || playlist.tracks.isEmpty) {
      setState(() => _isPlaying = false);
      return;
    }

    for (var step = 1; step <= playlist.tracks.length; step++) {
      final next = (_currentIndex + step) % playlist.tracks.length;
      if (playlist.tracks[next].hasAudio) {
        await _selectTrackAt(next);
        return;
      }
    }
    setState(() => _isPlaying = false);
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiLibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentTrack;

    return Stack(
      children: [
        AiToolsScreen(
          title: 'AI Mood Radio',
          bottomNavigationBar: _playlist != null && current != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniPlayerBar(
                      title: current.title,
                      subtitle: current.subtitle,
                      isPlaying: _isPlaying,
                      onTogglePlayback: () => unawaited(_togglePlayback()),
                      onNext: () => unawaited(_playNextTrack()),
                    ),
                    _MoodRadioBottomNav(
                      onHomeTap: () => Navigator.maybePop(context),
                      onLibraryTap: _openLibrary,
                    ),
                  ],
                )
              : null,
          children: [
            const AiToolsSectionTitle(text: 'Describe your mood'),
            const SizedBox(height: 10),
            AiToolsTextArea(
              controller: _moodController,
              maxLength: _maxMoodLength,
              hintText: 'Tell the radio how you feel right now...',
            ),
            const SizedBox(height: 22),
            AiToolsPrimaryButton(
              label: _isGenerating ? 'Generating...' : 'Generate Playlist',
              onPressed: _isGenerating
                  ? () {}
                  : () => unawaited(_generatePlaylist()),
            ),
            if (_playlist != null) ...[
              const SizedBox(height: 18),
              _PlaylistHeader(
                name: _playlist!.playlistName,
                summary: _playlist!.summary,
              ),
            ],
            const SizedBox(height: 28),
            const AiToolsSectionTitle(text: 'Now Playing'),
            const SizedBox(height: 10),
            if (current != null)
              _NowPlayingCard(
                title: current.title,
                subtitle: current.subtitle,
                isPlaying: _isPlaying,
                hasAudio: current.hasAudio,
                coverUrl: current.coverUrl,
                onClose: () async {
                  await AiMoodRadioService.stop();
                  if (!mounted) return;
                  setState(() {
                    _playlist = null;
                    _isPlaying = false;
                    _currentIndex = 0;
                  });
                },
                onPlayTap: () => unawaited(_togglePlayback()),
              )
            else
              const AiToolsEmptyState(
                message: 'Generate a playlist to start listening.',
              ),
            const SizedBox(height: 24),
            const AiToolsSectionTitle(text: 'Up Next'),
            const SizedBox(height: 10),
            if (_upNextEntries.isEmpty)
              const AiToolsEmptyState(message: 'More tracks will appear here.')
            else
              ..._upNextEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UpNextTrackRow(
                    title: entry.track.title,
                    subtitle: entry.track.subtitle,
                    duration: entry.track.duration,
                    hasAudio: entry.track.hasAudio,
                    coverUrl: entry.track.coverUrl,
                    onTap: () => unawaited(_selectTrackAt(entry.index)),
                  ),
                ),
              ),
          ],
        ),
        if (_isGenerating)
          _MoodProgressOverlay(progress: _generateProgress),
      ],
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  final String name;
  final String summary;

  const _PlaylistHeader({
    required this.name,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodProgressOverlay extends StatelessWidget {
  final int progress;

  const _MoodProgressOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$progress%',
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: AiToolsTheme.purple,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Building your playlist...',
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
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPlaying;
  final bool hasAudio;
  final String? coverUrl;
  final VoidCallback onClose;
  final VoidCallback onPlayTap;

  const _NowPlayingCard({
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.hasAudio,
    required this.coverUrl,
    required this.onClose,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverArt(url: coverUrl, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 88,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 40, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AiToolsTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AiToolsTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        AiToolsWaveform(
                          heights: kAiToolsWaveformHeights,
                          height: 28,
                          color: isPlaying
                              ? AiToolsTheme.purple
                              : const Color(0xFFB8B8B8),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AiToolsTheme.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPlayTap,
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AiToolsTheme.cardElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: AiToolsTheme.border),
                          ),
                          child: Icon(
                            !hasAudio
                                ? Icons.music_off_rounded
                                : (isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  final String? url;
  final double size;

  const _CoverArt({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: hasUrl
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _CoverFallback(),
              )
            : const _CoverFallback(),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B4FD6), Color(0xFF8A3D9A)],
        ),
      ),
      child: Icon(
        Icons.radio_rounded,
        color: Colors.white.withValues(alpha: 0.85),
        size: 28,
      ),
    );
  }
}

class _UpNextTrackRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final bool hasAudio;
  final String? coverUrl;
  final VoidCallback onTap;

  const _UpNextTrackRow({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.hasAudio,
    required this.coverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AiToolsTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AiToolsTheme.border),
          ),
          child: Row(
            children: [
              _CoverArt(url: coverUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasAudio ? subtitle : 'No stream available',
                      style: const TextStyle(
                        color: AiToolsTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                duration,
                style: const TextStyle(
                  color: AiToolsTheme.purple,
                  fontSize: 13,
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

class _MiniPlayerBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onNext;

  const _MiniPlayerBar({
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AiToolsTheme.cardElevated,
        border: Border(
          top: BorderSide(color: AiToolsTheme.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AiToolsTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 18,
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
                    color: AiToolsTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTogglePlayback,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AiToolsTheme.purple, width: 1.5),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AiToolsTheme.border),
              ),
              child: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodRadioBottomNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onLibraryTap;

  const _MoodRadioBottomNav({
    required this.onHomeTap,
    required this.onLibraryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: AiToolsTheme.background,
        border: Border(
          top: BorderSide(color: AiToolsTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _BottomNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              isActive: false,
              onTap: onHomeTap,
            ),
            _BottomNavItem(
              icon: Icons.library_music_outlined,
              label: 'Library',
              isActive: true,
              onTap: onLibraryTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AiToolsTheme.purple : AiToolsTheme.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
