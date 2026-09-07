import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../models/building.dart';
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'building_painter.dart';
import 'unit_component.dart';
import 'projectile.dart';

/// Haritadaki bir binanın bileşeni: türe/seviyeye/sahibe göre gerçekçi çizim,
/// ele geçirme halkası ve kule saldırı davranışı.
class BuildingComponent extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  BuildingComponent({required this.building})
      : super(
          position: building.position.clone(),
          anchor: Anchor.center,
          size: Vector2.all(90),
          // Karıncaların ALTINDA kalır (askerler bina önünden geçer;
          // eskiden 8'di ve ordu bina gövdesinin arkasında kayboluyordu).
          priority: -2,
        );

  final Building building;

  double _towerCooldown = 0;
  double _time = 0;

  Offset get _center => Offset(size.x / 2, size.y / 2);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    // Kule NÖTRKEN DE ateş eder (herkese düşman) — almak kolay olmasın.
    // LAN istemcisinde kule simüle edilmez (hasar host'ta işler).
    if (building.type == BuildingType.tower && !game.isNetClient) {
      _updateTower(dt);
    }
  }

  void _updateTower(double dt) {
    _towerCooldown -= dt;
    if (_towerCooldown > 0) return;
    // Seviye = mermi sayısı: sv2 iki, sv3 üç FARKLI hedefe aynı anda atar
    // (seviye ayrıca menzil, hasar ve atış hızı getirir).
    final ownerTeam = building.owner?.team; // null = nötr: herkes hedef
    final rangeSq = building.towerRange * building.towerRange;
    final candidates = <UnitComponent>[];
    game.spatialGrid.forEachNear(building.position, building.towerRange, (u) {
      if (u.dead || u.combatTeam == ownerTeam) return;
      if (u.position.distanceToSquared(building.position) < rangeSq) {
        candidates.add(u);
      }
    });
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.position
        .distanceToSquared(building.position)
        .compareTo(b.position.distanceToSquared(building.position)));

    _towerCooldown = building.towerCooldown;
    if (game.fog.isVisible(building.position)) AudioController.towerShot();
    final shots = math.min(building.towerShots, candidates.length);
    for (var i = 0; i < shots; i++) {
      game.world.add(Projectile(
        position: building.position + Vector2(0, -14),
        target: candidates[i],
        // Nötr garnizon eksik mürettebatla vurur (%60).
        damage: building.owner == null
            ? building.towerDamage * 0.6
            : building.towerDamage,
        color: const Color(0xFFC9B784), // fırlatılan çakıl
      ));
    }
  }

  /// Sahipli ve GÖRÜNÜR binalar gövdeleriyle takım rengine tonlanır —
  /// kimin binası olduğu bir bakışta okunur. Sis altında nötr görünür.
  Color? _tint;


  @override
  void render(Canvas canvas) {
    final seen = game.fog.isVisible(building.position);
    // Sahiplik (bayrak + gövde tonu) HER ZAMAN görünür — harita bilgisi.
    // Sis yalnızca CANLI bilgiyi (ele geçirme ilerlemesi) gizler.
    _tint = building.owner?.color;
    paintBuilding(
      canvas,
      building.type,
      center: _center,
      level: building.level,
      tint: _tint,
      time: _time,
      seed: (building.position.x + building.position.y).toInt() % 13,
    );
    _renderOwnership(canvas, seen);
  }

  // ------------------------------------------------------------- sahiplik

  void _renderOwnership(Canvas canvas, bool seen) {
    final c = _center;

    // Seviye noktaları (statik bilgi — her zaman görünür).
    for (var i = 0; i < building.level; i++) {
      canvas.drawCircle(
        Offset(c.dx - 8 + i * 8.0, size.y - 6),
        2.2,
        Paint()..color = _tint ?? kNeutralColor,
      );
    }

    if (!seen) return; // CANLI ele geçirme ilerlemesi sis altında gizli

    // Sadece ele geçirme sırasında görünen İNCE doluş halkası.
    if (building.captureProgress > 0 && building.capturingPlayer != null) {
      canvas.drawCircle(
        c,
        34,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 34),
        -math.pi / 2,
        2 * math.pi * building.captureProgress,
        false,
        Paint()
          ..color = building.capturingPlayer!.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

  }

}
