import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../../utils/color.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Story creator — WhatsApp/Snapchat-style story creation flow.
///
/// Entry point: [StoryCreator.open]. Supports three story types:
///   • Text  — full-screen editor with background color, font and text color.
///   • Photo — pro_image_editor (draggable/scalable text, stickers, filters…).
///   • Video — record or pick, add draggable text overlays, trim, then export
///             (text burned into the video via pro_video_editor).
///
/// All three write to the Firestore `stories` collection using the schema
/// understood by StoryModel (see home1.dart), so they display in the existing
/// story tray and viewer.
/// ─────────────────────────────────────────────────────────────────────────
class StoryCreator {
  StoryCreator._();

  /// Max length for a video story (seconds).
  static const int maxVideoSeconds = 60;

  /// Opens the story-type chooser and runs the selected creation flow.
  ///
  /// [resolveDisplayName] resolves a user id to a display name (reuse the
  /// caller's resolver so names stay consistent). [onPosted] is invoked after a
  /// story has been successfully published (e.g. to refresh the home stories).
  static Future<void> open(
    BuildContext context, {
    required Future<String> Function(String userId) resolveDisplayName,
    required Future<void> Function() onPosted,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      AppToastLike.error('Please sign in to create a story');
      return;
    }

    final choice = await _showTypeChooser(context);
    if (choice == null) return;
    if (!context.mounted) return;

    bool posted = false;
    final picker = ImagePicker();

    switch (choice) {
      case _StoryType.text:
        posted =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TextStoryEditorScreen(
                  resolveDisplayName: resolveDisplayName,
                ),
                fullscreenDialog: true,
              ),
            ) ??
            false;
        break;

