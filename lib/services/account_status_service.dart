import 'package:cloud_firestore/cloud_firestore.dart';

/// Account moderation status for an app user, read from usersData/{uid}.
/// Written by the admin `setUserStatus` Cloud Function.
class AccountStatusModel {
  final String status; // active | suspended | banned
  final String? reason;
  final int? until; // suspendedUntil (ms epoch), null = indefinite

  const AccountStatusModel({required this.status, this.reason, this.until});

  factory AccountStatusModel.fromData(Map<String, dynamic>? data) {
    final d = data ?? const {};
    return AccountStatusModel(
      status: (d['accountStatus'] ?? 'active').toString(),
      reason: d['statusReason']?.toString(),
      until: _readInt(d['suspendedUntil']),
    );
  }

  static int? _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return null;
  }

  bool get isBanned => status == 'banned';
  bool get isSuspended => status == 'suspended';

  /// Whether the user is currently blocked from using the app.
  /// A suspension with a past end date is treated as expired (not blocked).
  bool get isBlocked {
    if (isBanned) return true;
    if (isSuspended) {
      if (until == null) return true;
      return until! > DateTime.now().millisecondsSinceEpoch;
    }
    return false;
  }

  String get title => isBanned ? 'Account banned' : 'Account suspended';

  String get message {
    if (reason != null && reason!.trim().isNotEmpty) return reason!.trim();
    return isBanned
        ? 'Your account has been banned for violating our community policies.'
        : 'Your account has been suspended for violating our community policies.';
  }
}

class AccountStatusService {
  AccountStatusService._();

  /// One-shot read of a user's moderation status. Fails open (active) on error
  /// so a transient read failure never locks a legitimate user out.
  static Future<AccountStatusModel> fetch(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      return AccountStatusModel.fromData(doc.data());
    } catch (_) {
      return const AccountStatusModel(status: 'active');
    }
  }
}
