import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:beatjerky/models/verification_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:beatjerky/utils/role_utils.dart';

/// App-side access for the "Verified" (admin-approved) badge flow.
/// A user submits proof; an admin approves/rejects from the admin panel.
class VerificationService {
  VerificationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('verificationRequests');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Live view of the current user's request (null = never requested).
  static Stream<VerificationRequest?> watchMyRequest() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _requests.doc(uid).snapshots().map(
          (d) => d.exists ? VerificationRequest.fromDoc(d) : null,
        );
  }

  /// Uploads a proof image and returns its download URL.
  static Future<String?> uploadProof(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _storage.ref().child(
            'verification_proofs/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, s) {
      logDebugException('VerificationService.uploadProof', e, stackTrace: s);
      return null;
    }
  }

  /// Submits (or re-submits) a verification request.
  static Future<bool> submitRequest({
    required List<String> proofUrls,
    String note = '',
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return false;
    try {
      final userDoc = await _db.collection('usersData').doc(uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final roles = parseRolesFromUserData(data);
      final isOrg = rolesHaveOrganization(roles);
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      final name = [first, last].where((s) => s.isNotEmpty).join(' ');

      await _requests.doc(uid).set({
        'uid': uid,
        'name': name,
        'roles': roles,
        'type': isOrg ? 'organization' : 'individual',
        'proofUrls': proofUrls,
        'note': note.trim(),
        'status': VerifStatus.pending.value,
        'rejectReason': FieldValue.delete(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      return true;
    } catch (e, s) {
      logDebugException('VerificationService.submitRequest', e, stackTrace: s);
      return false;
    }
  }
}
