import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../screens/music_store/song_model.dart';

class SongProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  List<SongModel> songs = [];

  Future<void> fetchSongs(String storeId) async {
    final snap = await _firestore.collection('songs').where('storeId', isEqualTo: storeId).get();
    songs = snap.docs.map((d) => SongModel.fromMap(d.id, d.data())).toList();
    notifyListeners();
  }

  Future<void> addSong({
    required String storeId,
    required String title,
    required String singer,
    required String description,
    required double price,
    required int year,
    File? file,
    File? coverImage,
  }) async {
    String fileUrl = '';
    if (file != null) {
      final ref = _storage.ref('song_files/${DateTime.now().millisecondsSinceEpoch}.mp3');
      await ref.putFile(file);
      fileUrl = await ref.getDownloadURL();
    }
    String coverUrl = '';
    if (coverImage != null) {
      final cref = _storage.ref('song_covers/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await cref.putFile(coverImage);
      coverUrl = await cref.getDownloadURL();
    }
    final doc = await _firestore.collection('songs').add({
      'storeId': storeId,
      'title': title,
      'singer': singer,
      'description': description,
      'price': price,
      'year': year,
      'fileUrl': fileUrl,
      'coverImageUrl': coverUrl,
      'created_at': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
    final snapshot = await doc.get();
    songs.insert(0, SongModel.fromMap(snapshot.id, snapshot.data()!));
    notifyListeners();
  }

  Future<void> deleteSong(String songId) async {
    final song = songs.firstWhere((s) => s.id == songId);
    
    // Delete files from storage
    if (song.fileUrl.isNotEmpty) {
      try {
        final fileRef = _storage.refFromURL(song.fileUrl);
        await fileRef.delete();
      } catch (e) {
        print('Error deleting song file: $e');
      }
    }
    
    if (song.coverImageUrl.isNotEmpty) {
      try {
        final coverRef = _storage.refFromURL(song.coverImageUrl);
        await coverRef.delete();
      } catch (e) {
        print('Error deleting cover image: $e');
      }
    }

    // Delete document from Firestore
    await _firestore.collection('songs').doc(songId).delete();
    
    // Update local state
    songs.removeWhere((s) => s.id == songId);
    notifyListeners();
  }

  Future<void> updateSong({
    required String songId,
    required String title,
    required String singer,
    required String description,
    required double price,
    required int year,
    File? file,
    File? coverImage,
  }) async {
    final song = songs.firstWhere((s) => s.id == songId);
    String fileUrl = song.fileUrl;
    String coverUrl = song.coverImageUrl;

    // Update files if new ones are provided
    if (file != null) {
      // Delete old file
      if (fileUrl.isNotEmpty) {
        try {
          final oldRef = _storage.refFromURL(fileUrl);
          await oldRef.delete();
        } catch (e) {
          print('Error deleting old song file: $e');
        }
      }
      // Upload new file
      final ref = _storage.ref('song_files/${DateTime.now().millisecondsSinceEpoch}.mp3');
      await ref.putFile(file);
      fileUrl = await ref.getDownloadURL();
    }

    if (coverImage != null) {
      // Delete old cover
      if (coverUrl.isNotEmpty) {
        try {
          final oldRef = _storage.refFromURL(coverUrl);
          await oldRef.delete();
        } catch (e) {
          print('Error deleting old cover image: $e');
        }
      }
      // Upload new cover
      final cref = _storage.ref('song_covers/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await cref.putFile(coverImage);
      coverUrl = await cref.getDownloadURL();
    }

    // Update Firestore document
    await _firestore.collection('songs').doc(songId).update({
      'title': title,
      'singer': singer,
      'description': description,
      'price': price,
      'year': year,
      'fileUrl': fileUrl,
      'coverImageUrl': coverUrl,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update local state
    final index = songs.indexWhere((s) => s.id == songId);
    if (index != -1) {
      songs[index] = SongModel(
        id: songId,
        storeId: song.storeId,
        title: title,
        singer: singer,
        description: description,
        price: price,
        year: year,
        fileUrl: fileUrl,
        coverImageUrl: coverUrl,
      );
      notifyListeners();
    }
  }
}
