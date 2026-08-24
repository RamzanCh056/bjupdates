
import 'video_comments_model.dart';

class CurrentUserVideoModelFields {
  static const String videoId = 'id';
  static const String userId = 'userId';
  static const String description = 'description';
  static const String videoUrl = 'videoUrl';
  static const String isDeleted = 'isDeleted';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String videoLikes = 'videoLikes';
  static const String videoComments = 'videoComments';
}

class CurrentUserVideoModel {
  int videoId;
  int userId;
  String description;
  String videoUrl;
  bool isDeleted;
  String createdAt;
  String updatedAt;
  List videoLikes = [];
  List videoComments = [];

  CurrentUserVideoModel(
      {required this.userId,
      required this.videoId,
      required this.description,
      required this.isDeleted,
      required this.videoUrl,
      required this.createdAt,
      required this.videoComments,
      required this.videoLikes,
      required this.updatedAt});

  factory CurrentUserVideoModel.fromJson(Map<String, dynamic> json) =>
      CurrentUserVideoModel(
          userId: json[CurrentUserVideoModelFields.userId],
          videoId: json[CurrentUserVideoModelFields.videoId],
          description: json[CurrentUserVideoModelFields.description],
          isDeleted: json[CurrentUserVideoModelFields.isDeleted],
          videoUrl: json[CurrentUserVideoModelFields.videoUrl],
          createdAt: json[CurrentUserVideoModelFields.createdAt],
          videoComments: json[CurrentUserVideoModelFields.videoComments],
          videoLikes: json[CurrentUserVideoModelFields.videoLikes],
          updatedAt: json[CurrentUserVideoModelFields.updatedAt]);
}
