/// Instagram Reels–style algorithm tips and step labels for a user-friendly create flow.
/// Single source for "what works" tips and clear step indicators (Step 1 of 3, etc.).
class ReelTips {
  ReelTips._();

  // ─── Step labels (show in UI so user knows where they are) ───
  static const String step1Title = 'Choose your video';
  static const String step1Subtitle = 'Record or pick from gallery';
  static const String step2Title = 'Edit your reel';
  static const String step2Subtitle = 'Trim, music, filters & more';
  static const String step3Title = 'Preview & post';
  static const String step3Subtitle = 'Add caption and share';

  static const int totalSteps = 3;

  /// Short tip for the "   in" sheet (Step 1).
  static const String step1Tip =
      'Reels work best in vertical 9:16. Keep clips between 3–60 seconds.';

  /// Per-tool tips in the editor (Step 2). Index matches: Trim=0, Speed=1, Music=2, Filter=3, Text=4, Stickers=5.
  static const List<String> editorToolTips = [
    'Trim to 3–60 sec — shorter hooks (7–15 sec) often get more replays.',
    'Speed up for energy or slow down for drama. 1x is default.',
    'Trending music can boost reach. Sync beat to your cuts.',
    'A consistent look (e.g. one filter) helps your brand.',
    'Text in the first 3 seconds can hook viewers who watch without sound.',
    'Stickers add personality. Don’t overcrowd the frame.',
  ];

  /// Tip for preview/post screen (Step 3).
  static const String step3Tip =
      'A clear caption and cover image help people decide to watch.';

  /// Algorithm-style tips for the dismissible "Tips for better reach" card (Step 1 sheet).
  static const List<Map<String, String>> algorithmTips = [
    {
      'icon': '🎯',
      'title': 'Hook in 3 seconds',
      'text':
          'Grab attention in the first few seconds so people keep watching.',
    },
    {
      'icon': '📐',
      'title': 'Vertical 9:16',
      'text': 'We use 9:16 (portrait). Fills the screen and feels native.',
    },
    {
      'icon': '⏱️',
      'title': '3–60 seconds',
      'text': 'Short reels (7–15 sec) often get more replays. Max 60 sec.',
    },
    {
      'icon': '🎵',
      'title': 'Music & captions',
      'text': 'Add music in the editor. Use text so it works without sound.',
    },
    {
      'icon': '🖼️',
      'title': 'Strong cover',
      'text': 'Pick a clear cover frame so your reel stands out in the feed.',
    },
  ];
}
