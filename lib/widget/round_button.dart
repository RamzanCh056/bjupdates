import 'package:beatjerky/widget/reusable_text.dart';
import 'package:flutter/material.dart';

import '../utils/color.dart';


class RoundButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool filled;

  const RoundButton({
    super.key,
    required this.title,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
           gradient: buttonGradient
            ),
        child: ReusableText(
          title: title,
          size: 18,
          weight: FontWeight.w700,
          color: whiteColor,
        ),
      ),
    );
  }
}