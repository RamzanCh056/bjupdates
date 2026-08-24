import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _cardWidth = 160.0;

class DiscoverPeopleSection extends StatefulWidget {
  const DiscoverPeopleSection({super.key});

  @override
  State<DiscoverPeopleSection> createState() => _DiscoverPeopleSectionState();
}

class _DiscoverPeopleSectionState extends State<DiscoverPeopleSection> {
  bool _dismissed = false;
  bool _loading = true;
  final Map<String, Map<String, dynamic>> _peopleById = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('usersData')
          .limit(40)
          .get();

      if (!mounted) return;

      final people = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        if (doc.id == currentUser.uid) continue;
        people[doc.id] = doc.data();
        if (people.length >= 12) break;
      }

      setState(() {
        _peopleById
          ..clear()
          ..addAll(people);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _dismissPerson(String userId) {
    setState(() => _peopleById.remove(userId));
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    if (_loading) return const SizedBox(height: 8);
    if (_peopleById.isEmpty) return const SizedBox.shrink();

    final myRef =
        FirebaseFirestore.instance.collection('usersData').doc(currentUser.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: myRef.snapshots(),
      builder: (context, meSnap) {
        final meData = meSnap.data?.data() as Map<String, dynamic>? ?? {};
        final following = List<String>.from(meData['following'] ?? []);
        final followers = List<String>.from(meData['followers'] ?? []);
        final userIds = _peopleById.keys.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'People you may know',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _dismissed = true),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 210,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    for (var index = 0; index < userIds.length; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      _DiscoverPersonCard(
                        key: ValueKey(userIds[index]),
                        userId: userIds[index],
                        myUid: currentUser.uid,
                        data: _peopleById[userIds[index]]!,
                        myFollowers: followers,
                        isFollowing: following.contains(userIds[index]),
                        onDismiss: () => _dismissPerson(userIds[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiscoverPersonCard extends StatefulWidget {
  final String userId;
  final String myUid;
  final Map<String, dynamic> data;
  final List<String> myFollowers;
  final bool isFollowing;
  final VoidCallback onDismiss;

  const _DiscoverPersonCard({
    super.key,
    required this.userId,
    required this.myUid,
    required this.data,
    required this.myFollowers,
    required this.isFollowing,
    required this.onDismiss,
  });

  @override
  State<_DiscoverPersonCard> createState() => _DiscoverPersonCardState();
}

class _DiscoverPersonCardState extends State<_DiscoverPersonCard> {
  late bool _isFollowing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(covariant _DiscoverPersonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
  }

  int get _mutualCount {
    final theirFollowers = List<String>.from(widget.data['followers'] ?? []);
    return theirFollowers.where((id) => widget.myFollowers.contains(id)).length;
  }

  String get _displayName {
    final name =
        '${widget.data['firstName'] ?? ''} ${widget.data['secondName'] ?? ''}'
            .trim();
    if (name.isNotEmpty) return name;
    return (widget.data['email'] as String? ?? 'User').split('@').first;
  }

  String get _imageUrl =>
      (widget.data['profileImage'] ??
              widget.data['imageUrl'] ??
              widget.data['profileImg'] ??
              '') as String;

  Future<void> _toggleFollow() async {
    if (_busy) return;

    final nextFollowing = !_isFollowing;
    setState(() {
      _busy = true;
      _isFollowing = nextFollowing;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final myRef =
          FirebaseFirestore.instance.collection('usersData').doc(widget.myUid);
      final theirRef = FirebaseFirestore.instance
          .collection('usersData')
          .doc(widget.userId);

      batch.update(myRef, {
        'following': nextFollowing
            ? FieldValue.arrayUnion([widget.userId])
            : FieldValue.arrayRemove([widget.userId]),
      });
      batch.update(theirRef, {
        'followers': nextFollowing
            ? FieldValue.arrayUnion([widget.myUid])
            : FieldValue.arrayRemove([widget.myUid]),
      });
      await batch.commit();
    } catch (_) {
      if (mounted) {
        setState(() => _isFollowing = !nextFollowing);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _mutualCount > 0
        ? '$_mutualCount mutual'
        : 'Suggested for you';

    final label = _isFollowing
        ? 'Following'
        : (widget.myFollowers.contains(widget.userId) ? 'Follow back' : 'Follow');

    return SizedBox(
      height: 186,
      width: _cardWidth,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => openUserProfile(context, widget.userId),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFBB86FC),
                backgroundImage:
                    _imageUrl.isNotEmpty ? NetworkImage(_imageUrl) : null,
                child: _imageUrl.isEmpty
                    ? Text(
                        _displayName.isNotEmpty
                            ? _displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _busy ? null : _toggleFollow,
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isFollowing ? null : appGradient,
                      color: _isFollowing
                          ? Colors.white.withValues(alpha: 0.08)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: _isFollowing
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            )
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: _busy ? 0.7 : 1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
