import 'package:beatjerky/widget/reusable_text.dart';
import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:intl/intl.dart';

import '../utils/color.dart';

class BuildMessage extends StatelessWidget {
  final String message;
  final bool isMe;
  final dateTime;
  final bool isSameDate;
  final indexZero;

  const BuildMessage(
      {super.key,
      required this.message,
      required this.isMe,
      required this.dateTime,
      required this.isSameDate,
      required this.indexZero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          !isSameDate || indexZero
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: ReusableText(
                      title: DateFormat("dd-MMM-yyyy")
                          .format(DateTime.parse(dateTime)),
                      color: whiteColor,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          Container(
            padding:
                const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 15),
            decoration: isMe
                ? const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                    border: GradientBoxBorder(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomRight,
                        colors: [
                          indigoColor,
                          pinkColor,
                        ],
                      ),
                    ),
                  )
                : const BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10),
                        // topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                    color: pinkColor,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ReusableText(
                  title: message,
                  size: 18,
                  color: whiteColor,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          ReusableText(
            title: DateFormat("").add_jm().format(DateTime.parse(dateTime)),
            size: 10,
            color: whiteColor,
          ),
        ],
      ),
    );
  }
}
