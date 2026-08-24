// import 'package:flutter/material.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
//
// class SongPlayerScreen extends StatefulWidget {
//   final String title;
//   final String description;
//   final String fileUrl;
//   final String? coverImage;
//
//   const SongPlayerScreen({
//     super.key,
//     required this.title,
//     required this.description,
//     required this.fileUrl,
//     this.coverImage,
//   });
//
//   @override
//   State<SongPlayerScreen> createState() => _SongPlayerScreenState();
// }
//
// class _SongPlayerScreenState extends State<SongPlayerScreen> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   Duration _duration = Duration.zero;
//   Duration _position = Duration.zero;
//   Duration _buffered = Duration.zero;
//
//   bool isPlaying = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer();
//   }
//
//   Future<void> _initializePlayer() async {
//     try {
//       await _audioPlayer.setUrl(widget.fileUrl);
//
//       _audioPlayer.durationStream.listen((d) {
//         if (d != null) setState(() => _duration = d);
//       });
//
//       _audioPlayer.positionStream.listen((p) {
//         setState(() => _position = p);
//       });
//
//       _audioPlayer.bufferedPositionStream.listen((b) {
//         setState(() => _buffered = b);
//       });
//
//       _audioPlayer.playerStateStream.listen((state) {
//         setState(() {
//           isPlaying = state.playing;
//         });
//       });
//     } catch (e) {
//       debugPrint("Error loading audio: $e");
//     }
//   }
//
//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     super.dispose();
//   }
//
//   void _playPause() {
//     if (isPlaying) {
//       _audioPlayer.pause();
//     } else {
//       _audioPlayer.play();
//     }
//   }
//
//   void _seek(Duration position) {
//     _audioPlayer.seek(position);
//   }
//
//   void _rewind10() {
//     final newPosition = _position - const Duration(seconds: 10);
//     _audioPlayer.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
//   }
//
//   void _forward10() {
//     final newPosition = _position + const Duration(seconds: 10);
//     _audioPlayer.seek(newPosition < _duration ? newPosition : _duration);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: const Text("Podcast Details", style: TextStyle(color: Colors.black)),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             Align(
//               alignment: Alignment.topLeft,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.purple,
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 12)),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Container(
//               height: 200,
//               width: 200,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 color: Colors.grey.shade200,
//               ),
//               child: widget.coverImage != null && widget.coverImage!.isNotEmpty
//                   ? ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: Image.network(widget.coverImage!, fit: BoxFit.cover),
//               )
//                   : const Center(
//                 child: Icon(Icons.music_note, size: 100, color: Colors.black54),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(widget.title,
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 6),
//             Text(widget.description, style: const TextStyle(color: Colors.grey)),
//             const SizedBox(height: 30),
//
//             /// Progress Bar
//             ProgressBar(
//               progress: _position,
//               buffered: _buffered,
//               total: _duration,
//               onSeek: _seek,
//               timeLabelTextStyle: const TextStyle(color: Colors.black),
//               progressBarColor: Colors.purple,
//               bufferedBarColor: Colors.purple.shade100,
//               baseBarColor: Colors.grey.shade300,
//               thumbColor: Colors.blue,
//             ),
//             const SizedBox(height: 30),
//
//             /// Controls
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 const Icon(Icons.skip_previous, size: 30),
//                 IconButton(
//                   onPressed: _rewind10,
//                   icon: const Icon(Icons.replay_10, size: 30),
//                 ),
//                 Container(
//                   height: 60,
//                   width: 60,
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.purple,
//                   ),
//                   child: IconButton(
//                     icon: Icon(
//                       isPlaying ? Icons.pause : Icons.play_arrow,
//                       size: 34,
//                       color: Colors.white,
//                     ),
//                     onPressed: _playPause,
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: _forward10,
//                   icon: const Icon(Icons.forward_10, size: 30),
//                 ),
//                 const Icon(Icons.skip_next, size: 30),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class SongPlayerScreen extends StatefulWidget {
  final String title;
  final String description;
  final String fileUrl;
  final String? coverImage;

  const SongPlayerScreen({
    super.key,
    required this.title,
    required this.description,
    required this.fileUrl,
    this.coverImage,
  });

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _audioPlayer.setUrl(widget.fileUrl);
      _audioPlayer.durationStream.listen((d) {
        if (d != null) setState(() => _duration = d);
      });
      _audioPlayer.positionStream.listen((p) {
        setState(() => _position = p);
      });
      _audioPlayer.bufferedPositionStream.listen((b) {
        setState(() => _buffered = b);
      });
      _audioPlayer.playerStateStream.listen((state) {
        setState(() {
          isPlaying = state.playing;
        });
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() {
    if (isPlaying)
      _audioPlayer.pause();
    else
      _audioPlayer.play();
  }

  void _seek(Duration position) => _audioPlayer.seek(position);

  void _rewind10() {
    final newPosition = _position - const Duration(seconds: 10);
    _audioPlayer.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  void _forward10() {
    final newPosition = _position + const Duration(seconds: 10);
    _audioPlayer.seek(newPosition < _duration ? newPosition : _duration);
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
          'Now Playing',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
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
                    child: widget.coverImage != null && widget.coverImage!.isNotEmpty
                        ? Image.network(
                            widget.coverImage!,
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
                    widget.title,
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
                    widget.description.isNotEmpty ? widget.description : '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  ProgressBar(
                    progress: _position,
                    buffered: _buffered,
                    total: _duration,
                    onSeek: _seek,
                    timeLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    timeLabelPadding:6,
                    progressBarColor: accent,
                    bufferedBarColor: accent.withOpacity(0.3),
                    baseBarColor: Colors.white.withOpacity(0.2),
                    thumbColor: accent,
                    thumbGlowColor: accent.withOpacity(0.5),
                    thumbGlowRadius: 20,
                  ),
                  const SizedBox(height: 8),
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 4),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //     children: [
                  //       Text(
                  //         _formatDuration(_position),
                  //         style: TextStyle(
                  //           color: Colors.white.withOpacity(0.7),
                  //           fontSize: 12,
                  //         ),
                  //       ),
                  //       Text(
                  //         _formatDuration(_duration),
                  //         style: TextStyle(
                  //           color: Colors.white.withOpacity(0.7),
                  //           fontSize: 12,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
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
                      onPressed: _rewind10,
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Play/Pause Button
                  Container(
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
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      iconSize: 40,
                      padding: const EdgeInsets.all(16),
                      onPressed: _playPause,
                    ),
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
                      onPressed: _forward10,
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
