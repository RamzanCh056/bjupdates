import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const _cardBg = Color(0xFF1A1D23);
const _growthGreen = Color(0xFF4ADE80);

class HomeStatCards extends StatelessWidget {
  final int views;
  final int songs;
  final int reels;
  final String viewsGrowth;
  final String songsGrowth;
  final String reelsGrowth;

  const HomeStatCards({
    super.key,
    required this.views,
    required this.songs,
    required this.reels,
    required this.viewsGrowth,
    required this.songsGrowth,
    required this.reelsGrowth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$views',
              label: 'Views',
              growth: viewsGrowth,
              isPercent: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$songs',
              label: 'Songs',
              growth: songsGrowth,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$reels',
              label: 'Reels',
              growth: reelsGrowth,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String growth;
  final bool isPercent;

  const _StatCard({
    required this.value,
    required this.label,
    required this.growth,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final growthText = isPercent ? '↑ $growth%' : '↑ $growth';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            growthText,
            style: const TextStyle(
              color: _growthGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeStatCardsShimmer extends StatelessWidget {
  const HomeStatCardsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[850]!,
                highlightColor: Colors.grey[700]!,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}