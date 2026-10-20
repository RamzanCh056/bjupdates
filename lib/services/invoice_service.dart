import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/invoice_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// App-side access for DJ invoices (`invoices/{id}`).
class InvoiceService {
  InvoiceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('invoices');
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<List<Invoice>> watchMine() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _col.where('djUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(Invoice.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('InvoiceService.watchMine', e, stackTrace: s);
    });
  }

  static Stream<Invoice?> watchOne(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().map(
          (d) => d.exists ? Invoice.fromDoc(d) : null,
        );
  }

  static Future<String?> create(Invoice inv) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final data = inv.toMap();
      data['djUid'] = uid;
      data['createdAt'] = DateTime.now().millisecondsSinceEpoch;
      final ref = await _col.add(data);
      return ref.id;
    } catch (e, s) {
      logDebugException('InvoiceService.create', e, stackTrace: s);
      return null;
    }
  }

  static Future<bool> update(String id, Invoice inv) async {
    if (id.isEmpty) return false;
    try {
      final data = inv.toMap();
      data.remove('createdAt');
      data.remove('djUid');
      await _col.doc(id).update(data);
      return true;
    } catch (e, s) {
      logDebugException('InvoiceService.update', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> setStatus(String id, DocStatus status) async {
    if (id.isEmpty) return false;
    try {
      await _col.doc(id).update({'status': status.value});
      return true;
    } catch (e, s) {
      logDebugException('InvoiceService.setStatus', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> delete(String id) async {
    if (id.isEmpty) return false;
    try {
      await _col.doc(id).delete();
      return true;
    } catch (e, s) {
      logDebugException('InvoiceService.delete', e, stackTrace: s);
      return false;
    }
  }
}
