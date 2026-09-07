import 'dart:math' as math;

import 'package:flutter/material.dart';

/// İki çapraz kılıç ikonu (Material'da yok — kendi çizimimiz).
/// SAVAŞ butonlarında kullanılır.
class CrossedSwordsIcon extends StatelessWidget {
  const CrossedSwordsIcon({super.key, this.size = 24, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SwordsPainter(color),
    );
  }
}

class _SwordsPainter extends CustomPainter {
  _SwordsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    for (final flip in const [false, true]) {
      canvas.save();
      if (flip) {
        canvas.translate(s, 0);
        canvas.scale(-1, 1);
      }
      _sword(canvas, s);
      canvas.restore();
    }
  }

  /// Sol-alttan sağ-üste uzanan tek kılıç: namlu + sivri uç + siper + kabza.
  void _sword(Canvas canvas, double s) {
    final blade = Paint()
      ..color = color
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = color
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;

    final hiltEnd = Offset(s * 0.16, s * 0.86);
    final guardAt = Offset(s * 0.30, s * 0.72);
    final tip = Offset(s * 0.84, s * 0.14);

    // Namlu (siperden uca).
    canvas.drawLine(guardAt, tip, blade);
    // Sivri uç.
    final dir = (tip - guardAt);
    final len = dir.distance;
    final u = Offset(dir.dx / len, dir.dy / len);
    final n = Offset(-u.dy, u.dx);
    final tipPath = Path()
      ..moveTo(tip.dx + u.dx * s * 0.07, tip.dy + u.dy * s * 0.07)
      ..lineTo(tip.dx - u.dx * s * 0.08 + n.dx * s * 0.07,
          tip.dy - u.dy * s * 0.08 + n.dy * s * 0.07)
      ..lineTo(tip.dx - u.dx * s * 0.08 - n.dx * s * 0.07,
          tip.dy - u.dy * s * 0.08 - n.dy * s * 0.07)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = color);
    // Siper (namluya dik kısa çizgi).
    canvas.drawLine(
      guardAt + n * (s * 0.14) - u * (s * 0.02),
      guardAt - n * (s * 0.14) - u * (s * 0.02),
      thin,
    );
    // Kabza + topuz.
    canvas.drawLine(guardAt, hiltEnd, thin);
    canvas.drawCircle(hiltEnd, s * 0.06, Paint()..color = color);
    // Namluda ince parlama çizgisi.
    canvas.drawLine(
      guardAt + u * (s * 0.10) + n * (s * 0.02),
      tip - u * (s * 0.16) + n * (s * 0.02),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = math.max(1, s * 0.03)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SwordsPainter old) => old.color != color;
}
