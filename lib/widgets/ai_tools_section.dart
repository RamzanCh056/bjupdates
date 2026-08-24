import 'dart:ui';

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:flutter/material.dart';

class AiToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final String prompt;

  const AiToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.prompt,
  });
}

const List<AiToolItem> kAiTools = [
  AiToolItem(
    title: 'AI Beat Generator',
    subtitle: 'Studio beats',
    icon: Icons.music_note_rounded,
    gradientColors: [Color(0xFF7B2FF7), Color(0xFF9D4EDD)],
    prompt:
        'Act as an AI beat generator. Help me create a beat idea with tempo, mood, and arrangement notes.',
  ),
  AiToolItem(
    title: 'AI Vocal Enhancer',
    subtitle: 'Vocal polish',
    icon: Icons.mic_rounded,
    gradientColors: [Color(0xFF4CC9F0), Color(0xFF4361EE)],
    prompt:
        'Act as an AI vocal enhancer coach. Suggest practical steps to improve vocal clarity, tone, and mix.',
  ),
  AiToolItem(
    title: 'AI Lyrics Writer',
    subtitle: 'Songwriting',
    icon: Icons.edit_note_rounded,
    gradientColors: [Color(0xFFF107A3), Color(0xFFC026D3)],
    prompt:
        'Act as an AI lyrics writer. Help me write song lyrics with a clear theme, rhyme pattern, and hook.',
  ),
  AiToolItem(
    title: 'Viral Score Predictor',
    subtitle: 'Reach forecast',
    icon: Icons.insights_rounded,
    gradientColors: [Color(0xFF22D3EE), Color(0xFF10B981)],
    prompt:
        'Act as a viral score predictor for music releases. Score my track idea and explain what could improve reach.',
  ),
  AiToolItem(
    title: 'AI Music Coach',
    subtitle: 'Creator mentor',
    icon: Icons.chat_bubble_outline_rounded,
    gradientColors: [Color(0xFFF97316), Color(0xFFFBBF24)],
    prompt:
        'Act as my AI music coach. Give me a focused practice plan to improve songwriting and performance.',
  ),
  AiToolItem(
    title: 'Stem Splitter',
    subtitle: 'Track isolation',
    icon: Icons.graphic_eq_rounded,
    gradientColors: [Color(0xFF4CC9F0), Color(0xFF1E3A8A)],
    prompt:
        'Act as a stem-splitting assistant. Explain how to isolate vocals, drums, bass, and melody from a track.',
  ),
  AiToolItem(
    title: 'Script to Music',
    subtitle: 'Cinematic score',
    icon: Icons.movie_creation_outlined,
    gradientColors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
    prompt:
        'Act as a script-to-music assistant. Turn my scene or script into a music brief with mood, tempo, and cues.',
  ),
  AiToolItem(
    title: 'AI Mood Radio',
    subtitle: 'Mood streaming',
    icon: Icons.podcasts_rounded,
    gradientColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    prompt:
        'Act as an AI mood radio DJ. Recommend a playlist flow based on my current mood and music taste.',
  ),
];

const double _kCardRadius = 22;
const double _kGridSpacing = 14;

class AiToolsSection extends StatelessWidget {
  final void Function(AiToolItem tool) onToolTap;
  final VoidCallback? onViewAll;
  final int? maxVisibleTools;
  final bool showSubtitle;

  const AiToolsSection({
    super.key,
    required this.onToolTap,
    this.onViewAll,
    this.maxVisibleTools,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTools = maxVisibleTools != null
        ? kAiTools.take(maxVisibleTools!).toList()
        : kAiTools;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiToolsSectionHeader(
            onViewAll: onViewAll,
            showSubtitle: showSubtitle,
          ),
          const SizedBox(height: 16),
          _AiToolsGrid(
            tools: visibleTools,
            onToolTap: onToolTap,
          ),
        ],
      ),
    );
  }
}

class ViewAllAiToolsScreen extends StatelessWidget {
  final void Function(AiToolItem tool) onToolTap;
  final VoidCallback? onLibraryTap;

