import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart' show readMillis;

/// Public "Gigs & opportunities" board.
///
/// An [Opportunity] is an open post created by an organization-type account
/// (organizer, venue, agency, studio, label, supplier) looking for individual
/// professionals (artist, dj, band, technician). It lives in the top-level
/// `opportunities` collection — separate from the admin-managed `gigs` CRM.
///
/// Individuals apply through the `opportunities/{id}/applications/{uid}`
/// subcollection, one [OpportunityApplication] per applicant.

enum OpportunityStatus { open, closed, filled }

extension OpportunityStatusX on OpportunityStatus {
  String get value {
    switch (this) {
      case OpportunityStatus.open:
        return 'open';
      case OpportunityStatus.closed:
        return 'closed';
      case OpportunityStatus.filled:
        return 'filled';
    }
  }

  String get label {
    switch (this) {
      case OpportunityStatus.open:
        return 'Open';
      case OpportunityStatus.closed:
        return 'Closed';
      case OpportunityStatus.filled:
        return 'Filled';
    }
  }

  bool get isOpen => this == OpportunityStatus.open;

  static OpportunityStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'closed':
        return OpportunityStatus.closed;
      case 'filled':
        return OpportunityStatus.filled;
      default:
        return OpportunityStatus.open;
    }
  }
}

enum ApplicationStatus { pending, accepted, declined, withdrawn }

extension ApplicationStatusX on ApplicationStatus {
  String get value {
    switch (this) {
      case ApplicationStatus.pending:
        return 'pending';
      case ApplicationStatus.accepted:
        return 'accepted';
      case ApplicationStatus.declined:
        return 'declined';
      case ApplicationStatus.withdrawn:
        return 'withdrawn';
    }
  }

  String get label {
    switch (this) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.declined:
        return 'Declined';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  static ApplicationStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'declined':
        return ApplicationStatus.declined;
      case 'withdrawn':
        return ApplicationStatus.withdrawn;
      default:
        return ApplicationStatus.pending;
    }
  }
}

class Opportunity {
  final String id;
  final String title;
  final String description;

  /// Poster (organization account).
  final String postedByUid;
  final String postedByName;
  final String? postedByPhoto;

  /// The posting account's organization role (e.g. venue, agency).
  final String? orgRole;

  /// Individual roles the poster is looking for (dj, band, technician, artist).
  final List<String> rolesWanted;

  final String? city;
  final String? region;
  final String? postalCode;

  final num? budget;
  final String? currency;

  /// Optional event/start date, int-milliseconds.
  final int? startAt;

  final OpportunityStatus status;

  /// Denormalized count of applications (pending + decided).
  final int applicantCount;

  final int? createdAt;
  final int? updatedAt;

  /// Set when this is a recruitment post linked to an event.
  final String? eventId;
  final String? eventName;

  const Opportunity({
    required this.id,
    required this.title,
    this.description = '',
    this.postedByUid = '',
    this.postedByName = '',
    this.postedByPhoto,
    this.orgRole,
    this.rolesWanted = const [],
    this.city,
    this.region,
    this.postalCode,
    this.budget,
    this.currency,
    this.startAt,
    this.status = OpportunityStatus.open,
    this.applicantCount = 0,
    this.createdAt,
    this.updatedAt,
    this.eventId,
    this.eventName,
  });

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  factory Opportunity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Opportunity.fromMap(doc.id, doc.data() ?? const {});

  factory Opportunity.fromMap(String id, Map<String, dynamic> data) {
    return Opportunity(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      postedByUid: (data['postedByUid'] ?? '').toString(),
      postedByName: (data['postedByName'] ?? '').toString(),
      postedByPhoto: data['postedByPhoto']?.toString(),
      orgRole: data['orgRole']?.toString(),
      rolesWanted: _stringList(data['rolesWanted']),
      city: data['city']?.toString(),
      region: data['region']?.toString(),
      postalCode: data['postalCode']?.toString(),
      budget: data['budget'] is num ? data['budget'] as num : null,
      currency: data['currency']?.toString(),
      startAt: readMillis(data['startAt']),
      status: OpportunityStatusX.fromValue(data['status']),
      applicantCount:
          data['applicantCount'] is num ? (data['applicantCount'] as num).toInt() : 0,
      createdAt: readMillis(data['createdAt']),
      updatedAt: readMillis(data['updatedAt']),
      eventId: data['eventId']?.toString(),
      eventName: data['eventName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'postedByUid': postedByUid,
      'postedByName': postedByName,
      'postedByPhoto': postedByPhoto,
      'orgRole': orgRole,
      'rolesWanted': rolesWanted,
      'city': city,
      'region': region,
      'postalCode': postalCode,
      'budget': budget,
      'currency': currency,
      'startAt': startAt,
      'status': status.value,
      'applicantCount': applicantCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'eventId': eventId,
      'eventName': eventName,
    };
  }

  DateTime? get startDate =>
      startAt == null ? null : DateTime.fromMillisecondsSinceEpoch(startAt!);

  String get locationLine {
    final parts = <String>[
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
      if ((postalCode ?? '').trim().isNotEmpty) postalCode!.trim(),
    ];
    return parts.join(' · ');
  }
}

class OpportunityApplication {
  /// Doc id == applicant uid.
  final String id;
  final String opportunityId;
  final String applicantUid;
  final String applicantName;
  final String? applicantPhoto;
  final String? applicantRole;
  final String message;
  final ApplicationStatus status;
  final int? createdAt;

  const OpportunityApplication({
    required this.id,
    this.opportunityId = '',
    this.applicantUid = '',
    this.applicantName = '',
    this.applicantPhoto,
    this.applicantRole,
    this.message = '',
    this.status = ApplicationStatus.pending,
    this.createdAt,
  });

  factory OpportunityApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OpportunityApplication(
      id: doc.id,
      opportunityId: (data['opportunityId'] ?? '').toString(),
      applicantUid: (data['applicantUid'] ?? doc.id).toString(),
      applicantName: (data['applicantName'] ?? '').toString(),
      applicantPhoto: data['applicantPhoto']?.toString(),
      applicantRole: data['applicantRole']?.toString(),
      message: (data['message'] ?? '').toString(),
      status: ApplicationStatusX.fromValue(data['status']),
      createdAt: readMillis(data['createdAt']),
    );
  }

  DateTime? get createdDate =>
      createdAt == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAt!);
}
