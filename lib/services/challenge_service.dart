import 'dart:io';

import 'package:beatjerky/models/challenge_models.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:beatjerky/utils/name_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

class ChallengeService {
  ChallengeService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _collection = 'challenges';

  static String? get currentUid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection(_collection);

  static DocumentReference<Map<String, dynamic>> _challengeRef(String id) =>
      _challenges.doc(id);

  static CollectionReference<Map<String, dynamic>> _entriesRef(String id) =>
      _challengeRef(id).collection('entries');

  static Future<Map<String, dynamic>> _userSnapshot(String uid) async {
    final doc = await _firestore.collection('usersData').doc(uid).get();
    return doc.data() ?? {};
  }

  static Future<({String name, String? photo})> _creatorProfile(
    String uid,
  ) async {
    final data = await _userSnapshot(uid);
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
    return (name: name, photo: photo);
  }

  static String _audioContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  static String _formatAudioDuration(Duration? d) {
    if (d == null || d.inMilliseconds <= 0) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Upload a local beat/hook file to Storage and return beat metadata.
  static Future<ChallengeBeat> uploadBeatFile({
    required String localPath,
    required String fileName,
    int? sizeBytes,
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('Could not read the selected file');
    }

    var duration = '';
    AudioPlayer? probe;
    try {
      probe = AudioPlayer();
      final d = await probe.setFilePath(localPath);
      duration = _formatAudioDuration(d);
    } catch (error, stackTrace) {
      logDebugException(
        'ChallengeService.uploadBeatFile.probe',
        error,
        stackTrace: stackTrace,
      );
    } finally {
      await probe?.dispose();
    }

    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath =
        'challenges/beats/$myUid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.putFile(
      file,
      SettableMetadata(contentType: _audioContentType(fileName)),
    );
    final url = await ref.getDownloadURL();

    final dot = fileName.lastIndexOf('.');
    final title = dot > 0 ? fileName.substring(0, dot) : fileName;

    return ChallengeBeat(
      title: title.isEmpty ? 'Challenge Beat' : title,
      fileName: fileName,
      duration: duration,
      audioUrl: url,
      storagePath: storagePath,
      sizeLabel: sizeBytes != null && sizeBytes > 0
          ? _formatFileSize(sizeBytes)
          : null,
    );
  }

  /// Create + launch a challenge. Returns the new challenge.
  static Future<Challenge> createChallenge({
    required String title,
    required List<String> hashtags,
    required int deadlineDays,
    String? prizeText,
    required ChallengeBeat beat,
    String description =
        'Record your hottest hook over this beat. Top entry wins.',
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final trimmed = title.trim();
    if (trimmed.isEmpty) throw StateError('Add a challenge title');
    if (hashtags.isEmpty) throw StateError('Pick at least one hashtag');
    if (!beat.hasAudio) throw StateError('Pick your beat / hook MP3 first');

    final profile = await _creatorProfile(myUid);
    final endsAt = DateTime.now().add(Duration(days: deadlineDays));
    final ref = _challenges.doc();

    final payload = <String, dynamic>{
      'title': trimmed,
      'description': description,
      'hashtags': hashtags,
      'creatorId': myUid,
      'creatorName': profile.name,
      if (profile.photo != null) 'creatorPhoto': profile.photo,
      'status': 'active',
      'isOfficial': false,
      'isFeatured': false,
      'deadlineDays': deadlineDays,
      'endsAt': Timestamp.fromDate(endsAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'beat': beat.toMap(),
      if (prizeText != null && prizeText.trim().isNotEmpty)
        'prizeText': prizeText.trim(),
      'entryCount': 0,
      'viewCount': 0,
      'participantIds': <String>[],
      'scoring': {'views': 0.4, 'likes': 0.4, 'shares': 0.2},
    };

    await ref.set(payload);
    final snap = await ref.get();
    return Challenge.fromDoc(snap);
  }

  static Stream<List<Challenge>> watchFeed({int limit = 40}) {
    return _challenges
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Challenge.fromDoc).toList();
          list.sort((a, b) {
            // Featured first, then newest
            if (a.isFeatured != b.isFeatured) {
              return a.isFeatured ? -1 : 1;
            }
            final aT = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bT = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bT.compareTo(aT);
          });
          return list;
        })
        .handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'ChallengeService.watchFeed',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Stream<Challenge?> watchChallenge(String challengeId) {
    return _challengeRef(challengeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Challenge.fromDoc(doc);
    }).handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'ChallengeService.watchChallenge',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Future<Challenge?> getChallenge(String challengeId) async {
    final snap = await _challengeRef(challengeId).get();
    if (!snap.exists) return null;
    return Challenge.fromDoc(snap);
  }

