import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../model/music_track_model.dart';
import '../services/music_service.dart';
import 'dart:io';

class MusicBrowserScreen extends StatefulWidget {
  final Function(MusicTrack?)
  onMusicSelected; // Made nullable to support "no music"

  const MusicBrowserScreen({Key? key, required this.onMusicSelected})
    : super(key: key);

  @override
  State<MusicBrowserScreen> createState() => _MusicBrowserScreenState();
}

class _MusicBrowserScreenState extends State<MusicBrowserScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();

  String? _currentlyPlayingId;
  bool _isSearching = false;
  bool _isUploading = false;
  DateTime? _lastUploadAttempt;
  List<MusicTrack> _searchResults = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _previewPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchMusic(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await MusicService.searchTracks(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
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

  void _selectTrack(MusicTrack track) {
    _previewPlayer.stop();
    MusicService.incrementUseCount(track.id);
    widget.onMusicSelected(track);
    Navigator.pop(context);
  }

  void _selectNoMusic() {
    _previewPlayer.stop();
    widget.onMusicSelected(null);
    Navigator.pop(context);
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Music',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.purple),
              title: const Text(
                'Audio Files (Recommended)',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'MP3, WAV, AAC, M4A',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadMusicSafe();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.blue),
              title: const Text(
                'Alternative Method',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'If above fails, try this',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadMusicAlternative();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.green),
              title: const Text(
                'From Gallery',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Select video/audio from gallery',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadFromGallery();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Method 1: Safe file picker with aggressive state clearing
  Future<void> _uploadMusicSafe() async {
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can upload music', isError: true);
      return;
    }
    if (_isUploading) {
      print('Upload already in progress, ignoring request');
      return;
    }

    final now = DateTime.now();
    if (_lastUploadAttempt != null &&
        now.difference(_lastUploadAttempt!).inSeconds < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait 3 seconds between attempts'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _lastUploadAttempt = now;
    setState(() {
      _isUploading = true;
    });

    try {
      print('=== Safe Upload Method ===');

      // Aggressive state clearing
      await _clearFilePickerState();

      // Wait longer before attempting
      await Future.delayed(const Duration(milliseconds: 1000));

      print('Starting safe file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
        allowMultiple: false,
        allowCompression: false,
        withData: false,
        withReadStream: false,
      );

      await _handleFilePickerResult(result, 'Safe method');
    } catch (e) {
      await _handleFilePickerError(
        e,
        'Safe method failed. Try "Alternative Method"',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Method 2: Alternative approach with different configuration
  Future<void> _uploadMusicAlternative() async {
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can upload music', isError: true);
      return;
    }
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      print('=== Alternative Upload Method ===');

      // Clear state more aggressively
      await _clearFilePickerState();
      await Future.delayed(const Duration(milliseconds: 2000));

      print('Starting alternative file picker...');

      // Use different configuration
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowCompression: false,
        withData: false,
        withReadStream: false,
      );

      await _handleFilePickerResult(result, 'Alternative method');
    } catch (e) {
      await _handleFilePickerError(
        e,
        'Alternative method failed. Try "From Gallery"',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Method 3: Using image picker for video/audio
  Future<void> _uploadFromGallery() async {
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can upload music', isError: true);
      return;
    }
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      print('=== Gallery Upload Method ===');

      final ImagePicker picker = ImagePicker();

      // Try to pick video (which can contain audio)
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

      if (file != null) {
        print('Gallery file selected: ${file.name}');
        final videoFile = File(file.path);

        if (await videoFile.exists()) {
          _showUploadDialog(videoFile, file.name);
        } else {
          throw Exception('Selected file does not exist');
        }
      } else {
        print('No file selected from gallery');
      }
    } catch (e) {
      print('Error with gallery picker: $e');
      AppToast.show(
        'Gallery method failed. This is normal - not all devices support audio from gallery.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Helper method to aggressively clear file picker state
  Future<void> _clearFilePickerState() async {
    try {
      print('Clearing file picker state...');

      // Force clear any existing picker state
      await FilePicker.platform.clearTemporaryFiles();

      // Multiple delays to ensure state is cleared
      await Future.delayed(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 300));

      print('File picker state cleared');
    } catch (e) {
      print('Error clearing file picker state: $e');
    }
  }

  // Helper method to handle file picker results
  Future<void> _handleFilePickerResult(
    FilePickerResult? result,
    String method,
  ) async {
    print('$method result: $result');

    if (result != null && result.files.isNotEmpty) {
      print('$method - File selected: ${result.files.first.name}');
      final filePath = result.files.first.path;

      if (filePath != null) {
        final file = File(filePath);
        final fileName = result.files.first.name;

        if (await file.exists()) {
          _showUploadDialog(file, fileName);
        } else {
          throw Exception('Selected file does not exist');
        }
      } else {
        throw Exception('File path is null');
      }
    } else {
      print('$method - No file selected (user cancelled)');
    }
  }

  // Helper method to handle file picker errors
  Future<void> _handleFilePickerError(dynamic e, String message) async {
    print('File picker error: $e');

    if (e.toString().contains('multiple_request')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showUploadDialog(File audioFile, String fileName) {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final genreController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              title: const Text(
                'Upload Music',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'Enter song title',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: artistController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Artist',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'Enter artist name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: genreController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Genre',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'e.g., Pop, Hip Hop, Rock',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'File: $fileName',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty ||
                              artistController.text.trim().isEmpty) {
                            AppToast.show(
                              'Please fill in title and artist',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() {
                            isUploading = true;
                          });

                          try {
                            await _uploadMusicToFirebase(
                              audioFile,
                              titleController.text.trim(),
                              artistController.text.trim(),
                              genreController.text.trim().isEmpty
                                  ? 'Other'
                                  : genreController.text.trim(),
                            );

                            Navigator.pop(context);
                            AppToast.show('Music uploaded successfully!');
                          } catch (e) {
                            setDialogState(() {
                              isUploading = false;
                            });
                            AppToast.show('Upload failed: $e', isError: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Upload',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _uploadMusicToFirebase(
    File audioFile,
    String title,
    String artist,
    String genre,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Upload audio file to Firebase Storage
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${audioFile.path.split('/').last}';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('music_tracks')
        .child(fileName);

    final uploadTask = storageRef.putFile(audioFile);
    final snapshot = await uploadTask;
    final audioUrl = await snapshot.ref.getDownloadURL();

    // Get audio duration (simplified approach)
    final audioPlayer = AudioPlayer();
    Duration? duration;
    try {
      await audioPlayer.setFilePath(audioFile.path);
      duration = audioPlayer.duration ?? const Duration(minutes: 3);
    } catch (e) {
      duration = const Duration(minutes: 3); // Default duration
    } finally {
      await audioPlayer.dispose();
    }

    // Create music track document
    final trackData = {
      'id': FirebaseFirestore.instance.collection('musicTracks').doc().id,
      'title': title,
      'artist': artist,
      'genre': genre,
      'audioUrl': audioUrl,
      'coverImageUrl': '', // No cover image for now
      'duration': duration.inSeconds,
      'uploadedBy': user.uid,
      'uploadedAt': FieldValue.serverTimestamp(),
      'useCount': 0,
      'isTrending': false,
    };

    await FirebaseFirestore.instance
        .collection('musicTracks')
        .doc(trackData['id'] as String)
        .set(trackData);
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
          'Select Music',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectNoMusic,
            icon: const Icon(Icons.volume_off, color: Colors.white, size: 20),
            label: const Text(
              'No Music',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search music...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _searchMusic,
                ),
              ),
              // Tabs
              if (!_isSearching && _searchResults.isEmpty)
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.purple,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Trending'),
                    Tab(text: 'Browse'),
                    Tab(text: 'My Music'),
                  ],
                ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : _searchResults.isNotEmpty
          ? _buildSearchResults()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrendingTab(),
                _buildBrowseTab(),
                _buildMyMusicTab(),
              ],
            ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildMusicTile(_searchResults[index]);
      },
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
          return const Center(
            child: Text(
              'No trending music found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildMusicTile(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildBrowseTab() {
    return StreamBuilder<List<MusicTrack>>(
      stream: MusicService.getAllTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No music found', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildMusicTile(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildMyMusicTab() {
    return StreamBuilder<List<MusicTrack>>(
      stream: MusicService.getUserTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No music uploaded yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _showUploadOptions,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload, color: Colors.white),
                  label: Text(
                    _isUploading ? 'Selecting...' : 'Upload Music',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildMusicTile(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildMusicTile(MusicTrack track) {
    final isPlaying = _currentlyPlayingId == track.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: isPlaying ? Border.all(color: Colors.purple, width: 2) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
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
                      child: const Icon(Icons.music_note, color: Colors.white),
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
                Text(
                  track.durationFormatted,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 8),
                if (track.useCount > 0)
                  Text(
                    '${track.useCount} uses',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _playPreview(track),
              icon: Icon(
                isPlaying ? Icons.stop : Icons.play_arrow,
                color: isPlaying ? Colors.purple : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _selectTrack(track),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Use',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
