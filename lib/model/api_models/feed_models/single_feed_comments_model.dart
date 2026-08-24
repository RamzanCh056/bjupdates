



class SingleFeedCommentModelFields{
  static const String commentId='id';
  static const String userId='userId';
  static const String feedId='feedId';
  static const String comment='comment';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
  static const String user='user';
}

class SingleFeedCommentModel{
  int commentId;
  int userId;
  int feedId;
  String comment;
  String createdAt;
  String updatedAt;
  CommentsUserModel? user;

  SingleFeedCommentModel({
    required this.commentId,
    required this.userId,
    required this.feedId,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.user
  });

  factory SingleFeedCommentModel.fromJson(Map<String,dynamic>json)=>SingleFeedCommentModel(
      commentId: json[SingleFeedCommentModelFields.commentId],
      userId: json[SingleFeedCommentModelFields.userId],
      feedId: json[SingleFeedCommentModelFields.feedId],
      comment: json[SingleFeedCommentModelFields.comment],
      createdAt: json[SingleFeedCommentModelFields.createdAt],
      updatedAt: json[SingleFeedCommentModelFields.updatedAt],
      user: CommentsUserModel.fromJson(json[SingleFeedCommentModelFields.user])
  );

}




class CommentsUserModelFields{

  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String profileImg='profileImg';


}

class CommentsUserModel{

  String firstName;
  String lastName;
  String profileImg;


  CommentsUserModel({

    required this.firstName,
    required this.lastName,
    required this.profileImg

  });

  factory CommentsUserModel.fromJson(Map<String,dynamic> json)=>CommentsUserModel(

    firstName: json[CommentsUserModelFields.firstName]??'First Name',
    lastName: json[CommentsUserModelFields.lastName]??'Last Name',
    profileImg: json[CommentsUserModelFields.profileImg]??''

  );

}