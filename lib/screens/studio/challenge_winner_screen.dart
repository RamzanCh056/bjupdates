import 'package:beatjerky/models/challenge_models.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';

class ChallengeWinnerScreen extends StatelessWidget {
  final String? challengeId;
  final ChallengeEntry? entry;
  final String? challengeTitle;
  final String? hashtag;
  final int? totalEntries;

  const ChallengeWinnerScreen({
    super.key,
    this.challengeId,
    this.entry,
    this.challengeTitle,
    this.hashtag,
    this.totalEntries,
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
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      const Text(
                        '05 · YOU WON!',
                        style: TextStyle(
                          color: StudioFlowTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🎉   🥳   🎉',
                        style: TextStyle(fontSize: 22, height: 1.2),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              StudioFlowTheme.gold.withValues(alpha: 0.35),
                              recntsColor.withValues(alpha: 0.25),
                            ],
                          ),
                          border: Border.all(
                            color: StudioFlowTheme.gold.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: StudioFlowTheme.gold.withValues(alpha: 0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🏆', style: TextStyle(fontSize: 44)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'You Won! 🥇',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: StudioFlowTheme.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '#BJDarkTrap Challenge · You ranked #1 out of 2,418 entries',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _WinningEntryCard(),
                      const SizedBox(height: 14),
                      const _RewardsCard(),
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
                        onTap: () => AppToast.show('Sharing your win!'),
                        borderRadius: BorderRadius.circular(27),
                        child: const Center(
                          child: Text(
                            '🎂 Share Your Win',
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

class _WinningEntryCard extends StatelessWidget {
  const _WinningEntryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A1848),
            Color(0xFF1F1535),
            Color(0xFF15102A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: recntsColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  indigoColor.withValues(alpha: 0.85),
                  recntsColor.withValues(alpha: 0.9),
                  StudioFlowTheme.gold.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('🎤', style: TextStyle(fontSize: 42)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your Winning Entry',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: StudioFlowTheme.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: StudioFlowTheme.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  '🥇 #1 Winner',
                  style: TextStyle(
                    color: StudioFlowTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: recntsColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: recntsColor.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  '⭐ Featured 48h',
                  style: TextStyle(
                    color: recntsColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _WinStat(value: '3.2K', label: 'Views')),
              Expanded(child: _WinStat(value: '1.4K', label: 'Likes')),
              Expanded(child: _WinStat(value: '892', label: 'Shares')),
              Expanded(child: _WinStat(value: '9,840', label: 'Score')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinStat extends StatelessWidget {
  final String value;
  final String label;

  const _WinStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: StudioFlowTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RewardsCard extends StatelessWidget {
  const _RewardsCard();

  static const _rewards = [
    (emoji: '⭐', text: 'Permanent "Challenge Winner" badge on your profile'),
    (emoji: '🏠', text: 'Your track featured on Home screen for 48 hours'),
    (emoji: '🔔', text: 'Push notification sent to all your followers'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR REWARDS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ..._rewards.map((reward) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reward.text,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

void openChallengeWinner(
  BuildContext context, {
  String? challengeId,
  ChallengeEntry? entry,
  String? challengeTitle,
  String? hashtag,
  int? totalEntries,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChallengeWinnerScreen(
        challengeId: challengeId,
        entry: entry,
        challengeTitle: challengeTitle,
        hashtag: hashtag,
        totalEntries: totalEntries,
      ),
    ),
  );
}
