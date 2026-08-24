import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Full-screen image editor for create post flow.
/// Supports: crop, resize, rotate/flip, brightness & contrast, saturation,
/// filters, blur/sharpen, text, stickers/shapes.
/// Returns the edited image [File] when user taps Done, or null when cancelled.
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({
    super.key,
    required this.imageFile,
  });

  final File imageFile;

  /// Opens the editor and returns the edited [File], or null if cancelled.
  static Future<File?> open(BuildContext context, File imageFile) async {
    final result = await Navigator.of(context).push<File?>(
      MaterialPageRoute<File?>(
        builder: (context) => ImageEditorScreen(imageFile: imageFile),
        fullscreenDialog: true,
      ),
    );
    return result;
  }

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  /// True after we've already popped in onImageEditingComplete.
  /// Prevents double-pop: package calls onCloseEditor after onImageEditingComplete
  /// when user taps Done, which would otherwise pop Create Post and go to Feed.
  bool _alreadyPopped = false;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      widget.imageFile,
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF3797F0),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF3797F0),
            secondary: const Color(0xFF3797F0),
            surface: const Color(0xFF000000),
            onSurface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF000000),
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
      ),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          try {
            final dir = await getTemporaryDirectory();
            final path = '${dir.path}/edited_post_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(path);
            await file.writeAsBytes(bytes);
            if (mounted && !_alreadyPopped) {
              _alreadyPopped = true;
              Navigator.of(context).pop(file);
            }
          } catch (e) {
            if (mounted && !_alreadyPopped) {
              _alreadyPopped = true;
              Navigator.of(context).pop();
            }
          }
        },
        onCloseEditor: (EditorMode mode) {
          // Only pop when user cancels (X). When user taps Done, we already
          // popped in onImageEditingComplete; package still calls this after.
          if (mounted && !_alreadyPopped) {
            _alreadyPopped = true;
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
