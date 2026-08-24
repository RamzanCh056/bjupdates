import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music Picker Demo',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const MusicPickerScreen(),
    );
  }
}

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  File? _audioFile;

  Future<void> _pickMusic() async {
    // 1️⃣  Check & request permission
    final status = await Permission.audio.request(); // iOS
    // For Android 13+, audio covers READ_MEDIA_AUDIO; for Android <13 we add storage.
    final storageStatus = await Permission.storage.request();

    if (!status.isGranted && !storageStatus.isGranted) {
      AppToast.show(
        'Permission denied. Cannot pick music.', 
         
      );
      return;
    }

    // 2️⃣  Pick audio file
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;

    setState(() => _audioFile = File(result.files.single.path!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a Song')),
      body: Center(
        child: _audioFile == null
            ? const Text('No song selected.')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 48),
            const SizedBox(height: 12),
            Text(
              _audioFile!.path.split('/').last,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(_audioFile!.path,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickMusic,
        icon: const Icon(Icons.library_music),
        label: const Text('Pick Music'),
      ),
    );
  }
}
    