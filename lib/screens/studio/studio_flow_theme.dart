import 'package:flutter/material.dart';

class StudioFlowTheme {
  StudioFlowTheme._();

  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF15181F);
  static const Color surfaceElevated = Color(0xFF1A1D24);
  static const Color card = Color(0xFF1A1030);
  static const Color purple = Color(0xFFA855F7);
  static const Color purpleDark = Color(0xFF6D28D9);
  static const Color gold = Color(0xFFFBBF24);
  static const Color silver = Color(0xFFC8C8D0);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color dotInactive = Color(0xFF3A3A45);
  static const Color border = Color(0x24FFFFFF);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1848), Color(0xFF1A1030), Color(0xFF120A22)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
  );

  static const RadialGradient orbGradient = RadialGradient(
    colors: [Color(0x66A855F7), Color(0x1AA855F7), Color(0x000B0B0F)],
  );
}

class StudioFlowBackground extends StatelessWidget {
  final Widget child;

  const StudioFlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: StudioFlowTheme.background),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StudioFlowTheme.purple.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: -50,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StudioFlowTheme.purpleDark.withValues(alpha: 0.06),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class StudioFlowScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottomBar;
  final bool showBack;
  final Widget? titleTrailing;

  const StudioFlowScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.currentStep,
    this.totalSteps = 4,
    required this.child,
    this.onBack,
    this.bottomBar,
    this.showBack = true,
    this.titleTrailing,
  });

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showBack)
                          StudioBackButton(
                            onPressed:
                                onBack ?? () => Navigator.maybePop(context),
                          )
                        else
                          const SizedBox(width: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: StudioFlowTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              if (titleTrailing != null) titleTrailing!,
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: Text(
                          subtitle!,
                          style: const TextStyle(
                            color: StudioFlowTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    StudioStepIndicator(
                      currentStep: currentStep,
                      totalSteps: totalSteps,
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      ),
    );
  }
}

class StudioBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const StudioBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1F26),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: StudioFlowTheme.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class StudioStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StudioStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    final completed = currentStep - 1;
    final remaining = totalSteps - currentStep;

    return Row(
      children: [
        ...List.generate(completed, (_) {
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: StudioFlowTheme.purple,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        Container(
          width: 34,
          height: 6,
          decoration: BoxDecoration(
            color: StudioFlowTheme.purple,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: StudioFlowTheme.purple.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        ...List.generate(remaining, (_) {
          return Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: StudioFlowTheme.dotInactive,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        Text(
          'Step $currentStep of $totalSteps',
          style: const TextStyle(
            color: StudioFlowTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class StudioWaveform extends StatelessWidget {
  final List<double> heights;
  final Color color;
  final double height;

  const StudioWaveform({
    super.key,
    required this.heights,
    this.color = StudioFlowTheme.purple,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: heights.map((factor) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: height * factor.clamp(0.1, 1.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StudioDetectedBadge extends StatelessWidget {
  const StudioDetectedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: StudioFlowTheme.purple,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: StudioFlowTheme.purple.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Text(
        'Detected',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class StudioFooterTip extends StatelessWidget {
  final String text;

  const StudioFooterTip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          size: 17,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
