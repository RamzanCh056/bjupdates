// lib/providers/stores_provider/store_provider.dart

import 'dart:io';

import 'package:beatjerky/screens/store/store_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class StoreProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  List<StoreModel> storeList = [];

  /// Load all stores from Firestore into `storeList`
  Future<void> fetchStores() async {
    final query = await _firestore.collection('stores').orderBy('created_at', descending: true).get();

    storeList = query.docs.map((doc) {
      return StoreModel.fromMap(doc.id, doc.data());
    }).toList();

    notifyListeners();
  }

  /// Add a new store document (and optional image) to Firestore
  Future<void> addStore({
    required String storeName,
    required int discount,
    File? imageFile,
  }) async {
    String imageUrl = '';

    // 1) Upload image to Firebase Storage (if provided)
    if (imageFile != null) {
      final ref = _storage.ref().child('store_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    // 2) Create Firestore document
    final docRef = await _firestore.collection('stores').add({
      'name': storeName,
      'discount': discount,
      'imageUrl': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 3) Read it back and insert into our local list
    final snapshot = await docRef.get();
    final newStore = StoreModel.fromMap(snapshot.id, snapshot.data()!);

    // Insert at top of list so UI updates immediately
    storeList.insert(0, newStore);
    notifyListeners();
  }
}
