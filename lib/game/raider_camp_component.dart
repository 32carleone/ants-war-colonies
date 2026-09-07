import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../data/units.dart';
import '../models/player.dart';
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'unit_component.dart';

/// YAĞMACI KAMPI: haritadaki NÖTR paralı asker kampı. Çevresinde (70px)
/// asker çoğunluğu kuran taraf doluş halkasını doldurur; halka dolunca
/// kampın 5 yağmacısı (2 ateş, 1 orman, 1 kapan, 1 kesici) DOLDURANIN
/// ordusuna katılır. Kamp ~75 sn söner, sonra yeniden pazarlığa açılır —
/// tekrar tekrar alınabilir bir harita ödülüdür.
class RaiderCampComponent extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  RaiderCampComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center, priority: -2);

  static const double baseTime = 8; // 1 net askerle doluş (sn)
  static const double cooldownAfter = 75;
  static const List<UnitType> reward = [
    UnitType.fire,
    UnitType.fire,
    UnitType.wood,
    UnitType.trapjaw,
    UnitType.leafcutter,
  ];

  /// Doluş (0..1) ve dolduran taraf (takım + halka rengi için lider).
  double progress = 0;
  int? capturingTeam;
  Player? capturingLeader;

  /// Ödül verildikten sonra sönme süresi (0 = aktif).
  double cooldown = 0;

  double _time = 0;
  double _scanTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (game.isNetClient) return; // istemci: durum yayınından senkron
    if (cooldown > 0) {
      cooldown -= dt;
      if (cooldown <= 0) {
        progress = 0;
        capturingTeam = null;
        capturingLeader = null;
      }
      return;
    }
    _scanTimer -= dt;
    if (_scanTimer > 0) return;
    final tick = 0.25 - _scanTimer;
    _scanTimer = 0.25;

    // Çevredeki asker sayımı (takım bazında + takım lideri).
    final counts = <int, int>{};
    final leaders = <int, Player>{};
    final leaderCounts = <int, Map<int, int>>{};
    var total = 0;
    game.spatialGrid.forEachNear(position, kCaptureRadius, (u) {
      if (u.dead || u.spawnDelay > 0) return;
      if (u.owner.eliminated) return; // yabaniler kamp tutamaz
      final team = u.combatTeam;
      total++;
      counts.update(team, (c) => c + 1, ifAbsent: () => 1);
      final byPlayer = leaderCounts.putIfAbsent(team, () => {});
      final n =
          byPlayer.update(u.owner.id, (c) => c + 1, ifAbsent: () => 1);
      final lead = leaders[team];
      if (lead == null || n > (byPlayer[lead.id] ?? 0)) {
        leaders[team] = u.owner;
      }
    });
    int? domTeam;
    var domCount = 0;
    counts.forEach((team, c) {
      if (c > domCount) {
        domCount = c;
        domTeam = team;
      }
    });
    final net = domCount - (total - domCount);
    if (domTeam == null || net <= 0) {
      progress = (progress - tick / 4).clamp(0.0, 1.0);
      if (progress == 0) capturingTeam = null;
      return;
    }
    if (capturingTeam != domTeam) {
      progress = (progress - tick / 4).clamp(0.0, 1.0);
      if (progress == 0) {
        capturingTeam = domTeam;
        capturingLeader = leaders[domTeam];
      }
      return;
    }
    capturingLeader = leaders[domTeam] ?? capturingLeader;
    progress += tick * math.sqrt(net.clamp(1, 25).toDouble()) / baseTime;
    if (progress >= 1) _grantReward();
  }

  void _grantReward() {
    final owner = capturingLeader;
    progress = 0;
    cooldown = cooldownAfter;
    if (owner == null) return;
    var i = 0;
    for (final type in reward) {
      final angle = i * 2 * math.pi / reward.length;
      final pos = game.grid.nearestOpen(position +
          Vector2(math.cos(angle), math.sin(angle)) * 26);
      final unit = UnitComponent(
        type: type,
        owner: owner,
        position: pos,
        spawnDelay: i * 0.15,
      );
      game.units.add(unit);
      game.world.add(unit);
      i++;
    }
    if (owner == game.gameState.humanPlayer) {
      AudioController.produce();
    }
    capturingTeam = null;
    capturingLeader = null;
  }

  @override
  void render(Canvas canvas) {
    final dormant = cooldown > 0;
    final alpha = dormant ? 0.55 : 1.0;
    // Kamp zemini: çiğnenmiş toprak öbeği.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 74, height: 52),
      Paint()..color = const Color(0xFF57472E).withValues(alpha: 0.85 * alpha),
    );
    // İki yağmacı çadırı (koyu deri üçgenler).
    void tent(Offset at, double w, double h, Color c) {
      final p = Path()
        ..moveTo(at.dx - w / 2, at.dy + h / 2)
        ..lineTo(at.dx, at.dy - h / 2)
        ..lineTo(at.dx + w / 2, at.dy + h / 2)
        ..close();
      canvas.drawPath(p, Paint()..color = c.withValues(alpha: alpha));
      canvas.drawLine(
          at.translate(0, -h / 2),
          at.translate(0, h / 2),
          Paint()
            ..color = const Color(0x66000000)
            ..strokeWidth = 1.4);
    }

    tent(const Offset(-14, -4), 24, 20, const Color(0xFF6B4A32));
    tent(const Offset(13, 2), 20, 17, const Color(0xFF5C4326));
    // Kamp ateşi: sönükken kül, aktifken titreyen kor.
    final fireAt = const Offset(-1, 13);
    if (dormant) {
      canvas.drawCircle(fireAt, 4,
          Paint()..color = const Color(0xFF6E685C).withValues(alpha: 0.7));
    } else {
      final flick = 0.75 + math.sin(_time * 9) * 0.25;
      canvas.drawCircle(
          fireAt, 6.5, Paint()..color = const Color(0x33F6C044));
      canvas.drawCircle(fireAt, 3.2,
          Paint()..color = const Color(0xFFF6C044).withValues(alpha: flick));
      canvas.drawCircle(fireAt.translate(0, -1.5), 1.6,
          Paint()..color = const Color(0xFFFFE9B0).withValues(alpha: flick));
    }
    // Yağmacı bayrağı: yırtık koyu flama.
    canvas.drawLine(
        const Offset(24, -22),
        const Offset(24, -2),
        Paint()
          ..color = const Color(0xFF4A3A20)
          ..strokeWidth = 2);
    final flag = Path()
      ..moveTo(24, -22)
      ..lineTo(38, -18)
      ..lineTo(31, -15)
      ..lineTo(38, -12)
      ..lineTo(24, -9)
      ..close();
    canvas.drawPath(flag,
        Paint()..color = const Color(0xFF7A2F23).withValues(alpha: alpha));

    // DOLUŞ HALKASI: dolduran oyuncunun renginde (binalarla aynı dil).
    if (!dormant && progress > 0) {
      final ringColor = capturingLeader?.color ?? kNeutralColor;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 34),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }
    // Sönükken kalan süre kıvılcımı: ince soluk halka geri dolar.
    if (dormant) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 34),
        -math.pi / 2,
        2 * math.pi * (1 - cooldown / cooldownAfter).clamp(0.0, 1.0),
        false,
        Paint()
          ..color = const Color(0x59FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }
}
