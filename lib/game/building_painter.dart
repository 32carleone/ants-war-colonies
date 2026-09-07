import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../models/building.dart';

/// Bina gövdesi çizimi — OYUN SAHNESİ ve WIKI aynı fonksiyonu kullanır,
/// böylece wikideki görseller oyundakilerle birebir aynıdır.
/// [tint]: sahip rengi (null = nötr), [time]: canlılık animasyonları.
void paintBuilding(
  Canvas canvas,
  BuildingType type, {
  required Offset center,
  int level = 1,
  Color? tint,
  double time = 0,
  int seed = 5,
}) {
  switch (type) {
    case BuildingType.tower:
      _tower(canvas, center, level, tint, time);
    case BuildingType.resource:
      _resource(canvas, center, level, tint, time, seed);
    case BuildingType.power:
      _power(canvas, center, level, tint, time);
    case BuildingType.hatchery:
      _hatchery(canvas, center, tint, time, seed);
  }
}

Color _mix(Color base, Color? tint, double amount) =>
    tint == null ? base : Color.lerp(base, tint, amount)!;

/// Pürüzlü organik kapalı şekil (yataklar için).
Path buildingBlob(Offset center, double radius, int seed,
    {double squishY = 1, double jitter = 0.16, int points = 12}) {
  final path = Path();
  for (var i = 0; i <= points; i++) {
    final a = i / points * 2 * math.pi;
    final wob = math.sin(a * 3 + seed) * jitter +
        math.sin(a * 5 + seed * 1.7) * jitter * 0.5;
    final r = radius * (1 + wob);
    final x = center.dx + math.cos(a) * r;
    final y = center.dy + math.sin(a) * r * squishY;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// Sahip bayrağı: sallanan küçük flama (nötr soluk gri).
/// Şekil ÜÇGEN DEĞİL: uç köşesi OVAL, üst-alt kenarlar hafif kavisli
/// (rüzgârda kıvrılan kumaş dili) — bir tık da büyütülmüştür.
void drawBuildingFlag(Canvas canvas, Offset base,
    {double height = 19, Color? tint, double time = 0}) {
  final color = tint ?? kNeutralColor.withValues(alpha: 0.7);
  canvas.drawLine(
    base,
    base.translate(0, -height),
    Paint()
      ..color = const Color(0xFF4A3A20)
      ..strokeWidth = 1.6,
  );
  final wave = math.sin(time * 4) * 1.6; // dalgalanma
  final tipY = base.dy - height;
  const len = 14.0;
  final flag = Path()
    ..moveTo(base.dx, tipY)
    // Üst kenar: dışa doğru hafif kavis (dalgayla oynar).
    ..quadraticBezierTo(base.dx + len * 0.5, tipY - 2.0 + wave * 0.4,
        base.dx + len, tipY + 2.2 + wave * 0.5)
    // Uç köşe: sivri değil OVAL kıvrım.
    ..quadraticBezierTo(base.dx + len + 3.6, tipY + 4.6 + wave * 0.4,
        base.dx + len - 0.8, tipY + 6.6 + wave * 0.3)
    // Alt kenar: içe kavisli dönüş.
    ..quadraticBezierTo(base.dx + len * 0.45, tipY + 8.8 - wave * 0.3,
        base.dx, tipY + 8.2)
    ..close();
  canvas.drawPath(flag, Paint()..color = color.withValues(alpha: 0.95));
}

/// Kule: yükselen ahşap-toprak gözetleme kulesi — taban, incelen gövde,
/// tepede kazık çitli platform. Seviye = daha yüksek gövde + daha çok kazık.
void _tower(Canvas canvas, Offset c, int level, Color? tint, double time) {
  final h = 26.0 + level * 7; // gövde yüksekliği
  final top = c.dy - h;

  // Yer gölgesi.
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(4, 8), width: 52, height: 18),
    Paint()..color = const Color(0x552E2214),
  );
  // Taban toprak seti.
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(0, 6), width: 46, height: 18),
    Paint()..color = _mix(const Color(0xFF63512F), tint, 0.38),
  );

  // İncelen gövde.
  final body = Path()
    ..moveTo(c.dx - 17, c.dy + 6)
    ..lineTo(c.dx - 11, top)
    ..lineTo(c.dx + 11, top)
    ..lineTo(c.dx + 17, c.dy + 6)
    ..close();
  canvas.drawPath(body, Paint()..color = _mix(const Color(0xFF7A6540), tint, 0.38));
  // Sağ yüz gölgesi (hacim).
  final shade = Path()
    ..moveTo(c.dx + 4, c.dy + 6)
    ..lineTo(c.dx + 3, top)
    ..lineTo(c.dx + 11, top)
    ..lineTo(c.dx + 17, c.dy + 6)
    ..close();
  canvas.drawPath(shade, Paint()..color = _mix(const Color(0xFF5E4C2E), tint, 0.38));
  // Yatay kalas bantları.
  final band = Paint()
    ..color = const Color(0xFF4A3A20)
    ..strokeWidth = 1.6;
  for (var i = 1; i <= 2 + level; i++) {
    final ty = c.dy + 6 + (top - c.dy - 6) * i / (3.0 + level);
    final halfW = 17 - 6 * (c.dy + 6 - ty) / (c.dy + 6 - top);
    canvas.drawLine(Offset(c.dx - halfW, ty), Offset(c.dx + halfW, ty), band);
  }
  // Mazgal pencere.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(c.dx - 3, (c.dy + top) / 2), width: 4, height: 7),
      const Radius.circular(2),
    ),
    Paint()..color = const Color(0xFF241A0E),
  );
  // Kapı.
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(0, 3), width: 10, height: 12),
    Paint()..color = const Color(0xFF241A0E),
  );

  // Üst platform.
  canvas.drawOval(
    Rect.fromCenter(center: Offset(c.dx, top), width: 32, height: 12),
    Paint()..color = _mix(const Color(0xFF8A7248), tint, 0.3),
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(c.dx, top - 1), width: 25, height: 8),
    Paint()..color = _mix(const Color(0xFF6A5634), tint, 0.3),
  );
  // Kazık çit (palisade) — elips kenarında dikey kazıklar.
  final stake = Paint()
    ..color = const Color(0xFF4A3A20)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  final stakes = 7 + level * 2;
  for (var k = 0; k < stakes; k++) {
    final a = k * 2 * math.pi / stakes;
    final sx = c.dx + math.cos(a) * 15;
    final sy = top + math.sin(a) * 5;
    canvas.drawLine(Offset(sx, sy), Offset(sx, sy - 7), stake);
  }
  // Tepede sallanan sahip bayrağı.
  drawBuildingFlag(canvas, Offset(c.dx, top - 3),
      height: 12, tint: tint, time: time);

  // CANLILIK (karıncasız — askerlerle karışmasın): platform kenarında
  // yavaşça DÖNEN gözcü ışıltısı, mazgalda yanıp sönen nöbet ışığı ve
  // kapıdan ara ara savrulan toz.
  final blink = (math.sin(time * 2.2) * 0.5 + 0.5);
  canvas.drawCircle(
    Offset(c.dx - 3, (c.dy + top) / 2),
    1.6,
    Paint()
      ..color = const Color(0xFFF6C044).withValues(alpha: 0.25 + blink * 0.5),
  );
  final scoutA = time * 1.4;
  final scout = Offset(
      c.dx + math.cos(scoutA) * 14, top + math.sin(scoutA) * 4.5 - 4);
  canvas.drawCircle(scout, 2.6,
      Paint()..color = const Color(0x33F6C044));
  canvas.drawCircle(scout, 1.3,
      Paint()..color = const Color(0xCCF6E4A8));
  for (var i = 0; i < 2; i++) {
    final t = ((time * 0.5 + i * 0.5) % 1.0);
    canvas.drawCircle(
      c.translate(3 + t * 9 + i * 2, 7 - t * 3),
      1.0 + t * 1.4,
      Paint()..color = const Color(0xFF8A7248).withValues(alpha: 0.3 * (1 - t)),
    );
  }
}

