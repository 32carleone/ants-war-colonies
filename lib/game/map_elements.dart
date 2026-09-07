import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../models/game_map.dart';
import '../models/player.dart';
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'unit_component.dart';

/// KAZILABİLİR KAYA GEÇİDİ durumu: kapalı tıkaç → kazı ilerlemesi → AÇIK.
/// Kazı, bina ele geçirme gibi çevredeki asker çoğunluğuyla ilerler ama
/// KALICIDIR: rakip çoğunluğu yalnız duraklatır, ilerleme erimez.
class DigSite {
  DigSite(this.feature);

  final TerrainFeature feature;

  double progress = 0; // 0..1
  Player? digger; // halkanın rengi (son kazan takımın lideri)
  bool open = false;

  Vector2 get center {
    final pts = feature.points;
    if (pts.length == 1) return pts.first;
    return (pts.first + pts.last) / 2;
  }
}

/// Kazı geçidinin görseli: kapalıyken çatlaklı kaya tıkacı + kazı halkası,
/// açılınca kazılmış toprak patika. Kenarlar organik/pürüzlüdür.
class DigSiteComponent extends Component with HasGameReference<AntsWarsGame> {
  DigSiteComponent({required this.site}) : super(priority: -6);

  final DigSite site;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final f = site.feature;
    final a = f.points.first;
    final b = f.points.length > 1 ? f.points.last : f.points.first;
    final dir = b == a ? Vector2(1, 0) : (b - a).normalized();
    final normal = Vector2(-dir.y, dir.x);
    final len = math.max(a.distanceTo(b), f.width);
    final half = f.width / 2;
    final seed = (a.x + b.y).toInt() % 19;

