import 'dart:async';
import 'dart:developer';
import 'package:beatjerky/providers/feeds_provider/feed_comments_provider.dart';
import 'package:beatjerky/screens/New%20Feed/comment_screen.dart';
import 'package:beatjerky/screens/New%20Feed/feed_shimmer.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:provider/provider.dart';
import 'package:beatjerky/providers/feeds_provider/feeds_provider.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../../utils/name_utils.dart';
import '../auth_screen/login_screen.dart';
import '../../model/music_track_model.dart';
import '../../notification_services/trigger_notification_services.dart';
import '../../model/question_model.dart';
import 'create_post_screen.dart';
import '../view_user_profile_screen.dart';

class NewFeedScreen extends StatefulWidget {
  final String? initialPostId; // Optional postId to scroll to

  const NewFeedScreen({super.key, this.initialPostId});

  @override
  State<NewFeedScreen> createState() => _NewFeedScreenState();
}

class _NewFeedScreenState extends State<NewFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _postKeys = {};
  bool _hasScrolledToPost = false;
  bool _postsLoaded = false;
  static const double _estimatedPostHeight = 420.0;
  int _visibleStart = 0;
  int _visibleEnd = 2;
  int _lastPostCount = 0;

  void _updateVisibleRange() {
    if (!_scrollController.hasClients || !mounted) return;
    final provider = Provider.of<FeedProvider>(context, listen: false);
    final count = provider.posts.length;
    if (count == 0) return;
    final offset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    final start = (offset / _estimatedPostHeight).floor().clamp(0, count - 1);
    final end = ((offset + viewport) / _estimatedPostHeight).ceil().clamp(0, count - 1);
    if (start != _visibleStart || end != _visibleEnd || count != _lastPostCount) {
      _visibleStart = start;
      _visibleEnd = end;
      _lastPostCount = count;
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateVisibleRange);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateVisibleRange);
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to specific post by index using GlobalKey
  void _scrollToPostIndex(int index) {
    if (_hasScrolledToPost || index < 0) {
      return;
    }

    _hasScrolledToPost = true;

    // Wait for the list to be built and rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        // Retry if not ready
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) {
            _scrollToPostIndex(index);
          }
        });
        return;
      }

      // Use RenderObject to get exact position
      final key = _postKeys[index];
      if (key?.currentContext != null) {
        final RenderBox? renderBox =
            key!.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final scrollOffset =
              _scrollController.offset +
              position.dy -
              100; // 100px padding from top

          _scrollController.animateTo(
            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
          return;
        }
      }

      // Fallback: Use estimated height if key not available
      const estimatedHeight = 600.0;
      final offset = (index * estimatedHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToPost(List<Map<String, dynamic>> posts) {
    if (_hasScrolledToPost ||
        widget.initialPostId == null ||
        widget.initialPostId!.isEmpty) {
      return;
    }

    final index = posts.indexWhere(
      (post) => post['id'] == widget.initialPostId,
    );
    if (index < 0) {
      log('Post ${widget.initialPostId} not found in feed');
      return; // Post not found
    }

    log('Scrolling to post at index $index (postId: ${widget.initialPostId})');
    _scrollToPostIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(selectedRole: ''),
          ),
        );
      });
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Text(
              'BeatJerky Hub',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: appGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: recntsColor.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () async {
            
            final refreshed = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CreatePostScreen()),
            );
            if (refreshed == true) {
              feedProvider.fetchPosts();
            }
          },
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Builder(
        builder: (_) {
          final posts = feedProvider.posts;
          final postsCount = posts.length;
          final isLoading = feedProvider.isLoading;
          final hasError =
              feedProvider.errorMessage != null &&
              feedProvider.errorMessage!.isNotEmpty;

          log(
            '📱 Feed Screen State: postsCount=$postsCount, isLoading=$isLoading, hasError=$hasError',
          );

          // ============================================
          // PRIORITY 1: If feed data exists, show it
          // ============================================
          // Simple check: if posts count > 0, show posts
          if (postsCount > 0) {
            // Ensure posts are loaded before scrolling
            if (!_postsLoaded) {
              _postsLoaded = true;
              // Scroll to specific post if initialPostId is provided
              if (widget.initialPostId != null) {
                // Wait a bit for the list to render
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _scrollToPost(feedProvider.posts);
                    }
                  });
                });
              }
            } else if (_postsLoaded &&
                widget.initialPostId != null &&
                !_hasScrolledToPost) {
              // Retry scrolling if posts were already loaded
              _scrollToPost(feedProvider.posts);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateVisibleRange();
            });
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(top: 12.0, bottom: 12),
              itemCount: feedProvider.posts.length,
              itemBuilder: (context, index) {
                // Create or get GlobalKey for this post index
                if (!_postKeys.containsKey(index)) {
                  _postKeys[index] = GlobalKey();
                }

                final post = feedProvider.posts[index];

                String timeAgo = "now";
                if (post['timestamp'] != null) {
                  try {
                    timeAgo = timeago.format(
                      (post['timestamp'] as Timestamp).toDate(),
                      locale: 'en_short',
                    );
                  } catch (_) {}
                }

                final isVideoVisible = index >= _visibleStart && index <= _visibleEnd;
                return Container(
                  key: _postKeys[index],
                  child: HomeCard(
                    userId: post['userId'],
                    postId: post['id'],
                    fileUrl: post['fileUrl'],
                    likes: post['likes'],
                    impressions: _readImpressions(post),
                    description: post['description'],
                    userImage: post['userImage'],
                    userName: NameUtils.getDisplayName(
                      post['userFirstName'],
                      post['userSecondName'],
                    ),
                    time: timeAgo,
                    type: post['type'],
                    musicData: feedProvider.safeMusicDataFromMap(post['music']),
                    questionId: post['questionId'],
                    location: post['location'],
                    tags: post['tags'] != null
                        ? List<String>.from(post['tags'])
                        : null,
                    isVideoVisible: isVideoVisible,
                  ),
                );
              },
            );
          }

          // ============================================
          // PRIORITY 2: Show shimmer when loading
          // ============================================
          if (isLoading) {
            log('📱 Showing shimmer (loading)');
            return const FeedShimmer();
          }

          // ============================================
          // PRIORITY 3: Show error if there's an error
          // ============================================
          if (hasError) {
            log('📱 Showing error: ${feedProvider.errorMessage}');
            return Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Error: ${feedProvider.errorMessage}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // // ============================================
          // // PRIORITY 4: Show "No posts available" ONLY when feed data is empty
          // // ============================================
          // // Simple condition: posts count must be 0
          // // This is the ONLY condition needed - if posts exist, we already returned above
          // if (postsCount == 0) {
          //   log('📱 Showing "No posts available" (feed data is empty: postsCount=$postsCount)');
          //   return Center(
          //     child: Container(
          //       margin: const EdgeInsets.all(20),
          //       padding: const EdgeInsets.all(32),
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           colors: [
          //             const Color(0xFF16213E),
          //             const Color(0xFF1A2847),
          //           ],
          //         ),
          //         borderRadius: BorderRadius.circular(20),
          //         border: Border.all(
          //           color:recntsColor.withOpacity(0.3),
          //           width: 1.5,
          //         ),
          //       ),
          //       child: Column(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Icon(
          //             Icons.feed_outlined,
          //             color: recntsColor,
          //             size: 64,
          //           ),
          //           const SizedBox(height: 16),
          //           const Text(
          //             'No posts available',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //               fontWeight: FontWeight.w600,
          //             ),
          //           ),
          //           const SizedBox(height: 8),
          //           Text(
          //             'Be the first to share something!',
          //             style: TextStyle(
          //               color: Colors.white.withOpacity(0.7),
          //               fontSize: 14,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   );
          // }

          // Fallback: If somehow we reach here, show shimmer as safety
          log('📱 Fallback: Showing shimmer (unexpected state)');
          return const FeedShimmer();
        },
      ),
    );
  }
}

