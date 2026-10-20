/// Role utilities for the Firestore `roles` array design.
///
/// Normalized role values stored in Firestore `roles: ['dj']` (array).
/// Role-specific data lives in separate collections (artists, events, stores…).
library;

/// Normalized role keys used in the Firestore `roles` array.
class RoleKeys {
  // Individuals / acts
  static const String listener = 'listener';
  static const String artist = 'artist';
  static const String dj = 'dj';
  static const String band = 'band';
  static const String technician = 'technician';

  // Organizations / businesses
  static const String organizer = 'organizer';
  static const String venue = 'venue';
  static const String agency = 'agency';
  static const String studio = 'studio';
  static const String label = 'label';
  static const String supplier = 'supplier';
}

/// Individual (person / act) roles, in display order.
const List<String> individualRoles = [
  RoleKeys.listener,
  RoleKeys.artist,
  RoleKeys.dj,
  RoleKeys.band,
  RoleKeys.technician,
];

/// Organization (business) roles, in display order.
const List<String> organizationRoles = [
  RoleKeys.organizer,
  RoleKeys.venue,
  RoleKeys.agency,
  RoleKeys.studio,
  RoleKeys.label,
  RoleKeys.supplier,
];

/// Every selectable role, in display order.
const List<String> allRoles = [
  ...individualRoles,
  ...organizationRoles,
];

/// True if [role] is an organization/business role.
bool isOrganizationRole(String role) => organizationRoles.contains(role);

/// True if any of the parsed [roles] is an organization role.
bool rolesHaveOrganization(List<String> roles) =>
    roles.any(organizationRoles.contains);

/// Maps a UI/signup value (key or common label) to a normalized role.
String? uiRoleToNormalized(String? uiRole) {
  if (uiRole == null || uiRole.trim().isEmpty) return null;
  final r = uiRole.trim().toLowerCase();
  if (allRoles.contains(r)) return r;
  switch (r) {
    case 'artist / creator':
      return RoleKeys.artist;
    case 'venue / business':
      return RoleKeys.venue;
    case 'record label':
      return RoleKeys.label;
    default:
      return null;
  }
}

/// Parses roles from a Firestore user document.
/// Supports `roles: ['dj']` (array, preferred) and legacy `role: 'Artist'`.
List<String> parseRolesFromUserData(Map<String, dynamic>? data) {
  if (data == null) return [];

  final rolesRaw = data['roles'];
  if (rolesRaw is List) {
    return rolesRaw
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty && _isValidNormalizedRole(s))
        .toList();
  }

  final roleRaw = data['role'];
  if (roleRaw is String && roleRaw.trim().isNotEmpty) {
    final normalized = uiRoleToNormalized(roleRaw.trim());
    if (normalized != null) return [normalized];
  }

  return [];
}

bool _isValidNormalizedRole(String s) => allRoles.contains(s);

/// Whether the parsed roles list can create/manage events (organizer or venue).
bool rolesCanManageVenueAndEvents(List<String> roles) {
  return roles.contains(RoleKeys.organizer) || roles.contains(RoleKeys.venue);
}

/// Whether the parsed roles list can upload content and manage an artist profile.
bool isArtistRole(List<String> roles) {
  return roles.contains(RoleKeys.artist);
}

/// Display label for a role (for UI).
String roleDisplayLabel(String role) {
  switch (role) {
    case RoleKeys.listener:
      return 'Listener';
    case RoleKeys.artist:
      return 'Artist';
    case RoleKeys.dj:
      return 'DJ';
    case RoleKeys.band:
      return 'Band';
    case RoleKeys.technician:
      return 'Technician';
    case RoleKeys.organizer:
      return 'Organizer';
    case RoleKeys.venue:
      return 'Venue';
    case RoleKeys.agency:
      return 'Agency';
    case RoleKeys.studio:
      return 'Studio';
    case RoleKeys.label:
      return 'Label';
    case RoleKeys.supplier:
      return 'Supplier';
    default:
      return role;
  }
}
