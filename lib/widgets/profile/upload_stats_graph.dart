import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/home_stats_service.dart';

class UploadStatsGraph extends StatelessWidget {
  final UploadTimeSeries data;

  const UploadStatsGraph({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final labels = data.monthLabels;
    final n = labels.length;
    final xLabelStep = n <= 4 ? 1 : (n / 4).ceil();
    final songsSpots = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), data.songsY[i]),
    );
    final reelsSpots = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), data.reelsY[i]),
    );
    final postsSpots = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), data.postsY[i]),
    );
    final viewsSpots = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), data.viewsY[i]),
    );
    final maxY = [
      data.songsY.isEmpty ? 0 : data.songsY.reduce((a, b) => a > b ? a : b),
      data.reelsY.isEmpty ? 0 : data.reelsY.reduce((a, b) => a > b ? a : b),
      data.postsY.isEmpty ? 0 : data.postsY.reduce((a, b) => a > b ? a : b),
      data.viewsY.isEmpty ? 0 : data.viewsY.reduce((a, b) => a > b ? a : b),
    ].reduce((a, b) => a > b ? a : b);
    final maxYAxis = (maxY + (maxY > 0 ? 1 : 0)).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your uploads',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (n > 1 ? n - 1 : 0).toDouble(),
                  minY: 0,
                  maxY: maxYAxis,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    verticalInterval: n > 1
                        ? ((n - 1) / 6).clamp(0.5, double.infinity)
                        : 1,
                    horizontalInterval: maxYAxis > 0
                        ? (maxYAxis / 8).clamp(0.5, double.infinity)
                        : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.12),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: maxYAxis > 0
                            ? (maxYAxis / 8).clamp(0.5, double.infinity)
                            : 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < labels.length) {
                            if (i % xLabelStep != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[i],
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _lineBar(songsSpots, Colors.purple),
                    _lineBar(reelsSpots, const Color(0xFF03DAC6)),
                    _lineBar(postsSpots, Colors.orange),
                    _lineBar(viewsSpots, Colors.green),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((s) {
                          final label = switch (s.barIndex) {
                            0 => 'Songs',
                            1 => 'Reels',
                            2 => 'Feeds',
                            _ => 'Views',
                          };
                          return LineTooltipItem(
                            '$label: ${s.y.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                      getTooltipColor: (_) => Colors.black87,
                      tooltipBorder: const BorderSide(color: Colors.white24),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.purple, 'Songs'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFF03DAC6), 'Reels'),
                const SizedBox(width: 12),
                _legendDot(Colors.orange, 'Feeds'),
                const SizedBox(width: 12),
                _legendDot(Colors.green, 'Views'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 1,
          strokeColor: Colors.white.withValues(alpha: 0.6),
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class UploadStatsGraphShimmer extends StatelessWidget {
  const UploadStatsGraphShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey,
              highlightColor: Colors.grey,
              child: Container(
                height: 16,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Shimmer.fromColors(
              baseColor: Colors.grey,
              highlightColor: Colors.grey,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
