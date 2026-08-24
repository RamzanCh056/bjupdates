import 'feed_user_model.dart';

class FeedModelFields{
  static const String feedId='id';
  static const String userId='userId';
  static const String description='description';
  static const String imageUrl='imageUrl';
  static const String storeId="storeId";
  static const String isDeleted='isDeleted';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
  static const String user='user';
  static const String feedLikes='feedLikes';
  static const String feedComments='feedComments';
  static const String store="store";
  
  // Additional fields for user data that comes directly in the feed

}


class FeedModel {
  int feedId;
  int userId;
  String description;
  String imageUrl;
  int? storeId;
  bool isDeleted;
  String createdAt;
  String updatedAt;
  FeedUserModel? user;
  List feedLikes=[];
  List feedComments=[];
  Map<String,dynamic>? store;
  
  // Additional user data fields for when user data comes directly in the feed


  FeedModel({
   required this.userId,
   required this.feedId,
   required this.description,
    required this.storeId,
   required this.isDeleted,
   required this.imageUrl,
   required this.user,
   required this.createdAt,
   required this.feedComments,
   required this.feedLikes,
   required this.updatedAt,
    required this.store,

});

  factory FeedModel.fromJson(Map<String,dynamic> json)=>FeedModel(
      userId: json[FeedModelFields.userId],
      feedId: json[FeedModelFields.feedId],
      description: json[FeedModelFields.description],
      isDeleted: json[FeedModelFields.isDeleted],
      imageUrl: json[FeedModelFields.imageUrl],
      user: json[FeedModelFields.user]!=null? FeedUserModel.fromJson(json[FeedModelFields.user]):null,
      createdAt: json[FeedModelFields.createdAt],
      feedComments: json[FeedModelFields.feedComments],
      feedLikes: json[FeedModelFields.feedLikes],
      updatedAt: json[FeedModelFields.updatedAt],
      storeId: json[FeedModelFields.storeId],
      store: json[FeedModelFields.store],
      
  );
}