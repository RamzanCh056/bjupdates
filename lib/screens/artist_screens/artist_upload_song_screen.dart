import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class ArtistUploadSongScreen extends StatefulWidget {
  final String artistId;
  final String artistName;
  const ArtistUploadSongScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  State<ArtistUploadSongScreen> createState() => _ArtistUploadSongScreenState();
}

class _ArtistUploadSongScreenState extends State<ArtistUploadSongScreen> {
  final _form = GlobalKey<FormState>();
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  int _year = DateTime.now().year;

  // Picked assets
  File? _file; // when a real path is available
  List<int>? _fileBytes; // when iOS returns bytes-only
  String? _fileName;

  File? _cover;
  List<int>? _coverBytes;
  String? _coverName;

  bool _loading = false;
  double? _audioProgress; // 0..1 (unused when indeterminate)
  double? _coverProgress; // 0..1 (unused when indeterminate)
  bool _audioUploading = false;
  bool _coverUploading = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      setState(() {
        _fileName = f.name;
        if (f.path != null) {
          _file = File(f.path!);
          _fileBytes = null;
        } else if (f.bytes != null) {
          _fileBytes = f.bytes!.toList();
          _file = null;
        }
      });
    }
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() {
        _coverName = x.name;
        // On iOS the path may be inaccessible later; prefer bytes
        _coverBytes = bytes.toList();
        _cover = File(x.path);
      });
    }
  }

  Future<File> _bytesToTempFile(
    List<int> bytes,
    String fileNameFallback,
  ) async {
    final dir = await getTemporaryDirectory();
    final safe = fileNameFallback.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final f = File('${dir.path}/$safe');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<String> _uploadAudio({required String path}) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    UploadTask task;
    if (_file != null) {
      task = ref.putFile(_file!, SettableMetadata(contentType: 'audio/mpeg'));
    } else if (_fileBytes != null) {
      final temp = await _bytesToTempFile(
        _fileBytes!,
        _fileName ?? 'audio.mp3',
      );
      task = ref.putFile(temp, SettableMetadata(contentType: 'audio/mpeg'));
    } else {
      throw Exception('No audio selected');
    }
    // Avoid snapshotEvents to prevent large platform messages; show indeterminate bar instead
    final snap = await task;
    return snap.ref.getDownloadURL();
  }

  Future<String?> _uploadCover({required String path}) async {
    if (_cover == null && _coverBytes == null) return null;
    final ref = FirebaseStorage.instance.ref().child(path);
    UploadTask task;
    if (_cover != null) {
      task = ref.putFile(_cover!, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      final temp = await _bytesToTempFile(
        _coverBytes!,
        _coverName ?? 'cover.jpg',
      );
      task = ref.putFile(temp, SettableMetadata(contentType: 'image/jpeg'));
    }
    // Avoid snapshotEvents to prevent large platform messages; show indeterminate bar instead
    final snap = await task;
    return snap.ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!context.read<UserStatusProvider>().isArtist) {
      AppToast.show('Only Artists can upload audio tracks', isError: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_file == null && _fileBytes == null) {
      AppToast.show('Please select an MP3 file', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _audioUploading = true;
      _coverUploading = (_cover != null || _coverBytes != null);
      _audioProgress = null;
      _coverProgress = null;
    });
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final audioUrl = await _uploadAudio(
        path: 'artist_songs/${widget.artistId}/$now.mp3',
      );
      setState(() => _audioUploading = false);
      final coverUrl = await _uploadCover(
        path: 'artist_songs/${widget.artistId}/$now.jpg',
      );
      setState(() => _coverUploading = false);

      await FirebaseFirestore.instance.collection('artistSongs').add({
        'artistId': widget.artistId,
        'title': _titleC.text.trim(),
        'description': _descC.text.trim(),
        'year': _year,
        'audioUrl': audioUrl,
        'coverUrl': coverUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        AppToast.show('Song uploaded');
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Upload failed';
        if (e.code == 'permission-denied')
          msg = 'Upload not permitted by Firebase Storage rules.';
        AppToast.show(msg, isError: true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to upload: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Song • ${widget.artistName}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: ListView(
                children: [
                  _darkField(
                    controller: _titleC,
                    label: 'Title',
                    validator: (v) => v!.isEmpty ? 'Enter title' : null,
                  ),
                  const SizedBox(height: 8),
                  _darkField(controller: _descC, label: 'Description'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                          ),
                          child: const Text(
                            'Pick MP3',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _fileName!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  if (_audioUploading) ...[
                    const SizedBox(height: 8),
                    _IndeterminateTile(label: 'Uploading MP3'),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _pickCover,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                          ),
                          child: const Text(
                            'Pick Cover Image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_coverName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _coverName!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  if (_coverUploading) ...[
                    const SizedBox(height: 8),
                    _IndeterminateTile(label: 'Uploading cover'),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _year,
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropdownDecoration('Year'),
                    items: List.generate(20, (i) {
                      final y = DateTime.now().year - i;
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }),
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _year = v!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB86FC),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Add Song',
                            style: TextStyle(color: Colors.black),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading) Container(color: Colors.black26),
        ],
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[900],
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFBB86FC)),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[900],
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFBB86FC)),
      ),
    );
  }
}

class _IndeterminateTile extends StatelessWidget {
  final String label;
  const _IndeterminateTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Color(0xFF2E2E2E),
                    valueColor: AlwaysStoppedAnimation(Color(0xFFBB86FC)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
