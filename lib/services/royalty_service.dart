import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/invoice_models.dart' show DocStatus, DocStatusX;
import 'package:beatjerky/models/royalty_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// App-side access for royalty statements (`royaltyStatements/{id}`).
class RoyaltyService {
  RoyaltyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('royaltyStatements');
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Statements this user issued (as a label).
  static Stream<List<RoyaltyStatement>> watchIssued() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _col.where('labelUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(RoyaltyStatement.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('RoyaltyService.watchIssued', e, stackTrace: s);
    });
  }

  /// Statements addressed to this user (as an artist).
  static Stream<List<RoyaltyStatement>> watchReceived() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _col.where('artistUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(RoyaltyStatement.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('RoyaltyService.watchReceived', e, stackTrace: s);
    });
  }

  static Stream<RoyaltyStatement?> watchOne(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().map(
          (d) => d.exists ? RoyaltyStatement.fromDoc(d) : null,
        );
  }

  static Future<String?> create(RoyaltyStatement st) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final data = st.toMap();
      data['labelUid'] = uid;
      data['createdAt'] = DateTime.now().millisecondsSinceEpoch;
      final ref = await _col.add(data);
      return ref.id;
    } catch (e, s) {
      logDebugException('RoyaltyService.create', e, stackTrace: s);
      return null;
    }
  }

  static Future<bool> update(String id, RoyaltyStatement st) async {
    if (id.isEmpty) return false;
    try {
      final data = st.toMap();
      data.remove('createdAt');
      data.remove('labelUid');
      await _col.doc(id).update(data);
      return true;
    } catch (e, s) {
      logDebugException('RoyaltyService.update', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> setStatus(String id, DocStatus status) async {
    if (id.isEmpty) return false;
    try {
      await _col.doc(id).update({'status': status.value});
      return true;
    } catch (e, s) {
      logDebugException('RoyaltyService.setStatus', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> delete(String id) async {
    if (id.isEmpty) return false;
    try {
      await _col.doc(id).delete();
      return true;
    } catch (e, s) {
      logDebugException('RoyaltyService.delete', e, stackTrace: s);
      return false;
    }
  }
}
