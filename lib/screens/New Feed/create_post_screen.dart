import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/Stripe/SubscriptionHelper.dart';
import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import '../../model/music_track_model.dart';
import '../../model/question_model.dart';
import 'image_editor_screen.dart';

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  File? _selectedImage;
  bool _isUploading = false;
  TextEditingController descriptionController = TextEditingController();
  MusicTrack? _selectedMusic;

  // Tab controller for different post types
  late TabController _tabController;
  final SubscriptionServicefull _subscriptionService =
      SubscriptionServicefull();
  // Question creation state
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  String _selectedLocation = '';
  final List<String> _selectedTags = [];
  bool _isQuestionActive = true;
  DateTime? _expirationDate;

  // Music preview controls
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;
  double _musicVolume = 0.5;
  // Trim selection (in seconds)
  double _trackDurationSeconds = 0;
  double _clipStartSeconds = 0;
  double _clipEndSeconds = 15;
  StreamSubscription<Duration>? _positionSub;
  double _currentPosSeconds = 0;

  // AI generation state
  bool _isAIGenerating = false;

  // User display data for header (Facebook-style)
  String _userFirstName = 'There';
  String? _userProfileImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserDisplayData();
  }

  Future<void> _loadUserDisplayData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('usersData').doc(uid).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _userFirstName = data['firstName']?.toString() ?? 'There';
          _userProfileImage = data['profileImage']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      if (!mounted) return;
      await _showEditImageOption();
    }
  }

  /// Shows "Edit image?" dialog and opens editor if user chooses Edit.
  Future<void> _showEditImageOption() async {
    final edit = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: darkBackgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border.all(color: recntsColor.withOpacity(0.3)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Edit photo?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crop, filters, text & stickers',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recntsColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    if (edit == true && mounted && _selectedImage != null) {
      await _openImageEditor();
    }
  }

  Future<void> _openImageEditor() async {
    if (_selectedImage == null) return;
    final edited = await ImageEditorScreen.open(context, _selectedImage!);
    if (edited != null && mounted) {
      setState(() {
        _selectedImage = edited;
      });
    }
  }

  Future<void> _selectMusic() async {
    // Simple MP3 picker only (no extra fields)
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (res == null || res.files.single.path == null) return;

    final pickedPath = res.files.single.path!;
    final track = MusicTrack(
      id: 'local',
      title: 'My Music',
      artist: '',
      audioUrl: pickedPath,
      coverImageUrl: '',
      duration: 0,
      genre: '',
      uploadedAt: DateTime.now(),
      uploadedBy: _auth.currentUser?.uid ?? '',
    );
    setState(() {
      _selectedMusic = track;
    });
    await _setupPreview(track);
  }

  Future<void> _setupPreview(MusicTrack track) async {
    try {
      // Local mp3 vs remote url
      if (await File(track.audioUrl).exists()) {
        await _previewPlayer.setFilePath(track.audioUrl);
      } else {
        await _previewPlayer.setUrl(track.audioUrl);
      }
      await _previewPlayer.setVolume(_musicVolume);
      final dur = await _previewPlayer.durationStream.firstWhere(
        (d) => d != null,
      );
      _trackDurationSeconds = (dur ?? Duration.zero).inSeconds.toDouble();
      if (_trackDurationSeconds <= 0) {
        _trackDurationSeconds = 30; // fallback UI range
      }
      // Default 15s clip or full length if shorter
      _clipStartSeconds = 0;
      _clipEndSeconds = _trackDurationSeconds >= 15
          ? 15
          : _trackDurationSeconds;
      _positionSub?.cancel();
      _positionSub = _previewPlayer.positionStream.listen((pos) {
        final secs = pos.inSeconds.toDouble();
        if (mounted) {
          setState(() {
            _currentPosSeconds = secs;
          });
        }
        if (_isPreviewPlaying && secs >= _clipEndSeconds) {
          _previewPlayer.pause();
          _previewPlayer.seek(Duration(seconds: _clipStartSeconds.floor()));
          if (mounted) {
            setState(() {
              _isPreviewPlaying = false;
            });
          }
        }
      });
      setState(() {});
    } catch (e) {
      print('Error setting up preview: $e');
    }
  }

  Future<void> _togglePreview() async {
    try {
      if (_isPreviewPlaying) {
        await _previewPlayer.pause();
      } else {
        // Start from selected start point
        final withinClip =
            _currentPosSeconds >= _clipStartSeconds &&
            _currentPosSeconds <= _clipEndSeconds;
        if (!withinClip) {
          await _previewPlayer.seek(
            Duration(seconds: _clipStartSeconds.floor()),
          );
        }
        await _previewPlayer.play();
      }
      if (mounted) {
        setState(() {
          _isPreviewPlaying = !_isPreviewPlaying;
        });
      }
    } catch (e) {
      print('Error toggling preview: $e');
    }
  }

  static const String _uploadLogTag = '[CreatePost Upload]';

  Widget _addToPostIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }

  static const List<String> _quickEmojis = [
    '❤️', '🙌', '🔥', '🙏', '😢', '🥰', '😮', '😂', '👍', '🎉', '✨', '💯',
    '😊', '😍', '🤔', '😎', '🥳', '💪', '🙂', '😜',
  ];

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkBackgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Add emoji',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _quickEmojis.length,
                  itemBuilder: (context, index) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final emoji = _quickEmojis[index];
                          final text = descriptionController.text;
                          final selection = descriptionController.selection;
                          final offset = selection.baseOffset >= 0 && selection.extentOffset >= 0
                              ? selection.baseOffset
                              : text.length;
                          descriptionController.text = text.substring(0, offset) + emoji + text.substring(offset);
                          descriptionController.selection = TextSelection.collapsed(offset: offset + emoji.length);
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Text(_quickEmojis[index], style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isGettingLocation = false;

  Future<void> _pickLocation() async {
    if (_isGettingLocation) return;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppToast.show('Location permission denied', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        AppToast.show('Location permissions are permanently denied', isError: true);
        return;
      }
      setState(() => _isGettingLocation = true);
      AppToast.show('Getting location...', isError: false);
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            _selectedLocation = [p.locality, p.administrativeArea, p.country]
                .where((e) => e != null && e.isNotEmpty)
                .join(', ');
            if (_selectedLocation.isEmpty) _selectedLocation = p.country ?? 'Unknown';
            AppToast.show('Location added', isError: false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGettingLocation = false);
        AppToast.show('Could not get location. Try again.', isError: true);
      }
    }
  }

  Future<void> _uploadPost(String description) async {
    log('Starting post upload', name: _uploadLogTag);

    if (_selectedImage == null && description.trim().isEmpty) {
      log('Abort: no image and empty description', name: _uploadLogTag);
      AppToast.show(
        "Please add either text or image before posting!",
        isError: true,
      );
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      log('Abort: user not logged in', name: _uploadLogTag);
      AppToast.show("User not logged in.", isError: true);
      return;
    }
    log('User uid: ${user.uid}', name: _uploadLogTag);

    setState(() => _isUploading = true);

    try {
      log('Fetching user document...', name: _uploadLogTag);
      DocumentSnapshot userDoc = await _firestore
          .collection('usersData')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        log('Abort: usersData doc not found for ${user.uid}', name: _uploadLogTag);
        AppToast.show("User data not found!", isError: true);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String userFirstName = userData['firstName']?.toString() ?? 'Anonymous';
      String userSecondName = userData['secondName']?.toString() ?? '';
      String userImage = userData['profileImage']?.toString() ?? '';
      log('User data ok: $userFirstName', name: _uploadLogTag);

      String? fileUrl;
      String postType = 'text';

      if (_selectedImage != null) {
        log('Checking image file: ${_selectedImage!.path}', name: _uploadLogTag);
        if (!await _selectedImage!.exists()) {
          log('Abort: image file does not exist', name: _uploadLogTag);
          AppToast.show("Image file not found. Please select the image again.", isError: true);
          return;
        }
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        String fileType = 'posts';
        Reference storageRef = FirebaseStorage.instance.ref().child(
          '$fileType/${user.uid}/$fileName',
        );
        log('Reading image bytes...', name: _uploadLogTag);
        final imageBytes = await _selectedImage!.readAsBytes();
        log('Image size: ${imageBytes.length} bytes. Uploading to Storage...', name: _uploadLogTag);
        UploadTask uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        TaskSnapshot snapshot = await uploadTask;
        fileUrl = await snapshot.ref.getDownloadURL();
        log('Image uploaded. fileUrl: $fileUrl', name: _uploadLogTag);
        postType = 'image';
      }

      Map<String, dynamic> postData = {
        'userId': user.uid,
        'userFirstName': userFirstName,
        'userSecondName': userSecondName,
        'userImage': userImage,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'dislikes': 0,
        'comments': 0,
        'views': 0,
        'impressions': 0,
        'type': postType,
      };

      if (fileUrl != null) {
        postData['fileUrl'] = fileUrl;
      }

      if (_selectedLocation.isNotEmpty) {
        postData['location'] = _selectedLocation;
      }

      if (_selectedMusic != null) {
        String finalMusicUrl = _selectedMusic!.audioUrl;
        try {
          log('Uploading music...', name: _uploadLogTag);
          if (await File(_selectedMusic!.audioUrl).exists()) {
            final String fileName =
                'music_${DateTime.now().millisecondsSinceEpoch}.mp3';
            final ref = FirebaseStorage.instance.ref().child(
              'post_music/${user.uid}/$fileName',
            );
            final snap = await ref.putFile(File(_selectedMusic!.audioUrl));
            finalMusicUrl = await snap.ref.getDownloadURL();
            log('Music uploaded: $finalMusicUrl', name: _uploadLogTag);
          }
        } catch (e, st) {
          log('Error uploading music: $e\n$st', name: _uploadLogTag);
          print('$_uploadLogTag Error uploading music: $e');
        }

        postData['music'] = {
          'musicId': _selectedMusic!.id,
          'musicTitle': _selectedMusic!.title,
          'musicArtist': _selectedMusic!.artist,
          'musicUrl': finalMusicUrl,
          'musicStartTime': _clipStartSeconds.floor(),
          'musicClipDuration': (_clipEndSeconds - _clipStartSeconds).floor(),
          'musicVolume': _musicVolume,
        };
      }

      log('Writing post to Firestore (posts collection)...', name: _uploadLogTag);
      await _firestore.collection('posts').add(postData);
      log('Post document created. Sending notifications...', name: _uploadLogTag);

      await _sendNewPostNotificationToAllUsers();

      setState(() {
        _selectedImage = null;
        _selectedMusic = null;
        descriptionController.clear();
        _isPreviewPlaying = false;
      });

      AppToast.show("Post uploaded successfully!");
      log('Upload complete. Popping screen.', name: _uploadLogTag);
      Navigator.pop(context, true);
    } catch (e, stack) {
      print('$_uploadLogTag ERROR: $e');
      print('$_uploadLogTag STACK TRACE:\n$stack');
      log('Upload failed: $e', name: _uploadLogTag);
      log('Stack: $stack', name: _uploadLogTag);
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:?\s*', caseSensitive: false), '');
      AppToast.show(msg.length > 80 ? "Upload failed. Check connection and try again." : msg, isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _sendNewPostNotificationToAllUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final currentUserDoc = await _firestore
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';

      final usersSnapshot = await _firestore.collection('usersData').get();

      final trigger = TriggerNotificationService();
      int notificationCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId == currentUser.uid) continue;

        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            await trigger.sendPushNotification(
              token: fcmToken,
              title: 'New Post Alert! 📝',
              body: '$currentUserName just shared a new post',
            );
          } catch (e) {
            log('Error sending notification to user $userId: $e');
          }
        }

        final notificationData = {
          'type': 'new_post',
          'fromUserId': currentUser.uid,
          'fromUserName': currentUserName,
          'timestamp': FieldValue.serverTimestamp(),
          'message': '$currentUserName just shared a new post',
          'isRead': false,
        };

        await _firestore
            .collection('notifications')
            .doc(userId)
            .collection('userNotifications')
            .add(notificationData);

        notificationCount++;
      }

      log('New post notification sent to $notificationCount users');
    } catch (e) {
      log('Error sending new post notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press
        Navigator.pop(context);
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        backgroundColor: darkBackgroundPrimary,
        appBar: AppBar(
          backgroundColor: darkAppBarBackground,
          elevation: 0,
          title: const Text(
            "Create post",
            style: TextStyle(
              fontSize: 20,
              color: whiteColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 20, color: whiteColor),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: darkAppBarBackground,
              child: TabBar(
                controller: _tabController,
                indicatorColor: recntsColor,
                indicatorWeight: 3,
                labelColor: whiteColor,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: const [
                  Tab(text: "Post"),
                  Tab(text: "Poll"),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Regular Post Tab
            Container(
              color: darkBackgroundPrimary,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User row + "what's on your mind"
                    Container(
                      color: darkBackgroundSecondary,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: recntsColor.withOpacity(0.3),
                                backgroundImage: _userProfileImage != null && _userProfileImage!.isNotEmpty
                                    ? CachedNetworkImageProvider(_userProfileImage!)
                                    : null,
                                child: _userProfileImage == null || _userProfileImage!.isEmpty
                                    ? Text(
                                        _userFirstName.isNotEmpty ? _userFirstName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: whiteColor, fontWeight: FontWeight.w600, fontSize: 18),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _userFirstName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: whiteColor,
                                            ),
                                          ),
                                        ),
                                       
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: descriptionController,
                                      maxLines: 3,
                                      style: const TextStyle(fontSize: 16, color: whiteColor, height: 1.4),
                                      decoration: InputDecoration(
                                        hintText: "what's on your mind, $_userFirstName?",
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _showEmojiPicker,
                                icon: Icon(Icons.emoji_emotions_outlined, color: peopleColor, size: 26),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Content card (image with Edit / Remove or empty state)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: darkBackgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: recntsColor.withOpacity(0.25), width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _selectedImage != null
                            ? Stack(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 320,
                                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _openImageEditor,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: darkBackgroundSecondary.withOpacity(0.95),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: recntsColor.withOpacity(0.5)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit_rounded, size: 18, color: recntsColor),
                                              const SizedBox(width: 6),
                                              Text('Edit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: recntsColor)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedImage = null),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 20, color: whiteColor),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: double.infinity,
                                    height: 200,
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined, size: 48, color: recntsColor.withOpacity(0.7)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Add a photo or video',
                                          style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // AI caption (when image present)
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextButton.icon(
                          onPressed: () => _showAIGenerateSheet(),
                          icon: _isAIGenerating
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(recntsColor)))
                              : Icon(Icons.auto_awesome_rounded, size: 18, color: recntsColor),
                          label: Text(_isAIGenerating ? 'Generating…' : 'Suggest caption & hashtags', style: TextStyle(color: recntsColor, fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ),

                    // Add to your post - icon bar
                    Container(
                      color: darkBackgroundSecondary,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to your post',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _addToPostIcon(
                                icon: Icons.photo_library_outlined,
                                color: greenColor,
                                onTap: _pickImage,
                              ),
                              const SizedBox(width: 8),
                              _addToPostIcon(
                                icon: Icons.music_note_outlined,
                                color: recntsColor,
                                onTap: _selectMusic,
                              ),
                              const SizedBox(width: 8),
                              _addToPostIcon(
                                icon: Icons.emoji_emotions_outlined,
                                color: peopleColor,
                                onTap: _showEmojiPicker,
                              ),
                              const SizedBox(width: 8),
                              _addToPostIcon(
                                icon: Icons.location_on_outlined,
                                color: storeColor,
                                onTap: _isGettingLocation ? () {} : _pickLocation,
                              ),
                           
                            
                            ],
                          ),
                          if (_selectedMusic != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.music_note_rounded, size: 20, color: recntsColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_selectedMusic!.title}${_selectedMusic!.artist.isNotEmpty ? ' · ${_selectedMusic!.artist}' : ''}',
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _selectedMusic = null),
                                  child: Text('Remove', style: TextStyle(color: storeColor, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                          if (_selectedLocation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 20, color: storeColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedLocation,
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _selectedLocation = ''),
                                  child: Text('Remove', style: TextStyle(color: storeColor, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Music preview controls (when music selected)
                    if (_selectedMusic != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: darkBackgroundSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: recntsColor.withOpacity(0.25)),
                        ),
                        child: Row(
                            children: [
                              GestureDetector(
                                onTap: _togglePreview,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: appGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedMusic!.title,
                                      style: const TextStyle(
                                        color: whiteColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedMusic!.artist.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedMusic!.artist,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Trim selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Select clip',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${_formatSeconds(_clipStartSeconds)} - ${_formatSeconds(_clipEndSeconds)}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: RangeSlider(
                                values: RangeValues(
                                  _clipStartSeconds.clamp(
                                    0,
                                    _trackDurationSeconds,
                                  ),
                                  _clipEndSeconds.clamp(
                                    0,
                                    _trackDurationSeconds,
                                  ),
                                ),
                                min: 0,
                                max: _trackDurationSeconds > 0
                                    ? _trackDurationSeconds
                                    : 30,
                                divisions: (_trackDurationSeconds > 0
                                    ? _trackDurationSeconds.toInt()
                                    : 30),
                                activeColor: recntsColor,
                                inactiveColor: Colors.white24,
                                onChanged: (rng) {
                                  setState(() {
                                    // Keep at least 2s clip
                                    _clipStartSeconds = rng.start;
                                    _clipEndSeconds = rng.end;
                                    if ((_clipEndSeconds - _clipStartSeconds) <
                                        2) {
                                      _clipEndSeconds = _clipStartSeconds + 2;
                                    }
                                  });
                                  // If playing and cursor outside, seek into the clip start
                                  if (_isPreviewPlaying &&
                                      (_currentPosSeconds < _clipStartSeconds ||
                                          _currentPosSeconds >
                                              _clipEndSeconds)) {
                                    _previewPlayer.seek(
                                      Duration(
                                        seconds: _clipStartSeconds.floor(),
                                      ),
                                    );
                                  }
                                },
                                onChangeEnd: (rng) async {
                                  // Snap to start when user finishes adjusting
                                  if (_isPreviewPlaying) {
                                    await _previewPlayer.seek(
                                      Duration(
                                        seconds: _clipStartSeconds.floor(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            // Current time vs total duration for the selected clip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatSeconds(_currentPosSeconds),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatSeconds(_clipEndSeconds),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Current playhead inside selected clip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Slider(
                                value: _currentPosSeconds.clamp(
                                  _clipStartSeconds,
                                  _clipEndSeconds,
                                ),
                                min: _clipStartSeconds,
                                max: _clipEndSeconds,
                                activeColor: recntsColor,
                                inactiveColor: Colors.white12,
                                onChanged: (v) async {
                                  // Allow scrubbing within the clip
                                  setState(() {
                                    _currentPosSeconds = v;
                                  });
                                  await _previewPlayer.seek(
                                    Duration(seconds: v.floor()),
                                  );
                                },
                                onChangeStart: (_) {
                                  // Pause while scrubbing
                                  if (_isPreviewPlaying) {
                                    _previewPlayer.pause();
                                  }
                                },
                                onChangeEnd: (_) async {
                                  if (_isPreviewPlaying) {
                                    await _previewPlayer.play();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        // Volume slider
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.volume_down_rounded,
                                color: recntsColor,
                                size: 20,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _musicVolume,
                                  min: 0,
                                  max: 1,
                                  divisions: 10,
                                activeColor: recntsColor,
                                inactiveColor: Colors.white24,
                                onChanged: (v) async {
                                    setState(() => _musicVolume = v);
                                    try {
                                      await _previewPlayer.setVolume(v);
                                    } catch (_) {}
                                  },
                                ),
                              ),
                              const Icon(
                                Icons.volume_up_rounded,
                                color: recntsColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                    const SizedBox(height: 16),
                      SubscriptionGuard(
                        userEmail:
                            FirebaseAuth.instance.currentUser?.email ?? '',
                        onSubscribe: (context, email) async {
                          await _subscriptionService.showSubscriptionPopup(
                            context,
                            email,
                          );
                        },

                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Material(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (_selectedImage == null && descriptionController.text.trim().isEmpty) {
                                  AppToast.show("Add a photo or caption first.", isError: true);
                                  return;
                                }
                                _uploadPost(descriptionController.text.trim());
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: appGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        "Post",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Question Tab
            _buildQuestionTab(),
          ],
        ),
      ),
    );
  }

  // Build Question Tab
  Widget _buildQuestionTab() {
    return Container(
      color: const Color(0xFF0A0E27),
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Input
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.quiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "What's your question?",
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
                    colors: [const Color(0xFF16213E), const Color(0xFF1A2847)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFBB86FC).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _questionController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Ask your question here...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFBB86FC),
                        size: 22,
                      ),
                    ),
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
                ),
              ),
              const SizedBox(height: 24),

              // Options Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBB86FC).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.radio_button_checked_rounded,
                      color: Color(0xFFBB86FC),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Options (2-6 choices)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Options List
              ...List.generate(_optionControllers.length, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF16213E),
                                const Color(0xFF1A2847),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFBB86FC).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _optionControllers[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: "Option ${index + 1}",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () => _removeOption(index),
                            icon: const Icon(
                              Icons.remove_circle_rounded,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              // Add Option Button
              if (_optionControllers.length < 6)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFBB86FC).withOpacity(0.2),
                        const Color(0xFF03DAC6).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBB86FC).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addOption,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: appGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Add Option",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Location removed per request

              // Tags Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03DAC6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tag_rounded,
                      color: Color(0xFF03DAC6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Tags (Optional)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTagChip("TechJourney", Colors.purple),
                  _buildTagChip("Admissions", Colors.orange),
                  _buildTagChip("Education", Colors.blue),
                  _buildTagChip("Career", Colors.green),
                  _buildTagChip("Life", Colors.pink),
                ],
              ),
              SizedBox(height: 30),

              SubscriptionGuard(
                userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                onSubscribe: (context, email) async {
                  await _subscriptionService.showSubscriptionPopup(
                    context,
                    email,
                  );
                },

                child: Container(
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _createQuestionPost,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Post Question",
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
      ),
    );
  }

  // Build Video Tab
  Widget _buildVideoTab() {
    return Container(
      color: Color(0xFF1E1E1E),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              "Video Creation",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Coming Soon!",
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create_video');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                "Go to Video Creator",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Tag Chip
  Widget _buildTagChip(String tag, Color color) {
    bool isSelected = _selectedTags.contains(tag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedTags.remove(tag);
            } else {
              _selectedTags.add(tag);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.transparent : color.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: const [],
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Build AI Option
  Widget _buildAIOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2847).withOpacity(0.5),
                const Color(0xFF16213E).withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFBB86FC).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFBB86FC),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add option to question
  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  // Remove option from question
  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  // Create question post
  Future<void> _createQuestionPost() async {


    if (_questionController.text.trim().isEmpty) {
      AppToast.show("Please enter a question!", isError: true);
      return;
    }

    // final isArtist = context.read<UserStatusProvider>().isArtist;
    // if (!isArtist) {
    //   AppToast.show('Only Artists can post to the Poll', isError: true);
    //   return;
    // }

    List<String> validOptions = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      AppToast.show("Please add at least 2 options!", isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await _firestore
          .collection('usersData')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        AppToast.show("User data not found!", isError: true);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String userFirstName = userData['firstName']?.toString() ?? 'Anonymous';
      String userSecondName = userData['secondName']?.toString() ?? '';
      String userImage = userData['profileImage']?.toString() ?? '';

      // Create question options
      List<QuestionOption> options = validOptions.asMap().entries.map((entry) {
        return QuestionOption(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              entry.key.toString(),
          text: entry.value,
          votes: 0,
          voters: [],
        );
      }).toList();

      // Create question post
      QuestionPost questionPost = QuestionPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userFirstName: userFirstName,
        userSecondName: userSecondName,
        userImage: userImage,
        question: _questionController.text.trim(),
        location: null,
        options: options,
        timestamp: DateTime.now(),
        tags: _selectedTags,
        isActive: _isQuestionActive,
        expiresAt: _expirationDate,
      );

      // Save to Firestore
      await _firestore
          .collection('questions')
          .doc(questionPost.id)
          .set(questionPost.toMap());

      // Also save as a regular post for feed display
      Map<String, dynamic> postData = {
        'userId': user.uid,
        'userFirstName': userFirstName,
        'userSecondName': userSecondName,
        'userImage': userImage,
        'description': _questionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'dislikes': 0,
        'comments': 0,
        'views': 0,
        'impressions': 0,
        'type': 'question',
        'questionId': questionPost.id,
        'location': null,
        'tags': _selectedTags,
      };

      await _firestore.collection('posts').doc(questionPost.id).set(postData);

      AppToast.show("Question posted successfully!");

      // Clear form
      _questionController.clear();
      for (var controller in _optionControllers) {
        controller.clear();
      }
      _selectedLocation = '';
      _selectedTags.clear();
      _isQuestionActive = true;
      _expirationDate = null;

      Navigator.pop(context);
    } catch (e) {
      print("Error creating question: $e");
      AppToast.show("Error creating question: $e", isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ========== AI helpers ==========
  Future<void> _showAIGenerateSheet() async {
    if (_isAIGenerating) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF16213E), const Color(0xFF1A2847)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFFBB86FC).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Let AI help',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAIOption(
                    icon: Icons.text_fields_rounded,
                    title: 'Generate Caption',
                    subtitle: 'AI-powered caption for your image',
                    onTap: () async {
                      Navigator.pop(context);
                      await _generateCaption();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildAIOption(
                    icon: Icons.tag_rounded,
                    title: 'Generate Hashtags',
                    subtitle: 'Create trending hashtags',
                    onTap: () async {
                      Navigator.pop(context);
                      await _generateHashtags();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateCaption() async {
    final prompt =
        'Analyze the attached image and write a short, catchy, emoji-friendly social media caption (max 140 chars). Keep it relevant to the image content.';
    await _runAIVision(prompt, insertMode: _InsertMode.caption);
  }

  Future<void> _generateHashtags() async {
    final prompt =
        'Analyze the attached image and generate 8-12 relevant, trending hashtags. Output as a single line of space-separated hashtags only, no explanations.';
    await _runAIVision(prompt, insertMode: _InsertMode.hashtags);
  }

  Future<void> _runAI(String prompt, {required _InsertMode insertMode}) async {
    setState(() {
      _isAIGenerating = true;
    });
    try {
      final response = await http.post(
        Uri.parse(OpenAiConfig.chatCompletionsUrl),
        headers: OpenAiConfig.jsonAuthHeaders,
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are BJAI (BeatJerky AI). Generate concise social captions and hashtags.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 120,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = (data['choices'][0]['message']['content'] as String)
            .trim();
        setState(() {
          if (insertMode == _InsertMode.caption) {
            if (descriptionController.text.trim().isEmpty) {
              descriptionController.text = text;
            } else {
              descriptionController.text =
                  descriptionController.text.trim() + '\n' + text;
            }
          } else {
            final withSpace = descriptionController.text.trim().isEmpty
                ? ''
                : '\n';
            descriptionController.text =
                descriptionController.text.trim() + withSpace + text;
          }
        });
      } else {
        AppToast.show('AI error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      AppToast.show('AI error: $e', isError: true);
    } finally {
      if (mounted)
        setState(() {
          _isAIGenerating = false;
        });
    }
  }

  Future<void> _runAIVision(
    String prompt, {
    required _InsertMode insertMode,
  }) async {
    if (_selectedImage == null) {
      AppToast.show('Please add an image first.', isError: true);
      return;
    }
    setState(() {
      _isAIGenerating = true;
    });
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final b64 = base64Encode(bytes);
      final response = await http.post(
        Uri.parse(OpenAiConfig.chatCompletionsUrl),
        headers: OpenAiConfig.jsonAuthHeaders,
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,' + b64},
                },
              ],
            },
          ],
          'max_tokens': 120,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = (data['choices'][0]['message']['content'] as String)
            .trim();
        setState(() {
          if (insertMode == _InsertMode.caption) {
            if (descriptionController.text.trim().isEmpty) {
              descriptionController.text = text;
            } else {
              descriptionController.text =
                  descriptionController.text.trim() + '\n' + text;
            }
          } else {
            final withSpace = descriptionController.text.trim().isEmpty
                ? ''
                : '\n';
            descriptionController.text =
                descriptionController.text.trim() + withSpace + text;
          }
        });
      } else {
        AppToast.show('AI error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      AppToast.show('AI error: $e', isError: true);
    } finally {
      if (mounted)
        setState(() {
          _isAIGenerating = false;
        });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _positionSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }
}

String _formatSeconds(double secs) {
  final d = Duration(seconds: secs.floor());
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

enum _InsertMode { caption, hashtags }
