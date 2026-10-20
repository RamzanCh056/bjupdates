import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/opportunity_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// App-side data access for the public "Gigs & opportunities" board.
///
/// Collection layout:
///   opportunities/{id}
///   opportunities/{id}/applications/{applicantUid}
class OpportunityService {
  OpportunityService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _opps =>
      _db.collection('opportunities');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // --- Board (browse) -------------------------------------------------------

  /// Live list of posts. Ordered by newest first (single-field index only).
  /// Status / role / city filtering is applied client-side so no composite
  /// index is required.
  static Stream<List<Opportunity>> watchBoard({
    bool openOnly = true,
    String? roleWanted,
    String? city,
  }) {
    final role = (roleWanted ?? '').trim();
    final cityQ = (city ?? '').trim().toLowerCase();
    return _opps
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) {
      var list = snap.docs.map(Opportunity.fromDoc).toList();
      if (openOnly) {
        list = list.where((o) => o.status == OpportunityStatus.open).toList();
      }
      if (role.isNotEmpty) {
        list = list.where((o) => o.rolesWanted.contains(role)).toList();
      }
      if (cityQ.isNotEmpty) {
        list = list
            .where((o) => (o.city ?? '').toLowerCase().contains(cityQ))
            .toList();
      }
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('OpportunityService.watchBoard', e, stackTrace: s);
    });
  }

  /// Posts created by [uid] (newest first).
  static Stream<List<Opportunity>> watchMyPosts(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _opps
        .where('postedByUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Opportunity.fromDoc).toList();
      list.sort((a, b) =>
          (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('OpportunityService.watchMyPosts', e, stackTrace: s);
    });
  }

  static Stream<Opportunity?> watchOne(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _opps.doc(id).snapshots().map(
          (d) => d.exists ? Opportunity.fromDoc(d) : null,
        );
  }

  // --- Create / update ------------------------------------------------------

  /// Creates a post. Returns the new doc id, or null on failure.
  static Future<String?> createOpportunity({
    required String title,
    required String description,
    required String postedByName,
    String? postedByPhoto,
    String? orgRole,
    List<String> rolesWanted = const [],
    String? city,
    String? region,
    String? postalCode,
    num? budget,
    String? currency,
    int? startAt,
    String? eventId,
    String? eventName,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = await _opps.add(<String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'postedByUid': uid,
        'postedByName': postedByName.trim(),
        'postedByPhoto': postedByPhoto,
        'orgRole': orgRole,
        'rolesWanted': rolesWanted,
        'city': city?.trim(),
        'region': region?.trim(),
        'postalCode': postalCode?.trim(),
        'budget': budget,
        'currency': currency,
        'startAt': startAt,
        'status': OpportunityStatus.open.value,
        'applicantCount': 0,
        'eventId': eventId,
        'eventName': eventName,
        'createdAt': now,
        'updatedAt': now,
      });
      return ref.id;
    } catch (e, s) {
      logDebugException('OpportunityService.createOpportunity', e, stackTrace: s);
      return null;
    }
  }

  static Future<bool> updateOpportunity(
    String id, {
    String? title,
    String? description,
    List<String>? rolesWanted,
    String? city,
    String? region,
    String? postalCode,
    num? budget,
    String? currency,
    int? startAt,
    bool clearStartAt = false,
  }) async {
    if (id.isEmpty) return false;
    try {
      final data = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (title != null) data['title'] = title.trim();
      if (description != null) data['description'] = description.trim();
      if (rolesWanted != null) data['rolesWanted'] = rolesWanted;
      if (city != null) data['city'] = city.trim();
      if (region != null) data['region'] = region.trim();
      if (postalCode != null) data['postalCode'] = postalCode.trim();
      if (budget != null) data['budget'] = budget;
      if (currency != null) data['currency'] = currency;
      if (clearStartAt) {
        data['startAt'] = null;
      } else if (startAt != null) {
        data['startAt'] = startAt;
      }
      await _opps.doc(id).update(data);
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.updateOpportunity', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> setStatus(String id, OpportunityStatus status) async {
    if (id.isEmpty) return false;
    try {
      await _opps.doc(id).update(<String, dynamic>{
        'status': status.value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.setStatus', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> deleteOpportunity(String id) async {
    if (id.isEmpty) return false;
    try {
      await _opps.doc(id).delete();
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.deleteOpportunity', e, stackTrace: s);
      return false;
    }
  }

  // --- Applications ---------------------------------------------------------

  static CollectionReference<Map<String, dynamic>> _apps(String oppId) =>
      _opps.doc(oppId).collection('applications');

  /// The current user's application to [oppId] (null if none).
  static Stream<OpportunityApplication?> watchMyApplication(String oppId) {
    final uid = _uid;
    if (uid == null || uid.isEmpty || oppId.isEmpty) {
      return Stream.value(null);
    }
    return _apps(oppId).doc(uid).snapshots().map(
          (d) => d.exists ? OpportunityApplication.fromDoc(d) : null,
        );
  }

  /// Applicants for [oppId] (owner view), excluding withdrawn, newest first.
  static Stream<List<OpportunityApplication>> watchApplicants(String oppId) {
    if (oppId.isEmpty) return Stream.value(const []);
    return _apps(oppId).snapshots().map((snap) {
      final list = snap.docs
          .map(OpportunityApplication.fromDoc)
          .where((a) => a.status != ApplicationStatus.withdrawn)
          .toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('OpportunityService.watchApplicants', e, stackTrace: s);
    });
  }

  /// The current user's applications across all posts.
  /// NOTE: requires a collection-group index on `applicantUid`.
  static Stream<List<OpportunityApplication>> watchMyApplications() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _db
        .collectionGroup('applications')
        .where('applicantUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(OpportunityApplication.fromDoc)
          .where((a) => a.status != ApplicationStatus.withdrawn)
          .toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('OpportunityService.watchMyApplications', e, stackTrace: s);
    });
  }

  /// Apply (or re-apply after a withdrawal). Increments the post's
  /// applicantCount only on the first-ever application from this user.
  static Future<bool> apply({
    required String oppId,
    required String applicantName,
    String? applicantPhoto,
    String? applicantRole,
    String message = '',
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || oppId.isEmpty) return false;
    try {
      final appRef = _apps(oppId).doc(uid);
      final oppRef = _opps.doc(oppId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(appRef);
        final firstTime = !snap.exists;
        tx.set(
          appRef,
          <String, dynamic>{
            'opportunityId': oppId,
            'applicantUid': uid,
            'applicantName': applicantName.trim(),
            'applicantPhoto': applicantPhoto,
            'applicantRole': applicantRole,
            'message': message.trim(),
            'status': ApplicationStatus.pending.value,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
        if (firstTime) {
          tx.update(oppRef, <String, dynamic>{
            'applicantCount': FieldValue.increment(1),
          });
        }
      });
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.apply', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> withdraw(String oppId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || oppId.isEmpty) return false;
    try {
      await _apps(oppId).doc(uid).update(<String, dynamic>{
        'status': ApplicationStatus.withdrawn.value,
      });
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.withdraw', e, stackTrace: s);
      return false;
    }
  }

  /// Owner sets an applicant's status (accepted / declined / pending).
  static Future<bool> setApplicationStatus(
    String oppId,
    String applicantUid,
    ApplicationStatus status,
  ) async {
    if (oppId.isEmpty || applicantUid.isEmpty) return false;
    try {
      await _apps(oppId).doc(applicantUid).update(<String, dynamic>{
        'status': status.value,
      });
      return true;
    } catch (e, s) {
      logDebugException('OpportunityService.setApplicationStatus', e,
          stackTrace: s);
      return false;
    }
  }
}
