import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';

class RecentlyMusicScreenSkeleton extends StatelessWidget {
  const RecentlyMusicScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      shrinkWrap: true,
      itemCount: 10,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              const Skeleton(height: 10,width: 10,),
              const SizedBox(
                width: 20,
              ),
              const Skeleton(
                height: 60,
                width: 80,

              ),
              const SizedBox(
                width: 20,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(height: 15,width: 80,),
                  SizedBox(height: 5,),
                  Skeleton(height: 15,width: 50,)
                ],
              ),
              const Spacer(),
              const Skeleton(height: 5,width: 5,)
            ],
          ),
        );
      },
    );
  }
}
