enum StudioInputMode { humSing, beatbox, describe }

class StudioTrackInput {
  final StudioInputMode mode;
  final String? description;
  final Duration recordingDuration;
  final String? audioPath;

  const StudioTrackInput({
    required this.mode,
    this.description,
    this.recordingDuration = Duration.zero,
    this.audioPath,
  });

  bool get hasDescription =>
      description != null && description!.trim().isNotEmpty;

  bool get hasAudioFile =>
      audioPath != null && audioPath!.trim().isNotEmpty;
}

class StudioTrackAnalysis {
  final String genre;
  final int bpm;
  final String key;
  final String mood;

  const StudioTrackAnalysis({
    required this.genre,
    required this.bpm,
    required this.key,
    required this.mood,
  });

  String get genreLabel => genre;
  String get bpmLabel => '$bpm BPM';
  String get keyLabel => key;
  String get moodLabel => mood;

  /// Local heuristic fallback when Gemini/OpenAI are unavailable.
  static StudioTrackAnalysis fromInput(StudioTrackInput input) {
    final text = (input.description ?? '').toLowerCase();

    var genre = 'Trap / R&B';
    var bpm = 92;
    var key = 'C Minor';
    var mood = 'Dark · Melancholic';

    if (text.contains('happy') || text.contains('upbeat')) {
      mood = 'Bright · Energetic';
      key = 'G Major';
      bpm = 118;
      genre = 'Pop / Hip Hop';
    } else if (text.contains('chill') ||
        text.contains('lofi') ||
        text.contains('lo-fi')) {
      mood = 'Chill · Dreamy';
      key = 'D Minor';
      bpm = 78;
      genre = 'Lo-Fi / R&B';
    } else if (text.contains('aggressive') || text.contains('hard')) {
      mood = 'Aggressive · Intense';
      key = 'F Minor';
      bpm = 140;
      genre = 'Drill / Trap';
    } else if (text.contains('sad') ||
        text.contains('rain') ||
        text.contains('dark')) {
      mood = 'Dark · Melancholic';
      key = 'C Minor';
      bpm = 92;
      genre = 'Trap / R&B';
    }

    if (input.mode == StudioInputMode.beatbox) {
      bpm = (bpm + 8).clamp(70, 160);
      genre = 'Hip Hop / Trap';
    } else if (input.mode == StudioInputMode.humSing &&
        input.recordingDuration.inSeconds < 4) {
      bpm = (bpm - 6).clamp(70, 160);
    }

    return StudioTrackAnalysis(
      genre: genre,
      bpm: bpm,
      key: key,
      mood: mood,
    );
  }
}
