


class VideoUserModelFields{

  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String profileImg="profileImg";


}

class VideoUserModel{

  String firstName;
  String lastName;
  String profileImg;


  VideoUserModel({

    required this.firstName,
    required this.lastName,
    required this.profileImg

  });

  factory VideoUserModel.fromJson(Map<String,dynamic> json)=>VideoUserModel(

      firstName: json[VideoUserModelFields.firstName]??'First Name',
      lastName: json[VideoUserModelFields.lastName]??'Last Name',
      profileImg:json[VideoUserModelFields.profileImg]??""

  );

}