import 'package:flutter/material.dart';

/// Dims the preview outside [window] and outlines it, so the user knows
/// where to hold the barcode. [borderColor] lets the outline flash on a scan.
class AimBox extends StatelessWidget {
  final Rect window;
  final Color borderColor;

  const AimBox({
    super.key,
    required this.window,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: borderColor),
        duration: const Duration(milliseconds: 150),
        builder: (context, color, _) => CustomPaint(
          painter: _AimBoxPainter(window, color ?? borderColor),
        ),
      ),
    );
  }
}

class _AimBoxPainter extends CustomPainter {
  final Rect window;
  final Color borderColor;

  _AimBoxPainter(this.window, this.borderColor);

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
        ..strokeWidth = 3
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(_AimBoxPainter old) =>
      old.window != window || old.borderColor != borderColor;
}
