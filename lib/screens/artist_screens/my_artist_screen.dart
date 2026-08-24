import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'artist_upload_song_screen.dart';
import 'add_artist_dialog.dart';

class MyArtistsScreen extends StatefulWidget {
  const MyArtistsScreen({Key? key}) : super(key: key);

  @override
  State<MyArtistsScreen> createState() => _MyArtistsScreenState();
}

class _MyArtistsScreenState extends State<MyArtistsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allMyArtists = [];
  List<QueryDocumentSnapshot> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyArtists();
    _searchController.addListener(_onSearch);
  }

  Future<void> _fetchMyArtists() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await _firestore
        .collection('artists')
        .where('userId', isEqualTo: uid)
        .get();
    _allMyArtists = snap.docs;
    _filtered = List.from(_allMyArtists);
    setState(() => _loading = false);
  }

  void _onSearch() {
    final term = _searchController.text.toLowerCase();
    if (term.isEmpty) {
      setState(() => _filtered = List.from(_allMyArtists));
    } else {
      setState(() {
        _filtered = _allMyArtists
            .where((d) => (d['name'] as String).toLowerCase().contains(term))
            .toList();
      });
    }
  }

  Future<void> _openAddDialog() async {
    final userStatus = context.read<UserStatusProvider>();
    if (!userStatus.isArtist) {
      AppToast.show('Only Artists can add artist profiles', isError: true);
      return;
    }
    await showDialog(context: context, builder: (_) => const AddArtistDialog());
    await _fetchMyArtists();
  }

  Future<void> _editArtist(
    String artistId,
    String currentName,
    String currentBandName,
    String currentAbout,
    String currentImageUrl,
  ) async {
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can edit artist profiles', isError: true);
      return;
    }
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
                AppToast.show('Artist name is required', isError: true);
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
                await _fetchMyArtists(); // Refresh the list
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
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can delete artist profiles', isError: true);
      return;
    }
    // Check if artist has songs
    final songsSnapshot = await FirebaseFirestore.instance
        .collection('artistSongs')
        .where('artistId', isEqualTo: artistId)
        .get();

    final hasSongs = songsSnapshot.docs.isNotEmpty;
    final songCount = songsSnapshot.docs.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Delete Artist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$artistName"?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (hasSongs) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This artist has $songCount song${songCount == 1 ? '' : 's'} that will also be deleted permanently.',
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
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
                Navigator.pop(context);

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    backgroundColor: Color(0xFF1F1F1F),
                    content: Row(
                      children: [
                        CircularProgressIndicator(color: Color(0xFFBB86FC)),
                        SizedBox(width: 16),
                        Text(
                          'Deleting artist and songs...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );

                // Delete all songs first
                if (hasSongs) {
                  for (final songDoc in songsSnapshot.docs) {
                    final songData = songDoc.data() as Map<String, dynamic>;

                    // Delete audio file from storage
                    final audioUrl = songData['audioUrl'] as String? ?? '';
                    if (audioUrl.isNotEmpty &&
                        audioUrl.startsWith(
                          'https://firebasestorage.googleapis.com',
                        )) {
                      try {
                        final audioRef = FirebaseStorage.instance.refFromURL(
                          audioUrl,
                        );
                        await audioRef.delete();
                      } catch (e) {
                        print('Error deleting audio file: $e');
                      }
                    }

                    // Delete cover image from storage
                    final coverUrl = songData['coverUrl'] as String? ?? '';
                    if (coverUrl.isNotEmpty &&
                        coverUrl.startsWith(
                          'https://firebasestorage.googleapis.com',
                        )) {
                      try {
                        final coverRef = FirebaseStorage.instance.refFromURL(
                          coverUrl,
                        );
                        await coverRef.delete();
                      } catch (e) {
                        print('Error deleting cover image: $e');
                      }
                    }

                    // Delete song document
                    await FirebaseFirestore.instance
                        .collection('artistSongs')
                        .doc(songDoc.id)
                        .delete();
                  }
                }

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

                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        hasSongs
                            ? 'Artist and $songCount song${songCount == 1 ? '' : 's'} deleted successfully'
                            : 'Artist deleted successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                // Refresh the list
                await _fetchMyArtists();
              } catch (e) {
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // Show error message
                if (context.mounted) {
                  AppToast.show('Error deleting artist: $e', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userStatus = context.watch<UserStatusProvider>();
    const accent = recntsColor;
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Artists',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Toggle Row
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: darkBackgroundSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'All Artists',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {},
                        child: const Text(
                          'My Artists',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search + Add
            Row(
              children: [
                Expanded(
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
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        hintText: 'Search artist name...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openAddDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Heading
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Artists',
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
                      '${_filtered.length} artist${_filtered.length == 1 ? '' : 's'}',
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
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: accent),
                    )
                  : _filtered.isEmpty
                  ? Center(
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
                          Text(
                            _searchController.text.isEmpty
                                ? 'No artists yet'
                                : 'No artists found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Tap + to add your first artist'
                                : 'Try a different search',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      padding: const EdgeInsets.only(bottom: 32),
                      itemBuilder: (ctx, i) {
                        final doc = _filtered[i];
                        final data = doc.data()! as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                darkBackgroundSecondary,
                                darkBackgroundTertiary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: recntsColor.withOpacity(0.15),
                              width: 1,
                            ),
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
                              // Artist image
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child:
                                      data['imageUrl'] != null &&
                                          data['imageUrl'].toString().isNotEmpty
                                      ? Image.network(
                                          data['imageUrl'],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    gradient: appGradient,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            gradient: appGradient,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Artist info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      data['name'] as String? ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((data['bandName'] as String? ?? '')
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.music_note,
                                            size: 14,
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              data['bandName'] as String? ?? '',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Action buttons
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit and Delete buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _editArtist(
                                            doc.id,
                                            data['name'] ?? '',
                                            data['bandName'] ?? '',
                                            data['about'] ?? '',
                                            data['imageUrl'] ?? '',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.blue.withOpacity(
                                                  0.4,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.edit_rounded,
                                              color: Colors.blue,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _deleteArtist(
                                            doc.id,
                                            data['name'] ?? '',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.red.withOpacity(
                                                  0.4,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.delete_rounded,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Upload Song button
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: appGradient,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          if (!context
                                              .read<UserStatusProvider>()
                                              .isArtist) {
                                            AppToast.show(
                                              'Only Artists can upload songs',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ArtistUploadSongScreen(
                                                    artistId: doc.id,
                                                    artistName:
                                                        data['name']
                                                            as String? ??
                                                        '',
                                                  ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
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
                                  ),
                                ],
                              ),
                            ],
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
}
