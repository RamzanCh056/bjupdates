/// Utility functions for handling user names consistently across the app
class NameUtils {
  /// Gets a display name without duplicates
  /// If firstName and lastName are the same, returns only firstName
  /// Otherwise returns "firstName lastName"
  static String getDisplayName(String firstName, String lastName) {
    if (firstName.trim().toLowerCase() == lastName.trim().toLowerCase()) {
      return firstName.trim();
    }
    return "${firstName.trim()} ${lastName.trim()}";
  }

  /// Gets a display name with fallback for null/empty values
  static String getDisplayNameSafe(String? firstName, String? lastName, {String fallback = 'User'}) {
    if (firstName == null || firstName.isEmpty) {
      if (lastName == null || lastName.isEmpty) {
        return fallback;
      }
      return lastName.trim();
    }
    
    if (lastName == null || lastName.isEmpty) {
      return firstName.trim();
    }
    
    return getDisplayName(firstName, lastName);
  }
}
