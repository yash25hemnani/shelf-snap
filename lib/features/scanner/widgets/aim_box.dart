import 'package:flutter/material.dart';

/// Dims the preview outside [window] and outlines it, so the user knows
/// where to hold the barcode.
class AimBox extends StatelessWidget {
  final Rect window;

  const AimBox({super.key, required this.window});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _AimBoxPainter(window))),
        Positioned(
          left: 0,
          right: 0,
          top: window.bottom + 16,
          child: const Text(
            'Point at the barcode on the back cover',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _AimBoxPainter extends CustomPainter {
  final Rect window;

  _AimBoxPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(12));

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black54);

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_AimBoxPainter old) => old.window != window;
}