/// Kaynak binası: mantar çiftliği — seviyeyle çoğalan mantar kümesi.
void _resource(
    Canvas canvas, Offset c, int level, Color? tint, double time, int seed) {
  // Yaprak/toprak yatağı — pürüzlü organik kenarlı.
  canvas.drawPath(
    buildingBlob(c.translate(0, 4), 31, seed, squishY: 0.66, jitter: 0.18),
    Paint()..color = const Color(0xFF4C4426),
  );
  canvas.drawPath(
    buildingBlob(c.translate(0, 3), 26, seed + 4, squishY: 0.64, jitter: 0.2),
    Paint()..color = const Color(0xFF5A5230),
  );
  // Kenarda dökülmüş yaprak kırpıntıları.
  for (var i = 0; i < 6; i++) {
    final a = i * 1.15 + seed;
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(math.cos(a) * 33, math.sin(a) * 20 + 4),
          width: 6,
          height: 3.4),
      Paint()..color = const Color(0xFF7A9A4C).withValues(alpha: 0.8),
    );
  }
  // Mantarlar — hafifçe nefes alır (canlılık).
  final count = 2 + level;
  for (var i = 0; i < count; i++) {
    final a = i * 2.4 + 0.7;
    final r = 12.0 + (i % 2) * 7;
    final bob = math.sin(time * 1.8 + i * 1.3) * 2.0;
    final mc =
        c.translate(math.cos(a) * r, math.sin(a) * r * 0.6 - 2 + bob * 0.4);
    final capW = 13.0 - (i % 3) * 2 + bob * 0.5;
    // Sap.
    canvas.drawRect(
      Rect.fromCenter(center: mc.translate(0, 3), width: 3.4, height: 8),
      Paint()..color = const Color(0xFFD8CBA8),
    );
    // Şapka.
    canvas.drawOval(
      Rect.fromCenter(center: mc.translate(0, -2), width: capW, height: 7),
      Paint()..color = _mix(const Color(0xFFB9985E), tint, 0.5),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: mc.translate(-1, -3), width: capW * 0.5, height: 3),
      Paint()..color = const Color(0xFFCBAF7C),
    );
  }
  // CANLILIK (karıncasız): şapkalardan süzülen spor tanecikleri —
  // mantarların nefesiyle birlikte çiftlik sürekli "işler".
  for (var i = 0; i < 4; i++) {
    final t = ((time * 0.4 + i / 4) % 1.0);
    final a = i * 1.7 + 0.9;
    canvas.drawCircle(
      c.translate(
          math.cos(a) * 13 + math.sin(time * 1.3 + i) * 3, -4 - t * 15),
      1.1 + (1 - t) * 0.7,
      Paint()
        ..color = const Color(0xFFEDE2C4).withValues(alpha: 0.45 * (1 - t)),
    );
  }
  // Sahip bayrağı (kenarda).
  drawBuildingFlag(canvas, c.translate(24, -8), tint: tint, time: time);
}

