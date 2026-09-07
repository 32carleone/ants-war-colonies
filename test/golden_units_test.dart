import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ant_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 6 karınca tipinin çizim ön izlemesi: `--update-goldens` ile
/// test/goldens/units.png üretir; normalde görsel gerileme testi.
class _AntShowcasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF57472E));
    final types = UnitType.values;
    final slot = size.width / types.length;
    for (var i = 0; i < types.length; i++) {
      final spec = unitSpecs[types[i]]!;
      canvas.save();
      canvas.translate(slot * (i + 0.5), size.height / 2);
      canvas.scale(6.0 * spec.scale);
      canvas.rotate(-1.5708); // yukarı baksınlar
      paintAnt(
        canvas,
        types[i],
        walkPhase: 0.9,
        idleTime: 0.4,
        teamColor: const Color(0xFF9163BC),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('karınca çizimleri ön izleme', (tester) async {
    tester.view.physicalSize = const Size(1280, 260);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          painter: _AntShowcasePainter(),
          size: const Size(1280, 260),
        ),
      ),
    );

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/units.png'),
    );
  });
}
