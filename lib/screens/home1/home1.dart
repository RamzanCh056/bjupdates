import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:beatjerky/Stripe/SubscriptionHelper.dart';
import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:beatjerky/notification_services/build_notification_widget.dart';
import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:beatjerky/screens/home1/song_player_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'story_creator.dart';
import '../artist_screens/artist_screen.dart';
import '../event_screens/event_screen.dart';
import '../../providers/user_provider.dart';
import '../music_store/music_store_list_screen.dart';
import '../peoples_screen/people.dart';
import '../messages_screen.dart';
import '../store/store_screen.dart';
import '../view_user_profile_screen.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/ai_tools_section.dart';
import '../../widgets/home/live_events_section.dart';
import '../nearby_users_screen.dart';
import '../../services/chat_service.dart';
import '../bjai_screen.dart';
import '../ai_tools/ai_library_screen.dart';
import '../ai_tools/ai_beat_generator_screen.dart';
import '../ai_tools/ai_lyrics_writer_screen.dart';
import '../ai_tools/ai_mood_radio_screen.dart';
import '../ai_tools/ai_music_coach_screen.dart';
import '../ai_tools/ai_vocal_enhancer_screen.dart';
import '../ai_tools/script_to_music_screen.dart';
import '../ai_tools/stem_splitter_screen.dart';
import '../ai_tools/viral_score_predictor_screen.dart';

class Home1 extends StatefulWidget {
  const Home1({super.key});

  @override
  State<Home1> createState() => _Home1State();
}

class _Home1State extends State<Home1> {
  List<Map<String, dynamic>> songs = [];
  List<Map<String, dynamic>> filteredSongs = [];
  final TextEditingController searchController = TextEditingController();
  bool _isLoadingSongs = true;

  List<StoryModel> _stories = [];
  bool _isLoadingStories = true;
  // Track long press
  final FocusNode _searchFocus = FocusNode();

  // Cache for resolved display names to reduce reads
  final Map<String, String> _displayNameCache = {};

  // Responsive Helper
  double r(double size) {
    return size * (MediaQuery.of(context).size.width / 375.0);
  }

  // Resolve a user's display name from Firestore, trying multiple collections/fields
  Future<String> _resolveDisplayName(String userId) async {
    if (userId.isEmpty) return 'Unknown User';
    if (_displayNameCache.containsKey(userId))
      return _displayNameCache[userId]!;

    // Collections to try in order
    final List<String> collections = [
      'usersData',
      'users',
      'stores',
      'userdata',
    ];

    for (final collection in collections) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(userId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          String name = '';
          if ((data['name'] ?? '').toString().trim().isNotEmpty) {
            name = data['name'].toString().trim();
          } else if ((data['userFirstName'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty ||
              (data['userSecondName'] ?? '').toString().trim().isNotEmpty) {
            name =
                '${(data['userFirstName'] ?? '').toString().trim()} ${(data['userSecondName'] ?? '').toString().trim()}'
                    .trim();
          } else if ((data['firstName'] ?? '').toString().trim().isNotEmpty ||
              (data['lastName'] ?? '').toString().trim().isNotEmpty) {
            name =
                '${(data['firstName'] ?? '').toString().trim()} ${(data['lastName'] ?? '').toString().trim()}'
                    .trim();
          }

          if (name.isNotEmpty) {
            _displayNameCache[userId] = name;
            return name;
          }
        }
      } catch (_) {
        // continue trying next collection
      }
    }

    _displayNameCache[userId] = 'Unknown User';
    return 'Unknown User';
  }

  static const String _storiesCacheKey = 'home1_stories';
  static const String _songsCacheKey = 'home1_songs';
  static const String _graphCacheKey = 'home1_graph_data';
  static const String _graphCacheTimestampKey = 'home1_graph_timestamp';

  /// Time-series point: month label and cumulative counts for songs, reels, posts.
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

