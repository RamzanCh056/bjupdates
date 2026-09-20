import 'package:beatjerky/models/musician_payment_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// App-side, read-only access to the musician's payment records. Reads the
/// same `payments` collection the admin writes.
class MusicianPaymentService {
  MusicianPaymentService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('payments');

  /// Live list of this musician's payments, newest first.
  static Stream<List<Payment>> watchMyPayments(String musicianId) {
    if (musicianId.isEmpty) return Stream.value(const []);
    return _payments
        .where('musicianId', isEqualTo: musicianId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Payment.fromDoc).toList();
      list.sort((a, b) {
        final ka = a.dueDate ?? a.createdAt ?? 0;
        final kb = b.dueDate ?? b.createdAt ?? 0;
        return kb.compareTo(ka);
      });
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('MusicianPaymentService.watchMyPayments', e,
          stackTrace: s);
    });
  }
}
