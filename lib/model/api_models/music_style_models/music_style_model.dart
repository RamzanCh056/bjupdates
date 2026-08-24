



class MusicStyleModelFields{
  static const String id='id';
  static const String musicStyleName='musicStyleName';
  static const String musicStyleDescription='musicStyleDescription';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';

}

class MusicStyleModel{
  final int id;
  final String musicStyleName;
  final String musicStyleDescription;
  final String createdAt;
  final String updatedAt;


  MusicStyleModel({
    required this.id,
    required this.musicStyleName,
    required this.musicStyleDescription,
    required this.createdAt,
    required this.updatedAt,

});

  factory MusicStyleModel.fromJson(Map<String,dynamic> json)=>MusicStyleModel(
      id: json[MusicStyleModelFields.id],
      musicStyleName: json[MusicStyleModelFields.musicStyleName],
      musicStyleDescription: json[MusicStyleModelFields.musicStyleDescription],
      createdAt: json[MusicStyleModelFields.createdAt],
      updatedAt: json[MusicStyleModelFields.updatedAt],
  );

}