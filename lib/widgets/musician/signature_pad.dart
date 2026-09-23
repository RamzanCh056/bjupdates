import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A lightweight signature pad built on [CustomPainter] — no extra dependency.
///
/// Collects strokes and can export a transparent PNG via [SignaturePadController].
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Size _size = Size.zero;

  List<List<Offset>> get strokes => _strokes;
  bool get isEmpty => _strokes.every((s) => s.isEmpty);

  void _setSize(Size size) => _size = size;

  void startStroke(Offset p) {
    _strokes.add(<Offset>[p]);
    notifyListeners();
  }

  void appendPoint(Offset p) {
    if (_strokes.isEmpty) _strokes.add(<Offset>[]);
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Renders the current strokes to a transparent PNG. Returns null if empty.
  Future<Uint8List?> exportPng({double strokeWidth = 3.0}) async {
    if (isEmpty || _size == Size.zero) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
      } else {
        for (var i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(_size.width.ceil(), _size.height.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

class SignaturePad extends StatelessWidget {
  final SignaturePadController controller;
  final double height;
  final Color inkColor;

  const SignaturePad({
    super.key,
    required this.controller,
    this.height = 180,
    this.inkColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        controller._setSize(size);
        return SizedBox(
          width: size.width,
          height: height,
          child: GestureDetector(
            onPanStart: (d) => controller.startStroke(d.localPosition),
            onPanUpdate: (d) => controller.appendPoint(d.localPosition),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => CustomPaint(
                painter: _SignaturePainter(controller.strokes, inkColor),
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color inkColor;

  _SignaturePainter(this.strokes, this.inkColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = inkColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
      } else {
        for (var i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