/// Güç binası: ASKERİ ÜS — kazık çitli garnizon avlusu, komuta tümseği,
/// tüten feromon ocağı ve çift sancak. Seviye = daha çok kazık + sancak.
void _power(Canvas canvas, Offset c, int level, Color? tint, double time) {
  // Avlu zemini (çiğnenmiş toprak).
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(2, 5), width: 68, height: 46),
    Paint()..color = const Color(0x552E2214),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(0, 3), width: 64, height: 42),
    Paint()..color = _mix(const Color(0xFF6B5A38), tint, 0.3),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(0, 2), width: 54, height: 34),
    Paint()..color = _mix(const Color(0xFF7A6540), tint, 0.3),
  );

  // Kazık çit (güneyde kapı boşluğu bırakır).
  final stakePaint = Paint()
    ..color = const Color(0xFF4A3A20)
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;
  final stakeTop = Paint()..color = const Color(0xFF5E4C2E);
  final stakes = 12 + level * 3;
  for (var k = 0; k < stakes; k++) {
    final a = k * 2 * math.pi / stakes;
    // Kapı boşluğu: alt orta ~40°.
    if ((a - math.pi / 2).abs() < 0.35) continue;
    final sx = c.dx + math.cos(a) * 31;
    final sy = c.dy + 2 + math.sin(a) * 20;
    final hgt = 9.0 + math.sin(a) * 1.5;
    canvas.drawLine(Offset(sx, sy), Offset(sx, sy - hgt), stakePaint);
    canvas.drawCircle(Offset(sx, sy - hgt), 1.4, stakeTop);
  }

  // Komuta tümseği (avlu ortasında) + feromon ocağı ağzı.
  canvas.drawCircle(c.translate(0, -2), 15,
      Paint()..color = _mix(const Color(0xFF5C4A2E), tint, 0.38));
  canvas.drawCircle(c.translate(0, -4), 11,
      Paint()..color = _mix(const Color(0xFF6E5838), tint, 0.45));
  canvas.drawOval(
    Rect.fromCenter(
        center: c.translate(0, -5),
        width: 10 + math.sin(time * 1.5) * 1,
        height: 7 + math.sin(time * 1.5) * 0.6),
    Paint()..color = const Color(0xFF241A0E),
  );

  // Ocaktan yükselen feromon buharı (canlılık).
  for (var i = 0; i < 3; i++) {
    final t = ((time * 0.5 + i / 3) % 1.0);
    canvas.drawCircle(
      c.translate(math.sin(time * 2 + i * 2.1) * 3, -6 - t * 16),
      1.8 + t * 2.6,
      Paint()..color = const Color(0xFFE8B33C).withValues(alpha: 0.28 * (1 - t)),
    );
  }

  // Çift sancak (askeri kimlik) — sallanır, sahip rengini taşır.
  drawBuildingFlag(canvas, c.translate(-24, -6),
      height: 15, tint: tint, time: time);
  drawBuildingFlag(canvas, c.translate(20, -6),
      height: 15, tint: tint, time: time);

  // Talim kuklası (avluda küçük detay).
  canvas.drawLine(
    c.translate(12, 8),
    c.translate(12, 1),
    Paint()
      ..color = const Color(0xFF4A3A20)
      ..strokeWidth = 2,
  );
  canvas.drawCircle(c.translate(12, 0), 2, stakeTop);

  // CANLILIK (karıncasız): ocaktan avluya yayılan FEROMON NABZI —
  // periyodik genişleyen turuncu halka + kuklanın hafif sallanışı.
  final pulse = ((time * 0.6) % 1.0);
  canvas.drawOval(
    Rect.fromCenter(
        center: c.translate(0, -2),
        width: 18 + pulse * 42,
        height: 12 + pulse * 26),
    Paint()
      ..color = const Color(0xFFE8B33C).withValues(alpha: 0.30 * (1 - pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  final sway = math.sin(time * 3.1) * 1.3;
  canvas.drawLine(
    c.translate(12, 8),
    c.translate(12 + sway, 0),
    Paint()
      ..color = const Color(0xFF4A3A20)
      ..strokeWidth = 2,
  );
  canvas.drawCircle(c.translate(12 + sway, -1), 2, stakeTop);
}

/// KULUÇKA İSTASYONU (İkinci Çıkış): sıcak toprak çukurunda yumurta kümesi,
/// bir yanda gölgelik yaprak, önde dışarı açılan tünel ağzı. Sahibi burayı
/// ikinci çıkış olarak kullanır — güç vermez, yükseltilmez.
void _hatchery(Canvas canvas, Offset c, Color? tint, double time, int seed) {
  // Yer gölgesi + kabarık toprak seti (organik).
  canvas.drawPath(
    buildingBlob(c.translate(3, 8), 32, seed, squishY: 0.62, jitter: 0.2),
    Paint()..color = const Color(0x552E2214),
  );
  canvas.drawPath(
    buildingBlob(c.translate(0, 4), 30, seed, squishY: 0.68, jitter: 0.2),
    Paint()..color = _mix(const Color(0xFF6B4A2B), tint, 0.35),
  );
  canvas.drawPath(
    buildingBlob(c.translate(0, 2), 24, seed + 3, squishY: 0.66, jitter: 0.18),
    Paint()..color = _mix(const Color(0xFF84603A), tint, 0.3),
  );
  // Kuluçka çukuru (sıcak iç).
  canvas.drawPath(
    buildingBlob(c.translate(-2, 0), 16, seed + 6, squishY: 0.7, jitter: 0.16),
    Paint()..color = const Color(0xFF4E3820),
  );

  // Yumurtalar: krem oval küme — hafifçe "nefes alır" (kuluçka canlılığı).
  for (var i = 0; i < 5; i++) {
    final a = i * 1.35 + seed;
    final ex = c.dx - 2 + math.cos(a) * (6 + (i % 2) * 4);
    final ey = c.dy - 1 + math.sin(a) * 4.5;
    final swell = 1 + math.sin(time * 1.6 + i * 1.1) * 0.06;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(ex, ey), width: 7.5 * swell, height: 9.5 * swell),
      Paint()..color = const Color(0xFFEDE2C4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ex - 1.4, ey - 2), width: 2.6, height: 3),
      Paint()..color = const Color(0xFFFFF8E6),
    );
  }

  // Gölgelik yaprak (kuzeydoğuda, yumurtaları korur) — damarlı.
  canvas.save();
  canvas.translate(c.dx + 17, c.dy - 14);
  canvas.rotate(-0.5 + math.sin(time * 1.2) * 0.04);
  final leaf = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(14, -10, 26, -4)
    ..quadraticBezierTo(14, 6, 0, 0)
    ..close();
  canvas.drawPath(leaf, Paint()..color = const Color(0xFF6E8A44));
  canvas.drawLine(Offset.zero, const Offset(24, -4),
      Paint()
        ..color = const Color(0xFF55702F)
        ..strokeWidth = 1.4);
  canvas.restore();

  // TÜNEL AĞZI (ikinci çıkış!): güneyde koyu delik + çıkan izler.
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(6, 12), width: 13, height: 9),
    Paint()..color = const Color(0xFF241A0E),
  );
  for (var i = 0; i < 3; i++) {
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(10 + i * 6.0, 16 + i * 2.5),
          width: 4,
          height: 2.4),
      Paint()..color = const Color(0x66241A0E),
    );
  }

  // Sahip bayrağı.
  drawBuildingFlag(canvas, c.translate(-22, -8), tint: tint, time: time);
}