int _readImpressions(Map<String, dynamic> post) {
  final imp = post['impressions'];
  if (imp is int) return imp;
  final v = post['views'];
  if (v is int) return v;
  return int.tryParse('${imp ?? v ?? 0}') ?? 0;
}

class HomeCard extends StatefulWidget {
  final String fileUrl;
  final String postId;
  final int likes;
  final int impressions;
  final String userId;
  final String description;
  final String userName;
  final String userImage;
  final String time;
  final String type;
  final PostWithMusic? musicData;
  final String? questionId;
  final String? location;
  final List<String>? tags;
  /// When false, video is not loaded (saves memory). When true, video can init. Used by feed for visibility-based loading.
  final bool isVideoVisible;

  const HomeCard({
    super.key,
    required this.fileUrl,
    required this.postId,
    required this.userId,
    required this.description,
    required this.userName,
    required this.userImage,
    required this.time,
    required this.type,
    required this.likes,
    this.impressions = 0,
    this.musicData,
    this.questionId,
    this.location,
    this.tags,
    this.isVideoVisible = true,
  });

  @override
  _HomeCardState createState() => _HomeCardState();
}

class _HomeCardState extends State<HomeCard> {
  int likes = 0;
  int _impressions = 0;
  bool _hasRecordedImpression = false;
  bool _isLiked = false;
  bool _isUpdating = false;
  int shareCount = 0;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  int commentCount = 0; // Add comment count variable
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Music playback
  AudioPlayer? _musicPlayer;
  bool _isMusicPlaying = false;
  bool _isMusicInitialized = false;
  StreamSubscription<Duration>? _musicPosSub;
  double _musicClipStart = 0;
  double? _musicClipDuration;

