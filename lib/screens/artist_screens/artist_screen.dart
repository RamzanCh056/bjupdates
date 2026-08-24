import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/Dialog/show_premium_unlock_dialog.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_artist_dialog.dart';
import 'artist_upload_song_screen.dart';
import '../home1/song_player_screen.dart';

class AllArtistsScreen extends StatefulWidget {
  const AllArtistsScreen({super.key});

  @override
  State<AllArtistsScreen> createState() => _AllArtistsScreenState();
}

class _AllArtistsScreenState extends State<AllArtistsScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _artistsStream;
  late TabController _tabController;
  int _currentTab = 0;
  String? _selectedArtistId;
  String? _selectedArtistName;
  bool _isPaidUser = false;
  bool get isPaidUser => _isPaidUser;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    _artistsStream = _firestore
        .collection('artists')
        .orderBy('createdAt', descending: true)
        .snapshots();
    // _checkUserStatusAndShowPopup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No more audio management needed
  }

  Future<void> _checkUserStatusAndShowPopup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final isPaid = data['isPaid'] ?? false;

        setState(() {
          _isPaidUser = isPaid;
        });

        // Only show popup if user is NOT paid and hasn't seen it yet
        // if (!isPaid) {
        //   // Delay to ensure the screen is fully loaded
        //   await Future.delayed(const Duration(seconds: 2));
        //   if (mounted) {
        //     showPremiumUnlockDialog(
        //       titleString: 'Go Premium and watch ads get 30 points for unlock this Feature',
        //       context
        //     );

        //     // _showBlueTickPopup();
        //   }
        // }
      }
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  void _selectArtist(String artistId, String artistName) {
    print('DEBUG: Selecting artist - ID: $artistId, Name: $artistName');

    setState(() {
      if (_selectedArtistId == artistId) {
        _selectedArtistId = null;
        _selectedArtistName = null;
      } else {
        _selectedArtistId = artistId;
        _selectedArtistName = artistName;
      }
    });
    print('DEBUG: Selected artist ID is now: $_selectedArtistId');
  }

  Future<void> _editArtist(
    String artistId,
    String currentName,
    String currentBandName,
    String currentAbout,
    String currentImageUrl,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    final TextEditingController bandController = TextEditingController(
      text: currentBandName,
    );
    final TextEditingController aboutController = TextEditingController(
      text: currentAbout,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Edit Artist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Artist Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBB86FC)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bandController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Band Name (Optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBB86FC)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: aboutController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'About',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBB86FC)),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Artist name is required')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('artists')
                    .doc(artistId)
                    .update({
                      'name': nameController.text.trim(),
                      'bandName': bandController.text.trim(),
                      'about': aboutController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
                AppToast.show('Artist updated successfully');
              } catch (e) {
                AppToast.show('Error updating artist: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBB86FC),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArtist(String artistId, String artistName) async {
    // Check if artist has songs
    final songsSnapshot = await FirebaseFirestore.instance
        .collection('artistSongs')
        .where('artistId', isEqualTo: artistId)
        .get();

    if (songsSnapshot.docs.isNotEmpty) {
      AppToast.show(
        'Cannot delete artist with existing songs. Please delete all songs first.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Delete Artist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$artistName"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Delete artist image from storage if exists
                final artistDoc = await FirebaseFirestore.instance
                    .collection('artists')
                    .doc(artistId)
                    .get();
                if (artistDoc.exists) {
                  final data = artistDoc.data()!;
                  final imageUrl = data['imageUrl'] as String? ?? '';
                  if (imageUrl.isNotEmpty &&
                      imageUrl.startsWith(
                        'https://firebasestorage.googleapis.com',
                      )) {
                    try {
                      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
                      await ref.delete();
                    } catch (e) {
                      print('Error deleting artist image: $e');
                    }
                  }
                }

                // Delete artist document
                await FirebaseFirestore.instance
                    .collection('artists')
                    .doc(artistId)
                    .delete();

                Navigator.pop(context);
                AppToast.show('Artist deleted successfully');

                // Clear selection if deleted artist was selected
                if (_selectedArtistId == artistId) {
                  setState(() {
                    _selectedArtistId = null;
                    _selectedArtistName = null;
                  });
                }
              } catch (e) {
                AppToast.show('Error deleting artist: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _autoSelectFirstArtist(List<QueryDocumentSnapshot> docs) {
    if (_selectedArtistId == null && docs.isNotEmpty) {
      final firstArtist = docs.first;
      final artistId = firstArtist.id;
      final artistName = firstArtist['name'] as String? ?? 'Unknown';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectArtist(artistId, artistName);
      });
    }
  }

  Widget _buildAllArtistsTab(Color accent) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Artists',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: recntsColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedArtistId != null ? '1' : '0'} selected',
                  style: TextStyle(
                    color: recntsColor.withOpacity(0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _artistsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: recntsColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_search_rounded,
                          size: 56,
                          color: recntsColor.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No artists yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Artists will appear here',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              _autoSelectFirstArtist(docs);
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.6,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final data = docs[i].data()! as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Unknown';
                        final imageUrl = data['imageUrl'] as String? ?? '';
                        final artistId = docs[i].id;
                        final isSelected = _selectedArtistId == artistId;
                        return GestureDetector(
                          onTap: () => _selectArtist(artistId, name),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? recntsColor
                                        : Colors.white.withOpacity(0.12),
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: recntsColor.withOpacity(0.4),
                                            blurRadius: 14,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _artistPlaceholder(60),
                                        )
                                      : _artistPlaceholder(60),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? recntsColor
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_selectedArtistId != null) _buildSongsSection(accent),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _artistPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: appGradient, shape: BoxShape.circle),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildSongsSection(Color accent) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('artistSongs')
          .where('artistId', isEqualTo: _selectedArtistId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
            ),
          );
        }
        final songDocs = snap.data?.docs ?? [];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: darkBackgroundSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: recntsColor.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: recntsColor.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: recntsColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedArtistName ?? 'Artist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Songs',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (songDocs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No songs yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                ...songDocs.map((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final title = d['title'] as String? ?? 'Unknown';
                  final audioUrl = d['audioUrl'] as String? ?? '';
                  final coverImage = d['coverUrl'] as String? ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          darkBackgroundTertiary,
                          darkBackgroundSecondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: recntsColor.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: appGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: recntsColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: coverImage.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    coverImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((d['year']?.toString() ?? '').isNotEmpty)
                                Text(
                                  d['year'].toString(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (audioUrl.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SongPlayerScreen(
                                      title: title,
                                      fileUrl: audioUrl,
                                      coverImage: coverImage,
                                      description: '',
                                    ),
                                  ),
                                );
                              } else {
                                AppToast.show(
                                  'No audio file available',
                                  isError: true,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 56,
                              height: 56,
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
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyArtistsTab(Color accent) {
    if (_uid.isEmpty) {
      return Center(
        child: Text(
          'Sign in to see your artists',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('artists')
          .where('userId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: recntsColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 56,
                    color: recntsColor.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No artists yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add your first artist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data()! as Map<String, dynamic>;
            final name = data['name'] as String? ?? '';
            final imageUrl = data['imageUrl'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [darkBackgroundSecondary, darkBackgroundTertiary],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: recntsColor.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: recntsColor.withOpacity(0.06),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: recntsColor.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: recntsColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _myArtistImagePlaceholder(),
                            )
                          : _myArtistImagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((data['bandName'] as String? ?? '').isNotEmpty)
                          Text(
                            data['bandName'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () {
                              if (!context
                                  .read<UserStatusProvider>()
                                  .isArtist) {
                                AppToast.show(
                                  'Only Artists can edit artist profiles',
                                  isError: true,
                                );
                                return;
                              }
                              _editArtist(
                                doc.id,
                                name,
                                data['bandName'] ?? '',
                                data['about'] ?? '',
                                data['imageUrl'] ?? '',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              if (!context
                                  .read<UserStatusProvider>()
                                  .isArtist) {
                                AppToast.show(
                                  'Only Artists can delete artist profiles',
                                  isError: true,
                                );
                                return;
                              }
                              _deleteArtist(doc.id, name);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (!context.read<UserStatusProvider>().isArtist) {
                              AppToast.show(
                                'Only Artists can upload songs',
                                isError: true,
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistUploadSongScreen(
                                  artistId: doc.id,
                                  artistName: name,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: appGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: recntsColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.upload,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Upload Song',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _myArtistImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Artists',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: darkAppBarBackground,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'All Artists'),
                Tab(text: 'My Artists'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildAllArtistsTab(accent), _buildMyArtistsTab(accent)],
      ),
      floatingActionButton: _currentTab == 1
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
                onPressed: () async {
                  if (!context.read<UserStatusProvider>().isArtist) {
                    AppToast.show(
                      'Only Artists can add artist profiles',
                      isError: true,
                    );
                    return;
                  }
                  await showDialog(
                    context: context,
                    builder: (_) => const AddArtistDialog(),
                  );
                  setState(() {});
                },
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
    );
  }
}
