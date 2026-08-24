import 'dart:ui';

import 'package:flutter/material.dart';

class AiToolsTheme {
  static const Color background = Color(0xFF050816);
  static const Color backgroundElevated = Color(0xFF070B1A);
  static const Color card = Color(0xFF0D1224);
  static const Color cardElevated = Color(0xFF11182C);
  static const Color border = Color(0x1AFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A7B8);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color pink = Color(0xFFF107A3);
  static const Color electricBlue = Color(0xFF4CC9F0);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient ambientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1A7B2FF7),
      Color(0x00050816),
      Color(0x144CC9F0),
    ],
  );

  static const double radiusLg = 24;
  static const double radiusMd = 20;
  static const double radiusSm = 16;
  static const EdgeInsets screenPadding =
      EdgeInsets.fromLTRB(20, 8, 20, 28);
}

class AiToolsScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onInfo;
  final Widget? topAction;
  final Widget? bottomNavigationBar;

  const AiToolsScreen({
    super.key,
    required this.title,
    required this.children,
    this.onInfo,
    this.topAction,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiToolsTheme.background,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const AiToolsAmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                AiToolsTopBar(
                  title: title,
                  onInfo: onInfo,
                  trailing: topAction,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: AiToolsTheme.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
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

class AiToolsGeneratingOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? progress;

  const AiToolsGeneratingOverlay({
    super.key,
    required this.title,
    this.subtitle = 'This can take a few minutes',
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final progressValue = progress;
    final showPercent = progressValue != null && progressValue > 0;

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showPercent) ...[
                    Text(
                      '$progressValue%',
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 240,
                        height: 6,
                        child: LinearProgressIndicator(
                          value: (progressValue / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0x33FFFFFF),
                          color: AiToolsTheme.purple,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(
                      width: 240,
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        backgroundColor: Color(0x33FFFFFF),
                        color: AiToolsTheme.purple,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AiToolsTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AiToolsAmbientBackground extends StatelessWidget {
  const AiToolsAmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AiToolsTheme.ambientGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiToolsTheme.purple.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiToolsTheme.electricBlue.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiToolsTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onInfo;
  final Widget? trailing;

  const AiToolsTopBar({
    super.key,
    required this.title,
    this.onInfo,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AiToolsTheme.textPrimary,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AiToolsTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onInfo != null)
            IconButton(
              onPressed: onInfo,
              icon: const Icon(
                Icons.info_outline_rounded,
                color: AiToolsTheme.textPrimary,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class AiToolsSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AiToolsSectionTitle({
    super.key,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AiToolsGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const AiToolsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AiToolsTheme.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: AiToolsTheme.card.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AiToolsTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AiToolsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const AiToolsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AiToolsTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AiToolsTheme.radiusLg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x337B2FF7),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AiToolsTheme.radiusLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
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
    );
  }
}

class AiToolsOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const AiToolsOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.save_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AiToolsTheme.purple,
          side: const BorderSide(color: AiToolsTheme.purple, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AiToolsTheme.radiusLg),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class AiToolsChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool useGradientWhenSelected;

  const AiToolsChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.useGradientWhenSelected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected && useGradientWhenSelected
                ? AiToolsTheme.primaryGradient
                : null,
            color: isSelected && !useGradientWhenSelected
                ? AiToolsTheme.purple
                : isSelected
                    ? null
                    : AiToolsTheme.cardElevated,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? AiToolsTheme.purple.withValues(alpha: 0.8)
                  : AiToolsTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AiToolsTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class AiToolsTextArea extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final int maxLines;
  final String hintText;

  const AiToolsTextArea({
    super.key,
    required this.controller,
    required this.maxLength,
    this.maxLines = 4,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: hintText,
              hintStyle: const TextStyle(color: AiToolsTheme.textSecondary),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/$maxLength',
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiToolsDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const AiToolsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: AiToolsTheme.radiusSm,
      child: SizedBox(
        height: 48,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: AiToolsTheme.cardElevated,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AiToolsTheme.textSecondary,
            ),
            style: const TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class AiToolsSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? trailing;

  const AiToolsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AiToolsTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              trailing ?? '${(value * 100).round()}%',
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AiToolsTheme.purple,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: AiToolsTheme.purple,
            overlayColor: AiToolsTheme.purple.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class AiToolsToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailingBadge;

  const AiToolsToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: AiToolsTheme.radiusSm,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AiToolsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (trailingBadge != null) ...[
                      const SizedBox(width: 8),
                      trailingBadge!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AiToolsTheme.purple,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class AiToolsIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const AiToolsIconBadge({
    super.key,
    required this.icon,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: AiToolsTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class AiToolsWaveform extends StatelessWidget {
  final List<double> heights;
  final double height;
  final Color color;

  const AiToolsWaveform({
    super.key,
    required this.heights,
    this.height = 34,
    this.color = AiToolsTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: heights.map((factor) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: height * factor,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.72),
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

class AiToolsEmptyState extends StatelessWidget {
  final String message;

  const AiToolsEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AiToolsTheme.textSecondary,
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}

class AiToolsInfoDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiToolsTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AiToolsTheme.radiusSm),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AiToolsTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AiToolsTheme.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: AiToolsTheme.purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<double> kAiToolsWaveformHeights = [
  0.22, 0.38, 0.56, 0.42, 0.68, 0.5, 0.74, 0.58, 0.82, 0.62, 0.78, 0.48,
  0.66, 0.44, 0.6, 0.36, 0.52, 0.3, 0.46, 0.28, 0.4, 0.24, 0.34, 0.2, 0.3,
  0.18, 0.26, 0.16, 0.24, 0.14, 0.2, 0.12, 0.18, 0.1, 0.16, 0.12,
];
