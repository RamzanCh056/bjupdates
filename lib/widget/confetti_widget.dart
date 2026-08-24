import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiWidget extends StatefulWidget {
  final bool isActive;
  final Duration duration;

  const ConfettiWidget({
    Key? key,
    required this.isActive,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  _ConfettiWidgetState createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with TickerProviderStateMixin {
  late List<ConfettiPiece> _pieces;
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _pieces = List.generate(50, (index) => _createPiece());
    
    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    }
  }

  ConfettiPiece _createPiece() {
    return ConfettiPiece(
      color: _getRandomColor(),
      size: _random.nextDouble() * 8 + 4,
      startX: _random.nextDouble(),
      startY: -0.2,
      endX: _random.nextDouble() * 2 - 1,
      endY: 1.2,
      rotation: _random.nextDouble() * 360,
      rotationSpeed: _random.nextDouble() * 720 - 360,
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _pieces.map((piece) {
            final progress = _controller.value;
            final currentX = piece.startX + (piece.endX - piece.startX) * progress;
            final currentY = piece.startY + (piece.endY - piece.startY) * progress;
            final currentRotation = piece.rotation + piece.rotationSpeed * progress;

            return Positioned(
              left: currentX * MediaQuery.of(context).size.width,
              top: currentY * MediaQuery.of(context).size.height,
              child: Transform.rotate(
                angle: currentRotation * pi / 180,
                child: Opacity(
                  opacity: progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) * 5),
                  child: Container(
                    width: piece.size,
                    height: piece.size,
                    decoration: BoxDecoration(
                      color: piece.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ConfettiPiece {
  final Color color;
  final double size;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double rotation;
  final double rotationSpeed;

  ConfettiPiece({
    required this.color,
    required this.size,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.rotation,
    required this.rotationSpeed,
  });
}
