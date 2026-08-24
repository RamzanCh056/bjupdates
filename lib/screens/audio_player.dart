
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlay extends StatefulWidget {
  String? pathh;
  String? time;
  String? ColorValue;


  AudioPlay({
    Key? key,
    this.pathh,
    this.time,
    this.ColorValue,
  }) : super(key: key);

  @override
  State<AudioPlay> createState() => _AudioPlayState();

}

class _AudioPlayState extends State<AudioPlay> {
  final progressNotifier = ValueNotifier<ProgressBarState>(
    ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    ),
  );

  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);

  late AudioPlayer _audioPlayer;

  PageManager() {
    _init();
  }

  @override
  void initState() {
    PageManager();
    super.initState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _init() async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer.setUrl(widget.pathh!);

    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
        buttonNotifier.value = ButtonState.loading;
      } else if (!isPlaying) {
        buttonNotifier.value = ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        buttonNotifier.value = ButtonState.playing;
      } else {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });

    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: bufferedPosition,
        total: oldState.total,
      );
    });

    _audioPlayer.durationStream.listen((totalDuration) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: totalDuration ?? Duration.zero,
      );
    });
  }

  void play() {
    _audioPlayer.play();
  }

  void pause() {
    _audioPlayer.pause();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
              Color(0xFFEBEFFB)
          ),

          child: Column(

            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(int.parse(
                      widget.time!,
                    ) *
                        1000)),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ValueListenableBuilder<ButtonState>(
                      valueListenable: buttonNotifier,
                      builder: (__, value, _) {
                    switch (value) {
                    case ButtonState.loading:
                    return Container(
                    // margin: const EdgeInsets.only(bottom: 20),
                    width: 30.0,
                    height: 30.0,
                    child: const CircularProgressIndicator(),
                    );
                    case ButtonState.paused:
                    return GestureDetector(
                    onTap:  play,
                    child: Icon(Icons.play_circle_outline_outlined, size: 32,
                    color:  widget.ColorValue =='null'? Colors.black:Colors.white,
                    ));
                    //   IconButton(
                    //   icon: const Icon(Icons.play_arrow),
                    //   iconSize: 30.0,
                    //   onPressed: play,
                    // );
                    case ButtonState.playing:
                    return GestureDetector(
                    onTap:  pause,
                    child: Icon(Icons.pause_circle_outline, size: 32,color:  widget.ColorValue =='null'? Colors.black:Colors.white,));
                    //   IconButton(
                    //   icon: const Icon(Icons.pause),
                    //   iconSize: 30.0,
                    //   onPressed: pause,
                    // );
                    }
                    },
                    ),
                  ),
                  SizedBox(width: 8,),
                  Expanded(

                    child: ValueListenableBuilder<ProgressBarState>(
                      valueListenable: progressNotifier,
                      builder: (__, value, _) {
                    return ProgressBar(
                    progress: value.current,
                    buffered: value.buffered,
                    total: value.total,
                    onSeek: seek,
                    );
                    },
                    ),
                  ),
                ],
              ),




            ],
          ),)
    );
  }
}
// class PageManager  {
//
//
//
//   final progressNotifier = ValueNotifier<ProgressBarState>(
//
//     ProgressBarState(
//       current: Duration.zero,
//       buffered: Duration.zero,
//       total: Duration.zero,
//     ),
//   );
//
//   final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);
//
//   static const url =
//       'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
//
//
//   late AudioPlayer _audioPlayer;
//   PageManager() {
//     _init();
//   }
//
//   void _init() async {
//     _audioPlayer = AudioPlayer();
//     await _audioPlayer.setUrl(widget.pathh!);
//
//     _audioPlayer.playerStateStream.listen((playerState) {
//       final isPlaying = playerState.playing;
//       final processingState = playerState.processingState;
//       if (processingState == ProcessingState.loading ||
//           processingState == ProcessingState.buffering) {
//         buttonNotifier.value = ButtonState.loading;
//       } else if (!isPlaying) {
//         buttonNotifier.value = ButtonState.paused;
//       } else if (processingState != ProcessingState.completed) {
//         buttonNotifier.value = ButtonState.playing;
//       } else {
//         _audioPlayer.seek(Duration.zero);
//         _audioPlayer.pause();
//       }
//     });
//
//     _audioPlayer.positionStream.listen((position) {
//       final oldState = progressNotifier.value;
//       progressNotifier.value = ProgressBarState(
//         current: position,
//         buffered: oldState.buffered,
//         total: oldState.total,
//       );
//     });
//
//     _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
//       final oldState = progressNotifier.value;
//       progressNotifier.value = ProgressBarState(
//         current: oldState.current,
//         buffered: bufferedPosition,
//         total: oldState.total,
//       );
//     });
//
//     _audioPlayer.durationStream.listen((totalDuration) {
//       final oldState = progressNotifier.value;
//       progressNotifier.value = ProgressBarState(
//         current: oldState.current,
//         buffered: oldState.buffered,
//         total: totalDuration ?? Duration.zero,
//       );
//     });
//   }
//
//   void play() {
//     _audioPlayer.play();
//   }
//
//   void pause() {
//     _audioPlayer.pause();
//   }
//
//   void seek(Duration position) {
//     _audioPlayer.seek(position);
//   }
//
//   void dispose() {
//     _audioPlayer.dispose();
//   }
// }

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






