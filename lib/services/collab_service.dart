import 'dart:math';

import 'package:beatjerky/models/collab_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:beatjerky/utils/name_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollabService {
  CollabService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Random _random = Random();

  static const _collection = 'collabRooms';
  static const int maxParticipants = 2;

  static String? get currentUid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection(_collection);

  static DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _rooms.doc(roomId);

  static CollectionReference<Map<String, dynamic>> _messagesRef(String roomId) =>
      _roomRef(roomId).collection('messages');

  static Future<Map<String, dynamic>> _userSnapshot(String uid) async {
    final doc = await _firestore.collection('usersData').doc(uid).get();
    return doc.data() ?? {};
  }

  static CollabParticipantInfo _participantFromUserData(
    Map<String, dynamic> data, {
    required String role,
  }) {
    final name = NameUtils.getDisplayNameSafe(
      data['firstName']?.toString(),
      data['secondName']?.toString(),
      fallback: data['displayName']?.toString() ??
          data['name']?.toString() ??
          data['email']?.toString() ??
          'User',
    );
    final photo =
        data['photoURL']?.toString() ?? data['profileImage']?.toString();
    return CollabParticipantInfo(name: name, photo: photo, role: role);
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  static String normalizeCode(String raw) {
    var value = raw.trim().toUpperCase();
    if (value.contains('/')) {
      value = value.split('/').last;
    }
    value = value.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return value;
  }

  /// Creates a new prep room and returns the room code (also used as doc id).
  static Future<CollabRoom> createRoom({
    CollabBackingTrack? backingTrack,
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final myData = await _userSnapshot(myUid);
    final hostInfo = _participantFromUserData(
      myData,
      role: 'Hook / Chorus',
    );

    String code = _generateCode();
    for (var attempt = 0; attempt < 8; attempt++) {
      final existing = await _roomRef(code).get();
      if (!existing.exists) break;
      code = _generateCode();
    }

    final track = backingTrack ?? const CollabBackingTrack();
    final payload = <String, dynamic>{
      'code': code,
      'hostId': myUid,
      'status': 'waiting',
      'phase': 1,
      'participants': [myUid],
      'participantInfo': {myUid: hostInfo.toMap()},
      'backingTrack': track.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _roomRef(code).set(payload);
    await _sendSystemMessage(
      code,
      text: '${hostInfo.name} created the room. Share code $code to invite.',
      senderId: myUid,
      senderName: hostInfo.name,
    );

    final created = await _roomRef(code).get();
    return CollabRoom.fromDoc(created);
  }

  /// Join an existing room by code. Returns the room.
  static Future<CollabRoom> joinRoom(String rawCode) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final code = normalizeCode(rawCode);
    if (code.length < 3) {
      throw StateError('Enter a valid room code');
    }

    final ref = _roomRef(code);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Room $code not found');
    }

    final room = CollabRoom.fromDoc(snap);
    if (room.participants.contains(myUid)) {
      return room;
    }
    if (room.isFull) {
      throw StateError('Room is full');
    }
    if (room.status == 'closed') {
      throw StateError('Room is closed');
    }

    final myData = await _userSnapshot(myUid);
    final guestInfo = _participantFromUserData(
      myData,
      role: 'Verse / Rap',
    );

    await ref.update({
      'participants': FieldValue.arrayUnion([myUid]),
      'participantInfo.$myUid': guestInfo.toMap(),
      'status': 'prep',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _sendSystemMessage(
      code,
      text: '${guestInfo.name} joined the room 🎤',
      senderId: myUid,
      senderName: guestInfo.name,
    );

    final updated = await ref.get();
    return CollabRoom.fromDoc(updated);
  }

  static Stream<CollabRoom?> watchRoom(String roomId) {
    return _roomRef(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CollabRoom.fromDoc(doc);
    }).handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'CollabService.watchRoom',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Stream<List<CollabRoom>> watchMyRooms({String? uid}) {
    final userId = uid ?? currentUid;
    if (userId == null) return Stream.value(const []);

    return _rooms
        .where('participants', arrayContains: userId)
        .limit(30)
        .snapshots()
        .map((snap) {
          final rooms = snap.docs.map(CollabRoom.fromDoc).toList();
          rooms.sort((a, b) {
            final aT = a.updatedAt?.millisecondsSinceEpoch ??
                a.createdAt?.millisecondsSinceEpoch ??
                0;
            final bT = b.updatedAt?.millisecondsSinceEpoch ??
                b.createdAt?.millisecondsSinceEpoch ??
                0;
            return bT.compareTo(aT);
          });
          return rooms;
        })
        .handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'CollabService.watchMyRooms',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Stream<List<CollabMessage>> watchMessages(
    String roomId, {
    int limit = 80,
  }) {
    return _messagesRef(roomId)
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) => snap.docs.map(CollabMessage.fromDoc).toList())
        .handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'CollabService.watchMessages',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Future<void> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final roomSnap = await _roomRef(roomId).get();
    if (!roomSnap.exists) throw StateError('Room not found');
    final room = CollabRoom.fromDoc(roomSnap);
    if (!room.participants.contains(myUid)) {
      throw StateError('You are not in this room');
    }

    final name = room.infoFor(myUid)?.name ?? 'User';

    await _messagesRef(roomId).add({
      'text': trimmed,
      'senderId': myUid,
      'senderName': name,
      'type': 'chat',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _roomRef(roomId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _sendSystemMessage(
    String roomId, {
    required String text,
    required String senderId,
    required String senderName,
  }) async {
    await _messagesRef(roomId).add({
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Host or any participant can advance to recording phase.
  static Future<void> startRecordingPhase(String roomId) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final snap = await _roomRef(roomId).get();
    if (!snap.exists) throw StateError('Room not found');
    final room = CollabRoom.fromDoc(snap);
    if (!room.participants.contains(myUid)) {
      throw StateError('You are not in this room');
    }

    await _roomRef(roomId).update({
      'phase': 2,
      'status': 'recording',
      'updatedAt': FieldValue.serverTimestamp(),
      'recordingStartedAt': FieldValue.serverTimestamp(),
    });

    final name = room.infoFor(myUid)?.name ?? 'Someone';
    await _sendSystemMessage(
      roomId,
      text: '$name started the recording phase 🎙️',
      senderId: myUid,
      senderName: name,
    );
  }

  static Future<void> markRecordingDone(String roomId) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    await _roomRef(roomId).update({
      'participantInfo.$myUid.recordingStatus': 'done',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
