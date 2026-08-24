import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';
import '../model/music_model.dart';

class MusicStyleSkeleton extends StatefulWidget {
  const MusicStyleSkeleton({Key? key}) : super(key: key);

  @override
  State<MusicStyleSkeleton> createState() => _MusicStyleSkeletonState();
}

class _MusicStyleSkeletonState extends State<MusicStyleSkeleton> {
  final List<MusicModel> musicData = [
    MusicModel(
        name: "Rap Gangs",
        image:
        "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=870&q=80"),
    MusicModel(
        name: "Rap Party",
        image:
        "https://images.unsplash.com/photo-1471478331149-c72f17e33c73?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=869&q=80"),
    MusicModel(
        name: "Hip Hop Now",
        image:
        "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=870&q=80"),
    MusicModel(
        name: "Rap Dizz",
        image:
        "https://images.unsplash.com/photo-1465821185615-20b3c2fbf41b?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=998&q=80"),
    MusicModel(
        name: "Hip Hop Now",
        image:
        "https://images.unsplash.com/photo-1415201364774-f6f0bb35f28f?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=870&q=80"),
    MusicModel(
        name: "Rap Party",
        image:
        "https://images.unsplash.com/photo-1471478331149-c72f17e33c73?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=869&q=80"),

  ];

  // getAllMusicStyles()async{
  //   await MusicStyleServices().getMusicStyles(context);
  // }

  @override
  void initState() {
    // getAllMusicStyles();
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 8,
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20),
      itemBuilder: (BuildContext context, int index) {
        return const Skeleton(
          height: 100,
          width: 100,
        );
      },
    );
  }
}
