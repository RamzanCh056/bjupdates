import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../model/api_models/video_models/current_user_video_model.dart';

class VideoScreenPage extends StatefulWidget {
  CurrentUserVideoModel video;
  final String? firstName;
  final String? lastName;
  VideoScreenPage({required this.video, this.firstName, this.lastName});
  @override
  _VideoScreenPageState createState() => _VideoScreenPageState();
}

class _VideoScreenPageState extends State<VideoScreenPage> {

   final SubscriptionServicefull  _subscriptionService = SubscriptionServicefull();
  @override
  void initState() {
    super.initState();
  }
  
  Widget build(BuildContext context) {
    return Scaffold(
      body:
      
      
       VideoScreen(
        firstName: widget.firstName,
        lastName: widget.lastName,
        video: widget.video,
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  CurrentUserVideoModel video;
  final String? firstName;
  final String? lastName;
  VideoScreen({required this.video, this.firstName, this.lastName});
  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;

  @override
  void initState() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(
        widget.video.videoUrl.replaceAll('public', '')))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
    _initializeVideoPlayerFuture = _videoController!.initialize();
    _videoController!.play();
    // _videoController!.setLooping(true);

    super.initState();
  }

  @override
  void dispose() {
    _videoController!.dispose();
    _videoController!.pause();
    super.dispose();
  }

  Widget _video(BuildContext context) {
    return InkWell(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      },
      child: Container(
        color: Colors.black,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return VideoPlayer(_videoController!);
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  // Widget _top() {
  //   return Align(
  //     alignment: Alignment.topCenter,
  //     child: Container(
  //       padding: EdgeInsets.all(16.0),
  //       width: double.infinity,
  //       height: 50,
  //       color: Colors.transparent,
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           TtText(text: 'Following', size: 18),
  //           VerticalDivider(
  //             color: Colors.white,
  //           ),
  //           TtText(
  //             text: 'For You',
  //             size: 18,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _right(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: 60,
        height: MediaQuery.of(context).size.height / 2,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: TtIcon(
                iconData: Icons.favorite,
                size: 36,
              ),
              onPressed: () {},
            ),
            TtText(text: widget.video.videoLikes.length.toString(), size: 18),
            SizedBox(height: 16),
            IconButton(
              icon: TtIcon(iconData: Icons.comment, size: 36),
              onPressed: () {},
            ),
            TtText(
                text: widget.video.videoComments.length.toString(), size: 18),
            SizedBox(height: 16),
            PopupMenuButton(
                itemBuilder: (context) => [
                      PopupMenuItem(
                          child: 
                          // widget.video.userId ==
                          //         Provider.of<CurrentUserProvider>(context,
                          //                 listen: false)
                          //             .user!
                          //             .userId
                          //     ? 
                              TextButton(
                                  onPressed: () {
                                    showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            content: Text(
                                                "Are you sure to delete video"),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text("No")),
                                              TextButton(
                                                  onPressed: () async {
                                                    // await VideoServices()
                                                    //     .deleteVideo(
                                                    //         widget
                                                    //             .video.videoId,
                                                    //         context);
                                                    // await getAllVideos();
                                                    // await getVideoCommentsAndLikes();
                                                    Navigator.pop(context);
                                                    setState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text("Delete"))
                                            ],
                                          );
                                        });
                                  },
                                  child: const Text("Delete"),
                                ))
                              // : TextButton(
                              //     onPressed: () {},
                              //     child: const Text("About"),
                              //   ))
                    ]),
          ],
        ),
      ),
    );
  }

  Widget _bottom() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: EdgeInsets.all(8),
        width: double.infinity,
        height: 120,
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6),
            Row(
              children: [
                // User Name and Verification
                Expanded(
                  child: Row(
                    children: [
                      TtText(
                          text: '@${widget.firstName} ${widget.lastName}', size: 18),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                      )
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            TtText(text: widget.video.description, size: 13),
            SizedBox(height: 6),
            Row(
              children: [
                TtIcon(iconData: Icons.music_note, size: 14),
                TtText(text: 'Original Sound', size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _video(context),
        // _top(),
        _bottom(),
        _right(context),
      ],
    );
  }
}

class TtIcon extends StatelessWidget {
  final IconData? iconData;
  final double? size;

  const TtIcon({Key? key, this.iconData, this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(iconData, size: this.size, color: Colors.white);
  }
}

class TtText extends StatelessWidget {
  final String text;
  final double size;

  const TtText({Key? key, required this.text, required this.size})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: Colors.white, fontSize: size));
  }
}
