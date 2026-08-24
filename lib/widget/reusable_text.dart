import 'package:flutter/material.dart';

class ReusableText extends StatelessWidget {
  final String ? title;
  final double ? size;
  final FontWeight ? weight;
  final Color ? color;
  final FontStyle ? fontStyle;
  final TextAlign ? textAlign;
  const ReusableText({Key? key, this.title, this.size, this.weight, this.color, this.fontStyle, this.textAlign, }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title!,
      textAlign: textAlign,
      style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontStyle: fontStyle),
    );
  }
}
