import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';

class TrackPublishedScreen extends StatelessWidget {
  final String trackTitle;
  final String collaboratorName;
  final String genre;
  final String duration;

  const TrackPublishedScreen({
    super.key,
    this.trackTitle = 'Rainy Night Vibes',
    this.collaboratorName = 'Sudais',
    this.genre = 'Dark Trap',
    this.duration = '2:47',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: StudioFlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      const Text(
                        '05 · PUBLISHED!',
                        style: TextStyle(
                          color: StudioFlowTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🎉', style: TextStyle(fontSize: 42)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Track Published!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: StudioFlowTheme.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Live on both profiles. You\'re both credited and earning from this track.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _PublishedTrackCard(
                        title: trackTitle,
                        meta: 'You & $collaboratorName · $genre · $duration',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfilePublishedCard(
                              initial: 'A',
                              label: 'Your Profile',
                              accentColor: recntsColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfilePublishedCard(
                              initial: collaboratorName.isNotEmpty
                                  ? collaboratorName[0].toUpperCase()
                                  : 'S',
                              label: collaboratorName,
                              accentColor: indigoColor,
                            ),
                          ),
                        ],
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
                        onTap: () {
                          AppToast.show('Shared to WhatsApp & Feed!');
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        borderRadius: BorderRadius.circular(27),
                        child: const Center(
                          child: Text(
                            '📤 Share to WhatsApp & Feed',
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

class _PublishedTrackCard extends StatelessWidget {
  final String title;
  final String meta;

  const _PublishedTrackCard({
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: recntsColor.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: recntsColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFA855F7),
                  Color(0xFF7C3AED),
                  Color(0xFFB717DB),
                ],
              ),
            ),
            child: const Center(
              child: Text('🎵', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              color: StudioFlowTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _StatColumn(value: '0', label: 'Plays')),
              Expanded(child: _StatColumn(value: '0', label: 'Likes')),
              Expanded(child: _StatColumn(value: '0', label: 'Tips')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: StudioFlowTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: StudioFlowTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProfilePublishedCard extends StatelessWidget {
  final String initial;
  final String label;
  final Color accentColor;

  const _ProfilePublishedCard({
    required this.initial,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accentColor,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '✅ Published',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

void openTrackPublished(
  BuildContext context, {
  String trackTitle = 'Rainy Night Vibes',
  String collaboratorName = 'Sudais',
  String genre = 'Dark Trap',
  String duration = '2:47',
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TrackPublishedScreen(
        trackTitle: trackTitle,
        collaboratorName: collaboratorName,
        genre: genre,
        duration: duration,
      ),
    ),
  );
}
