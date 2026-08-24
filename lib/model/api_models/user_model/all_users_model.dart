


class AllUserModelFields{
  static const String userId='id';
  static const String firstName='firstName';
  static const String lastName='lastName';
  static const String email='email';
  static const String password='password';
  static const String isAdmin='isAdmin';
  static const String isDeleted='isDeleted';
  static const String profileImg='profileImg';
  static const String isOnline='isOnline';
  static const String lastOnline='lastOnline';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
}

class AllUserModel{
  int userId;
  String firstName;
  String lastName;
  String email;
  String password;
  bool isAdmin;
  bool isDeleted;
  String? profileImg;
  bool isOnline;
  String lastOnline;
  String createdAt;
  String updatedAt;

  AllUserModel({
    required this.userId,
   required this.firstName,
   required this.lastName,
   required this.email,
    required this.password,
    required this.isAdmin,
    required this.isDeleted,
    required this.profileImg,
    required this.isOnline,
    required this.lastOnline,
    required this.createdAt,
    required this.updatedAt,
});

  factory AllUserModel.fromJson(Map<String,dynamic> json)=>AllUserModel(
      userId: json[AllUserModelFields.userId],
      firstName: json[AllUserModelFields.firstName],
      lastName: json[AllUserModelFields.lastName],
      email: json[AllUserModelFields.email],
      password: json[AllUserModelFields.password],
      isAdmin: json[AllUserModelFields.isAdmin],
      isDeleted: json[AllUserModelFields.isDeleted],
      profileImg: json[AllUserModelFields.profileImg],
      isOnline: json[AllUserModelFields.isOnline],
      lastOnline: json[AllUserModelFields.lastOnline]??'',
      createdAt: json[AllUserModelFields.createdAt]??'',
      updatedAt: json[AllUserModelFields.updatedAt]??''
  );

}