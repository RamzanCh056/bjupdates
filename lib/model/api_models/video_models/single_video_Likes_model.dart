

class SingleVideoLikesModelFields{
  static const String commentId='id';
  static const String userId='userId';
  static const String videoId='videoId';
  // static const String comment='comment';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
  static const String user='user';
}

class SingleVideoLikesModel{
  int likeId;
  int userId;
  int videoId;
  // String comment;
  String createdAt;
  String updatedAt;
  VideoLikesUserModel? user;

  SingleVideoLikesModel({
    required this.likeId,
    required this.userId,
    required this.videoId,
    // required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.user
  });

  factory SingleVideoLikesModel.fromJson(Map<String,dynamic>json)=>SingleVideoLikesModel(
      likeId: json[SingleVideoLikesModelFields.commentId],
      userId: json[SingleVideoLikesModelFields.userId],
      videoId: json[SingleVideoLikesModelFields.videoId],
      // comment: json[SingleVideoLikesModelFields.comment],
      createdAt: json[SingleVideoLikesModelFields.createdAt],
      updatedAt: json[SingleVideoLikesModelFields.updatedAt],
      user: VideoLikesUserModel.fromJson(json[SingleVideoLikesModelFields.user])
  );

}




class VideoLikesUserModelFields{

  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String profileImg='profileImg';


}

class VideoLikesUserModel{

  String firstName;
  String lastName;
  String profileImg;


  VideoLikesUserModel({

    required this.firstName,
    required this.lastName,
    required this.profileImg

  });

  factory VideoLikesUserModel.fromJson(Map<String,dynamic> json)=>VideoLikesUserModel(

    firstName: json[VideoLikesUserModelFields.firstName]??'First Name',
    lastName: json[VideoLikesUserModelFields.lastName]??'Last Name',
    profileImg: json[VideoLikesUserModelFields.profileImg]??''

  );

}