import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Shared comment bottom sheet widget that can be used for both feed posts and reels
class SharedCommentBottomSheet extends StatefulWidget {
  /// List of comments as Map<String, dynamic>
  /// Each comment should have: id, userId, userName, userImage, text, timestamp, parentId
  final List<Map<String, dynamic>> comments;
  
  /// Whether comments are currently loading
  final bool isLoading;
  
  /// Callback to add a new comment
  final Future<void> Function(String text) onAddComment;
  
  /// Callback to add a reply to a comment
  final Future<void> Function(String parentCommentId, String text) onAddReply;
  
  /// Optional callback when the sheet is dismissed
  final VoidCallback? onDismiss;
  
  /// Optional callback to delete a comment (if null, delete button won't show)
  final Future<void> Function(String commentId, String commentUserId)? onDeleteComment;
  
  /// Optional callback to edit a comment (only shown for current user's comments)
  /// Receives the commentId and the updated text
  final Future<void> Function(String commentId, String newText)? onEditComment;
  
  /// Optional function to fetch user data (for reels that need async user fetching)
  /// If provided, this will be used instead of userName/userImage from comment data
  final Future<Map<String, dynamic>?> Function(String userId)? fetchUserData;
  
  /// Optional post/reel owner ID to show "by author" badge
  final String? postOwnerId;
  
  /// Optional callback for liking a comment
  final Future<void> Function(String commentId)? onLikeComment;
  
  /// Optional map of comment IDs to like counts
  final Map<String, int>? commentLikes;

  const SharedCommentBottomSheet({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.onAddComment,
    required this.onAddReply,
    this.onDismiss,
    this.onDeleteComment,
    this.fetchUserData,
    this.postOwnerId,
    this.onLikeComment,
    this.commentLikes,
    this.onEditComment,
  });

  @override
  State<SharedCommentBottomSheet> createState() => _SharedCommentBottomSheetState();
}

