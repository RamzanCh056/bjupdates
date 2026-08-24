import 'package:flutter/material.dart';

/// Full-height tabbed sheet: **Clip** · **Audio** · **Color** · **Effects**.
/// Pass pre-built tab bodies from the parent screen (they call parent [setState]).
Future<void> showReelStudioBottomSheet(
  BuildContext context, {
  required int initialTab,
  required Widget clipTab,
  required Widget audioTab,
  required Widget colorTab,
  required Widget effectsTab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121212),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height * 0.92;
      return SafeArea(
        child: SizedBox(
          height: h,
          child: DefaultTabController(
            length: 4,
            initialIndex: initialTab.clamp(0, 3),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Studio',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFF0095F6),
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFF0095F6),
                  tabs: const [
                    Tab(text: 'Clip'),
                    Tab(text: 'Audio'),
                    Tab(text: 'Color'),
                    Tab(text: 'Effects'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      clipTab,
                      audioTab,
                      colorTab,
                      effectsTab,
                    ],
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
