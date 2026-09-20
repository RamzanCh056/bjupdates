import 'package:beatjerky/models/musician_document_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// App-side, read-only access to the musician's documents. Reads the same
/// `documents` collection the admin writes.
class MusicianDocumentService {
  MusicianDocumentService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _documents =>
      _db.collection('documents');

  /// Live list of this musician's documents, newest first.
  static Stream<List<MusicianDocument>> watchMyDocuments(String musicianId) {
    if (musicianId.isEmpty) return Stream.value(const []);
    return _documents
        .where('musicianId', isEqualTo: musicianId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(MusicianDocument.fromDoc).toList();
      list.sort((a, b) => (b.uploadedAt ?? 0).compareTo(a.uploadedAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('MusicianDocumentService.watchMyDocuments', e,
          stackTrace: s);
    });
  }
}
