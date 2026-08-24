


class FeedUserModelFields{

  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String profileImg="profileImage"; // Changed from "profileImg" to "profileImage"

}

class FeedUserModel{

  String firstName;
  String lastName;
  String profileImg;


  FeedUserModel({

    required this.firstName,
    required this.lastName,
    required this.profileImg

  });

  factory FeedUserModel.fromJson(Map<String,dynamic> json)=>FeedUserModel(

      firstName: json[FeedUserModelFields.firstName]??'First Name',
      lastName: json[FeedUserModelFields.lastName]??'Last Name',
      profileImg: json['profileImage'] ?? 
                  json[FeedUserModelFields.profileImg] ?? 
                  json['avatar'] ?? 
                  json['image'] ?? 
                  json['photo'] ?? 
                  ""
  );

}