// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class PeopleScreen extends StatelessWidget {
//   PeopleScreen({Key? key}) : super(key: key);
//
//   final _auth = FirebaseAuth.instance;
//   final _firestore = FirebaseFirestore.instance;
//
//   @override
//   Widget build(BuildContext context) {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) {
//       return const Scaffold(
//         body: Center(child: Text('You must be signed in')),
//       );
//     }
//
//     final myDocRef = _firestore.collection('usersData').doc(currentUser.uid);
//
//     return DefaultTabController(
//       length: 3,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('People'),
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//           elevation: 0,
//         ),
//         body: StreamBuilder<DocumentSnapshot>(
//           stream: myDocRef.snapshots(),
//           builder: (ctx, meSnap) {
//             if (meSnap.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//
//             final meData = meSnap.data?.data() as Map<String, dynamic>? ?? {};
//             final followers = List<String>.from(meData['followers'] ?? []);
//             final following = List<String>.from(meData['following'] ?? []);
//
//             return Column(
//               children: [
//                 // --- Counts Row ---
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _buildCountColumn(followers.length, 'Followers'),
//                       _buildCountColumn(following.length, 'Following'),
//                     ],
//                   ),
//                 ),
//
//                 // --- Tab Bar ---
//                 TabBar(
//                   labelColor: Colors.purple,
//                   unselectedLabelColor: Colors.grey,
//                   indicatorColor: Colors.purple,
//                   tabs: [
//                     const Tab(text: 'All'),
//                     Tab(text: 'Followers (${followers.length})'),
//                     Tab(text: 'Following (${following.length})'),
//                   ],
//                 ),
//
//                 // --- Tab Views ---
//                 Expanded(
//                   child: TabBarView(
//                     children: [
//                       _buildAllUsersTab(currentUser.uid, following),
//                       ConnectionsList(uids: followers),
//                       ConnectionsList(uids: following),
//                     ],
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCountColumn(int count, String label) {
//     return Column(
//       children: [
//         Text(
//           '$count',
//           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         Text(label),
//       ],
//     );
//   }
//
//   Widget _buildAllUsersTab(String myUid, List<String> following) {
//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore.collection('usersData').snapshots(),
//       builder: (ctx2, allSnap) {
//         if (allSnap.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         final docs = allSnap.data?.docs ?? [];
//         final others = docs.where((d) => d.id != myUid).toList();
//         if (others.isEmpty) {
//           return const Center(child: Text('No other users found'));
//         }
//
//         return ListView.builder(
//           itemCount: others.length,
//           itemBuilder: (context, i) {
//             final doc = others[i];
//             final data = doc.data()! as Map<String, dynamic>;
//             final name = '${data['firstName'] ?? ''} ${data['secondName'] ?? ''}'.trim();
//             final email = data['email'] ?? '';
//             final followersList = List<String>.from(data['followers'] ?? []);
//             final isFollowing = following.contains(doc.id);
//
//             return ListTile(
//               title: Text(name.isEmpty ? email : name),
//               subtitle: Text(
//                 '$email • ${followersList.length} follower${followersList.length == 1 ? '' : 's'}',
//               ),
//               trailing: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: isFollowing ? Colors.grey : Colors.purple,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                 ),
//                 child: Text(isFollowing ? 'Following' : 'Follow'),
//                 onPressed: () async {
//                   final batch = _firestore.batch();
//
//                   // toggle following for me
//                   batch.update(
//                     _firestore.collection('usersData').doc(myUid),
//                     {
//                       'following': isFollowing ? FieldValue.arrayRemove([doc.id]) : FieldValue.arrayUnion([doc.id]),
//                     },
//                   );
//                   // toggle followers for them
//                   batch.update(
//                     doc.reference,
//                     {
//                       'followers': isFollowing ? FieldValue.arrayRemove([myUid]) : FieldValue.arrayUnion([myUid]),
//                     },
//                   );
//
//                   await batch.commit();
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// /// Shows a simple list of user profiles for a given list of UIDs.
// class ConnectionsList extends StatelessWidget {
//   final List<String> uids;
//   const ConnectionsList({Key? key, required this.uids}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     if (uids.isEmpty) {
//       return const Center(child: Text('No connections to show'));
//     }
//
//     // Firestore only allows up to 10 in whereIn
//     final queryUids = uids.length > 10 ? uids.sublist(0, 10) : uids;
//
//     return FutureBuilder<QuerySnapshot>(
//       future: FirebaseFirestore.instance.collection('usersData').where(FieldPath.documentId, whereIn: queryUids).get(),
//       builder: (ctx, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         final docs = snap.data?.docs ?? [];
//         if (docs.isEmpty) {
//           return const Center(child: Text('No users found'));
//         }
//         return ListView.builder(
//           itemCount: docs.length,
//           itemBuilder: (context, i) {
//             final data = docs[i].data()! as Map<String, dynamic>;
//             final name = '${data['firstName'] ?? ''} ${data['secondName'] ?? ''}'.trim();
//             final email = data['email'] ?? '';
//             return ListTile(
//               leading: const CircleAvatar(child: Icon(Icons.person)),
//               title: Text(name.isEmpty ? email : name),
//               subtitle: Text(email),
//             );
//           },
//         );
//       },
//     );
//   }
// }

// people_chat_screens.dart
// people_chat_screens.dart
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:beatjerky/screens/messages_screen.dart';
import 'package:beatjerky/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Main screen showing all users, followers, and following lists
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text(
            'You must be signed in',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final myDocRef = FirebaseFirestore.instance.collection('usersData').doc(currentUser.uid);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: darkBackgroundPrimary,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          backgroundColor: darkAppBarBackground,
          elevation: 0,
          title: const Text(
            'People',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                color: darkAppBarBackground,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: const TabBar(
                indicatorColor: Color(0xFFBB86FC),
                indicatorWeight: 3,
                labelColor: Color(0xFFBB86FC),
                unselectedLabelColor: Colors.white54,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: myDocRef.snapshots(),
          builder: (context, meSnap) {
            if (meSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
              );
            }
            final meData = meSnap.data?.data() as Map<String, dynamic>? ?? {};
            final followers = List<String>.from(meData['followers'] ?? []);
            final following = List<String>.from(meData['following'] ?? []);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCountColumn(followers.length, 'Followers'),
                      _buildCountColumn(following.length, 'Following'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _UsersListTab(myUid: currentUser.uid, following: following),
                      ConnectionsList(uids: followers),
                      ConnectionsList(uids: following),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCountColumn(int count, String label) {
    const accent = Color(0xFFBB86FC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.15),
            const Color(0xFF2A2A2A).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withOpacity(0.3),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFFBB86FC),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab showing all users except current user, with follow/chat actions
class _UsersListTab extends StatelessWidget {
  final String myUid;
  final List<String> following;
  const _UsersListTab({Key? key, required this.myUid, required this.following}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usersData').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
          );
        }
        final docs = snapshot.data?.docs.where((d) => d.id != myUid).toList() ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No other users found', style: TextStyle(color: Colors.white70)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data()! as Map<String, dynamic>;
            final name = '${data['firstName'] ?? ''} ${data['secondName'] ?? ''}'.trim();
            final email = data['email'] ?? '';
            final followersList = List<String>.from(data['followers'] ?? []);
            final isFollowing = following.contains(doc.id);

            final imageUrl = (data['imageUrl'] ?? data['profileImage'] ?? data['profileImg'] ?? '') as String;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1F1F1F),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
          color: Color(0xFFBB86FC),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Avatar (tap to open profile)
                    GestureDetector(
                      onTap: () => openUserProfile(context, doc.id),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFBB86FC).withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBB86FC).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFBB86FC),
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl.isEmpty
                              ? Text(
                                  (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? email : name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$email • ${followersList.length} follower${followersList.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Follow/Following Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: isFollowing
                                ? null
                                : appGradient,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isFollowing
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: isFollowing
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFFBB86FC).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final batch = FirebaseFirestore.instance.batch();
                                batch.update(
                                  FirebaseFirestore.instance.collection('usersData').doc(myUid),
                                  {
                                    'following': isFollowing
                                        ? FieldValue.arrayRemove([doc.id])
                                        : FieldValue.arrayUnion([doc.id]),
                                  },
                                );
                                batch.update(
                                  doc.reference,
                                  {
                                    'followers': isFollowing
                                        ? FieldValue.arrayRemove([myUid])
                                        : FieldValue.arrayUnion([myUid]),
                                  },
                                );
                                await batch.commit();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: isFollowing
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Chat Button (only if not following)
                        if (!isFollowing) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final photo = imageUrl.isNotEmpty ? imageUrl : null;
                              final displayName = name.isEmpty ? email : name;
                              try {
                                final chatId = await ChatService.openOrCreateChat(
                                  peerUid: doc.id,
                                  peerName: displayName,
                                  peerPhoto: photo,
                                );
                                if (!context.mounted) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      peerUid: doc.id,
                                      peerName: displayName,
                                      peerImage: photo,
                                      chatId: chatId,
                                    ),
                                  ),
                                );
                              } catch (_) {}
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBB86FC).withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFBB86FC).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.comment_rounded,
                                color: Color(0xFFBB86FC),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Widget displaying a list of given UIDs (followers/following)
class ConnectionsList extends StatelessWidget {
  final List<String> uids;
  const ConnectionsList({Key? key, required this.uids}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return const Center(child: Text('No connections to show', style: TextStyle(color: Colors.white70)));
    }

    final queryUids = uids.length > 10 ? uids.sublist(0, 10) : uids;
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('usersData').where(FieldPath.documentId, whereIn: queryUids).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No users found', style: TextStyle(color: Colors.white70)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemBuilder: (context, index) {
            final docRef = docs[index];
            final docId = docRef.id;
            final data = docRef.data()! as Map<String, dynamic>;
            final name = '${data['firstName'] ?? ''} ${data['secondName'] ?? ''}'.trim();
            final email = data['email'] ?? '';
            final imageUrl = (data['imageUrl'] ?? data['profileImage'] ?? data['profileImg'] ?? '') as String;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1F1F1F),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
          color: Color(0xFFBB86FC),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                leading: GestureDetector(
                  onTap: () => openUserProfile(context, docId),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFBB86FC).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB86FC).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFBB86FC),
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 24)
                          : null,
                    ),
                  ),
                ),
                title: Text(
                  name.isEmpty ? email : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
