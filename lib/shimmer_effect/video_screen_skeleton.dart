import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';

class VideoScreenSkeleton extends StatelessWidget {
  const VideoScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 20.0,right: 5,bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                children:  [
                  //like
                  Skeleton(
                    height: 35,
                    width: 35,
                    shape: BoxShape.circle,
                  ),
                  SizedBox(height: 5,),
                  Skeleton(
                    height: 10,
                    width: 15,

                  ),
                  SizedBox(height: 10,),
                  //comment
                  Skeleton(
                    height: 35,
                    width: 35,
                    shape: BoxShape.circle,
                  ),
                  SizedBox(height: 5,),
                  Skeleton(
                    height: 10,
                    width: 15,

                  ),
                  SizedBox(height: 10,),
                  //
                  Skeleton(
                    height: 35,
                    width: 35,
                    shape: BoxShape.circle,
                  ),
                  SizedBox(height: 5,),
                  Skeleton(
                    height: 10,
                    width: 15,

                  ),

                ],
              ),
            ),
            const SizedBox(height: 20,),

            const Skeleton(width: 60,height: 20,),
            const SizedBox(height: 10,),
            const Skeleton(height: 40,width: 100,)
          ],
        ),
      ),
    );
  }
}
