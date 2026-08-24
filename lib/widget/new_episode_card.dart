
import 'package:beatjerky/widget/reusable_text.dart';
import 'package:flutter/material.dart';
import '../utils/color.dart';


class NewEpisodeCard extends StatelessWidget {
  const NewEpisodeCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          Row(
            children: [
              const ReusableText(
                title: "11 Episoods",
                size: 12,
                color: greyColor,
              ),
              const SizedBox(width: 5,),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: buttonGradient,
                ),
                child: const ReusableText(
                  title: "NEW",
                  size: 12,
                  color: whiteColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5,),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 2,
                child: ReusableText(
                  title: "Monday Morning Peacher - Is still relevnt?",
                  color: whiteColor,size: 16,
                  weight: FontWeight.w400,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    height: 30,
                    width: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: buttonGradient,
                    ),
                    child: const Icon(Icons.play_arrow,color: whiteColor,),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 7,),
          Row(
            children: const [
              Icon(Icons.calendar_month_rounded,color: greyColor,size: 20,),
              SizedBox(width: 5,),
              ReusableText(title: "12 Apr 2021",color: greyColor,),
              SizedBox(width: 20,),
              Icon(Icons.alarm,color: greyColor,size: 20,),
              SizedBox(width: 5,),
              ReusableText(title: "22:45",color: greyColor,),
            ],
          ),
          SizedBox(height: 20,),
          Divider(color: backgroundColor,thickness: 1,),
        ],
      ),
    );
  }
}
