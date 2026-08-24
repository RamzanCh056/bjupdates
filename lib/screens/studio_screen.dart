import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/screens/notification/notification.dart';
import 'package:beatjerky/screens/studio/challenges_feed_screen.dart';
import 'package:beatjerky/screens/studio/co_producer_flow_screen.dart';
import 'package:beatjerky/screens/studio/live_collabs_screen.dart';
import 'package:beatjerky/utils/ai_tool_navigation.dart';
import 'package:beatjerky/widgets/ai_tools_section.dart';
import 'package:flutter/material.dart';

class _StudioQuickTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final String aiToolTitle;

  const _StudioQuickTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.aiToolTitle,
  });
}

const _kQuickTools = [
  _StudioQuickTool(
    title: 'Vocal Enhance',
    subtitle: 'Studio polish',
    icon: Icons.mic_rounded,
    iconBg: Color(0xFF7B2FF7),
    aiToolTitle: 'AI Vocal Enhancer',
  ),
  _StudioQuickTool(
    title: 'Stem Splitter',
    subtitle: 'Isolate tracks',
    icon: Icons.content_cut_rounded,
    iconBg: Color(0xFF22C55E),
    aiToolTitle: 'Stem Splitter',
  ),
  _StudioQuickTool(
    title: 'Lyrics Writer',
    subtitle: 'AI songwriting',
    icon: Icons.edit_note_rounded,
    iconBg: Color(0xFFFBBF24),
    aiToolTitle: 'AI Lyrics Writer',
  ),
  _StudioQuickTool(
    title: 'Viral Score',
    subtitle: 'Reach forecast',
    icon: Icons.bar_chart_rounded,
    iconBg: Color(0xFFEF4444),
    aiToolTitle: 'Viral Score Predictor',
  ),
];

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  AiToolItem? _toolByTitle(String title) {
    for (final tool in kAiTools) {
      if (tool.title == title) return tool;
    }
    return null;
  }

  void _openQuickTool(BuildContext context, _StudioQuickTool quickTool) {
    final tool = _toolByTitle(quickTool.aiToolTitle);
    if (tool != null) {
      AiToolNavigation.openTool(context, tool);
    }
  }

  void _openCoProducer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoProducerFlowScreen()),
    );
  }

  void _openLiveCollabs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveCollabsScreen()),
    );
  }

  void _openChallenges(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChallengesFeedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0F),
      body: Stack(
        children: [
          const AiToolsAmbientBackground(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StudioHeader(
                          onNotifications: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _CoProducerHeroCard(
                          onStart: () => _openCoProducer(context),
                        ),
                        const SizedBox(height: 14),
                        _LiveCollabEntryCard(
                          onTap: () => _openLiveCollabs(context),
                        ),
                        const SizedBox(height: 10),
                        _ChallengesEntryCard(
                          onTap: () => _openChallenges(context),
                        ),
                        const SizedBox(height: 28),
                        _QuickToolsHeader(
                          onViewAll: () =>
                              AiToolNavigation.openAllTools(context),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = _kQuickTools[index];
                        return _QuickToolCard(
                          tool: tool,
                          onTap: () => _openQuickTool(context, tool),
                        );
                      },
                      childCount: _kQuickTools.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  final VoidCallback onNotifications;

  const _StudioHeader({required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Studio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
        ),
        Material(
          color: const Color(0xFF1A1D24),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onNotifications,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFFFBBF24),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoProducerHeroCard extends StatelessWidget {
  final VoidCallback onStart;

  const _CoProducerHeroCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B1F6E),
              Color(0xFF2A1654),
              Color(0xFF1A1038),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -12,
              child: Icon(
                Icons.music_note_rounded,
                size: 120,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              right: 36,
              bottom: 28,
              child: Icon(
                Icons.music_note_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D50FF).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF9D50FF).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✨', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          'AI POWERED',
                          style: TextStyle(
                            color: Color(0xFFD8B4FE),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI Co-Producer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hum anything. Get a full professional beat in under 2 minutes.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9D50FF), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9D50FF)
                                .withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onStart,
                          borderRadius: BorderRadius.circular(26),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Start Creating',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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

class _ChallengesEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ChallengesEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15181F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFBB86FC).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB717DB), Color(0xFF7B2FF7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Challenges',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Compete, win prizes, go viral',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFBB86FC).withValues(alpha: 0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCollabEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LiveCollabEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15181F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFBB86FC).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBB86FC), Color(0xFFB717DB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFBB86FC).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Collabs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Record together live with any artist',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFBB86FC).withValues(alpha: 0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickToolsHeader extends StatelessWidget {
  final VoidCallback onViewAll;

  const _QuickToolsHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Quick Tools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9D50FF),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickToolCard extends StatelessWidget {
  final _StudioQuickTool tool;
  final VoidCallback onTap;

  const _QuickToolCard({
    required this.tool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15181F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tool.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
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
    );
  }
}
