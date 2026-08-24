import 'package:beatjerky/providers/feeds_provider/feed_comments_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/widgets/shared_comment_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommentScreen extends StatefulWidget {
  final String postId;
  final String? postOwnerId;

  const CommentScreen({super.key, required this.postId, this.postOwnerId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<CommentProvider>().loadComments(widget.postId);
    });
  }

  @override
  void dispose() {
    context.read<CommentProvider>().clear();
    super.dispose();
  }

  // @override
  // Widget build(BuildContext context) {
  //   final commentProvider = context.watch<CommentProvider>();
  //   return Container(
  //     height: MediaQuery.of(context).size.height * 0.7,
  //     color: const Color(0xFF1E1E1E),
  //     child: Column(
  //       children: [
  //         const SizedBox(height: 8),
  //         Container(height: 4, width: 40, color: Colors.grey),
  //         const SizedBox(height: 12),
  //         const Text("Comments", style: TextStyle(color: Colors.white, fontSize: 18)),

  //         Expanded(
  //           child: commentProvider.isLoading && commentProvider.comments.isEmpty
  //               ? const Center(child: CircularProgressIndicator(color: Colors.purple))
  //               : commentProvider.comments.isEmpty
  //                   ? const Center(
  //                       child: Text('No comments yet',
  //                           style: TextStyle(color: Colors.grey)))
  //                   : ListView.builder(
  //                       padding: const EdgeInsets.all(16),
  //                       itemCount: commentProvider.comments.length,
  //                       itemBuilder: (context, index) {
  //                         final c = commentProvider.comments[index];
  //                         final timestamp = c['timestamp'];
  //                           String timeAgo = '';

  //                           if (timestamp != null) {
  //                             final dateTime = timestamp.toDate();
  //                             timeAgo = timeago.format(dateTime, locale: 'en_short');
  //                           }
  //                         return ListTile(
  //                           leading: CircleAvatar(
  //                             backgroundImage: (c['userImage'] ?? '').isNotEmpty
  //                                 ? NetworkImage(c['userImage'])
  //                                 : null,
  //                             backgroundColor: Colors.purple,
  //                             child: (c['userImage'] ?? '').isEmpty
  //                                 ? Text(c['userName'].isNotEmpty ? c['userName'][0].toUpperCase(): "",
  //                                     style: const TextStyle(color: Colors.white))
  //                                 : null,
  //                           ),
  //                           title: Text(
  //                             c['userName'],
  //                             style: const TextStyle(
  //                                 color: Colors.white,
  //                                 fontWeight: FontWeight.bold),
  //                           ),
  //                           subtitle: Text(
  //                             c['text'],
  //                             style: const TextStyle(color: Colors.white70),
  //                           ),
  //                           trailing: Row(
  //                             mainAxisSize: MainAxisSize.min,
  //                             children: [
  //                               Padding(
  //                                 padding: const EdgeInsets.only(top: 25.0),
  //                                 child: Text(
  //                                   timeAgo,
  //                                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         );
  //                       },
  //                     ),
  //         ),

  //         // Input
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           color: Colors.grey[900],
  //           child: Row(
  //             children: [
  //               Expanded(
  //                 child: TextField(
  //                   controller: _controller,
  //                   style: const TextStyle(color: Colors.white),
  //                   decoration: const InputDecoration(
  //                     hintText: 'Write a comment...',
  //                     hintStyle: TextStyle(color: Colors.grey),
  //                     border: InputBorder.none,
  //                   ),
  //                 ),
  //               ),
  //               IconButton(
  //                 icon: const Icon(Icons.send, color: Colors.purple),
  //                 onPressed: () async {
  //                   if (_controller.text.trim().isNotEmpty) {
  //                     await commentProvider.addComment(
  //                       widget.postId,
  //                       _controller.text.trim(),
  //                     );
  //                     _controller.clear();
  //                   }
  //                 },
  //               )
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final commentProvider = context.watch<CommentProvider>();

    return SharedCommentBottomSheet(
      comments: commentProvider.comments,
      isLoading: commentProvider.isLoading,
      postOwnerId: widget.postOwnerId,
      onAddComment: (text) async {
        await commentProvider.addComment(widget.postId, text);
      },
      onAddReply: (parentCommentId, text) async {
        await commentProvider.addReply(widget.postId, parentCommentId, text);
      },
      onDeleteComment: (commentId, commentUserId) async {
        await _deleteComment(commentId, commentUserId);
      },
      onEditComment: (commentId, newText) async {
        try {
          await commentProvider.editComment(widget.postId, commentId, newText);
          AppToast.show('Comment updated');
        } catch (e) {
          AppToast.show('Error updating comment: $e', isError: true);
        }
      },
    );
  }

  Future<void> _deleteComment(String commentId, String commentUserId) async {
    final commentProvider = context.read<CommentProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Security check - verify the comment belongs to current user
    if (commentUserId != currentUserId) {
      AppToast.show('You don\'t have permission to delete this comment', isError: true);
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.red.withOpacity(0.3),
            width: 1.5,
          ),
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
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Comment',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
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
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await commentProvider.deleteComment(widget.postId, commentId, commentUserId);
        AppToast.show('Comment deleted successfully');
      } catch (e) {
        AppToast.show('Error deleting comment: $e', isError: true);
      }
    }
  }

}