      case _StoryType.photo:
        final source = await _showSourceChooser(context, isVideo: false);
        if (source == null || !context.mounted) return;
        try {
          final XFile? img = await picker.pickImage(
            source: source,
            maxWidth: 1920,
            imageQuality: 90,
          );
          if (img == null || !context.mounted) return;
          posted =
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ImageStoryEditorScreen(
                    imageFile: File(img.path),
                    resolveDisplayName: resolveDisplayName,
                  ),
                  fullscreenDialog: true,
                ),
              ) ??
              false;
        } catch (e) {
          AppToastLike.error('Could not open photo: $e');
        }
        break;

      case _StoryType.video:
        final source = await _showSourceChooser(context, isVideo: true);
        if (source == null || !context.mounted) return;
        try {
          final XFile? vid = await picker.pickVideo(
            source: source,
            maxDuration: const Duration(seconds: maxVideoSeconds),
          );
          if (vid == null || !context.mounted) return;
          posted =
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => VideoStoryEditorScreen(
                    videoFile: File(vid.path),
                    resolveDisplayName: resolveDisplayName,
                  ),
                  fullscreenDialog: true,
                ),
              ) ??
              false;
        } catch (e) {
          AppToastLike.error('Could not open video: $e');
        }
        break;
    }

    if (posted) {
      await onPosted();
    }
  }

  // ── Type chooser bottom sheet ──────────────────────────────────────────
  static Future<_StoryType?> _showTypeChooser(BuildContext context) {
    return showModalBottomSheet<_StoryType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: darkBackgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Create story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _chooserTile(
                context,
                icon: Icons.text_fields_rounded,
                title: 'Text',
                subtitle: 'Write with colors and fonts',
                value: _StoryType.text,
              ),
              _chooserTile(
                context,
                icon: Icons.photo_camera_rounded,
                title: 'Photo',
                subtitle: 'Add text, stickers and more',
                value: _StoryType.photo,
              ),
              _chooserTile(
                context,
                icon: Icons.videocam_rounded,
                title: 'Video',
                subtitle: 'Record or pick, up to ${maxVideoSeconds}s',
                value: _StoryType.video,
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _chooserTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required _StoryType value,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera / gallery chooser ───────────────────────────────────────────
  static Future<ImageSource?> _showSourceChooser(
    BuildContext context, {
    required bool isVideo,
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: darkBackgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.camera_alt_rounded,
                  color: recntsColor,
                ),
                title: Text(
                  isVideo ? 'Record video' : 'Take photo',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: recntsColor,
                ),
                title: Text(
                  'Choose from gallery',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _StoryType { text, photo, video }

/// Small toast helper so this file doesn't depend on the app's AppToast.
class AppToastLike {
  static void info(String msg) => Fluttertoast.showToast(msg: msg);
  static void error(String msg) => Fluttertoast.showToast(msg: msg);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Shared upload service — writes stories to Storage + Firestore.
/// ─────────────────────────────────────────────────────────────────────────
class StoryUploadService {
  StoryUploadService._();

  static const Duration _storyLifetime = Duration(hours: 24);

  static Future<String> _ownerName(
    Future<String> Function(String) resolveDisplayName,
    String uid,
  ) async {
    try {
      final name = await resolveDisplayName(uid);
      if (name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return 'Me';
  }

  static Map<String, dynamic> _baseStory({
    required String ownerId,
    required String ownerName,
    required DateTime now,
  }) {
    return {
      'username': ownerName,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'isLive': false,
      'viewers': <String>[],
      'timestamp': Timestamp.fromDate(now),
      'expiryTime': Timestamp.fromDate(now.add(_storyLifetime)),
    };
  }

  /// Publishes a styled text story.
  static Future<bool> postTextStory({
    required String text,
    required int backgroundColor,
    required int textColor,
    required String fontFamily,
    required Future<String> Function(String) resolveDisplayName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now();
    final ownerName = await _ownerName(resolveDisplayName, user.uid);

    final data = _baseStory(ownerId: user.uid, ownerName: ownerName, now: now)
      ..addAll({
        'content': text,
        'textContent': text,
        'isImage': false,
        'mediaType': 'text',
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'fontFamily': fontFamily,
      });

    await FirebaseFirestore.instance.collection('stories').add(data);
    return true;
  }

  /// Publishes an image story from already-edited bytes.
  static Future<bool> postImageStory({
    required Uint8List bytes,
    required Future<String> Function(String) resolveDisplayName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now();
    final ownerName = await _ownerName(resolveDisplayName, user.uid);

    final ref = FirebaseStorage.instance.ref().child(
      'stories/${now.millisecondsSinceEpoch}_${user.uid}.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    final data = _baseStory(ownerId: user.uid, ownerName: ownerName, now: now)
      ..addAll({
        'content': url,
        'textContent': null,
        'isImage': true,
        'mediaType': 'image',
      });

    await FirebaseFirestore.instance.collection('stories').add(data);
    return true;
  }

  /// Publishes a video story. [thumbnailBytes] is optional.
  static Future<bool> postVideoStory({
    required File videoFile,
    Uint8List? thumbnailBytes,
    required Future<String> Function(String) resolveDisplayName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now();
    final ownerName = await _ownerName(resolveDisplayName, user.uid);
    final stamp = '${now.millisecondsSinceEpoch}_${user.uid}';

    final ref = FirebaseStorage.instance.ref().child('stories/$stamp.mp4');
    await ref.putFile(videoFile, SettableMetadata(contentType: 'video/mp4'));
    final url = await ref.getDownloadURL();

    String? thumbUrl;
    if (thumbnailBytes != null) {
      try {
        final tRef = FirebaseStorage.instance.ref().child(
          'stories/${stamp}_thumb.jpg',
        );
        await tRef.putData(
          thumbnailBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        thumbUrl = await tRef.getDownloadURL();
      } catch (_) {}
    }

    final data = _baseStory(ownerId: user.uid, ownerName: ownerName, now: now)
      ..addAll({
        'content': url,
        'textContent': null,
        'isImage': false,
        'mediaType': 'video',
        if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
      });

    await FirebaseFirestore.instance.collection('stories').add(data);
    return true;
  }
}

/// A translucent full-screen blocking loader.
class _PostingOverlay extends StatelessWidget {
  const _PostingOverlay({this.label = 'Posting…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: recntsColor),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// TEXT STORY EDITOR — WhatsApp-style.
/// ─────────────────────────────────────────────────────────────────────────
class TextStoryEditorScreen extends StatefulWidget {
  const TextStoryEditorScreen({super.key, required this.resolveDisplayName});

  final Future<String> Function(String userId) resolveDisplayName;

  @override
  State<TextStoryEditorScreen> createState() => _TextStoryEditorScreenState();
}

class _TextStoryEditorScreenState extends State<TextStoryEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Background color palette (solid).
  static const List<Color> _backgrounds = [
    Color(0xFF0A0E27),
    Color(0xFFB717DB),
    Color(0xFFD127AE),
    Color(0xFF3797F0),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
    Color(0xFF111827),
    Color(0xFFFFFFFF),
  ];

  static const List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Color(0xFFFFEB3B),
    Color(0xFF00E5FF),
    Color(0xFFFF4081),
    Color(0xFF69F0AE),
  ];

  static const List<String> _fonts = [
    'Roboto',
    'Montserrat',
    'Lobster',
    'Pacifico',
    'Oswald',
    'Dancing Script',
    'Bebas Neue',
    'Caveat',
    'Anton',
    'Playfair Display',
  ];

  int _bgIndex = 1;
  int _textColorIndex = 0;
  int _fontIndex = 0;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color get _bg => _backgrounds[_bgIndex];
  Color get _textColor => _textColors[_textColorIndex];
  String get _font => _fonts[_fontIndex];

  TextStyle get _textStyle {
    final base = TextStyle(
      color: _textColor,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    try {
      return GoogleFonts.getFont(_font, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  void _cycleFont() =>
      setState(() => _fontIndex = (_fontIndex + 1) % _fonts.length);

  void _cycleTextColor() => setState(
    () => _textColorIndex = (_textColorIndex + 1) % _textColors.length,
  );

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      AppToastLike.info('Write something first');
      return;
    }
    setState(() => _posting = true);
    try {
      final ok = await StoryUploadService.postTextStory(
        text: text,
        backgroundColor: _bg.value,
        textColor: _textColor.value,
        fontFamily: _font,
        resolveDisplayName: widget.resolveDisplayName,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _posting = false);
        AppToastLike.error('Could not post story');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      AppToastLike.error('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final onLight = _bg.computeLuminance() > 0.6;
    final iconColor = onLight ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor: _bg,
      // Keep the text centered in the FULL screen; the bottom bar lifts above
      // the keyboard manually via viewInsets padding below.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Tap anywhere to keep editing.
          Positioned(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode.requestFocus(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    cursorColor: _textColor,
                    style: _textStyle,
                    maxLength: 500,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Tap to type',
                      hintStyle: _textStyle.copyWith(
                        color: _textColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: iconColor, size: 28),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const Spacer(),
                  // Font cycle
                  _topButton(
                    onTap: _cycleFont,
                    child: Text(
                      'Aa',
                      style: GoogleFonts.getFont(
                        _font,
                        textStyle: TextStyle(
                          color: iconColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text color cycle
                  _topButton(
                    onTap: _cycleTextColor,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: iconColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: background palette + post button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 10
                    : MediaQuery.of(context).padding.bottom + 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _backgrounds.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final selected = i == _bgIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _bgIndex = i),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _backgrounds[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? recntsColor
                                      : Colors.white.withOpacity(0.6),
                                  width: selected ? 3 : 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _posting ? null : _post,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        gradient: appGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_posting) const _PostingOverlay(),
        ],
      ),
    );
  }

  Widget _topButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// IMAGE STORY EDITOR — wraps pro_image_editor, then uploads.
/// ─────────────────────────────────────────────────────────────────────────
class ImageStoryEditorScreen extends StatefulWidget {
  const ImageStoryEditorScreen({
    super.key,
    required this.imageFile,
    required this.resolveDisplayName,
  });

  final File imageFile;
  final Future<String> Function(String userId) resolveDisplayName;

  @override
  State<ImageStoryEditorScreen> createState() => _ImageStoryEditorScreenState();
}

class _ImageStoryEditorScreenState extends State<ImageStoryEditorScreen> {
  bool _handled = false;
  bool _posting = false;

  Future<void> _uploadAndClose(Uint8List bytes) async {
    if (_handled) return;
    _handled = true;
    setState(() => _posting = true);
    try {
      final ok = await StoryUploadService.postImageStory(
        bytes: bytes,
        resolveDisplayName: widget.resolveDisplayName,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ok);
    } catch (e) {
      if (!mounted) return;
      AppToastLike.error('Error posting: $e');
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProImageEditor.file(
          widget.imageFile,
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.material,
            theme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: recntsColor,
              colorScheme: const ColorScheme.dark(
                primary: recntsColor,
                secondary: indigoColor,
                surface: darkBackgroundPrimary,
                onSurface: Colors.white,
              ),
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
              ),
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              await _uploadAndClose(bytes);
            },
            onCloseEditor: (EditorMode mode) {
              // User cancelled (X). When Done is tapped we already handled it.
              if (mounted && !_handled) {
                _handled = true;
                Navigator.of(context).pop(false);
              }
            },
          ),
        ),
        if (_posting) const _PostingOverlay(),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// VIDEO STORY EDITOR — draggable text overlays + trim, then burn via
/// pro_video_editor.
/// ─────────────────────────────────────────────────────────────────────────
class _VideoTextOverlay {
  _VideoTextOverlay({
    required this.text,
    required this.center,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.colorValue = 0xFFFFFFFF,
    this.fontFamily = 'Roboto',
  });

  String text;
  Offset center; // pixel offset from top-left of the preview box
  double scale;
  double rotation;
  int colorValue;
  String fontFamily;

  // Transient values captured at the start of a scale/drag gesture.
  double metaScale = 1.0;
  double metaRotation = 0.0;

  static const double baseFontSize = 30;
}

class VideoStoryEditorScreen extends StatefulWidget {
  const VideoStoryEditorScreen({
    super.key,
    required this.videoFile,
    required this.resolveDisplayName,
  });

  final File videoFile;
  final Future<String> Function(String userId) resolveDisplayName;

  @override
  State<VideoStoryEditorScreen> createState() => _VideoStoryEditorScreenState();
}

class _VideoStoryEditorScreenState extends State<VideoStoryEditorScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;

  final List<_VideoTextOverlay> _overlays = [];
  Size _previewSize = Size.zero;

  // Source-derived geometry (set once the video is initialized). Using the
  // video's own aspect/size for preview + export keeps them identical and
  // avoids stretching a non-9:16 clip into a fixed frame.
  double _videoAspect = 9 / 16;
  int _exportW = 1080;
  int _exportH = 1920;

  // Trim
  double _durationMs = 0;
  RangeValues _trim = const RangeValues(0, 0);

  bool _exporting = false;
  double _exportProgress = 0;

  static const List<Color> _overlayColors = [
    Colors.white,
    Colors.black,
    Color(0xFFFFEB3B),
    Color(0xFF00E5FF),
    Color(0xFFFF4081),
    Color(0xFF69F0AE),
    Color(0xFFB717DB),
  ];
  static const List<String> _overlayFonts = [
    'Roboto',
    'Montserrat',
    'Lobster',
    'Pacifico',
    'Oswald',
    'Bebas Neue',
    'Anton',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(widget.videoFile);
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) return;
      c.setLooping(true);

      // Derive preview aspect + export size from the actual video so nothing
      // gets stretched into a fixed 9:16 frame.
      final vs = c.value.size;
      if (vs.width > 0 && vs.height > 0) {
        _videoAspect = vs.width / vs.height;
        double sw = vs.width, sh = vs.height;
        const double maxDim =
            1920; // cap the long side to keep files reasonable
        final double longSide = sw > sh ? sw : sh;
        final double scale = longSide > maxDim ? maxDim / longSide : 1.0;
        int ew = (sw * scale).round();
        int eh = (sh * scale).round();
        ew -= ew % 2; // even dimensions required by most codecs
        eh -= eh % 2;
        _exportW = ew < 2 ? 2 : ew;
        _exportH = eh < 2 ? 2 : eh;
      }

      final durMs = c.value.duration.inMilliseconds.toDouble();
      _durationMs = durMs;
      final cap = (StoryCreator.maxVideoSeconds * 1000).toDouble();
      final end = durMs > cap ? cap : durMs;
      _trim = RangeValues(0, end);
      setState(() => _ready = true);
      c.play();
      _watchTrim();
    } catch (e) {
      if (!mounted) return;
      AppToastLike.error('Could not load video: $e');
      Navigator.of(context).pop(false);
    }
  }

  // Loop playback within the trimmed range.
  void _watchTrim() {
    _controller?.addListener(() {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      final posMs = c.value.position.inMilliseconds.toDouble();
      if (posMs < _trim.start - 50 || posMs > _trim.end) {
        c.seekTo(Duration(milliseconds: _trim.start.toInt()));
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ── Add / edit a text overlay ──────────────────────────────────────────
  Future<void> _addOrEditText([_VideoTextOverlay? existing]) async {
    final result = await showModalBottomSheet<_VideoTextOverlay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextOverlayInputSheet(
        initial: existing,
        colors: _overlayColors,
        fonts: _overlayFonts,
      ),
    );
    if (result == null) return;
    setState(() {
      if (existing != null) {
        existing
          ..text = result.text
          ..colorValue = result.colorValue
          ..fontFamily = result.fontFamily;
        if (existing.text.trim().isEmpty) _overlays.remove(existing);
      } else if (result.text.trim().isNotEmpty) {
        _overlays.add(
          _VideoTextOverlay(
            text: result.text,
            center: Offset(_previewSize.width / 2, _previewSize.height / 2),
            colorValue: result.colorValue,
            fontFamily: result.fontFamily,
          ),
        );
      }
    });
  }

  TextStyle _overlayTextStyle(_VideoTextOverlay o) {
    final base = TextStyle(
      color: Color(o.colorValue),
      fontSize: _VideoTextOverlay.baseFontSize,
      fontWeight: FontWeight.w700,
      height: 1.2,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
      ],
    );
    try {
      return GoogleFonts.getFont(o.fontFamily, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  // ── Export overlay as a single transparent PNG at [w]x[h] ──────────────
  Future<Uint8List?> _buildOverlayBytes(int w, int h) async {
    if (_overlays.isEmpty || _previewSize == Size.zero) return null;

    // Make sure fonts are loaded so they render on the canvas.
    try {
      await GoogleFonts.pendingFonts([
        for (final o in _overlays) _overlayTextStyle(o),
      ]);
    } catch (_) {}

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final scaleX = w / _previewSize.width;
    final scaleY = h / _previewSize.height;

    for (final o in _overlays) {
      if (o.text.trim().isEmpty) continue;
      final fontSize = _VideoTextOverlay.baseFontSize * o.scale * scaleY;
      final tp = TextPainter(
        text: TextSpan(
          text: o.text,
          style: _overlayTextStyle(o).copyWith(fontSize: fontSize),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 5,
      );
      tp.layout(maxWidth: w * 0.9);

      canvas.save();
      canvas.translate(o.center.dx * scaleX, o.center.dy * scaleY);
      canvas.rotate(o.rotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  // ── Export + upload ────────────────────────────────────────────────────
  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportProgress = 0;
    });
    _controller?.pause();

    // Export at the video's own dimensions so the framing/quality is preserved.
    final int exportWidth = _exportW;
    final int exportHeight = _exportH;

    try {
      final overlayBytes = await _buildOverlayBytes(exportWidth, exportHeight);

      final startMs = _trim.start.toInt();
      final endMs = _trim.end.toInt();
      final taskId = 'story-${DateTime.now().millisecondsSinceEpoch}';

      final task = RenderVideoModel(
        id: taskId,
        video: EditorVideo.file(widget.videoFile),
        imageBytes: overlayBytes,
        outputFormat: VideoOutputFormat.mp4,
        enableAudio: true,
        startTime: Duration(milliseconds: startMs),
        endTime: Duration(milliseconds: endMs),
        bitrate: 4500000,
        transform: ExportTransform(
          flipX: false,
          flipY: false,
          x: 0,
          y: 0,
          width: exportWidth,
          height: exportHeight,
          rotateTurns: 0,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
      );

      final sub = ProVideoEditor.instance.progressStreamById(taskId).listen((
        data,
      ) {
        if (mounted) {
          setState(() => _exportProgress = data.progress.clamp(0.0, 1.0));
        }
      });

      Uint8List bytes;
      try {
        bytes = await ProVideoEditor.instance.renderVideo(task);
      } finally {
        await sub.cancel();
      }

      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/$taskId.mp4');
      await outFile.writeAsBytes(bytes);

      final ok = await StoryUploadService.postVideoStory(
        videoFile: outFile,
        resolveDisplayName: widget.resolveDisplayName,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ok);
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      AppToastLike.error('Could not export video: $e');
      _controller?.play();
    }
  }

  String _fmt(double ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video preview at the video's own aspect ratio (no distortion),
            // with the draggable text overlays on top. Preview geometry matches
            // the export geometry so what you see is what gets rendered.
            Positioned(
              child: Center(
                child: _ready && c != null
                    ? AspectRatio(
                        aspectRatio: _videoAspect > 0 ? _videoAspect : (9 / 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _previewSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return ClipRect(
                              child: Stack(
                                children: [
                                  // Fills the aspect box exactly -> undistorted.
                                  Positioned.fill(child: VideoPlayer(c)),
                                  for (final o in _overlays) _overlayWidget(o),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : const CircularProgressIndicator(color: recntsColor),
              ),
            ),

            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _exporting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                  const Spacer(),
                  _pillButton(
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    onTap: _exporting ? null : () => _addOrEditText(),
                  ),
                ],
              ),
            ),

            // Bottom: trim + post
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_ready && _durationMs > 0) ...[
                      Row(
                        children: [
                          Text(
                            _fmt(_trim.start),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: RangeSlider(
                              values: _trim,
                              min: 0,
                              max: _durationMs,
                              activeColor: recntsColor,
                              inactiveColor: Colors.white24,
                              onChanged: (v) {
                                // Enforce max clip length.
                                final maxLen =
                                    (StoryCreator.maxVideoSeconds * 1000)
                                        .toDouble();
                                var start = v.start;
                                var end = v.end;
                                if (end - start > maxLen) {
                                  if (start != _trim.start) {
                                    end = start + maxLen;
                                  } else {
                                    start = end - maxLen;
                                  }
                                }
                                setState(() => _trim = RangeValues(start, end));
                                _controller?.seekTo(
                                  Duration(milliseconds: start.toInt()),
                                );
                              },
                            ),
                          ),
                          Text(
                            _fmt(_trim.end),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _overlays.isEmpty
                                ? 'Tap “Text” to add captions'
                                : 'Drag • pinch • rotate text · tap to edit',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _exporting ? null : _export,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: appGradient,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_exporting)
              _PostingOverlay(
                label: 'Rendering… ${(_exportProgress * 100).toInt()}%',
              ),
          ],
        ),
      ),
    );
  }

  Widget _overlayWidget(_VideoTextOverlay o) {
    // Position by aligning the child's center at the normalized point.
    final align = _previewSize == Size.zero
        ? Alignment.center
        : Alignment(
            (o.center.dx / _previewSize.width) * 2 - 1,
            (o.center.dy / _previewSize.height) * 2 - 1,
          );
    return Positioned.fill(
      child: Align(
        alignment: align,
        child: GestureDetector(
          onTap: () => _addOrEditText(o),
          onScaleStart: (details) {
            o.metaScale = o.scale;
            o.metaRotation = o.rotation;
          },
          onScaleUpdate: (details) {
            setState(() {
              o.center += details.focalPointDelta;
              o.center = Offset(
                o.center.dx.clamp(0.0, _previewSize.width),
                o.center.dy.clamp(0.0, _previewSize.height),
              );
              o.scale = (o.metaScale * details.scale).clamp(0.4, 4.0);
              o.rotation = o.metaRotation + details.rotation;
            });
          },
          child: Transform.rotate(
            angle: o.rotation,
            child: Transform.scale(
              scale: o.scale,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  o.text,
                  textAlign: TextAlign.center,
                  style: _overlayTextStyle(o),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to type/edit an overlay's text, color and font.
class _TextOverlayInputSheet extends StatefulWidget {
  const _TextOverlayInputSheet({
    required this.initial,
    required this.colors,
    required this.fonts,
  });

  final _VideoTextOverlay? initial;
  final List<Color> colors;
  final List<String> fonts;

  @override
  State<_TextOverlayInputSheet> createState() => _TextOverlayInputSheetState();
}

class _TextOverlayInputSheetState extends State<_TextOverlayInputSheet> {
  late final TextEditingController _controller;
  late int _colorIndex;
  late int _fontIndex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.text ?? '');
    _colorIndex = widget.initial == null
        ? 0
        : widget.colors
              .indexWhere((c) => c.value == widget.initial!.colorValue)
              .clamp(0, widget.colors.length - 1);
    _fontIndex = widget.initial == null
        ? 0
        : widget.fonts
              .indexOf(widget.initial!.fontFamily)
              .clamp(0, widget.fonts.length - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _previewStyle() {
    final base = TextStyle(
      color: widget.colors[_colorIndex],
      fontSize: 22,
      fontWeight: FontWeight.w700,
    );
    try {
      return GoogleFonts.getFont(widget.fonts[_fontIndex], textStyle: base);
    } catch (_) {
      return base;
    }
  }

  void _done() {
    Navigator.of(context).pop(
      _VideoTextOverlay(
        text: _controller.text,
        center: Offset.zero,
        colorValue: widget.colors[_colorIndex].value,
        fontFamily: widget.fonts[_fontIndex],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: darkBackgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: recntsColor.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                maxLength: 200,
                textAlign: TextAlign.center,
                style: _previewStyle(),
                cursorColor: recntsColor,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Type text…',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            // Colors
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final selected = i == _colorIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: widget.colors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? recntsColor : Colors.white24,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Fonts
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.fonts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = i == _fontIndex;
                  TextStyle style;
                  final base = TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  );
                  try {
                    style = GoogleFonts.getFont(
                      widget.fonts[i],
                      textStyle: base,
                    );
                  } catch (_) {
                    style = base;
                  }
                  return GestureDetector(
                    onTap: () => setState(() => _fontIndex = i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? recntsColor.withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? recntsColor : Colors.white12,
                        ),
                      ),
                      child: Text('Aa', style: style),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: recntsColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _done,
                child: const Text(
                  'Done',
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
      ),
    );
  }
}
