import 'package:beatjerky/models/challenge_models.dart';
import 'package:beatjerky/screens/studio/challenge_leaderboard_screen.dart';
import 'package:beatjerky/screens/studio/new_challenge_screen.dart';
import 'package:beatjerky/screens/studio/record_challenge_entry_screen.dart';
import 'package:beatjerky/screens/studio/studio_flow_theme.dart';
import 'package:beatjerky/services/challenge_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChallengesFeedScreen extends StatelessWidget {
  const ChallengesFeedScreen({super.key});

  void _openEntries(BuildContext context, Challenge challenge) {
    openChallengeLeaderboard(context, challengeId: challenge.id);
  }

  Future<void> _openEntry(BuildContext context, Challenge challenge) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppToast.show('Please sign in first');
      return;
    }
    if (challenge.isOwnedBy(uid)) {
      _openEntries(context, challenge);
      return;
    }
    try {
      if (!challenge.hasJoined(uid)) {
        await ChallengeService.joinChallenge(challenge.id);
      }
      if (!context.mounted) return;
      openRecordChallengeEntry(context, challengeId: challenge.id);
    } catch (e) {
      AppToast.show(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: StudioFlowTheme.background,
      body: StudioFlowBackground(
        child: SafeArea(
          child: StreamBuilder<List<Challenge>>(
            stream: ChallengeService.watchFeed(),
            builder: (context, snapshot) {
              final challenges = snapshot.data ?? const <Challenge>[];
              Challenge? featured;
              for (final c in challenges) {
                if (c.isFeatured || c.isOfficial) {
                  featured = c;
                  break;
                }
              }
              featured ??= challenges.isNotEmpty ? challenges.first : null;
              final featuredChallenge = featured;
              final rest = challenges
                  .where((c) =>
                      featuredChallenge == null || c.id != featuredChallenge.id)
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '01 · CHALLENGE FEED',
                            style: TextStyle(
                              color: StudioFlowTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ChallengesHeader(
                            onCreate: () => openNewChallenge(context),
                          ),
                          const SizedBox(height: 18),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: recntsColor,
                                ),
                              ),
                            )
                          else if (featuredChallenge != null)
                            _FeaturedChallengeCard(
                              challenge: featuredChallenge,
                              isMine: featuredChallenge.isOwnedBy(myUid),
                              alreadyJoined:
                                  featuredChallenge.hasJoined(myUid),
                              onPrimary: () => featuredChallenge.isOwnedBy(myUid)
                                  ? _openEntries(context, featuredChallenge)
                                  : _openEntry(context, featuredChallenge),
                              onEntries: () =>
                                  _openEntries(context, featuredChallenge),
                            )
                          else
                            _EmptyFeedCard(
                              onCreate: () => openNewChallenge(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (rest.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final challenge = rest[index];
                            final isMine = challenge.isOwnedBy(myUid);
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == rest.length - 1 ? 0 : 12,
                              ),
                              child: _ChallengeFeedCard(
                                challenge: challenge,
                                isMine: isMine,
                                alreadyJoined: challenge.hasJoined(myUid),
                                onPrimary: () => isMine
                                    ? _openEntries(context, challenge)
                                    : _openEntry(context, challenge),
                                onEntries: () =>
                                    _openEntries(context, challenge),
                              ),
                            );
                          },
                          childCount: rest.length,
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyFeedCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudioFlowTheme.border),
      ),
      child: Column(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          const Text(
            'No challenges yet',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create the first one and invite artists to compete.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onCreate,
            style: TextButton.styleFrom(foregroundColor: recntsColor),
            child: const Text(
              '+ Create Challenge',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengesHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _ChallengesHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudioBackButton(onPressed: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '🔥 Challenges',
            style: TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCreate,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                gradient: buttonGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool isMine;
  final bool alreadyJoined;
  final VoidCallback onPrimary;
  final VoidCallback onEntries;

  const _FeaturedChallengeCard({
    required this.challenge,
    required this.isMine,
    required this.alreadyJoined,
    required this.onPrimary,
    required this.onEntries,
  });

  String get _badgeLabel {
    if (isMine) return 'YOUR CHALLENGE';
    if (challenge.isOfficial) return 'OFFICIAL BJ CHALLENGE';
    return 'FEATURED';
  }

  String get _ctaLabel {
    if (isMine) return 'View entries';
    if (alreadyJoined) return 'Continue';
    return 'Accept';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1848), Color(0xFF1F1535), Color(0xFF15102A)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: recntsColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: recntsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: recntsColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMine ? Icons.person_rounded : Icons.star_rounded,
                      color: recntsColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _badgeLabel,
                      style: const TextStyle(
                        color: recntsColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                challenge.endsInLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            challenge.title,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isMine
                ? 'Others Accept this — you watch entries and pick a winner.'
                : (challenge.description.isEmpty
                    ? 'Record your hottest hook over this beat.'
                    : challenge.description),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (challenge.prizeText != null &&
              challenge.prizeText!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: recntsColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💰 ${challenge.prizeText}',
                    style: const TextStyle(
                      color: recntsColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (challenge.sponsorName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sponsored by ${challenge.sponsorName}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: onEntries,
                child: Text(
                  challenge.entriesLabel,
                  style: TextStyle(
                    color: recntsColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: recntsColor.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                ),
              ),
              Text(
                challenge.viewsLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPrimary,
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: buttonGradient,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isMine ? '📊' : '🎤',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _ctaLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeFeedCard extends StatelessWidget {
  final Challenge challenge;
  final bool isMine;
  final bool alreadyJoined;
  final VoidCallback onPrimary;
  final VoidCallback onEntries;

  const _ChallengeFeedCard({
    required this.challenge,
    required this.isMine,
    required this.alreadyJoined,
    required this.onPrimary,
    required this.onEntries,
  });

  String get _ctaLabel {
    if (isMine) return 'Manage';
    if (alreadyJoined) return 'Continue';
    return 'Join';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioFlowTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMine
              ? recntsColor.withValues(alpha: 0.4)
              : StudioFlowTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: indigoColor,
                backgroundImage:
                    (challenge.creatorPhoto != null &&
                            challenge.creatorPhoto!.isNotEmpty)
                        ? NetworkImage(challenge.creatorPhoto!)
                        : null,
                child: (challenge.creatorPhoto == null ||
                        challenge.creatorPhoto!.isEmpty)
                    ? Text(
                        challenge.creatorInitial,
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
                    Text(
                      isMine ? 'You' : challenge.creatorName,
                      style: const TextStyle(
                        color: StudioFlowTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isMine)
                      const Text(
                        'Your challenge',
                        style: TextStyle(
                          color: recntsColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                challenge.timeAgoLabel,
                style: const TextStyle(
                  color: StudioFlowTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            challenge.title,
            style: const TextStyle(
              color: StudioFlowTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.hashtagsLabel,
            style: const TextStyle(
              color: recntsColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1016),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        recntsColor.withValues(alpha: 0.5),
                        indigoColor.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🎹', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.beat.title,
                        style: const TextStyle(
                          color: StudioFlowTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        challenge.beat.hasAudio
                            ? challenge.beat.metaLabel
                            : 'No audio attached',
                        style: const TextStyle(
                          color: StudioFlowTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1F26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    challenge.beat.hasAudio
                        ? Icons.music_note_rounded
                        : Icons.music_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Color(0xFFFF8A8A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      challenge.daysLeftLabel,
                      style: const TextStyle(
                        color: Color(0xFFFF8A8A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onEntries,
                child: Text(
                  challenge.entriesLabel,
                  style: const TextStyle(
                    color: StudioFlowTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPrimary,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: buttonGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _ctaLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isMine
                              ? Icons.insights_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void openChallengesFeed(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ChallengesFeedScreen()),
  );
}
