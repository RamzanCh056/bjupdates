


import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class Skeleton extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxShape? shape;
  const Skeleton({this.width,this.height,this.shape=BoxShape.rectangle,super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(

      gradient: const LinearGradient(colors: [
        Colors.white,
        Colors.white54,

      ]),
      child: Container(
        height: height,
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: shape!,
           color: const Color(0x40ffffff),
          borderRadius: shape==BoxShape.circle?null:BorderRadius.circular(16)
        ),
      ),
    );
  }
}
