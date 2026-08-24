import 'dart:io';
import 'dart:typed_data';

import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

class ProVideoWithPicker extends StatefulWidget {
  const ProVideoWithPicker({super.key});

  @override
  State<ProVideoWithPicker> createState() => _ProVideoWithPickerState();
}

class _ProVideoWithPickerState extends State<ProVideoWithPicker> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedVideo; // nullable to avoid late initialization
  Uint8List? _renderedVideoBytes;
  bool _isRendering = false;
  String? _taskId;

  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  // Helper to create task when a video is picked
  RenderVideoModel _buildTaskFromPicked(XFile file) {
    final id = 'task-${DateTime.now().millisecondsSinceEpoch}';
    _taskId = id;

    return RenderVideoModel(
      id: id,
      video: EditorVideo.file(File(file.path)),
      imageBytes: null,
      outputFormat: VideoOutputFormat.mp4,
      enableAudio: true,
      playbackSpeed: 1.0,
      startTime: const Duration(seconds: 0),
      endTime: null,
      blur: 0,
      bitrate: 3000000,
      transform: const ExportTransform(
        flipX: false,
        flipY: false,
        x: 0,
        y: 0,
        width: 720,
        height: 1280,
        rotateTurns: 0,
        scaleX: 1.0,
        scaleY: 1.0,
      ),
    );
  }

  Future<void> pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      await _disposeVideoController();

      setState(() {
        _pickedVideo = file;
        _renderedVideoBytes = null;
        _taskId = null;
      });

      // Initialize video controller with picked video
      _videoController = VideoPlayerController.file(File(file.path));
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setPlaybackSpeed(_playbackSpeed);
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Video pick error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e')),
      );
    }
  }

  Future<void> renderPickedVideo() async {
    if (_pickedVideo == null) return;
    final task = _buildTaskFromPicked(_pickedVideo!);

    setState(() => _isRendering = true);

    try {
      final Uint8List result = await ProVideoEditor.instance.renderVideo(task);

      await _disposeVideoController();

      setState(() {
        _renderedVideoBytes = result;
      });

      // Save the rendered video bytes to a temp file for video_player usage
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/${_taskId!}.mp4';
      final file = File(filePath);
      await file.writeAsBytes(result);

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setPlaybackSpeed(_playbackSpeed);

      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Render error: $e');
      AppToast.show('Rendering failed: $e', isError: true);
    } finally {
      setState(() => _isRendering = false);
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Text('No video loaded.');
    }

    final duration = _videoController!.value.duration;
    final position = _videoController!.value.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (_isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
                setState(() {
                  _isPlaying = !_isPlaying;
                });
              },
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: duration.inMilliseconds.toDouble(),
                value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                onChanged: (value) {
                  _videoController!.seekTo(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Text('${position.inSeconds}s / ${duration.inSeconds}s'),
          ],
        ),
        Row(
          children: [
            const Text('Speed:'),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: _playbackSpeed,
              items: const [
                DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                DropdownMenuItem(value: 2.0, child: Text('2.0x')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _playbackSpeed = value;
                  _videoController!.setPlaybackSpeed(value);
                });
              },
            )
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _pickedVideo != null || _renderedVideoBytes != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pro Video Picker Example')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: _isRendering ? null : pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Pick Video from Gallery'),
              ),
              const SizedBox(height: 12),
              if (hasVideo)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pickedVideo != null)
                      Text('Selected: ${_pickedVideo!.name}'),
                    if (_renderedVideoBytes != null)
                      Text('Rendered video (${_renderedVideoBytes!.lengthInBytes} bytes)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: (_isRendering || _pickedVideo == null) ? null : renderPickedVideo,
                          child: const Text('Render Selected Video'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isRendering
                              ? null
                              : () async {
                                  await _disposeVideoController();
                                  setState(() {
                                    _pickedVideo = null;
                                    _renderedVideoBytes = null;
                                    _taskId = null;
                                    _isPlaying = false;
                                  });
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_taskId != null)
                      StreamBuilder<ProgressModel>(
                        stream: ProVideoEditor.instance.progressStreamById(_taskId!),
                        builder: (context, snapshot) {
                          final progress = snapshot.data?.progress ?? 0.0;
                          return Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(value: progress),
                              ),
                              const SizedBox(width: 12),
                              Text('${(progress * 100).toStringAsFixed(1)}%'),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    if (_isRendering) const Text('Rendering... please wait'),
                    _buildVideoPlayer(),
                  ],
                )
              else
                const Text('No video selected.'),
            ],
          ),
        ),
      ),
    );
  }
}