// import 'package:audio_session/audio_session.dart';
// import 'package:beat_jerky/model/api_models/all_categories/all_category_song_model.dart';
// import 'package:beat_jerky/repo/api_consts.dart';
// import 'package:beat_jerky/utils/color.dart';
// import 'package:beat_jerky/widget/reusable_text.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get_core/get_core.dart';
// import 'package:get/get_rx/src/rx_types/rx_types.dart';
// import 'package:flutter/services.dart';
// import 'package:just_audio/just_audio.dart';
//
// class PreacherPodcast extends StatefulWidget {
//   const PreacherPodcast({required this.song,Key? key}) : super(key: key);
//   final CategoriesSongModel song;
//
//   @override
//   State<PreacherPodcast> createState() => _PreacherPodcastState();
// }
//
// class _PreacherPodcastState extends State<PreacherPodcast> {
//   double value = 40;
//
//   final _player=AudioPlayer();
//   Duration? duration;
//   initializeSong()async{
//     duration=await _player.setUrl(widget.song.fileURL.replaceAll('public', ApiConstants.baseUrl));
//   }
//   @override
//   void initState() {
//     initializeSong();
//     // TODO: implement initState
//     super.initState();
//   }
//   bool isPlaying=false;
//
//   @override
//   void dispose() {
//     // ambiguate(WidgetsBinding.instance)!.removeObserver();
//     // Release decoders and buffers back to the operating system making them
//     // available for other apps to use.
//     _player.dispose();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused) {
//       // Release the player's resources when not in use. We use "stop" so that
//       // if the app resumes later, it will still remember what position to
//       // resume from.
//       _player.stop();
//     }
//   }
//
//   Future<void> _init() async {
//     // Inform the operating system of our app's audio attributes etc.
//     // We pick a reasonable default for an app that plays speech.
//     final session = await AudioSession.instance;
//     await session.configure(const AudioSessionConfiguration.speech());
//     // Listen to errors during playback.
//     _player.playbackEventStream.listen((event) {},
//         onError: (Object e, StackTrace stackTrace) {
//           print('A stream error occurred: $e');
//         });
//     // Try to load audio from a source and catch any errors.
//     try {
//       // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
//       await _player.setAudioSource(AudioSource.uri(Uri.parse(
//           "https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3")));
//     } catch (e) {
//       print("Error loading audio source: $e");
//     }
//   }
//
//
//   // Stream<PositionData> get _positionDataStream =>
//   //     Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
//   //         _player.positionStream,
//   //         _player.bufferedPositionStream,
//   //         _player.durationStream,
//   //             (position, bufferedPosition, duration) => PositionData(
//   //             position, bufferedPosition, duration ?? Duration.zero));
//
//
//   @override
//   Widget build(BuildContext context) {
//
//     var height = MediaQuery.of(context).size.height;
//     var width = MediaQuery.of(context).size.width;
//
//
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(
//           backgroundColor: transparentColor,
//           centerTitle: true,
//           title: const ReusableText(
//             title: "Podcast Details",
//           ),
//         ),
//         body: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             children: [
//               SizedBox(
//                 height: height * 0.4,
//                 width: width * 0.9,
//                 child: Stack(
//                   children: [
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(30),
//                       child: widget.song.coverImageURL!=null && widget.song.coverImageURL!.contains('public')?
//                           Image.network(widget.song.coverImageURL!.replaceAll('public', ApiConstants.baseUrl),
//                             height: height * 0.4,
//                             width: width * 0.9,):Image.asset(
//                         "assets/images/peakpx.jpg",
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                     Container(
//                       height: 35,
//                       width: 60,
//                       margin: const EdgeInsets.all(10),
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(5),
//                         gradient: buttonGradient,
//                       ),
//                       child: const ReusableText(
//                         title: "NEW",
//                         size: 12,
//                         color: whiteColor,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(
//                 height: 20,
//               ),
//               ReusableText(
//                 title: widget.song.title,
//                 size: 25,
//                 weight: FontWeight.w700,
//                 color: whiteColor,
//               ),
//               const SizedBox(
//                 height: 10,
//               ),
//               ReusableText(
//                 title: widget.song.descriptionOfSong,
//                 color: greyColor,
//               ),
//               const SizedBox(
//                 height: 30,
//               ),
//               Container(
//                 width: double.infinity,
//                 child: SliderTheme(
//                   data:  SliderThemeData(
//                     overlayShape: SliderComponentShape.noOverlay,
//                     trackHeight: 8,
//                   ),
//                   child: Slider(
//                       value: value,
//                       activeColor: indigoColor,
//                       inactiveColor: backgroundColor,
//                       thumbColor: whiteColor,
//                       min: 0,
//                       max: 100,
//
//                       onChanged: (v) {
//                         setState(() {
//                           value = v;
//                         });
//                       }),
//                 ),
//               ),
//
//               const SizedBox(
//                 height: 7,
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 3),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     ReusableText(
//                       title: "10",
//                       color: greyColor,
//                       size: 15,
//                       weight: FontWeight.w700,
//                     ),
//                     ReusableText(
//                       title: "22:45",
//                       color: greyColor,
//                       size: 15,
//                       weight: FontWeight.w700,
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(
//                 height: 20,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Icon(Icons.skip_previous,color: greyColor,size: 30,),
//                   Icon(Icons.replay_10,color: greyColor,size: 30,),
//                   InkWell(
//                     onTap: ()async{
//                       if(isPlaying){
//                         _player.pause();
//                         isPlaying=false;
//                         setState(() {
//
//                         });
//                       }else{
//                         _player.play();
//                         isPlaying=true;
//                         setState(() {
//                         });
//                       }
//
//
//
//                     },
//                     child: Container(
//                       height: 50,
//                       width: 50,
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         gradient: buttonGradient,
//                       ),
//                       child: isPlaying?const Icon(Icons.pause,color: whiteColor,size: 40,):const Icon(Icons.play_arrow,color: whiteColor,size: 40,),
//                     ),
//                   ),
//                  Icon(Icons.forward_10,color: greyColor,size: 30,),
//                   Icon(Icons.skip_next,color: greyColor,size: 30,),
//                 ],
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
