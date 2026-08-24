import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/models/collab_models.dart';
import 'package:beatjerky/screens/studio/collab_widgets.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/collab_service.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum _CollabTakeState { recording, paused, stopped }

class CollabRecordingScreen extends StatefulWidget {
  final String roomId;

  const CollabRecordingScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<CollabRecordingScreen> createState() => _CollabRecordingScreenState();
}

class _CollabRecordingScreenState extends State<CollabRecordingScreen>
    with TickerProviderStateMixin {
  static const _timeLeftStart = Duration(minutes: 1, seconds: 23);

  Duration _elapsed = Duration.zero;
  Duration _timeLeft = _timeLeftStart;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  final List<double> _waveHeights = List<double>.filled(32, 0.3);
  bool _markedDone = false;
  _CollabTakeState _takeState = _CollabTakeState.recording;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isRecording => _takeState == _CollabTakeState.recording;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_updateWaveform);
    _startTake();
  }

  void _startTake() {
    setState(() => _takeState = _CollabTakeState.recording);
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
        if (_timeLeft.inSeconds > 0) {
          _timeLeft -= const Duration(seconds: 1);
        }
      });
    });
  }

  void _pauseTake() {
    setState(() => _takeState = _CollabTakeState.paused);
    _timer?.cancel();
    _pulseController.stop();
    _waveController.stop();
  }

  void _stopTake() {
    setState(() => _takeState = _CollabTakeState.stopped);
    _timer?.cancel();
    _pulseController.stop();
    _waveController.stop();
  }

  void _toggleMic() {
    switch (_takeState) {
      case _CollabTakeState.recording:
        _pauseTake();
      case _CollabTakeState.paused:
        _startTake();
      case _CollabTakeState.stopped:
        setState(() {
          _elapsed = Duration.zero;
          _timeLeft = _timeLeftStart;
        });
        _startTake();
    }
  }

  void _updateWaveform() {
    if (!_isRecording) return;
    final t = _waveController.value * math.pi * 2;
    setState(() {
      for (var i = 0; i < _waveHeights.length; i++) {
        final phase = t + (i * 0.42);
        _waveHeights[i] = 0.15 + (0.5 + math.sin(phase).abs() * 0.45);
      }
    });
  }

  Future<void> _leaveWithoutFinishing() async {
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _finishTake() async {
    if (_markedDone) return;
    _markedDone = true;
    _stopTake();
    try {
      await CollabService.markRecordingDone(widget.roomId);
    } catch (_) {}
    if (mounted) {
      Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusSuffix {
    switch (_takeState) {
      case _CollabTakeState.recording:
        return ' · Recording...';
      case _CollabTakeState.paused:
        return ' · Paused';
      case _CollabTakeState.stopped:
        return ' · Stopped';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: StreamBuilder<CollabRoom?>(
            stream: CollabService.watchRoom(widget.roomId),
            builder: (context, snapshot) {
              final room = snapshot.data;
              final myUid = _myUid;
              final peerId = (room != null && myUid != null)
                  ? room.peerIdFor(myUid)
                  : null;
              final peer = peerId == null ? null : room?.infoFor(peerId);
              final me = myUid == null ? null : room?.infoFor(myUid);
              final guestName = peer?.name ?? 'Collaborator';
              final guestDone = peer?.recordingStatus == 'done';
              final meDone = me?.recordingStatus == 'done';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                    child: _RecordingHeader(
                      timeLeft: _timeLeft,
                      onBack: _leaveWithoutFinishing,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: CollabPhaseIndicator(
                      currentPhase: 2,
                      label: 'Record',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CollaboratorStatusCard(
                            guestName: guestName,
                            isDone: guestDone,
                          ),
                          const SizedBox(height: 16),
                          _RecordingWorkspace(
                            elapsed: _elapsed,
                            statusSuffix: _statusSuffix,
                            waveHeights: _waveHeights,
                            pulseController: _pulseController,
                            formatDuration: _formatDuration,
                            isActive: _isRecording,
                            takeState: _takeState,
                            onMicTap: _toggleMic,
                            onPause: _pauseTake,
                            onResume: _startTake,
                            onStop: _stopTake,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleStatusCard(
                                  name: guestName,
                                  part: peer?.role.split('/').first.trim() ??
                                      'Verse',
                                  statusLabel:
                                      guestDone ? '✅ Done' : '⏳ Waiting',
                                  statusColor: guestDone
                                      ? const Color(0xFF22C55E)
                                      : StudioFlowTheme.textMuted,
                                  isActive: false,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _RoleStatusCard(
                                  name: 'You',
                                  part: meDone
                                      ? (me?.role.split('/').first.trim() ??
                                          'Hook')
                                      : 'Hook ← Now',
                                  partColor: recntsColor,
                                  statusLabel: meDone
                                      ? '✅ Done'
                                      : _isRecording
                                          ? '🔴 Recording'
                                          : _takeState == _CollabTakeState.paused
                                              ? '⏸ Paused'
                                              : '⏹ Stopped',
                                  statusColor: meDone
                                      ? const Color(0xFF22C55E)
                                      : recntsColor,
                                  isActive: _isRecording,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: buttonGradient,
                          borderRadius: BorderRadius.circular(27),
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
                            onTap: _finishTake,
                            borderRadius: BorderRadius.circular(27),
                            child: const Center(
                              child: Text(
                                '✅ Done with my take',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _RecordingHeader extends StatelessWidget {
  final Duration timeLeft;
  final VoidCallback onBack;

  const _RecordingHeader({
    required this.timeLeft,
    required this.onBack,
  });

  String _formatLeft(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s left';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudioBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Recording',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Color(0xFFFF8A8A),
              ),
              const SizedBox(width: 4),
              Text(
                _formatLeft(timeLeft),
                style: const TextStyle(
                  color: Color(0xFFFF8A8A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollaboratorStatusCard extends StatelessWidget {
  final String guestName;
  final bool isDone;

  const _CollaboratorStatusCard({
    required this.guestName,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: indigoColor,
            child: Text(
              guestName.isNotEmpty ? guestName[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guestName,
                  style: const TextStyle(
                    color: StudioFlowTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isDone ? '✅ Finished recording' : '⏳ Waiting for their take',
                  style: TextStyle(
                    color: isDone
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _StaticWaveformIcon(color: Colors.white.withValues(alpha: 0.28)),
        ],
      ),
    );
  }
}

class _StaticWaveformIcon extends StatelessWidget {
  final Color color;

  const _StaticWaveformIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [0.35, 0.55, 0.4, 0.7, 0.45, 0.6, 0.38];
    return SizedBox(
      width: 36,
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: heights.map((h) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: 22 * h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecordingWorkspace extends StatelessWidget {
  final Duration elapsed;
  final String statusSuffix;
  final List<double> waveHeights;
  final AnimationController pulseController;
  final String Function(Duration) formatDuration;
  final bool isActive;
  final _CollabTakeState takeState;
  final VoidCallback onMicTap;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _RecordingWorkspace({
    required this.elapsed,
    required this.statusSuffix,
    required this.waveHeights,
    required this.pulseController,
    required this.formatDuration,
    required this.isActive,
    required this.takeState,
    required this.onMicTap,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final micIcon = takeState == _CollabTakeState.recording
        ? Icons.pause_rounded
        : Icons.mic_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: recntsColor.withValues(alpha: isActive ? 0.55 : 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: recntsColor.withValues(alpha: isActive ? 0.08 : 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR TURN — RECORD HOOK / CHORUS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: waveHeights.map((factor) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: Container(
                      height: 56 * factor.clamp(0.12, 1.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            recntsColor.withValues(
                              alpha: isActive ? 0.95 : 0.35,
                            ),
                            recntsColor.withValues(
                              alpha: isActive ? 0.45 : 0.15,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onMicTap,
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final glow = isActive
                    ? 0.28 + (pulseController.value * 0.22)
                    : 0.1;
                return Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: recntsColor.withValues(alpha: glow),
                        blurRadius: 36,
                        spreadRadius: isActive ? 4 : 0,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recntsColor.withValues(alpha: isActive ? 0.12 : 0.06),
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recntsColor.withValues(alpha: isActive ? 0.2 : 0.1),
                      border: Border.all(
                        color: recntsColor.withValues(
                          alpha: isActive ? 0.45 : 0.25,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                            )
                          : LinearGradient(
                              colors: [
                                recntsColor.withValues(alpha: 0.5),
                                indigoColor.withValues(alpha: 0.5),
                              ],
                            ),
                    ),
                    child: Icon(
                      micIcon,
                      color: StudioFlowTheme.silver,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: formatDuration(elapsed),
                  style: const TextStyle(color: StudioFlowTheme.textPrimary),
                ),
                TextSpan(
                  text: statusSuffix,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (takeState == _CollabTakeState.recording)
                _ControlChip(
                  icon: Icons.pause_rounded,
                  label: 'Pause',
                  color: recntsColor,
                  onTap: onPause,
                )
              else
                _ControlChip(
                  icon: Icons.play_arrow_rounded,
                  label: takeState == _CollabTakeState.stopped
                      ? 'Re-record'
                      : 'Resume',
                  color: recntsColor,
                  onTap: onResume,
                ),
              if (takeState != _CollabTakeState.stopped) ...[
                const SizedBox(width: 12),
                _ControlChip(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  color: const Color(0xFFEF4444),
                  onTap: onStop,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleStatusCard extends StatelessWidget {
  final String name;
  final String part;
  final Color? partColor;
  final String statusLabel;
  final Color statusColor;
  final bool isActive;

  const _RoleStatusCard({
    required this.name,
    required this.part,
    this.partColor,
    required this.statusLabel,
    required this.statusColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? recntsColor.withValues(alpha: 0.55)
              : StudioFlowTheme.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mic_rounded,
            size: 18,
            color: StudioFlowTheme.silver.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            part,
            style: TextStyle(
              color: partColor ?? StudioFlowTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

void openCollabRecording(
  BuildContext context, {
  required String roomId,
  bool replace = false,
}) {
  final route = MaterialPageRoute(
    builder: (_) => CollabRecordingScreen(roomId: roomId),
  );
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}
