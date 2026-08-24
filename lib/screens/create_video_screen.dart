import 'dart:io';
import 'package:beatjerky/Stripe/SubscriptionHelper.dart';
import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/screens/Dialog/show_premium_unlock_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

import '../model/music_track_model.dart';
import '../services/music_service.dart';
import '../utils/reel_video_spec.dart';
import '../utils/reel_tips.dart';
import '../widget/music_browser.dart';
import '../widget/video_editor.dart';
import 'reel_preview_upload_screen.dart';

class CreateVideoScreen extends StatefulWidget {
  /// When set (e.g. opened from Reels tab), after editor we go to ReelPreviewUploadScreen instead of staying here.
  final FirebaseStorage? reelsStorage;
  final FirebaseAuth? reelsAuth;
  final FirebaseFirestore? reelsFirestore;
  final Future<String?> Function(
    String videoUrl,
    String description, {
    Map<String, dynamic>? editData,
    String? coverUrl,
  })? reelsSaveToFirestore;

  const CreateVideoScreen({
    Key? key,
    this.reelsStorage,
    this.reelsAuth,
    this.reelsFirestore,
    this.reelsSaveToFirestore,
  }) : super(key: key);

  @override
  _CreateVideoScreenState createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen>
    with TickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _previewPlayer = AudioPlayer();

  final SubscriptionServicefull _subscriptionService =
      SubscriptionServicefull();

  // Video state
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Music state
  MusicTrack? _selectedMusic;
  bool _isMusicPlaying = false;
  double _musicVolume = 0.5;
  double _videoVolume = 1.0;

  // UI state
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  late TabController _tabController;
  String _selectedFilter = 'None';

  /// Optional cover photo for the reel (Instagram-style)
  File? _selectedCoverImage;

  /// Edit data from VideoEditorScreen (caption, stickers, etc.) when user came from editor
  Map<String, dynamic>? _pendingEditData;

  /// True when user just returned from VideoEditorScreen — show only preview, description, cover, upload (no editing tools)
  bool _cameFromEditor = false;

  // Available filters (matches TikTok-style video editor effects)
  final List<String> _filters = [
    'None',
    'Normal',
    'Vintage',
    'B&W',
    'Sepia',
    'Cool',
    'Warm',
    'Vivid',
    'Dramatic',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _videoController?.dispose();
    _videoController = null;
    _previewPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      print('Starting video picker from source: $source');

      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        // Align with ReelVideoSpec.maxDurationSeconds (camera recording; gallery may still vary by OS).
        maxDuration: Duration(seconds: ReelVideoSpec.maxDurationSeconds),
      );

