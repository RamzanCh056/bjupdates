import 'dart:async';
import 'dart:ui';

import 'package:beatjerky/models/chat_models.dart';
import 'package:beatjerky/services/chat_service.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/name_utils.dart';
import 'view_user_profile_screen.dart';

const _chatAccent = Color(0xFFa855f7);
const _chatAccentDeep = Color(0xFF7c3aed);
const _chatAccentLight = Color(0xFFc084fc);
const _chatPageBg = Color(0xFF0d1117);
const _chatSurface = Color(0xFF1a1f2e);
const _chatGradient = LinearGradient(
  colors: [_chatAccentDeep, _chatAccent, _chatAccentLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchMode = false;
  bool _searchLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearchMode = false;
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() {
      _isSearchMode = true;
      _searchLoading = true;
    });
    final results = await ChatService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  String _getDisplayName(Map<String, dynamic> user) {
    return NameUtils.getDisplayNameSafe(
      user['firstName']?.toString(),
      user['secondName']?.toString(),
      fallback: user['email']?.toString() ?? 'Unknown User',
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(date);
    }
    return DateFormat('MMM d').format(date);
  }

  Future<void> _openChat({
    required String peerId,
    required String name,
    String? photo,
    String? chatId,
  }) async {
    final id = chatId ?? await ChatService.openOrCreateChat(
      peerUid: peerId,
      peerName: name,
      peerPhoto: photo,
    );
    if (!mounted) return;
    final deletedPeer = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerUid: peerId,
          peerName: name,
          peerImage: photo,
          chatId: id,
        ),
      ),
    );
    if (deletedPeer != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteChat(String chatId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkAppBarBackground,
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete chat with $displayName? This will remove all messages.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ChatService.deleteChat(chatId);
      if (mounted) Fluttertoast.showToast(msg: 'Chat deleted');
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: 'Failed to delete chat');
    }
  }

  Widget _buildConversationListShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: darkBackgroundPrimary.withValues(alpha: 0.7),
          highlightColor: darkAppBarBackground.withValues(alpha: 0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, color: Colors.grey),
                      const SizedBox(height: 8),
                      Container(height: 14, width: 120, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUser?.uid;
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: darkBackgroundPrimary,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _chatAccent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search or start new chat',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          Expanded(
            child: _isSearchMode ? _buildSearchList() : _buildInboxList(uid),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchList() {
    if (_searchLoading) return _buildConversationListShimmer();
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users match your search',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final name = _getDisplayName(user);
        final photo = user['profileImage']?.toString();
        return _ConversationListItem(
          peerId: user['id'] as String,
          displayName: name,
          profileImage: photo,
          preview: 'Tap to start conversation',
          timestamp: null,
          isUnread: false,
          onTap: () => _openChat(peerId: user['id'] as String, name: name, photo: photo),
        );
      },
    );
  }

  Widget _buildInboxList(String? uid) {
    if (uid == null) {
      return const Center(child: Text('Please sign in', style: TextStyle(color: Colors.white70)));
    }
    return StreamBuilder<List<ChatSummary>>(
      stream: ChatService.watchInbox(uid: uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load conversations.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return _buildConversationListShimmer();
        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return Center(
            child: Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
            ),
          );
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final peer = chat.peerInfoFor(uid);
            final last = chat.lastMessage;
            final preview = last == null || last.text.isEmpty
                ? 'Tap to start conversation'
                : last.text;
            return _ConversationListItem(
              peerId: chat.peerIdFor(uid),
              displayName: peer.name,
              profileImage: peer.photo,
              preview: preview,
              timestamp: last?.timestamp ?? chat.lastUpdated,
              isUnread: chat.isUnreadFor(uid),
              onTap: () => _openChat(
                peerId: chat.peerIdFor(uid),
                name: peer.name,
                photo: peer.photo,
                chatId: chat.id,
              ),
              onDelete: () => _deleteChat(chat.id, peer.name),
              formatTimestamp: _formatTimestamp,
            );
          },
        );
      },
    );
  }
}

