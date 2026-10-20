import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/name_utils.dart';
import '../utils/pro_profile_utils.dart';
import '../utils/role_utils.dart';

/// One directory entry = one (user, professional role) pair.
///
/// A user who is both a DJ and a Venue appears as two entries, each showing
/// that role's own profile (name, location, etc.). Entries are built from
/// per-role profiles (`proProfiles`), with the legacy single profile folded in.
class DirectoryEntry {
  final String uid;

  /// The specific professional role this entry represents.
  final String roleKey;

  final String name;
  final String? photoUrl;
  final String? bio;
  final String? city;
  final String? region;

  const DirectoryEntry({
    required this.uid,
    required this.roleKey,
    required this.name,
    this.photoUrl,
    this.bio,
    this.city,
    this.region,
  });

  bool get isOrganization => isOrganizationRole(roleKey);

  String get locationLine {
    final parts = <String>[
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
    ];
    return parts.join(', ');
  }

  /// All directory entries for one user document — one per professional
  /// (non-listener) role the user has. Each entry uses that role's saved
  /// sub-profile when present, otherwise the user's base name.
  static List<DirectoryEntry> fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final roles = parseRolesFromUserData(data)
        .where((r) => r != RoleKeys.listener)
        .toList();
    if (roles.isEmpty) return const [];

    final profiles = readProProfiles(data);
    final baseName = NameUtils.getDisplayNameSafe(
      data['firstName']?.toString(),
      data['secondName']?.toString(),
      fallback: data['displayName']?.toString() ??
          data['email']?.toString() ??
          'User',
    );
    final photo =
        data['profileImage']?.toString() ?? data['photoURL']?.toString();
    final bio = data['bio']?.toString();

    final out = <DirectoryEntry>[];
    for (final role in roles) {
      final pro = profiles[role] ?? const <String, dynamic>{};
      String? pg(String key) {
        final v = (pro[key] ?? '').toString().trim();
        return v.isEmpty ? null : v;
      }

      final orgName = (pro['orgName'] ?? '').toString().trim();
      final stageName = (pro['stageName'] ?? '').toString().trim();
      final name = orgName.isNotEmpty
          ? orgName
          : (stageName.isNotEmpty ? stageName : baseName);

      out.add(DirectoryEntry(
        uid: doc.id,
        roleKey: role,
        name: name,
        photoUrl: photo,
        bio: bio,
        city: pg('city') ?? data['city']?.toString(),
        region: pg('region') ?? data['region']?.toString(),
      ));
    }
    return out;
  }
}