  /// Loads cached graph data if available
  Future<
    ({
      List<String> monthLabels,
      List<double> songsY,
      List<double> reelsY,
      List<double> postsY,
      List<double> viewsY,
    })?
  >
  _loadCachedGraphData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_graphCacheKey);
      if (cached == null) return null;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      return (
        monthLabels: List<String>.from(data['monthLabels'] ?? []),
        songsY: List<double>.from(
          (data['songsY'] ?? []).map((e) => e.toDouble()),
        ),
        reelsY: List<double>.from(
          (data['reelsY'] ?? []).map((e) => e.toDouble()),
        ),
        postsY: List<double>.from(
          (data['postsY'] ?? []).map((e) => e.toDouble()),
        ),
        viewsY: List<double>.from(
          (data['viewsY'] ?? []).map((e) => e.toDouble()),
        ),
      );
    } catch (e) {
      log('Error loading cached graph data: $e');
      return null;
    }
  }

  /// Saves graph data to cache
  Future<void> _saveGraphDataToCache(
    ({
      List<String> monthLabels,
      List<double> songsY,
      List<double> reelsY,
      List<double> postsY,
      List<double> viewsY,
    })
    data,
  ) async {
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

  /// Fetches time-series data: cumulative uploads by month for songs, reels, posts, and views.
  Future<
    ({
      List<String> monthLabels,
      List<double> songsY,
      List<double> reelsY,
      List<double> postsY,
      List<double> viewsY,
    })
  >
  _fetchUploadTimeSeries({bool forceRefresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return (
        monthLabels: ['No data'],
        songsY: [0.0],
        reelsY: [0.0],
        postsY: [0.0],
        viewsY: [0.0],
      );
    }

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _loadCachedGraphData();
      if (cached != null) {
        // Refresh in background
        _fetchUploadTimeSeries(forceRefresh: true).then((freshData) {
          _saveGraphDataToCache(freshData);
        });
        return cached;
      }
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('songs')
            .where('userId', isEqualTo: uid)
            .get(),
        FirebaseFirestore.instance
            .collection('reels')
            .where('userId', isEqualTo: uid)
            .get(),
        FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: uid)
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

      // Extract views data from reels and posts
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

        // Count uploads
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

        // Calculate total views for content created up to this month
        int totalViews = 0;

        // Sum views from reels created up to this month
        for (final reelDoc in reelDocs) {
          final reelData = reelDoc.data();
          final reelTimestamp = reelData['timestamp'];
          if (reelTimestamp == null) continue;
          final reelDate = (reelTimestamp as Timestamp).toDate();
          if (reelDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            final views = reelData['views'] is int
                ? reelData['views'] as int
                : 0;
            totalViews += views;
          }
        }

        // Sum impressions/views from posts created up to this month
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

      // Save to cache
      await _saveGraphDataToCache(result);

      return result;
    } catch (_) {
      // Try to return cached data if fetch fails
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

  /// Dashboard quick actions that change by role (role-specific buttons).
  // Widget _buildRoleQuickActions(BuildContext context) {
  //   return Consumer<UserStatusProvider>(
  //     builder: (_, userStatus, __) {
  //       final isArtist = userStatus.isArtist;
  //       final canManage = userStatus.canManageVenueAndEvents;
  //       if (!isArtist && !canManage) return const SizedBox(height: 12);

  //       final actions = <Widget>[];
  //       if (isArtist) {
  //         actions.add(
  //           _quickActionChip(
  //             icon: Icons.upload_file,
  //             label: 'Upload Song',
  //             onTap: () {
  //               if (!context.read<UserStatusProvider>().isArtist) {
  //                 AppToast.show('Only Artists can upload songs', isError: true);
  //                 return;
  //               }
  //               showAddSongBottomSheet(context);
  //             },
  //           ),
  //         );
  //       }
  //       if (canManage) {
  //         actions.add(
  //           _quickActionChip(
  //             icon: Icons.event,
  //             label: 'Create Event',
  //             onTap: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (_) => const EventsScreen()),
  //               );
  //             },
  //           ),
  //         );
  //         actions.add(
  //           _quickActionChip(
  //             icon: Icons.store,
  //             label: 'Venue / Store',
  //             onTap: () {
  //               if (!context
  //                   .read<UserStatusProvider>()
  //                   .canManageVenueAndEvents) {
  //                 AppToast.show(
  //                   'Only Organizers and Venues can manage venue/store',
  //                   isError: true,
  //                 );
  //                 return;
  //               }
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (_) => const StoreScreen()),
  //               );
  //             },
  //           ),
  //         );
  //       }
  //       if (actions.isEmpty) return const SizedBox(height: 12);
  //       return Padding(
  //         padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(12)),
  //         child: SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             children: actions
  //                 .map(
  //                   (w) => Padding(
  //                     padding: EdgeInsets.only(right: r(8)),
  //                     child: w,
  //                   ),
  //                 )
  //                 .toList(),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _quickActionChip({
  //   required IconData icon,
  //   required String label,
  //   required VoidCallback onTap,
  // }) {
  //   return Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       onTap: onTap,
  //       borderRadius: BorderRadius.circular(20),
  //       child: Container(
  //         padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(10)),
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             colors: [
  //               const Color(0xFFBB86FC).withOpacity(0.25),
  //               const Color(0xFF03DAC6).withOpacity(0.15),
  //             ],
  //           ),
  //           borderRadius: BorderRadius.circular(20),
  //           border: Border.all(color: const Color(0xFFBB86FC).withOpacity(0.4)),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(icon, size: 18, color: const Color(0xFFBB86FC)),
  //             SizedBox(width: r(6)),
  //             Text(
  //               label,
  //               style: const TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 13,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildStatsCards() removed — stats shown via Professional dashboard on Profile.

  Widget _buildUploadStatsGraph() {
    return FutureBuilder<
      ({
        List<String> monthLabels,
        List<double> songsY,
        List<double> reelsY,
        List<double> postsY,
        List<double> viewsY,
      })
    >(
      future: _fetchUploadTimeSeries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildGraphShimmer();
        }
        final d = snapshot.data!;
        final labels = d.monthLabels;
        final n = labels.length;
        // Try to keep only ~4 labels visible on X axis for readability
        final xLabelStep = n <= 4 ? 1 : (n / 4).ceil();
        final songsSpots = List.generate(
          n,
          (i) => FlSpot(i.toDouble(), d.songsY[i]),
        );
        final reelsSpots = List.generate(
          n,
          (i) => FlSpot(i.toDouble(), d.reelsY[i]),
        );
        final postsSpots = List.generate(
          n,
          (i) => FlSpot(i.toDouble(), d.postsY[i]),
        );
        final viewsSpots = List.generate(
          n,
          (i) => FlSpot(i.toDouble(), d.viewsY[i]),
        );
        final maxY = [
          d.songsY.isEmpty ? 0 : d.songsY.reduce((a, b) => a > b ? a : b),
          d.reelsY.isEmpty ? 0 : d.reelsY.reduce((a, b) => a > b ? a : b),
          d.postsY.isEmpty ? 0 : d.postsY.reduce((a, b) => a > b ? a : b),
          d.viewsY.isEmpty ? 0 : d.viewsY.reduce((a, b) => a > b ? a : b),
        ].reduce((a, b) => a > b ? a : b);
        final maxYAxis = (maxY + (maxY > 0 ? 1 : 0)).toDouble();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(8)),
          child: Container(
            padding: EdgeInsets.all(r(16)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your uploads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: r(16)),
                SizedBox(
                  height: r(200),
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
                          color: Colors.white.withOpacity(0.15),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: r(28),
                            interval: maxYAxis > 0
                                ? (maxYAxis / 8).clamp(0.5, double.infinity)
                                : 1,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: r(10),
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
                                // Only show some labels so they don't overlap
                                if (i % xLabelStep != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: r(9),
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
                        LineChartBarData(
                          spots: songsSpots,
                          isCurved: true,
                          color: Colors.purple,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: Colors.purple,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white.withOpacity(0.6),
                                ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                        LineChartBarData(
                          spots: reelsSpots,
                          isCurved: true,
                          color: const Color(0xFF03DAC6),
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: const Color(0xFF03DAC6),
                                  strokeWidth: 1,
                                  strokeColor: Colors.white.withOpacity(0.6),
                                ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                        LineChartBarData(
                          spots: postsSpots,
                          isCurved: true,
                          color: Colors.orange,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: Colors.orange,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white.withOpacity(0.6),
                                ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                        LineChartBarData(
                          spots: viewsSpots,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: Colors.green,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white.withOpacity(0.6),
                                ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((s) {
                              String label = '';
                              if (s.barIndex == 0)
                                label = 'Songs';
                              else if (s.barIndex == 1)
                                label = 'Reels';
                              else if (s.barIndex == 2)
                                label = 'Feeds';
                              else
                                label = 'Views';
                              return LineTooltipItem(
                                '$label: ${s.y.toInt()}',
                                TextStyle(
                                  color: Colors.white,
                                  fontSize: r(11),
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                          getTooltipColor: (_) => Colors.black87,
                          tooltipBorder: BorderSide(color: Colors.white24),
                          tooltipPadding: EdgeInsets.symmetric(
                            horizontal: r(10),
                            vertical: r(8),
                          ),
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          final barColor = barData.color ?? Colors.grey;
                          return spotIndexes.map((i) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: Colors.white38, strokeWidth: 1.5),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bd, index) =>
                                    FlDotCirclePainter(
                                      radius: 4,
                                      color: barColor,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
                SizedBox(height: r(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(Colors.purple, 'Songs'),
                    SizedBox(width: r(12)),
                    _legendDot(const Color(0xFF03DAC6), 'Reels'),
                    SizedBox(width: r(12)),
                    _legendDot(Colors.orange, 'Feeds'),
                    SizedBox(width: r(12)),
                    _legendDot(Colors.green, 'Views'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        SizedBox(width: r(4)),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: r(11)),
        ),
      ],
    );
  }

  Widget _buildGraphShimmer() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(8)),
      child: Container(
        padding: EdgeInsets.all(r(16)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[850]!,
              highlightColor: Colors.grey[700]!,
              child: Container(
                height: r(16),
                width: r(100),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: r(16)),
            // Graph area shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[850]!,
              highlightColor: Colors.grey[700]!,
              child: Container(
                height: r(200),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: r(8)),
            // Legend shimmer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[850]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: r(60),
                    height: r(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(width: r(12)),
                Shimmer.fromColors(
                  baseColor: Colors.grey[850]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: r(60),
                    height: r(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(width: r(12)),
                Shimmer.fromColors(
                  baseColor: Colors.grey[850]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: r(60),
                    height: r(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(width: r(12)),
                Shimmer.fromColors(
                  baseColor: Colors.grey[850]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: r(60),
                    height: r(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convert a song map to JSON-safe map (Firestore Timestamp → milliseconds).
  Map<String, dynamic> _songToCacheJson(Map<String, dynamic> song) {
    final map = <String, dynamic>{};
    song.forEach((key, value) {
      map[key] = value is Timestamp ? value.millisecondsSinceEpoch : value;
    });
    return map;
  }

  Future<void> _loadSongsFromCacheOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_songsCacheKey);
    bool hadValidCache = false;
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        final loaded = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) {
          setState(() {
            songs = loaded;
            filteredSongs = songs;
            _isLoadingSongs = false;
          });
          hadValidCache = loaded.isNotEmpty;
        }
      } catch (e) {
        print('Error loading songs cache: $e');
      }
    }
    // Only fetch from network when we don't have cached data (avoids refetch when returning to home)
    if (!hadValidCache) await fetchSongs();
  }

  Future<void> _saveSongsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = songs.map((s) => _songToCacheJson(s)).toList();
      await prefs.setString(_songsCacheKey, jsonEncode(list));
    } catch (e) {
      print('Error saving songs cache: $e');
    }
  }

  Future<void> _loadStoriesFromCacheOrFetch() async {
    log('🔄 _loadStoriesFromCacheOrFetch called');
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_storiesCacheKey);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        final now = DateTime.now();
        final loaded = list
            .map(
              (e) =>
                  StoryModel.fromCacheJson(Map<String, dynamic>.from(e as Map)),
            )
            .where((s) => s.expiryTime.isAfter(now))
            .toList();
        if (mounted) {
          setState(() {
            _stories = loaded;
            _isLoadingStories = false; // Set to false after loading cache
          });
          log('📦 Loaded ${loaded.length} stories from cache');
        }
      } catch (e) {
        log('❌ Error loading stories cache: $e');
      }
    } else {
      log('📦 No cached stories found');
    }
    // Always try to fetch from network to get latest stories, but use cache as fallback
    log('🌐 Fetching stories from network...');
    await fetchStories();
  }

  Future<void> _saveStoriesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _stories.map((s) => s.toCacheJson()).toList();
      await prefs.setString(_storiesCacheKey, jsonEncode(list));
    } catch (e) {
      print('Error saving stories cache: $e');
    }
  }

  // Fetch stories from Firebase
  Future<void> fetchStories() async {
    log('🚀 fetchStories() called');
    if (mounted) {
      setState(() => _isLoadingStories = true);
    }

    final now = DateTime.now();
    QuerySnapshot? snapshot;
    bool fetchedAllStories = false;

    // Strategy 1: Try query with orderBy first (requires index)
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('expiryTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiryTime', descending: true)
          .get();
      log(
        '✅ Stories query with orderBy succeeded - found ${snapshot.docs.length} docs',
      );

      // If we got 0 docs, check if there are ANY stories at all (even expired)
      if (snapshot.docs.isEmpty) {
        log(
          '⚠️ No non-expired stories found. Checking if there are any stories in database...',
        );
        try {
          final allStoriesSnapshot = await FirebaseFirestore.instance
              .collection('stories')
              .limit(5) // Just check if collection exists
              .get();
          log(
            '📊 Total stories in database (including expired): ${allStoriesSnapshot.docs.length}',
          );

          if (allStoriesSnapshot.docs.isNotEmpty) {
            log(
              '⚠️ Found ${allStoriesSnapshot.docs.length} stories but all are expired',
            );
            // Show expired stories info for debugging
            for (var doc in allStoriesSnapshot.docs) {
              final data = doc.data();
              final expiryTime = data['expiryTime'] as Timestamp?;
              if (expiryTime != null) {
                final expiryDate = expiryTime.toDate();
                final isExpired = expiryDate.isBefore(now);
                log(
                  '  - Story ${doc.id}: expiryTime=${expiryDate}, expired=$isExpired',
                );
              }
            }
          } else {
            log('📭 No stories found in database at all');
          }
        } catch (e) {
          log('Error checking all stories: $e');
        }
      }
    } catch (e) {
      log('⚠️ Stories query with orderBy failed (might need index): $e');

      // Strategy 2: Try without orderBy
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('stories')
            .where('expiryTime', isGreaterThan: Timestamp.fromDate(now))
            .get();
        log(
          '✅ Stories query without orderBy succeeded - found ${snapshot.docs.length} docs',
        );
      } catch (e2) {
        log('⚠️ Stories query without orderBy also failed: $e2');

        // Strategy 3: Get ALL stories and filter in memory (most reliable)
        try {
          snapshot = await FirebaseFirestore.instance
              .collection('stories')
              .get();
          fetchedAllStories = true;
          log(
            '✅ Stories query (all stories) succeeded - found ${snapshot.docs.length} docs',
          );
        } catch (e3) {
          log('❌ All story queries failed: $e3');
          // If all queries fail, try to load from cache
          if (mounted) {
            await _loadStoriesFromCacheOnly();
          }
          return;
        }
      }
    }

    if (snapshot != null && mounted) {
      try {
        log('Processing ${snapshot.docs.length} story documents...');

        final fetchedStories = snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final story = StoryModel.fromFirestore(data, doc.id);

                // Filter expired stories if we got all stories
                if (fetchedAllStories && story.expiryTime.isBefore(now)) {
                  log(
                    '  ⏰ Story ${doc.id} expired (expiryTime: ${story.expiryTime})',
                  );
                  return null;
                }

                return story;
              } catch (e) {
                log('❌ Error parsing story ${doc.id}: $e');
                log('Story data: ${doc.data()}');
                return null;
              }
            })
            .where((story) => story != null)
            .cast<StoryModel>()
            .toList();

        // Always sort by expiryTime descending (newest first)
        fetchedStories.sort((a, b) => b.expiryTime.compareTo(a.expiryTime));

        log(
          '✅ Successfully processed ${fetchedStories.length} valid stories (out of ${snapshot.docs.length} total)',
        );

        if (fetchedStories.isEmpty && snapshot.docs.isNotEmpty) {
          log(
            '⚠️ All ${snapshot.docs.length} stories in database have expired',
          );
        }

        setState(() {
          _stories = fetchedStories;
          _isLoadingStories = false;
        });
        await _saveStoriesToCache();
        log('✅ Stories state updated - total: ${_stories.length}');
      } catch (e) {
        log('❌ Error processing fetched stories: $e');
        if (mounted) {
          await _loadStoriesFromCacheOnly();
        }
      }
    }
  }

  // Load stories from cache only (fallback)
  Future<void> _loadStoriesFromCacheOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_storiesCacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        final now = DateTime.now();
        final loaded = list
            .map(
              (e) =>
                  StoryModel.fromCacheJson(Map<String, dynamic>.from(e as Map)),
            )
            .where((s) => s.expiryTime.isAfter(now))
            .toList();
        if (mounted) {
          setState(() {
            _stories = loaded;
            _isLoadingStories = false;
          });
          log('Loaded ${loaded.length} stories from cache as fallback');
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingStories = false);
        }
        log('No cached stories available');
      }
    } catch (cacheError) {
      log('Error loading stories from cache fallback: $cacheError');
      if (mounted) {
        setState(() => _isLoadingStories = false);
      }
    }
  }

  // Cleanup expired stories
  Future<void> _cleanupExpiredStories() async {
    try {
      final now = DateTime.now();
      final expiredStories = _stories
          .where((story) => story.expiryTime.isBefore(now))
          .toList();

      for (final story in expiredStories) {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(story.id)
            .delete();

        // Delete image from Storage if it's an image story
        if (story.isImage &&
            story.content.startsWith(
              'https://firebasestorage.googleapis.com',
            )) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(story.content);
            await ref.delete();
          } catch (e) {
            print('Error deleting story image: $e');
          }
        }
      }

      // Refresh stories list
      await fetchStories();
    } catch (e) {
      print('Error cleaning up expired stories: $e');
    }
  }

  String? isPaid;
  bool _isSubscribing = false;
  @override
  void initState() {
    super.initState();
    _loadSongsFromCacheOrFetch();
    _loadStoriesFromCacheOrFetch();
    // Start story cleanup timer
    _startStoryCleanupTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Timer for cleaning up expired stories
  Timer? _storyCleanupTimer;

  void _startStoryCleanupTimer() {
    _storyCleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupExpiredStories();
    });
  }

  @override
  void dispose() {
    _storyCleanupTimer?.cancel();
    searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void filterSongs(String query) {
    setState(() {
      filteredSongs = songs.where((song) {
        final title = song['title']?.toString().toLowerCase() ?? '';
        final singer = song['singer']?.toString().toLowerCase() ?? '';
        final year = song['year']?.toString().toLowerCase() ?? '';
        final description = song['description']?.toString().toLowerCase() ?? '';

        final searchLower = query.toLowerCase();
        return title.contains(searchLower) ||
            singer.contains(searchLower) ||
            year.contains(searchLower) ||
            description.contains(searchLower);
      }).toList();
    });
  }

  Future<void> fetchSongs() async {
    setState(() {
      _isLoadingSongs = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null) {
        Fluttertoast.showToast(msg: "User not logged in");
        setState(() {
          _isLoadingSongs = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        songs = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        filteredSongs = songs; // Initialize filtered songs with all songs
        _isLoadingSongs = false;
      });
      await _saveSongsToCache();
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to load songs: $e");
      setState(() {
        _isLoadingSongs = false;
      });
    }
  }

  Future<void> deleteSong(String songId, String songUrl) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Get the song document to check ownership
      final songDoc = await FirebaseFirestore.instance
          .collection('songs')
          .doc(songId)
          .get();

      if (!songDoc.exists) {
        Fluttertoast.showToast(msg: "Song not found");
        return;
      }

      final songData = songDoc.data();
      if (songData == null || songData['userId'] != currentUserId) {
        Fluttertoast.showToast(msg: "You can only delete your own songs");
        return;
      }

      // Delete the audio file from Firebase Storage
      if (songUrl.isNotEmpty) {
        final ref = FirebaseStorage.instance.refFromURL(songUrl);
        await ref.delete();
      }

      // Delete the song document from Firestore
      await FirebaseFirestore.instance.collection('songs').doc(songId).delete();

      // Update the local state
      setState(() {
        songs.removeWhere((song) => song['id'] == songId);
        filteredSongs.removeWhere((song) => song['id'] == songId);
      });

      Fluttertoast.showToast(msg: "Song deleted successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete song: $e");
    }
  }

  void _handleUploadSong() {
    if (FirebaseAuth.instance.currentUser == null) {
      AppToast.show('Please sign in to upload songs', isError: true);
      return;
    }
    showAddSongBottomSheet(context);
  }

  Future<void> _handleUploadSongAndRefresh() async {
    if (FirebaseAuth.instance.currentUser == null) {
      AppToast.show('Please sign in to upload songs', isError: true);
      return;
    }
    await showAddSongBottomSheet(context);
    await fetchSongs();
  }

  //tabs data above the search field
  final List<TabsModel> tabsData = [
    TabsModel(
      requiredIcon: Icons.mic,
      label: "Artists",
      labelColor: Colors.white,
      bgColor: const Color(0xFF8B5CF6),
    ),
    TabsModel(
      requiredIcon: Icons.event,
      label: "Events",
      labelColor: Colors.white,
      bgColor: const Color(0xFF22C55E),
    ),
    TabsModel(
      requiredIcon: Icons.message,
      label: "Message",
      labelColor: Colors.white,
      bgColor: const Color(0xFF3B82F6),
    ),
    TabsModel(
      requiredIcon: Icons.store,
      label: "Store",
      labelColor: Colors.white,
      bgColor: const Color(0xFFF59E0B),
    ),
    TabsModel(
      requiredIcon: Icons.person,
      label: "People",
      labelColor: Colors.white,
      bgColor: Colors.blue,
    ),
    TabsModel(
      requiredIcon: Icons.library_music,
      label: "Add Song",
      labelColor: Colors.white,
      bgColor: Colors.orange,
    ),
    TabsModel(
      requiredIcon: Icons.music_note,
      label: "Music Style",
      labelColor: Colors.white,
      bgColor: Colors.teal,
    ),
  ];

  int currentIndex = 0;

  Future<void> showAddSongBottomSheet(BuildContext context) async {
    String selectedYear = '2024';
    File? pickedFile;
    String? fileName;
    bool isUploading = false;

    final TextEditingController singerController = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    final _auth = FirebaseAuth.instance;
    final _firestore = FirebaseFirestore.instance;
    final trigger = TriggerNotificationService();

    // -------------------------------
    // 🔔 Internal Notification Sender
    // -------------------------------
    Future<void> _sendSongNotificationToAllUsers({
      required String type,
      required String title,
      required String body,
      required String message,
    }) async {
      try {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;

        // Get current user name
        final currentUserDoc = await _firestore
            .collection('usersData')
            .doc(currentUser.uid)
            .get();

        final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

        // Get all users
        final usersSnapshot = await _firestore.collection('usersData').get();
        int count = 0;

        for (var userDoc in usersSnapshot.docs) {
          final userId = userDoc.id;
          if (userId == currentUser.uid) continue;

          final userData = userDoc.data();
          final fcmToken = userData['fcmToken'] as String?;

          // 🔹 Send FCM push
          if (fcmToken != null && fcmToken.isNotEmpty) {
            try {
              await trigger.sendPushNotification(
                token: fcmToken,
                title: title,
                body: body,
              );
            } catch (e) {
              debugPrint('Error sending push to $userId: $e');
            }
          }

          // 🔹 Save notification in Firestore
          await _firestore
              .collection('notifications')
              .doc(userId)
              .collection('userNotifications')
              .add({
                'type': type,
                'fromUserId': currentUser.uid,
                'fromUserName': currentUserName,
                'timestamp': FieldValue.serverTimestamp(),
                'message': message,
                'isRead': false,
              });

          count++;
        }

        debugPrint('Song notification "$type" sent to $count users');
      } catch (e) {
        debugPrint('Error sending song notification: $e');
      }
    }

    Future<void> _pickMusic() async {
      // 1️⃣  Check & request permission
      final status = await Permission.audio.request(); // iOS
      // For Android 13+, audio covers READ_MEDIA_AUDIO; for Android <13 we add storage.
      final storageStatus = await Permission.storage.request();

      if (!status.isGranted && !storageStatus.isGranted) {
        if (context.mounted) {
          AppToast.show(
            'Permission denied – can\'t pick music.',
            isError: true,
          );
        }
        return;
      }

      // 2️⃣  Pick audio file
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;

      setState(() {
        pickedFile = File(result.files.single.path!);
        fileName = path.basename(pickedFile!.path);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        const accent = Color(0xFFBB86FC);
        return Container(
          decoration: BoxDecoration(
            color: darkBackgroundPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: appGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.upload_file,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Upload New Song',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(height: 30, color: Color(0xFF3A3A3A)),
                        // File Picker Button
                        GestureDetector(
                          onTap: () => _pickMusic(),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withOpacity(0.2),
                                  const Color(0xFF2A2A2A).withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    fileName != null
                                        ? Icons.music_note
                                        : Icons.add_circle_outline,
                                    color: accent,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName ?? 'Choose MP3 Song',
                                        style: TextStyle(
                                          color: fileName != null
                                              ? Colors.white
                                              : accent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (fileName != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'File selected',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tap to select audio file',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Singer Name Field
                        _buildTextField(
                          controller: singerController,
                          hint: 'Singer Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        // Song Title Field
                        _buildTextField(
                          controller: titleController,
                          hint: 'Song Title',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 16),
                        // Description Field
                        _buildTextField(
                          controller: descriptionController,
                          hint: 'Song Description (Optional)',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        // Year Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: accent.withOpacity(0.7),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Year:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              DropdownButton<String>(
                                dropdownColor: const Color(0xFF1F1F1F),
                                value: selectedYear,
                                underline: Container(),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: accent,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() => selectedYear = newValue!);
                                },
                                items: ['2023', '2024', '2025']
                                    .map(
                                      (val) => DropdownMenuItem(
                                        value: val,
                                        child: Text(val),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Upload Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: appGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    if (pickedFile == null ||
                                        singerController.text.isEmpty ||
                                        titleController.text.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg:
                                            "Please complete all required fields.",
                                      );
                                      return;
                                    }

                                    try {
                                      setState(() => isUploading = true);

                                      final ref = FirebaseStorage.instance
                                          .ref()
                                          .child(
                                            'songs/${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile!.path)}',
                                          );

                                      await ref.putFile(pickedFile!);
                                      final url = await ref.getDownloadURL();

                                      await FirebaseFirestore.instance
                                          .collection('songs')
                                          .add({
                                            'singer': singerController.text,
                                            'title': titleController.text,
                                            'description':
                                                descriptionController.text,
                                            'year': selectedYear,
                                            'url': url,
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                            'userId': FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                          });

                                      // ✅ Trigger and save notification
                                      await _sendSongNotificationToAllUsers(
                                        type: 'new_song',
                                        title: '🎵 New Song Uploaded!',
                                        body:
                                            '${singerController.text} just uploaded a new song "${titleController.text}"',
                                        message:
                                            'A new song "${titleController.text}" by ${singerController.text} is now available.',
                                      );

                                      Fluttertoast.showToast(
                                        msg: "Song uploaded successfully",
                                      );
                                      Navigator.pop(context);
                                      fetchSongs();
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                        msg: "Error uploading: $e",
                                      );
                                    } finally {
                                      setState(() => isUploading = false);
                                    }
                                  },
                            icon: isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                            label: Text(
                              isUploading ? 'Uploading...' : 'Upload Song',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> showEditSongBottomSheet(
    BuildContext context,
    Map<String, dynamic> song,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Server-side ownership verification
    if (song['userId'] != currentUserId) {
      AppToast.show('You can only edit your own songs', isError: true);
      return;
    }

    String selectedYear = song['year'] ?? '2024';
    File? pickedFile;
    String? fileName;
    bool isUploading = false;

    final TextEditingController singerController = TextEditingController(
      text: song['singer'],
    );
    final TextEditingController titleController = TextEditingController(
      text: song['title'],
    );
    final TextEditingController descriptionController = TextEditingController(
      text: song['description'],
    );

    Future<void> _pickMusic() async {
      final status = await Permission.audio.request();
      final storageStatus = await Permission.storage.request();

      if (!status.isGranted && !storageStatus.isGranted) {
        if (context.mounted) {
          AppToast.show(
            'Permission denied – can\'t pick music.',
            isError: true,
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;

      setState(() {
        pickedFile = File(result.files.single.path!);
        fileName = path.basename(pickedFile!.path);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        const accent = Color(0xFFBB86FC);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: appGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Edit Song',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(height: 30, color: Color(0xFF3A3A3A)),
                        // File Picker Button
                        GestureDetector(
                          onTap: () => _pickMusic(),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withOpacity(0.2),
                                  const Color(0xFF2A2A2A).withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    fileName != null
                                        ? Icons.music_note
                                        : Icons.audiotrack,
                                    color: accent,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName ??
                                            'Change MP3 File (Optional)',
                                        style: TextStyle(
                                          color: fileName != null
                                              ? Colors.white
                                              : accent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (fileName != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'New file selected',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Keep current file or tap to change',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Singer Name Field
                        _buildTextField(
                          controller: singerController,
                          hint: 'Singer Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        // Song Title Field
                        _buildTextField(
                          controller: titleController,
                          hint: 'Song Title',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 16),
                        // Description Field
                        _buildTextField(
                          controller: descriptionController,
                          hint: 'Song Description (Optional)',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        // Year Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: accent.withOpacity(0.7),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Year:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              DropdownButton<String>(
                                dropdownColor: const Color(0xFF1F1F1F),
                                value: selectedYear,
                                underline: Container(),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: accent,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() => selectedYear = newValue!);
                                },
                                items: ['2023', '2024', '2025']
                                    .map(
                                      (val) => DropdownMenuItem(
                                        value: val,
                                        child: Text(val),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Update Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: appGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    if (singerController.text.isEmpty ||
                                        titleController.text.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg:
                                            "Please complete all required fields.",
                                      );
                                      return;
                                    }

                                    try {
                                      setState(() => isUploading = true);

                                      String url = song['url'];
                                      if (pickedFile != null) {
                                        // Delete old file if exists
                                        if (song['url'].isNotEmpty) {
                                          final oldRef = FirebaseStorage
                                              .instance
                                              .refFromURL(song['url']);
                                          await oldRef.delete();
                                        }

                                        // Upload new file
                                        final ref = FirebaseStorage.instance
                                            .ref()
                                            .child(
                                              'songs/${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile!.path)}',
                                            );
                                        await ref.putFile(pickedFile!);
                                        url = await ref.getDownloadURL();
                                      }

                                      await FirebaseFirestore.instance
                                          .collection('songs')
                                          .doc(song['id'])
                                          .update({
                                            'singer': singerController.text,
                                            'title': titleController.text,
                                            'description':
                                                descriptionController.text,
                                            'year': selectedYear,
                                            'url': url,
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                          });

                                      Fluttertoast.showToast(
                                        msg: "Song updated successfully",
                                      );
                                      Navigator.pop(context);
                                      fetchSongs();
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                        msg: "Error updating: $e",
                                      );
                                    } finally {
                                      setState(() => isUploading = false);
                                    }
                                  },
                            icon: isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                            label: Text(
                              isUploading ? 'Updating...' : 'Update Song',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 12,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  InputDecoration input(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),

          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: accent, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: maxLines > 1 ? 14 : 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isTablet = size.width >= 600;
    // Home tabs: always 4 in one row (Artists, Events, Message, People)
    const homeTabsCrossAxisCount = 4;
    final tabsChildAspectRatio = isTablet ? 1.7 : 0.95;
    final SubscriptionServicefull _subscriptionService =
        SubscriptionServicefull();
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Role switcher (shows current role; multi-role users can switch)
            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: r(16)),
            //   child: Consumer<UserStatusProvider>(
            //     builder: (_, userStatus, __) {
            //       if (userStatus.roles.isEmpty) return const SizedBox.shrink();
            //       return Row(children: [const RoleSwitcherChip()]);
            //     },
            //   ),
            // ),
            const SizedBox(height: 8),
            // Stories stay fixed, not scrolling
            _buildStoriesSection(),
            const SizedBox(height: 4),

            // Everything below stories is scrollable
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: mediaQuery.viewInsets.bottom,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LiveEventsSection(),

                          const NearbyUsersHomeSection(),

                          // Quick action grid – Artists, Events, Message, Store
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              itemCount: 4,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: homeTabsCrossAxisCount,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: tabsChildAspectRatio,
                                  ),
                              itemBuilder: (BuildContext context, int index) {
                                return _buildTabs(
                                  tabsData[index].requiredIcon,
                                  tabsData[index].label,
                                  tabsData[index].labelColor,
                                  tabsData[index].bgColor,
                                  () {
                                    setState(() {
                                      currentIndex = index;
                                    });
                                    if (index == 0) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AllArtistsScreen(),
                                        ),
                                      );
                                    } else if (index == 1) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EventsScreen(),
                                        ),
                                      );
                                    } else if (index == 2) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MessagesScreen(),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const StoreScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  compact: true,
                                );
                              },
                            ),
                          ),

                          AiToolsSection(
                            onToolTap: _openAiTool,
                            onViewAll: _openAllAiTools,
                            maxVisibleTools: 4,
                            showSubtitle: false,
                          ),

                          _buildHomeSongsSection(currentUserId),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stories Section Widget - UPDATED WITH GROUPING
  Widget _buildStoriesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stories',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              buildNotificationIcon(),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 100,
            child: Builder(
              builder: (context) {
                // Show shimmer while loading
                if (_isLoadingStories) {
                  log('📱 Stories UI: Showing shimmer (loading)');
                  return _buildStoriesShimmer();
                }

                final now = DateTime.now();
                final stories = _stories
                    .where((s) => s.expiryTime.isAfter(now))
                    .toList();

                log(
                  '📱 Stories UI: _isLoadingStories=$_isLoadingStories, total stories=${_stories.length}, valid stories=${stories.length}',
                );

                // If loading is complete but no stories, show create story option
                if (stories.isEmpty) {
                  log(
                    '📱 Stories UI: No stories found, showing create story item only',
                  );
                  // Show just the "Create Story" button when no stories exist
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return _buildCreateStoryItem();
                    },
                  );
                }

                // ✅ GROUP STORIES BY USER
                Map<String, List<StoryModel>> groupedStories = {};
                for (var story in stories) {
                  if (!groupedStories.containsKey(story.ownerId)) {
                    groupedStories[story.ownerId] = [];
                  }
                  groupedStories[story.ownerId]!.add(story);
                }

                // Sort stories within each group by timestamp (newest first)
                groupedStories.forEach((key, value) {
                  value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                });

                // Convert to list: current user first, then others by most recent story timestamp
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                List<MapEntry<String, List<StoryModel>>> sortedGroups =
                    groupedStories.entries.toList();
                sortedGroups.sort((a, b) {
                  if (currentUserId != null && a.key == currentUserId)
                    return -1;
                  if (currentUserId != null && b.key == currentUserId) return 1;
                  final aTime = a.value.first.timestamp;
                  final bTime = b.value.first.timestamp;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sortedGroups.length + 1, // +1 for "Your Story"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCreateStoryItem();
                    } else {
                      final userStories = sortedGroups[index - 1].value;
                      return _buildUserStoriesItem(userStories);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(
    IconData requiredIcon,
    String label,
    Color labelColor,
    Color bgColor,
    VoidCallback onTap, {
    bool compact = false,
  }) {
    return TopIcon(
      icon: requiredIcon,
      label: label,
      color: bgColor,
      labelColor: labelColor,
      onTap: onTap,
      compact: compact,
    );
  }

  void _openAiTool(AiToolItem tool) {
    if (tool.title == 'AI Beat Generator') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiBeatGeneratorScreen()),
      );
      return;
    }

    if (tool.title == 'AI Vocal Enhancer') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiVocalEnhancerScreen()),
      );
      return;
    }

    if (tool.title == 'AI Lyrics Writer') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiLyricsWriterScreen()),
      );
      return;
    }

    if (tool.title == 'AI Music Coach') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiMusicCoachScreen()),
      );
      return;
    }

    if (tool.title == 'Viral Score Predictor') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ViralScorePredictorScreen(),
        ),
      );
      return;
    }

    if (tool.title == 'AI Mood Radio') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiMoodRadioScreen()),
      );
      return;
    }

    if (tool.title == 'Stem Splitter') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StemSplitterScreen()),
      );
      return;
    }

    if (tool.title == 'Script to Music') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScriptToMusicScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BJAI(initialPrompt: tool.prompt)),
    );
  }

  void _openAiLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiLibraryScreen()),
    );
  }

  void _openAllAiTools() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAllAiToolsScreen(
          onToolTap: _openAiTool,
          onLibraryTap: _openAiLibrary,
        ),
      ),
    );
  }

  // Create Story Item (WhatsApp-style "My status")
  Widget _buildCreateStoryItem() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              _openStoryCreator();
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pinkColor, indigoColor],
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'My status',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build story item for a user (WhatsApp-style: green ring = unread, grey = read)
  Widget _buildUserStoriesItem(List<StoryModel> userStories) {
    if (userStories.isEmpty) return const SizedBox.shrink();

    final firstStory = userStories.first;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnStory = firstStory.ownerId == currentUserId;
    // WhatsApp: green ring = unread (current user has not viewed), grey = read
    final hasViewed = isOwnStory || firstStory.viewers.contains(currentUserId);
    final ringColor = hasViewed
        ? Colors.white.withOpacity(0.4)
        : const Color(0xFF25D366); // WhatsApp green for unread

    // Unique viewers count (one person viewing multiple stories = 1 viewer)
    int viewerCount = 0;
    if (isOwnStory) {
      final Set<String> uniqueViewers = {};
      for (var story in userStories) {
        uniqueViewers.addAll(story.viewers);
      }
      viewerCount = uniqueViewers.length;
    }

    return Container(
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              _showStoryViewerForUser(userStories);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: _storyTrayThumb(firstStory),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              firstStory.ownerName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwnStory && viewerCount > 0)
            GestureDetector(
              onTap: () => _showAllStoriesViews(userStories),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$viewerCount ${viewerCount == 1 ? 'viewer' : 'viewers'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Open the new full-featured story creator (text / photo / video).
  Future<void> _openStoryCreator() async {
    await StoryCreator.open(
      context,
      resolveDisplayName: _resolveDisplayName,
      onPosted: () async {
        await fetchStories();
      },
    );
  }

  // Thumbnail shown in the horizontal stories tray for a user's first story.
  Widget _storyTrayThumb(StoryModel story) {
    if (story.isImage) {
      return Image.network(
        story.content,
        fit: BoxFit.cover,
        width: 52,
        height: 52,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: darkBackgroundTertiary,
            child: const Icon(
              Icons.image_rounded,
              color: Color(0xFFBB86FC),
              size: 24,
            ),
          );
        },
      );
    }
    if (story.isVideo) {
      final hasThumb =
          story.thumbnailUrl != null && story.thumbnailUrl!.isNotEmpty;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (hasThumb)
            Image.network(
              story.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: darkBackgroundTertiary),
            )
          else
            Container(color: darkBackgroundTertiary),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white70,
              size: 22,
            ),
          ),
        ],
      );
    }
    // Text story: colored circle with initials.
    final bg = story.backgroundColor != null
        ? Color(story.backgroundColor!)
        : darkBackgroundTertiary;
    final tc = story.textColor != null ? Color(story.textColor!) : Colors.white;
    final label = story.content.trim();
    return Container(
      color: bg,
      child: Center(
        child: Text(
          label.isEmpty
              ? 'T'
              : (label.length > 2 ? label.substring(0, 2) : label),
          style: TextStyle(
            color: tc,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Track story view with timestamp in a dedicated subcollection
  Future<void> _trackStoryView({
    required String storyId,
    required String ownerId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == ownerId) return; // Don't track self-views

    try {
      final uid = currentUser.uid;

      // Ensure viewer is in the viewers array (legacy support)
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
            'viewers': FieldValue.arrayUnion([uid]),
          });

      // Store / update last view time in a subcollection
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .doc(uid)
          .set({
            'viewerId': uid,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error tracking story view with timestamp: $e');
    }
  }

  // ✅ NEW METHOD: Show story viewer starting with the user's first story
  void _showStoryViewerForUser(List<StoryModel> userStories) async {
    if (userStories.isEmpty) return;

    final firstStory = userStories.first;

    // Track view for first story if not the owner (non-blocking)
    _trackStoryView(storyId: firstStory.id, ownerId: firstStory.ownerId).then((
      _,
    ) {
      if (mounted) {
        fetchStories();
      }
    });

    // Navigate to full-screen Instagram-like story viewer with user's stories
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstagramStoryViewer(
          stories: userStories,
          initialIndex: 0, // Always start from first story
          onStoryView: (storyId) {
            // Track view for other stories too (with timestamp)
            try {
              final story = userStories.firstWhere((s) => s.id == storyId);
              _trackStoryView(storyId: storyId, ownerId: story.ownerId).then((
                _,
              ) {
                if (mounted) {
                  fetchStories();
                }
              });
            } catch (e) {
              print('Error finding story for onStoryView: $e');
            }
          },
          onSendReply: (story, replyText, userName) {
            _sendStoryReply(
              story: story,
              replyText: replyText,
              currentUserName: userName,
            );
          },
          onDeleteStory: (storyId) {
            _deleteStory(storyId);
          },
          resolveDisplayName: _resolveDisplayName,
        ),
      ),
    );
  }

  // ✅ NEW METHOD: Show all stories views (for own stories)
  void _showAllStoriesViews(List<StoryModel> userStories) async {
    // Collect all unique viewers across all stories, with counts and last-view time
    Map<String, int> viewerCounts = {}; // userId -> count of stories viewed
    Map<String, DateTime> lastViewTimes =
        {}; // userId -> approximate last view time
    Set<String> allViewers = {};

    for (var story in userStories) {
      for (var viewerId in story.viewers) {
        allViewers.add(viewerId);
        viewerCounts[viewerId] = (viewerCounts[viewerId] ?? 0) + 1;
        // Use story timestamp as an approximation of when this viewer saw it
        final currentLast = lastViewTimes[viewerId];
        if (currentLast == null || story.timestamp.isAfter(currentLast)) {
          lastViewTimes[viewerId] = story.timestamp;
        }
      }
    }

    // Fetch user names for all viewers
    List<Map<String, dynamic>> viewersData = [];
    for (String userId in allViewers) {
      final name = await _resolveDisplayName(userId);
      viewersData.add({
        'userId': userId,
        'name': name,
        'count': viewerCounts[userId] ?? 0,
        'lastViewedAt': lastViewTimes[userId],
      });
    }

    // Sort by most recent view time first, then by count
    viewersData.sort((a, b) {
      final ta = a['lastViewedAt'] as DateTime?;
      final tb = b['lastViewedAt'] as DateTime?;
      if (ta != null && tb != null) {
        return tb.compareTo(ta); // newest first
      }
      if (ta != null) return -1;
      if (tb != null) return 1;
      return (b['count'] as int).compareTo(a['count'] as int);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkAppBarBackground,
        title: Text('Story Views', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: viewersData.isEmpty
              ? const Center(
                  child: Text(
                    'No views yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: viewersData.length,
                  itemBuilder: (context, index) {
                    final viewer = viewersData[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFBB86FC),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        viewer['name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        (() {
                          final lastViewedAt =
                              viewer['lastViewedAt'] as DateTime?;
                          if (lastViewedAt != null) {
                            return 'Viewed ${_getTimeAgo(lastViewedAt)}';
                          }
                          final count = viewer['count'] as int? ?? 0;
                          if (count > 0) {
                            return 'Viewed $count of ${userStories.length} stories';
                          }
                          return 'Viewed your stories';
                        })(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFBB86FC)),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for time ago
  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Send Story Reply (runs in background)
  void _sendStoryReply({
    required StoryModel story,
    required String replyText,
    required String currentUserName,
  }) {
    // Run all async operations in background without blocking UI
    Future(() async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Create chat ID (sorted UIDs for consistent chat room)
        final chatId = ChatService.chatIdFor(currentUser.uid, story.ownerId);

        // Create a short, type-aware preview label for the reply bubble.
        String storyPreview;
        if (story.isImage) {
          storyPreview = (story.textContent != null &&
                  story.textContent!.trim().isNotEmpty)
              ? story.textContent!.trim()
              : 'Photo';
        } else if (story.isVideo) {
          storyPreview = (story.textContent != null &&
                  story.textContent!.trim().isNotEmpty)
              ? story.textContent!.trim()
              : 'Video';
        } else {
          // Text story: preview is the text itself.
          storyPreview = story.content.length > 60
              ? '${story.content.substring(0, 60)}…'
              : story.content;
        }

        await ChatService.sendMessage(
          chatId: chatId,
          peerUid: story.ownerId,
          text: replyText,
          extraFields: {
            'isStoryReply': true,
            'storyId': story.id,
            'storyContent': story.content,
            'storyPreview': storyPreview,
            'storyIsImage': story.isImage,
            // New: type-aware fields so the chat can render text/video replies.
            'storyMediaType': story.mediaType,
            if (story.thumbnailUrl != null)
              'storyThumbnailUrl': story.thumbnailUrl,
            if (story.backgroundColor != null)
              'storyBackgroundColor': story.backgroundColor,
            if (story.textColor != null) 'storyTextColor': story.textColor,
            if (story.fontFamily != null) 'storyFontFamily': story.fontFamily,
            'storyOwnerId': story.ownerId,
            'storyOwnerName': story.ownerName,
          },
        );

        // Create notification for story owner (run in parallel)
        final trigger = TriggerNotificationService();
        final storyOwnerDoc = FirebaseFirestore.instance
            .collection('usersData')
            .doc(story.ownerId)
            .get();

        final notificationSave = FirebaseFirestore.instance
            .collection('notifications')
            .doc(story.ownerId)
            .collection('userNotifications')
            .add({
              'type': 'story_reply',
              'fromUserId': currentUser.uid,
              'fromUserName': currentUserName,
              'timestamp': FieldValue.serverTimestamp(),
              'message': '$currentUserName replied to your story',
              'isRead': false,
              'storyId': story.id,
            });

        // Wait for both to complete
        final doc = await storyOwnerDoc;
        final fcmToken = doc.data()?['fcmToken'] as String?;

        // Send push notification if token exists
        if (fcmToken != null && fcmToken.isNotEmpty) {
          trigger
              .sendPushNotification(
                token: fcmToken,
                title: '📸 Story Reply',
                body:
                    '$currentUserName replied to your story: ${replyText.length > 30 ? replyText.substring(0, 30) + "..." : replyText}',
              )
              .catchError((e) => print('Error sending push notification: $e'));
        }

        await notificationSave;
      } catch (e) {
        print('Error sending story reply: $e');
        // Show error toast if needed
        if (mounted) {
          Fluttertoast.showToast(msg: "Reply sent, but notification failed");
        }
      }
    });
  }

  // Show Story Viewer - Instagram Style
  void _showStoryViewer(StoryModel story) async {
    // Get all stories from the same user first
    final allStories = _stories
        .where((s) => s.ownerId == story.ownerId)
        .toList();
    final initialIndex = allStories.indexWhere((s) => s.id == story.id);

    if (initialIndex == -1) return;

    // Track view if not the owner (non-blocking)
    _trackStoryView(storyId: story.id, ownerId: story.ownerId).then((_) {
      if (mounted) {
        fetchStories();
      }
    });

    // Navigate to full-screen Instagram-like story viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstagramStoryViewer(
          stories: allStories,
          initialIndex: initialIndex,
          onStoryView: (storyId) {
            // Track view for other stories too (with timestamp)
            try {
              final story = allStories.firstWhere((s) => s.id == storyId);
              _trackStoryView(storyId: storyId, ownerId: story.ownerId).then((
                _,
              ) {
                if (mounted) {
                  fetchStories();
                }
              });
            } catch (e) {
              print('Error finding story for onStoryView: $e');
            }
          },
          onSendReply: (story, replyText, userName) {
            _sendStoryReply(
              story: story,
              replyText: replyText,
              currentUserName: userName,
            );
          },
          onDeleteStory: (storyId) {
            _deleteStory(storyId);
          },
          resolveDisplayName: _resolveDisplayName,
        ),
      ),
    );
  }

  // Delete Story
  Future<void> _deleteStory(String storyId) async {
    try {
      // Find the story to get its content
      final story = _stories.firstWhere((s) => s.id == storyId);

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .delete();

      // If it's an image story, also delete from Firebase Storage
      if (story.isImage && story.content.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(story.content);
          await ref.delete();
        } catch (e) {
          print('Error deleting image from storage: $e');
        }
      }

      // Remove from local list
      setState(() {
        _stories.removeWhere((s) => s.id == storyId);
      });

      Fluttertoast.showToast(msg: "Story deleted successfully!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error deleting story: $e");
    }
  }

  // Shimmer loading widget for stories
  Widget _buildStoriesShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(right: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[850]!,
            highlightColor: Colors.grey[700]!,
            child: Column(
              children: [
                // Story circle shimmer
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[700]!, width: 2),
                  ),
                ),
                const SizedBox(height: 6),
                // Username shimmer
                Container(
                  width: 50,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Shimmer loading widget for songs
  Widget _buildHomeSongsSection(String? currentUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r(16)),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllSongsScreen(
                        songs: songs,
                        currentUserId: currentUserId,
                        getSongs: () => songs,
                        onUploadSong: _handleUploadSongAndRefresh,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: r(2),
                    vertical: r(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All Songs',
                      style: TextStyle(
                        color: const Color(0xFFBB86FC),
                        fontSize: r(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: r(4)),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: const Color(0xFFBB86FC),
                      size: r(14),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _handleUploadSong,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: r(8),
                    vertical: r(8),
                  ),
                ),
                icon: Icon(
                  Icons.library_music_rounded,
                  color: const Color(0xFFBB86FC),
                  size: r(16),
                ),
                label: Text(
                  'Upload Song',
                  style: TextStyle(
                    color: const Color(0xFFBB86FC),
                    fontSize: r(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingSongs)
          _buildSongShimmer()
        else if (filteredSongs.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r(16)),
            child: SizedBox(
              height: r(220),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBB86FC).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.music_note_outlined,
                        size: 64,
                        color: Color(0xFFBB86FC),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      searchController.text.isEmpty
                          ? 'No Songs Yet'
                          : 'No Songs Found',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      searchController.text.isEmpty
                          ? 'Upload your first song to get started'
                          : 'Try a different search term',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (searchController.text.isEmpty) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _handleUploadSong,
                        icon: const Icon(
                          Icons.upload_rounded,
                          color: Color(0xFFBB86FC),
                        ),
                        label: const Text(
                          'Upload Song',
                          style: TextStyle(
                            color: Color(0xFFBB86FC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: r(16)),
            itemCount: filteredSongs.length > 3 ? 3 : filteredSongs.length,
            itemBuilder: (context, index) {
              final song = filteredSongs[index];
              final isOwner = song['userId'] == currentUserId;

              return Container(
                margin: EdgeInsets.only(bottom: r(12)),
                decoration: BoxDecoration(
                  color: darkBackgroundPrimary,
                  borderRadius: BorderRadius.circular(r(20)),
                  border: Border.all(
                    color: const Color(0xFFBB86FC).withOpacity(0.2),
                    width: r(1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SongPlayerScreen(
                            title: song['title'],
                            description: song['description'],
                            fileUrl: song['url'],
                            coverImage: song['coverImage'],
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(r(20)),
                    child: Padding(
                      padding: EdgeInsets.all(r(16)),
                      child: Row(
                        children: [
                          Container(
                            width: r(40),
                            height: r(40),
                            decoration: BoxDecoration(
                              gradient: appGradient,
                              borderRadius: BorderRadius.circular(r(12)),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: r(28),
                              ),
                            ),
                          ),
                          SizedBox(width: r(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        song['title'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: r(16),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: r(12),
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        SizedBox(width: r(4)),
                                        Text(
                                          song['year'] ?? '',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: r(12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: r(6)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: r(14),
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    SizedBox(width: r(4)),
                                    Expanded(
                                      child: Text(
                                        song['singer'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: r(13),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isOwner) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    showEditSongBottomSheet(context, song),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1F1F1F),
                                      title: const Text(
                                        'Delete Song?',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Text(
                                        'Are you sure you want to delete this song? This action cannot be undone.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    deleteSong(song['id'], song['url'] ?? '');
                                  }
                                },
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSongShimmer() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: r(16)),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: r(12)),
          decoration: BoxDecoration(
            color: darkBackgroundPrimary,
            borderRadius: BorderRadius.circular(r(20)),
            border: Border.all(
              color: const Color(0xFFBB86FC).withOpacity(0.2),
              width: r(1),
            ),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[850]!,
            highlightColor: Colors.grey[700]!,
            child: Padding(
              padding: EdgeInsets.all(r(16)),
              child: Row(
                children: [
                  // Album art shimmer
                  Container(
                    width: r(80),
                    height: r(80),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(r(12)),
                    ),
                  ),
                  SizedBox(width: r(16)),
                  // Song details shimmer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: r(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(r(4)),
                          ),
                        ),
                        SizedBox(height: r(8)),
                        Container(
                          width: r(120),
                          height: r(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(r(4)),
                          ),
                        ),
                        SizedBox(height: r(8)),
                        Container(
                          width: r(80),
                          height: r(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(r(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Instagram-like Full-Screen Story Viewer
class InstagramStoryViewer extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  final Function(String storyId) onStoryView;
  final Function(StoryModel story, String replyText, String userName)
  onSendReply;
  final Function(String storyId) onDeleteStory;
  final Future<String> Function(String userId) resolveDisplayName;

  const InstagramStoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onStoryView,
    required this.onSendReply,
    required this.onDeleteStory,
    required this.resolveDisplayName,
  });

  @override
  State<InstagramStoryViewer> createState() => _InstagramStoryViewerState();
}

class _InstagramStoryViewerState extends State<InstagramStoryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _storyTimer;
  double _progress = 0.0;
  final TextEditingController _replyController = TextEditingController();
  String? _currentUserName;
  final FocusNode _replyFocusNode = FocusNode();
  bool _isTimerPaused = false;
  bool _isLongPressing = false;

  // Video playback for video stories
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  // Image preloading for image stories (timer waits until the image is ready).
  bool _isImageReady = false;
  // Auto-advance duration for text & image stories (ms). Video uses its own length.
  static const double _staticStoryDurationMs = 5000;

  // Local helper for "time ago" labels inside the viewer
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Dynamic view-time formatter used for all viewer lists:
  /// - < 1 minute  -> "Just now"
  /// - < 30 minutes -> "Xm ago"
  /// - >= 30 minutes -> exact time like "2:30 PM"
  String _formatViewTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 30) {
      return '${diff.inMinutes} min ago';
    }
    return DateFormat('h:mm a').format(timestamp);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _setupCurrentStory();
    _startStoryTimer();
    _loadCurrentUserName();

    // Track initial story view
    widget.onStoryView(widget.stories[_currentIndex].id);

    // Listen to focus changes to pause/resume timer
    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pauseTimer();
      } else {
        _resumeTimer();
      }
    });
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(StoryModel story) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: darkAppBarBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Delete Story?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this story? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeTimer(); // Resume timer when cancelled
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDeleteStory(story.id);
              Navigator.pop(context); // Close story viewer
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).then((_) {
      // Resume timer if dialog is dismissed by tapping outside
      if (mounted) {
        _resumeTimer();
      }
    });
  }

  // Show viewers for current story with names
  Future<void> _showCurrentStoryViewers(StoryModel story) async {
    // Fetch detailed view records (name + time)
    final viewsSnapshot = await FirebaseFirestore.instance
        .collection('stories')
        .doc(story.id)
        .collection('views')
        .orderBy('timestamp', descending: true)
        .get();

    if (!mounted) return;

    // Build enriched viewer list with names and timestamps (may be empty)
    final List<Map<String, dynamic>> viewersData = [];
    if (viewsSnapshot.docs.isNotEmpty) {
      // Preferred: use detailed view records with timestamps
      for (final doc in viewsSnapshot.docs) {
        final data = doc.data();
        final userId = (data['viewerId'] ?? doc.id) as String;
        final name = await widget.resolveDisplayName(userId);
        final ts = data['timestamp'] as Timestamp?;
        viewersData.add({
          'userId': userId,
          'name': name,
          // If timestamp is missing (older data), fall back to story timestamp
          'timestamp': ts != null ? ts.toDate() : story.timestamp,
        });
      }
    } else if (story.viewers.isNotEmpty) {
      // Fallback: use legacy viewers array; approximate with story timestamp
      for (final userId in story.viewers) {
        final name = await widget.resolveDisplayName(userId);
        viewersData.add({
          'userId': userId,
          'name': name,
          'timestamp': story.timestamp,
        });
      }
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final sheetHeight = mediaQuery.size.height * 0.6;
        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: darkAppBarBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBB86FC).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.visibility,
                          color: Color(0xFFBB86FC),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Story viewers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              viewersData.isEmpty
                                  ? 'No views yet'
                                  : '${viewersData.length} ${viewersData.length == 1 ? 'view' : 'views'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFF333333)),
                Expanded(
                  child: viewersData.isEmpty
                      ? Center(
                          child: Text(
                            'No views yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: viewersData.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white.withOpacity(0.08),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final viewer = viewersData[index];
                            final viewerName =
                                (viewer['name'] as String?)?.trim() ?? '';
                            final viewedAt = viewer['timestamp'] as DateTime?;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: appGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFFBB86FC,
                                    ).withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    viewerName.isNotEmpty
                                        ? viewerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                viewerName.isNotEmpty
                                    ? viewerName
                                    : 'Unknown user',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                (() {
                                  if (viewedAt != null) {
                                    // Same style as global viewers dialog:
                                    // "Viewed Just now" / "Viewed X min ago" / "Viewed 2:30 PM"
                                    return 'Viewed ${_formatTimeAgo(viewedAt)}';
                                  }
                                  return 'Viewed your story';
                                })(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Resume timer after bottom sheet is closed
    if (mounted) {
      _resumeTimer();
    }
  }

  Future<void> _loadCurrentUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && mounted) {
      final name = await widget.resolveDisplayName(currentUser.uid);
      if (mounted) {
        setState(() {
          _currentUserName = name;
        });
      }
    }
  }

  /// Prepares playback for the story at [_currentIndex]. Disposes any previous
  /// video controller and, if the current story is a video, creates a new one.
  void _setupCurrentStory() {
    final oldController = _videoController;
    _videoController = null;
    _isVideoReady = false;
    _isImageReady = false;
    oldController?.dispose();

    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;
    final story = widget.stories[_currentIndex];

    // Video story: create + initialize a controller; timer waits for _isVideoReady.
    if (story.isVideo) {
      if (story.content.isEmpty) return;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(story.content),
      );
      _videoController = controller;
      controller
          .initialize()
          .then((_) {
            if (!mounted || _videoController != controller) return;
            controller.setLooping(false);
            controller.play();
            setState(() {
              _isVideoReady = true;
              _progress = 0.0;
            });
          })
          .catchError((_) {
            if (!mounted || _videoController != controller) return;
            setState(() => _isVideoReady = false);
          });
      return;
    }

    // Image story: preload so the timer only starts once it's on screen.
    if (story.isImage && story.content.isNotEmpty) {
      bool stillCurrent() =>
          mounted &&
          _currentIndex >= 0 &&
          _currentIndex < widget.stories.length &&
          widget.stories[_currentIndex].id == story.id;
      precacheImage(
        NetworkImage(story.content),
        context,
        onError: (_, __) {
          if (!stillCurrent()) return;
          setState(() {
            _isImageReady = true; // show error placeholder; don't stall forever
            _progress = 0.0;
          });
        },
      ).then((_) {
        if (!stillCurrent()) return;
        setState(() {
          _isImageReady = true;
          _progress = 0.0;
        });
      });
      return;
    }

    // Text story: nothing to load (renders immediately).
  }

  void _startStoryTimer() {
    _progress = 0.0;
    _isTimerPaused = false;
    _storyTimer?.cancel();
    _storyTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isTimerPaused) {
        return;
      }
      final story =
          (_currentIndex >= 0 && _currentIndex < widget.stories.length)
          ? widget.stories[_currentIndex]
          : null;

      double next;
      if (story != null && story.isVideo) {
        // Video: progress follows playback position.
        final controller = _videoController;
        if (controller == null || !_isVideoReady) {
          return; // wait until the video is ready before advancing
        }
        final durMs = controller.value.duration.inMilliseconds;
        final posMs = controller.value.position.inMilliseconds;
        if (durMs <= 0) return;
        next = (posMs >= durMs - 60) ? 1.0 : (posMs / durMs);
      } else if (story != null && story.isImage) {
        // Image: wait until it has loaded before advancing.
        if (!_isImageReady) return;
        next = _progress + (50.0 / _staticStoryDurationMs);
      } else {
        // Text: fixed duration.
        next = _progress + (50.0 / _staticStoryDurationMs);
      }

      setState(() {
        _progress = next.clamp(0.0, 1.0);
      });

      if (_progress >= 1.0 && mounted) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _pauseTimer() {
    if (mounted) {
      setState(() {
        _isTimerPaused = true;
      });
    }
    _videoController?.pause();
  }

  void _resumeTimer() {
    if (mounted) {
      setState(() {
        _isTimerPaused = false;
      });
    }
    if (_isVideoReady) _videoController?.play();
  }

  void _nextStory() {
    if (!mounted) return;

    if (widget.stories.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    if (_currentIndex < widget.stories.length - 1) {
      _currentIndex++;
      if (mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (!mounted) return;

    if (widget.stories.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      if (mounted && _pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _onPageChanged(int index) {
    if (!mounted || index < 0 || index >= widget.stories.length) return;

    _storyTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _progress = 0.0;
      _isTimerPaused = false; // Reset pause state on page change
    });
    _setupCurrentStory();
    _startStoryTimer();
    widget.onStoryView(widget.stories[index].id);
  }

  void _onTapUp(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 2) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _sendReply() {
    if (!mounted || _currentIndex < 0 || _currentIndex >= widget.stories.length)
      return;

    final replyText = _replyController.text.trim();
    if (replyText.isNotEmpty && _currentUserName != null) {
      widget.onSendReply(
        widget.stories[_currentIndex],
        replyText,
        _currentUserName!,
      );
      _replyController.clear();
      _replyFocusNode.unfocus();
      Fluttertoast.showToast(msg: "Reply sent!");
    }
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= widget.stories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }

    final currentStory = widget.stories[_currentIndex];
    final isOwnStory =
        currentStory.ownerId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story Content
          Positioned.fill(
            bottom: 0, // Story content fills the full screen
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onLongPressStart: (_) {
                _isLongPressing = true;
                _pauseTimer();
              },
              onLongPressEnd: (_) {
                _isLongPressing = false;
                _resumeTimer();
              },
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  final story = widget.stories[index];
                  return _buildStoryContent(story);
                },
              ),
            ),
          ),
          // Bottom area (no tap detection to prevent closing)
          if (isOwnStory)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: SizedBox.shrink(), // Placeholder to block taps
            ),

          // Top Progress Bars (WhatsApp-style thin segments)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 6,
            right: 6,
            child: Row(
              children: List.generate(widget.stories.length, (index) {
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: EdgeInsets.symmetric(
                      horizontal: index == _currentIndex ? 0 : 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    child: index == _currentIndex
                        ? Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: index < _currentIndex
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                          ),
                  ),
                );
              }),
            ),
          ),

          // Top Header (WhatsApp-style: avatar + name left, time + close right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // User Avatar (tap to open profile)
                  GestureDetector(
                    onTap: () => openUserProfile(context, currentStory.ownerId),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: darkBackgroundTertiary,
                      child: Text(
                        currentStory.ownerName.isNotEmpty
                            ? currentStory.ownerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // User Name
                  Expanded(
                    child: Text(
                      currentStory.ownerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Time (right side, WhatsApp-style "5m")
                  Text(
                    currentStory.timeAgo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isOwnStory)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                      color: Colors.grey[900],
                      onOpened: () {
                        _pauseTimer();
                      },
                      onCanceled: () {
                        _resumeTimer();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delete Story',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'views',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Color(0xFFBB86FC),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'View Story Viewers',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(currentStory);
                        } else if (value == 'views') {
                          _showCurrentStoryViewers(currentStory);
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Reply Section (match chat input behavior)
          if (!isOwnStory)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Container(
                // color: darkBackgroundPrimary,
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 6,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text Field Container (copied from messages_screen style)
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        decoration: BoxDecoration(
                          color: darkAppBarBackground,
                          borderRadius: BorderRadius.circular(21),

                          border: Border.all(color: Color(0xFFBB86FC)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                focusNode: _replyFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLines: null,
                                decoration: InputDecoration(
                                  hintText:
                                      'Reply to ${currentStory.ownerName}',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 9,
                                  ),
                                ),
                                onSubmitted: (_) => _sendReply(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Send Button (styled similar to chat screen)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBB86FC),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _sendReply,
                          borderRadius: BorderRadius.circular(25),
                          child: const Center(
                            child: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom overlay: caption (image stories only) + view button (own story)
          if ((currentStory.isImage &&
                  currentStory.textContent != null &&
                  currentStory.textContent!.isNotEmpty) ||
              isOwnStory)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  14 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption only for image stories (not text stories)
                    if (currentStory.isImage &&
                        currentStory.textContent != null &&
                        currentStory.textContent!.isNotEmpty) ...[
                      Text(
                        currentStory.textContent!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Thin horizontal line below caption
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        color: Colors.white.withOpacity(0.35),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // View section: chevron up, then eye + count (centered)
                    if (isOwnStory)
                      GestureDetector(
                        onTap: () {
                          _pauseTimer();
                          _showCurrentStoryViewers(currentStory);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.visibility_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${currentStory.viewers.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    if (story.isVideo) {
      return _buildVideoStoryContent(story);
    }
    if (story.isText || !story.isImage) {
      return _buildTextStoryContent(story);
    }
    // Image story
    final isActive =
        _currentIndex >= 0 &&
        _currentIndex < widget.stories.length &&
        widget.stories[_currentIndex].id == story.id;
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              story.content,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.image, color: Colors.white54, size: 60),
                );
              },
            ),
            if (isActive && !_isImageReady)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoStoryContent(StoryModel story) {
    final isActive =
        _currentIndex >= 0 &&
        _currentIndex < widget.stories.length &&
        widget.stories[_currentIndex].id == story.id;
    final controller = _videoController;

    if (isActive && controller != null && _isVideoReady) {
      return SizedBox.expand(
        child: ColoredBox(
          color: Colors.black,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final vSize = controller.value.size;
              final vw = vSize.width > 0 ? vSize.width : 9.0;
              final vh = vSize.height > 0 ? vSize.height : 16.0;
              return FittedBox(
                fit: BoxFit.fitWidth,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: vw,
                  height: vh,
                  child: VideoPlayer(controller),
                ),
              );
            },
          ),
        ),
      );
    }

    // Off-screen or still initializing: thumbnail (+ spinner only when active).
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (story.thumbnailUrl != null && story.thumbnailUrl!.isNotEmpty)
            Image.network(
              story.thumbnailUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          if (isActive)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextStoryContent(StoryModel story) {
    final bg = story.backgroundColor != null
        ? Color(story.backgroundColor!)
        : null;
    final textColor = story.textColor != null
        ? Color(story.textColor!)
        : Colors.white;
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    TextStyle textStyle;
    if (story.fontFamily != null && story.fontFamily!.isNotEmpty) {
      try {
        textStyle = GoogleFonts.getFont(
          story.fontFamily!,
          textStyle: baseStyle,
        );
      } catch (_) {
        textStyle = baseStyle;
      }
    } else {
      textStyle = baseStyle;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        gradient: bg == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [recntsColor, indigoColor],
              )
            : null,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(story.content, style: textStyle, textAlign: TextAlign.center),
    );
  }
}

/// Screen showing all tabs (Artists, Events, Message, People, Add Song, Music Style).
/// Opened when user taps "View All" on the home tabs grid.
class ViewAllTabsScreen extends StatelessWidget {
  final List<TabsModel> tabsData;

  /// Called when Add Song is tapped; receives [context] so the bottom sheet opens on this screen.
  final void Function(BuildContext context) onAddSong;
  final SubscriptionServicefull _subscriptionService =
      SubscriptionServicefull();
  ViewAllTabsScreen({
    super.key,
    required this.tabsData,
    required this.onAddSong,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final crossAxisCount = size.width >= 900
        ? 5
        : isTablet
        ? 4
        : 3;
    final aspectRatio = isTablet ? 1.15 : 1.1;

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkBackgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'View All',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          itemCount: tabsData.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (BuildContext context, int index) {
            final tab = tabsData[index];
            return TopIcon(
              icon: tab.requiredIcon,
              label: tab.label,
              color: tab.bgColor,
              labelColor: tab.labelColor,
              onTap: () {
                if (index == 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AllArtistsScreen()),
                  );
                } else if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EventsScreen()),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MessagesScreen()),
                  );
                } else if (index == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoreScreen(),
                    ),
                  );
                } else if (index == 4) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PeopleScreen()),
                  );
                } else if (index == 5) {
                  onAddSong(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StoreListScreen()),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class TopIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color labelColor;
  final VoidCallback? onTap;
  final bool compact;

  const TopIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.labelColor = Colors.black,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 12.0 : 16.0;
    final iconPadding = compact ? 10.0 : 12.0;
    final iconSize = compact ? 20.0 : 24.0;
    final spacing = compact ? 8.0 : 10.0;
    final fontSize = compact ? 11.0 : 12.0;
    final borderRadius = compact ? 18.0 : 20.0;
    final iconRadius = compact ? 12.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(iconRadius),
                ),
                child: Icon(icon, color: Colors.white, size: iconSize),
              ),
              SizedBox(height: spacing),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Story Model Class
class StoryModel {
  final String id;
  final String username;
  final String content;
  final String? textContent; // For text overlay on images
  final bool isImage;
  final bool isLive;
  final DateTime timestamp;
  final String ownerId;
  final String ownerName;
  final List<String> viewers;
  final DateTime expiryTime;

  // ── New story-creator fields (backward compatible) ──
  /// 'text' | 'image' | 'video'. Derived from [isImage] for legacy docs.
  final String mediaType;

  /// ARGB int for styled text-story background (single color). Null = default gradient.
  final int? backgroundColor;

  /// ARGB int for styled text-story text color.
  final int? textColor;

  /// GoogleFonts family name for styled text stories.
  final String? fontFamily;

  /// Thumbnail image URL for video stories (shown in the stories tray).
  final String? thumbnailUrl;

  bool get isVideo => mediaType == 'video';
  bool get isText => mediaType == 'text';

  StoryModel({
    required this.id,
    required this.username,
    required this.content,
    this.textContent,
    required this.isImage,
    required this.isLive,
    required this.timestamp,
    required this.ownerId,
    required this.ownerName,
    required this.viewers,
    required this.expiryTime,
    this.mediaType = 'image',
    this.backgroundColor,
    this.textColor,
    this.fontFamily,
    this.thumbnailUrl,
  });

  // Create from Firestore document
  factory StoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    final bool legacyIsImage = data['isImage'] ?? false;
    return StoryModel(
      id: id,
      username: data['username'] ?? '',
      content: data['content'] ?? '',
      textContent: data['textContent'],
      isImage: legacyIsImage,
      isLive: data['isLive'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      viewers: List<String>.from(data['viewers'] ?? []),
      expiryTime: (data['expiryTime'] as Timestamp).toDate(),
      mediaType:
          (data['mediaType'] as String?) ?? (legacyIsImage ? 'image' : 'text'),
      backgroundColor: (data['backgroundColor'] as num?)?.toInt(),
      textColor: (data['textColor'] as num?)?.toInt(),
      fontFamily: data['fontFamily'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'content': content,
      'textContent': textContent,
      'isImage': isImage,
      'isLive': isLive,
      'timestamp': Timestamp.fromDate(timestamp),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'viewers': viewers,
      'expiryTime': Timestamp.fromDate(expiryTime),
      'mediaType': mediaType,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (textColor != null) 'textColor': textColor,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'username': username,
    'content': content,
    'textContent': textContent,
    'isImage': isImage,
    'isLive': isLive,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'viewers': viewers,
    'expiryTime': expiryTime.millisecondsSinceEpoch,
    'mediaType': mediaType,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'fontFamily': fontFamily,
    'thumbnailUrl': thumbnailUrl,
  };

  factory StoryModel.fromCacheJson(Map<String, dynamic> data) {
    return StoryModel(
      id: data['id'] as String? ?? '',
      username: data['username'] as String? ?? '',
      content: data['content'] as String? ?? '',
      textContent: data['textContent'] as String?,
      isImage: data['isImage'] as bool? ?? false,
      isLive: data['isLive'] as bool? ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num?)?.toInt() ?? 0,
      ),
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      viewers: List<String>.from(data['viewers'] as List? ?? []),
      expiryTime: DateTime.fromMillisecondsSinceEpoch(
        (data['expiryTime'] as num?)?.toInt() ?? 0,
      ),
      mediaType:
          (data['mediaType'] as String?) ??
          ((data['isImage'] as bool? ?? false) ? 'image' : 'text'),
      backgroundColor: (data['backgroundColor'] as num?)?.toInt(),
      textColor: (data['textColor'] as num?)?.toInt(),
      fontFamily: data['fontFamily'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class TabsModel {
  final IconData requiredIcon;
  final String label;
  final Color labelColor;
  final Color bgColor;

  TabsModel({
    required this.requiredIcon,
    required this.label,
    required this.labelColor,
    required this.bgColor,
  });
}

// All Songs Screen with Search
class AllSongsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final String? currentUserId;
  final Future<void> Function()? onUploadSong;
  final List<Map<String, dynamic>> Function()? getSongs;

  const AllSongsScreen({
    Key? key,
    required this.songs,
    required this.currentUserId,
    this.onUploadSong,
    this.getSongs,
  }) : super(key: key);

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late List<Map<String, dynamic>> _sourceSongs;
  List<Map<String, dynamic>> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _sourceSongs = List<Map<String, dynamic>>.from(widget.songs);
    _filteredSongs = _sourceSongs;
    _searchController.addListener(_filterSongs);
  }

  Future<void> _refreshSongsFromSource() async {
    if (widget.onUploadSong != null) {
      await widget.onUploadSong!();
    }
    if (!mounted) return;
    setState(() {
      _sourceSongs = List<Map<String, dynamic>>.from(
        widget.getSongs?.call() ?? widget.songs,
      );
    });
    _filterSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _filterSongs() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredSongs = _sourceSongs;
      });
      return;
    }

    setState(() {
      _filteredSongs = _sourceSongs.where((song) {
        final title = (song['title'] ?? '').toString().toLowerCase();
        final singer = (song['singer'] ?? '').toString().toLowerCase();
        final year = (song['year'] ?? '').toString().toLowerCase();
        final description = (song['description'] ?? '')
            .toString()
            .toLowerCase();
        final searchLower = query.toLowerCase();
        return title.contains(searchLower) ||
            singer.contains(searchLower) ||
            year.contains(searchLower) ||
            description.contains(searchLower);
      }).toList();
    });
  }

  double r(double size) {
    return size * (MediaQuery.of(context).size.width / 375.0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.currentUserId;

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'All Songs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded, color: Color(0xFFBB86FC)),
            tooltip: 'Upload Song',
            onPressed: widget.onUploadSong == null
                ? null
                : _refreshSongsFromSource,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(16)),
            child: Container(
              decoration: BoxDecoration(
                color: darkBackgroundPrimary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: recntsColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: Colors.white, fontSize: r(15)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: r(15)),
                    child: Icon(
                      Icons.search,
                      color: const Color(0xFFBB86FC).withOpacity(0.7),
                      size: r(22),
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: r(22),
                    minHeight: r(36),
                  ),
                  hintText: 'Search Songs...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: r(15),
                  ),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white.withOpacity(0.7),
                            size: r(18),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterSongs();
                            _searchFocus.unfocus();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _filterSongs(),
              ),
            ),
          ),

          // Songs List
          Expanded(
            child: _filteredSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBB86FC).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.music_note_outlined,
                            size: 64,
                            color: Color(0xFFBB86FC),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _searchController.text.isEmpty
                              ? "No Songs Yet"
                              : "No Songs Found",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty
                              ? "Upload your first song to get started"
                              : "Try a different search term",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(r(16), 0, r(16), r(42)),
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      final isOwner = song['userId'] == currentUserId;

                      return Container(
                        margin: EdgeInsets.only(bottom: r(12)),
                        decoration: BoxDecoration(
                          color: darkBackgroundPrimary,
                          borderRadius: BorderRadius.circular(r(20)),
                          border: Border.all(
                            color: const Color(0xFFBB86FC).withOpacity(0.2),
                            width: r(1),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SongPlayerScreen(
                                    title: song['title'],
                                    description: song['description'],
                                    fileUrl: song['url'],
                                    coverImage: song['coverImage'],
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(r(20)),
                            child: Padding(
                              padding: EdgeInsets.all(r(16)),
                              child: Row(
                                children: [
                                  // Album Art
                                  Container(
                                    width: r(40),
                                    height: r(40),
                                    decoration: BoxDecoration(
                                      gradient: appGradient,
                                      borderRadius: BorderRadius.circular(
                                        r(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: r(28),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: r(16)),
                                  // Song Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              song['title'] ?? '',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: r(16),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: r(12),
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                                SizedBox(width: r(4)),
                                                Text(
                                                  song['year'] ?? '',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.5),
                                                    fontSize: r(12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: r(6)),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: r(14),
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                            SizedBox(width: r(4)),
                                            Expanded(
                                              child: Text(
                                                song['singer'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.6),
                                                  fontSize: r(13),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action Buttons (if owner)
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.white.withOpacity(0.7),
                                        size: r(20),
                                      ),
                                      color: darkAppBarBackground,
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Edit',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          // Handle edit - you can add this functionality
                                        } else if (value == 'delete') {
                                          // Handle delete - you can add this functionality
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
