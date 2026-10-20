import 'dart:async';

import 'package:beatjerky/utils/debug_log.dart';
import 'package:beatjerky/utils/geohash_utils.dart';
import 'package:beatjerky/utils/name_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

enum NearbyGenderFilter { all, male, female, other }

class NearbyUser {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final double distanceKm;
  final DateTime? lastActive;
  /// Normalized: `male`, `female`, or `other`.
  final String? gender;

  const NearbyUser({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.bio,
    required this.distanceKm,
    this.lastActive,
    this.gender,
  });

  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!) <= const Duration(minutes: 5);
  }
}

class NearbyUsersResult {
  final List<NearbyUser> users;
  final bool locationSharingEnabled;
  final bool permissionDenied;
  final String? errorMessage;

  const NearbyUsersResult({
    this.users = const [],
    this.locationSharingEnabled = false,
    this.permissionDenied = false,
    this.errorMessage,
  });
}

/// Location sharing + geohash queries for nearby users.
class NearbyUsersService {
  NearbyUsersService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const double minUpdateDistanceM = 500;
  static const Duration minUpdateInterval = Duration(minutes: 5);

  static Position? _lastPosition;
  static DateTime? _lastWriteAt;

  static Future<LocationPermission> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static bool permissionGranted(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  /// Gender is filtered client-side after Firestore fetch — avoids composite
  /// indexes with geohash/lastActive and handles legacy docs without the field.
  static String? normalizeGender(dynamic raw) {
    if (raw == null) return null;
    final g = raw.toString().trim().toLowerCase();
    if (g.isEmpty) return null;
    if (g == 'm' || g == 'male' || g == 'man') return 'male';
    if (g == 'f' || g == 'female' || g == 'woman') return 'female';
    if (g == 'other' ||
        g == 'non-binary' ||
        g == 'nonbinary' ||
        g == 'nb' ||
        g == 'prefer not to say') {
      return 'other';
    }
    return 'other';
  }

  static bool matchesGender(String? userGender, NearbyGenderFilter filter) {
    switch (filter) {
      case NearbyGenderFilter.all:
        return true;
      case NearbyGenderFilter.male:
        return userGender == 'male';
      case NearbyGenderFilter.female:
        return userGender == 'female';
      case NearbyGenderFilter.other:
        return userGender == 'other';
    }
  }

  static NearbyUser _userFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required double distanceKm,
  }) {
    final data = doc.data() ?? {};
    final name = NameUtils.getDisplayNameSafe(
      data['firstName']?.toString(),
      data['secondName']?.toString(),
      fallback: data['displayName']?.toString() ??
          data['email']?.toString() ??
          'User',
    );

    return NearbyUser(
      uid: doc.id,
      displayName: name,
      photoURL:
          data['photoURL']?.toString() ?? data['profileImage']?.toString(),
      bio: data['bio']?.toString(),
      distanceKm: distanceKm,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      gender: normalizeGender(data['gender']),
    );
  }

  /// Updates Firestore location if moved enough or interval elapsed.
  static Future<bool> updateMyLocation({bool force = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final permission = await requestPermission();
    if (!permissionGranted(permission)) return false;

    final position = await _currentPosition();

    if (!force && _lastPosition != null && _lastWriteAt != null) {
      final moved = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsed = DateTime.now().difference(_lastWriteAt!);
      if (moved < minUpdateDistanceM && elapsed < minUpdateInterval) {
        return true;
      }
    }

    final geohash = GeohashUtils.encode(position.latitude, position.longitude);
    await _firestore.collection('usersData').doc(uid).set(
      {
        'location': {
          'geohash': geohash,
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'locationSharing': true,
        'lastActive': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    _lastPosition = position;
    _lastWriteAt = DateTime.now();
    return true;
  }

  static Future<void> disableLocationSharing() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('usersData').doc(uid).set(
      {'locationSharing': false},
      SetOptions(merge: true),
    );
  }

  static Future<NearbyUsersResult> fetchNearby({
    required double radiusKm,
    bool refreshLocation = true,
    NearbyGenderFilter gender = NearbyGenderFilter.all,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      return const NearbyUsersResult(errorMessage: 'Please sign in');
    }

    final permission = await requestPermission();
    if (!permissionGranted(permission)) {
      return const NearbyUsersResult(permissionDenied: true);
    }

    try {
      if (refreshLocation) {
        await updateMyLocation(force: true);
      }

      final position = await _currentPosition();

      final bounds = GeohashUtils.queryBounds(
        position.latitude,
        position.longitude,
        radiusKm,
      );

      final seen = <String, NearbyUser>{};

      for (final bound in bounds) {
        final snap = await _firestore
            .collection('usersData')
            .where('locationSharing', isEqualTo: true)
            .where('location.geohash', isGreaterThanOrEqualTo: bound[0])
            .where('location.geohash', isLessThanOrEqualTo: bound[1])
            .limit(40)
            .get();

        for (final doc in snap.docs) {
          if (doc.id == myUid) continue;
          final data = doc.data();
          final loc = data['location'] as Map<String, dynamic>?;
          if (loc == null) continue;
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          final dist = GeohashUtils.distanceKm(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );
          if (dist > radiusKm) continue;

          final user = _userFromDoc(doc, distanceKm: dist);
          if (!matchesGender(user.gender, gender)) continue;

          final existing = seen[doc.id];
          if (existing == null || dist < existing.distanceKm) {
            seen[doc.id] = user;
          }
        }
      }

      final list = seen.values.toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return NearbyUsersResult(
        users: list,
        locationSharingEnabled: true,
      );
    } catch (e, st) {
      logDebugException('NearbyUsersService.fetchNearby', e, stackTrace: st);
      return NearbyUsersResult(errorMessage: e.toString());
    }
  }

  /// All registered users, sorted by recent activity (no location filter).
  static Future<NearbyUsersResult> fetchAll({
    NearbyGenderFilter gender = NearbyGenderFilter.all,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      return const NearbyUsersResult(errorMessage: 'Please sign in');
    }

    try {
      // Pull the full user directory — do not require locationSharing here.
      final snap = await _firestore.collection('usersData').limit(300).get();

      final users = <NearbyUser>[];
      for (final doc in snap.docs) {
        if (doc.id == myUid) continue;
        final user = _userFromDoc(doc, distanceKm: 0);
        if (matchesGender(user.gender, gender)) {
          users.add(user);
        }
      }

      users.sort((a, b) {
        final aa = a.lastActive;
        final ba = b.lastActive;
        if (aa == null && ba == null) {
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        }
        if (aa == null) return 1;
        if (ba == null) return -1;
        return ba.compareTo(aa);
      });

      return NearbyUsersResult(users: users);
    } catch (e, st) {
      logDebugException('NearbyUsersService.fetchAll', e, stackTrace: st);
      return NearbyUsersResult(errorMessage: e.toString());
    }
  }

  static Future<Position> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }
}
