
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../model/api_models/all_categories/all_category_song_model.dart';
import '../utils/color.dart';
import '../widget/reusable_text.dart';

class AudioPlay extends StatefulWidget {
  final CategoriesSongModel song;
  const AudioPlay({Key? key, required this.song}) : super(key: key);

  @override
  State<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends State<AudioPlay> {
  late final AudioPlayer _audioPlayer;
  final progressNotifier = ValueNotifier<ProgressBarState>(
    ProgressBarState(current: Duration.zero, buffered: Duration.zero, total: Duration.zero),
  );
  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    // await _audioPlayer.setUrl(
    //   widget.song.fileURL.replaceAll('public', ApiConstants.baseUrl),
    // );

    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing;
      final processing = state.processingState;
      if (processing == ProcessingState.loading || processing == ProcessingState.buffering) {
        buttonNotifier.value = ButtonState.loading;
      } else if (!playing) {
        buttonNotifier.value = ButtonState.paused;
      } else if (processing != ProcessingState.completed) {
        buttonNotifier.value = ButtonState.playing;
      } else {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      final s = progressNotifier.value;
      progressNotifier.value = ProgressBarState(current: pos, buffered: s.buffered, total: s.total);
    });

    _audioPlayer.bufferedPositionStream.listen((buf) {
      final s = progressNotifier.value;
      progressNotifier.value = ProgressBarState(current: s.current, buffered: buf, total: s.total);
    });

    _audioPlayer.durationStream.listen((dur) {
      final s = progressNotifier.value;
      progressNotifier.value = ProgressBarState(current: s.current, buffered: s.buffered, total: dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void play() => _audioPlayer.play();
  void pause() => _audioPlayer.pause();
  void seek(Duration pos) => _audioPlayer.seek(pos);
  void seekForward() => _audioPlayer.seek(
        Duration(seconds: progressNotifier.value.current.inSeconds + 10),
      );
  void seekBackward() => _audioPlayer.seek(
        Duration(seconds: progressNotifier.value.current.inSeconds - 10),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: blackColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const ReusableText(
            title: "Podcast Details",
            color: whiteColor,
            size: 20,
            weight: FontWeight.bold,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Cover art
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.song.coverImageURL != null && widget.song.coverImageURL!.contains('public')
                    ? Image.network(
                        widget.song.coverImageURL!.replaceAll('public', ''),
                        height: Get.height * 0.4,
                        width: Get.width * 0.9,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        "assets/images/peakpx.jpg",
                        height: Get.height * 0.4,
                        width: Get.width * 0.9,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 20),

              // Title & description
              ReusableText(
                title: widget.song.title,
                size: 24,
                weight: FontWeight.w700,
                color: whiteColor,
              ),
              const SizedBox(height: 8),
              ReusableText(
                title: widget.song.descriptionOfSong,
                color: greyColor,
                size: 14,
              ),
              const SizedBox(height: 24),

              // Progress bar
              ValueListenableBuilder<ProgressBarState>(
                valueListenable: progressNotifier,
                builder: (_, state, __) {
                  return ProgressBar(
                    progress: state.current,
                    buffered: state.buffered,
                    total: state.total,
                    baseBarColor: Colors.white24,
                    progressBarColor: Colors.purpleAccent,
                    bufferedBarColor: Colors.white38,
                    thumbColor: whiteColor,
                    timeLabelTextStyle: const TextStyle(color: whiteColor),
                    onSeek: seek,
                  );
                },
              ),
              const SizedBox(height: 20),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    color: whiteColor,
                    iconSize: 32,
                    onPressed: seekBackward,
                  ),
                  ValueListenableBuilder<ButtonState>(
                    valueListenable: buttonNotifier,
                    builder: (_, state, __) {
                      switch (state) {
                        case ButtonState.loading:
                          return const CircularProgressIndicator(color: whiteColor);
                        case ButtonState.paused:
                          return IconButton(
                            icon: const Icon(Icons.play_arrow),
                            color: whiteColor,
                            iconSize: 48,
                            onPressed: play,
                          );
                        case ButtonState.playing:
                          return IconButton(
                            icon: const Icon(Icons.pause),
                            color: whiteColor,
                            iconSize: 48,
                            onPressed: pause,
                          );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    color: whiteColor,
                    iconSize: 32,
                    onPressed: seekForward,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressBarState {
  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
  final Duration current;
  final Duration buffered;
  final Duration total;
}

enum ButtonState { paused, playing, loading }
