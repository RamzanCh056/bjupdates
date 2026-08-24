import 'dart:typed_data';

import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/models/ai_library_item.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AiLibrarySaveRequest {
  final String type;
  final String title;
  final String sourceTool;
  final String? textContent;
  final Uint8List? audioBytes;
  final String? audioFileName;
  final Map<String, dynamic> metadata;

  const AiLibrarySaveRequest({
    required this.type,
    required this.title,
    required this.sourceTool,
    this.textContent,
    this.audioBytes,
    this.audioFileName,
    this.metadata = const {},
  });
}

class AiLibraryService {
  AiLibraryService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('ai_library');
  }

  static String? get _userId => _auth.currentUser?.uid;

  static Future<String> save(AiLibrarySaveRequest request) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Please sign in to save to your library.');
    }

    final docRef = _collection(userId).doc();
    String? audioUrl;

    if (request.audioBytes != null && request.audioBytes!.isNotEmpty) {
      audioUrl = await _uploadAudio(
        userId: userId,
        itemId: docRef.id,
        bytes: request.audioBytes!,
        fileName: request.audioFileName ?? '${docRef.id}.mp3',
      );
    }

    final item = AiLibraryItem(
      id: docRef.id,
      userId: userId,
      type: request.type,
      title: request.title,
      sourceTool: request.sourceTool,
      textContent: request.textContent,
      audioUrl: audioUrl,
      metadata: request.metadata,
      createdAt: DateTime.now(),
    );

    await docRef.set(item.toMap());
    return docRef.id;
  }

  static Future<String> _uploadAudio({
    required String userId,
    required String itemId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'mp3';
    final contentType = ext == 'wav' ? 'audio/wav' : 'audio/mpeg';
    final ref = _storage.ref('ai_library/$userId/$itemId.$ext');

    try {
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (error, stackTrace) {
      logDebugException('AiLibraryService._uploadAudio', error, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Stream<List<AiLibraryItem>> watchLibrary({int limit = 50}) {
    final userId = _userId;
    if (userId == null) return Stream.value(const []);

    return _collection(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AiLibraryItem.fromMap(
                  doc.id,
                  doc.data(),
                  userId: userId,
                ),
              )
              .toList(),
        );
  }

  static Stream<List<GeneratedBeat>> watchBeats({int limit = 20}) {
    return AiBeatGeneratorService.watchUserBeats(limit: limit);
  }

  static Future<void> deleteItem(String itemId) async {
    final userId = _userId;
    if (userId == null) return;
    await _collection(userId).doc(itemId).delete();
  }

  static Future<void> toggleFavorite(String itemId, bool value) async {
    final userId = _userId;
    if (userId == null) return;
    await _collection(userId).doc(itemId).update({'isFavorite': value});
  }

  static String errorMessage(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
