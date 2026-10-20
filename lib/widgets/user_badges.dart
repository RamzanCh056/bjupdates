import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_badges.dart';

/// Shows the verified (blue seal) and/or premium (gold seal) badges for any
/// user, looked up by uid and cached per app session so lists don't refetch.
///
/// Drop `UserBadges(uid: authorUid)` next to a name anywhere a user is shown.
class UserBadges extends StatefulWidget {
  final String uid;
  final double size;
  final double gap;

  const UserBadges({
    super.key,
    required this.uid,
    this.size = 14,
    this.gap = 3,
  });

  @override
  State<UserBadges> createState() => _UserBadgesState();
}

class _UserBadgesState extends State<UserBadges> {
  @override
  Widget build(BuildContext context) {
    final cached = _BadgeCache.cached(widget.uid);
    if (cached != null) {
      return BadgeStrip(
        verified: cached.verified,
        premium: cached.premium,
        size: widget.size,
        gap: widget.gap,
      );
    }
    return FutureBuilder<_Flags>(
      future: _BadgeCache.get(widget.uid),
      builder: (context, snap) {
        final f = snap.data;
        if (f == null) return const SizedBox.shrink();
        return BadgeStrip(
          verified: f.verified,
          premium: f.premium,
          size: widget.size,
          gap: widget.gap,
        );
      },
    );
  }
}

class _Flags {
  final bool verified;
  final bool premium;
  const _Flags(this.verified, this.premium);
}

/// Session cache + in-flight de-duplication for user badge flags.
class _BadgeCache {
  _BadgeCache._();

  static final Map<String, _Flags> _cache = {};
  static final Map<String, Future<_Flags>> _inflight = {};

  static _Flags? cached(String uid) => _cache[uid];

  static Future<_Flags> get(String uid) {
    if (uid.isEmpty) return Future.value(const _Flags(false, false));
    final hit = _cache[uid];
    if (hit != null) return Future.value(hit);
    final pending = _inflight[uid];
    if (pending != null) return pending;

    final future = _fetch(uid);
    _inflight[uid] = future;
    return future;
  }

  static Future<_Flags> _fetch(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final flags = _Flags(
        data['verified'] == true,
        data['isPaid'] == true,
      );
      _cache[uid] = flags;
      return flags;
    } catch (_) {
      final flags = const _Flags(false, false);
      _cache[uid] = flags;
      return flags;
    } finally {
      _inflight.remove(uid);
    }
  }
}
