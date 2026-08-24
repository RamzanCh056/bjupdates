



class VideoLikesModelFields{
  static const String likeId='id';
  static const String userId='userId';
  static const String videoId='videoId';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
}

class VideoLikesModel{
  int likeId;
  int userId;
  int videoId;
  String createdAt;
  String updatedAt;

  VideoLikesModel({
   required this.likeId,
   required this.userId,
   required this.videoId,
   required this.createdAt,
   required this.updatedAt
});

  factory VideoLikesModel.fromJson(Map<String,dynamic>json)=>VideoLikesModel(
      likeId: json[VideoLikesModelFields.likeId],
      userId: json[VideoLikesModelFields.userId],
      videoId: json[VideoLikesModelFields.videoId],
      createdAt: json[VideoLikesModelFields.createdAt],
      updatedAt: json[VideoLikesModelFields.updatedAt]
  );

}