class _SharedCommentBottomSheetState extends State<SharedCommentBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyToCommentId;
  String? _replyToUserName;
  bool _hasText = false;
  
  // Quick emoji reactions
  final List<String> _quickEmojis = ['❤️', '🙌', '🔥', '🙏', '😢', '🥰', '😮', '😂'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  void _setReplyTo(String? commentId, String? userName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserName = userName;
      // Auto-insert @username when replying
      if (userName != null && commentId != null) {
        _controller.text = '@$userName ';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      } else {
        _controller.clear();
      }
    });
  }

  void _clearReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getTopLevelComments() {
    final allComments = widget.comments;
    return allComments
        .where((c) =>
            c['parentId'] == null ||
            (c['parentId'] as String?) == '' ||
            !(allComments.any((p) => p['id'] == c['parentId'])))
        .toList();
  }

  List<Map<String, dynamic>> _getRepliesFor(String parentId) {
    return widget.comments
        .where((c) => (c['parentId'] as String?) == parentId)
        .toList();
  }

  String? _getParentCommentUsername(String? parentId) {
    if (parentId == null) return null;
    try {
      final parent = widget.comments.firstWhere(
        (c) => c['id'] == parentId,
      );
      // Return userName from comment data (works for both feeds and reels)
      return parent['userName'] as String?;
    } catch (e) {
      return null;
    }
  }

  Widget _buildCommentCard(
    Map<String, dynamic> data, {
    bool isReply = false,
  }) {
    final ts = data['timestamp'];
    String ago = '';
    if (ts != null) {
      try {
        final dt = ts.toDate();
        ago = timeago.format(dt, locale: 'en_short');
      } catch (e) {
        ago = '';
      }
    }

    final uid = data['userId'] as String? ?? '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == uid;
    final isAuthor = widget.postOwnerId != null && uid == widget.postOwnerId;
    final likeCount = widget.commentLikes?[data['id']] ?? 0;

    // If fetchUserData is provided, use FutureBuilder to fetch user data
    if (widget.fetchUserData != null) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: widget.fetchUserData!(uid),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const SizedBox();
          }
          final user = userSnap.data!;
          return _buildCommentCardContent(
            data: data,
            isReply: isReply,
            ago: ago,
            uid: uid,
            isOwner: isOwner,
            isAuthor: isAuthor,
            likeCount: likeCount,
            userName: user['firstName'] ?? data['userName'] ?? 'Unknown',
            userImage: user['profileImage'] ?? data['userImage'] ?? '',
          );
        },
      );
    }

    // Otherwise use data directly from comment
    return _buildCommentCardContent(
      data: data,
      isReply: isReply,
      ago: ago,
      uid: uid,
      isOwner: isOwner,
      isAuthor: isAuthor,
      likeCount: likeCount,
      userName: data['userName'] ?? 'User',
      userImage: data['userImage'] ?? '',
    );
  }

  Widget _buildCommentCardContent({
    required Map<String, dynamic> data,
    required bool isReply,
    required String ago,
    required String uid,
    required bool isOwner,
    required bool isAuthor,
    required int likeCount,
    required String userName,
    required String userImage,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 48 : 16,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (uid.isNotEmpty) {
                openUserProfile(context, uid);
              }
            },
            child: CircleAvatar(
              backgroundImage: userImage.isNotEmpty
                  ? NetworkImage(userImage)
                  : null,
              backgroundColor: Colors.grey[700],
              radius: isReply ? 14 : 18,
              child: userImage.isEmpty && userName.isNotEmpty
                  ? Text(
                      userName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isReply ? 12 : 14,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username, timestamp, and like count
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ago.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        ago,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                    if (isAuthor) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.favorite,
                        size: 12,
                        color: Colors.red[400],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'by author',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Comment text
                Text(
                  data['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Actions row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final parentId = data['parentId'] as String?;
                        final rootId = (parentId != null && parentId.isNotEmpty)
                            ? parentId
                            : data['id'] as String?;
                        _setReplyTo(rootId, userName);
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOwner && widget.onEditComment != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          _showEditDialog(
                            data['id'] as String,
                            (data['text'] ?? '') as String,
                          );
                        },
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Nested reply indicator - show parent comment username
                if (isReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          'Reply to ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          _getParentCommentUsername(data['parentId'] as String?) ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Delete button (only for comment owner)
          if (isOwner && widget.onDeleteComment != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.grey[400],
              ),
              onPressed: () => widget.onDeleteComment!(
                data['id'] as String,
                uid,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(String commentId, String initialText) async {
    if (widget.onEditComment == null) return;

    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2847),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit comment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            maxLines: null,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Update your comment',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(text);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      await widget.onEditComment!(commentId, result.trim());
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_replyToCommentId != null) {
      // Remove @username prefix if user hasn't typed anything after it
      // But keep it if user has added their own text
      String replyText = text;
      if (_replyToUserName != null && text.startsWith('@$_replyToUserName ')) {
        // User might have typed after @username, so we keep the full text
        // The @username will be part of the comment text
        replyText = text;
      }
      await widget.onAddReply(_replyToCommentId!, replyText);
    } else {
      await widget.onAddComment(text);
    }

    _clearReply();
  }

  void _handleQuickEmoji(String emoji) {
    _controller.text = _controller.text + emoji;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;
    final maxHeight = (mq.size.height * 0.9) - mq.padding.bottom;
    final topLevelComments = _getTopLevelComments();
    final hasComments = widget.comments.isNotEmpty;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: mq.viewInsets.bottom + bottomPadding,
        ),
        child: Container(
          height: maxHeight.clamp(300.0, mq.size.height * 0.9),
          decoration: const BoxDecoration(
            color: darkBackgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      "Comments",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      color: Colors.white,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDismiss?.call();
                      },
                    ),
                  ],
                ),
              ),

              // Comments list
              Expanded(
                child: widget.isLoading && !hasComments
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : !hasComments
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 48,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Be the first to comment!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: topLevelComments.length,
                            itemBuilder: (context, index) {
                              final c = topLevelComments[index];
                              final commentId = c['id'] as String? ?? '';
                              final children = _getRepliesFor(commentId);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCommentCard(c),
                                  for (final r in children)
                                    _buildCommentCard(r, isReply: true),
                                ],
                              );
                            },
                          ),
              ),

              // Quick emoji reactions
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickEmojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _handleQuickEmoji(_quickEmojis[index]),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Text(
                          _quickEmojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Reply target indicator
              if (_replyToCommentId != null && _replyToUserName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: darkBackgroundSecondary,
                  child: Row(
                    children: [
                      Text(
                        'Replying to $_replyToUserName',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearReply,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

              // Input field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: darkBackgroundPrimary,
                  border: Border(
                    top: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                child: Row(
                  children: [
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyToUserName == null
                              ? 'Add a comment...'
                              : 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    // Send button
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: _hasText
                            ? Colors.blue
                            : Colors.grey[400],
                      ),
                      onPressed: _hasText ? _handleSend : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
