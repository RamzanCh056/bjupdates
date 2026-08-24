import 'package:beatjerky/shimmer_effect/shimmer_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: const [
                  Skeleton(height: 15,width: 20,),
                  SizedBox(
                    height: 5,
                  ),
                  Skeleton(height: 15,width: 60,)
                ],
              ),
              const Skeleton(
                height: 90,
                width: 90,
                shape: BoxShape.circle,
              ),
              Column(
                children: const [
                  Skeleton(height: 15,width: 20,),
                  SizedBox(
                    height: 5,
                  ),
                  Skeleton(height: 15,width: 60,)
                ],
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const Skeleton(height: 15,width: 80,),
          const SizedBox(
            height: 5,
          ),
          const Skeleton(height: 15,width: 50,),
          const SizedBox(
            height: 20,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const[
              Skeleton(width: 80,height: 35,),
              SizedBox(width: 20,),
              Skeleton(width: 80,height: 35,)
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Skeleton(
                height: 30,
                width: 120,
              ),
              SizedBox(width: 10,),
              Skeleton(
                height: 30,
                width: 120,),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: GridView.builder(
              itemCount: 5,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
              itemBuilder: (BuildContext context, int index) {
                return Skeleton(height: Get.height*.2,width: Get.width*.4,);
              },
            ),
          )
        ],
      ),
    );
  }
}
