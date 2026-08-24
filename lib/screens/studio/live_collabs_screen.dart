import 'package:beatjerky/models/collab_models.dart';
import 'package:beatjerky/screens/studio/collab_recording_screen.dart';
import 'package:beatjerky/screens/studio/collab_room_screen.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/collab_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LiveCollabsScreen extends StatefulWidget {
  const LiveCollabsScreen({super.key});

  @override
  State<LiveCollabsScreen> createState() => _LiveCollabsScreenState();
}

class _LiveCollabsScreenState extends State<LiveCollabsScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  bool _creating = false;
  bool _joining = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_creating) return;
    if (FirebaseAuth.instance.currentUser == null) {
      AppToast.show('Please sign in to create a room');
      return;
    }

    setState(() => _creating = true);
    try {
      final room = await CollabService.createRoom();
      if (!mounted) return;
      openCollabRoom(context, roomId: room.id);
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinRoom() async {
    if (_joining) return;
    if (FirebaseAuth.instance.currentUser == null) {
      AppToast.show('Please sign in to join a room');
      return;
    }

    final code = CollabService.normalizeCode(_roomCodeController.text);
    if (code.isEmpty) {
      AppToast.show('Enter a room code');
      return;
    }

    setState(() => _joining = true);
    try {
      final room = await CollabService.joinRoom(code);
      if (!mounted) return;
      _roomCodeController.clear();
      openCollabRoom(context, roomId: room.id);
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 20, 0),
                  child: _LiveCollabsHeader(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _StartCollabCard(
                      isLoading: _creating,
                      onCreate: _createRoom,
                    ),
                    const SizedBox(height: 22),
                    const _OrJoinDivider(),
                    const SizedBox(height: 18),
                    _JoinRoomSection(
                      controller: _roomCodeController,
                      isLoading: _joining,
                      onJoin: _joinRoom,
                    ),
                    const SizedBox(height: 28),
                    _MyRoomsSection(
                      onOpenRoom: (room) {
                        if (room.isRecording) {
                          openCollabRecording(context, roomId: room.id);
                        } else {
                          openCollabRoom(context, roomId: room.id);
                        }
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCollabsHeader extends StatelessWidget {
  const _LiveCollabsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudioBackButton(onPressed: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Live Collabs',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartCollabCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onCreate;

  const _StartCollabCard({
    required this.isLoading,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A1848),
              Color(0xFF1A2847),
              Color(0xFF12102A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recntsColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Icon(
                Icons.mic_external_on_rounded,
                size: 88,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: recntsColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: recntsColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎙️', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Text(
                          'LIVE STUDIO',
                          style: TextStyle(
                            color: recntsColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Start a Collab Room',
                    style: TextStyle(
                      color: StudioFlowTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invite any artist. Record together live. Publish to both profiles.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: buttonGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: recntsColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isLoading ? null : onCreate,
                          borderRadius: BorderRadius.circular(25),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('🚀', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Room',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrJoinDivider extends StatelessWidget {
  const _OrJoinDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR JOIN A ROOM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _JoinRoomSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onJoin;

  const _JoinRoomSection({
    required this.controller,
    required this.isLoading,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTER ROOM CODE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: StudioFlowTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. XK92',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0E1016),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onJoin(),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onJoin,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Join',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyRoomsSection extends StatelessWidget {
  final ValueChanged<CollabRoom> onOpenRoom;

  const _MyRoomsSection({required this.onOpenRoom});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Rooms',
          style: TextStyle(
            color: StudioFlowTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (uid == null)
          Text(
            'Sign in to see your rooms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          )
        else
          StreamBuilder<List<CollabRoom>>(
            stream: CollabService.watchMyRooms(uid: uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: recntsColor,
                      ),
                    ),
                  ),
                );
              }

              final rooms = snapshot.data ?? const <CollabRoom>[];
              if (rooms.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StudioFlowTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StudioFlowTheme.border),
                  ),
                  child: Text(
                    'No rooms yet. Create one and share the code with a collaborator.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < rooms.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _RoomCard(
                      room: rooms[i],
                      myUid: uid,
                      onOpen: () => onOpenRoom(rooms[i]),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final CollabRoom room;
  final String myUid;
  final VoidCallback onOpen;

  const _RoomCard({
    required this.room,
    required this.myUid,
    required this.onOpen,
  });

  Future<void> _shareCode() async {
    await Clipboard.setData(ClipboardData(text: room.code));
    AppToast.show('Room code ${room.code} copied!');
  }

  @override
  Widget build(BuildContext context) {
    final waiting = room.participants.length < 2;
    final recording = room.isRecording;
    final statusColor = recording
        ? const Color(0xFFEF4444)
        : waiting
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    final openLabel = recording
        ? 'Resume'
        : waiting
            ? 'Open'
            : 'Rejoin';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: recording
                  ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                  : StudioFlowTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.55),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.displayTitle(myUid),
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      room.statusSubtitle(myUid),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (waiting) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _shareCode,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.ios_share_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: recording ? null : buttonGradient,
                      color: recording
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      border: recording
                          ? Border.all(
                              color:
                                  const Color(0xFFEF4444).withValues(alpha: 0.45),
                            )
                          : null,
                    ),
                    child: Text(
                      openLabel,
                      style: TextStyle(
                        color: recording
                            ? const Color(0xFFFF8A8A)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
