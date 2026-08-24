// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'package:beatjerky/screens/settings_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/screens/video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:image_picker/image_picker.dart';
import '../model/api_models/video_models/current_user_video_model.dart';
import '../shimmer_effect/profile_screen_skeleton.dart';
import '../utils/color.dart';
import '../widget/reusable_text.dart';
import '../widget/round_button.dart';

class OtherUsersProfileView extends StatefulWidget {
  final int userId;
  final String userfirstname;
  final String userlastname;
  final String userImage;

  const OtherUsersProfileView(
      {Key? key,
      required this.userId,
      required this.userfirstname,
      required this.userlastname,

      required this.userImage})
      : super(key: key);

  @override
  State<OtherUsersProfileView> createState() => _OtherUsersProfileViewState();
}

class _OtherUsersProfileViewState extends State<OtherUsersProfileView> {
  File? videoFile;
  File? galleryFile;
  final picker = ImagePicker();
  bool isVideo = true;
  bool isPic = false;
  List<String> imageUrls = [];

  List<CurrentUserVideoModel> videos = [];
  getCurrentUserAllVideos() async {
    await getUserVideos();
    // videos =
        // Provider.of<CurrentUserVideoProvider>(context, listen: false).videos;
    print(videos.length);
    setState(() {});
  }

  Future getUserVideos() async {
    // var header = {
    //   'Content-Type': 'application/json',
    // };

    // // String uri =
    // //     "${ApiConstants.baseUrl}${ApiConstants.getUserVideos}${widget.userId}";

    // print("");
    // http.Response response =
    //     await ApiServices().getService(uri: "uri", header: header);

    // if (response.statusCode == 200) {
    //   var data = jsonDecode(response.body);
    //   List videosMap = data['data'];
    //   print("Video response body:${response.body}");
    //   print("Video map length: ${videosMap.length}");
    //   // print(feedsMap);
    //   // imageUrl=imageUrl.replaceAll('public', ApiConstants.baseUrl);

    //   List<CurrentUserVideoModel> videosList = [];
    //   for (int i = 0; i < videosMap.length; i++) {
    //     videosList.add(CurrentUserVideoModel.fromJson(videosMap[i]));
    //   }
    //   print(videosList.length);
    //   // Provider.of<CurrentUserVideoProvider>(context, listen: false)
    //       // .updateVideos(videosList);
    //   EasyLoading.dismiss();
    //   return true;
    // } else {
    //   EasyLoading.showError(response.statusCode.toString());
    //   return false;
    // }
  }

  List<String> extractImageUrls(dynamic feedData) {
    for (var feed in feedData) {
      if (feed.containsKey('imageUrl')) {
        setState(() {
          imageUrls.add(feed['imageUrl']);
        });
      }
    }
    return imageUrls;
  }

  Future<List<String>> getUserrAllFeeds() async {
    // try {
    //   var header = {
    //     'Content-Type': 'application/json',
    //   };

    //   String uri ="";

    //   print(uri);
    //   http.Response response =
    //       await ApiServices().getService(uri: uri, header: header);

    //   print("Feed response: ${response.body}");
    //   if (response.statusCode == 200) {
    //     var data = jsonDecode(response.body);
    //     List feedsMap = data['data'];
    //     List<String> imageUrls = extractImageUrls(feedsMap);

    //     print("Image URLs: $imageUrls");
    //     print("Number of images: ${imageUrls.length}");

    //     EasyLoading.dismiss();

    //     return imageUrls;
    //   } else {
    //     EasyLoading.showError(response.statusCode.toString());
    //     return [];
    //   }
    // } catch (e) {
    //   print(e);
    //   return [];
    // }
    return [];
  }

  int followers = 0;
  int following = 0;

  Future<void> getFollowersAndFollowing() async {
    // try {
    //   var header = {
    //     'Content-Type': 'application/json',
    //   };

    //   String uri =
    //       "";

    //   print("URI :$uri");
    //   print("Header:$header");
    //   http.Response response =
    //       await ApiServices().getService(uri: uri, header: header);
    //   print("Response body: ${response.body}");

    //   if (response.statusCode == 200) {
    //     var data = jsonDecode(response.body);
    //     setState(() {
    //       following = data['data']['following'];
    //       followers = data['data']['follower'];
    //     });

    //     print('Following: $following');
    //     print('Followers: $followers');
    //   } else {
    //     EasyLoading.showError(response.statusCode.toString());
    //   }
    // } catch (e) {
    //   print(e);
    // }
  }

