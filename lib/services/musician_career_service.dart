import 'dart:io';
import 'dart:typed_data';

import 'package:beatjerky/models/musician_career_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// App-side data access for the Musician-Career feature.
///
/// Reads/writes the SAME Firestore collections the admin back-office uses
/// (`musicians`, `formTemplates`, `formAssignments`, `formSubmissions`).
/// See `models/musician_career_models.dart` for the shared schema contract.
///
/// Identity model (locked): `musicians` are auto-id docs; `musicianId` == the
/// doc id; a `userId` field links the profile to an app-auth user. Admin
/// pre-registered musicians have an empty `userId` — the app "claims" them by
/// email on registration. Child docs written by the app stamp `userId` so the
/// security rules stay lookup-free.
class MusicianCareerService {
  MusicianCareerService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _musicians =>
      _db.collection('musicians');
  static CollectionReference<Map<String, dynamic>> get _templates =>
      _db.collection('formTemplates');
  static CollectionReference<Map<String, dynamic>> get _assignments =>
      _db.collection('formAssignments');
  static CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection('formSubmissions');

  // -------------------------------------------------------------------------
  // Musician profile
  // -------------------------------------------------------------------------

  /// The musician profile linked to the signed-in user, or null if none.
  static Future<Musician?> getMyMusician() async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      final snap =
          await _musicians.where('userId', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return Musician.fromDoc(snap.docs.first);
    } catch (e, s) {
      logDebugException('MusicianCareerService.getMyMusician', e, stackTrace: s);
      return null;
    }
  }

  /// Live view of the signed-in user's musician profile.
  static Stream<Musician?> watchMyMusician() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);
    return _musicians
        .where('userId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : Musician.fromDoc(snap.docs.first))
        .handleError((Object e, StackTrace s) {
      logDebugException('MusicianCareerService.watchMyMusician', e,
          stackTrace: s);
    });
  }

  /// An admin pre-registered profile with this email and no linked user yet,
  /// or null. Used to offer "claim your profile" during registration.
  static Future<Musician?> findClaimableByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      final snap = await _musicians
          .where('email', isEqualTo: normalized)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        final m = Musician.fromDoc(doc);
        if (m.userId.isEmpty) return m;
      }
      return null;
    } catch (e, s) {
      logDebugException('MusicianCareerService.findClaimableByEmail', e,
          stackTrace: s);
      return null;
    }
  }

  /// Register the signed-in user as a new musician (self-serve). Returns the
  /// created profile's id.
  static Future<String> registerMusician(Musician draft) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final photoUrl = draft.photoUrl ?? await currentUserPhotoUrl();
    final payload = draft
        .copyWith(
          userId: uid,
          email: draft.email.trim().toLowerCase(),
          photoUrl: photoUrl,
        )
        .toMap(forCreate: true);
    final ref = await _musicians.add(payload);
    return ref.id;
  }

  /// Link an existing admin pre-registered profile to the signed-in user.
  /// Only succeeds while the profile has no `userId`.
  static Future<void> claimMusician(String musicianId) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not signed in');
    final photoUrl = await currentUserPhotoUrl();
    await _musicians.doc(musicianId).update({
      'userId': uid,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// The signed-in user's app profile photo (usersData/{uid}.profileImage).
  static Future<String?> currentUserPhotoUrl() async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('usersData').doc(uid).get();
      final url = doc.data()?['profileImage']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (e, st) {
      logDebugException('MusicianCareerService.currentUserPhotoUrl', e,
          stackTrace: st);
      return null;
    }
  }

  /// Mirror a new app profile photo onto the user's musician profile so the
  /// hub and the admin back-office show the same picture. No-op if the user
  /// has no musician profile. Safe to call fire-and-forget.
  static Future<void> syncPhotoUrl(String photoUrl) async {
    final uid = currentUid;
    if (uid == null || photoUrl.isEmpty) return;
    try {
      final snap =
          await _musicians.where('userId', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      if ((doc.data()['photoUrl']?.toString() ?? '') == photoUrl) return;
      await doc.reference.update({
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      logDebugException('MusicianCareerService.syncPhotoUrl', e,
          stackTrace: st);
    }
  }

  /// Patch fields on the user's own musician profile.
  static Future<void> updateMusician(
      String musicianId, Map<String, dynamic> patch) async {
    await _musicians.doc(musicianId).update({
      ...patch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // -------------------------------------------------------------------------
  // Templates
  // -------------------------------------------------------------------------

  /// Load a single form template by id.
  static Future<FormTemplate?> getTemplate(String templateId) async {
    try {
      final doc = await _templates.doc(templateId).get();
      if (!doc.exists) return null;
      return FormTemplate.fromDoc(doc);
    } catch (e, s) {
      logDebugException('MusicianCareerService.getTemplate', e, stackTrace: s);
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Assignments ("My Forms")
  // -------------------------------------------------------------------------

  /// Live list of forms assigned to this musician, newest first.
  static Stream<List<FormAssignment>> watchMyAssignments(String musicianId) {
    if (musicianId.isEmpty) return Stream.value(const []);
    return _assignments
        .where('musicianId', isEqualTo: musicianId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(FormAssignment.fromDoc).toList();
      list.sort((a, b) => (b.assignedAt ?? 0).compareTo(a.assignedAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('MusicianCareerService.watchMyAssignments', e,
          stackTrace: s);
    });
  }

  // -------------------------------------------------------------------------
  // Submissions
  // -------------------------------------------------------------------------

  /// Deterministic submission doc id: one submission per assignment.
  static DocumentReference<Map<String, dynamic>> _submissionRef(
          String assignmentId) =>
      _submissions.doc(assignmentId);

  /// Live view of the submission for an assignment (may not exist yet).
  static Stream<FormSubmission?> watchSubmission(String assignmentId) {
    return _submissionRef(assignmentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FormSubmission.fromDoc(doc);
    }).handleError((Object e, StackTrace s) {
      logDebugException('MusicianCareerService.watchSubmission', e,
          stackTrace: s);
    });
  }

  /// One-shot read of the submission for an assignment.
  static Future<FormSubmission?> getSubmission(String assignmentId) async {
    try {
      final doc = await _submissionRef(assignmentId).get();
      if (!doc.exists) return null;
      return FormSubmission.fromDoc(doc);
    } catch (e, s) {
      logDebugException('MusicianCareerService.getSubmission', e,
          stackTrace: s);
      return null;
    }
  }

  /// Create or update the draft answers for an assignment (autosave).
  /// Keeps status as inProgress unless already submitted/approved.
  static Future<void> saveDraft({
    required FormAssignment assignment,
    required Map<String, dynamic> answers,
    Map<String, String>? files,
  }) async {
    final uid = currentUid ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'assignmentId': assignment.id,
      'templateId': assignment.templateId,
      'musicianId': assignment.musicianId,
      'answers': answers,
      if (files != null && files.isNotEmpty) 'files': files,
      'status': FormStatus.inProgress.value,
      'updatedAt': now,
      if (uid.isNotEmpty) 'userId': uid,
    };
    await _submissionRef(assignment.id).set(data, SetOptions(merge: true));

    // Reflect progress on the assignment so admin "My Forms" lists stay live.
    if (assignment.status == FormStatus.notStarted) {
      await _assignments
          .doc(assignment.id)
          .update({'status': FormStatus.inProgress.value}).catchError(
              (Object e, StackTrace s) {
        logDebugException('MusicianCareerService.saveDraft/assignment', e,
            stackTrace: s);
      });
    }
  }

  /// Finalize a submission for review.
  static Future<void> submit({
    required FormAssignment assignment,
    required Map<String, dynamic> answers,
    Map<String, String>? files,
  }) async {
    final uid = currentUid ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'assignmentId': assignment.id,
      'templateId': assignment.templateId,
      'musicianId': assignment.musicianId,
      'answers': answers,
      if (files != null && files.isNotEmpty) 'files': files,
      'status': FormStatus.submitted.value,
      'submittedAt': now,
      'updatedAt': now,
      if (uid.isNotEmpty) 'userId': uid,
    };
    await _submissionRef(assignment.id).set(data, SetOptions(merge: true));
    await _assignments
        .doc(assignment.id)
        .update({'status': FormStatus.submitted.value}).catchError(
            (Object e, StackTrace s) {
      logDebugException('MusicianCareerService.submit/assignment', e,
          stackTrace: s);
    });
  }

  // -------------------------------------------------------------------------
  // File field uploads
  // -------------------------------------------------------------------------

  /// Upload a file answering a file/image/document field. Returns the download
  /// URL to store in the submission's `files` map under the field id.
  static Future<String> uploadFieldFile({
    required String assignmentId,
    required String fieldId,
    required File file,
    String? fileName,
  }) async {
    final uid = currentUid ?? 'anon';
    final raw = fileName ?? file.path.split('/').last;
    final safeName = raw.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        'musician_forms/$uid/$assignmentId/$fieldId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Upload raw bytes answering a field (e.g. a captured signature PNG).
  /// Returns the download URL to store under the field id.
  static Future<String> uploadFieldBytes({
    required String assignmentId,
    required String fieldId,
    required Uint8List bytes,
    String extension = 'png',
    String contentType = 'image/png',
  }) async {
    final uid = currentUid ?? 'anon';
    final path =
        'musician_forms/$uid/$assignmentId/$fieldId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
