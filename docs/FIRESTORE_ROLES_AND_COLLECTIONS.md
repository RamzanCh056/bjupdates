# Firestore: Roles Array & Role-Specific Collections

## User document: use `roles` array

Store roles as an **array** in the main user document, not a single `role` string.

**Collection:** `usersData`  
**Document:** per user (by Auth UID)

**Recommended shape (keep user doc lean):**

```json
{
  "docId": "<uid>",
  "firstName": "...",
  "secondName": "...",
  "email": "...",
  "createdAt": "...",
  "following": [],
  "subscription": "unpaid",
  "roles": ["listener", "artist"]
}
```

- **Normalized role values:** `listener`, `artist`, `organizer`, `venue`
- A user can have multiple roles, e.g. `roles: ["listener", "artist"]`
- **Backward compatibility:** The app still supports a legacy single `role` field (e.g. `"Artist / Creator"`) and treats it as a one-element roles list.

## Role-specific data: separate collections

Do **not** store role-specific data inside the main user document. Use separate collections and reference the user by `userId` / `ownerId` where needed.

| Data | Collection(s) | Notes |
|------|----------------|--------|
| Artist profiles | `artists` | `userId` links to user |
| Artist songs | `artistSongs` | `artistId` links to artist |
| Events | `events` | `ownerId` links to user |
| Venue / store profiles | `musicStores`, `stores` | `userId` links to user |
| Songs (home) | `songs` | `userId` links to user |
| Posts (feed) | `posts` | `userId` links to user |
| Reels | `reels` | `userId` links to user |
| Rewards / points | `userRewards` | doc id = user uid |

This keeps:

- **usersData** small and focused on identity, subscription, and `roles`
- Role-specific features (artists, events, stores, etc.) in their own collections
- Clear ownership via `userId` / `ownerId` fields

## Code references

- **Parsing roles:** `lib/utils/role_utils.dart`  
  - `parseRolesFromUserData(data)` – reads `roles` array or legacy `role` string  
  - `uiRoleToNormalized(uiRole)` – maps signup dropdown to normalized value  
  - `RoleKeys` – constants: `listener`, `artist`, `organizer`, `venue`
- **Provider:** `lib/providers/user_provider.dart` – exposes `roles` and `isArtist`, `isOrganizer`, `isVenue`, `canManageVenueAndEvents`
- **Signup:** writes `roles: [normalizedRole]` (no longer writes single `role`)
