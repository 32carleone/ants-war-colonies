import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/abilities.dart';

/// Yetenekler için ÖZEL ÇİZİMLER — Material ikonları yerine her gücün
/// kendi mini sahnesi. Kare bir alana (size×size) çizilir ama dış çerçeve
/// YOKTUR; slotlar/rozetler/wiki hep bunu kullanır.
class AbilityArt extends StatelessWidget {
  const AbilityArt({super.key, required this.type, this.size = 24});

  final AbilityType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AbilityArtPainter(type),
    );
  }
}

class _AbilityArtPainter extends CustomPainter {
  _AbilityArtPainter(this.type);

  final AbilityType type;

  @override
  void paint(Canvas canvas, Size size) =>
      paintAbilityArt(canvas, type, size.width);

  @override
  bool shouldRepaint(covariant _AbilityArtPainter old) => old.type != type;
}

/// [size]×[size] alana yetenek çizimini yapar (Flame tarafı da kullanır —
/// örn. düşman yuvasındaki mini rozetler).
void paintAbilityArt(Canvas canvas, AbilityType type, double size) {
  canvas.save();
  canvas.scale(size / 24); // tasarımlar 24×24 ızgarada
  switch (type) {
    case AbilityType.lightning:
      _lightning(canvas);
    case AbilityType.reinforce:
      _reinforce(canvas);
    case AbilityType.summonWood:
      _summonWood(canvas);
    case AbilityType.summonLeaf:
      _summonLeaf(canvas);
    case AbilityType.speedPheromone:
      _speed(canvas);
    case AbilityType.battleFrenzy:
      _frenzy(canvas);
    case AbilityType.heal:
      _heal(canvas);
    case AbilityType.rain:
      _rain(canvas);
    case AbilityType.poisonCloud:
      _poison(canvas);
    case AbilityType.fearScream:
      _fear(canvas);
    case AbilityType.armorPheromone:
      _armor(canvas);
    case AbilityType.fireRing:
      _fireRing(canvas);
    case AbilityType.freeze:
      _freeze(canvas);
  }
  canvas.restore();
}

// ------------------------------------------------------------ çizimler

void _cloud(Canvas c, Offset at, Color color, {double k = 1}) {
  final p = Paint()..color = color;
  c.drawCircle(at.translate(-4 * k, 0), 3.6 * k, p);
  c.drawCircle(at.translate(0, -2 * k), 4.4 * k, p);
  c.drawCircle(at.translate(4.5 * k, 0.5 * k), 3.2 * k, p);
  c.drawOval(
      Rect.fromCenter(
          center: at.translate(0, 1.5 * k), width: 15 * k, height: 6 * k),
      p);
}

void _lightning(Canvas c) {
  _cloud(c, const Offset(12, 6.5), const Color(0xFF6E7B8A));
  final bolt = Path()
    ..moveTo(13.5, 8)
    ..lineTo(9, 14.5)
    ..lineTo(12, 15)
    ..lineTo(9.5, 21.5)
    ..lineTo(16, 13.5)
    ..lineTo(12.8, 13)
    ..lineTo(15.8, 8)
    ..close();
  c.drawPath(bolt, Paint()..color = const Color(0xFFF6D879));
  c.drawPath(
    bolt,
    Paint()
      ..color = const Color(0xFFE8B33C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
}

void _reinforce(Canvas c) =>
    _summonAnt(c, const Color(0xFF7E4A2A), const Color(0xFFE8B33C));

/// Orman Çağrısı: kızıl-kahve orman karıncası + yeşil artı.
void _summonWood(Canvas c) =>
    _summonAnt(c, const Color(0xFF8A3B24), const Color(0xFF7CB342));

/// Kesici Çağrısı: yeşil kesici (sırtında yaprak) + krem artı.
void _summonLeaf(Canvas c) {
  _summonAnt(c, const Color(0xFF5E7C3E), const Color(0xFFF2E8D5));
  // Sırtında taşıdığı yaprak parçası.
  final leaf = Path()
    ..moveTo(6, 6.5)
    ..quadraticBezierTo(2.5, 3.5, 6.5, 1.8)
    ..quadraticBezierTo(10.5, 1.2, 10, 4.5)
    ..quadraticBezierTo(9, 7.5, 6, 6.5)
    ..close();
  c.drawPath(leaf, Paint()..color = const Color(0xFF96B565));
}

/// Karınca silüeti (üç boğum + bacaklar) + köşede artı — çağrı yetenekleri.
void _summonAnt(Canvas c, Color bodyColor, Color plusColor) {
  final body = Paint()..color = bodyColor;
  final leg = Paint()
    ..color = const Color(0xFF4A2E18)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  c.save();
  c.translate(10, 14);
  c.rotate(-0.5);
  for (final side in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final x = -3.0 + i * 3;
      c.drawLine(Offset(x, 0), Offset(x + 2 * side - 2, 4.5 * side), leg);
    }
  }
  c.drawOval(Rect.fromCenter(
      center: const Offset(-4, 0), width: 7, height: 5), body);
  c.drawOval(Rect.fromCenter(
      center: const Offset(1, 0), width: 4.5, height: 4), body);
  c.drawCircle(const Offset(5, 0), 2.4, body);
  c.drawLine(const Offset(6, -1), const Offset(8.5, -3.5), leg);
  c.drawLine(const Offset(6, 1), const Offset(8.5, 3.5), leg);
  c.restore();
  final plus = Paint()
    ..color = plusColor
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(17.5, 4.5), const Offset(17.5, 10.5), plus);
  c.drawLine(const Offset(14.5, 7.5), const Offset(20.5, 7.5), plus);
}

