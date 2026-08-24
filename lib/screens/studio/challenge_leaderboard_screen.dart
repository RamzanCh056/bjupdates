import 'package:beatjerky/models/challenge_models.dart';
import 'package:beatjerky/screens/studio/challenge_winner_screen.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/challenge_service.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChallengeLeaderboardScreen extends StatelessWidget {
  final String challengeId;

  const ChallengeLeaderboardScreen({
    super.key,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: StreamBuilder<Challenge?>(
            stream: ChallengeService.watchChallenge(challengeId),
            builder: (context, challengeSnap) {
              final challenge = challengeSnap.data;

              return StreamBuilder<List<ChallengeEntry>>(
                stream: ChallengeService.watchLeaderboard(challengeId),
                builder: (context, entriesSnap) {
                  final entries =
                      entriesSnap.data ?? const <ChallengeEntry>[];
                  ChallengeEntry? myEntry;
                  var myRank = 0;
                  if (myUid != null) {
                    for (var i = 0; i < entries.length; i++) {
                      if (entries[i].userId == myUid) {
                        myEntry = entries[i];
                        myRank = i + 1;
                        break;
                      }
                    }
                  }

                  final topEntries = entries.take(20).toList();

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '04 · LEADERBOARD',
                                style: TextStyle(
                                  color: StudioFlowTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _LeaderboardAppBar(
                                onBack: () => Navigator.maybePop(context),
                                hashtag: challenge?.primaryHashtag ??
                                    '#BeatChallenge',
                                title: challenge?.title ?? 'Challenge',
                                endsIn: challenge?.endsInLabel ?? '',
                              ),
                              const SizedBox(height: 14),
                              _ScoringStatsBar(
                                entryCount: challenge?.entryCount ??
                                    entries.length,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (entriesSnap.connectionState ==
                              ConnectionState.waiting &&
                          !entriesSnap.hasData)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(color: recntsColor),
                          ),
                        )
                      else if (topEntries.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No entries yet. Be the first to submit!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = topEntries[index];
                                final rank = index + 1;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _LeaderboardRankCard(
                                    rank: rank,
                                    entry: entry,
                                    isMe: entry.userId == myUid,
                                    highlightBorder:
                                        rank == 1 || entry.userId == myUid,
                                    onTap: rank == 1
                                        ? () => openChallengeWinner(
                                              context,
                                              challengeId: challengeId,
                                              entry: entry,
                                              challengeTitle: challenge?.title,
                                              hashtag: challenge?.primaryHashtag,
                                              totalEntries:
                                                  challenge?.entryCount ??
                                                      entries.length,
                                            )
                                        : null,
                                  ),
                                );
                              },
                              childCount: topEntries.length,
                            ),
                          ),
                        ),
                      if (myEntry != null && myRank > 20)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          sliver: SliverToBoxAdapter(
                            child: _LeaderboardRankCard(
                              rank: myRank,
                              entry: myEntry,
                              isMe: true,
                              highlightBorder: true,
                            ),
                          ),
                        )
                      else
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LeaderboardAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final String hashtag;
  final String title;
  final String endsIn;

  const _LeaderboardAppBar({
    required this.onBack,
    required this.hashtag,
    required this.title,
    required this.endsIn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🏆', style: TextStyle(fontSize: 24, height: 1)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: hashtag,
                      style: const TextStyle(
                        color: recntsColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' · $title'),
                    if (endsIn.isNotEmpty) TextSpan(text: ' · $endsIn'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoringStatsBar extends StatelessWidget {
  final int entryCount;

  const _ScoringStatsBar({required this.entryCount});

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,###').format(entryCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Row(
        children: [
          const Expanded(child: _StatColumn(label: 'Views', value: '×0.4')),
          const Expanded(child: _StatColumn(label: 'Likes', value: '×0.4')),
          const Expanded(child: _StatColumn(label: 'Shares', value: '×0.2')),
          Expanded(
            child: _StatColumn(
              label: formatted,
              value: 'entries',
              accentLabel: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool accentLabel;

  const _StatColumn({
    required this.label,
    required this.value,
    this.accentLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accentLabel
                ? recntsColor
                : Colors.white.withValues(alpha: 0.4),
            fontSize: accentLabel ? 14 : 11,
            fontWeight: accentLabel ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: recntsColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRankCard extends StatelessWidget {
  final int rank;
  final ChallengeEntry entry;
  final bool isMe;
  final bool highlightBorder;
  final VoidCallback? onTap;

  const _LeaderboardRankCard({
    required this.rank,
    required this.entry,
    this.isMe = false,
    this.highlightBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreLabel = NumberFormat('#,###').format(entry.score.round());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: StudioFlowTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlightBorder
                  ? recntsColor.withValues(alpha: 0.45)
                  : StudioFlowTheme.border,
            ),
          ),
          child: Row(
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: indigoColor,
                backgroundImage:
                    (entry.userPhoto != null && entry.userPhoto!.isNotEmpty)
                        ? NetworkImage(entry.userPhoto!)
                        : null,
                child: (entry.userPhoto == null || entry.userPhoto!.isEmpty)
                    ? Text(
                        entry.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMe ? 'You' : entry.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMe
                                  ? recntsColor
                                  : StudioFlowTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (rank == 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  StudioFlowTheme.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: StudioFlowTheme.gold
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              '⭐ Top',
                              style: TextStyle(
                                color: StudioFlowTheme.gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.durationLabel} · ${_compact(entry.views)} views · ${_compact(entry.likes)} likes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    scoreLabel,
                    style: const TextStyle(
                      color: recntsColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Score',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    if (rank == 1) return const Text('🥇', style: TextStyle(fontSize: 26));
    if (rank == 2) return const Text('🥈', style: TextStyle(fontSize: 26));
    if (rank == 3) return const Text('🥉', style: TextStyle(fontSize: 26));

    final label = rank >= 10 ? '#$rank' : '$rank';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        shape: BoxShape.circle,
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: rank >= 10 ? recntsColor : StudioFlowTheme.textMuted,
            fontSize: rank >= 10 ? 10 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

void openChallengeLeaderboard(
  BuildContext context, {
  required String challengeId,
  bool replace = false,
}) {
  final route = MaterialPageRoute(
    builder: (_) => ChallengeLeaderboardScreen(challengeId: challengeId),
  );
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}