    if (site.open) {
      _renderDugChannel(canvas, a, dir, normal, len, half, seed);
    } else {
      _renderPlug(canvas, a, dir, normal, len, half, seed);
      _renderProgress(canvas);
    }
  }

  /// Kapalı tıkaç: hat boyunca sıkışmış pürüzlü kaya kütleleri + çatlaklar.
  void _renderPlug(Canvas c, Vector2 a, Vector2 dir, Vector2 normal,
      double len, double half, int seed) {
    // Etek gölgesi.
    c.drawPath(_bandPath(a, dir, normal, len, half + 6, seed, 5),
        Paint()..color = const Color(0x4D241A0E));
    // Kaya gövdesi (koyu — kazılası tıkaç, dağdan farklı görünsün).
    c.drawPath(_bandPath(a, dir, normal, len, half + 1, seed, 4),
        Paint()..color = const Color(0xFF5C554A));
    c.drawPath(_bandPath(a, dir, normal, len, half * 0.55, seed + 3, 3),
        Paint()..color = const Color(0xFF6E675A));
    // Tıkaç boyunca iri yumrular.
    for (var d = 8.0; d < len; d += 15) {
      final wob = math.sin(d * 0.9 + seed) * half * 0.4;
      final p = a + dir * d + normal * wob;
      final r = 5.5 + math.sin(d * 1.7 + seed) * 2;
      c.drawPath(
        _blob(Offset(p.x, p.y), r, seed + d.toInt(), points: 8, jitter: 0.25),
        Paint()
          ..color = (d ~/ 15).isEven
              ? const Color(0xFF77705F)
              : const Color(0xFF645D50),
      );
    }
    // Çatlaklar: kazılabilirlik ipucu (ilerledikçe koyulaşıp çoğalır).
    final crack = Paint()
      ..color = const Color(0xFF2E2820)
          .withValues(alpha: 0.55 + site.progress * 0.45)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final crackCount = 3 + (site.progress * 6).round();
    for (var i = 0; i < crackCount; i++) {
      var p = a + dir * ((i + 0.5) * len / crackCount) +
          normal * (math.sin(i * 2.1 + seed) * half * 0.5);
      for (var s = 0; s < 3; s++) {
        final n = p +
            dir * (math.sin(i + s * 1.3 + seed) * 7) +
            normal * ((s.isEven ? 1 : -1) * (4 + s * 3));
        c.drawLine(Offset(p.x, p.y), Offset(n.x, n.y), crack);
        p = n;
      }
    }
    // Kazı sürüyorsa toz/toprak zerreleri savrulur (canlılık).
    if (site.progress > 0 && !site.open) {
      final mid = site.center;
      for (var i = 0; i < 6; i++) {
        final t = ((_time * 0.9 + i / 6) % 1.0);
        final ang = i * 1.05 + seed;
        c.drawCircle(
          Offset(mid.x + math.cos(ang) * (10 + t * 26),
              mid.y + math.sin(ang) * (8 + t * 18) - t * 10),
          1.6 * (1 - t) + 0.4,
          Paint()
            ..color = const Color(0xFFB89B6E).withValues(alpha: 0.5 * (1 - t)),
        );
      }
    }
  }

  /// Kazı ilerleme halkası (bina ele geçirme halkasıyla aynı dil).
  void _renderProgress(Canvas c) {
    if (site.progress <= 0 || site.open) return;
    final mid = site.center;
    final center = Offset(mid.x, mid.y);
    const r = 40.0;
    c.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * site.progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = site.digger?.color ?? const Color(0xFFD8C9A3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Açılmış geçit: kazılmış toprak patika + iki yana itilmiş moloz.
  void _renderDugChannel(Canvas c, Vector2 a, Vector2 dir, Vector2 normal,
      double len, double half, int seed) {
    final (earth, floor) = switch (game.map.theme) {
      MapTheme.grass => (const Color(0xFF5C4A2E), const Color(0xFF6E5A38)),
      MapTheme.scorched => (const Color(0xFF3A2A1E), const Color(0xFF4E3A28)),
      MapTheme.snow => (const Color(0xFF6E5C42), const Color(0xFF84704E)),
    };
    // Kazılmış çukur tabanı (pürüzlü bant).
    c.drawPath(_bandPath(a, dir, normal, len, half + 2, seed, 4),
        Paint()..color = earth);
    c.drawPath(_bandPath(a, dir, normal, len, half * 0.6, seed + 3, 3),
        Paint()..color = floor);
    // Patika izleri: geçit boyunca ayak izi benekleri.
    for (var d = 6.0; d < len; d += 11) {
      final wob = math.sin(d * 1.3 + seed) * half * 0.3;
      final p = a + dir * d + normal * wob;
      c.drawOval(
        Rect.fromCenter(
            center: Offset(p.x, p.y), width: 4.5, height: 2.6),
        Paint()..color = const Color(0x33241A0E),
      );
    }
    // İki yana itilmiş moloz yığınları (kazının kanıtı).
    for (final side in const [-1.0, 1.0]) {
      for (var d = 10.0; d < len; d += 17) {
        final p = a +
            dir * (d + math.sin(d + seed) * 3) +
            normal * ((half + 6 + math.sin(d * 0.7 + seed) * 2.5) * side);
        c.drawPath(
          _blob(Offset(p.x, p.y), 3.4 + (d.toInt() % 3),
              seed + d.toInt() + (side > 0 ? 7 : 0),
              points: 7, jitter: 0.3),
          Paint()..color = const Color(0xFF77705F),
        );
      }
    }
  }

  /// Hat boyunca İKİ KENARI DA pürüzlü kapalı bant.
  Path _bandPath(Vector2 a, Vector2 dir, Vector2 normal, double len,
      double half, int seed, double jitter) {
    final path = Path();
    const step = 9.0;
    for (var d = -half * 0.7; d <= len + half * 0.7; d += step) {
      final w = half +
          math.sin(d * 0.31 + seed) * jitter +
          math.sin(d * 0.73 + seed * 1.7) * jitter * 0.6;
      // Uçlarda yuvarlanma: bant kapsül gibi kapanır.
      final endT = math.min(1.0,
          math.min((d + half * 0.7) / (half * 0.7), (len + half * 0.7 - d) / (half * 0.7)));
      final p = a + dir * d + normal * (w * math.sqrt(endT.clamp(0.0, 1.0)));
      if (d == -half * 0.7) {
        path.moveTo(p.x, p.y);
      } else {
        path.lineTo(p.x, p.y);
      }
    }
    for (var d = len + half * 0.7; d >= -half * 0.7; d -= step) {
      final w = half +
          math.sin(d * 0.27 + seed * 2.3) * jitter +
          math.sin(d * 0.61 + seed) * jitter * 0.5;
      final endT = math.min(1.0,
          math.min((d + half * 0.7) / (half * 0.7), (len + half * 0.7 - d) / (half * 0.7)));
      final p = a + dir * d - normal * (w * math.sqrt(endT.clamp(0.0, 1.0)));
      path.lineTo(p.x, p.y);
    }
    return path..close();
  }

  Path _blob(Offset center, double radius, int seed,
      {int points = 10, double jitter = 0.2}) {
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final ang = i / points * 2 * math.pi;
      final wob = math.sin(ang * 3 + seed) * jitter +
          math.sin(ang * 5 + seed * 1.7) * jitter * 0.5;
      final r = radius * (1 + wob);
      final x = center.dx + math.cos(ang) * r;
      final y = center.dy + math.sin(ang) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }
}

/// NÖTR YABAN ARISI YUVASI: kâğıt dokulu organik kovan; çevresinde devriye
/// gezen arılar menzile giren HER askeri (takım ayırmadan) sokar.
/// Alan baskısı yaratır: "buradan geçme" — geçersen bedelini ödersin.
class WaspNestComponent extends Component
    with HasGameReference<AntsWarsGame> {
  WaspNestComponent(
      {required this.feature, required this.position, required this.radius})
      : super(priority: 8);

  final TerrainFeature feature;
  final Vector2 position;

  /// Yuvanın gövde yarıçapı (feature.width/2).
  final double radius;

  /// KOVAN YIKILABİLİR: dibine yığılan ordu kemirir; can bitince kovan
  /// çöker, arılar susar ve engel KALICI olarak açılır.
  double hp = kWaspNestHp;
  bool destroyed = false;

  double _time = 0;
  double _stingTimer = 0;
  double _chewTimer = 0;
  double _hitFlash = 0;

  /// Son sokma: hedef konumu + görsel süre (dalış çizgisi için).
  Vector2? _stingAt;
  double _stingFlash = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (destroyed) return;
    if (_stingFlash > 0) _stingFlash -= dt;
    if (_hitFlash > 0) _hitFlash -= dt;
    if (game.countdown > 0) return;
    // LAN istemcisi kovanı simüle etmez: can/yıkım host yayınından gelir.
    if (game.isNetClient) return;

    // KEMİRME: kovanın dibindeki (her takımdan) askerler ona hasar verir.
    _chewTimer -= dt;
    if (_chewTimer <= 0) {
      _chewTimer = 0.5;
      var dps = 0.0;
      game.spatialGrid.forEachNear(position, radius + 32, (u) {
        if (u.dead || u.spawnDelay > 0) return;
        dps += u.spec.damage;
      });
      if (dps > 0) {
        hp -= dps * 0.5;
        _hitFlash = 0.25;
        if (hp <= 0) {
          destroyed = true;
          game.clearFeature(feature); // enkazın üstünden yürünür
          if (game.fog.isVisible(position)) AudioController.capture();
          return;
        }
      }
    }

    _stingTimer -= dt;
    if (_stingTimer > 0) return;
    _stingTimer = kWaspCooldown;

    // Menzildeki EN YAKIN asker sokulur — takım fark etmez.
    var bestD = kWaspRange * kWaspRange;
    UnitComponent? victim;
    game.spatialGrid.forEachNear(position, kWaspRange, (u) {
      if (u.dead || u.spawnDelay > 0) return;
      final d = u.position.distanceToSquared(position);
      if (d < bestD) {
        bestD = d;
        victim = u;
      }
    });
    final v = victim;
    if (v == null) return;
    v.takeDamage(kWaspDamage);
    _stingAt = v.position.clone();
    _stingFlash = 0.35;
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(position.x, position.y);

    if (destroyed) {
      // ENKAZ: ezilmiş kovan parçaları — kalıcı iz, üstünden yürünür.
      canvas.drawPath(_blob(c.translate(0, 3), radius * 0.95, 7, jitter: 0.3),
          Paint()..color = const Color(0x66594E3C));
      for (var i = 0; i < 5; i++) {
        final a = i * 1.3 + 0.6;
        canvas.drawPath(
          _blob(c.translate(math.cos(a) * radius * 0.6,
                  math.sin(a) * radius * 0.45), 5 + (i % 3) * 2.0, i * 3,
              points: 7, jitter: 0.3),
          Paint()..color = const Color(0xFF9C8E76),
        );
      }
      return;
    }

    // Tehlike bölgesi: çok silik, nefes alan organik hale (göze batmaz).
    final auraR = kWaspRange * (0.96 + math.sin(_time * 1.4) * 0.03);
    canvas.drawPath(
      _blob(c, auraR, 11, points: 18, jitter: 0.06),
      Paint()..color = const Color(0xFFE8B33C).withValues(alpha: 0.045),
    );

    // Zemin gölgesi + çalı yatağı (yuva bir kütüğün üstünde durur).
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(3, radius * 0.5),
          width: radius * 2.4,
          height: radius * 1.1),
      Paint()..color = const Color(0x4D241A0E),
    );
    canvas.drawPath(_blob(c.translate(0, 4), radius * 0.9, 7, jitter: 0.22),
        Paint()..color = const Color(0xFF4A3A20));

    // Kâğıt kovan: üst üste organik katmanlar (gri-bej girdap dokusu).
    final layers = [
      (radius * 0.92, const Color(0xFF9C8E76), 3),
      (radius * 0.74, const Color(0xFFB0A288), 6),
      (radius * 0.55, const Color(0xFFC2B396), 9),
      (radius * 0.36, const Color(0xFFB0A288), 12),
    ];
    for (final (r, color, seed) in layers) {
      canvas.drawPath(
          _blob(c.translate(0, -radius * 0.15), r, seed,
              points: 11, jitter: 0.14),
          Paint()..color = color);
    }
    // Girdap çizgileri (kâğıt dokusu).
    final swirl = Paint()
      ..color = const Color(0x59736550)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(
            center: c.translate(0, -radius * 0.15),
            radius: radius * (0.3 + i * 0.22)),
        0.4 + i * 0.9,
        2.6,
        false,
        swirl,
      );
    }
    // HASAR: can azaldıkça koyulaşan çatlaklar + vuruş titremesi.
    final dmg = 1 - (hp / kWaspNestHp).clamp(0.0, 1.0);
    if (dmg > 0.15) {
      final crack = Paint()
        ..color = const Color(0xFF4A3A20).withValues(alpha: 0.3 + dmg * 0.6)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final n = (dmg * 5).ceil();
      for (var i = 0; i < n; i++) {
        var px = c.dx + math.sin(i * 2.6) * radius * 0.3;
        var py = c.dy - radius * 0.15 + math.cos(i * 1.9) * radius * 0.3;
        for (var sgm = 0; sgm < 2; sgm++) {
          final nx = px + math.sin(i * 3.1 + sgm * 2.2) * 9;
          final ny = py + 6 + sgm * 5;
          canvas.drawLine(Offset(px, py), Offset(nx, ny), crack);
          px = nx;
          py = ny;
        }
      }
    }
    if (_hitFlash > 0) {
      canvas.drawPath(
        _blob(c.translate(0, -radius * 0.15), radius * 0.95, 3,
            points: 11, jitter: 0.14),
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: 0.25 * (_hitFlash / 0.25)),
      );
    }
    // Kemirilirken minik CAN YAYI (yalnız hasarlıyken görünür).
    if (dmg > 0.02) {
      canvas.drawArc(
        Rect.fromCircle(center: c.translate(0, -radius * 0.15), radius: radius + 8),
        -math.pi / 2,
        2 * math.pi * (1 - dmg),
        false,
        Paint()
          ..color = const Color(0xFFE8B33C).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Giriş deliği (altta) + çevresinde nöbetçi arılar.
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, radius * 0.32),
          width: radius * 0.42,
          height: radius * 0.34),
      Paint()..color = const Color(0xFF241A0E),
    );

    // Devriye arıları: ikisi yuva çevresinde, ikisi geniş alanda dolaşır.
    for (var i = 0; i < 4; i++) {
      final wide = i >= 2;
      final orbitR = wide
          ? kWaspRange * (0.45 + 0.28 * math.sin(_time * 0.7 + i * 2.4))
          : radius * (1.15 + 0.25 * math.sin(_time * 2.1 + i));
      final ang = _time * (wide ? 0.9 : 1.7) * (i.isEven ? 1 : -1) + i * 1.9;
      final wx = c.dx + math.cos(ang) * orbitR;
      final wy = c.dy - radius * 0.15 + math.sin(ang) * orbitR * 0.72;
      _drawWasp(canvas, Offset(wx, wy), ang + (i.isEven ? 1.57 : -1.57));
    }

    // Sokma dalışı: kovandan hedefe hızlı sarı iz.
    final sting = _stingAt;
    if (sting != null && _stingFlash > 0) {
      final t = 1 - (_stingFlash / 0.35);
      final from = c.translate(0, -radius * 0.15);
      final to = Offset(sting.x, sting.y);
      final head = Offset.lerp(from, to, (t * 1.6).clamp(0.0, 1.0))!;
      final tail = Offset.lerp(from, to, (t * 1.6 - 0.3).clamp(0.0, 1.0))!;
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..color = const Color(0xFFE8B33C)
              .withValues(alpha: 0.7 * (_stingFlash / 0.35))
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      _drawWasp(canvas, head, math.atan2(to.dy - from.dy, to.dx - from.dx));
    }
  }

  /// Minik yaban arısı: sarı-siyah çizgili gövde + titreşen şeffaf kanatlar.
  void _drawWasp(Canvas canvas, Offset at, double heading) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(heading);
    // Kanat titreşimi.
    final flap = math.sin(_time * 40) * 0.6;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-0.5, side * (2.6 + flap)),
            width: 4.6,
            height: 2.2),
        Paint()..color = const Color(0x66FFFFFF),
      );
    }
    // Gövde: baş + çizgili karın.
    canvas.drawCircle(
        const Offset(2.4, 0), 1.3, Paint()..color = const Color(0xFF2E2418));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, 0), width: 5.4, height: 3),
      Paint()..color = const Color(0xFFE8B33C),
    );
    final stripe = Paint()
      ..color = const Color(0xFF2E2418)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(-0.6, -1.4), const Offset(-0.6, 1.4), stripe);
    canvas.drawLine(const Offset(-2.2, -1.2), const Offset(-2.2, 1.2), stripe);
    canvas.restore();
  }

  Path _blob(Offset center, double radius, int seed,
      {int points = 12, double jitter = 0.16}) {
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * math.pi;
      final wob = math.sin(a * 3 + seed) * jitter +
          math.sin(a * 5 + seed * 1.7) * jitter * 0.5;
      final r = radius * (1 + wob);
      final x = center.dx + math.cos(a) * r;
      final y = center.dy + math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }
}
