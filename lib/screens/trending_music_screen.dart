import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../model/music_track_model.dart';
import '../services/music_service.dart';

class TrendingMusicScreen extends StatefulWidget {
  const TrendingMusicScreen({Key? key}) : super(key: key);

  @override
  State<TrendingMusicScreen> createState() => _TrendingMusicScreenState();
}

class _TrendingMusicScreenState extends State<TrendingMusicScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _playPreview(MusicTrack track) async {
    try {
      if (_currentlyPlayingId == track.id) {
        await _previewPlayer.stop();
        setState(() {
          _currentlyPlayingId = null;
        });
        return;
      }

      await _previewPlayer.stop();
      await _previewPlayer.setUrl(track.audioUrl);
      await _previewPlayer.play();
      
      setState(() {
        _currentlyPlayingId = track.id;
      });

      // Auto-stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () async {
        if (_currentlyPlayingId == track.id) {
          await _previewPlayer.stop();
          if (mounted) {
            setState(() {
              _currentlyPlayingId = null;
            });
          }
        }
      });
    } catch (e) {
      print('Error playing preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trending Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Trending'),
            Tab(text: 'Popular'),
            Tab(text: 'Recent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrendingTab(),
          _buildPopularTab(),
          _buildRecentTab(),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    return StreamBuilder<List<MusicTrack>>(
      stream: MusicService.getTrendingTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.trending_up,
            title: 'No Trending Music',
            subtitle: 'Be the first to discover trending tracks!',
          );
        }

        return _buildMusicList(snapshot.data!);
      },
    );
  }

  Widget _buildPopularTab() {
    return StreamBuilder<List<MusicTrack>>(
      stream: MusicService.getAllTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.star,
            title: 'No Popular Music',
            subtitle: 'Popular tracks will appear here',
          );
        }

        // Sort by use count for popular tracks
        final popularTracks = snapshot.data!
          ..sort((a, b) => b.useCount.compareTo(a.useCount));

        return _buildMusicList(popularTracks.take(50).toList());
      },
    );
  }

  Widget _buildRecentTab() {
    return StreamBuilder<List<MusicTrack>>(
      stream: MusicService.getAllTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.access_time,
            title: 'No Recent Music',
            subtitle: 'Recently added tracks will appear here',
          );
        }

        // Already sorted by upload date (most recent first)
        return _buildMusicList(snapshot.data!.take(50).toList());
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicList(List<MusicTrack> tracks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _buildMusicTile(track, index + 1);
      },
    );
  }

  Widget _buildMusicTile(MusicTrack track, int rank) {
    final isPlaying = _currentlyPlayingId == track.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPlaying ? Colors.purple.withOpacity(0.1) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: isPlaying
            ? Border.all(color: Colors.purple, width: 2)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank number
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.orange : Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: rank <= 3 ? 14 : 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Album cover
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: track.coverImageUrl.isNotEmpty
                      ? Image.network(
                          track.coverImageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[700],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[700],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                ),
                if (track.isTrending)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        title: Text(
          track.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.artist,
              style: TextStyle(color: Colors.grey[400]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    track.genre,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  track.durationFormatted,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 8),
                if (track.useCount > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.grey[500],
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${track.useCount}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button
            IconButton(
              onPressed: () => _playPreview(track),
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.purple : Colors.purple.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            // More options
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              color: Colors.grey[800],
              onSelected: (value) {
                switch (value) {
                  case 'use_in_post':
                    // TODO: Navigate to create post with selected music
                    break;
                  case 'add_to_favorites':
                    // TODO: Add to user favorites
                    break;
                  case 'share':
                    // TODO: Share track
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'use_in_post',
                  child: Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Use in Post', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_to_favorites',
                  child: Row(
                    children: [
                      Icon(Icons.favorite_border, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Add to Favorites', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Share', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

