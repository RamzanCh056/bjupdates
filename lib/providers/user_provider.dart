import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/role_utils.dart';

class UserStatusProvider extends ChangeNotifier {
  bool loading = true;

  // Subscription / plan info
  bool isPaid = false;
  String paidPlan = 'none';

  // Reward points
  int totalPoints = 0;

  /// Parsed roles from Firestore: prefers roles array, falls back to legacy role string.
  /// Normalized values: 'listener', 'artist', 'organizer', 'venue'.
  List<String> roles = [];

  /// When user has multiple roles, they can switch. This is the active role for UI/permissions.
  /// When null, all roles apply (default). When set, only this role's permissions apply.
  String? activeRole;

  /// Effective roles for permission checks: [activeRole] if set and valid, else full [roles].
  List<String> get effectiveRoles {
    if (activeRole != null &&
        activeRole!.trim().isNotEmpty &&
        roles.contains(activeRole!.trim().toLowerCase())) {
      return [activeRole!.trim().toLowerCase()];
    }
    return roles;
  }

  /// Whether user has more than one role (can switch).
  bool get hasMultipleRoles => roles.length > 1;

  /// Set active role (use RoleKeys). Pass null to use all roles.
  void setActiveRole(String? role) {
    if (role == activeRole) return;
    activeRole = role?.trim().toLowerCase();
    if (activeRole != null && !roles.contains(activeRole)) activeRole = null;
    notifyListeners();
  }

  /// Persist role switch to Firestore and apply immediately.
  /// This keeps signup single-role behavior while allowing dashboard switching.
  Future<bool> switchRoleAndPersist(String role) async {
    final normalized = role.trim().toLowerCase();
    const allowed = {
      RoleKeys.listener,
      RoleKeys.artist,
      RoleKeys.organizer,
      RoleKeys.venue,
    };
    if (!allowed.contains(normalized)) return false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      await FirebaseFirestore.instance.collection('usersData').doc(uid).set({
        'roles': [normalized],
      }, SetOptions(merge: true));

      // Update local state immediately; listener will also sync shortly after.
      roles = [normalized];
      activeRole = normalized;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Failed to switch role: $e');
      return false;
    }
  }

  /// All signed-in users can upload audio/video and manage artist profiles.
  bool get isArtist => FirebaseAuth.instance.currentUser != null;

  /// All signed-in users can create/manage events and venues.
  bool get isOrganizer => FirebaseAuth.instance.currentUser != null;

  /// All signed-in users can create/manage venue profiles.
  bool get isVenue => FirebaseAuth.instance.currentUser != null;

  /// All signed-in users can create/manage venue profiles and events.
  bool get canManageVenueAndEvents =>
      FirebaseAuth.instance.currentUser != null;

  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<DocumentSnapshot>? _rewardsSub;
  StreamSubscription<User?>? _authSub;

  UserStatusProvider() {
    print('📱 UserStatusProvider: Initializing...');
    // listen auth state
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    print('✅ UserStatusProvider: Auth state listener set up');
  }

  void _onAuthChanged(User? user) {
    print(
      '👤 Auth state changed: ${user != null ? "User logged in (${user.uid})" : "No user"}',
    );
    _cancelListeners();

    if (user == null) {
      print('ℹ️ No user detected - resetting all values to default');
      // no user → reset
      isPaid = false;
      paidPlan = 'none';
      totalPoints = 0;
      roles = [];
      activeRole = null;
      loading = false;
      notifyListeners();
      print(
        '✅ User status reset: isPaid=$isPaid, paidPlan=$paidPlan, totalPoints=$totalPoints, loading=$loading',
      );
      return;
    }

    print('👤 User authenticated: UID=${user.uid}, Email=${user.email}');
    _listenToUserData(user.uid);
    _listenToUserRewards(user.uid);
  }

  void _listenToUserData(String uid) {
    print('📡 Setting up userData listener for UID: $uid');
    loading = true;
    notifyListeners();
    print('⏳ Loading state set to true');

    _userSub = FirebaseFirestore.instance
        .collection('usersData')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            print(
              '📄 userData snapshot received: ${doc.exists ? "Document exists" : "Document does not exist"}',
            );

            if (doc.exists) {
              final data = doc.data() as Map<String, dynamic>;
              print('📊 userData content: $data');

              isPaid = data['isPaid'] == true;
              paidPlan = (data['paidPlan'] as String?) ?? 'none';
              roles = parseRolesFromUserData(data);
              if (activeRole != null && !roles.contains(activeRole)) {
                activeRole = null;
              }

              print(
                '💰 Subscription data - isPaid: $isPaid, paidPlan: $paidPlan, roles: $roles',
              );
            } else {
              print('⚠️ userData document does not exist for UID: $uid');
              isPaid = false;
              paidPlan = 'none';
              roles = [];
              print(
                '💰 Subscription data reset to defaults - isPaid: $isPaid, paidPlan: $paidPlan, roles: $roles',
              );
            }

            loading = false;
            print('⏳ Loading state set to false');
            notifyListeners();
            print('🔄 Notified listeners about userData update');
          },
          onError: (e) {
            print('❌ Error in userData listener: $e');
            loading = false;
            notifyListeners();
            print('🔄 Notified listeners about error state');
          },
        );

    print('✅ userData listener setup complete');
  }

  void _listenToUserRewards(String uid) {
    print('📡 Setting up userRewards listener for UID: $uid');

    _rewardsSub = FirebaseFirestore.instance
        .collection('userRewards')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            print(
              '📄 userRewards snapshot received: ${doc.exists ? "Document exists" : "Document does not exist"}',
            );

            if (doc.exists) {
              final data = doc.data() as Map<String, dynamic>;
              print('📊 userRewards content: $data');

              totalPoints = (data['totalPoints'] ?? 0) as int;
              print('🎯 Total points updated: $totalPoints');
            } else {
              print('⚠️ userRewards document does not exist for UID: $uid');
              totalPoints = 0;
              print('🎯 Total points reset to: $totalPoints');
            }

            notifyListeners();
            print('🔄 Notified listeners about userRewards update');
          },
          onError: (e) {
            print('❌ Error in userRewards listener: $e');
            // keep old value, maybe log
            print('⚠️ Keeping previous totalPoints value: $totalPoints');
          },
        );

    print('✅ userRewards listener setup complete');
  }

  void _cancelListeners() {
    print('🛑 Cancelling active listeners...');

    if (_userSub != null) {
      _userSub?.cancel();
      print('✅ userData listener cancelled');
    } else {
      print('ℹ️ No active userData listener to cancel');
    }

    if (_rewardsSub != null) {
      _rewardsSub?.cancel();
      print('✅ userRewards listener cancelled');
    } else {
      print('ℹ️ No active userRewards listener to cancel');
    }

    _userSub = null;
    _rewardsSub = null;
    print('✅ Listeners cleared');
  }

  @override
  void dispose() {
    print('🗑️ Disposing UserStatusProvider...');
    _cancelListeners();

    if (_authSub != null) {
      _authSub?.cancel();
      print('✅ Auth state listener cancelled');
    }

    super.dispose();
    print('✅ UserStatusProvider disposed');
  }

  // Helper method to get current state as string (useful for debugging)
  String get currentState {
    return '''
📊 Current UserStatusProvider State:
   - Loading: $loading
   - isPaid: $isPaid
   - paidPlan: $paidPlan
   - totalPoints: $totalPoints
   - Active listeners: ${_userSub != null || _rewardsSub != null}
    ''';
  }
}
