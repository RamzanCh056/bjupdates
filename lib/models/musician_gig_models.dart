import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart' show readMillis, MusicianRole, MusicianRoleX, PaymentStatus, PaymentStatusX;

/// Gig model for the Musician-Career feature — mirrors the admin schema
/// (`beatjerky-admin/src/lib/types.ts` → Gig). Timestamps are int-milliseconds.
/// A gig is linked to musicians via [assignedMusicianIds]; its [status] follows
/// the lifecycle draft → offered → accepted/declined → confirmed →
/// completed/cancelled.

enum GigStatus {
  draft,
  offered,
  accepted,
  declined,
  confirmed,
  completed,
  cancelled,
}

extension GigStatusX on GigStatus {
  String get value {
    switch (this) {
      case GigStatus.draft:
        return 'draft';
      case GigStatus.offered:
        return 'offered';
      case GigStatus.accepted:
        return 'accepted';
      case GigStatus.declined:
        return 'declined';
      case GigStatus.confirmed:
        return 'confirmed';
      case GigStatus.completed:
        return 'completed';
      case GigStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case GigStatus.draft:
        return 'Draft';
      case GigStatus.offered:
        return 'Offered';
      case GigStatus.accepted:
        return 'Accepted';
      case GigStatus.declined:
        return 'Declined';
      case GigStatus.confirmed:
        return 'Confirmed';
      case GigStatus.completed:
        return 'Completed';
      case GigStatus.cancelled:
        return 'Cancelled';
    }
  }

  static GigStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'offered':
        return GigStatus.offered;
      case 'accepted':
        return GigStatus.accepted;
      case 'declined':
        return GigStatus.declined;
      case 'confirmed':
        return GigStatus.confirmed;
      case 'completed':
        return GigStatus.completed;
      case 'cancelled':
        return GigStatus.cancelled;
      default:
        return GigStatus.draft;
    }
  }

  /// The musician can respond (accept/decline) only while the gig is offered.
  bool get awaitingResponse => this == GigStatus.offered;
}

class Gig {
  final String id;
  final String title;
  final String? venue;
  final String? address;
  final int? startAt;
  final int? soundcheckAt;
  final MusicianRole? role;
  final String? organizer;
  final num? paymentAmount;
  final String? currency;
  final PaymentStatus? paymentStatus;
  final GigStatus status;
  final List<String> assignedMusicianIds;
  final String? notes;
  final String createdBy;
  final int? createdAt;

  const Gig({
    required this.id,
    required this.title,
    this.venue,
    this.address,
    this.startAt,
    this.soundcheckAt,
    this.role,
    this.organizer,
    this.paymentAmount,
    this.currency,
    this.paymentStatus,
    this.status = GigStatus.draft,
    this.assignedMusicianIds = const [],
    this.notes,
    this.createdBy = '',
    this.createdAt,
  });

  factory Gig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Gig.fromMap(doc.id, doc.data() ?? const {});

  factory Gig.fromMap(String id, Map<String, dynamic> data) {
    return Gig(
      id: id,
      title: (data['title'] ?? '').toString(),
      venue: data['venue']?.toString(),
      address: data['address']?.toString(),
      startAt: readMillis(data['startAt']),
      soundcheckAt: readMillis(data['soundcheckAt']),
      role: data['role'] != null ? MusicianRoleX.fromValue(data['role']) : null,
      organizer: data['organizer']?.toString(),
      paymentAmount: data['paymentAmount'] is num ? data['paymentAmount'] as num : null,
      currency: data['currency']?.toString(),
      paymentStatus: data['paymentStatus'] != null
          ? PaymentStatusX.fromValue(data['paymentStatus'])
          : null,
      status: GigStatusX.fromValue(data['status']),
      assignedMusicianIds:
          List<String>.from(data['assignedMusicianIds'] ?? const []),
      notes: data['notes']?.toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: readMillis(data['createdAt']),
    );
  }

  DateTime? get startDate =>
      startAt == null ? null : DateTime.fromMillisecondsSinceEpoch(startAt!);
}
