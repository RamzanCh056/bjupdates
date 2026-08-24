import 'package:flutter/material.dart';

import '../services/home_stats_service.dart';
import '../utils/color.dart';
import '../widgets/home/home_screen_widgets.dart';
import '../widgets/profile/upload_stats_graph.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  final String userId;

  const ProfessionalDashboardScreen({super.key, required this.userId});

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  late Future<UploadTimeSeries> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = HomeStatsService.fetchUploadTimeSeries(
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Professional dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<UploadTimeSeries>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 8),
                  HomeStatCardsShimmer(),
                  UploadStatsGraphShimmer(),
                ],
              ),
            );
          }

          final d = snapshot.data!;
          final views = d.viewsY.isEmpty ? 0 : d.viewsY.last.toInt();
          final songs = d.songsY.isEmpty ? 0 : d.songsY.last.toInt();
          final reels = d.reelsY.isEmpty ? 0 : d.reelsY.last.toInt();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                HomeStatCards(
                  views: views,
                  songs: songs,
                  reels: reels,
                  viewsGrowth: '${HomeStatsService.viewsPercent(d.viewsY)}',
                  songsGrowth: '${HomeStatsService.delta(d.songsY)}',
                  reelsGrowth: '${HomeStatsService.delta(d.reelsY)}',
                ),
                UploadStatsGraph(data: d),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
