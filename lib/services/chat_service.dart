import 'dart:async';

import 'package:beatjerky/models/chat_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:beatjerky/utils/name_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int defaultMessagePageSize = 50;
  static const Duration typingFreshness = Duration(seconds: 5);

  static String? get currentUid => _auth.currentUser?.uid;

  static String chatIdFor(String uidA, String uidB) {
    final uids = [uidA, uidB]..sort();
    return '${uids[0]}_${uids[1]}';
  }

  static DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _firestore.collection('chats').doc(chatId);

  static CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatRef(chatId).collection('messages');

  /// Real-time inbox ordered by latest activity.
  static Stream<List<ChatSummary>> watchInbox({String? uid}) {
    final userId = uid ?? currentUid;
    if (userId == null) return Stream.value(const []);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatSummary.fromDoc).toList())
        .handleError((Object error, StackTrace stackTrace) {
          logDebugException('ChatService.watchInbox', error, stackTrace: stackTrace);
        });
  }

  /// Latest messages in a thread (real-time).
  static Stream<List<ChatMessage>> watchMessages(
    String chatId, {
    int limit = defaultMessagePageSize,
  }) {
    return _messagesRef(chatId)
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList())
        .handleError((Object error, StackTrace stackTrace) {
          logDebugException('ChatService.watchMessages', error, stackTrace: stackTrace);
        });
  }

  /// Typing map on chat doc: `{ uid: Timestamp }`.
  static Stream<String?> watchPeerTyping(String chatId, String myUid) {
    return _chatRef(chatId).snapshots().map((doc) {
      final typing = doc.data()?['typing'] as Map<String, dynamic>?;
      if (typing == null) return null;
      final now = DateTime.now();
      for (final entry in typing.entries) {
        if (entry.key == myUid) continue;
        final ts = entry.value;
        if (ts is! Timestamp) continue;
        if (now.difference(ts.toDate()) <= typingFreshness) {
          return entry.key;
        }
      }
      return null;
    });
  }

  static Timer? _typingDebounce;
  static void setTypingDebounced(String chatId, String uid) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 350), () {
      _chatRef(chatId).set(
        {
          'typing': {uid: FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> clearTyping(String chatId, String uid) async {
    _typingDebounce?.cancel();
    try {
      await _chatRef(chatId).update({'typing.$uid': FieldValue.delete()});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _userSnapshot(String uid) async {
    final doc = await _firestore.collection('usersData').doc(uid).get();
    return doc.data() ?? {};
  }

  static ChatParticipantInfo _participantFromUserData(Map<String, dynamic> data) {
    final name = NameUtils.getDisplayNameSafe(
      data['firstName']?.toString(),
      data['secondName']?.toString(),
      fallback: data['displayName']?.toString() ??
          data['name']?.toString() ??
          data['email']?.toString() ??
          'User',
    );
    final photo = data['photoURL']?.toString() ??
        data['profileImage']?.toString();
    return ChatParticipantInfo(name: name, photo: photo);
  }

  /// Ensures chat doc exists; returns chat id.
  static Future<String> openOrCreateChat({
    required String peerUid,
    String? peerName,
    String? peerPhoto,
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final chatId = chatIdFor(myUid, peerUid);
    final chatDoc = await _chatRef(chatId).get();
    if (chatDoc.exists) {
      final participants = chatDoc.data()?['participants'];
      if (participants is List && participants.contains(myUid)) {
        return chatId;
      }
      // Legacy parent doc without participants — fall through and upgrade via set().
    }

    final myData = await _userSnapshot(myUid);
    final peerData = peerUid == myUid
        ? <String, dynamic>{}
        : await _userSnapshot(peerUid);

    final myInfo = _participantFromUserData(myData);
    final peerInfo = peerName != null
        ? ChatParticipantInfo(name: peerName, photo: peerPhoto)
        : _participantFromUserData(peerData);

    await _chatRef(chatId).set({
      'participants': [myUid, peerUid]..sort(),
      'participantInfo': {
        myUid: myInfo.toMap(),
        peerUid: peerInfo.toMap(),
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return chatId;
  }

  /// Find existing chat between two users (if any).
  static Future<String?> findExistingChatId(String peerUid) async {
    final myUid = currentUid;
    if (myUid == null) return null;
    final chatId = chatIdFor(myUid, peerUid);
    final doc = await _chatRef(chatId).get();
    if (doc.exists) return chatId;
    return null;
  }

  static Future<void> sendMessage({
    required String chatId,
    required String peerUid,
    required String text,
    Map<String, dynamic>? extraFields,
  }) async {
    final myUid = currentUid;
    if (myUid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await openOrCreateChat(peerUid: peerUid);

    final msgRef = _messagesRef(chatId).doc();
    final payload = <String, dynamic>{
      'text': trimmed,
      'senderId': myUid,
      'receiverId': peerUid,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'read': false,
      if (extraFields != null) ...extraFields,
    };

    await msgRef.set(payload);

    await _chatRef(chatId).set(
      {
        'participants': [myUid, peerUid]..sort(),
        'lastMessage': {
          'text': trimmed,
          'senderId': myUid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await clearTyping(chatId, myUid);
  }

  static Future<List<ChatMessage>> loadOlderMessages({
    required String chatId,
    required Timestamp before,
    int limit = defaultMessagePageSize,
  }) async {
    final snap = await _messagesRef(chatId)
        .orderBy('timestamp', descending: true)
        .where('timestamp', isLessThan: before)
        .limit(limit)
        .get();
    final list = snap.docs.map(ChatMessage.fromDoc).toList();
    return list.reversed.toList();
  }

  static Future<void> markThreadRead(String chatId) async {
    final myUid = currentUid;
    if (myUid == null) return;

    try {
      final unread = await _messagesRef(chatId)
          .where('receiverId', isEqualTo: myUid)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _firestore.batch();
      var changed = false;
      for (final doc in unread.docs) {
        final data = doc.data();
        final status = data['status']?.toString();
        final read = data['read'] == true;
        if (status != 'read' && !read) {
          batch.update(doc.reference, {'status': 'read', 'read': true});
          changed = true;
        }
      }
      if (changed) {
        await batch.commit();
        final chatSnap = await _chatRef(chatId).get();
        final last = chatSnap.data()?['lastMessage'] as Map<String, dynamic>?;
        if (last != null && last['senderId'] != myUid) {
          await _chatRef(chatId).update({
            'lastMessage.status': 'read',
          });
        }
      }
    } catch (e, st) {
      logDebugException('ChatService.markThreadRead', e, stackTrace: st);
    }
  }

  static Future<void> deleteChat(String chatId) async {
    final messages = await _messagesRef(chatId).get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_chatRef(chatId));
    await batch.commit();
  }

  /// Search users to start a new conversation (excludes self).
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final myUid = currentUid;
    if (myUid == null || query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final snap = await _firestore.collection('usersData').limit(200).get();
    return snap.docs
        .where((d) => d.id != myUid)
        .map((d) => {'id': d.id, ...d.data()})
        .where((user) {
          final name = NameUtils.getDisplayNameSafe(
            user['firstName']?.toString(),
            user['secondName']?.toString(),
            fallback: user['email']?.toString() ?? '',
          ).toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(q) || email.contains(q);
        })
        .take(30)
        .toList();
  }
}
