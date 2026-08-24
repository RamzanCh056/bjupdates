import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MusicStyleScreen extends StatefulWidget {
  const MusicStyleScreen({super.key});

  @override
  State<MusicStyleScreen> createState() => _MusicStyleScreenState();
}

class _MusicStyleScreenState extends State<MusicStyleScreen> {
  List<Map<String, dynamic>> musicStyles = [];

  @override
  void initState() {
    super.initState();
    fetchMusicStyles();
  }

  Future<void> fetchMusicStyles() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('musicStyles')
          .get();

      setState(() {
        musicStyles = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      });
    } catch (e) {
      print('Error fetching music styles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Music Style',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: musicStyles.isEmpty
          ? const Center(
              child: Text(
                'No music styles found',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: musicStyles.length,
              itemBuilder: (context, index) {
                final style = musicStyles[index];
                final name = style['name'] ?? 'Unknown Style';
                final description = style['description'] ?? 'No description available';
                final imageUrl = style['imageUrl'];

                return Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      // TODO: Navigate to music style detail screen
                      AppToast.show('$name details coming soon!');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              image: imageUrl != null && imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageUrl == null || imageUrl.isEmpty
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
