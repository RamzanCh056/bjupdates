import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../screens/professional_dashboard_screen.dart';

class ProfessionalDashboardCard extends StatelessWidget {
  final String userId;

  const ProfessionalDashboardCard({super.key, required this.userId});

  Future<int> _viewsLast30Days() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    int total = 0;

    Future<void> addViews(String collection) async {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        DateTime? date;
        if (ts is Timestamp) date = ts.toDate();
        if (date == null || date.isBefore(since)) continue;

        final views = data['views'];
        if (views is int) {
          total += views;
          continue;
        }
        final impressions = data['impressions'];
        if (impressions is int) total += impressions;
      }
    }

    await addViews('reels');
    await addViews('posts');
    return total;
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _openDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessionalDashboardScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDashboard(context),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: FutureBuilder<int>(
              future: _viewsLast30Days(),
              builder: (context, snapshot) {
                final views = snapshot.data ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Professional dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                color: Colors.green.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Loading views...'
                                      : '${_formatCount(views)} views in the last 30 days.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: 0.65,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
