import 'dart:async';
import 'dart:math' as math;

import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/services/ai_vocal_enhancer_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/debug_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

class AiVocalEnhancerScreen extends StatefulWidget {
  const AiVocalEnhancerScreen({super.key});

  @override
  State<AiVocalEnhancerScreen> createState() => _AiVocalEnhancerScreenState();
}

class _AiVocalEnhancerScreenState extends State<AiVocalEnhancerScreen> {
  UploadedVocalFile? _uploadedVocal;
  EnhancedVocalResult? _enhancedVocal;

  bool _isUploading = false;
  bool _isEnhancing = false;
  int _enhanceProgress = 0;
  Timer? _progressTimer;
  bool _isRawPlaying = false;
  bool _isEnhancedPlaying = false;
  bool _isSaving = false;

  bool _removeNoise = true;
  bool _pitchCorrection = true;
  bool _autoTune = true;
  bool _improveClarity = true;
  bool _studioQuality = true;

  VocalEnhancerSettings get _settings => VocalEnhancerSettings(
        removeNoise: _removeNoise,
        pitchCorrection: _pitchCorrection,
        autoTune: _autoTune,
        improveClarity: _improveClarity,
        studioQuality: _studioQuality,
      );

  @override
  void initState() {
    super.initState();
    AiVocalEnhancerService.rawPlayerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isRawPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isRawPlaying = false;
        }
      });
    });
    AiVocalEnhancerService.enhancedPlayerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isEnhancedPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isEnhancedPlaying = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    AiVocalEnhancerService.stopAll();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted || !_isEnhancing) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_enhanceProgress < 92) {
          _enhanceProgress = (_enhanceProgress + 1 + math.Random().nextInt(2))
              .clamp(1, 92);
        }
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _showInfoDialog() {
    AiToolsInfoDialog.show(
      context,
      title: 'AI Vocal Enhancer',
      message:
          'Upload a vocal recording and OpenAI will generate a step-by-step coaching guide for enhancing it in your DAW based on your settings.',
    );
  }

  Future<void> _pickVocalFile() async {
    if (_isUploading || _isEnhancing) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        AppToast.show('Could not read the selected file.', isError: true);
        return;
      }

      setState(() {
        _isUploading = true;
        _enhancedVocal = null;
      });
      await AiVocalEnhancerService.stopAll();

      final uploaded = await AiVocalEnhancerService.probeLocalVocal(
        fileName: file.name,
        localPath: path,
      );

      if (!mounted) return;
      setState(() {
        _uploadedVocal = uploaded;
        _isRawPlaying = false;
        _isEnhancedPlaying = false;
      });
    } catch (error, stackTrace) {
      logDebugException('AiVocalEnhancerScreen.pickVocal', error, stackTrace: stackTrace);
      AppToast.show(AiVocalEnhancerService.errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _clearUploadedVocal() async {
    await AiVocalEnhancerService.stopAll();
    setState(() {
      _uploadedVocal = null;
      _enhancedVocal = null;
      _isRawPlaying = false;
      _isEnhancedPlaying = false;
    });
  }

  Future<void> _enhanceVocal() async {
    final uploaded = _uploadedVocal;
    if (uploaded == null) {
      AppToast.show('Upload a vocal file first.', isError: true);
      return;
    }
    if (_isEnhancing) return;

    setState(() {
      _isEnhancing = true;
      _enhanceProgress = 1;
    });
    _startProgressTimer();
    await AiVocalEnhancerService.stopEnhanced();

    try {
      final enhanced = await AiVocalEnhancerService.enhanceVocal(
        uploaded: uploaded,
        settings: _settings,
      );
      _stopProgressTimer();
      if (!mounted) return;

      setState(() => _enhanceProgress = 100);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      setState(() {
        _enhancedVocal = enhanced;
        _isEnhancedPlaying = false;
        _isEnhancing = false;
        _enhanceProgress = 0;
      });
      AppToast.show('Vocal coaching guide ready.');
    } catch (error, stackTrace) {
      _stopProgressTimer();
      logDebugException('AiVocalEnhancerScreen.enhanceVocal', error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isEnhancing = false;
          _enhanceProgress = 0;
        });
        AppToast.show(AiVocalEnhancerService.errorMessage(error), isError: true);
      }
    }
  }

  Future<void> _toggleRawPlayback() async {
    final uploaded = _uploadedVocal;
    if (uploaded == null) return;

    try {
      if (_isRawPlaying) {
        await AiVocalEnhancerService.pauseRaw();
        return;
      }
      await AiVocalEnhancerService.playRaw(uploaded.localPath);
    } catch (error, stackTrace) {
      logDebugException('AiVocalEnhancerScreen.rawPlayback', error, stackTrace: stackTrace);
      AppToast.show('Could not play the uploaded vocal.', isError: true);
    }
  }

  Future<void> _toggleEnhancedPlayback() async {
    final enhanced = _enhancedVocal;
    if (enhanced == null) return;

    if (enhanced.isGuideOnly) {
      _showCoachingGuide(enhanced.coachingGuide ?? '');
      return;
    }

    try {
      if (_isEnhancedPlaying) {
        await AiVocalEnhancerService.pauseEnhanced();
        return;
      }
      if (AiVocalEnhancerService.hasEnhancedLoaded) {
        await AiVocalEnhancerService.resumeEnhanced();
        return;
      }
      await AiVocalEnhancerService.playEnhanced(
        enhanced.audioBytes,
        durationSeconds: enhanced.durationSeconds,
      );
    } catch (error, stackTrace) {
      logDebugException(
        'AiVocalEnhancerScreen.enhancedPlayback',
        error,
        stackTrace: stackTrace,
      );
      AppToast.show('Could not play the enhanced vocal.', isError: true);
    }
  }

  void _showCoachingGuide(String guide) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AiToolsTheme.cardElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Vocal Coaching Guide',
                    style: TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    guide,
                    style: const TextStyle(
                      color: AiToolsTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareEnhanced() async {
    final enhanced = _enhancedVocal;
    if (enhanced == null) return;

    try {
      if (enhanced.isGuideOnly) {
        await SharePlus.instance.share(
          ShareParams(
            text: enhanced.coachingGuide ?? '',
            subject: enhanced.fileName,
          ),
        );
        return;
      }

      final file = await AiVocalEnhancerService.writeShareableFile(
        enhanced.audioBytes,
        fileName: enhanced.fileName,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: enhanced.fileName,
        ),
      );
    } catch (error, stackTrace) {
      logDebugException('AiVocalEnhancerScreen.share', error, stackTrace: stackTrace);
      AppToast.show('Could not share this file.', isError: true);
    }
  }

  Future<void> _saveToLibrary() async {
    final enhanced = _enhancedVocal;
    if (enhanced == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await AiLibraryService.save(
        AiLibrarySaveRequest(
          type: 'vocal',
          title: enhanced.fileName,
          sourceTool: 'AI Vocal Enhancer',
          textContent: enhanced.coachingGuide,
          audioBytes: enhanced.audioBytes.isEmpty ? null : enhanced.audioBytes,
          audioFileName: enhanced.fileName,
          metadata: {
            'durationSeconds': enhanced.durationSeconds,
            'removeNoise': _removeNoise,
            'pitchCorrection': _pitchCorrection,
            'autoTune': _autoTune,
            'improveClarity': _improveClarity,
            'studioQuality': _studioQuality,
          },
        ),
      );
      AppToast.show('Saved to library.');
    } catch (error) {
      AppToast.show(AiLibraryService.errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _deleteEnhanced() async {
    await AiVocalEnhancerService.stopEnhanced();
    setState(() {
      _enhancedVocal = null;
      _isEnhancedPlaying = false;
    });
    AppToast.show('Enhanced vocal removed.');
  }

  bool get _isBusy => _isUploading || _isEnhancing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiToolsScreen(
          title: 'AI Vocal Enhancer',
          onInfo: _showInfoDialog,
          children: [
            const AiToolsSectionTitle(text: 'Upload your vocal'),
            const SizedBox(height: 10),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AiToolsTheme.purple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_uploadedVocal != null)
              _UploadedVocalCard(
                fileName: _uploadedVocal!.fileName,
                duration: _uploadedVocal!.durationLabel,
                isPlaying: _isRawPlaying,
                onClose: _isBusy ? null : _clearUploadedVocal,
                onPlayTap: _toggleRawPlayback,
              )
            else
              _UploadPlaceholderCard(
                onTap: _isBusy ? () {} : _pickVocalFile,
              ),
            const SizedBox(height: 22),
            _EnhancementSettingsCard(
              removeNoise: _removeNoise,
              pitchCorrection: _pitchCorrection,
              autoTune: _autoTune,
              improveClarity: _improveClarity,
              studioQuality: _studioQuality,
              enabled: !_isBusy,
              onRemoveNoiseChanged: (value) =>
                  setState(() => _removeNoise = value),
              onPitchCorrectionChanged: (value) =>
                  setState(() => _pitchCorrection = value),
              onAutoTuneChanged: (value) => setState(() => _autoTune = value),
              onImproveClarityChanged: (value) =>
                  setState(() => _improveClarity = value),
              onStudioQualityChanged: (value) =>
                  setState(() => _studioQuality = value),
            ),
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: _isBusy,
              child: Opacity(
                opacity: _isBusy ? 0.7 : 1,
                child: AiToolsPrimaryButton(
                  label: _isEnhancing ? 'Creating Coaching Guide...' : 'Enhance Vocal',
                  icon: Icons.graphic_eq_rounded,
                  onPressed: _enhanceVocal,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const AiToolsSectionTitle(text: 'Coaching Guide'),
            const SizedBox(height: 10),
            if (_enhancedVocal != null)
              _EnhancedVocalCard(
                fileName: _enhancedVocal!.fileName,
                duration: _enhancedVocal!.durationLabel,
                coachingGuide: _enhancedVocal!.coachingGuide,
                isGuideOnly: _enhancedVocal!.isGuideOnly,
                isPlaying: _isEnhancedPlaying,
                onPlayTap: _toggleEnhancedPlayback,
                onShare: _shareEnhanced,
                onSave: _saveToLibrary,
                onDelete: _deleteEnhanced,
              )
            else
              const AiToolsEmptyState(
                message:
                    'Your vocal coaching guide will appear here after processing.',
              ),
          ],
        ),
        if (_isEnhancing)
          AiToolsGeneratingOverlay(
            progress: _enhanceProgress,
            title: 'Creating your vocal coaching guide...',
            subtitle: 'Powered by OpenAI',
          ),
      ],
    );
  }
}

