import 'package:flutter/material.dart';

import '../../utils/color.dart';
import '../bjai_screen.dart';

/// AI assistant hub for professionals. Each helper opens the existing BJAI
/// chat pre-loaded with a tailored prompt, so the same assistant now helps
/// with opportunities, events, profiles and career growth — not only music.
class ProAssistantScreen extends StatelessWidget {
  const ProAssistantScreen({super.key});

  static const Color _accent = Color(0xFFBB86FC);

  static const List<_Section> _sections = [
    _Section('Opportunities', Icons.campaign_outlined, [
      _Helper(
        'Write an opportunity post',
        'Draft a clear gig/opportunity listing',
        Icons.edit_note,
        'Help me write a short, appealing opportunity post to hire a performer. '
            'Ask me what role, date, city and budget I have in mind, then write it '
            'in 3-4 friendly, professional sentences.',
      ),
      _Helper(
        'What makes a good gig post?',
        'Tips to attract the right applicants',
        Icons.tips_and_updates_outlined,
        'Give me a short checklist of what to include in a gig/opportunity post '
            'so I attract the right professionals (role, date, pay, location, '
            'expectations).',
      ),
    ]),
    _Section('Events', Icons.event, [
      _Helper(
        'Plan my event checklist',
        'Step-by-step planning list',
        Icons.checklist_rounded,
        'Create a practical planning checklist for a live music event. Ask me the '
            'event type, size and date first, then give me the checklist.',
      ),
      _Helper(
        'Suggest staff & suppliers',
        'Who and what you need',
        Icons.groups_2_outlined,
        'Based on an event I describe, suggest the staff (DJ, sound, lighting, '
            'security, etc.) and suppliers I should book. Ask me the event size '
            'and type first.',
      ),
    ]),
    _Section('Profile', Icons.person_outline, [
      _Helper(
        'Write my professional bio',
        'A short, strong bio',
        Icons.badge_outlined,
        'Help me write a short professional bio for my BeatJerky profile. Ask me '
            'my role, experience and style, then write 2-3 polished sentences.',
      ),
      _Helper(
        'Improve my profile',
        'Make it stand out',
        Icons.auto_awesome,
        'Give me tips to improve my professional music profile so clients and '
            'organizers take me seriously.',
      ),
    ]),
    _Section('Career', Icons.trending_up_rounded, [
      _Helper(
        'How do I get more gigs?',
        'Practical ways to find work',
        Icons.work_outline,
        'Give me practical, realistic ways to find more gigs and opportunities as '
            'a music professional.',
      ),
      _Helper(
        'Grow my network',
        'Connect with the right people',
        Icons.hub_outlined,
        'How can I grow my professional network in the music industry and build '
            'useful connections?',
      ),
    ]),
  ];

  void _open(BuildContext context, String prompt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BJAI(initialPrompt: prompt)),
    );
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
          'AI assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _intro(context),
          const SizedBox(height: 20),
          for (final section in _sections) ...[
            _sectionHeader(section),
            const SizedBox(height: 10),
            ...section.helpers.map((h) => _helperCard(context, h)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BJAI()),
        ),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: appGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask anything',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Open the assistant and chat freely.',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(_Section s) {
    return Row(
      children: [
        Icon(s.icon, color: _accent, size: 18),
        const SizedBox(width: 8),
        Text(s.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _helperCard(BuildContext context, _Helper h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(context, h.prompt),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(h.icon, color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(h.subtitle,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.north_east, color: Colors.white38, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  final List<_Helper> helpers;
  const _Section(this.title, this.icon, this.helpers);
}

class _Helper {
  final String title;
  final String subtitle;
  final IconData icon;
  final String prompt;
  const _Helper(this.title, this.subtitle, this.icon, this.prompt);
}
