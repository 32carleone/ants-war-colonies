import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'unit_component.dart';

/// YAĞMACI AKREP — nötr canavar: yuvasının çevresinde devriye gezer,
/// menziline giren HER askere (takım ayırmadan) kıskaç atar. Arı kovanının
/// hareketli abisidir: canı yüksektir ama YIKILIR — son darbeyi vuran
/// oyuncu ALTIN ÖDÜLÜ alır. Bir süre sonra yeni bir akrep aynı bölgeye
/// yerleşir (tekrarlanan harita hedefi).
class ScorpionComponent extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  ScorpionComponent({required Vector2 home})
      : home = home.clone(),
        super(
          position: home.clone(),
          anchor: Anchor.center,
          size: Vector2.all(64),
          priority: 18,
        );

  /// Devriye merkezi (akrep buradan fazla uzaklaşmaz).
  final Vector2 home;

  static const double maxHp = 500;
  static const double leash = 150; // evden azami uzaklık
  static const double wanderRadius = 110;
  static const double attackRange = 90; // kıskaç menzili (hedef seçimi)
  static const double meleeRange = 34; // vuruş mesafesi
  static const double attackDamage = 18;
  static const double attackEvery = 1.1;
  static const double chewRadius = 40; // askerler bu mesafeden kemirir
  static const double moveSpeed = 34;
  static const int bounty = 150; // öldürene altın
  static const double respawnAfter = 6; // leş solma süresi (sn) — DİRİLMEZ

  double hp = maxHp;
  bool get alive => hp > 0;
  double respawnLeft = 0;

  double _time = 0;
  double _attackCooldown = 0;
  double _chewTimer = 0;
  double _hitFlash = 0;
  double _wanderTimer = 0;
  Vector2? _wanderTo;
  double facing = 0;
  double _walkPhase = 0;

  /// Sokma görseli (kuyruk saplanışı).
  Vector2? _stingAt;
  double _stingFlash = 0;

  /// Son kemiren oyuncular (ödül son darbeyi vurana gider).
  int? _lastChewer;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_hitFlash > 0) _hitFlash -= dt;
    if (_stingFlash > 0) _stingFlash -= dt;

    // LAN İSTEMCİSİ: simülasyon yok — konum/can host yayınından gelir,
    // burada yalnız görsel zaman ilerler (yumuşak yaklaşım netSync'te).
    if (game.isNetClient) {
      _clientLerp(dt);
      return;
    }
    if (game.countdown > 0) return;

    // ÖLÜYSE: akrep GERİ GELMEZ — leşi kısa süre solup kaybolur
    // (harita ödülü tek seferliktir; bölge kalıcı güvene düşer).
    if (!alive) {
      if (respawnLeft > 0) respawnLeft -= dt; // leş solma sayacı
      return;
    }

    _attackCooldown -= dt;

    // KEMİRME: dibine yığılan askerler (her takımdan) akrebi keser.
    _chewTimer -= dt;
    if (_chewTimer <= 0) {
      _chewTimer = 0.5;
      var dps = 0.0;
      UnitComponent? closest;
      var closestD = double.infinity;
      game.spatialGrid.forEachNear(position, chewRadius, (u) {
        if (u.dead || u.spawnDelay > 0) return;
        dps += u.spec.damage;
        final d = u.position.distanceToSquared(position);
        if (d < closestD) {
          closestD = d;
          closest = u;
        }
      });
      if (dps > 0) {
        hp -= dps * 0.5;
        _hitFlash = 0.25;
        _lastChewer = closest?.owner.id;
        if (hp <= 0) {
          _die();
          return;
        }
      }
    }

    // HEDEF: menzildeki en yakın asker — kovala ve sok.
    UnitComponent? victim;
    var bestD = attackRange * attackRange;
    game.spatialGrid.forEachNear(position, attackRange, (u) {
      if (u.dead || u.spawnDelay > 0) return;
      final d = u.position.distanceToSquared(position);
      if (d < bestD) {
        bestD = d;
        victim = u;
      }
    });

    final v = victim;
    if (v != null) {
      _faceTowards(v.position, dt);
      final dist = math.sqrt(bestD);
      if (dist > meleeRange) {
        _step(v.position, dt);
      } else if (_attackCooldown <= 0) {
        _attackCooldown = attackEvery;
        v.takeDamage(attackDamage);
        _stingAt = v.position.clone();
        _stingFlash = 0.3;
      }
      return;
    }

    // DEVRİYE: ev çevresinde ağır ağır gezinir.
    _wanderTimer -= dt;
    if (_wanderTimer <= 0 || _wanderTo == null) {
      _wanderTimer = 2.5 + game.rng.nextDouble() * 3;
      final a = game.rng.nextDouble() * 2 * math.pi;
      final r = game.rng.nextDouble() * wanderRadius;
      _wanderTo = game.grid.nearestOpen(
          home + Vector2(math.cos(a) * r, math.sin(a) * r));
    }
    final to = _wanderTo!;
    if (position.distanceToSquared(to) > 12 * 12) {
      _faceTowards(to, dt);
      _step(to, dt);
    }
  }

  void _die() {
    hp = 0;
    respawnLeft = respawnAfter;
    // ÖDÜL: son darbeyi vuran oyuncuya altın (bot da kazanabilir).
    final id = _lastChewer;
    if (id != null) {
      for (final p in game.gameState.players) {
        if (p.id != id || p.eliminated) continue;
        p.resources += bounty;
        p.goldEarned += bounty;
        if (p.id == game.gameState.humanPlayer?.id) {
          game.registerGain(bounty);
        }
      }
    }
    if (game.fog.isVisible(position)) AudioController.capture();
    game.netHost?.broadcastScorpionDeath(this);
  }

  void _step(Vector2 toward, double dt) {
    final delta = toward - position;
    final dist = delta.length;
    if (dist < 0.5) return;
    // Tasma: evden fazla uzaklaşma.
    final next = position + delta / dist * (moveSpeed * dt);
    if (next.distanceToSquared(home) > leash * leash) return;
    if (game.grid.isBlockedAt(next)) return;
    position.setFrom(next);
    _walkPhase += moveSpeed * dt * 0.35;
  }

  void _faceTowards(Vector2 p, double dt) {
    final targetAngle = math.atan2(p.y - position.y, p.x - position.x);
    var diff = (targetAngle - facing) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;
    facing += diff.clamp(-5 * dt, 5 * dt);
  }

  // ---- LAN istemci senkronu ----
  Vector2? netTarget;

  void netSync(double x, double y, double newHp, double respawn) {
    (netTarget ??= Vector2.zero()).setValues(x, y);
    if (newHp < hp) _hitFlash = 0.25;
    hp = newHp;
    respawnLeft = respawn;
  }

  void _clientLerp(double dt) {
    final t = netTarget;
    if (t == null) return;
    final dx = t.x - position.x, dy = t.y - position.y;
    final d2 = dx * dx + dy * dy;
    if (d2 > 120 * 120) {
      position.setValues(t.x, t.y);
      return;
    }
    if (d2 < 0.5) return;
    final k = math.min(1.0, dt * 8);
    position.x += dx * k;
    position.y += dy * k;
    _walkPhase += math.sqrt(d2) * k * 0.35;
    _faceTowards(t, dt);
  }

  // ------------------------------------------------------------- çizim

  @override
  void render(Canvas canvas) {
    if (!game.fog.isVisible(position)) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    if (!alive) {
      _renderCarcass(canvas);
      canvas.restore();
      return;
    }

    // Tehlike halesi (çok silik, nefes alır).
    canvas.drawCircle(
      Offset.zero,
      attackRange * (0.95 + math.sin(_time * 1.3) * 0.04),
      Paint()..color = const Color(0xFFB0553A).withValues(alpha: 0.05),
    );
    // Gölge.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 3), width: 44, height: 18),
      Paint()..color = const Color(0x40000000),
    );

    canvas.rotate(facing);
    _renderBody(canvas);
    canvas.restore();

    // Can yayı (yalnız hasarlıyken, kovanla aynı dil).
    final dmg = 1 - (hp / maxHp).clamp(0.0, 1.0);
    if (dmg > 0.02) {
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.x / 2, size.y / 2), radius: 30),
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

    // Sokma izi: kuyruktan hedefe kızıl çizgi.
    final sting = _stingAt;
    if (sting != null && _stingFlash > 0) {
      final from = Offset(size.x / 2, size.y / 2);
      final to = Offset(
          sting.x - position.x + size.x / 2,
          sting.y - position.y + size.y / 2);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = const Color(0xFFB0553A)
              .withValues(alpha: 0.7 * (_stingFlash / 0.3))
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Akrep gövdesi: kalkan sırtlı gövde + kıskaçlar + kıvrık iğneli kuyruk.
  /// Tema dili: organik, pürüzlü; koyu kızıl-amber (nötr canavar rengi).
  void _renderBody(Canvas canvas) {
    const body = Color(0xFF7A4A30);
    const dark = Color(0xFF5C3622);
    const lite = Color(0xFF96613E);
    final legPaint = Paint()
      ..color = dark
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Bacaklar (4 çift, yürüyüşle salınır).
    for (final side in const [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final ax = 8.0 - i * 6.5;
        final swing =
            math.sin(_walkPhase + i * 1.7 + (side > 0 ? 0 : math.pi)) * 3;
        canvas.drawLine(
          Offset(ax, side * 6),
          Offset(ax + swing, side * 15),
          legPaint,
        );
      }
    }

    // Kıskaç kolları + kıskaçlar (önde, hafif açılıp kapanır).
    final pinch = math.sin(_time * 3) * 0.15;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(
          Offset(12, side * 5), Offset(20, side * 12), legPaint);
      canvas.save();
      canvas.translate(21, side * 13);
      canvas.rotate(side * (0.5 + pinch));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: 11, height: 7),
          Paint()..color = body);
      // Kıskaç ağzı (V çentiği).
      canvas.drawPath(
        Path()
          ..moveTo(4, -1.5)
          ..lineTo(8, side * -3.0)
          ..lineTo(5, 1.5)
          ..close(),
        Paint()..color = dark,
      );
      canvas.restore();
    }

    // Gövde: segmentli sırt (arkadan öne büyüyen ovaller).
    for (var i = 0; i < 4; i++) {
      final w = 22.0 - i * 3;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(4.0 - i * 6.5, 0), width: w, height: w * 0.62),
        Paint()..color = i.isEven ? body : lite,
      );
    }
    // Sırt deseni.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(2, 0), width: 12, height: 6),
      Paint()..color = dark,
    );

    // Kuyruk: geriye kıvrılan segmentler + iğne (saldırırken kalkar).
    final rise = _stingFlash > 0 ? 1.4 : math.sin(_time * 2) * 0.15 + 0.9;
    var tx = -16.0;
    var ty = 0.0;
    for (var i = 0; i < 4; i++) {
      tx -= 5.5;
      ty -= 2.2 * rise * (i + 1) / 2;
      canvas.drawCircle(
          Offset(tx, ty), 4.2 - i * 0.5, Paint()..color = dark);
    }
    // İğne.
    canvas.drawPath(
      Path()
        ..moveTo(tx - 2, ty - 2)
        ..lineTo(tx - 8, ty - 7 * rise)
        ..lineTo(tx + 1, ty - 4)
        ..close(),
      Paint()..color = const Color(0xFFB0553A),
    );

    // Vuruş parlaması.
    if (_hitFlash > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 46, height: 30),
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: 0.25 * (_hitFlash / 0.25)),
      );
    }
  }

  /// Leş: solmuş kabuk + dağılmış kıskaçlar (birkaç sn'de yiter).
  void _renderCarcass(Canvas canvas) {
    final fade = (respawnLeft / respawnAfter).clamp(0.0, 1.0) * 0.6;
    if (fade <= 0.01) return;
    final paint = Paint()
      ..color = const Color(0xFF5C4A3A).withValues(alpha: fade);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 34, height: 16),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-18, -2), width: 12, height: 7),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(16, 8), width: 10, height: 6),
      paint,
    );
  }
}
