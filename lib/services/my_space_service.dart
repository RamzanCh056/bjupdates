import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/musician_gig_models.dart';
import 'package:beatjerky/models/opportunity_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// Something on My Space that the user may want to act on.
enum AttentionKind { reviewApplicants, accepted }

class AttentionItem {
  final AttentionKind kind;
  final String title;
  final String subtitle;

  /// Opportunity doc id (empty for aggregate items).
  final String refId;

  const AttentionItem({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.refId = '',
  });
}

/// Aggregated tracking numbers for the signed-in professional.
class MySpaceSummary {
  final int events;
  final int opportunities;
  final int opportunitiesOpen;
  final int applicantsReceived;
  final int applications;
  final int applicationsPending;
  final int applicationsAccepted;
  final int gigs;
  final int gigsUpcoming;
  final List<AttentionItem> attention;

  const MySpaceSummary({
    this.events = 0,
    this.opportunities = 0,
    this.opportunitiesOpen = 0,
    this.applicantsReceived = 0,
    this.applications = 0,
    this.applicationsPending = 0,
    this.applicationsAccepted = 0,
    this.gigs = 0,
    this.gigsUpcoming = 0,
    this.attention = const [],
  });
}

/// Loads the user's professional activity for the "My Space" tracking hub.
class MySpaceService {
  MySpaceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<MySpaceSummary> loadSummary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const MySpaceSummary();

    final results = await Future.wait([
      _events(uid),
      _opportunities(uid),
      _applications(uid),
      _gigs(uid),
    ]);

    final ev = results[0] as int;
    final opp = results[1] as _OppAgg;
    final app = results[2] as _AppAgg;
    final gig = results[3] as _GigAgg;

    final attention = <AttentionItem>[
      ...opp.attention,
      if (app.accepted > 0)
        AttentionItem(
          kind: AttentionKind.accepted,
          title: 'You were accepted',
          subtitle:
              '${app.accepted} opportunit${app.accepted == 1 ? 'y' : 'ies'} · tap to view',
        ),
    ];

    return MySpaceSummary(
      events: ev,
      opportunities: opp.total,
      opportunitiesOpen: opp.open,
      applicantsReceived: opp.applicants,
      applications: app.total,
      applicationsPending: app.pending,
      applicationsAccepted: app.accepted,
      gigs: gig.total,
      gigsUpcoming: gig.upcoming,
      attention: attention,
    );
  }

  static Future<int> _events(String uid) async {
    try {
      final snap = await _db
          .collection('events')
          .where('ownerId', isEqualTo: uid)
          .get();
      return snap.docs.length;
    } catch (e, s) {
      logDebugException('MySpaceService._events', e, stackTrace: s);
      return 0;
    }
  }

  static Future<_OppAgg> _opportunities(String uid) async {
    try {
      final snap = await _db
          .collection('opportunities')
          .where('postedByUid', isEqualTo: uid)
          .get();
      var open = 0;
      var applicants = 0;
      final attention = <AttentionItem>[];
      for (final doc in snap.docs) {
        final o = Opportunity.fromDoc(doc);
        applicants += o.applicantCount;
        if (o.status == OpportunityStatus.open) open++;
        if (o.status == OpportunityStatus.open && o.applicantCount > 0) {
          attention.add(AttentionItem(
            kind: AttentionKind.reviewApplicants,
            title: o.title.isEmpty ? 'Opportunity' : o.title,
            subtitle:
                '${o.applicantCount} applicant${o.applicantCount == 1 ? '' : 's'} to review',
            refId: doc.id,
          ));
        }
      }
      return _OppAgg(
        total: snap.docs.length,
        open: open,
        applicants: applicants,
        attention: attention,
      );
    } catch (e, s) {
      logDebugException('MySpaceService._opportunities', e, stackTrace: s);
      return const _OppAgg();
    }
  }

  static Future<_AppAgg> _applications(String uid) async {
    try {
      final snap = await _db
          .collectionGroup('applications')
          .where('applicantUid', isEqualTo: uid)
          .get();
      final apps = snap.docs
          .map(OpportunityApplication.fromDoc)
          .where((a) => a.status != ApplicationStatus.withdrawn)
          .toList();
      var pending = 0;
      var accepted = 0;
      for (final a in apps) {
        if (a.status == ApplicationStatus.pending) pending++;
        if (a.status == ApplicationStatus.accepted) accepted++;
      }
      return _AppAgg(total: apps.length, pending: pending, accepted: accepted);
    } catch (e, s) {
      logDebugException('MySpaceService._applications', e, stackTrace: s);
      return const _AppAgg();
    }
  }

  static Future<_GigAgg> _gigs(String uid) async {
    try {
      final snap = await _db
          .collection('gigs')
          .where('assignedMusicianIds', arrayContains: uid)
          .get();
      final now = DateTime.now();
      var upcoming = 0;
      var active = 0;
      for (final doc in snap.docs) {
        final g = Gig.fromDoc(doc);
        if (g.status == GigStatus.cancelled ||
            g.status == GigStatus.declined) {
          continue;
        }
        active++;
        final d = g.startDate;
        if (d != null && d.isAfter(now)) upcoming++;
      }
      return _GigAgg(total: active, upcoming: upcoming);
    } catch (e, s) {
      logDebugException('MySpaceService._gigs', e, stackTrace: s);
      return const _GigAgg();
    }
  }
}

class _OppAgg {
  final int total;
  final int open;
  final int applicants;
  final List<AttentionItem> attention;
  const _OppAgg({
    this.total = 0,
    this.open = 0,
    this.applicants = 0,
    this.attention = const [],
  });
}

class _AppAgg {
  final int total;
  final int pending;
  final int accepted;
  const _AppAgg({this.total = 0, this.pending = 0, this.accepted = 0});
}

class _GigAgg {
  final int total;
  final int upcoming;
  const _GigAgg({this.total = 0, this.upcoming = 0});
}
