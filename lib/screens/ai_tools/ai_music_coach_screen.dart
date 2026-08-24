import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/model/music_coach_message_model.dart';
import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_music_coach_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AiMusicCoachScreen extends StatefulWidget {
  const AiMusicCoachScreen({super.key});

  @override
  State<AiMusicCoachScreen> createState() => _AiMusicCoachScreenState();
}

class _AiMusicCoachScreenState extends State<AiMusicCoachScreen> {
  static const List<String> _quickPrompts = [
    'Analyze my beat',
    'Mixing tips',
    'Songwriting help',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isClearing = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveFirstName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first;
      if (localPart.isNotEmpty) {
        return localPart[0].toUpperCase() + localPart.substring(1);
      }
    }

    return 'there';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_isTyping || _isClearing) return;

    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to chat with your music coach.', isError: true);
      return;
    }
    if (!OpenAiConfig.isConfigured) {
      AppToast.show(OpenAiConfig.missingApiKeyMessage, isError: true);
      return;
    }

    setState(() => _isTyping = true);
    _messageController.clear();
    _scrollToBottom();

    try {
      final historyBefore = await AiMusicCoachService.watchMessages().first;
      final pendingUserMessage = MusicCoachMessage(
        id: '',
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );

      await AiMusicCoachService.saveMessage(text: text, isUser: true);
      final reply = await AiMusicCoachService.requestCoachReply(
        userMessage: text,
        history: [...historyBefore, pendingUserMessage],
      );
      await AiMusicCoachService.saveMessage(text: reply, isUser: false);
      if (!mounted) return;
      _scrollToBottom();
    } catch (error, stackTrace) {
      logDebugException('AiMusicCoachScreen.sendMessage', error, stackTrace: stackTrace);
      if (mounted) {
        AppToast.show(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    if (_isTyping || _isClearing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.show('Please sign in to clear coach chats.', isError: true);
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiToolsTheme.cardElevated,
        title: const Text(
          'Clear coach chat?',
          style: TextStyle(color: AiToolsTheme.textPrimary),
        ),
        content: const Text(
          'This removes your saved music coach conversation from your account.',
          style: TextStyle(color: AiToolsTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    setState(() => _isClearing = true);
    try {
      await AiMusicCoachService.clearHistory();
      if (!mounted) return;
      AppToast.show('Coach chat cleared.');
    } catch (error, stackTrace) {
      logDebugException('AiMusicCoachScreen.clearHistory', error, stackTrace: stackTrace);
      if (mounted) {
        AppToast.show(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiToolsTheme.background,
      body: Stack(
        children: [
          const AiToolsAmbientBackground(),
          SafeArea(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;

                return Column(
                  children: [
                    AiToolsTopBar(
                      title: 'AI Music Coach',
                      trailing: IconButton(
                        onPressed: _isClearing ? null : _clearHistory,
                        icon: _isClearing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AiToolsTheme.textSecondary,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                color: AiToolsTheme.textSecondary,
                                size: 20,
                              ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<MusicCoachMessage>>(
                        stream: AiMusicCoachService.watchMessages(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AiToolsTheme.purple,
                                strokeWidth: 2,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            logDebugException(
                              'AiMusicCoachScreen.messagesStream',
                              snapshot.error!,
                              stackTrace: snapshot.stackTrace,
                            );
                            return Center(
                              child: Padding(
                                padding: AiToolsTheme.screenPadding,
                                child: Text(
                                  'Could not load coach chats. ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AiToolsTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }

                          final messages = snapshot.data ?? const <MusicCoachMessage>[];
                          final itemCount = messages.length +
                              (messages.isEmpty ? 1 : 0) +
                              (_isTyping ? 1 : 0);

                          return ListView.builder(
                            controller: _scrollController,
                            padding: AiToolsTheme.screenPadding,
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (messages.isEmpty && index == 0) {
                                return _CoachMessageBubble(
                                  text:
                                      "Hi ${_resolveFirstName(user)}! I'm your AI music coach. Ask me about beat making, mixing, songwriting, or your next creative move.",
                                  isUser: false,
                                );
                              }

                              final messageIndex =
                                  messages.isEmpty ? index - 1 : index;
                              if (messageIndex >= messages.length) {
                                return const _CoachTypingBubble();
                              }

                              final message = messages[messageIndex];
                              return _CoachMessageBubble(
                                text: message.text,
                                isUser: message.isUser,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _quickPrompts.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final prompt = _quickPrompts[index];
                                  return _QuickPromptChip(
                                    label: prompt,
                                    onTap: _isTyping ? null : () => _sendMessage(prompt),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AiToolsGlassCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    radius: AiToolsTheme.radiusLg,
                                    child: TextField(
                                      controller: _messageController,
                                      enabled: !_isTyping && !_isClearing,
                                      style: const TextStyle(
                                        color: AiToolsTheme.textPrimary,
                                        fontSize: 15,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Ask anything...',
                                        hintStyle: TextStyle(
                                          color: AiToolsTheme.textSecondary,
                                          fontSize: 15,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _isTyping || _isClearing
                                      ? null
                                      : () => _sendMessage(),
                                  child: Opacity(
                                    opacity: _isTyping || _isClearing ? 0.6 : 1,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: AiToolsTheme.primaryGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AiToolsTheme.purple
                                                .withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _isTyping
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.send_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _CoachMessageBubble({
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? AiToolsTheme.purple : AiToolsTheme.card,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 18),
              ),
              border: Border.all(
                color: isUser
                    ? AiToolsTheme.purple.withValues(alpha: 0.8)
                    : AiToolsTheme.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                text,
                style: const TextStyle(
                  color: AiToolsTheme.textPrimary,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachTypingBubble extends StatelessWidget {
  const _CoachTypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _CoachMessageBubble(
          text: 'Coach is thinking...',
          isUser: false,
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickPromptChip({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AiToolsTheme.cardElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AiToolsTheme.purple.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: AiToolsTheme.purple.withValues(alpha: 0.12),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AiToolsTheme.purple,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
