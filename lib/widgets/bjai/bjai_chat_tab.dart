import 'package:beatjerky/services/bjai_service.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/widgets/bjai/bjai_ui.dart';
import 'package:flutter/material.dart';

class BjaiChatTab extends StatefulWidget {
  final String? initialPrompt;

  const BjaiChatTab({super.key, this.initialPrompt});

  @override
  State<BjaiChatTab> createState() => _BjaiChatTabState();
}

class _BjaiChatTabState extends State<BjaiChatTab> {
  final BjaiService _bjai = BjaiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatBubble> _messages = [];
  bool _isTyping = false;

  static const _suggestions = [
    ('Write lyrics for a trap beat', Icons.lyrics_outlined),
    ('Give me a song title idea', Icons.title_outlined),
    ('How do I promote my music?', Icons.trending_up_rounded),
    ('Help me write a hook', Icons.music_note_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendMessage(prompt));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(_ChatBubble(text: trimmed, isUser: true));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => BjaiChatMessage(isUser: m.isUser, text: m.text))
          .toList();

      final reply = await _bjai.sendChat(history);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatBubble(text: reply, isUser: false));
        _isTyping = false;
      });
    } on BjaiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatBubble(text: e.message, isUser: false, isError: true),
        );
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatBubble(
            text: 'Something went wrong, try again.',
            isUser: false,
            isError: true,
          ),
        );
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty = _messages.isEmpty && !_isTyping;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottomPad),
            children: [
              if (showEmpty) _buildEmptyState(),
              ..._messages.map(_buildBubble),
              if (_isTyping) const _TypingIndicator(),
            ],
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: bjaiGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bjaiPurple.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your music co-pilot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lyrics, hooks, promo tips & production advice',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions.map((s) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendMessage(s.$1),
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: bjaiSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s.$2,
                          size: 14,
                          color: purpleAccent.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.$1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatBubble message) {
    final isUser = message.isUser;
    final maxW = MediaQuery.sizeOf(context).width * 0.78;

    if (message.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: Colors.red[300]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.text,
                  style: TextStyle(color: Colors.red[200], fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: bjaiGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: bjaiPurple.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 36),
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
        decoration: BoxDecoration(
          color: bjaiSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: bjaiGradient,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'BJ AI',
                  style: TextStyle(
                    color: purpleAccent.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            bjaiFormattedText(message.text),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 14, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: bjaiBg.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bjaiSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Message BJ AI…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: bjaiGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: bjaiPurple.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isTyping ? null : () => _sendMessage(_controller.text),
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: _isTyping
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bjaiSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = (_controller.value * 3 - index).clamp(0.0, 1.0);
                return Container(
                  margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: bjaiPurple.withValues(alpha: 0.25 + t * 0.75),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