  /// Mark user as joined (Accept / Join). Creators manage — they don't Accept.
  static Future<void> joinChallenge(String challengeId) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');

    final snap = await _challengeRef(challengeId).get();
    if (!snap.exists) throw StateError('Challenge not found');
    final challenge = Challenge.fromDoc(snap);
    if (challenge.isEnded) throw StateError('This challenge has ended');
    if (challenge.isOwnedBy(myUid)) {
      throw StateError(
        'This is your challenge — open View entries to see who joined.',
      );
    }

    await _challengeRef(challengeId).update({
      'participantIds': FieldValue.arrayUnion([myUid]),
      'viewCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Submit (or replace) the current user's entry.
  static Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required int durationSec,
    String? audioUrl,
  }) async {
    final myUid = currentUid;
    if (myUid == null) throw StateError('Not signed in');
    if (durationSec < 1) throw StateError('Record something first');

    final challengeSnap = await _challengeRef(challengeId).get();
    if (!challengeSnap.exists) throw StateError('Challenge not found');
    final challenge = Challenge.fromDoc(challengeSnap);
    if (challenge.isEnded) throw StateError('This challenge has ended');
    if (challenge.isOwnedBy(myUid)) {
      throw StateError(
        'Creators manage challenges — others Accept and submit entries.',
      );
    }

    final profile = await _creatorProfile(myUid);
    final entryRef = _entriesRef(challengeId).doc(myUid);
    final existing = await entryRef.get();
    final isNew = !existing.exists;

    // Seed mild engagement so leaderboard isn't all zeros for demos
    final views = isNew ? 12 : (existing.data()?['views'] as num?)?.toInt() ?? 12;
    final likes = isNew ? 4 : (existing.data()?['likes'] as num?)?.toInt() ?? 4;
    final shares = isNew ? 1 : (existing.data()?['shares'] as num?)?.toInt() ?? 1;
    final score = ChallengeEntry.computeScore(
      views: views,
      likes: likes,
      shares: shares,
    );

    final payload = <String, dynamic>{
      'userId': myUid,
      'userName': profile.name,
      if (profile.photo != null) 'userPhoto': profile.photo,
      'durationSec': durationSec,
      'status': 'ready',
      'views': views,
      'likes': likes,
      'shares': shares,
      'score': score,
      'updatedAt': FieldValue.serverTimestamp(),
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };

    await entryRef.set(payload, SetOptions(merge: true));

    await _challengeRef(challengeId).update({
      'participantIds': FieldValue.arrayUnion([myUid]),
      if (isNew) 'entryCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final saved = await entryRef.get();
    return ChallengeEntry.fromDoc(saved);
  }

  static Stream<List<ChallengeEntry>> watchLeaderboard(
    String challengeId, {
    int limit = 50,
  }) {
    return _entriesRef(challengeId)
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ChallengeEntry.fromDoc).toList())
        .handleError((Object error, StackTrace stackTrace) {
      logDebugException(
        'ChallengeService.watchLeaderboard',
        error,
        stackTrace: stackTrace,
      );
    });
  }

  static Future<ChallengeEntry?> getMyEntry(String challengeId) async {
    final myUid = currentUid;
    if (myUid == null) return null;
    final snap = await _entriesRef(challengeId).doc(myUid).get();
    if (!snap.exists) return null;
    return ChallengeEntry.fromDoc(snap);
  }
}