void _speed(Canvas c) {
  // Üç teal şerit ok: soldan sağa hız.
  for (var i = 0; i < 3; i++) {
    final x = 4.0 + i * 6;
    final a = 0.45 + i * 0.27;
    final chevron = Path()
      ..moveTo(x, 5)
      ..lineTo(x + 5.5, 12)
      ..lineTo(x, 19)
      ..lineTo(x + 2.6, 19)
      ..lineTo(x + 8.1, 12)
      ..lineTo(x + 2.6, 5)
      ..close();
    c.drawPath(
        chevron, Paint()..color = const Color(0xFF6FD6C0).withValues(alpha: a));
  }
}

void _frenzy(Canvas c) {
  // Pençe izi: üç kavisli kırmızı-turuncu yırtık.
  for (var i = 0; i < 3; i++) {
    final x = 6.0 + i * 5.2;
    final slash = Path()
      ..moveTo(x, 3.5)
      ..quadraticBezierTo(x + 3.5, 12, x - 1.5, 20.5)
      ..quadraticBezierTo(x + 1.2, 12, x - 2.2, 4.5)
      ..close();
    c.drawPath(
      slash,
      Paint()
        ..color = Color.lerp(const Color(0xFFE8683C),
            const Color(0xFFC0392B), i / 2)!,
    );
  }
}

void _heal(Canvas c) {
  // Yaprak + parlak artı.
  final leaf = Path()
    ..moveTo(10, 21)
    ..quadraticBezierTo(2.5, 13, 8, 6)
    ..quadraticBezierTo(14.5, 1.5, 17, 5.5)
    ..quadraticBezierTo(18.5, 14, 10, 21)
    ..close();
  c.drawPath(leaf, Paint()..color = const Color(0xFF7CB342));
  c.drawLine(
    const Offset(10.5, 19),
    const Offset(14.5, 7),
    Paint()
      ..color = const Color(0xFF4F6B34)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );
  final plus = Paint()
    ..color = const Color(0xFFF2E8D5)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(18, 15.5), const Offset(18, 20.5), plus);
  c.drawLine(const Offset(15.5, 18), const Offset(20.5, 18), plus);
}

void _rain(Canvas c) {
  _cloud(c, const Offset(12, 7), const Color(0xFF8FA6B8));
  final drop = Paint()..color = const Color(0xFF4A90C4);
  for (final (dx, dy) in const [(7.0, 14.0), (12.0, 17.0), (17.0, 14.0)]) {
    final d = Path()
      ..moveTo(dx, dy)
      ..quadraticBezierTo(dx - 2.2, dy + 3.6, dx, dy + 5)
      ..quadraticBezierTo(dx + 2.2, dy + 3.6, dx, dy)
      ..close();
    c.drawPath(d, drop);
  }
}

