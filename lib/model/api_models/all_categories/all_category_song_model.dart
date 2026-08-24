


class CategorySongsModelFields{
  static const String id='id';
  static const String title='title';
  static const String singer='singer';
  static const String year='year';
  static const String descriptionOfSong='descriptionOfSong';
  static const String fileURL='fileURL';
  static const String coverImageURL='coverImageURL';
  static const String songCategoryID='songCategoryID';
  static const String createdAt='createdAt';
  static const String updatedAt='updatedAt';
}

class CategoriesSongModel{
  final int id;
  final String title;
  final String singer;
  final String year;
  final String descriptionOfSong;
  final String fileURL;
  final String? coverImageURL;
  final int songCategoryID;
  final String createdAt;
  final String updatedAt;

  CategoriesSongModel({
    required this.id,
    required this.title,
    required this.singer,
    required this.year,
    required this.descriptionOfSong,
    required this.fileURL,
    required this.coverImageURL,
    required this.songCategoryID,
    required this.createdAt,
    required this.updatedAt,
});


  factory CategoriesSongModel.fromJson(Map<String,dynamic> json)=>CategoriesSongModel(
      id: json[CategorySongsModelFields.id],
      title: json[CategorySongsModelFields.title],
      singer: json[CategorySongsModelFields.singer],
      year: json[CategorySongsModelFields.year]??"",
      descriptionOfSong: json[CategorySongsModelFields.descriptionOfSong],
      fileURL: json[CategorySongsModelFields.fileURL],
      coverImageURL: json[CategorySongsModelFields.coverImageURL],
      songCategoryID: json[CategorySongsModelFields.songCategoryID],
      createdAt: json[CategorySongsModelFields.createdAt],
      updatedAt: json[CategorySongsModelFields.updatedAt]
  );


}