      if (pickedFile != null) {
        print('Video picked: ${pickedFile.path}');
        final videoFile = File(pickedFile.path);

        // Basic validation before initialization
        if (!await videoFile.exists()) {
          throw Exception('Selected video file does not exist');
        }

        final fileStat = await videoFile.stat();
        print('Selected video size: ${fileStat.size} bytes');

        if (fileStat.size == 0) {
          throw Exception('Selected video file is empty');
        }

        if (!ReelVideoSpec.isWithinFileSize(fileStat.size)) {
          throw Exception(
            'Video file is too large (max ${ReelVideoSpec.maxFileSizeBytes ~/ (1024 * 1024)} MB). '
            'Current size: ${(fileStat.size / (1024 * 1024)).toStringAsFixed(1)} MB',
          );
        }

        final fileName = pickedFile.name ?? pickedFile.path.split('/').last;
        final extension = fileName.toLowerCase().split('.').last;
        if (!ReelVideoSpec.isSupportedFormat(extension)) {
          throw Exception(
            'Unsupported format. Use ${ReelVideoSpec.supportedFormats.join(" or ").toUpperCase()} only.',
          );
        }

        // Open TikTok-style editor. Use post-frame so route is stable after returning from camera intent.
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        // Release preview player so only the editor holds one ExoPlayer (avoids OOM).
        _videoController?.dispose();
        _videoController = null;
        if (mounted) setState(() => _isVideoInitialized = false);
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoEditorScreen(
              videoFile: videoFile,
              onVideoEdited: (editedFile, editData) {
                Navigator.pop(context);
                // Defer so CreateVideoScreen rebuilds after the editor route is fully removed (avoids "child._parent" / Duplicate GlobalKey).
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (!mounted) return;
                  _initializeVideoWithEdit(editedFile, editData);
                });
              },
            ),
          ),
        );
      } else {
        print('No video selected');
      }
    } catch (e) {
      print('Error picking video: $e');
      AppToast.show('Error selecting video: ${e.toString()}', isError: true);
    }
  }

  /// Music from editor when _selectedMusic was not set (e.g. upload before init).
  MusicTrack? get _musicFromPendingEditData {
    if (_pendingEditData == null || _pendingEditData!['music'] == null)
      return null;
    final m = _pendingEditData!['music'];
    if (m is! Map<String, dynamic>) return null;
    return MusicTrack(
      id: (m['id'] ?? m['musicId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      artist: (m['artist'] ?? '').toString(),
      audioUrl: (m['audioUrl'] ?? '').toString(),
      coverImageUrl: (m['coverImageUrl'] ?? '').toString(),
      duration: (m['duration'] is int) ? m['duration'] as int : 0,
      genre: (m['genre'] ?? '').toString(),
      useCount: (m['useCount'] is int) ? m['useCount'] as int : 0,
      isTrending: m['isTrending'] == true,
      uploadedAt: m['uploadedAt'] is DateTime
          ? m['uploadedAt'] as DateTime
          : DateTime.now(),
      uploadedBy: (m['uploadedBy'] ?? '').toString(),
    );
  }

  /// Initialize video with optional edit data from VideoEditorScreen (music, filter, volumes, caption)
  void _initializeVideoWithEdit(
    File videoFile,
    Map<String, dynamic>? editData,
  ) {
    // When opened from Reels tab: go straight to Preview & Post screen for a unified flow.
    if (widget.reelsStorage != null &&
        widget.reelsAuth != null &&
        widget.reelsFirestore != null &&
        widget.reelsSaveToFirestore != null) {
      Navigator.pop(context);
      Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => ReelPreviewUploadScreen(
            videoFile: videoFile,
            editData: editData,
            storage: widget.reelsStorage!,
            auth: widget.reelsAuth!,
            firestore: widget.reelsFirestore!,
            saveToFirestore: widget.reelsSaveToFirestore!,
          ),
        ),
      );
      return;
    }

    _cameFromEditor =
        true; // Skip editing tools/effects — go straight to preview flow
    _pendingEditData = editData;
    if (editData != null) {
      if (editData['music'] != null && editData['music'] is Map) {
        final m = editData['music'] as Map<String, dynamic>;
        _selectedMusic = MusicTrack(
          id: m['id']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          artist: m['artist']?.toString() ?? '',
          audioUrl: m['audioUrl']?.toString() ?? '',
          coverImageUrl: m['coverImageUrl']?.toString() ?? '',
          duration: (m['duration'] is int) ? m['duration'] as int : 0,
          genre: m['genre']?.toString() ?? '',
          useCount: (m['useCount'] is int) ? m['useCount'] as int : 0,
          isTrending: m['isTrending'] == true,
          uploadedAt: m['uploadedAt'] is DateTime
              ? m['uploadedAt'] as DateTime
              : DateTime.now(),
          uploadedBy: m['uploadedBy']?.toString() ?? '',
        );
      }
      if (editData['musicVolume'] != null)
        _musicVolume = (editData['musicVolume'] as num).toDouble();
      if (editData['videoVolume'] != null)
        _videoVolume = (editData['videoVolume'] as num).toDouble();
      if (editData['filter'] != null && editData['filter'] != 'None') {
        _selectedFilter = editData['filter'] as String;
      }
    }
    _initializeVideo(videoFile);
  }

  Future<void> _initializeVideo(File videoFile) async {
    try {
      // Hide video UI first so no build uses the controller we're about to dispose (avoids crash).
      setState(() {
        _selectedVideo = videoFile;
        _isVideoInitialized = false;
      });
      _videoController?.dispose();
      _videoController = null;

      // Check if file exists and is valid
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final fileStat = await videoFile.stat();
      print('Video file size: ${fileStat.size} bytes');

      if (fileStat.size == 0) {
        throw Exception('Video file is empty');
      }

      if (!ReelVideoSpec.isWithinFileSize(fileStat.size)) {
        throw Exception(
          'Video file is too large (max ${ReelVideoSpec.maxFileSizeBytes ~/ (1024 * 1024)} MB)',
        );
      }

      _videoController = VideoPlayerController.file(videoFile);

      // Set a timeout for initialization
      await _videoController!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Video initialization timeout - file may be corrupted or too large',
          );
        },
      );

      final duration = _videoController!.value.duration;
      if (!ReelVideoSpec.isWithinMaxDuration(duration)) {
        throw Exception(
          'Video must be at most ${ReelVideoSpec.maxDurationSeconds} seconds long.',
        );
      }

      setState(() {
        _isVideoInitialized = true;
      });

      _videoController!.setLooping(true);
      _videoController!.play();
    } catch (e) {
      print('Error initializing video: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) {
        setState(() {
          _selectedVideo = null;
          _isVideoInitialized = false;
        });
        AppToast.show('Error loading video: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _selectMusic() async {
    // Show direct music options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        // height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
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
              'Add Music to Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // Upload from device
            ListTile(
              leading: const Icon(
                Icons.upload_file,
                color: Colors.purple,
                size: 28,
              ),
              title: const Text(
                'Upload from Device',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Add your own music file',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadMusicDirectly();
              },
            ),

            const SizedBox(height: 10),

            // Browse existing music
            ListTile(
              leading: const Icon(
                Icons.library_music,
                color: Colors.blue,
                size: 28,
              ),
              title: const Text(
                'Browse Music Library',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Choose from uploaded songs',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _browseExistingMusic();
              },
            ),

            const SizedBox(height: 10),

            // No music
            ListTile(
              leading: const Icon(
                Icons.music_off,
                color: Colors.grey,
                size: 28,
              ),
              title: const Text(
                'No Music',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Create video without music',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedMusic = null;
                  _isMusicPlaying = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadMusicDirectly() async {
    try {
      print('Starting direct music upload...');

      // Use the safe file picker from music browser
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
        allowMultiple: false,
        allowCompression: false,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        final fileName = result.files.first.name;

        if (filePath != null) {
          final file = File(filePath);

          if (await file.exists()) {
            // Create a temporary music track for preview
            final tempTrack = MusicTrack(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              title: fileName.split('.').first,
              artist: 'Local File',
              audioUrl: filePath,
              coverImageUrl: '', // No cover image for local files
              duration: 0, // Duration will be detected when playing
              genre: 'Local',
              uploadedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
              uploadedAt: DateTime.now(), // Use DateTime instead of Timestamp
              useCount: 0,
            );

            setState(() {
              _selectedMusic = tempTrack;
            });

            AppToast.show('Music selected: $fileName', isError: false);
            _playMusicPreview();
          } else {
            AppToast.show('Selected file does not exist', isError: true);
          }
        } else {
          AppToast.show('File path is invalid', isError: true);
        }
      }
    } catch (e) {
      print('Error uploading music directly: $e');
      AppToast.show('Error selecting music: $e', isError: true);
    }
  }

  Future<void> _browseExistingMusic() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MusicBrowserScreen(
          onMusicSelected: (track) {
            setState(() {
              _selectedMusic = track;
            });
            if (track != null) {
              _playMusicPreview();
            }
          },
        ),
      ),
    );
  }

  Future<void> _playMusicPreview() async {
    if (_selectedMusic == null) return;

    try {
      if (_isMusicPlaying) {
        await _previewPlayer.stop();
        setState(() {
          _isMusicPlaying = false;
        });
      } else {
        print('Attempting to play music: ${_selectedMusic!.audioUrl}');

        // Handle local files differently
        if (_selectedMusic!.id.startsWith('temp_')) {
          // For local files, use setFilePath instead of setUrl
          final audioFile = File(_selectedMusic!.audioUrl);

          if (!await audioFile.exists()) {
            throw Exception(
              'Audio file does not exist: ${_selectedMusic!.audioUrl}',
            );
          }

          final fileStat = await audioFile.stat();
          print('Audio file size: ${fileStat.size} bytes');

          if (fileStat.size == 0) {
            throw Exception('Audio file is empty');
          }

          print('Playing local file: ${audioFile.path}');
          await _previewPlayer.setFilePath(audioFile.path);
        } else {
          // For remote URLs, use setUrl
          print('Playing remote URL: ${_selectedMusic!.audioUrl}');
          await _previewPlayer.setUrl(_selectedMusic!.audioUrl);
        }

        await _previewPlayer.setVolume(_musicVolume);
        await _previewPlayer.play();
        setState(() {
          _isMusicPlaying = true;
        });

        // Auto-stop after 30 seconds
        Future.delayed(const Duration(seconds: 30), () async {
          if (_isMusicPlaying) {
            await _previewPlayer.stop();
            if (mounted) {
              setState(() {
                _isMusicPlaying = false;
              });
            }
          }
        });
      }
    } catch (e) {
      print('Error playing music preview: $e');
      setState(() {
        _isMusicPlaying = false;
      });
      AppToast.show('Cannot preview this audio file', isError: true);
    }
  }

  Future<void> _uploadVideo() async {
    // if (!context.read<UserStatusProvider>().isArtist) {
    //   AppToast.show('Only Artists can upload videos', isError: true);
    //   return;
    // }
    if (_selectedVideo == null) {
      AppToast.show('Please select a video first', isError: true);
      return;
    }

    // 🔐 Ensure user logged in
    final user = _auth.currentUser;
    if (user == null) {
      AppToast.show('User not logged in', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Simulate upload progress
      for (int i = 0; i <= 50; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _uploadProgress = i / 100;
        });
      }

      // Upload video to Firebase Storage
      String fileName = "videos/${DateTime.now().millisecondsSinceEpoch}.mp4";
      Reference storageRef = _storage.ref(fileName);
      UploadTask uploadTask = storageRef.putFile(
        _selectedVideo!,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress (defer setState to avoid layout-during-build)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes);
        final nextProgress = 0.5 + (progress * 0.5);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _uploadProgress = nextProgress);
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String videoUrl = await snapshot.ref.getDownloadURL();

      // Upload cover photo if selected
      String? coverUrl;
      if (_selectedCoverImage != null) {
        final coverFileName =
            "reel_covers/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg";
        final coverRef = _storage.ref(coverFileName);
        await coverRef.putFile(_selectedCoverImage!);
        coverUrl = await coverRef.getDownloadURL();
      }

      // Backend metadata: user_id, reel_id, caption, music_id, video_url, thumbnail_url, duration, created_at
      final description = _descriptionController.text.trim();
      final createdAt = FieldValue.serverTimestamp();
      Map<String, dynamic> videoData = {
        'userId': user.uid,
        'videoUrl': videoUrl,
        'description': description.isNotEmpty ? description : null,
        'likes': 0,
        'likedBy': <String>[],
        'views': 0,
        'public': true,
        'timestamp': createdAt,
        'createdAt': createdAt,
      };
      if (coverUrl != null && coverUrl.isNotEmpty) {
        videoData['coverUrl'] = coverUrl;
        videoData['thumbnailUrl'] = coverUrl;
      }

      final pending = _pendingEditData;
      if (pending != null) {
        final trimEndMs = (pending['trimEndMs'] as num?)?.toDouble();
        final trimStartMs = (pending['trimStartMs'] as num?)?.toDouble();
        if (trimEndMs != null && trimStartMs != null && trimEndMs > trimStartMs) {
          videoData['duration'] = ((trimEndMs - trimStartMs) / 1000.0).round();
        }
      }

      final musicToSave = _selectedMusic ?? _musicFromPendingEditData;
      if (musicToSave != null) {
        String finalAudioUrl = musicToSave.audioUrl;
        String finalMusicId = musicToSave.id;

        if (musicToSave.id.startsWith('temp_')) {
          print('Uploading local music file to Firebase...');

          final musicFile = File(musicToSave.audioUrl);
          if (await musicFile.exists()) {
            String musicFileName =
                "music/${DateTime.now().millisecondsSinceEpoch}_${musicToSave.title}.mp3";
            Reference musicStorageRef = _storage.ref(musicFileName);
            UploadTask musicUploadTask = musicStorageRef.putFile(musicFile);

            TaskSnapshot musicSnapshot = await musicUploadTask;
            finalAudioUrl = await musicSnapshot.ref.getDownloadURL();
            finalMusicId = 'uploaded_${DateTime.now().millisecondsSinceEpoch}';

            final musicData = {
              'id': finalMusicId,
              'title': musicToSave.title,
              'artist': musicToSave.artist,
              'genre': musicToSave.genre,
              'audioUrl': finalAudioUrl,
              'coverImageUrl': '',
              'uploadedBy': user.uid,
              'uploadedAt': FieldValue.serverTimestamp(),
              'useCount': 1,
              'duration': musicToSave.duration,
              'isTrending': false,
            };

            await FirebaseFirestore.instance
                .collection('musicTracks')
                .doc(finalMusicId)
                .set(musicData);

            print('Local music uploaded successfully: $finalAudioUrl');
          }
        }

        videoData['music'] = {
          'id': finalMusicId,
          'musicId': finalMusicId,
          'title': musicToSave.title,
          'artist': musicToSave.artist,
          'genre': musicToSave.genre,
          'audioUrl': finalAudioUrl,
          'musicUrl': finalAudioUrl,
          'duration': musicToSave.duration,
        };
        videoData['musicId'] = finalMusicId;
        videoData['musicVolume'] = _musicVolume;
        videoData['videoVolume'] = _videoVolume;

        if (!musicToSave.id.startsWith('temp_')) {
          await MusicService.incrementUseCount(musicToSave.id);
        }
      }

      if (_selectedFilter != 'None') {
        videoData['filter'] = _selectedFilter;
      }

      if (pending != null &&
          pending['caption'] != null &&
          pending['caption'] is Map) {
        final cap = pending['caption'] as Map<String, dynamic>;
        if (cap['text'] != null && (cap['text'] as String).isNotEmpty) {
          videoData['caption'] = cap;
        }
      }

      final docRef = await _firestore.collection('reels').add(videoData);
      await docRef.update({'reelId': docRef.id});

      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      AppToast.show('Video uploaded successfully!', isError: false);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      AppToast.show('Error uploading video: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.reelsSaveToFirestore != null)
                  Text(
                    'Step 1 of ${ReelTips.totalSteps} • ${ReelTips.step1Subtitle}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mq = MediaQuery.of(context);
          final screenWidth = mq.size.width;
          final horizontalPadding = (screenWidth * 0.05).clamp(12.0, 24.0);
          final bottomPadding = 20.0 + mq.padding.bottom;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video preview and editing section
                _buildVideoEditingSection(context),

                // Music section (skip when just returned from editor — already set there)
                if (_selectedVideo != null && !_cameFromEditor)
                  _buildMusicSection(context),

                // Filters and effects (skip when just returned from editor)
                if (!_cameFromEditor) _buildFiltersSection(context),
                // Description section
                _buildDescriptionSection(context),

                // Cover photo (optional)
                if (_selectedVideo != null) _buildCoverPhotoSection(context),

                // Upload button
                Container(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isUploading) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A2847),
                            const Color(0xFF16213E),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFBB86FC).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFBB86FC),
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Uploading...",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${(_uploadProgress * 100).toInt()}%",
                                style: const TextStyle(
                                  color: Color(0xFFBB86FC),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                        const SizedBox(height: 20),
                      ],
                      SubscriptionGuard(
                    userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                    onSubscribe: (context, email) async {
                      await _subscriptionService.showSubscriptionPopup(
                        context,
                        email,
                      );
                    },

                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isUploading ? null : _uploadVideo,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: _isUploading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Uploading...",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Post Video",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoEditingSection(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final screenWidth = mq.size.width;
    final margin = (screenWidth * 0.05).clamp(12.0, 24.0);
    final videoHeight = _selectedVideo != null
        ? (screenHeight * 0.45).clamp(220.0, 500.0)
        : (screenHeight * 0.25).clamp(160.0, 260.0);

    return Container(
      margin: EdgeInsets.all(margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video preview section with integrated music controls
          Container(
            width: double.infinity,
            height: videoHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _selectedVideo != null
                    ? [const Color(0xFF1A2847), const Color(0xFF16213E)]
                    : [
                        const Color(0xFF16213E).withOpacity(0.5),
                        const Color(0xFF1A2847).withOpacity(0.5),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedVideo != null
                    ? const Color(0xFFBB86FC).withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child:
                _selectedVideo != null &&
                    _isVideoInitialized &&
                    _videoController != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _SafeVideoPreview(
                      controller: _videoController!,
                      applyFilter: _applyVideoFilter,
                      onChangeVideo: _showVideoSourceDialog,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_camera_back,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Video',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildVideoButton(
                            'Camera',
                            Icons.camera_alt,
                            () => _pickVideo(ImageSource.camera),
                          ),
                          _buildVideoButton(
                            'Gallery',
                            Icons.photo_library,
                            () => _pickVideo(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Video editing tools — hidden when user just came from editor (preview-only flow)
          if (_selectedVideo != null && !_cameFromEditor) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBB86FC), Color(0xFF03DAC6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Video Tools',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF1A2847), const Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFBB86FC).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),

            // Volume control
            if (_selectedMusic == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF1A2847), const Color(0xFF16213E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF03DAC6).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF03DAC6), Color(0xFFBB86FC)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Video Volume',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(_videoVolume * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF03DAC6),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _videoVolume,
                      onChanged: (value) {
                        setState(() {
                          _videoVolume = value;
                        });
                        _videoController?.setVolume(value);
                      },
                      activeColor: const Color(0xFF03DAC6),
                      inactiveColor: Colors.white.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMusicSection(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final margin = (screenWidth * 0.05).clamp(12.0, 24.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple Music Addition - ONE TAP PROCESS
          if (_selectedMusic == null)
            // No music selected - show big add music button
            GestureDetector(
              onTap: _selectMusic,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFBB86FC).withOpacity(0.2),
                      const Color(0xFF03DAC6).withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFBB86FC).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBB86FC), Color(0xFF03DAC6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.library_music_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tap to Add Background Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose from your device or our library',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            // Music selected - show selected music with easy controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF1A2847), const Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFBB86FC).withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Music info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMusic!.title,
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
                              _selectedMusic!.artist,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Play/Stop button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isMusicPlaying
                                ? [Colors.red.shade600, Colors.red.shade800]
                                : [
                                    Colors.green.shade600,
                                    Colors.green.shade800,
                                  ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _playMusicPreview,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                _isMusicPlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Change music button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFBB86FC).withOpacity(0.2),
                              const Color(0xFF03DAC6).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFBB86FC).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _selectMusic,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'Change',
                                style: TextStyle(
                                  color: Color(0xFFBB86FC),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Volume controls
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFBB86FC),
                                    Color(0xFF03DAC6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Music Volume',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(_musicVolume * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFFBB86FC),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _musicVolume,
                          onChanged: (value) {
                            setState(() {
                              _musicVolume = value;
                            });
                            if (_isMusicPlaying) {
                              _previewPlayer.setVolume(value);
                            }
                          },
                          activeColor: const Color(0xFFBB86FC),
                          inactiveColor: Colors.white.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF03DAC6),
                                    Color(0xFFBB86FC),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.videocam_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Video Volume',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(_videoVolume * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFF03DAC6),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _videoVolume,
                          onChanged: (value) {
                            setState(() {
                              _videoVolume = value;
                            });
                            if (_isMusicPlaying) {
                              _videoController?.setVolume(value);
                            }
                          },
                          activeColor: const Color(0xFF03DAC6),
                          inactiveColor: Colors.white.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Music info will be shown in video preview area instead
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final margin = (screenWidth * 0.05).clamp(12.0, 24.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBB86FC), Color(0xFF03DAC6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_vintage_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filters & Effects',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final margin = (screenWidth * 0.05).clamp(12.0, 24.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBB86FC), Color(0xFF03DAC6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Description',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1A2847), const Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBB86FC).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Color(0xFFBB86FC),
                    size: 22,
                  ),
                ),
                filled: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPhotoSection(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final margin = (screenWidth * 0.05).clamp(12.0, 24.0);
    final coverMaxHeight = (screenHeight * 0.35).clamp(200.0, 320.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBB86FC).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: Color(0xFFBB86FC),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cover photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1A2847), const Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBB86FC).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCoverImage == null)
                  Row(
                    children: [
                      Icon(
                        Icons.image_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Optional',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add a cover so your reel looks better in the feed',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final XFile? img = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1080,
                            imageQuality: 85,
                          );
                          if (img != null) {
                            final path = img.path;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedCoverImage = File(path));
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.add_photo_alternate_rounded,
                          color: Color(0xFFBB86FC),
                          size: 20,
                        ),
                        label: const Text(
                          'Add cover',
                          style: TextStyle(
                            color: Color(0xFFBB86FC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: coverMaxHeight),
                    child: AspectRatio(
                      aspectRatio: 9 / 14,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBB86FC).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _selectedCoverImage!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 10,
                                right: 3,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () async {
                                          final XFile? img = await _picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 1080,
                                                imageQuality: 85,
                                              );
                                          if (img != null) {
                                            final path = img.path;
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              if (mounted) setState(() => _selectedCoverImage = File(path));
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.edit_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Change',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) setState(() => _selectedCoverImage = null);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _applyVideoFilter(Widget videoWidget) {
    if (_selectedFilter == 'None') {
      return videoWidget;
    }

    return ColorFiltered(
      colorFilter: _getColorFilter(_selectedFilter),
      child: videoWidget,
    );
  }

  ColorFilter _getColorFilter(String filter) {
    switch (filter) {
      case 'Black & White':
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Sepia':
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          1.0,
          0.0,
          0.0,
          0,
          20,
          0.0,
          1.0,
          0.0,
          0,
          10,
          0.0,
          0.0,
          0.8,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.8,
          0.0,
          0.2,
          0,
          0,
          0.0,
          0.9,
          0.1,
          0,
          0,
          0.0,
          0.0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.2,
          0.0,
          0.0,
          0,
          20,
          0.0,
          1.1,
          0.0,
          0,
          10,
          0.0,
          0.0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Bright':
        return const ColorFilter.matrix([
          1.2,
          0.0,
          0.0,
          0,
          30,
          0.0,
          1.2,
          0.0,
          0,
          30,
          0.0,
          0.0,
          1.2,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'Dark':
        return const ColorFilter.matrix([
          0.8,
          0.0,
          0.0,
          0,
          -20,
          0.0,
          0.8,
          0.0,
          0,
          -20,
          0.0,
          0.0,
          0.8,
          0,
          -20,
          0,
          0,
          0,
          1,
          0,
        ]);
      default:
        return const ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }

  Widget _buildVideoButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVideoSourceDialog() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Select Video Source',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.purple),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
    if (source != null && mounted) {
      await _pickVideo(source);
    }
  }
}

/// Defers video controller rebuilds to the next frame to avoid layout-during-build.
class _SafeVideoPreview extends StatefulWidget {
  const _SafeVideoPreview({
    required this.controller,
    required this.applyFilter,
    required this.onChangeVideo,
  });

  final VideoPlayerController controller;
  final Widget Function(Widget) applyFilter;
  final VoidCallback onChangeVideo;

  @override
  State<_SafeVideoPreview> createState() => _SafeVideoPreviewState();
}

class _SafeVideoPreviewState extends State<_SafeVideoPreview> {
  void _onControllerUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(_SafeVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (!c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
      );
    }
    final ar = c.value.aspectRatio;
    final safeAspectRatio = (ar.isFinite && ar > 0) ? ar : 9 / 16;
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: safeAspectRatio,
          child: widget.applyFilter(VideoPlayer(c)),
        ),
        GestureDetector(
          onTap: () {
            if (c.value.isPlaying) {
              c.pause();
            } else {
              c.play();
            }
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              c.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            onPressed: widget.onChangeVideo,
            icon: const Icon(Icons.edit, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
