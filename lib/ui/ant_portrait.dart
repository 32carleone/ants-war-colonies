import 'package:flutter/material.dart';

import '../data/units.dart';
import '../game/ant_painter.dart';

/// Küçük karınca portresi (oyundaki gerçek ressamla) — panel ve wiki ortak.
class AntPortrait extends StatelessWidget {
  const AntPortrait({
    super.key,
    required this.type,
    this.size = 34,
    this.background = const Color(0xFF57472E),
  });

  final UnitType type;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter(type, background),
      size: Size.square(size),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.type, this.background);

  final UnitType type;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = background,
    );
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-1.5708);
    canvas.scale(size.width / 34 * 1.05 * unitSpecs[type]!.scale);
    paintAnt(canvas, type,
        walkPhase: 0.9, idleTime: 0.4, teamColor: const Color(0x00000000));
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.type != type || old.background != background;
}