/// Profile avatar that shows a placeholder on image load errors (e.g. 412, 404).
Widget _buildProfileAvatar({
  required String? profileImage,
  required String initial,
  double radius = 28,
}) {
  final size = radius * 2;
  final placeholder = CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF8696A0),
    child: Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: radius * 0.7,
      ),
    ),
  );
  if (profileImage == null || profileImage.isEmpty) return placeholder;
  return ClipOval(
    child: Image.network(
      profileImage,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    ),
  );
}

class _ConversationListItem extends StatelessWidget {
  final String peerId;
  final String displayName;
  final String? profileImage;
  final String preview;
  final Timestamp? timestamp;
  final bool isUnread;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String Function(Timestamp?) formatTimestamp;

  _ConversationListItem({
    required this.peerId,
    required this.displayName,
    this.profileImage,
    required this.preview,
    this.timestamp,
    this.isUnread = false,
    required this.onTap,
    this.onDelete,
    String Function(Timestamp?)? formatTimestamp,
  }) : formatTimestamp = formatTimestamp ?? _defaultFormatTimestamp;

  static String _defaultFormatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: darkBackgroundPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => openUserProfile(context, peerId),
              child: _buildProfileAvatar(profileImage: profileImage, initial: initial, radius: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          formatTimestamp(timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isUnread ? 0.9 : 0.6),
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: _chatAccent,
                  shape: BoxShape.circle,
                ),
              ),
            if (onDelete != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.6), size: 22),
                color: darkAppBarBackground,
                onSelected: (value) {
                  if (value == 'delete') onDelete!();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete chat', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Chat screen with real-time messaging between two users
class ChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String? peerImage;
  final String? chatId;
  const ChatScreen({
    Key? key,
    required this.peerUid,
    required this.peerName,
    this.peerImage,
    this.chatId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  late String chatId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _shouldScrollToBottomOnUpdate = false;
  bool _hasScrolledToInitialBottom = false;
  bool _loadingOlder = false;
  bool _streamReady = false;
  final List<ChatMessage> _olderMessages = [];
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  List<ChatMessage> _liveMessages = [];

  @override
  void initState() {
    super.initState();
    chatId = widget.chatId ?? ChatService.chatIdFor(currentUser.uid, widget.peerUid);
    _messageController.addListener(_onMessageTextChanged);
    _scrollController.addListener(_onScroll);
    ChatService.markThreadRead(chatId);
    _messagesSub = ChatService.watchMessages(chatId).listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _liveMessages = messages;
          _streamReady = true;
        });
        ChatService.markThreadRead(chatId);
      },
      onError: (_, __) {
        if (mounted) setState(() => _streamReady = true);
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 48 && !_loadingOlder) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    final all = [..._olderMessages, ..._liveMessages];
    final first = all.isEmpty ? null : all.first.timestamp;
    if (first == null) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await ChatService.loadOlderMessages(chatId: chatId, before: first);
      if (mounted && older.isNotEmpty) {
        setState(() => _olderMessages.insertAll(0, older));
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onMessageTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    if (hasText) {
      ChatService.setTypingDebounced(chatId, currentUser.uid);
    } else {
      ChatService.clearTyping(chatId, currentUser.uid);
    }
  }

  @override
  void dispose() {
    ChatService.clearTyping(chatId, currentUser.uid);
    _messagesSub?.cancel();
    _messageController.removeListener(_onMessageTextChanged);
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _shouldScrollToBottomOnUpdate = true);
    _messageController.clear();
    try {
      await ChatService.sendMessage(
        chatId: chatId,
        peerUid: widget.peerUid,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Failed to send message');
      }
    }
  }

  Future<void> _deleteChatAndPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkAppBarBackground,
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete chat with ${widget.peerName}? This will remove all messages.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ChatService.deleteChat(chatId);

      if (mounted) {
        Fluttertoast.showToast(msg: 'Chat deleted');
        Navigator.pop(context, widget.peerUid);
      }
    } catch (e) {
      print('Error deleting chat: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: 'Failed to delete chat');
      }
    }
  }

  String _formatDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  List<_ChatListEntry> _buildEntries(List<ChatMessage> messages) {
    final entries = <_ChatListEntry>[];
    DateTime? lastDay;
    for (final msg in messages) {
      final ts = msg.timestamp?.toDate();
      if (ts != null) {
        final day = DateTime(ts.year, ts.month, ts.day);
        if (lastDay == null || day != lastDay) {
          entries.add(_ChatListEntry.date(_formatDay(ts)));
          lastDay = day;
        }
      }
      entries.add(_ChatListEntry.message(msg));
    }
    return entries;
  }

  Widget _buildChatShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: 4,
      itemBuilder: (context, index) {
        final isRight = index.isOdd;
        return Shimmer.fromColors(
          baseColor: _chatSurface,
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Align(
            alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              width: MediaQuery.of(context).size.width * (isRight ? 0.62 : 0.52),
              height: 48,
              decoration: BoxDecoration(
                color: _chatSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isRight ? 20 : 6),
                  bottomRight: Radius.circular(isRight ? 6 : 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.senderId == currentUser.uid;
    final isPending = isMe && (msg.isPending || msg.timestamp == null);
    final maxW = MediaQuery.sizeOf(context).width * 0.76;

    if (msg.isStoryReply) {
      return _buildStoryReplyBubble(
        isMe: isMe,
        data: msg.extra,
        text: msg.text,
        pending: isPending,
        time: _formatTime(msg.timestamp),
      );
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMe ? 20 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 20),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isMe ? 52 : 0,
        right: isMe ? 0 : 36,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxW),
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              decoration: BoxDecoration(
                gradient: isMe ? _chatGradient : null,
                color: isMe ? null : _chatSurface,
                borderRadius: borderRadius,
                border: isMe ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? _chatAccent.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isMe ? 1 : 0.92),
                  fontSize: 15,
                  height: 1.42,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.timestamp != null)
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _DeliveryIcon(status: msg.status, pending: isPending),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryReplyBubble({
    required bool isMe,
    required Map<String, dynamic> data,
    required String text,
    required bool pending,
    required String time,
  }) {
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMe ? 20 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 20),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 10, left: isMe ? 40 : 0, right: isMe ? 0 : 28),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxW),
              decoration: BoxDecoration(
                gradient: isMe ? _chatGradient : null,
                color: isMe ? null : _chatSurface,
                borderRadius: borderRadius,
                border: isMe ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: _chatAccent.withValues(alpha: isMe ? 0.25 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories_rounded,
                            size: 14, color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Replied to ${data['storyOwnerName'] ?? 'story'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: data['storyIsImage'] == true
                              ? Image.network(
                                  data['storyContent']?.toString() ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_rounded,
                                    color: Colors.white54,
                                    size: 22,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    ((data['storyPreview'] ?? 'S') as String).isNotEmpty
                                        ? ((data['storyPreview'] ?? 'S') as String)[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['storyPreview']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (time.isNotEmpty || isMe) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.32),
                        fontSize: 10.5,
                      ),
                    ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _DeliveryIcon(status: ChatMessageStatus.sent, pending: pending),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _chatAccent.withValues(alpha: 0.22),
                    _chatAccent.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(color: _chatAccent.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: _chatAccentLight.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Start the conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hey to ${widget.peerName} — your messages are private between you two.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerInitial =
        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?';
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _chatPageBg,
      body: Stack(
        children: [
          const _ChatAmbientBackground(),
          Column(
            children: [
              _PremiumChatHeader(
                peerName: widget.peerName,
                peerUid: widget.peerUid,
                peerImage: widget.peerImage,
                peerInitial: peerInitial,
                chatId: chatId,
                myUid: currentUser.uid,
                onDelete: _deleteChatAndPop,
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final messages = [..._olderMessages, ..._liveMessages];

                    if (!_streamReady) return _buildChatShimmer();
                    if (messages.isEmpty) return _buildEmptyChat();

                    final entries = _buildEntries(messages);

                    if (!_hasScrolledToInitialBottom) {
                      _hasScrolledToInitialBottom = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(const Duration(milliseconds: 80), () {
                          if (mounted && _scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });
                      });
                    } else if (_shouldScrollToBottomOnUpdate) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                          );
                        }
                        if (mounted) setState(() => _shouldScrollToBottomOnUpdate = false);
                      });
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: entries.length + (_loadingOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingOlder && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _chatAccent.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          );
                        }
                        final entryIndex = _loadingOlder ? index - 1 : index;
                        final entry = entries[entryIndex];
                        if (entry.isDate) {
                          return _DateChip(label: entry.dateLabel!);
                        }
                        return _buildMessageBubble(entry.message!);
                      },
                    );
                  },
                ),
              ),
              StreamBuilder<String?>(
                stream: ChatService.watchPeerTyping(chatId, currentUser.uid),
                builder: (context, snap) {
                  if (snap.data == null) return const SizedBox.shrink();
                  return _TypingBar(name: widget.peerName);
                },
              ),
              _PremiumComposer(
                controller: _messageController,
                focusNode: _focusNode,
                hasText: _hasText,
                bottomPad: bottomPad,
                onSend: sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium chat UI components
// ---------------------------------------------------------------------------

class _ChatListEntry {
  final bool isDate;
  final String? dateLabel;
  final ChatMessage? message;

  _ChatListEntry.date(this.dateLabel)
      : isDate = true,
        message = null;

  _ChatListEntry.message(this.message)
      : isDate = false,
        dateLabel = null;
}

class _ChatAmbientBackground extends StatelessWidget {
  const _ChatAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: _chatPageBg),
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_chatAccent.withValues(alpha: 0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_chatAccentDeep.withValues(alpha: 0.08), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumChatHeader extends StatelessWidget {
  final String peerName;
  final String peerUid;
  final String? peerImage;
  final String peerInitial;
  final String chatId;
  final String myUid;
  final VoidCallback onDelete;

  const _PremiumChatHeader({
    required this.peerName,
    required this.peerUid,
    this.peerImage,
    required this.peerInitial,
    required this.chatId,
    required this.myUid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, topPad + 6, 12, 12),
          decoration: BoxDecoration(
            color: _chatPageBg.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              GestureDetector(
                onTap: () => openUserProfile(context, peerUid),
                child: _buildProfileAvatar(
                  profileImage: peerImage,
                  initial: peerInitial,
                  radius: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => openUserProfile(context, peerUid),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      StreamBuilder<String?>(
                        stream: ChatService.watchPeerTyping(chatId, myUid),
                        builder: (context, snap) {
                          final typing = snap.data != null;
                          return Text(
                            typing ? 'typing…' : 'Tap to view profile',
                            style: TextStyle(
                              color: typing
                                  ? _chatAccentLight.withValues(alpha: 0.95)
                                  : Colors.white.withValues(alpha: 0.38),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.85)),
                color: _chatSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Delete chat', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final ChatMessageStatus status;
  final bool pending;

  const _DeliveryIcon({required this.status, required this.pending});

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return Icon(Icons.schedule_rounded,
          size: 13, color: Colors.white.withValues(alpha: 0.35));
    }
    if (status == ChatMessageStatus.read) {
      return Icon(Icons.done_all_rounded,
          size: 14, color: _chatAccentLight.withValues(alpha: 0.95));
    }
    return Icon(Icons.check_rounded,
        size: 13, color: Colors.white.withValues(alpha: 0.4));
  }
}

class _TypingBar extends StatefulWidget {
  final String name;

  const _TypingBar({required this.name});

  @override
  State<_TypingBar> createState() => _TypingBarState();
}

class _TypingBarState extends State<_TypingBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _chatSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = (_controller.value + i * 0.2) % 1.0;
                    final y = t < 0.5 ? t * 2 : (1 - t) * 2;
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      child: Transform.translate(
                        offset: Offset(0, -3 * y),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _chatAccent.withValues(alpha: 0.5 + y * 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final double bottomPad;
  final VoidCallback onSend;

  const _PremiumComposer({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.bottomPad,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPad),
          decoration: BoxDecoration(
            color: _chatPageBg.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: _chatSurface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: hasText
                          ? _chatAccent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.35,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (hasText) onSend();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedScale(
                scale: hasText ? 1 : 0.88,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: hasText ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: hasText ? _chatGradient : null,
                      color: hasText ? null : _chatSurface,
                      shape: BoxShape.circle,
                      border: hasText
                          ? null
                          : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color: _chatAccent.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: hasText
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
