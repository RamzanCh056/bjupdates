import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart' show readMillis;

/// A document shared with / belonging to a musician — mirrors the admin schema
/// (`beatjerky-admin/src/lib/types.ts` → MusicianDocument). Read-only in the app.
class MusicianDocument {
  final String id;
  final String musicianId;
  final String category; // bio, media, contract, setlist, resume, etc.
  final String name;
  final String url;
  final bool isPublic;
  final int? uploadedAt;

  const MusicianDocument({
    required this.id,
    required this.musicianId,
    this.category = 'other',
    this.name = '',
    this.url = '',
    this.isPublic = false,
    this.uploadedAt,
  });

  factory MusicianDocument.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MusicianDocument.fromMap(doc.id, doc.data() ?? const {});

  factory MusicianDocument.fromMap(String id, Map<String, dynamic> data) {
    return MusicianDocument(
      id: id,
      musicianId: (data['musicianId'] ?? '').toString(),
      category: (data['category'] ?? 'other').toString(),
      name: (data['name'] ?? '').toString(),
      url: (data['url'] ?? '').toString(),
      isPublic: data['isPublic'] == true,
      uploadedAt: readMillis(data['uploadedAt']),
    );
  }

  /// Best-effort file extension derived from the name or URL (lowercased).
  String get extension {
    final source = name.contains('.') ? name : url.split('?').first;
    final dot = source.lastIndexOf('.');
    if (dot < 0 || dot == source.length - 1) return '';
    return source.substring(dot + 1).toLowerCase();
  }
}
