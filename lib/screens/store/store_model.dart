import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String name;
  final int discount;
  final String imageUrl;

  StoreModel({
    required this.id,
    required this.name,
    required this.discount,
    required this.imageUrl,
  });

  /// Create a StoreModel from a Firestore document
  factory StoreModel.fromMap(String id, Map<String, dynamic> data) {
    return StoreModel(
      id:       id,
      name:     data['name']     as String? ?? '',
      discount: data['discount'] as int?    ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  /// Convert to a Firestore-compatible map (optional)
  Map<String, dynamic> toMap() {
    return {
      'name':       name,
      'discount':   discount,
      'imageUrl':   imageUrl,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}