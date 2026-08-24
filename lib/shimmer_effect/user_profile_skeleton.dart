import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserProfileSkeleton extends StatelessWidget {
  const UserProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
              leading: const Skeleton(width: 40,height: 40),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(
                    height: 20,
                    width: Get.width*.4,
                  ),
                  const SizedBox(height: 10,),
                  Skeleton(
                    height: 15,
                    width: Get.width*.3,
                  ),
                ],
              ),
              trailing: Skeleton(width: Get.width*.25,height: 45,)
          ),
          const SizedBox(
            height: 20,
          ),
          // NetworkImage(imageUrl),
          // Image.network(imageUrl),
          // FadeInImage(
          //     placeholder: const AssetImage('assets/images/beet.jpg'),
          //     image: NetworkImage(imageUrl)),

          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }
}
