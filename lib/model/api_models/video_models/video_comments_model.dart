



class VideoCommentModelFields{
  static const String commentId='id';
  static const String userId='userId';
  static const String videoId='videoId';
  static const String comment='comment';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
}

class VideoCommentModel{
  int commentId;
  int userId;
  int videoId;
  String comment;
  String createdAt;
  String updatedAt;

  VideoCommentModel({
    required this.commentId,
    required this.userId,
    required this.videoId,
    required this.comment,
    required this.createdAt,
    required this.updatedAt
  });

  factory VideoCommentModel.fromJson(Map<String,dynamic>json)=>VideoCommentModel(
      commentId: json[VideoCommentModelFields.commentId],
      userId: json[VideoCommentModelFields.userId],
      videoId: json[VideoCommentModelFields.videoId],
      comment: json[VideoCommentModelFields.comment],
      createdAt: json[VideoCommentModelFields.createdAt],
      updatedAt: json[VideoCommentModelFields.updatedAt]
  );

}