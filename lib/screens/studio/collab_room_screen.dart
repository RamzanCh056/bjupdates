import 'dart:async';

import 'package:beatjerky/models/collab_models.dart';
import 'package:beatjerky/screens/studio/collab_recording_screen.dart';
import 'package:beatjerky/screens/studio/collab_widgets.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/collab_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollabRoomScreen extends StatefulWidget {
  final String roomId;

  const CollabRoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<CollabRoomScreen> createState() => _CollabRoomScreenState();
}

class _CollabRoomScreenState extends State<CollabRoomScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isPlaying = false;
  bool _startingRecording = false;
  bool _sending = false;
  bool _navigatedToRecording = false;
  StreamSubscription<CollabRoom?>? _roomSub;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _roomSub = CollabService.watchRoom(widget.roomId).listen((room) {
      if (!mounted || room == null) return;
      if (room.isRecording && !_navigatedToRecording) {
        _navigatedToRecording = true;
        openCollabRecording(context, roomId: room.id, replace: true);
      }
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await CollabService.sendMessage(roomId: widget.roomId, text: text);
      _chatController.clear();
      if (_chatScrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    if (_startingRecording) return;
    setState(() => _startingRecording = true);
    try {
      await CollabService.startRecordingPhase(widget.roomId);
      // Navigation happens via room stream when phase flips to 2.
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
      if (mounted) setState(() => _startingRecording = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    AppToast.show('Room code $code copied!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: StreamBuilder<CollabRoom?>(
            stream: CollabService.watchRoom(widget.roomId),
            builder: (context, roomSnap) {
              if (roomSnap.connectionState == ConnectionState.waiting &&
                  !roomSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: recntsColor),
                );
              }

              final room = roomSnap.data;
              if (room == null) {
                return _RoomMissing(
                  onBack: () => Navigator.maybePop(context),
                );
              }

              final myUid = _myUid;
              final peerId = myUid == null ? null : room.peerIdFor(myUid);
              final me = myUid == null ? null : room.infoFor(myUid);
              final peer = peerId == null ? null : room.infoFor(peerId);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                    child: _RoomHeader(
                      roomCode: room.code,
                      onCopyCode: () => _copyCode(room.code),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: CollabPhaseIndicator(
                      currentPhase: 1,
                      label: 'Prep',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ParticipantCard(
                                  initial: me?.initial ?? 'Y',
                                  name: 'You',
                                  role: me?.role ?? 'Hook / Chorus',
                                  isActive: true,
                                  accentColor: recntsColor,
                                  photoUrl: me?.photo,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: peer == null
                                    ? _WaitingGuestCard(
                                        roomCode: room.code,
                                        onShare: () => _copyCode(room.code),
                                      )
                                    : _ParticipantCard(
                                        initial: peer.initial,
                                        name: peer.name,
                                        role: peer.role,
                                        accentColor: indigoColor,
                                        photoUrl: peer.photo,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _SectionLabel(text: 'BACKING TRACK'),
                          const SizedBox(height: 8),
                          _BackingTrackCard(
                            track: room.backingTrack,
                            isPlaying: _isPlaying,
                            onTogglePlay: () {
                              setState(() => _isPlaying = !_isPlaying);
                              AppToast.show(
                                _isPlaying
                                    ? 'Playing backing track (preview)'
                                    : 'Paused',
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<List<CollabMessage>>(
                            stream: CollabService.watchMessages(widget.roomId),
                            builder: (context, msgSnap) {
                              final messages =
                                  msgSnap.data ?? const <CollabMessage>[];
                              return _CollabChatSection(
                                messages: messages,
                                myUid: myUid,
                                scrollController: _chatScrollController,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ChatInputBar(
                    controller: _chatController,
                    isSending: _sending,
                    onSend: _sendMessage,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: _StartRecordingButton(
                      isLoading: _startingRecording,
                      enabled: room.participants.length >= 1,
                      onTap: _startRecording,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomMissing extends StatelessWidget {
  final VoidCallback onBack;

  const _RoomMissing({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room not found',
              style: TextStyle(
                color: StudioFlowTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String roomCode;
  final VoidCallback onCopyCode;

  const _RoomHeader({
    required this.roomCode,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudioBackButton(onPressed: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onCopyCode,
            child: Text(
              'Room $roomCode',
              style: const TextStyle(
                color: StudioFlowTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCopyCode,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: Color(0xFFEF4444)),
              SizedBox(width: 5),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingGuestCard extends StatelessWidget {
  final String roomCode;
  final VoidCallback onShare;

  const _WaitingGuestCard({
    required this.roomCode,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Waiting…',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Share $roomCode',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onShare,
            child: Text(
              'Copy code',
              style: TextStyle(
                color: recntsColor.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final String initial;
  final String name;
  final String role;
  final Color accentColor;
  final bool isActive;
  final String? photoUrl;

  const _ParticipantCard({
    required this.initial,
    required this.name,
    required this.role,
    required this.accentColor,
    this.isActive = false,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? recntsColor.withValues(alpha: 0.65)
              : StudioFlowTheme.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: accentColor,
                backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? NetworkImage(photoUrl!)
                    : null,
                child: (photoUrl == null || photoUrl!.isEmpty)
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioFlowTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isActive)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: recntsColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: StudioFlowTheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _BackingTrackCard extends StatelessWidget {
  final CollabBackingTrack track;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const _BackingTrackCard({
    required this.track,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: buttonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.piano_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.primaryLabel,
                  style: const TextStyle(
                    color: StudioFlowTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.metaLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTogglePlay,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recntsColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: recntsColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollabChatSection extends StatelessWidget {
  final List<CollabMessage> messages;
  final String? myUid;
  final ScrollController scrollController;

  const _CollabChatSection({
    required this.messages,
    required this.myUid,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PrepPhaseChip(),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 280),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF12141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: StudioFlowTheme.border),
          ),
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'Say hi and plan your parts…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    if (msg.type == 'system') {
                      return _SystemChatLine(text: msg.text);
                    }
                    final isMe = myUid != null && msg.senderId == myUid;
                    final sender = isMe ? 'You' : msg.senderName;
                    final trimmed = sender.trim();
                    final initial = trimmed.isEmpty
                        ? 'U'
                        : trimmed[0].toUpperCase();
                    return _ChatBubble(
                      isMe: isMe,
                      sender: sender,
                      initial: initial,
                      text: msg.text,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SystemChatLine extends StatelessWidget {
  final String text;

  const _SystemChatLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _PrepPhaseChip extends StatelessWidget {
  const _PrepPhaseChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12141A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: recntsColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Prep Phase — Discuss your plan',
            style: TextStyle(
              color: recntsColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isMe;
  final String sender;
  final String initial;
  final String text;

  const _ChatBubble({
    required this.isMe,
    required this.sender,
    required this.initial,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = isMe ? recntsColor : indigoColor;
    const bubbleColor = Color(0xFF1C1F28);
    const nameStyle = TextStyle(
      color: StudioFlowTheme.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    const textStyle = TextStyle(
      color: StudioFlowTheme.textPrimary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(text, style: textStyle),
    );

    final nameLabel = Text(sender, style: nameStyle);
    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: avatarColor,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                nameLabel,
                const SizedBox(height: 4),
                bubble,
              ],
            ),
          ),
          const SizedBox(width: 8),
          avatar,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        avatar,
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              nameLabel,
              const SizedBox(height: 4),
              bubble,
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: StudioFlowTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: const Color(0xFF12141A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: recntsColor.withValues(alpha: 0.45),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSending ? null : onSend,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  color: recntsColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                width: 46,
                height: 46,
                child: isSending
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
    );
  }
}

class _StartRecordingButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;

  const _StartRecordingButton({
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (!enabled || isLoading) ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              gradient: buttonGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: recntsColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Recording Phase',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Both artists will record their parts',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openCollabRoom(
  BuildContext context, {
  required String roomId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CollabRoomScreen(roomId: roomId),
    ),
  );
}
