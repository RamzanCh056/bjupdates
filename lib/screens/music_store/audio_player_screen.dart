
import 'package:beatjerky/screens/music_store/song_model.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../utils/color.dart';

class AudioPlayerScreen extends StatefulWidget {
  final SongModel song;
  const AudioPlayerScreen({required this.song, Key? key}) : super(key: key);
  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _player;
  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setUrl(widget.song.fileUrl);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.more_vert, color: Colors.white),
        //     onPressed: () {},
        //   ),
        // ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Album Art
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: widget.song.coverImageUrl.isNotEmpty
                        ? Image.network(
                            widget.song.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Song Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.song.singer,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.song.price > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money, color: accent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.song.price.toStringAsFixed(2),
                            style: TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: StreamBuilder<DurationState>(
                stream: _player.positionStream.map((position) => DurationState(
                      position: position,
                      duration: _player.duration ?? Duration.zero,
                    )),
                builder: (context, snapshot) {
                  final durationState = snapshot.data ?? DurationState(
                        position: Duration.zero,
                        duration: Duration.zero,
                      );
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                          thumbColor: accent,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: durationState.duration.inMilliseconds > 0
                              ? durationState.position.inMilliseconds.toDouble()
                              : 0.0,
                          max: durationState.duration.inMilliseconds > 0
                              ? durationState.duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            _player.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(durationState.position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(durationState.duration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Replay 10s
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      iconSize: 28,
                      onPressed: () => _player.seek(
                        _player.position - const Duration(seconds: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Play/Pause Button
                  StreamBuilder<bool>(
                    stream: _player.playingStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          iconSize: 40,
                          padding: const EdgeInsets.all(16),
                          onPressed: () => playing ? _player.pause() : _player.play(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  // Forward 10s
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      iconSize: 28,
                      onPressed: () => _player.seek(
                        _player.position + const Duration(seconds: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.3),
            const Color(0xFF2A2A2A).withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: accent,
        ),
      ),
    );
  }
}

class DurationState {
  final Duration position;
  final Duration duration;

  DurationState({required this.position, required this.duration});
}

