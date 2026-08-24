import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

class AiNowPlayingScreen extends StatefulWidget {
  final GeneratedBeat beat;

  const AiNowPlayingScreen({
    super.key,
    required this.beat,
  });

  @override
  State<AiNowPlayingScreen> createState() => _AiNowPlayingScreenState();
}

class _AiNowPlayingScreenState extends State<AiNowPlayingScreen> {
  bool _isFavorite = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.beat.isFavorite;
    _preparePlayback();
  }

  Future<void> _preparePlayback() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await AiBeatGeneratorService.startBeat(widget.beat);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error, stackTrace) {
      logDebugException('AiNowPlayingScreen.preparePlayback', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = error.toString();
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final nextValue = !_isFavorite;
    setState(() => _isFavorite = nextValue);
    try {
      await AiBeatGeneratorService.setFavorite(
        beatId: widget.beat.id,
        isFavorite: nextValue,
      );
    } catch (error, stackTrace) {
      logDebugException('AiNowPlayingScreen.toggleFavorite', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isFavorite = !nextValue);
      }
      AppToast.show(error.toString(), isError: true);
    }
  }

  Future<void> _shareBeat() async {
    final url = widget.beat.previewAudioUrl?.trim();
    if (url == null || url.isEmpty) {
      AppToast.show('No audio URL to share.', isError: true);
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: 'Listen to "${widget.beat.title}" on Beat Jerky\n$url',
        subject: widget.beat.title,
      ),
    );
  }

  String get _subtitle {
    return '${widget.beat.bpm} BPM • ${widget.beat.keyLabel}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final targetDuration = widget.beat.targetDuration;

    return Scaffold(
      backgroundColor: AiToolsTheme.background,
      body: Stack(
        children: [
          const AiToolsAmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: _loadError != null
                      ? _buildErrorState()
                      : Column(
                          children: [
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: _NowPlayingArtwork(
                                  isLoading: _isLoading,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.beat.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AiToolsTheme.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _toggleFavorite,
                                    icon: Icon(
                                      _isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _isFavorite
                                          ? AiToolsTheme.pink
                                          : AiToolsTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _subtitle,
                                  style: const TextStyle(
                                    color: AiToolsTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: StreamBuilder<Duration>(
                                stream: AiBeatGeneratorService.positionStream,
                                builder: (context, positionSnapshot) {
                                  final position = _clampToTarget(
                                    positionSnapshot.data ?? Duration.zero,
                                    targetDuration,
                                  );
                                  final total = targetDuration;

                                  return Column(
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4,
                                          activeTrackColor: AiToolsTheme.purple,
                                          inactiveTrackColor:
                                              Colors.white.withValues(alpha: 0.12),
                                          thumbColor: Colors.white,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape: SliderComponentShape.noOverlay,
                                        ),
                                        child: Slider(
                                          min: 0,
                                          max: total.inMilliseconds.toDouble(),
                                          value: position.inMilliseconds
                                              .clamp(0, total.inMilliseconds)
                                              .toDouble(),
                                          onChanged: _isLoading
                                              ? null
                                              : (value) {
                                                  AiBeatGeneratorService.seek(
                                                    Duration(
                                                      milliseconds: value.round(),
                                                    ),
                                                  );
                                                },
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: AiToolsTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(total),
                                            style: const TextStyle(
                                              color: AiToolsTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            StreamBuilder<PlayerState>(
                              stream: AiBeatGeneratorService.playerStateStream,
                              builder: (context, snapshot) {
                                final isPlaying =
                                    snapshot.data?.playing ?? AiBeatGeneratorService.isPlaying;
                                return _PlaybackControlsRow(
                                  isPlaying: isPlaying && _loadError == null,
                                  isLoading: _isLoading,
                                  onPlayPause: () async {
                                    if (_isLoading) return;
                                    await AiBeatGeneratorService.togglePlayPause();
                                  },
                                  onPrevious: () => AiBeatGeneratorService.seekRelative(
                                    const Duration(seconds: -10),
                                  ),
                                  onNext: () => AiBeatGeneratorService.seekRelative(
                                    const Duration(seconds: 10),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            _BottomUtilityBar(
                              isFavorite: _isFavorite,
                              onFavorite: _toggleFavorite,
                              onDownload: () {
                                AppToast.show('Download coming soon.');
                              },
                              onShare: _shareBeat,
                              onQueue: () {
                                AppToast.show('Queue coming soon.');
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AiToolsTheme.textPrimary,
              size: 28,
            ),
          ),
          const Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AiToolsTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              AppToast.show('More options coming soon.');
            },
            icon: const Icon(
              Icons.menu_rounded,
              color: AiToolsTheme.textPrimary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Duration _clampToTarget(Duration position, Duration target) {
    if (position > target) {
      return target;
    }
    return position;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AiToolsTheme.pink,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Could not play this beat.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _preparePlayback,
              child: const Text(
                'Try again',
                style: TextStyle(color: AiToolsTheme.purple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingArtwork extends StatelessWidget {
  final bool isLoading;

  const _NowPlayingArtwork({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AiToolsTheme.purple.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A1548),
                      Color(0xFF0A0E1C),
                      Color(0xFF1A0F2E),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AiToolsTheme.pink.withValues(alpha: 0.45),
                        AiToolsTheme.purple.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 88,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AiToolsTheme.purple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackControlsRow extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PlaybackControlsRow({
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ControlIcon(
            icon: Icons.shuffle_rounded,
            onTap: () => AppToast.show('Shuffle coming soon.'),
          ),
          _ControlIcon(icon: Icons.skip_previous_rounded, onTap: onPrevious),
          GestureDetector(
            onTap: isLoading ? null : onPlayPause,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AiToolsTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AiToolsTheme.purple.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          _ControlIcon(icon: Icons.skip_next_rounded, onTap: onNext),
          _ControlIcon(
            icon: Icons.repeat_rounded,
            onTap: () => AppToast.show('Repeat coming soon.'),
          ),
        ],
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: AiToolsTheme.textPrimary,
        size: 28,
      ),
    );
  }
}

class _BottomUtilityBar extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onQueue;

  const _BottomUtilityBar({
    required this.isFavorite,
    required this.onFavorite,
    required this.onDownload,
    required this.onShare,
    required this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? AiToolsTheme.pink : AiToolsTheme.textPrimary,
              size: 24,
            ),
          ),
          IconButton(
            onPressed: onDownload,
            icon: const Icon(
              Icons.download_rounded,
              color: AiToolsTheme.textPrimary,
              size: 24,
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(
              Icons.ios_share_rounded,
              color: AiToolsTheme.textPrimary,
              size: 24,
            ),
          ),
          IconButton(
            onPressed: onQueue,
            icon: const Icon(
              Icons.queue_music_rounded,
              color: AiToolsTheme.textPrimary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the full-screen now playing UI and starts playback.
Future<void> openAiBeatNowPlaying(
  BuildContext context,
  GeneratedBeat beat,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => AiNowPlayingScreen(beat: beat),
    ),
  );
}
