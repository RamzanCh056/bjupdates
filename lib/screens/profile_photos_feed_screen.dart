import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/feeds_provider/feeds_provider.dart';
import '../utils/color.dart';
import '../utils/name_utils.dart';
import 'New Feed/new_feed.dart';

/// Full-screen feed of a profile's photo posts, using the same [HomeCard] UI as the main feed.
/// Tapping a photo in the profile grid opens this screen so the user can scroll through all photos.
class ProfilePhotosFeedScreen extends StatefulWidget {
  final String profileUserId;
  final String profileUserName;
  final String? profileUserImage;
  /// Post ID of the photo the user tapped — feed will scroll to this exact post.
  final String? initialPostId;

  const ProfilePhotosFeedScreen({
    Key? key,
    required this.profileUserId,
    required this.profileUserName,
    this.profileUserImage,
    this.initialPostId,
  }) : super(key: key);

  @override
  State<ProfilePhotosFeedScreen> createState() => _ProfilePhotosFeedScreenState();
}

class _ProfilePhotosFeedScreenState extends State<ProfilePhotosFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _estimatedCardHeight = 520;
  bool _hasScrolledToInitial = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPost(List<QueryDocumentSnapshot> docs) {
    if (_hasScrolledToInitial || widget.initialPostId == null || widget.initialPostId!.isEmpty) return;
    final index = docs.indexWhere((d) => d.id == widget.initialPostId);
    if (index < 0) return;
    _hasScrolledToInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final offset = (index * _estimatedCardHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Photos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: widget.profileUserId)
            .where('type', isEqualTo: 'image')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: recntsColor, strokeWidth: 3),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: Colors.white.withOpacity(0.6)),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load photos',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'Could not load photos',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
              ),
            );
          }
          // Sort by timestamp descending in memory (avoids composite index)
          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
            ..sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>?)?['timestamp'];
              final bTs = (b.data() as Map<String, dynamic>?)?['timestamp'];
              final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
              final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_rounded, size: 64, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                  ),
                ],
              ),
            );
          }

          _scrollToPost(docs);

          final feedProvider = context.read<FeedProvider>();
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              String timeAgo = 'now';
              if (data['timestamp'] != null) {
                try {
                  timeAgo = timeago.format(
                    (data['timestamp'] as Timestamp).toDate(),
                    locale: 'en_short',
                  );
                } catch (_) {}
              }
              final userFirstName = data['userFirstName']?.toString() ?? '';
              final userSecondName = data['userSecondName']?.toString() ?? '';
              final userName = userFirstName.isNotEmpty || userSecondName.isNotEmpty
                  ? NameUtils.getDisplayName(userFirstName, userSecondName)
                  : widget.profileUserName;
              final userImage = data['userImage']?.toString() ?? widget.profileUserImage ?? '';

              return HomeCard(
                userId: data['userId']?.toString() ?? widget.profileUserId,
                postId: doc.id,
                fileUrl: data['fileUrl']?.toString() ?? '',
                likes: (data['likes'] is int) ? data['likes'] as int : int.tryParse('${data['likes'] ?? 0}') ?? 0,
                impressions: (data['impressions'] is int)
                  ? data['impressions'] as int
                  : (data['views'] is int)
                      ? data['views'] as int
                      : int.tryParse('${data['impressions'] ?? data['views'] ?? 0}') ?? 0,
                description: data['description']?.toString() ?? '',
                userImage: userImage,
                userName: userName,
                time: timeAgo,
                type: data['type']?.toString() ?? 'image',
                musicData: feedProvider.safeMusicDataFromMap(data['music'] as Map<String, dynamic>?),
                questionId: data['questionId']?.toString(),
                location: data['location']?.toString(),
                tags: data['tags'] != null ? List<String>.from(data['tags'] as List) : null,
              );
            },
          );
        },
      ),
    );
  }
}
