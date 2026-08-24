  import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:beatjerky/shimmer_effect/user_profile_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Get.height*.4,
      width: Get.width*.9,
      child: Column(
        children: [
          const UserProfileSkeleton(),
          Skeleton(height: Get.height*.2,width: Get.width*.9,),

          Padding(
            padding: const EdgeInsets.only(left: 20.0,right: 20,top: 10),
            child: Row(
              children: const[
                Skeleton(
                  height: 20,
                  width: 20,
                ),
                SizedBox(width: 15,),
                Skeleton(
                  height: 20,
                  width: 20,
                ),
                Spacer(),
                Skeleton(
                  height: 20,
                  width: 20,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
