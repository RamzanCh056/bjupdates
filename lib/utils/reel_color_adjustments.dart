import 'package:flutter/material.dart';

/// Preview-only color matrices for reel editor (chain order: brightness → contrast →
/// saturation → warmth → shadows/highlights → micro-sharpen).
class ReelColorAdjustments {
  ReelColorAdjustments._();

  /// v in [-1, 1]
  static List<double> brightness(double v) {
    final o = v.clamp(-1.0, 1.0) * 90;
    return [
      1, 0, 0, 0, o,
      0, 1, 0, 0, o,
      0, 0, 1, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  /// v in [-1, 1] → contrast factor ~[0.35, 1.85]
  static List<double> contrast(double v) {
    final c = (1.0 + v.clamp(-1.0, 1.0) * 0.85).clamp(0.2, 2.2);
    final t = 128.0 * (1.0 - c);
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  /// v in [-1, 1] → saturation 0 (gray) … 2
  static List<double> saturation(double v) {
    final s = (1.0 + v.clamp(-1.0, 1.0)).clamp(0.0, 2.0);
    const r = 0.213, g = 0.715, b = 0.072;
    final inv = 1.0 - s;
    return [
      inv * r + s, inv * g, inv * b, 0, 0,
      inv * r, inv * g + s, inv * b, 0, 0,
      inv * r, inv * g, inv * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// v in [-1, 1] warm (+) / cool (-)
  static List<double> warmth(double v) {
    final w = v.clamp(-1.0, 1.0) * 0.22;
    return [
      1 + w, 0, 0, 0, 8 * w,
      0, 1, 0, 0, 0,
      0, 0, 1 - w, 0, -8 * w,
      0, 0, 0, 1, 0,
    ];
  }

  /// Simple lift: shadows brighten, highlights darken (approximation).
  static List<double> shadowsHighlights(double shadows, double highlights) {
    final sh = shadows.clamp(-1.0, 1.0) * 45;
    final hi = highlights.clamp(-1.0, 1.0) * -35;
    final o = sh + hi;
    return [
      1, 0, 0, 0, o * 0.6,
      0, 1, 0, 0, o * 0.6,
      0, 0, 1, 0, o * 0.6,
      0, 0, 0, 1, 0,
    ];
  }

  /// Fake sharpen: slight extra contrast.
  static List<double> sharpen(double v) {
    return contrast(v.clamp(0.0, 1.0) * 0.35);
  }

  static Widget wrapChain(
    Widget video, {
    double brightnessVal = 0,
    double contrastV = 0,
    double saturationV = 0,
    double warmthV = 0,
    double shadows = 0,
    double highlights = 0,
    double sharpenV = 0,
  }) {
    Widget w = video;
    if (brightnessVal.abs() > 0.002) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(brightness(brightnessVal)), child: w);
    }
    if (contrastV.abs() > 0.002) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(contrast(contrastV)), child: w);
    }
    if (saturationV.abs() > 0.002) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(saturation(saturationV)), child: w);
    }
    if (warmthV.abs() > 0.002) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(warmth(warmthV)), child: w);
    }
    if (shadows.abs() > 0.002 || highlights.abs() > 0.002) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(shadowsHighlights(shadows, highlights)), child: w);
    }
    if (sharpenV > 0.02) {
      w = ColorFiltered(colorFilter: ColorFilter.matrix(sharpen(sharpenV)), child: w);
    }
    return w;
  }
}

/// Darkens edges for preview (amount 0…1).
class ReelVignetteOverlay extends StatelessWidget {
  const ReelVignetteOverlay({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0.002) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _VignettePainter(amount.clamp(0.0, 1.0)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  _VignettePainter(this.amount);
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final g = RadialGradient(
      center: Alignment.center,
      radius: 1.05,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: amount * 0.92),
      ],
      stops: const [0.42, 1.0],
    );
    final paint = Paint()..shader = g.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) => old.amount != amount;
}
