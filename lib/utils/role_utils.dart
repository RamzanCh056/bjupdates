/// Role utilities for Firestore roles array design.
///
/// Normalized role values stored in Firestore: 'listener', 'artist', 'organizer', 'venue'.
/// User document should use: roles: ['listener', 'artist'] (array).
/// Role-specific data lives in separate collections (artists, events, musicStores, etc.).
library;

/// Normalized role keys used in Firestore `roles` array.
class RoleKeys {
  static const String listener = 'listener';
  static const String artist = 'artist';
  static const String organizer = 'organizer';
  static const String venue = 'venue';
}

/// Maps UI/signup dropdown value to normalized role for storage.
String? uiRoleToNormalized(String? uiRole) {
  if (uiRole == null || uiRole.trim().isEmpty) return null;
  final r = uiRole.trim().toLowerCase();
  if (r == 'listener') return RoleKeys.listener;
  if (r == 'artist / creator' || r == 'artist') return RoleKeys.artist;
  if (r == 'organizer') return RoleKeys.organizer;
  if (r == 'venue / business' || r == 'venue') return RoleKeys.venue;
  return null;
}

/// Parses roles from Firestore user document.
/// Supports both:
/// - roles: ['listener', 'artist'] (array, preferred)
/// - role: 'Artist / Creator' (legacy single string)
List<String> parseRolesFromUserData(Map<String, dynamic>? data) {
  if (data == null) return [];

  // Prefer roles array
  final rolesRaw = data['roles'];
  if (rolesRaw is List) {
    return rolesRaw
        .map(
          (e) => (e is String)
              ? (e as String).trim().toLowerCase()
              : e.toString().trim().toLowerCase(),
        )
        .where((s) => s.isNotEmpty && _isValidNormalizedRole(s))
        .toList();
  }

  // Fallback: legacy single role field
  final roleRaw = data['role'];
  if (roleRaw is String && roleRaw.trim().isNotEmpty) {
    final normalized = _legacyRoleToNormalized(roleRaw.trim());
    if (normalized != null) return [normalized];
  }

  return [];
}

bool _isValidNormalizedRole(String s) {
  return s == RoleKeys.listener ||
      s == RoleKeys.artist ||
      s == RoleKeys.organizer ||
      s == RoleKeys.venue;
}

String? _legacyRoleToNormalized(String legacy) {
  final r = legacy.toLowerCase().trim();
  if (r == 'listener') return RoleKeys.listener;
  if (r == 'artist / creator' || r == 'artist') return RoleKeys.artist;
  if (r == 'organizer') return RoleKeys.organizer;
  if (r == 'venue / business' || r == 'venue') return RoleKeys.venue;
  return null;
}

/// Whether the parsed roles list can create/manage events (organizer or venue).
bool rolesCanManageVenueAndEvents(List<String> roles) {
  return roles.contains(RoleKeys.organizer) || roles.contains(RoleKeys.venue);
}

/// Whether the parsed roles list can upload content and manage artist profile.
bool isArtistRole(List<String> roles) {
  return roles.contains(RoleKeys.artist);
}

/// Display label for role (for UI).
String roleDisplayLabel(String role) {
  switch (role) {
    case RoleKeys.listener:
      return 'Listener';
    case RoleKeys.artist:
      return 'Artist';
    case RoleKeys.organizer:
      return 'Organizer';
    case RoleKeys.venue:
      return 'Venue';
    default:
      return role;
  }
}
