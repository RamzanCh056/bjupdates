
import 'package:beatjerky/model/api_models/video_models/video_user_model.dart';

import 'video_comments_model.dart';

class VideoModelFields{
  static const String videoId='id';
  static const String userId='userId';
  static const String description='description';
  static const String videoUrl='videoUrl';
  static const String isDeleted='isDeleted';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
  static const String user='user';
  static const String videoLikes='videoLikes';
  static const String videoComments='videoComments';
}


class VideoModel {
  int videoId;
  int userId;
  String description;
  String videoUrl;
  bool isDeleted;
  String createdAt;
  String updatedAt;
  VideoUserModel? user;
  List videoLikes=[];
  List videoComments=[];

  VideoModel({
   required this.userId,
   required this.videoId,
   required this.description,
   required this.isDeleted,
   required this.videoUrl,
   required this.user,
   required this.createdAt,
   required this.videoComments,
   required this.videoLikes,
   required this.updatedAt
});

  factory VideoModel.fromJson(Map<String,dynamic> json)=>VideoModel(
      userId: json[VideoModelFields.userId],
      videoId: json[VideoModelFields.videoId],
      description: json[VideoModelFields.description],
      isDeleted: json[VideoModelFields.isDeleted],
      videoUrl: json[VideoModelFields.videoUrl],
      user: json[VideoModelFields.user]!=null?VideoUserModel.fromJson(json[VideoModelFields.user]):null,
      createdAt: json[VideoModelFields.createdAt],
      videoComments: json[VideoModelFields.videoComments],
      videoLikes: json[VideoModelFields.videoLikes],
      updatedAt: json[VideoModelFields.updatedAt]
  );
}