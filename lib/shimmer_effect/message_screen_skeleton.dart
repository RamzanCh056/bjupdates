import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';

class MessageScreenSkeleton extends StatelessWidget {
  const MessageScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 10,
      itemBuilder: (BuildContext context, int index) {

        return
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              // mainAxisSize: MainAxisSize.min,

              children: [
                const Skeleton(height: 30,width: 30,shape: BoxShape.circle,),
                const SizedBox(width: 15,),
                Column(
                  children: const [
                    Skeleton(height: 10,width: 70,),
                    SizedBox(height: 5,),
                    Skeleton(height: 10,width: 50,),
                  ],
                ),
                const Spacer(),
                const Skeleton(height: 10,width: 20,)
              ],
            ),
          );
      },

    );
  }
}
