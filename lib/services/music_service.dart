import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';
import '../model/music_track_model.dart';

class MusicService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Get trending music tracks
  static Stream<List<MusicTrack>> getTrendingTracks() {
    return _firestore
        .collection('musicTracks')
        .where('isTrending', isEqualTo: true)
        .orderBy('useCount', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get all music tracks
  static Stream<List<MusicTrack>> getAllTracks() {
    return _firestore
        .collection('musicTracks')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Search music tracks
  static Future<List<MusicTrack>> searchTracks(String query) async {
    try {
      final snapshot = await _firestore
          .collection('musicTracks')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error searching tracks: $e');
      return [];
    }
  }

  // Play preview of a track
  static Future<void> playPreview(String audioUrl, {Duration? startAt}) async {
    try {
      await _audioPlayer.setUrl(audioUrl);
      if (startAt != null) {
        await _audioPlayer.seek(startAt);
      }
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing preview: $e');
    }
  }

  // Stop audio preview
  static Future<void> stopPreview() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping preview: $e');
    }
  }

  // Increment use count when a track is used
  static Future<void> incrementUseCount(String trackId) async {
    try {
      await _firestore.collection('musicTracks').doc(trackId).update({
        'useCount': FieldValue.increment(1),
      });

      // Update trending status if use count is high
      final doc = await _firestore.collection('musicTracks').doc(trackId).get();
      final useCount = doc.data()?['useCount'] ?? 0;
      
      if (useCount >= 10 && !(doc.data()?['isTrending'] ?? false)) {
        await _firestore.collection('musicTracks').doc(trackId).update({
          'isTrending': true,
        });
      }
    } catch (e) {
      print('Error incrementing use count: $e');
    }
  }

  // Add a new music track
  static Future<String?> addMusicTrack(MusicTrack track) async {
    try {
      final docRef = await _firestore.collection('musicTracks').add(track.toMap());
      return docRef.id;
    } catch (e) {
      print('Error adding music track: $e');
      return null;
    }
  }

  // Get music track by ID
  static Future<MusicTrack?> getTrackById(String trackId) async {
    try {
      final doc = await _firestore.collection('musicTracks').doc(trackId).get();
      if (doc.exists) {
        return MusicTrack.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting track by ID: $e');
      return null;
    }
  }

  // Get user's uploaded tracks
  static Stream<List<MusicTrack>> getUserTracks() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('musicTracks')
        .where('uploadedBy', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MusicTrack.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Upload audio file to Firebase Storage
  static Future<String?> uploadAudioFile(String filePath, String fileName) async {
    try {
      final ref = _storage.ref('music_tracks/$fileName');
      final uploadTask = ref.putFile(File(filePath));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading audio file: $e');
      return null;
    }
  }

  // Get popular genres
  static Future<List<String>> getPopularGenres() async {
    try {
      final snapshot = await _firestore.collection('musicTracks').get();
      final genres = snapshot.docs
          .map((doc) => doc.data()['genre'] as String?)
          .where((genre) => genre != null && genre.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      
      return genres;
    } catch (e) {
      print('Error getting genres: $e');
      return ['Pop', 'Hip Hop', 'Rock', 'Electronic', 'R&B', 'Country'];
    }
  }

  // Dispose audio player
  static void dispose() {
    _audioPlayer.dispose();
  }
}
