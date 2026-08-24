import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/song_provider/song_provider.dart';
import 'audio_player_screen.dart';
import 'create_song_screen.dart';
import 'music_store_model.dart';

class SongListScreen extends StatefulWidget {
  final MusicStoreModel store;
  const SongListScreen({required this.store, Key? key}) : super(key: key);

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().fetchSongs(widget.store.id);
    });
  }

  void _deleteSong(BuildContext context, String songId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Server-side ownership verification
    if (widget.store.userId != currentUserId) {
      AppToast.show('You can only delete songs from your own store', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Song?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this song? This action cannot be undone.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<SongProvider>().deleteSong(songId);
        AppToast.show('Song deleted successfully');
      } catch (e) {
        AppToast.show('Failed to delete song: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);

    final songs = context.watch<SongProvider>().songs;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isStoreOwner = widget.store.userId == currentUserId;

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: Text(
          widget.store.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: songs.isEmpty
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
                  const Text(
                    'No Songs Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isStoreOwner
                        ? 'Add your first song to this store'
                        : 'This store has no songs yet',
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
              padding: const EdgeInsets.all(16),
              itemCount: songs.length,
              itemBuilder: (_, i) {
                final s = songs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                   border: Border.all(
          color: accent.withOpacity(0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AudioPlayerScreen(song: s)),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Cover Image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFBB86FC).withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFBB86FC).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: s.coverImageUrl.isNotEmpty
                                    ? Image.network(
                                        s.coverImageUrl,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Song Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          s.singer,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (s.price > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          size: 14,
                                          color: const Color(0xFFBB86FC),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          s.price.toStringAsFixed(2),
                                          style: const TextStyle(
                                            color: Color(0xFFBB86FC),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isStoreOwner) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateSongScreen(
                                            storeId: widget.store.id,
                                            song: s,
                                          ),
                                        ),
                                      ),
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
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      onPressed: () => _deleteSong(context, s.id),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: appGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFBB86FC).withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: isStoreOwner
          ? Container(
              decoration: BoxDecoration(
                gradient: appGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: recntsColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateSongScreen(storeId: widget.store.id),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildPlaceholder() {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.2),
            const Color(0xFF2A2A2A).withOpacity(0.8),
          ],
        ),
      ),
      child: const Icon(
        Icons.music_note,
        color: accent,
        size: 32,
      ),
    );
  }
  }

