import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:beatjerky/models/musician_gig_models.dart';
import 'package:beatjerky/models/opportunity_models.dart';
import 'package:beatjerky/models/schedule_models.dart';
import 'package:beatjerky/screens/event_screens/event_model.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// Aggregates the signed-in user's dated commitments into one calendar feed:
///   • events they own        (`events` where ownerId == uid)
///   • gigs assigned to them   (`gigs` where assignedMusicianIds contains uid)
///   • opportunities they posted and ones they were accepted to
class ScheduleService {
  ScheduleService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Loads every dated item for the current user, sorted soonest first.
  /// Each source is guarded so one failure doesn't drop the rest.
  static Future<List<ScheduleItem>> loadMySchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final results = await Future.wait<List<ScheduleItem>>([
      _loadEvents(uid),
      _loadGigs(uid),
      _loadPostedOpportunities(uid),
      _loadAcceptedOpportunities(uid),
    ]);

    final all = <ScheduleItem>[];
    for (final r in results) {
      all.addAll(r);
    }
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  static Future<List<ScheduleItem>> _loadEvents(String uid) async {
    try {
      final snap = await _db
          .collection('events')
          .where('ownerId', isEqualTo: uid)
          .get();
      final items = <ScheduleItem>[];
      for (final doc in snap.docs) {
        final e = Event1Model.fromMap(doc.id, doc.data());
        final date = DateTime.tryParse(e.date);
        if (date == null) continue;
        final time = (e.startTime.isNotEmpty && e.endTime.isNotEmpty)
            ? '${e.startTime} – ${e.endTime}'
            : (e.startTime.isNotEmpty ? e.startTime : null);
        items.add(ScheduleItem(
          id: 'event_${doc.id}',
          kind: ScheduleKind.event,
          title: e.eventName.isEmpty ? 'Event' : e.eventName,
          subtitle: e.artistName.isEmpty ? null : e.artistName,
          date: date,
          time: time,
          location: e.place.isEmpty ? null : e.place,
          refId: doc.id,
        ));
      }
      return items;
    } catch (e, s) {
      logDebugException('ScheduleService._loadEvents', e, stackTrace: s);
      return const [];
    }
  }

  static Future<List<ScheduleItem>> _loadGigs(String uid) async {
    try {
      final snap = await _db
          .collection('gigs')
          .where('assignedMusicianIds', arrayContains: uid)
          .get();
      final items = <ScheduleItem>[];
      for (final doc in snap.docs) {
        final g = Gig.fromDoc(doc);
        final date = g.startDate;
        if (date == null) continue;
        if (g.status == GigStatus.cancelled ||
            g.status == GigStatus.declined) {
          continue;
        }
        items.add(ScheduleItem(
          id: 'gig_${doc.id}',
          kind: ScheduleKind.gig,
          title: g.title.isEmpty ? 'Gig' : g.title,
          subtitle: g.venue ?? g.organizer,
          date: date,
          time: _hhmm(date),
          location: g.address ?? g.venue,
          refId: doc.id,
        ));
      }
      return items;
    } catch (e, s) {
      logDebugException('ScheduleService._loadGigs', e, stackTrace: s);
      return const [];
    }
  }

  static Future<List<ScheduleItem>> _loadPostedOpportunities(
      String uid) async {
    try {
      final snap = await _db
          .collection('opportunities')
          .where('postedByUid', isEqualTo: uid)
          .get();
      final items = <ScheduleItem>[];
      for (final doc in snap.docs) {
        final o = Opportunity.fromDoc(doc);
        final date = o.startDate;
        if (date == null) continue;
        items.add(ScheduleItem(
          id: 'opp_posted_${doc.id}',
          kind: ScheduleKind.opportunity,
          title: o.title.isEmpty ? 'Opportunity' : o.title,
          subtitle: 'Posted · ${o.status.label}',
          date: date,
          time: _hhmm(date),
          location: o.city,
          refId: doc.id,
        ));
      }
      return items;
    } catch (e, s) {
      logDebugException(
          'ScheduleService._loadPostedOpportunities', e, stackTrace: s);
      return const [];
    }
  }

  static Future<List<ScheduleItem>> _loadAcceptedOpportunities(
      String uid) async {
    try {
      final snap = await _db
          .collectionGroup('applications')
          .where('applicantUid', isEqualTo: uid)
          .get();
      final accepted = snap.docs
          .map(OpportunityApplication.fromDoc)
          .where((a) => a.status == ApplicationStatus.accepted)
          .toList();
      if (accepted.isEmpty) return const [];

      final items = <ScheduleItem>[];
      for (final a in accepted) {
        if (a.opportunityId.isEmpty) continue;
        final doc =
            await _db.collection('opportunities').doc(a.opportunityId).get();
        if (!doc.exists) continue;
        final o = Opportunity.fromDoc(doc);
        final date = o.startDate;
        if (date == null) continue;
        items.add(ScheduleItem(
          id: 'opp_accepted_${doc.id}',
          kind: ScheduleKind.opportunity,
          title: o.title.isEmpty ? 'Opportunity' : o.title,
          subtitle: 'Accepted · ${o.postedByName}',
          date: date,
          time: _hhmm(date),
          location: o.city,
          refId: doc.id,
        ));
      }
      return items;
    } catch (e, s) {
      logDebugException(
          'ScheduleService._loadAcceptedOpportunities', e, stackTrace: s);
      return const [];
    }
  }
}
