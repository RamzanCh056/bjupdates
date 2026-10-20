/// A single dated item on the user's personal calendar, aggregated from
/// events they own, gigs assigned to them, and opportunities they posted or
/// were accepted to.
enum ScheduleKind { event, gig, opportunity }

extension ScheduleKindX on ScheduleKind {
  String get label {
    switch (this) {
      case ScheduleKind.event:
        return 'Event';
      case ScheduleKind.gig:
        return 'Gig';
      case ScheduleKind.opportunity:
        return 'Opportunity';
    }
  }
}

class ScheduleItem {
  final String id;
  final ScheduleKind kind;
  final String title;
  final String? subtitle;
  final DateTime date;
  final String? time;
  final String? location;

  /// Firestore doc id of the underlying event/gig/opportunity.
  final String refId;

  const ScheduleItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.subtitle,
    this.time,
    this.location,
    this.refId = '',
  });

  /// The date with the time-of-day stripped (midnight) — used for grouping
  /// and calendar-day matching.
  DateTime get day => DateTime(date.year, date.month, date.day);
}
