class SongModel {
  final String id;
  final String title;
  final String singer;
  final String description;
  final String fileUrl;
  final String coverImageUrl;
  final double price;
  final int year;
  final String storeId;

  SongModel({
    required this.id,
    required this.title,
    required this.singer,
    required this.description,
    required this.fileUrl,
    required this.coverImageUrl,
    required this.price,
    required this.year,
    required this.storeId,
  });

  factory SongModel.fromMap(String id, Map<String, dynamic> m) {
    return SongModel(
      id:           id,
      title:        m['title']        as String? ?? '',
      singer:       m['singer']       as String? ?? '',
      description:  m['description']  as String? ?? '',
      fileUrl:      m['fileUrl']      as String? ?? '',
      coverImageUrl: m['coverImageUrl'] as String? ?? '',
      price:        (m['price'] as num?)?.toDouble() ?? 0.0,
      year:         m['year']         as int?    ?? 0,
      storeId:      m['storeId']      as String? ?? '',
    );
  }
}
