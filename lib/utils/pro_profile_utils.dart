import 'role_utils.dart';

/// Helpers for per-role professional profiles.
///
/// New layout: `usersData/{uid}.proProfiles = { <roleKey>: { ...fields } }`.
/// A single legacy `usersData/{uid}.proProfile` map is still honoured — it is
/// treated as the profile for its own `role`, so nothing breaks before data is
/// migrated.

/// All saved professional profiles keyed by role (legacy folded in).
Map<String, Map<String, dynamic>> readProProfiles(Map<String, dynamic>? data) {
  final out = <String, Map<String, dynamic>>{};
  if (data == null) return out;

  final raw = data['proProfiles'];
  if (raw is Map) {
    raw.forEach((k, v) {
      if (v is Map && v.isNotEmpty) {
        out[k.toString()] = v.cast<String, dynamic>();
      }
    });
  }

  // Legacy single profile fallback.
  final legacy = data['proProfile'];
  if (legacy is Map && legacy.isNotEmpty) {
    final m = legacy.cast<String, dynamic>();
    final role = (m['role'] ?? '').toString().trim();
    if (role.isNotEmpty && !out.containsKey(role)) {
      out[role] = m;
    }
  }

  return out;
}

/// The sub-profile saved for [role], or null.
Map<String, dynamic>? proProfileForRole(
  Map<String, dynamic>? data,
  String role,
) {
  if (role.isEmpty) return null;
  return readProProfiles(data)[role];
}

/// Roles that currently have a saved professional profile.
List<String> rolesWithProProfile(Map<String, dynamic>? data) =>
    readProProfiles(data).keys.toList();

/// Choose a role to display: [preferred] if it has a profile, else the first
/// non-listener role with a profile, else the first available, else null.
String? pickProfileRole(Map<String, dynamic>? data, {String? preferred}) {
  final all = readProProfiles(data);
  if (all.isEmpty) return null;
  if (preferred != null &&
      preferred.isNotEmpty &&
      all.containsKey(preferred)) {
    return preferred;
  }
  for (final k in all.keys) {
    if (k != RoleKeys.listener) return k;
  }
  return all.keys.first;
}
