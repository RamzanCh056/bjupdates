import 'package:beatjerky/screens/podcast_details.dart';
import 'package:flutter/material.dart';

import '../utils/color.dart';
import '../widget/reusable_text.dart';

class RecommendationTab extends StatelessWidget {
  const RecommendationTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return ListView(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                  return const PodcastDetails();
                }));
              },
              child: Row(
                  children: List.generate(5, (index) {
                    return Container(
                      height: height * 0.3,
                      width: width * 0.7,
                      alignment: Alignment.bottomCenter,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: const DecorationImage(
                          fit: BoxFit.cover,
                          image: AssetImage("assets/images/peakpx.jpg"),
                        ),
                      ),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: backgroundColor.withOpacity(0.8)),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                gradient: buttonGradient,
                              ),
                              child: const ReusableText(
                                title: "NEW",
                                size: 15,
                                color: whiteColor,
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            const ReusableText(
                              title: "Peacher Podcast Eps 11",
                              size: 14,
                              color: whiteColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  })),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const ReusableText(
                    title: "Recently Play",
                    size: 16,
                    color: whiteColor,
                  ),
                  const ReusableText(
                    title: "See all",
                    color: greyColor,
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              ...List.generate(5, (index) =>  InkWell(
                onTap: (){
                  // Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                  //   return const PreacherPodcast();
                  // }),);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: lightBlackColor,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 100,
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            "assets/images/mice.jpg",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10,),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ReusableText(
                              title: "Designer's life eps 5",
                              weight: FontWeight.w700,
                              color: whiteColor,
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            const ReusableText(
                              title: "By Richard Mile",
                              size: 15,
                              weight: FontWeight.w400,
                              color: greyColor,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const ReusableText(
                                  title: "12:30/25:59",
                                  size: 15,
                                  weight: FontWeight.w400,
                                  color: greyColor,
                                ),
                                Container(
                                  height: 40,
                                  width: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: buttonGradient,
                                  ),
                                  child: const Icon(Icons.play_arrow,color: whiteColor,),
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),),
            ],
          ),
        ),
      ],
    );
  }
}