  const ViewAllAiToolsScreen({
    super.key,
    required this.onToolTap,
    this.onLibraryTap,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsScreen(
      title: 'AI Tools',
      topAction: onLibraryTap != null
          ? IconButton(
              onPressed: onLibraryTap,
              icon: const Icon(
                Icons.library_music_outlined,
                color: AiToolsTheme.textPrimary,
              ),
              tooltip: 'AI Library',
            )
          : null,
      children: [
        _AiToolsGrid(
          tools: kAiTools,
          onToolTap: onToolTap,
          childAspectRatio: 1.65,
        ),
      ],
    );
  }
}

class _AiToolsSectionHeader extends StatelessWidget {
  final VoidCallback? onViewAll;
  final bool showSubtitle;

  const _AiToolsSectionHeader({
    this.onViewAll,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Tools',
                style: TextStyle(
                  color: AiToolsTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 4),
                const Text(
                  'Premium AI studio utilities',
                  style: TextStyle(
                    color: AiToolsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AiToolsTheme.purple,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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

class _AiToolsGrid extends StatelessWidget {
  final List<AiToolItem> tools;
  final void Function(AiToolItem tool) onToolTap;
  final double childAspectRatio;

  const _AiToolsGrid({
    required this.tools,
    required this.onToolTap,
    this.childAspectRatio = 1.65,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: tools.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: _kGridSpacing,
        mainAxisSpacing: _kGridSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _PremiumAiToolCard(
          tool: tool,
          onTap: () => onToolTap(tool),
        );
      },
    );
  }
}

class _PremiumAiToolCard extends StatefulWidget {
  final AiToolItem tool;
  final VoidCallback onTap;

  const _PremiumAiToolCard({
    required this.tool,
    required this.onTap,
  });

  @override
  State<_PremiumAiToolCard> createState() => _PremiumAiToolCardState();
}

class _PremiumAiToolCardState extends State<_PremiumAiToolCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController;
  Offset _pointer = Offset.zero;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  Offset _magneticOffset(Size size) {
    if (!_hovered || size.isEmpty) {
      return Offset.zero;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final delta = _pointer - center;
    return Offset(delta.dx * 0.035, delta.dy * 0.035);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pointer = Offset.zero;
      }),
      onHover: (event) => setState(() => _pointer = event.localPosition),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final scale = _pressed ? 0.985 : (_hovered ? 1.025 : 1.0);
            final elevation = _hovered ? 18.0 : 10.0;
            final magnetic = _magneticOffset(size);

            return AnimatedBuilder(
              animation: _gradientController,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.identity()
                    ..translate(magnetic.dx, magnetic.dy)
                    ..scale(scale, scale, 1.0),
                  transformAlignment: Alignment.center,
                  child: child,
                );
              },
              child: _buildCardSurface(size, elevation),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardSurface(Size size, double elevation) {
    final glowAlignment = _hovered && size.width > 0
        ? Alignment(
            ((_pointer.dx / size.width) * 2) - 1,
            ((_pointer.dy / size.height) * 2) - 1,
          )
        : Alignment.topLeft;
    final gradientShift = _gradientController.value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCardRadius),
            color: AiToolsTheme.card.withValues(alpha: 0.82),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovered ? 0.14 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tool.gradientColors.first
                    .withValues(alpha: _hovered ? 0.22 : 0.1),
                blurRadius: elevation,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1 + (gradientShift * 0.35),
                        -1,
                      ),
                      end: Alignment(
                        1 - (gradientShift * 0.35),
                        1,
                      ),
                      colors: [
                        widget.tool.gradientColors.first
                            .withValues(alpha: 0.22),
                        widget.tool.gradientColors.last
                            .withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (_hovered)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: glowAlignment,
                        radius: 0.85,
                        colors: [
                          widget.tool.gradientColors.first
                              .withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconBadge(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tool.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AiToolsTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.tool.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AiToolsTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.12,
                          ),
                        ),
                      ],
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

  Widget _buildIconBadge() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.tool.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.tool.gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          widget.tool.icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
