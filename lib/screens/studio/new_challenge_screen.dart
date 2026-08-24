import 'package:beatjerky/screens/studio/challenge_leaderboard_screen.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/challenge_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewChallengeScreen extends StatefulWidget {
  const NewChallengeScreen({super.key});

  @override
  State<NewChallengeScreen> createState() => _NewChallengeScreenState();
}

class _NewChallengeScreenState extends State<NewChallengeScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _prizeController;

  final Set<String> _selectedHashtags = {'#BJDarkTrap'};
  final List<String> _availableHashtags = [
    '#BJDarkTrap',
    '#BeatChallenge',
    '#BJRap',
  ];

  int _selectedDeadlineDays = 7;
  bool _launching = false;
  bool _pickingBeat = false;

  String? _beatLocalPath;
  String? _beatFileName;
  int? _beatSizeBytes;
  String? _beatDurationPreview;

  bool get _hasBeat =>
      _beatLocalPath != null &&
      _beatLocalPath!.isNotEmpty &&
      _beatFileName != null &&
      _beatFileName!.isNotEmpty;

  String get _beatMetaPreview {
    final parts = <String>[];
    if (_beatDurationPreview != null && _beatDurationPreview!.isNotEmpty) {
      parts.add(_beatDurationPreview!);
    }
    if (_beatSizeBytes != null && _beatSizeBytes! > 0) {
      final b = _beatSizeBytes!;
      if (b >= 1024 * 1024) {
        parts.add('${(b / (1024 * 1024)).toStringAsFixed(1)} MB');
      } else {
        parts.add('${(b / 1024).toStringAsFixed(0)} KB');
      }
    }
    return parts.isEmpty ? 'Ready to upload' : parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Show me your best hook 🔥');
    _prizeController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  void _toggleHashtag(String tag) {
    setState(() {
      if (_selectedHashtags.contains(tag)) {
        if (_selectedHashtags.length > 1) {
          _selectedHashtags.remove(tag);
        }
      } else {
        _selectedHashtags.add(tag);
      }
    });
  }

  Future<void> _pickBeat() async {
    if (_pickingBeat || _launching) return;
    setState(() => _pickingBeat = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        AppToast.show('Could not read the selected file.', isError: true);
        return;
      }

      setState(() {
        _beatLocalPath = path;
        _beatFileName = file.name;
        _beatSizeBytes = file.size;
        _beatDurationPreview = null;
      });
    } catch (error, stackTrace) {
      logDebugException('NewChallengeScreen.pickBeat', error, stackTrace: stackTrace);
      AppToast.show('Could not pick that file', isError: true);
    } finally {
      if (mounted) setState(() => _pickingBeat = false);
    }
  }

  Future<void> _launchChallenge() async {
    if (_launching) return;
    if (FirebaseAuth.instance.currentUser == null) {
      AppToast.show('Please sign in to launch a challenge');
      return;
    }
    if (!_hasBeat) {
      AppToast.show('Pick your beat / hook MP3 first');
      return;
    }

    setState(() => _launching = true);
    try {
      final beat = await ChallengeService.uploadBeatFile(
        localPath: _beatLocalPath!,
        fileName: _beatFileName!,
        sizeBytes: _beatSizeBytes,
      );
      final challenge = await ChallengeService.createChallenge(
        title: _titleController.text.trim(),
        hashtags: _selectedHashtags.toList(),
        deadlineDays: _selectedDeadlineDays,
        prizeText: _prizeController.text.trim().isEmpty
            ? null
            : _prizeController.text.trim(),
        beat: beat,
      );
      if (!mounted) return;
      AppToast.show('Challenge launched! Others can Accept — you manage entries.');
      openChallengeLeaderboard(
        context,
        challengeId: challenge.id,
        replace: true,
      );
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                child: Row(
                  children: [
                    StudioBackButton(
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Challenge',
                        style: TextStyle(
                          color: StudioFlowTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '02 · NEW CHALLENGE',
                        style: TextStyle(
                          color: StudioFlowTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('YOUR BEAT / HOOK'),
                      const SizedBox(height: 10),
                      _BeatHookCard(
                        selected: _hasBeat,
                        fileName: _beatFileName ?? 'Tap to pick MP3 / WAV',
                        meta: _hasBeat
                            ? _beatMetaPreview
                            : 'This plays in their ear when they Accept',
                        loading: _pickingBeat,
                        onTap: _pickBeat,
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('CHALLENGE TITLE'),
                      const SizedBox(height: 10),
                      _ChallengeTextField(controller: _titleController),
                      const SizedBox(height: 22),
                      const _SectionLabel('HASHTAG'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._availableHashtags.map((tag) {
                            final selected = _selectedHashtags.contains(tag);
                            return _HashtagChip(
                              label: tag,
                              selected: selected,
                              onTap: () => _toggleHashtag(tag),
                            );
                          }),
                          _AddHashtagChip(
                            onTap: () {
                              AppToast.show('Custom hashtags coming soon');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('DEADLINE'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _DeadlinePill(
                            label: '3 Days',
                            selected: _selectedDeadlineDays == 3,
                            onTap: () =>
                                setState(() => _selectedDeadlineDays = 3),
                          ),
                          const SizedBox(width: 8),
                          _DeadlinePill(
                            label: '7 Days',
                            selected: _selectedDeadlineDays == 7,
                            onTap: () =>
                                setState(() => _selectedDeadlineDays = 7),
                          ),
                          const SizedBox(width: 8),
                          _DeadlinePill(
                            label: '30 Days',
                            selected: _selectedDeadlineDays == 30,
                            onTap: () =>
                                setState(() => _selectedDeadlineDays = 30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('PRIZE (OPTIONAL)'),
                      const SizedBox(height: 10),
                      _ChallengeTextField(
                        controller: _prizeController,
                        hint: 'e.g. Feature on my profile, Rs.1000...',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: buttonGradient,
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: recntsColor.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _launching ? null : _launchChallenge,
                        borderRadius: BorderRadius.circular(27),
                        child: Center(
                          child: _launching
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '🚀 Launch Challenge',
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
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: StudioFlowTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _BeatHookCard extends StatelessWidget {
  final bool selected;
  final String fileName;
  final String meta;
  final bool loading;
  final VoidCallback onTap;

  const _BeatHookCard({
    required this.selected,
    required this.fileName,
    required this.meta,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? recntsColor.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        selected
                            ? Icons.music_note_rounded
                            : Icons.upload_file_rounded,
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
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioFlowTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;

  const _ChallengeTextField({
    required this.controller,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: StudioFlowTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: StudioFlowTheme.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: StudioFlowTheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HashtagChip({
    required this.label,
    required this.selected,
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
          decoration: BoxDecoration(
            color: selected
                ? recntsColor.withValues(alpha: 0.1)
                : StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? recntsColor.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? recntsColor : StudioFlowTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddHashtagChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddHashtagChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: const Text(
            '+ Add',
            style: TextStyle(
              color: StudioFlowTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeadlinePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DeadlinePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? recntsColor.withValues(alpha: 0.1)
                  : StudioFlowTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? recntsColor.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? recntsColor : StudioFlowTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openNewChallenge(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NewChallengeScreen()),
  );
}
