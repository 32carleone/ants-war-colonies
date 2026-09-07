import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/units.dart';
import '../models/nest.dart';
import '../ui/ability_art.dart' show paintAbilityArt;
import 'ant_painter.dart';
import 'ants_wars_game.dart';

/// Ana yuvanın haritadaki bileşeni: tümsek, giriş deliği, kraliçe,
/// takım halkası ve üretim doluş yayı. (Nüfus sayısı yazılmaz — üst bar
/// zaten gösterir.) Düşman yuvalarının yanında botun yetenek seti mini
/// ikonlarla belirtilir (göze batmayan küçük rozet).
/// Dokunma/sürükleme etkileşimleri InputController üzerinden yönetilir.
class NestComponent extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  NestComponent({required this.nest})
      : super(
          position: nest.position.clone(),
          anchor: Anchor.center,
          size: Vector2.all(110),
        );

  final Nest nest;

  Offset get _center => Offset(size.x / 2, size.y / 2);

  /// Pürüzlü organik tümsek şekli (haritayla bütünleşik).
  Path _blob(Offset center, double radius, int seed,
      {double jitter = 0.12, int points = 14}) {
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * math.pi;
      final wob = math.sin(a * 3 + seed) * jitter +
          math.sin(a * 5 + seed * 1.7) * jitter * 0.5;
      final r = radius * (1 + wob);
      final x = center.dx + math.cos(a) * r;
      final y = center.dy + math.sin(a) * r * 0.94;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  /// Düşman yuvasının canlı bilgileri (nüfus, üretim, can) sis altında gizli.
  bool get _infoVisible {
    final human = game.gameState.humanPlayer;
    if (human == null || nest.owner.id == human.id) return true;
    return game.fog.isVisible(nest.position);
  }

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (nest.destroyed) {
      _renderRuined(canvas);
      return;
    }
    final c = _center;

    // Tümsek katmanları — PÜRÜZLÜ organik şekil (haritayla bütünleşik),
    // takım rengine tonlu. Bayrak/renk sahibini HER ZAMAN gösterir.
    final tc = nest.owner.color;
    Color tinted(Color base, double t) => Color.lerp(base, tc, t)!;
    final seed = (nest.position.x + nest.position.y).toInt() % 19;
    canvas.drawPath(_blob(c.translate(3, 5), 46, seed, jitter: 0.1),
        Paint()..color = const Color(0x552E2214));
    // Varsayılan yuva animasyonu: tümsek nazikçe NEFES ALIR.
    final breathe = 1 + math.sin(_time * 1.6) * 0.018;
    canvas.drawPath(_blob(c, 46, seed, jitter: 0.11),
        Paint()..color = tinted(const Color(0xFF5C4326), 0.18));
    canvas.drawPath(
        _blob(c.translate(0, -3), 37 * breathe, seed + 5, jitter: 0.13),
        Paint()..color = tinted(const Color(0xFF6F5330), 0.26));
    canvas.drawPath(
        _blob(c.translate(0, -5), 28 * breathe, seed + 9, jitter: 0.15),
        Paint()..color = tinted(const Color(0xFF7E613A), 0.34));

    // Doku: kazılmış toprak taneleri (deterministik serpinti).
    final grain = Paint()..color = const Color(0x33241A0E);
    final grainLight = Paint()..color = const Color(0x2EFFF3D6);
    for (var i = 0; i < 26; i++) {
      final a = i * 2.399963;
      final r = 14 + (i * 7) % 30;
      final gp = c.translate(math.cos(a) * r, math.sin(a) * r * 0.8 - 2);
      canvas.drawCircle(gp, 1.1 + (i % 3) * 0.5, i.isEven ? grain : grainLight);
    }
    // Giriş çevresi kazı seti (taze toprak halkası).
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -4), width: 32, height: 24),
      Paint()..color = tinted(const Color(0xFF8A6E45), 0.3),
    );
    // Küçük yan tünel ağzı.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-22, 14), width: 9, height: 6),
      Paint()..color = const Color(0xFF241A0E),
    );
    // Erzak köşesi: yaprak parçaları + tohum.
    final leaf = Paint()..color = const Color(0xFF7A9A4C);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(24, 16), width: 7, height: 4),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(29, 12), width: 5, height: 3),
      leaf,
    );
    canvas.drawCircle(
        c.translate(20, 21), 2, Paint()..color = const Color(0xFFC9B784));
    // Minik taşlar.
    canvas.drawCircle(
        c.translate(-28, -14), 2.4, Paint()..color = const Color(0xFF8D877A));
    canvas.drawCircle(
        c.translate(-24, -18), 1.6, Paint()..color = const Color(0xFF7A7468));

    // Giriş deliği (kazı ritmiyle hafifçe nabız atar).
    final mouth = 1 + math.sin(_time * 2.3) * 0.05;
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, -4), width: 24 * mouth, height: 17 * mouth),
      Paint()..color = const Color(0xFF241A0E),
    );
    // Girişten süzülen toz zerreleri (sürekli kazı hissi).
    for (var k = 0; k < 3; k++) {
      final t = ((_time * 0.6 + k / 3) % 1.0);
      canvas.drawCircle(
        c.translate(math.sin(_time * 1.3 + k * 2.1) * 5, -8 - t * 20),
        1.3 + t * 1.4,
        Paint()
          ..color = const Color(0xFFC9B784).withValues(alpha: 0.3 * (1 - t)),
      );
    }

    // Kraliçe: girişin hemen yanında, yuvadan asla ayrılmaz.
    _renderQueen(canvas, c.translate(14, 8));

    // İşçi trafiği: girişte dönüp duran minik karıncalar (nüfusla orantılı).
    _renderWorkerTraffic(canvas, c);

    // Takım bayrağı: tümseğin tepesinde sallanan büyük flama.
    final base = c.translate(-16, -26);
    canvas.drawLine(
      base,
      base.translate(0, -20),
      Paint()
        ..color = const Color(0xFF4A3A20)
        ..strokeWidth = 2.2,
    );
    final wave = math.sin(_time * 3.4) * 2.2;
    final flag = Path()
      ..moveTo(base.dx, base.dy - 20)
      ..lineTo(base.dx + 15, base.dy - 16 + wave * 0.4)
      ..lineTo(base.dx, base.dy - 12)
      ..close();
    canvas.drawPath(flag, Paint()..color = nest.owner.color);

    // Üretim doluş yayı (halkanın hemen içinde) — sis altında gizli.
    if (nest.productionQueue.isNotEmpty && _infoVisible) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 40),
        -math.pi / 2,
        2 * math.pi * nest.productionProgress,
        false,
        Paint()
          ..color = const Color(0xFFF2E8D5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }



    // Düşman yuvası: botun yetenek seti mini ikonlarla (göze batmadan).
    _renderEnemyAbilities(canvas, c);

    // Kraliçe can barı (hasar aldıysa göster) — sis altında gizli.
    if (nest.queenHp < kQueenMaxHp && _infoVisible) {
      final ratio = (nest.queenHp / kQueenMaxHp).clamp(0.0, 1.0);
      final barRect = Rect.fromLTWH(size.x / 2 - 25, 2, 50, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2.5)),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barRect.left, barRect.top, barRect.width * ratio, 5),
          const Radius.circular(2.5),
        ),
        Paint()
          ..color = Color.lerp(
              const Color(0xFFD32F2F), const Color(0xFF7CB342), ratio)!,
      );
    }
  }

  /// Düşman takım yuvasının altında botun 3 yeteneği: küçük yarı saydam
  /// rozet içinde mini ikonlar. Yetenekler harita bilgisi gibi açıktır
  /// (rakibin elini bilmek taktik verir) ama görsel olarak geri planda kalır.
  List<AbilityType>? _enemyAbilities;
  String? _personaLabel;
  TextPainter? _personaTp;

  void _renderEnemyAbilities(Canvas canvas, Offset c) {
    final human = game.gameState.humanPlayer;
    if (human == null || nest.owner.team == human.team) return;
    if (_enemyAbilities == null) {
      for (final b in game.bots) {
        if (b.player.id == nest.owner.id) {
          _enemyAbilities = b.abilities;
          // KİŞİLİK GÖSTERİMİ: rakibin karakteri açık bilgidir —
          // "Kale ile oynuyorsun" bilmek taktik verir (seferde gizli).
          if (game.gameState.mission == null) {
            _personaLabel = b.persona.label;
          }
        }
      }
      if (_enemyAbilities == null) return;
    }
    final abilities = _enemyAbilities!;
    final w = abilities.length * 14.0 + 6;
    final rect =
        Rect.fromCenter(center: c.translate(0, 54), width: w, height: 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0x59000000),
    );
    var x = rect.left + 3;
    for (final t in abilities) {
      canvas.save();
      canvas.translate(x, rect.top + 2);
      paintAbilityArt(canvas, t, 12);
      canvas.restore();
      x += 14;
    }
    // Rozet altında kişilik adı (küçük, takım renginde — göze batmaz).
    final label = _personaLabel;
    if (label != null) {
      final tp = _personaTp ??= TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: nest.owner.color.withValues(alpha: 0.95),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c.translate(-tp.width / 2, 63));
    }
  }

  /// Giriş deliği çevresinde giren-çıkan işçi karıncalar (canlılık).
  /// Sayı yuva nüfusuyla orantılı; rota deterministik (zaman tabanlı).
  void _renderWorkerTraffic(Canvas canvas, Offset center) {
    final workers = (2 + nest.population ~/ 8).clamp(2, 5);
    for (var k = 0; k < workers; k++) {
      final phase = k * 2.1;
      final w = 0.5 + (k % 3) * 0.14; // tur hızı
      final angle = _time * w + phase;
      // Yarıçap girişten dışa doğru gidip gelir (içeri girip çıkma hissi).
      final r = 12 + 24 * (0.5 + 0.5 * math.sin(_time * 0.7 + phase * 1.7));
      final pos = center.translate(
          math.cos(angle) * r, math.sin(angle) * r * 0.8 - 4);
      // Hareket yönü (teğet).
      final heading = angle + math.pi / 2;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(heading);
      canvas.scale(0.42);
      paintAnt(
        canvas,
        UnitType.fire,
        walkPhase: _time * 9 + k * 2,
        idleTime: _time + k,
        teamColor: nest.owner.color.withValues(alpha: 0.0), // işaretsiz işçi
      );
      canvas.restore();
    }
  }

  void _renderQueen(Canvas canvas, Offset at) {
    final body = Paint()..color = const Color(0xFF3B2A17);
    final shine = Paint()..color = const Color(0xFF54402A);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-0.5);
    // Bacaklar.
    final leg = Paint()
      ..color = const Color(0xFF2C1F10)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final x = -2.0 + i * 4;
        canvas.drawLine(
            Offset(x, 0), Offset(x + 3 * side - 3, 6.0 * side), leg);
      }
    }
    // Abdomen (kraliçede iri) — toraks — kafa.
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(-8, 0), width: 16, height: 10),
        body);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(-9, -1.5), width: 9, height: 4),
        shine);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(2, 0), width: 7, height: 6), body);
    canvas.drawCircle(const Offset(8, 0), 3.2, body);
    // Antenler.
    canvas.drawLine(const Offset(9, -1), const Offset(13, -5), leg);
    canvas.drawLine(const Offset(9, 1), const Offset(13, 5), leg);
    canvas.restore();
  }

  void _renderRuined(Canvas canvas) {
    final c = _center;
    // Çökmüş, sahipsiz yuva.
    canvas.drawCircle(c, 44, Paint()..color = const Color(0xFF3A2D1B));
    canvas.drawCircle(c.translate(-6, 2), 20, Paint()..color = const Color(0xFF2A2012));
    canvas.drawCircle(c.translate(12, -6), 12, Paint()..color = const Color(0xFF312615));
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -2), width: 34, height: 22),
      Paint()..color = const Color(0xFF1C1409),
    );
  }
}
