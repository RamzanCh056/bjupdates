import 'package:beatjerky/utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ArtistSongsScreen extends StatelessWidget {
  final String artistId;
  final String artistName;
  const ArtistSongsScreen({super.key, required this.artistId, required this.artistName});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    final query = FirebaseFirestore.instance
        .collection('artistSongs')
        .where('artistId', isEqualTo: artistId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text('$artistName Songs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
               decoration: BoxDecoration(
                color: darkBackgroundPrimary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: recntsColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  hintText: 'Search Songs',
                  hintStyle: const TextStyle(color: Colors.white54),
                 
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
          ),
          // Songs list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accent));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No songs yet', style: TextStyle(color: Colors.white70)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data()! as Map<String, dynamic>;
                    final title = d['title'] as String? ?? 'Unknown';
                    final year = d['year']?.toString() ?? '';
                    final albumArt = d['coverUrl'] as String?;
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Album art placeholder
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Song details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  artistName,
                                  style: const TextStyle(color: Colors.white60),
                                ),
                                if (year.isNotEmpty)
                                  Text(
                                    year,
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                              ],
                            ),
                          ),
                          // Play button
                          Container(
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


