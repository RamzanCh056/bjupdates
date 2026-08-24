import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/music_store/music_store_model.dart';

class MusicStoreProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  List<MusicStoreModel> stores = [];

  Future<void> fetchStores() async {
    final snap = await _firestore.collection('musicStores').orderBy('created_at', descending: true).get();
    stores = snap.docs.map((d) => MusicStoreModel.fromMap(d.id, d.data())).toList();
    notifyListeners();
  }

  Future<void> addStore({
    required String name,
    required int discount,
    File? imageFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    String imageUrl = '';
    if (imageFile != null) {
      final ref = _storage.ref('store_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }
    final doc = await _firestore.collection('musicStores').add({
      'name': name,
      'discount': discount,
      'imageUrl': imageUrl,
      'userId': currentUserId,
      'created_at': FieldValue.serverTimestamp(),
    });
    final snapshot = await doc.get();
    stores.insert(0, MusicStoreModel.fromMap(snapshot.id, snapshot.data()!));
    notifyListeners();
  }

  Future<void> createMusicStore({
    required String name,
    // required int discount,
    File? imageFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    String imageUrl = '';
    if (imageFile != null) {
      final ref = _storage.ref('store_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }
    final doc = await _firestore.collection('musicStores').add({
      'name': name,
      // 'discount': discount,
      'imageUrl': imageUrl,
      'userId': currentUserId,
      'created_at': FieldValue.serverTimestamp(),
    });
    final snapshot = await doc.get();
    stores.insert(0, MusicStoreModel.fromMap(snapshot.id, snapshot.data()!));
    notifyListeners();
  }

  Future<void> deleteStore(String storeId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Security check - verify the store belongs to current user
    final storeDoc = await _firestore.collection('musicStores').doc(storeId).get();
    if (!storeDoc.exists || storeDoc.data()?['userId'] != currentUserId) {
      throw Exception('You don\'t have permission to delete this store');
    }

    await _firestore.collection('musicStores').doc(storeId).delete();
    stores.removeWhere((store) => store.id == storeId);
    notifyListeners();
  }

  Future<void> updateStore({
    required String storeId,
    required String name,
    required int discount,
    File? imageFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Security check - verify the store belongs to current user
    final storeDoc = await _firestore.collection('musicStores').doc(storeId).get();
    if (!storeDoc.exists || storeDoc.data()?['userId'] != currentUserId) {
      throw Exception('You don\'t have permission to update this store');
    }

    String imageUrl = '';
    if (imageFile != null) {
      final ref = _storage.ref('store_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    final updateData = {
      'name': name,
      'discount': discount,
      if (imageFile != null) 'imageUrl': imageUrl,
    };

    await _firestore.collection('musicStores').doc(storeId).update(updateData);
    
    // Update local state
    final index = stores.indexWhere((store) => store.id == storeId);
    if (index != -1) {
      final updatedStore = MusicStoreModel(
        id: storeId,
        name: name,
        discount: discount,
        imageUrl: imageFile != null ? imageUrl : stores[index].imageUrl,
        userId: currentUserId,
      );
      stores[index] = updatedStore;
      notifyListeners();
    }
  }
}
