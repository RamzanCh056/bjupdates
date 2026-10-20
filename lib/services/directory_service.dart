import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/directory_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// Professional directory: browsable list of users by professional role.
///
/// A user appears once per professional role they have. With a role filter
/// active, only that role's entries show; with no role filter, the list is
/// collapsed to one entry per user (their first role) to avoid duplicates.
class DirectoryService {
  DirectoryService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<List<DirectoryEntry>> watchDirectory({
    String? roleFilter,
    String? query,
  }) {
    final role = (roleFilter ?? '').trim();
    final q = (query ?? '').trim().toLowerCase();
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return _db
        .collection('usersData')
        .limit(400)
        .snapshots()
        .map((snap) {
      final list = <DirectoryEntry>[];
      final seenUids = <String>{};
      for (final doc in snap.docs) {
        if (myUid != null && doc.id == myUid) continue;
        final entries = DirectoryEntry.fromDoc(doc);
        for (final e in entries) {
          if (role.isNotEmpty) {
            if (e.roleKey != role) continue;
          } else {
            // No role filter → one entry per user.
            if (seenUids.contains(e.uid)) continue;
            seenUids.add(e.uid);
          }
          if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) continue;
          list.add(e);
        }
      }
      list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('DirectoryService.watchDirectory', e, stackTrace: s);
    });
  }
}
