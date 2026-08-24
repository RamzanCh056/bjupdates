import 'dart:convert';

import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/model/music_coach_message_model.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AiMusicCoachService {
  AiMusicCoachService._();

  static const int _historyLimit = 24;
  static const String _systemPrompt =
      'You are Beat Jerky\'s AI Music Coach. Coach creators on beat making, arrangement, mixing, mastering, songwriting, sound design, workflow, and career growth. Be practical, encouraging, and specific. Use short paragraphs and numbered steps when helpful. Keep answers focused and mobile-friendly.';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> _messagesCollection(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('music_coach_chats');
  }

  static Stream<List<MusicCoachMessage>> watchMessages({int limit = 200}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(const []);
    }

    return _messagesCollection(userId)
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MusicCoachMessage.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((Object error, StackTrace stackTrace) {
          logDebugException(
            'AiMusicCoachService.watchMessages',
            error,
            stackTrace: stackTrace,
          );
        });
  }

  static Future<void> saveMessage({
    required String text,
    required bool isUser,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Please sign in to save coach chats.');
    }

    try {
      await _messagesCollection(userId).add(
        MusicCoachMessage(
          id: '',
          text: text.trim(),
          isUser: isUser,
        ).toMap(),
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiMusicCoachService.saveMessage',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<String> requestCoachReply({
    required String userMessage,
    required List<MusicCoachMessage> history,
  }) async {
    final trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    if (!OpenAiConfig.isConfigured) {
      throw StateError(OpenAiConfig.missingApiKeyMessage);
    }

    try {
      final response = await http.post(
        Uri.parse(OpenAiConfig.chatCompletionsUrl),
        headers: OpenAiConfig.jsonAuthHeaders,
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': 0.75,
          'max_tokens': 700,
          'messages': _buildChatMessages(
            history: history,
            userMessage: trimmedMessage,
          ),
        }),
      );

      if (response.statusCode != 200) {
        throw OpenAiConfig.requestException(response);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw Exception('Music coach returned an empty response.');
      }

      return content.trim();
    } catch (error, stackTrace) {
      logDebugException(
        'AiMusicCoachService.requestCoachReply',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> clearHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Please sign in to clear coach chats.');
    }

    try {
      final snapshot = await _messagesCollection(userId).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (error, stackTrace) {
      logDebugException(
        'AiMusicCoachService.clearHistory',
        error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static List<Map<String, String>> _buildChatMessages({
    required List<MusicCoachMessage> history,
    required String userMessage,
  }) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    final recentHistory = history.length > _historyLimit
        ? history.sublist(history.length - _historyLimit)
        : history;

    for (final message in recentHistory) {
      final text = message.text.trim();
      if (text.isEmpty) {
        continue;
      }

      messages.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': text,
      });
    }

    final lastMessage = messages.isNotEmpty ? messages.last : null;
    if (lastMessage == null ||
        lastMessage['role'] != 'user' ||
        lastMessage['content'] != userMessage) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    return messages;
  }
}
