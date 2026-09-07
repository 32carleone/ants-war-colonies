import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../data/units.dart';

/// Tür bazlı gövde renkleri (gerçek türlerin görünümünden).
class _AntColors {
  const _AntColors(this.head, this.thorax, this.abdomen);
  final Color head;
  final Color thorax;
  final Color abdomen;
}

const Map<UnitType, _AntColors> _colors = {
  // Solenopsis: kızıl-kahve gövde, koyu abdomen.
  UnitType.fire:
      _AntColors(Color(0xFFB05A2E), Color(0xFFA9532B), Color(0xFF6E3018)),
  // Formica rufa: koyu kafa, pas kızılı toraks, koyu abdomen.
  UnitType.wood:
      _AntColors(Color(0xFF4A2C16), Color(0xFFA85C28), Color(0xFF3E2712)),
  // Odontomachus: ince, koyu kahve.
  UnitType.trapjaw:
      _AntColors(Color(0xFF54381E), Color(0xFF5E4022), Color(0xFF48301A)),
  // Atta askeri: kızıl-kahve, iri kafa.
  UnitType.leafcutter:
      _AntColors(Color(0xFFA85427), Color(0xFF9C4F24), Color(0xFF7E3E1D)),
};

/// Üstten görünüm karınca çizer. Merkez orijindedir, +x yönüne bakar,
/// gövde uzunluğu ~20 birimdir; çağıran taraf canvas'ı ölçekler/döndürür.
///
/// [walkPhase] bacak döngüsünün fazı (yürüdükçe artar),
/// [idleTime] anten salınımı için zaman,
/// [teamColor] abdomen üstüne ince takım işareti.
void paintAnt(
  Canvas canvas,
  UnitType type, {
  required double walkPhase,
  required double idleTime,
  required Color teamColor,
}) {
  final c = _colors[type]!;
  final legPaint = Paint()
    ..color = const Color(0xFF241708)
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;

  // --- Bacaklar (6 adet, dönüşümlü üçlü adım — tripod yürüyüşü) ---
  // Ön / orta / arka bacakların gövdeye bağlanma x'i ve uzanma yönü.
  const attachX = [3.0, 0.5, -2.0];
  const reachX = [5.5, 0.5, -5.0]; // ön ileri, orta yana, arka geriye
  for (final side in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      // Tripod: (ön+arka bir yanda, orta diğer yanda) aynı fazda sallanır.
      final tripodOffset = ((i + (side > 0 ? 1 : 0)) % 2) * math.pi;
      final swing = math.sin(walkPhase + tripodOffset) * 2.6;
      final attach = Offset(attachX[i], side * 1.8);
      final tip = Offset(attachX[i] + reachX[i] + swing, side * 8.0);
      final elbow = Offset(
        attach.dx + (tip.dx - attach.dx) * 0.35,
        side * 5.2,
      );
      canvas.drawLine(attach, elbow, legPaint);
      canvas.drawLine(elbow, tip, legPaint);
    }
  }

  // --- Gövde: abdomen (arka), petiol, toraks, kafa ---
  final abdomenPaint = Paint()..color = c.abdomen;
  final thoraxPaint = Paint()..color = c.thorax;
  final headPaint = Paint()..color = c.head;

  // Abdomen — Mermi/Kesici için daha iri.
  final abdomenW = type == UnitType.trapjaw ? 8.5 : 10.0;
  final abdomenH = type == UnitType.trapjaw ? 5.5 : 7.0;
  canvas.drawOval(
    Rect.fromCenter(
        center: const Offset(-6.5, 0), width: abdomenW, height: abdomenH),
    abdomenPaint,
  );
  // Abdomen parlaması.
  canvas.drawOval(
    Rect.fromCenter(
        center: const Offset(-7, -1.2), width: abdomenW * 0.55, height: 2.2),
    Paint()..color = Color.lerp(c.abdomen, const Color(0xFFFFFFFF), 0.18)!,
  );
  // Petiol (ince bel).
  canvas.drawCircle(const Offset(-1.5, 0), 1.4, thoraxPaint);
  // Toraks.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(1.5, 0), width: 6, height: 4.2),
    thoraxPaint,
  );

  // Kafa — Kesici askerde belirgin şekilde iri.
  final headR = type == UnitType.leafcutter ? 3.8 : 2.7;
  canvas.drawCircle(Offset(6.5, 0), headR, headPaint);

  // --- Çeneler (mandibula) ---
  final jawPaint = Paint()
    ..color = const Color(0xFF241708)
    ..strokeWidth = type == UnitType.leafcutter ? 1.8 : 1.0
    ..strokeCap = StrokeCap.round;
  final headFront = 6.5 + headR;
  if (type == UnitType.trapjaw) {
    // Odontomachus: 180° açık, uzun düz kapan çeneler.
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(headFront - 1, s * 1.2),
        Offset(headFront + 5.5, s * 4.5),
        jawPaint,
      );
    }
  } else {
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(headFront - 1, s * 1.0),
        Offset(headFront + 2.4, s * 2.2),
        jawPaint,
      );
    }
  }

  // --- Antenler (boşta hafif salınır) ---
  final antennaPaint = Paint()
    ..color = const Color(0xFF241708)
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;
  for (final s in const [-1.0, 1.0]) {
    final sway = math.sin(idleTime * 3 + s * 1.7) * 0.8;
    final base = Offset(6.5 + headR * 0.6, s * headR * 0.55);
    final mid = Offset(base.dx + 3.2, s * (3.2 + sway * 0.4));
    final tipOff = Offset(mid.dx + 2.8 + sway * 0.5, s * (4.6 + sway));
    canvas.drawLine(base, mid, antennaPaint);
    canvas.drawLine(mid, tipOff, antennaPaint);
  }

  // --- Takım işareti: toraks üstünde ince renk noktası ---
  canvas.drawCircle(const Offset(1.5, 0), 0.9, Paint()..color = teamColor);
}