  // Stream subscriptions for proper disposal
  StreamSubscription<DocumentSnapshot>? _likeStatusSubscription;
  StreamSubscription<DocumentSnapshot>? _likeCountSubscription;
  StreamSubscription<DocumentSnapshot>? _questionSubscription;

  // Question state
  QuestionPost? _questionData;
  String? _selectedOptionId;
  bool _hasVoted = false;
  bool _isLoadingQuestion = false;
  bool get isLoadingQuestion => _isLoadingQuestion;

  Future<void> _recordImpression() async {
    if (_hasRecordedImpression || !mounted) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final isOwnPost = widget.userId == currentUser.uid;

    if (isOwnPost) {
      try {
        final postRef = _firestore.collection('posts').doc(widget.postId);
        final doc = await postRef.get();
        if (!doc.exists || !mounted) return;
        final alreadyCounted = doc.data()?['impressionCountedByOwner'] == true;
        if (alreadyCounted) {
          _hasRecordedImpression = true;
          return;
        }
        await _firestore.runTransaction((transaction) async {
          transaction.update(postRef, {
            'impressions': FieldValue.increment(1),
            'impressionCountedByOwner': true,
          });
        });
        if (mounted) {
          _hasRecordedImpression = true;
          setState(() => _impressions = _impressions + 1);
        }
      } catch (_) {}
      return;
    }

    _hasRecordedImpression = true;
    if (mounted) setState(() => _impressions = _impressions + 1);
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'impressions': FieldValue.increment(1),
      });
    } catch (_) {
      if (mounted)
        setState(() => _impressions = _impressions > 0 ? _impressions - 1 : 0);
    }
  }

  @override
  void initState() {
    super.initState();
    likes = widget.likes;
    _impressions = widget.impressions;
    _checkUserLikeStatus();
    _listenToLikeStatus();
    _listenToLikeCount();
    _loadCommentCount();

    if (widget.type == 'video' && widget.fileUrl.isNotEmpty && widget.isVideoVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initVideoIfNeeded();
      });
    }

    // Initialize music player if post has music
    if (widget.musicData != null && widget.musicData!.musicUrl != null) {
      _initializeMusicPlayer();
    }

    // Load question data if this is a question post
    if (widget.type == 'question' && widget.questionId != null) {
      _loadQuestionData();
      _questionSubscription = _firestore
          .collection('questions')
          .doc(widget.questionId!)
          .snapshots()
          .listen((doc) {
            if (!mounted) return;
            if (doc.exists) {
              try {
                final map = doc.data() as Map<String, dynamic>;
                _questionData = QuestionPost.fromMap(map);
                final currentUser = _auth.currentUser;
                if (currentUser != null) {
                  bool voted = false;
                  String? selected;
                  for (final opt in _questionData!.options) {
                    if (opt.voters.contains(currentUser.uid)) {
                      voted = true;
                      selected = opt.id;
                      break;
                    }
                  }
                  _hasVoted = voted;
                  _selectedOptionId = selected;
                }
                setState(() {});
              } catch (_) {}
            }
          });
    }
    // Record one impression when this post is shown (short delay then update UI immediately)
    Future.delayed(const Duration(milliseconds: 300), _recordImpression);
  }

  @override
  void didUpdateWidget(covariant HomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != 'video') return;
    if (widget.isVideoVisible && !oldWidget.isVideoVisible) {
      _initVideoIfNeeded();
    } else if (!widget.isVideoVisible && oldWidget.isVideoVisible) {
      _disposeVideo();
    }
  }

  void _videoPlayStateListener() {
    if (!mounted || _videoController == null) return;
    final playing = _videoController!.value.isPlaying;
    if (playing != _isVideoPlaying) {
      setState(() => _isVideoPlaying = playing);
    }
  }

  Future<void> _initVideoIfNeeded() async {
    if (_videoController != null || widget.fileUrl.isEmpty || widget.type != 'video') return;
    try {
      final c = VideoPlayerController.network(widget.fileUrl);
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(_videoPlayStateListener);
      setState(() {
        _videoController = c;
        _isVideoPlaying = c.value.isPlaying;
      });
    } catch (e) {
      debugPrint('Feed video init error: $e');
      if (mounted) setState(() {});
    }
  }

  void _disposeVideo() {
    final c = _videoController;
    if (c != null) {
      c.removeListener(_videoPlayStateListener);
      c.dispose();
      _videoController = null;
      _isVideoPlaying = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeMusicPlayer() async {
    try {
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setUrl(widget.musicData!.musicUrl!);
      await _musicPlayer!.setVolume(widget.musicData!.musicVolume ?? 0.5);

      _musicClipStart = (widget.musicData!.musicStartTime ?? 0).toDouble();
      _musicClipDuration = widget.musicData!.musicClipDuration?.toDouble();

      if (_musicClipStart > 0) {
        await _musicPlayer!.seek(Duration(seconds: _musicClipStart.toInt()));
      }

      _musicPosSub?.cancel();
      _musicPosSub = _musicPlayer!.positionStream.listen((pos) {
        if (_musicClipDuration != null) {
          final end = _musicClipStart + _musicClipDuration!;
          if (pos.inSeconds >= end.toInt()) {
            _musicPlayer?.pause();
            _musicPlayer?.seek(Duration(seconds: _musicClipStart.toInt()));
            if (mounted && _isMusicPlaying) {
              setState(() {
                _isMusicPlaying = false;
              });
            }
          }
        }
      });

      setState(() {
        _isMusicInitialized = true;
      });
    } catch (e) {
      print('Error initializing music player: $e');
    }
  }

  Future<void> _toggleMusicPlayback() async {
    if (!_isMusicInitialized || _musicPlayer == null) {
      await _initializeMusicPlayer();
      if (_musicPlayer == null) return;
    }

    try {
      if (_isMusicPlaying) {
        await _musicPlayer!.pause();
      } else {
        // Ensure we start inside clip
        final pos = _musicPlayer!.position;
        if (pos.inSeconds < _musicClipStart.toInt()) {
          await _musicPlayer!.seek(Duration(seconds: _musicClipStart.toInt()));
        }
        await _musicPlayer!.play();
      }

      setState(() {
        _isMusicPlaying = !_isMusicPlaying;
      });
    } catch (e) {
      print('Error toggling music playback: $e');
    }
  }

  Future<void> _loadCommentCount() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();

      setState(() {
        commentCount = snapshot.docs.length;
      });
    } catch (e) {
      print('Error loading comment count: $e');
    }
  }

  Future<void> _sendLikeNotification() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Don't send notification if user is liking their own post
      if (currentUser.uid == widget.userId) return;

      log("postuserid ${widget.userId}");

      // Get post owner's FCM token using your approach
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usersData') // Correct collection name
          .doc(widget.userId)
          .get();

      final userData = userSnapshot.data();
      final targetToken = userData?['fcmToken'] as String?;

      // Get current user's name for the notification
      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      if (targetToken != null && targetToken.isNotEmpty) {
        // Send push notification
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: targetToken,
          title: 'New Like! ❤️',
          body: '$currentUserName liked your post',
        );
      } else {
        log('No FCM token found for user ${widget.userId}');
      }
      // Save notification to Firestore
      final notificationData = {
        'type': 'like',
        'fromUserId': currentUser.uid,
        'fromUserName': currentUserName,
        'postId': widget.postId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$currentUserName liked your post',
        'isRead': false,
      };
      await _firestore
          .collection('notifications')
          .doc(widget.userId)
          .collection('userNotifications')
          .add(notificationData);

      log('Like notification sent and saved for ${widget.userId}');
    } catch (e) {
      log('Error sending like notification: $e');
    }
  }

  @override
  void dispose() {
    _likeStatusSubscription?.cancel();
    _likeCountSubscription?.cancel();
    _questionSubscription?.cancel();
    _disposeVideo();
    _musicPosSub?.cancel();
    _musicPlayer?.dispose();
    super.dispose();
  }

  Future<void> _checkUserLikeStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final likeDoc = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _isLiked = likeDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking user like status: $e');
    }
  }

  // Listen to real-time like status changes
  void _listenToLikeStatus() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _likeStatusSubscription = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _isLiked = snapshot.exists;
            });
          }
        });
  }

  // Listen to real-time like count and impressions from post document
  void _listenToLikeCount() {
    _likeCountSubscription = _firestore
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newLikes = data['likes'] is int
                ? data['likes'] as int
                : int.tryParse('${data['likes'] ?? 0}') ?? 0;
            final newImpressions = data['impressions'] is int
                ? data['impressions'] as int
                : (data['views'] is int
                      ? data['views'] as int
                      : int.tryParse(
                              '${data['impressions'] ?? data['views'] ?? 0}',
                            ) ??
                            0);
            setState(() {
              likes = newLikes;
              if (newImpressions > _impressions) _impressions = newImpressions;
            });
          }
        });
  }

  Future<void> _toggleLike() async {
    if (_isUpdating) return; // Prevent multiple rapid taps

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppToast.show('Please log in to like posts', isError: true);
      return;
    }

    // Keep originals for rollback
    final bool originalIsLiked = _isLiked;
    final int originalLikes = likes;

    // Optimistic UI update
    setState(() {
      _isUpdating = true;
      _isLiked = !_isLiked;
      likes = _isLiked ? likes + 1 : (likes > 0 ? likes - 1 : 0);
    });

    bool isUnliking = false;

    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(widget.postId);
      final DocumentReference<Map<String, dynamic>> likeRef = postRef
          .collection('likes')
          .doc(currentUser.uid);

      await _firestore.runTransaction((transaction) async {
        final likeSnap = await transaction.get(likeRef);
        final postSnap = await transaction.get(postRef);
        final int serverLikes = (postSnap.data()?['likes'] ?? 0) is int
            ? (postSnap.data()?['likes'] ?? 0) as int
            : int.tryParse('${postSnap.data()?['likes'] ?? 0}') ?? 0;

        if (likeSnap.exists) {
          // Unlike: remove like doc and decrement count (min 0)
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': serverLikes > 0 ? serverLikes - 1 : 0,
          });

          isUnliking = true;
        } else {
          // Like: create like doc and increment count
          transaction.set(likeRef, {
            'userId': currentUser.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {'likes': serverLikes + 1});
        }
      });

      // Send notification to post owner if someone liked their post
      if (!originalIsLiked && _isLiked) {
        await _sendLikeNotification();
      }

      if (isUnliking) {
        // Delete notification
        await _deleteLikeNotification(
          fromUserId: currentUser.uid,
          toUserId: widget.userId,
          postId: widget.postId,
        );
      }
    } catch (e) {
      // Roll back optimistic change on failure
      if (mounted) {
        setState(() {
          _isLiked = originalIsLiked;
          likes = originalLikes;
        });
      }
      print('Error toggling like in transaction: $e');
      AppToast.show('Could not update like. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteLikeNotification({
    required String fromUserId,
    required String toUserId,
    required String postId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(toUserId)
          .collection('userNotifications')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: 'like')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      log(
        'Deleted like notification from $fromUserId to $toUserId on post $postId',
      );
    } catch (e) {
      log('Error deleting like notification: $e');
    }
  }

  // Load question data
  Future<void> _loadQuestionData() async {
    if (widget.questionId == null) return;

    setState(() => _isLoadingQuestion = true);

    try {
      DocumentSnapshot doc = await _firestore
          .collection('questions')
          .doc(widget.questionId)
          .get();

      if (doc.exists && mounted) {
        _questionData = QuestionPost.fromMap(
          doc.data() as Map<String, dynamic>,
        );

        // Check if current user has already voted
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          for (var option in _questionData!.options) {
            if (option.voters.contains(currentUser.uid)) {
              _hasVoted = true;
              _selectedOptionId = option.id;
              break;
            }
          }
        }

        setState(() {});
      }
    } catch (e) {
      print('Error loading question data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuestion = false);
      }
    }
  }

  // Vote on question option
  Future<void> _voteOnOption(String optionId) async {
    if (_questionData == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppToast.show('Please log in to vote', isError: true);
      return;
    }

    try {
      // Update the question document allowing users to change their vote anytime
      await _firestore.runTransaction((transaction) async {
        DocumentReference questionRef = _firestore
            .collection('questions')
            .doc(widget.questionId!);

        DocumentSnapshot questionDoc = await transaction.get(questionRef);
        if (!questionDoc.exists) return;

        Map<String, dynamic> data = questionDoc.data() as Map<String, dynamic>;
        List<dynamic> options = data['options'] ?? [];

        // First remove this user from all options' voters,
        // then add them to the newly selected option.
        for (int i = 0; i < options.length; i++) {
          List<String> voters = List<String>.from(options[i]['voters'] ?? []);

          // Remove current user from this option if present
          voters.remove(currentUser.uid);

          // If this is the newly selected option, add the user
          if (options[i]['id'] == optionId) {
            if (!voters.contains(currentUser.uid)) {
              voters.add(currentUser.uid);
            }
          }

          options[i]['voters'] = voters;
          options[i]['votes'] = voters.length;
        }

        // Update total votes
        int totalVotes = 0;
        for (var option in options) {
          totalVotes += ((option['votes'] ?? 0) as num).toInt();
        }

        transaction.update(questionRef, {
          'options': options,
          'totalVotes': totalVotes,
        });
      });

      // Update local state
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _selectedOptionId = optionId;
        });
      }

      // Reload question data to get updated vote counts
      await _loadQuestionData();
    } catch (e) {
      print('Error voting: $e');
      AppToast.show('Error voting. Please try again.', isError: true);
    }
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _showComments(BuildContext context, String postId) {
    context.read<CommentProvider>().clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return CommentScreen(postId: postId, postOwnerId: widget.userId);
      },
    ).then((_) {
      _loadCommentCount();
    });
  }

  // Handle menu selection (edit, delete, report)
  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'edit':
        _showEditPostDialog(context);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
      case 'report':
        _showReportOptions(context);
        break;
    }
  }

  // Show edit post dialog
  void _showEditPostDialog(BuildContext context) {
    final TextEditingController editController = TextEditingController(
      text: widget.description,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2847),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFBB86FC).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: appGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: editController,
            maxLines: 3,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Edit your post...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF0A0E27).withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFBB86FC),
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBB86FC).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await _updatePost(editController.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2847),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await _deletePost();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show report options
  void _showReportOptions(BuildContext context) {
    final List<String> reportReasons = [
      'Sexual Content',
      'Hateful Speech',
      'Violence',
      'Harassment',
      'Spam',
      'False Information',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedReason;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Report Post', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Please select a reason for reporting this post:',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                  SizedBox(height: 16),
                  ...reportReasons.map(
                    (reason) => RadioListTile<String>(
                      title: Text(
                        reason,
                        style: TextStyle(color: Colors.white),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason = value;
                        });
                      },
                      activeColor: Colors.purple,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedReason != null) {
                      await _reportPost(selectedReason!);
                      Navigator.pop(context);
                      _showReportConfirmation(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white, // Make button text white
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show report confirmation
  void _showReportConfirmation(BuildContext context) {
    AppToast.show(
      'Post reported successfully. We will review it soon and take appropriate action.',
    );
  }

  // Update post description
  Future<void> _updatePost(String newDescription) async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'description': newDescription,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      AppToast.show('Post updated successfully!');
    } catch (e) {
      print('Error updating post: $e');
      AppToast.show('Failed to update post. Please try again.', isError: true);
    }
  }

  // Delete post
  Future<void> _deletePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).delete();

      // Show success message
      AppToast.show('Post deleted successfully!');

      // Note: The post will automatically disappear from the StreamBuilder
      // since it's listening to Firebase changes
    } catch (e) {
      print('Error deleting post: $e');
      AppToast.show('Failed to delete post. Please try again.', isError: true);
    }
  }

  // Report post
  Future<void> _reportPost(String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('reports').add({
        'postId': widget.postId,
        'reporterId': currentUser.uid,
        'reportedUserId': widget.userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('Post reported successfully with reason: $reason');
    } catch (e) {
      print('Error reporting post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF16213E), const Color(0xFF1A2847)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFBB86FC).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBB86FC).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E27).withOpacity(0.5),
                  const Color(0xFF16213E).withOpacity(0.3),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with profile image, user info, and menu
                Row(
                  children: [
                    // User avatar (tap to open profile)
                    GestureDetector(
                      onTap: () => openUserProfile(context, widget.userId),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: appGradient,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBB86FC).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: widget.userImage.isNotEmpty
                              ? NetworkImage(widget.userImage)
                              : null,
                          backgroundColor: const Color(0xFF1A2847),
                          child: widget.userImage.isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: _firestore
                                .collection('usersData')
                                .doc(widget.userId)
                                .get(),
                            builder: (context, snap) {
                              final paid =
                                  (snap.data?.data()
                                      as Map<String, dynamic>?)?['isPaid'] ??
                                  false;
                              return Row(
                                children: [
                                  Text(
                                    widget.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (paid)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.time,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More options menu
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                      ),
                      color: const Color(0xFF1A2847),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFFBB86FC).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      onSelected: (value) =>
                          _handleMenuSelection(value, context),
                      itemBuilder: (BuildContext context) {
                        // Check if this is the current user's post
                        final currentUserId =
                            FirebaseAuth.instance.currentUser?.uid;
                        final isOwnPost = currentUserId == widget.userId;

                        // Debug prints
                        print('Current user ID: $currentUserId');
                        print('Post creator ID: ${widget.userId}');
                        print('Is own post: $isOwnPost');

                        if (isOwnPost) {
                          // Show edit and delete options for own posts
                          return [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Edit Post',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Post',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        } else {
                          // Show report option for others' posts
                          return [
                            const PopupMenuItem<String>(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.report,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Report',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        }
                      },
                    ),
                  ],
                ),

                // Description - SEPARATE ROW BELOW USER INFO
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],

                // Compact music row under username (like screenshot)
                if (widget.musicData != null &&
                    widget.musicData!.musicTitle != null &&
                    widget.musicData!.musicTitle!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFBB86FC).withOpacity(0.2),
                            const Color(0xFF03DAC6).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFBB86FC).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: appGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (widget.musicData!.musicArtist != null &&
                                      widget.musicData!.musicArtist!.isNotEmpty)
                                  ? '${widget.musicData!.musicTitle!} • ${widget.musicData!.musicArtist!}'
                                  : widget.musicData!.musicTitle!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _toggleMusicPlayback,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                _isMusicPlaying
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Poll content - always show a block for question posts
          if (widget.type == 'question') ...[
            const SizedBox(height: 12),
            _questionData != null
                ? _buildQuestionContent()
                : _buildPollSkeleton(),
          ],

          // Media content - only show if there's an image or video
          if (widget.fileUrl.isNotEmpty) ...[
            const SizedBox(height: 2), // Small gap between header and media
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: widget.type == 'video'
                  ? _buildVideoContent()
                  : _buildImageContent(),
            ),
          ],

          // Action buttons only - NO DESCRIPTION HERE
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0E27).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Like button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: _isLiked
                            ? LinearGradient(
                                colors: [
                                  Colors.red.withOpacity(0.2),
                                  Colors.red.withOpacity(0.1),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isLiked
                              ? Colors.red.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isLiked
                                ? Colors.red
                                : Colors.white.withOpacity(0.7),
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            likes.toString(),
                            style: TextStyle(
                              color: _isLiked
                                  ? Colors.red
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              fontWeight: _isLiked
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
                // Views (informational)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/impression-rate.png',
                        width: 22,
                        height: 22,
                        color: Colors.white.withOpacity(0.7),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.insights_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatViewCount(_impressions),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Comment button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showComments(context, widget.postId);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            color: Colors.white.withOpacity(0.7),
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            commentCount.toString(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (widget.fileUrl.isEmpty) return const SizedBox.shrink();

    final c = _videoController;
    final initialized = c != null && c.value.isInitialized;

    final aspectRatio = (c != null && c.value.aspectRatio > 0 && c.value.aspectRatio.isFinite)
        ? c.value.aspectRatio
        : (16 / 9);
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: VideoPlayer(c),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Play/Pause overlay
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: appGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBB86FC).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (c == null) return;
                    setState(() {
                      if (c.value.isPlaying) {
                        c.pause();
                      } else {
                        c.play();
                      }
                      _isVideoPlaying = c.value.isPlaying;
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    child: Icon(
                      _isVideoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Video indicator
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build question content
  Widget _buildQuestionContent() {
    if (_questionData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location and tags
          if (widget.location != null ||
              (widget.tags != null && widget.tags!.isNotEmpty)) ...[
            Row(
              children: [
                if (widget.location != null) ...[
                  Icon(Icons.location_on, color: Colors.grey[400], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    widget.location!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  if (widget.tags != null && widget.tags!.isNotEmpty)
                    const SizedBox(width: 12),
                ],
                if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                  ...widget.tags!
                      .take(2)
                      .map(
                        (tag) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTagColor(tag).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getTagColor(tag).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: _getTagColor(tag),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Question options
          ..._questionData!.options.map((option) {
            final percentage = _questionData!.totalVotes > 0
                ? (option.votes / _questionData!.totalVotes * 100).round()
                : 0;
            final isSelected = _selectedOptionId == option.id;
            final hasVoted = _hasVoted;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _voteOnOption(option.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFBB86FC).withOpacity(0.25),
                              const Color(0xFF03DAC6).withOpacity(0.15),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              const Color(0xFF1A2847).withOpacity(0.5),
                              const Color(0xFF16213E).withOpacity(0.5),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFBB86FC)
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFBB86FC).withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isSelected ? appGradient : null,
                              color: isSelected ? null : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFBB86FC,
                                        ).withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected ? appGradient : null,
                              color: isSelected
                                  ? null
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasVoted) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _questionData!.totalVotes > 0
                                ? option.votes / _questionData!.totalVotes
                                : 0.0,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isSelected
                                  ? const Color(0xFFBB86FC)
                                  : Colors.white.withOpacity(0.3),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          // Vote count
          if (_questionData!.totalVotes > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${_questionData!.totalVotes} vote${_questionData!.totalVotes == 1 ? '' : 's'}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // Skeleton shown while poll loads the first time
  Widget _buildPollSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _skeletonOption(),
          const SizedBox(height: 8),
          _skeletonOption(),
        ],
      ),
    );
  }

  Widget _skeletonOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  // Get color for tag
  Color _getTagColor(String tag) {
    switch (tag.toLowerCase()) {
      case 'techjourney':
        return Colors.purple;
      case 'admissions':
        return Colors.orange;
      case 'education':
        return Colors.blue;
      case 'career':
        return Colors.green;
      case 'life':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget _buildImageContent() {
    // Don't show image if no URL
    if (widget.fileUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: widget.fileUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 300,
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 300,
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.error, color: Colors.white, size: 50),
        ),
      ),
      memCacheWidth: 800, // Optimize memory usage
      memCacheHeight: 600,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 600,
    );
  }
}
