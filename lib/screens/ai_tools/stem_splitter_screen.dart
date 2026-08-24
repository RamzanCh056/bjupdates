import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/stem_splitter_service.dart';
import 'package:beatjerky/services/viral_score_predictor_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class _StemOption {
  final String title;
  final String description;
  final IconData icon;
  final String outputFileName;

  const _StemOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.outputFileName,
  });
}

class StemSplitterScreen extends StatefulWidget {
  const StemSplitterScreen({super.key});

  @override
  State<StemSplitterScreen> createState() => _StemSplitterScreenState();
}

class _StemSplitterScreenState extends State<StemSplitterScreen> {
  static const List<String> _qualities = [
    'High (Best Quality)',
    'Medium',
    'Fast (Lower Quality)',
  ];
  static const List<String> _formats = ['WAV', 'MP3', 'FLAC'];
  static const List<_StemOption> _stemOptions = [
    _StemOption(
      title: 'Vocals',
      description: 'Extract vocal track',
      icon: Icons.mic_none_rounded,
      outputFileName: 'My_Track_Vocals.wav',
    ),
    _StemOption(
      title: 'Drums',
      description: 'Extract drum track',
      icon: Icons.album_outlined,
      outputFileName: 'My_Track_Drums.wav',
    ),
    _StemOption(
      title: 'Bass',
      description: 'Extract bass track',
      icon: Icons.electric_bolt_rounded,
      outputFileName: 'My_Track_Bass.wav',
    ),
    _StemOption(
      title: 'Other Instruments',
      description: 'Extract remaining instruments',
      icon: Icons.piano_off_outlined,
      outputFileName: 'My_Track_Other.wav',
    ),
    _StemOption(
      title: 'Piano',
      description: 'Extract piano track',
      icon: Icons.piano_rounded,
      outputFileName: 'My_Track_Piano.wav',
    ),
  ];

  String? _trackFileName;
  String? _trackDuration;
  int _trackDurationSeconds = 0;
  bool _hasUploadedTrack = false;
  bool _hasOutputStems = false;
  bool _isSplitting = false;
  int _splitProgress = 0;
  StemAnalysisResult? _analysis;
  Timer? _progressTimer;
  String _selectedQuality = _qualities.first;
  String _selectedFormat = _formats.first;
  final Map<String, bool> _selectedStems = {
    for (final option in _stemOptions) option.title: true,
  };

  void _showInfoDialog() {
    AiToolsInfoDialog.show(
      context,
      title: 'Stem Splitter',
      message:
          'Upload a mixed track, choose the stems you want, and split them into separate files.',
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickTrack() async {
    if (_isSplitting) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        AppToast.show('Could not read file.', isError: true);
        return;
      }
      final track = await ViralScorePredictorService.probeLocalTrack(
        fileName: file.name,
        localPath: path,
      );
      setState(() {
        _trackFileName = track.fileName;
        _trackDuration = track.durationLabel;
        _trackDurationSeconds = track.durationSeconds;
        _hasUploadedTrack = true;
        _hasOutputStems = false;
        _analysis = null;
      });
    } catch (error, stackTrace) {
      logDebugException('StemSplitterScreen.pickTrack', error, stackTrace: stackTrace);
      AppToast.show('Upload failed.', isError: true);
    }
  }

