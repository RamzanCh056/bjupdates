import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'studio_flow_theme.dart';

class CollabPhaseIndicator extends StatelessWidget {
  final int currentPhase;
  final int totalPhases;
  final String label;

  const CollabPhaseIndicator({
    super.key,
    required this.currentPhase,
    this.totalPhases = 3,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final completed = currentPhase - 1;
    final remaining = totalPhases - currentPhase;

    return Row(
      children: [
        ...List.generate(completed, (_) {
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: recntsColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        Container(
          width: 34,
          height: 6,
          decoration: BoxDecoration(
            color: recntsColor,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: recntsColor.withValues(alpha: 0.35),
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
          'Phase $currentPhase of $totalPhases · $label',
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
