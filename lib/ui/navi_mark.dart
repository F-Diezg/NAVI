import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Marca de NAVI dibujada en código (una chispa de cuatro puntas),
/// la misma que el icono de la app.
class NaviMark extends StatelessWidget {
  const NaviMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * 0.24));
    canvas.drawRRect(r, Paint()..color = naviNight);

    final c = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(
      c,
      size.width * 0.36,
      Paint()
        ..shader = RadialGradient(colors: [
          naviSeed.withValues(alpha: 0.45),
          naviSeed.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.36)),
    );
    _star(canvas, c, size.width * 0.30, const Color(0xFFFFD166));
    _star(canvas, Offset(size.width * 0.74, size.height * 0.27),
        size.width * 0.09, Colors.white);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final rr = i.isEven ? r : r * 0.28;
      final pt = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
