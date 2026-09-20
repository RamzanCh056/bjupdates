import 'package:flutter/material.dart';

import '../../models/musician_career_models.dart';
import '../../services/musician_career_service.dart';
import '../../utils/color.dart';
import 'musician_form_screen.dart';
import 'musician_register_screen.dart';

/// Entry screen for the Musician-Career feature.
///
/// Not a musician yet → a "Become a musician" call to action.
/// Registered → a profile summary and the "My Forms" list (assignments),
/// each opening the dynamic form renderer.
class MusicianHubScreen extends StatefulWidget {
  const MusicianHubScreen({super.key});

  @override
  State<MusicianHubScreen> createState() => _MusicianHubScreenState();
}

class _MusicianHubScreenState extends State<MusicianHubScreen> {
  final Map<String, String> _templateTitles = <String, String>{};
  String? _userPhoto;
  bool _healTried = false;

  @override
  void initState() {
    super.initState();
    MusicianCareerService.currentUserPhotoUrl().then((url) {
      if (mounted && url != null) setState(() => _userPhoto = url);
    });
  }

  /// If the musician doc's photo is out of sync with the app profile photo,
  /// heal it once so the hub and the admin match.
  void _healPhoto(Musician m) {
    if (_healTried) return;
    final live = _userPhoto;
    if (live == null || live.isEmpty) return;
    _healTried = true;
    if ((m.photoUrl ?? '') != live) {
      MusicianCareerService.syncPhotoUrl(live);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Musician tools',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: StreamBuilder<Musician?>(
        stream: MusicianCareerService.watchMyMusician(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: purpleAccent));
          }
          final musician = snap.data;
          if (musician == null) return _notRegistered();
          _healPhoto(musician);
          return _registered(musician);
        },
      ),
    );
  }

  // --- not registered -------------------------------------------------------

  Widget _notRegistered() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                  gradient: appGradient, shape: BoxShape.circle),
              child: const Icon(Icons.music_note,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Start your musician profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Register as a musician to receive booking forms, share your details with the BeatJerky team, and manage your career in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: buttonGradient,
                    borderRadius: BorderRadius.circular(14)),
                child: TextButton(
                  onPressed: _openRegister,
                  child: const Text('Become a musician',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MusicianRegisterScreen()),
    );
    // The profile stream refreshes the UI automatically on return.
  }

  // --- registered -----------------------------------------------------------

  Widget _registered(Musician m) {
    return Column(
      children: [
        _profileHeader(m),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text('My forms',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FormAssignment>>(
            stream: MusicianCareerService.watchMyAssignments(m.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: purpleAccent));
              }
              final items = snap.data ?? const <FormAssignment>[];
              if (items.isEmpty) return _noForms();
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _formRow(items[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _profileHeader(Musician m) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: _effectivePhoto(m) != null
                ? NetworkImage(_effectivePhoto(m)!)
                : null,
            child: _effectivePhoto(m) == null
                ? Text(
                    m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [
                    m.primaryRole.label,
                    if (m.experience != null) m.experience!.label,
                    if ((m.location ?? '').isNotEmpty) m.location!,
                  ].join(' · '),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _effectivePhoto(Musician m) {
    if (_userPhoto != null && _userPhoto!.isNotEmpty) return _userPhoto;
    if (m.photoUrl != null && m.photoUrl!.isNotEmpty) return m.photoUrl;
    return null;
  }

  Widget _noForms() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                color: Colors.white.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text('No forms yet',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'When the BeatJerky team sends you a form to complete, it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow(FormAssignment a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => MusicianFormScreen(assignment: a)),
        ),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleFor(a),
                    const SizedBox(height: 8),
                    _statusPill(a.status),
                    if (a.deadline != null) ...[
                      const SizedBox(height: 6),
                      Text('Due ${_formatDate(a.deadline!)}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleFor(FormAssignment a) {
    final cached = _templateTitles[a.templateId];
    if (cached != null) {
      return Text(cached,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600));
    }
    return FutureBuilder<FormTemplate?>(
      future: MusicianCareerService.getTemplate(a.templateId),
      builder: (context, snap) {
        final title = snap.data?.title ?? 'Form';
        if (snap.hasData) _templateTitles[a.templateId] = title;
        return Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600));
      },
    );
  }

  Widget _statusPill(FormStatus status) {
    Color c;
    switch (status) {
      case FormStatus.approved:
        c = greenColor;
        break;
      case FormStatus.submitted:
      case FormStatus.reviewed:
        c = eventsColor;
        break;
      case FormStatus.changesRequested:
        c = peopleColor;
        break;
      case FormStatus.inProgress:
        c = purpleAccent;
        break;
      case FormStatus.notStarted:
        c = greyColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