void _poison(Canvas c) {
  _cloud(c, const Offset(12, 13), const Color(0xFF86A34A), k: 1.35);
  final bubble = Paint()..color = const Color(0xFF9CBB5A);
  c.drawCircle(const Offset(7, 6), 2.0, bubble);
  c.drawCircle(const Offset(13, 4), 1.4, bubble);
  c.drawCircle(const Offset(17.5, 6.5), 1.7, bubble);
  // Koyu benekler (zehir gözenekleri).
  final pore = Paint()..color = const Color(0xFF55642B);
  c.drawCircle(const Offset(9, 13), 1.3, pore);
  c.drawCircle(const Offset(14.5, 15), 1.6, pore);
}

void _fear(Canvas c) {
  // Çığlık: merkez nokta + iki yana genişleyen mor ses dalgaları.
  c.drawCircle(const Offset(12, 12), 2.6,
      Paint()..color = const Color(0xFFB07CC6));
  for (var i = 1; i <= 2; i++) {
    final p = Paint()
      ..color = const Color(0xFFB07CC6).withValues(alpha: 1 - i * 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 - i * 0.5
      ..strokeCap = StrokeCap.round;
    final r = 4.5 + i * 3.6;
    c.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: r),
        -0.7, 1.4, false, p);
    c.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: r),
        math.pi - 0.7, 1.4, false, p);
  }
}

void _armor(Canvas c) {
  final shield = Path()
    ..moveTo(12, 2.5)
    ..lineTo(19.5, 5.5)
    ..lineTo(19.5, 12)
    ..quadraticBezierTo(19.5, 18.5, 12, 21.5)
    ..quadraticBezierTo(4.5, 18.5, 4.5, 12)
    ..lineTo(4.5, 5.5)
    ..close();
  c.drawPath(shield, Paint()..color = const Color(0xFF9BB8C9));
  c.drawPath(
    shield,
    Paint()
      ..color = const Color(0xFF5E7B8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  // Krem şerit vurgu.
  final stripe = Path()
    ..moveTo(12, 5)
    ..lineTo(17, 7)
    ..lineTo(17, 12)
    ..quadraticBezierTo(17, 16.5, 12, 19)
    ..close();
  c.drawPath(stripe,
      Paint()..color = const Color(0xFFF2E8D5).withValues(alpha: 0.35));
}

void _fireRing(Canvas c) {
  c.drawCircle(
    const Offset(12, 13),
    7,
    Paint()
      ..color = const Color(0xFFE8683C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6,
  );
  // Halka üstünde alevler.
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 - math.pi / 2;
    final bx = 12 + math.cos(a) * 7;
    final by = 13 + math.sin(a) * 7;
    final h = i.isEven ? 4.2 : 3.0;
    final flame = Path()
      ..moveTo(bx - 1.6, by)
      ..lineTo(bx + math.cos(a) * h, by + math.sin(a) * h)
      ..lineTo(bx + 1.6, by)
      ..close();
    c.drawPath(flame,
        Paint()..color = i.isEven
            ? const Color(0xFFF6C044)
            : const Color(0xFFE8683C));
  }
}

void _freeze(Canvas c) {
  final p = Paint()
    ..color = const Color(0xFFBFE6F5)
    ..strokeWidth = 1.9
    ..strokeCap = StrokeCap.round;
  final tip = Paint()
    ..color = const Color(0xFF8FCBE8)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final dir = Offset(math.cos(a), math.sin(a));
    final end = Offset(12 + dir.dx * 8.5, 12 + dir.dy * 8.5);
    c.drawLine(const Offset(12, 12), end, p);
    // Uç çatalları.
    final mid = Offset(12 + dir.dx * 5.5, 12 + dir.dy * 5.5);
    final left = Offset(math.cos(a + 0.6), math.sin(a + 0.6));
    final right = Offset(math.cos(a - 0.6), math.sin(a - 0.6));
    c.drawLine(mid, mid + left * 2.6, tip);
    c.drawLine(mid, mid + right * 2.6, tip);
  }
  c.drawCircle(const Offset(12, 12), 1.8,
      Paint()..color = const Color(0xFFE8F6FC));
}
