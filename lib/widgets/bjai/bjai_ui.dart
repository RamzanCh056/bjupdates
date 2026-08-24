import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';

const bjaiBg = Color(0xFF0D1117);
const bjaiSurface = Color(0xFF161B22);
const bjaiSurfaceLight = Color(0xFF1C2333);
const bjaiPurple = Color(0xFFA855F7);
const bjaiPurpleDeep = Color(0xFF7C3AED);

const bjaiGradient = LinearGradient(
  colors: [bjaiPurple, bjaiPurpleDeep],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Renders basic **bold** markdown from AI responses.
Widget bjaiFormattedText(
  String text, {
  Color color = Colors.white,
  double fontSize = 14.5,
}) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    );
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }

  return SelectableText.rich(
    TextSpan(
      children: spans,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        height: 1.55,
        letterSpacing: 0.1,
      ),
    ),
  );
}

Widget bjaiProviderChip() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bjaiPurple.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: bjaiPurple.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 11, color: purpleAccent.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Text(
          'OpenAI',
          style: TextStyle(
            color: purpleAccent.withValues(alpha: 0.95),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}
