import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-approved identity verification ("Verified" blue-seal badge).
/// Stored at `verificationRequests/{uid}` — one request per user.
enum VerifStatus { none, pending, approved, rejected }

extension VerifStatusX on VerifStatus {
  String get value {
    switch (this) {
      case VerifStatus.none:
        return 'none';
      case VerifStatus.pending:
        return 'pending';
      case VerifStatus.approved:
        return 'approved';
      case VerifStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case VerifStatus.none:
        return 'Not verified';
      case VerifStatus.pending:
        return 'Under review';
      case VerifStatus.approved:
        return 'Verified';
      case VerifStatus.rejected:
        return 'Rejected';
    }
  }

  static VerifStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'pending':
        return VerifStatus.pending;
      case 'approved':
        return VerifStatus.approved;
      case 'rejected':
        return VerifStatus.rejected;
      default:
        return VerifStatus.none;
    }
  }
}

class VerificationRequest {
  final String uid;
  final String name;
  final List<String> roles;

  /// individual | organization
  final String type;
  final List<String> proofUrls;
  final String note;
  final VerifStatus status;
  final String? rejectReason;
  final int? createdAt;
  final int? reviewedAt;
  final String? reviewedBy;

  const VerificationRequest({
    required this.uid,
    this.name = '',
    this.roles = const [],
    this.type = 'individual',
    this.proofUrls = const [],
    this.note = '',
    this.status = VerifStatus.none,
    this.rejectReason,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory VerificationRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    return VerificationRequest(
      uid: doc.id,
      name: (d['name'] ?? '').toString(),
      roles: (d['roles'] is List)
          ? (d['roles'] as List).map((e) => e.toString()).toList()
          : const [],
      type: (d['type'] ?? 'individual').toString(),
      proofUrls: (d['proofUrls'] is List)
          ? (d['proofUrls'] as List).map((e) => e.toString()).toList()
          : const [],
      note: (d['note'] ?? '').toString(),
      status: VerifStatusX.fromValue(d['status']),
      rejectReason: d['rejectReason']?.toString(),
      createdAt: d['createdAt'] is num ? (d['createdAt'] as num).toInt() : null,
      reviewedAt: d['reviewedAt'] is num ? (d['reviewedAt'] as num).toInt() : null,
      reviewedBy: d['reviewedBy']?.toString(),
    );
  }
}
