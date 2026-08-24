import 'package:flutter/material.dart';
import 'package:gradient_borders/gradient_borders.dart';

import '../utils/color.dart';
import '../widget/new_episode_card.dart';
import '../widget/reusable_text.dart';

class PodcastDetails extends StatelessWidget {
  const PodcastDetails({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          backgroundColor: transparentColor,
          leading: InkWell(
            onTap: (){
              Navigator.pop(context);
            },
            child: const Icon(
              Icons.arrow_back_ios,
              color: whiteColor,
            ),
          ),
          centerTitle: true,
          title: const ReusableText(
            title: "Podcast Details",
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(
                  height: height * 0.3,
                  width: width * 0.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      "assets/images/peakpx.jpg",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                const ReusableText(
                  title: "Preacher Podcast",
                  size: 18,
                  weight: FontWeight.w700,
                  color: whiteColor,
                ),
                const SizedBox(
                  height: 5,
                ),
                const ReusableText(
                  title: "Hosted by Roy Willam & Grace Lia",
                  color: greyColor,
                ),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                indigoColor,
                                pinkColor,
                              ],
                            )),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: whiteColor,
                            ),
                            const ReusableText(
                              title: "Play All",
                              size: 18,
                              weight: FontWeight.w400,
                              color: whiteColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 20,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: const GradientBoxBorder(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomRight,
                              colors: [
                                indigoColor,
                                pinkColor,
                              ],
                            ),
                          ),
                        ),
                        child: const ReusableText(
                          title: "Subscribed",
                          size: 18,
                          weight: FontWeight.w400,
                          color: whiteColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  children: [
                    ReusableText(
                      title: "11 Episoods",
                      size: 16,
                      color: whiteColor.withOpacity(0.8),
                    ),
                    const Spacer(),
                    const ReusableText(
                      title: "Sort",
                      size: 16,
                      color: greyColor,
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: greyColor,
                    )
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                ...List.generate(3, (index) => NewEpisodeCard(),),
              ],
            ),
          ),
        ),
      );
  }
}
