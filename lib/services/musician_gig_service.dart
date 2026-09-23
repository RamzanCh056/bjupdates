import 'package:beatjerky/models/musician_gig_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// App-side data access for gigs. Reads the same `gigs` collection the admin
/// writes. A gig is linked to a musician through `assignedMusicianIds`.
class MusicianGigService {
  MusicianGigService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _gigs =>
      _db.collection('gigs');

  /// Live list of gigs this musician is assigned to, soonest first.
  static Stream<List<Gig>> watchMyGigs(String musicianId) {
    if (musicianId.isEmpty) return Stream.value(const []);
    return _gigs
        .where('assignedMusicianIds', arrayContains: musicianId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Gig.fromDoc).toList();
      list.sort((a, b) {
        final sa = a.startAt ?? 1 << 62;
        final sb = b.startAt ?? 1 << 62;
        return sa.compareTo(sb);
      });
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('MusicianGigService.watchMyGigs', e, stackTrace: s);
    });
  }

  /// Respond to an offered gig. NOTE: the admin schema keeps a single [status]
  /// on the gig, so accepting/declining sets the gig's status directly (fits
  /// the common one-musician-per-gig case).
  static Future<void> respond(String gigId, GigStatus status) async {
    await _gigs.doc(gigId).update({'status': status.value});
  }

  static Future<void> accept(String gigId) => respond(gigId, GigStatus.accepted);
  static Future<void> decline(String gigId) => respond(gigId, GigStatus.declined);
}
