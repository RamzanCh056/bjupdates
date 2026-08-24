class MusicStoreModel {
  final String id;
  final String name;
  final String imageUrl;
  final int discount;
  final String userId;

  MusicStoreModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.discount,
    required this.userId,
  });

  factory MusicStoreModel.fromMap(String id, Map<String, dynamic> m) {
    return MusicStoreModel(
      id: id,
      name: m['name'] as String? ?? '',
      imageUrl: m['imageUrl'] as String? ?? '',
      discount: m['discount'] as int? ?? 0,
      userId: m['userId'] as String? ?? '',
    );
  }
}
