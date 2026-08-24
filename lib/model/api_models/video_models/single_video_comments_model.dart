




class SingleVideoCommentModelFields{
  static const String commentId='id';
  static const String userId='userId';
  static const String videoId='videoId';
  static const String comment='comment';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
  static const String user='user';
}

class SingleVideoCommentModel{
  int commentId;
  int userId;
  int videoId;
  String comment;
  String createdAt;
  String updatedAt;
  VideoCommentsUserModel? user;

  SingleVideoCommentModel({
    required this.commentId,
    required this.userId,
    required this.videoId,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.user
  });

  factory SingleVideoCommentModel.fromJson(Map<String,dynamic>json)=>SingleVideoCommentModel(
      commentId: json[SingleVideoCommentModelFields.commentId],
      userId: json[SingleVideoCommentModelFields.userId],
      videoId: json[SingleVideoCommentModelFields.videoId],
      comment: json[SingleVideoCommentModelFields.comment],
      createdAt: json[SingleVideoCommentModelFields.createdAt],
      updatedAt: json[SingleVideoCommentModelFields.updatedAt],
      user: json[SingleVideoCommentModelFields.user]!=null?VideoCommentsUserModel.fromJson(json[SingleVideoCommentModelFields.user]):null
  );

}




class VideoCommentsUserModelFields{

  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String profileImg='profileImg';


}

class VideoCommentsUserModel{

  String firstName;
  String lastName;
  String profileImg;


  VideoCommentsUserModel({

    required this.firstName,
    required this.lastName,
    required this.profileImg

  });

  factory VideoCommentsUserModel.fromJson(Map<String,dynamic> json)=>VideoCommentsUserModel(

    firstName: json[VideoCommentsUserModelFields.firstName]??'First Name',
    lastName: json[VideoCommentsUserModelFields.lastName]??'Last Name',
    profileImg: json[VideoCommentsUserModelFields.profileImg]??''

  );

}