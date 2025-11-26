import 'package:flutter/material.dart';
import 'dart:math';

class PortalWidget extends StatelessWidget {
  final double size;
  final Animation<double> animation;
  final Color color;

  const PortalWidget({super.key, required this.size, required this.animation, this.color = Colors.purple});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2,
      height: size * 2,
      child: CustomPaint(
        painter: _PortalPainter(animation.value, color),
      ),
    );
  }
}

class _PortalPainter extends CustomPainter {
  final double t;
  final Color color;
  _PortalPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) * (0.8 + 0.15 * sin(t * 6));
    paint.color = color.withOpacity(0.25 + 0.1 * sin(t * 8));
    canvas.drawCircle(center, radius * 1.2, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = color.withOpacity(0.9);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PortalPainter old) => t != old.t || color != old.color;
}