class _AudioIconBadge extends StatelessWidget {
  const _AudioIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AiToolsTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _PlayCircleButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _PlayCircleButton({
    required this.isPlaying,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.08 : 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _UploadedVocalCard extends StatelessWidget {
  final String fileName;
  final String duration;
  final bool isPlaying;
  final VoidCallback? onClose;
  final VoidCallback onPlayTap;

  const _UploadedVocalCard({
    required this.fileName,
    required this.duration,
    required this.isPlaying,
    required this.onClose,
    required this.onPlayTap,
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
              const _AudioIconBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              if (onClose != null)
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
            children: [
              const Expanded(
                child: AiToolsWaveform(
                  heights: kAiToolsWaveformHeights,
                  height: 52,
                ),
              ),
              const SizedBox(width: 10),
              _PlayCircleButton(
                isPlaying: isPlaying,
                onTap: onPlayTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadPlaceholderCard extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadPlaceholderCard({required this.onTap});

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
                'Tap to upload your vocal',
                style: TextStyle(
                  color: AiToolsTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'MP3, WAV, M4A, AAC (max ~12 MB)',
                style: TextStyle(
                  color: AiToolsTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancementSettingsCard extends StatelessWidget {
  final bool removeNoise;
  final bool pitchCorrection;
  final bool autoTune;
  final bool improveClarity;
  final bool studioQuality;
  final bool enabled;
  final ValueChanged<bool> onRemoveNoiseChanged;
  final ValueChanged<bool> onPitchCorrectionChanged;
  final ValueChanged<bool> onAutoTuneChanged;
  final ValueChanged<bool> onImproveClarityChanged;
  final ValueChanged<bool> onStudioQualityChanged;

  const _EnhancementSettingsCard({
    required this.removeNoise,
    required this.pitchCorrection,
    required this.autoTune,
    required this.improveClarity,
    required this.studioQuality,
    required this.enabled,
    required this.onRemoveNoiseChanged,
    required this.onPitchCorrectionChanged,
    required this.onAutoTuneChanged,
    required this.onImproveClarityChanged,
    required this.onStudioQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enhancement Settings',
            style: TextStyle(
              color: AiToolsTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _EnhancementToggleRow(
            label: 'Remove Noise',
            value: removeNoise,
            onChanged: enabled ? onRemoveNoiseChanged : null,
          ),
          _EnhancementToggleRow(
            label: 'Pitch Correction',
            value: pitchCorrection,
            onChanged: enabled ? onPitchCorrectionChanged : null,
          ),
          _EnhancementToggleRow(
            label: 'Auto Tune',
            value: autoTune,
            onChanged: enabled ? onAutoTuneChanged : null,
          ),
          _EnhancementToggleRow(
            label: 'Improve Clarity',
            value: improveClarity,
            onChanged: enabled ? onImproveClarityChanged : null,
          ),
          _EnhancementToggleRow(
            label: 'Studio Quality',
            value: studioQuality,
            showProBadge: true,
            onChanged: enabled ? onStudioQualityChanged : null,
          ),
        ],
      ),
    );
  }
}

class _EnhancementToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool showProBadge;
  final ValueChanged<bool>? onChanged;

  const _EnhancementToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showProBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (showProBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AiToolsTheme.purple.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AiToolsTheme.purple.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        color: AiToolsTheme.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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

class _EnhancedVocalCard extends StatelessWidget {
  final String fileName;
  final String duration;
  final String? coachingGuide;
  final bool isGuideOnly;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _EnhancedVocalCard({
    required this.fileName,
    required this.duration,
    required this.coachingGuide,
    required this.isGuideOnly,
    required this.isPlaying,
    required this.onPlayTap,
    required this.onShare,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AiToolsGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AudioIconBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuideOnly ? 'OpenAI coaching guide' : duration,
                      style: const TextStyle(
                        color: AiToolsTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _PlayCircleButton(
                isPlaying: isPlaying,
                onTap: onPlayTap,
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AiToolsTheme.textSecondary,
                ),
                color: AiToolsTheme.cardElevated,
                onSelected: (value) {
                  if (value == 'Share') {
                    onShare();
                  } else if (value == 'Save') {
                    onSave();
                  } else if (value == 'Delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Share', child: Text('Share')),
                  PopupMenuItem(value: 'Save', child: Text('Save to Library')),
                  PopupMenuItem(value: 'Delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (isGuideOnly && coachingGuide != null && coachingGuide!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              coachingGuide!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AiToolsTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onPlayTap,
              child: const Text('View full guide'),
            ),
          ],
        ],
      ),
    );
  }
}