  void _clearUploadedTrack() {
    setState(() {
      _hasUploadedTrack = false;
      _hasOutputStems = false;
      _trackFileName = null;
      _trackDuration = null;
      _analysis = null;
    });
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted || !_isSplitting) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_splitProgress < 92) {
          _splitProgress = (_splitProgress + 1 + math.Random().nextInt(2)).clamp(1, 92);
        }
      });
    });
  }

  Future<void> _splitStems() async {
    if (!_hasUploadedTrack || _trackFileName == null) {
      AppToast.show('Upload an audio file first.', isError: true);
      return;
    }
    final selected = _selectedStems.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selected.isEmpty) {
      AppToast.show('Select at least one stem to extract.', isError: true);
      return;
    }
    if (_isSplitting) return;

    setState(() {
      _isSplitting = true;
      _splitProgress = 1;
      _hasOutputStems = false;
      _analysis = null;
    });
    _startProgressTimer();

    try {
      final analysis = await StemSplitterService.analyzeTrack(
        fileName: _trackFileName!,
        durationSeconds: _trackDurationSeconds,
        selectedStems: selected,
        quality: _selectedQuality,
        format: _selectedFormat,
      );

      _progressTimer?.cancel();
      if (!mounted) return;
      setState(() => _splitProgress = 100);
      await Future.delayed(const Duration(milliseconds: 300));

      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'stem',
          title: _trackFileName!,
          sourceTool: 'Stem Splitter',
          textContent: analysis.toLibraryText(),
          metadata: {
            'stems': selected,
            'quality': _selectedQuality,
            'format': _selectedFormat,
          },
        ),
      );

      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _hasOutputStems = true;
        _isSplitting = false;
      });
      AppToast.show('Stem analysis saved to library.');
    } catch (error, stackTrace) {
      _progressTimer?.cancel();
      logDebugException('StemSplitterScreen.split', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isSplitting = false;
          _splitProgress = 0;
        });
      }
      AppToast.show(error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiToolsScreen(
          title: 'Stem Splitter',
          onInfo: _showInfoDialog,
          children: [
            const AiToolsSectionTitle(text: 'Upload your audio'),
            const SizedBox(height: 10),
            _hasUploadedTrack && _trackFileName != null
                ? _UploadedAudioCard(
                    fileName: _trackFileName!,
                    duration: _trackDuration ?? '',
                    onClose: _isSplitting ? () {} : _clearUploadedTrack,
                  )
                : _UploadAudioPlaceholder(
                    onTap: _isSplitting ? () {} : _pickTrack,
                  ),
        const SizedBox(height: 22),
        const AiToolsSectionTitle(text: 'Select Stems to Extract'),
        const SizedBox(height: 10),
        ..._stemOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StemSelectionRow(
              option: option,
              value: _selectedStems[option.title] ?? false,
              onChanged: (value) {
                setState(() => _selectedStems[option.title] = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const AiToolsSectionTitle(text: 'Advanced Settings'),
        const SizedBox(height: 12),
        _SettingsDropdown(
          label: 'Quality',
          value: _selectedQuality,
          items: _qualities,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedQuality = value);
          },
        ),
        const SizedBox(height: 14),
        _SettingsDropdown(
          label: 'Format',
          value: _selectedFormat,
          items: _formats,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedFormat = value);
          },
        ),
        const SizedBox(height: 24),
        AiToolsPrimaryButton(
          label: _isSplitting ? 'Analyzing...' : 'Split Stems',
          onPressed: _isSplitting ? () {} : _splitStems,
        ),
        const SizedBox(height: 28),
        const AiToolsSectionTitle(text: 'Output Stems'),
        const SizedBox(height: 10),
        if (_hasOutputStems && _analysis != null)
          AiToolsGlassCard(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _analysis!.toLibraryText(),
              style: TextStyle(
                color: AiToolsTheme.textPrimary.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          )
        else
          const AiToolsEmptyState(
            message: 'Upload a track and tap Split Stems to analyze and save.',
          ),
          ],
        ),
        if (_isSplitting)
          _StemProgressOverlay(progress: _splitProgress),
      ],
    );
  }
}

class _StemProgressOverlay extends StatelessWidget {
  final int progress;

  const _StemProgressOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$progress%',
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: AiToolsTheme.purple,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Analyzing stems...',
                  style: TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadedAudioCard extends StatelessWidget {
  final String fileName;
  final String duration;
  final VoidCallback onClose;

  const _UploadedAudioCard({
    required this.fileName,
    required this.duration,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AiToolsTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: AiToolsTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AiToolsTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Expanded(
                child: AiToolsWaveform(
                  heights: kAiToolsWaveformHeights,
                  height: 52,
                ),
              ),
              SizedBox(width: 10),
              _PlayCircleButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadAudioPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadAudioPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AiToolsTheme.radiusMd),
        child: AiToolsGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: const Column(
            children: [
              Icon(
                Icons.upload_file_rounded,
                color: AiToolsTheme.textSecondary,
                size: 28,
              ),
              SizedBox(height: 10),
              Text(
                'Tap to upload your audio',
                style: TextStyle(
                  color: AiToolsTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayCircleButton extends StatelessWidget {
  const _PlayCircleButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.black,
        size: 22,
      ),
    );
  }
}

class _StemSelectionRow extends StatelessWidget {
  final _StemOption option;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _StemSelectionRow({
    required this.option,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AiToolsTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AiToolsTheme.border),
      ),
      child: Row(
        children: [
          Icon(option.icon, color: AiToolsTheme.textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  style: const TextStyle(
                    color: AiToolsTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AiToolsTheme.purple,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AiToolsTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AiToolsDropdown(
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _OutputStemRow extends StatelessWidget {
  final _StemOption option;
  final String duration;

  const _OutputStemRow({
    required this.option,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AiToolsTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AiToolsTheme.border),
      ),
      child: Row(
        children: [
          Icon(option.icon, color: AiToolsTheme.textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.outputFileName,
                  style: const TextStyle(
                    color: AiToolsTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: AiToolsTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const _PlayCircleButton(),
          IconButton(
            onPressed: () {
              AppToast.show('Download ${option.outputFileName} coming soon.');
            },
            icon: const Icon(
              Icons.download_rounded,
              color: AiToolsTheme.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
