import 'package:beatjerky/screens/ai_tools/ai_library_screen.dart';
import 'package:beatjerky/screens/studio/co_producer_flow_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_lyrics_writer_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_mood_radio_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_music_coach_screen.dart';
import 'package:beatjerky/screens/ai_tools/ai_vocal_enhancer_screen.dart';
import 'package:beatjerky/screens/ai_tools/script_to_music_screen.dart';
import 'package:beatjerky/screens/ai_tools/stem_splitter_screen.dart';
import 'package:beatjerky/screens/ai_tools/viral_score_predictor_screen.dart';
import 'package:beatjerky/screens/bjai_screen.dart';
import 'package:beatjerky/widgets/ai_tools_section.dart';
import 'package:flutter/material.dart';

class AiToolNavigation {
  AiToolNavigation._();

  static void openTool(BuildContext context, AiToolItem tool) {
    switch (tool.title) {
      case 'AI Beat Generator':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoProducerFlowScreen()),
        );
        return;
      case 'AI Vocal Enhancer':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiVocalEnhancerScreen()),
        );
        return;
      case 'AI Lyrics Writer':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiLyricsWriterScreen()),
        );
        return;
      case 'AI Music Coach':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiMusicCoachScreen()),
        );
        return;
      case 'Viral Score Predictor':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ViralScorePredictorScreen(),
          ),
        );
        return;
      case 'AI Mood Radio':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiMoodRadioScreen()),
        );
        return;
      case 'Stem Splitter':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StemSplitterScreen()),
        );
        return;
      case 'Script to Music':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScriptToMusicScreen()),
        );
        return;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BJAI(initialPrompt: tool.prompt),
          ),
        );
    }
  }

  static void openLibrary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiLibraryScreen()),
    );
  }

  static void openAllTools(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewAllAiToolsScreen(
          onToolTap: (tool) => openTool(context, tool),
          onLibraryTap: () => openLibrary(context),
        ),
      ),
    );
  }
}