  bool isLoading = true;
  initializedScreen() async {
    getFollowersAndFollowing();
    getUserrAllFeeds();
    getCurrentUserAllVideos();
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    initializedScreen();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: transparentColor,
          elevation: 0,
          title: const ReusableText(title: "Profile"),
          automaticallyImplyLeading: false,
          actions: [
            InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (BuildContext context) {
                      return SettingsScreen();
                    }),
                  );
                },
                child: Icon(
                  Icons.settings,
                  color: whiteColor,
                )),
            SizedBox(
              width: 20,
            )
          ],
        ),
        body: !isLoading
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            ReusableText(
                              title: followers.toString(),
                              size: 18,
                              weight: FontWeight.w500,
                              color: greyColor,
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            const ReusableText(
                              title: "Followers",
                              size: 18,
                              weight: FontWeight.w700,
                              color: whiteColor,
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                                height: 90,
                                width: 90,
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: blackColor,
                                    shape: BoxShape.circle,
                                    border: GradientBoxBorder(
                                      width: 2,
                                      gradient: LinearGradient(
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          indigoColor,
                                          pinkColor,
                                        ],
                                      ),
                                    )),
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(widget
                                              .userImage !=
                                          null
                                      ? widget.userImage.toString()
                                      : "http://beatjerky.com/api/profile/file_1688928075186_profile.png"),
                                  // FadeInImage(
                                  //   fit: BoxFit.contain,
                                  //     placeholder: const AssetImage("assets/images/dp.jpg"),
                                  //     image: NetworkImage(provider.user!.imageUrl!=null?provider.user!.imageUrl.toString():
                                  //     "http://beatjerky.com/api/profile/file_1688928075186_profile.png")),
                                )),
                            // Positioned(
                            //     right: 0,
                            //     bottom: 0,
                            //     child: InkWell(
                            //       onTap: () async {
                            //         _showPicker(context: context);
                            //       },
                            //       child: const Icon(
                            //         Icons.camera_alt,
                            //         color: whiteColor,
                            //         size: 30,
                            //       ),
                            //     ))
                          ],
                        ),
                        Column(
                          children: [
                            ReusableText(
                              title: following.toString(),
                              size: 18,
                              weight: FontWeight.w500,
                              color: greyColor,
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            const ReusableText(
                              title: "Following",
                              size: 18,
                              weight: FontWeight.w700,
                              color: whiteColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ReusableText(
                      title: "${widget.userfirstname} ${widget.userlastname}",
                      color: whiteColor,
                      size: 18,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    const ReusableText(
                      title: "Sprinkling kindness everywhere I go",
                      color: greyColor,
                      weight: FontWeight.w500,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                            child: RoundButton(
                          title: 'Follow',
                          onTap: () async {
                            // await FollowServices()
                                // .followUser(widget.userId, context);
                          },
                        )),
                        // SizedBox(
                        //   width: 20,
                        // ),
                        // Expanded(
                        //   child: GestureDetector(
                        //     onTap: () {
                        //       Navigator.push(
                        //           context,
                        //           MaterialPageRoute(
                        //               builder: (context) => EditProfile()));
                        //     },
                        //     child: Container(
                        //       padding: const EdgeInsets.all(12),
                        //       alignment: Alignment.center,
                        //       decoration: BoxDecoration(
                        //         borderRadius: BorderRadius.circular(10),
                        //         border: const GradientBoxBorder(
                        //           gradient: LinearGradient(
                        //             begin: Alignment.topRight,
                        //             end: Alignment.bottomRight,
                        //             colors: [
                        //               indigoColor,
                        //               pinkColor,
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //       child: const ReusableText(
                        //         title: "Edit",
                        //         size: 18,
                        //         weight: FontWeight.w400,
                        //         color: whiteColor,
                        //       ),
                        //     ),
                        //   ),
                        // )
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              isVideo = true;
                              isPic = false;
                            });
                          },
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.video_library,
                                    color: isVideo ? whiteColor : greyColor,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  ReusableText(
                                    title: "Videos",
                                    size: 15,
                                    color: isVideo ? whiteColor : greyColor,
                                    weight: FontWeight.w700,
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Container(
                                height: 3,
                                width: 100,
                                color: isVideo ? pinkColor : transparentColor,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 40,
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              isVideo = false;
                              isPic = true;
                            });
                          },
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: isPic ? whiteColor : greyColor,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  ReusableText(
                                    title: "Photos",
                                    size: 15,
                                    color: isPic ? whiteColor : greyColor,
                                    weight: FontWeight.w700,
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Container(
                                height: 3,
                                width: 100,
                                color: isPic ? pinkColor : transparentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    isVideo
                        ? Expanded(
                            child: GridView.builder(
                                itemCount: videos.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10),
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () {
                                      Get.to(() => VideoScreenPage(
                                          firstName: widget.userfirstname,
                                          lastName: widget.userlastname,
                                          video: videos[index]));
                                    },
                                    child: Container(
                                      height: 100,
                                      width: 100,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: Colors.white10,
                                          image: const DecorationImage(
                                              image: AssetImage(
                                                  'assets/images/logo.png'))),
                                    ),
                                  );
                                })

                            // Builder(
                            //   builder: (context) {
                            //     return GridView.builder(
                            //       itemCount: videos.length,
                            //       gridDelegate:
                            //           const SliverGridDelegateWithFixedCrossAxisCount(
                            //               crossAxisCount: 2,
                            //               crossAxisSpacing: 10,
                            //               mainAxisSpacing: 10),
                            //       itemBuilder: (BuildContext context, int index) {
                            //
                            //         getThumbnail(videos[index].videoUrl.replaceAll('public', ApiConstants.baseUrl));
                            //         print(getThumbnail(videos[index].videoUrl.replaceAll('public', ApiConstants.baseUrl)));
                            //         print("I am printing video");
                            //         return Container(
                            //           height: 50,
                            //           width: 50,
                            //
                            //           alignment: Alignment.center,
                            //           decoration: BoxDecoration(
                            //             borderRadius: BorderRadius.circular(10),
                            //             color: Colors.white
                            //           ),
                            //           child: Image.file(File(VideoThumbnail.thumbnailFile(video: videos[index].videoUrl.replaceAll('public', ApiConstants.baseUrl)).toString())),
                            //
                            //         );
                            //
                            //       },
                            //     );
                            //   }
                            // ),
                            )
                        : Expanded(
                            child: GridView.builder(
                              itemCount: imageUrls.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10),
                              itemBuilder: (BuildContext context, int index) {
                                return Container(
                                  height: 100,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                        image: NetworkImage(imageUrls[index]
                                            .replaceAll('public',
                                                    '')),
                                        fit: BoxFit.cover),
                                  ),
                                );
                              },
                            ),
                          )
                  ],
                ),
              )
            : const ProfileScreenSkeleton(),
      );
  }

  void _showPicker({
    required BuildContext context,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  getImage(ImageSource.camera);
                },
              ),
              Center(
                child: InkWell(
                    onTap: () async {
                      if (galleryFile != null) {
                        EasyLoading.show(status: "Uploading...");
                        // await Provider.of<CurrentUserProvider>(context,
                        //         listen: false)
                        //     .uploadProfilePicture(galleryFile!.path, context);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                          alignment: Alignment.center,
                          width: MediaQuery.of(context).size.width * .3,
                          height: 40,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24)),
                          child: const Text(
                            "Upload",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          )),
                    )),
              )
            ],
          ),
        );
      },
    );
  }

  Future getVideo(
    ImageSource img,
  ) async {
    final pickedFile = await picker.pickVideo(
        source: img,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(minutes: 10));
    XFile? xfilePick = pickedFile;
    setState(
      () {
        if (xfilePick != null) {
          galleryFile = File(pickedFile!.path);
        } else {
          AppToast.show('Nothing is selected', isError: true);
        }
      },
    );
  }

  Future getImage(
    ImageSource img,
  ) async {
    final pickedFile = await picker.pickImage(
      source: img,
      preferredCameraDevice: CameraDevice.front,
    );
    XFile? xfilePick = pickedFile;
    setState(
      () {
        if (xfilePick != null) {
          galleryFile = File(pickedFile!.path);
        } else {
          AppToast.show('Nothing is selected', isError: true);
        }
      },
    );
  }
}
