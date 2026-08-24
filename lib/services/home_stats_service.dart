import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef UploadTimeSeries = ({
  List<String> monthLabels,
  List<double> songsY,
  List<double> reelsY,
  List<double> postsY,
  List<double> viewsY,
});

class HomeStatsService {
  static const _graphCacheKey = 'home1_graph_cache';
  static const _graphCacheTimestampKey = 'home1_graph_timestamp';

  static List<DateTime> _datesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <DateTime>[];
    for (final doc in docs) {
      final t = doc.data()['timestamp'];
      if (t == null) continue;
      if (t is Timestamp) out.add(t.toDate());
    }
    return out;
  }

  static String _monthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[month - 1];
  }

  static Future<UploadTimeSeries?> _loadCachedGraphData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_graphCacheKey);
      if (cached == null) return null;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      return (
        monthLabels: List<String>.from(data['monthLabels'] ?? []),
        songsY: List<double>.from(
          (data['songsY'] ?? []).map((e) => (e as num).toDouble()),
        ),
        reelsY: List<double>.from(
          (data['reelsY'] ?? []).map((e) => (e as num).toDouble()),
        ),
        postsY: List<double>.from(
          (data['postsY'] ?? []).map((e) => (e as num).toDouble()),
        ),
        viewsY: List<double>.from(
          (data['viewsY'] ?? []).map((e) => (e as num).toDouble()),
        ),
      );
    } catch (e) {
      log('Error loading cached graph data: $e');
      return null;
    }
  }

  static Future<void> _saveGraphDataToCache(UploadTimeSeries data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'monthLabels': data.monthLabels,
        'songsY': data.songsY,
        'reelsY': data.reelsY,
        'postsY': data.postsY,
        'viewsY': data.viewsY,
      };
      await prefs.setString(_graphCacheKey, jsonEncode(cacheData));
      await prefs.setInt(
        _graphCacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      log('Error saving graph data to cache: $e');
    }
  }

  static Future<UploadTimeSeries> fetchUploadTimeSeries({
    required String userId,
    bool forceRefresh = false,
  }) async {
    if (userId.isEmpty) {
      return (
        monthLabels: ['No data'],
        songsY: [0.0],
        reelsY: [0.0],
        postsY: [0.0],
        viewsY: [0.0],
      );
    }

    if (!forceRefresh) {
      final cached = await _loadCachedGraphData();
      if (cached != null) {
        fetchUploadTimeSeries(userId: userId, forceRefresh: true).then((fresh) {
          _saveGraphDataToCache(fresh);
        });
        return cached;
      }
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('songs')
            .where('userId', isEqualTo: userId)
            .get(),
        FirebaseFirestore.instance
            .collection('reels')
            .where('userId', isEqualTo: userId)
            .get(),
        FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .get(),
      ]);
      final songDates = _datesFromDocs(results[0].docs);
      final reelDates = _datesFromDocs(results[1].docs);
      final postDates = _datesFromDocs(results[2].docs);

      final allMonths = <DateTime>{};
      void addMonths(List<DateTime> dates) {
        for (final d in dates) {
          allMonths.add(DateTime(d.year, d.month));
        }
      }

      addMonths(songDates);
      addMonths(reelDates);
      addMonths(postDates);

      if (allMonths.isEmpty) {
        return (
          monthLabels: ['No data'],
          songsY: [0.0],
          reelsY: [0.0],
          postsY: [0.0],
          viewsY: [0.0],
        );
      }

      final sorted = allMonths.toList()..sort();
      final monthLabels = sorted
          .map(
            (m) => '${_monthShort(m.month)} ${m.year.toString().substring(2)}',
          )
          .toList();
      final songsY = <double>[];
      final reelsY = <double>[];
      final postsY = <double>[];
      final viewsY = <double>[];

      final reelDocs = results[1].docs;
      final postDocs = results[2].docs;

      for (final monthStart in sorted) {
        final monthEnd = DateTime(
          monthStart.year,
          monthStart.month + 1,
          0,
          23,
          59,
          59,
        );

        songsY.add(
          songDates
              .where(
                (d) => d.isBefore(monthEnd.add(const Duration(seconds: 1))),
              )
              .length
              .toDouble(),
        );
        reelsY.add(
          reelDates
              .where(
                (d) => d.isBefore(monthEnd.add(const Duration(seconds: 1))),
              )
              .length
              .toDouble(),
        );
        postsY.add(
          postDates
              .where(
                (d) => d.isBefore(monthEnd.add(const Duration(seconds: 1))),
              )
              .length
              .toDouble(),
        );

        int totalViews = 0;
        for (final reelDoc in reelDocs) {
          final reelData = reelDoc.data();
          final reelTimestamp = reelData['timestamp'];
          if (reelTimestamp == null) continue;
          final reelDate = (reelTimestamp as Timestamp).toDate();
          if (reelDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            final views = reelData['views'] is int ? reelData['views'] as int : 0;
            totalViews += views;
          }
        }

        for (final postDoc in postDocs) {
          final postData = postDoc.data();
          final postTimestamp = postData['timestamp'];
          if (postTimestamp == null) continue;
          final postDate = (postTimestamp as Timestamp).toDate();
          if (postDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            final impressions = postData['impressions'] is int
                ? postData['impressions'] as int
                : (postData['views'] is int ? postData['views'] as int : 0);
            totalViews += impressions;
          }
        }

        viewsY.add(totalViews.toDouble());
      }

      final result = (
        monthLabels: monthLabels,
        songsY: songsY,
        reelsY: reelsY,
        postsY: postsY,
        viewsY: viewsY,
      );

      await _saveGraphDataToCache(result);
      return result;
    } catch (_) {
      final cached = await _loadCachedGraphData();
      if (cached != null) return cached;

      return (
        monthLabels: ['No data'],
        songsY: [0.0],
        reelsY: [0.0],
        postsY: [0.0],
        viewsY: [0.0],
      );
    }
  }

  static int delta(List<double> ys) {
    if (ys.length < 2) return 0;
    return (ys.last - ys[ys.length - 2]).round().clamp(0, 9999);
  }

  static int viewsPercent(List<double> ys) {
    if (ys.length < 2) return 0;
    final prev = ys[ys.length - 2];
    if (prev == 0) return ys.last > 0 ? 100 : 0;
    return (((ys.last - prev) / prev) * 100).round().clamp(0, 999);
  }
}
