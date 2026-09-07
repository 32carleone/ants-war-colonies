import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/units.dart';
import '../models/player.dart';
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'unit_component.dart';

/// Bir yeteneği uygular (insan veya bot fark etmez — PART-10 botları da
/// bu fonksiyonu çağırır). Hedef gerekliliği/cooldown kontrolü çağırana aittir.
void castAbility(
  AntsWarsGame game,
  Player caster,
  AbilityType type,
  Vector2? target,
) {
  // LAN HOST: görsel/işitsel efekt istemcilerde de patlasın diye yayınla.
  game.netHost?.broadcastFx(type, target, caster.team);
  final spec = abilitySpecs[type]!;
  switch (type) {
    case AbilityType.lightning:
      final t = target!;
      final rSq = spec.radius * spec.radius;
      // Denge: 40 hasar — Ateş Karıncalarını siler, orta sınıfı ağır
      // yaralar ama tek vuruşta orduyu silmez (eskiden 60'tı, çok güçlüydü).
      for (final u in List.of(game.units)) {
        if (!u.dead && u.position.distanceToSquared(t) <= rSq) {
          u.takeDamage(40);
        }
      }
      for (final nest in game.nests.values) {
        if (!nest.destroyed &&
            nest.position.distanceToSquared(t) <= rSq) {
          nest.receiveAttack(40);
        }
      }
      AudioController.lightning();
      game.world.add(LightningFx(position: t.clone()));

    case AbilityType.reinforce:
    case AbilityType.summonWood:
    case AbilityType.summonLeaf:
      AudioController.abilityCast();
      final t = target!;
      // Çağrı yetenekleri: tür/kadro yeteneğe göre (denge: ucuz asker
      // kalabalık, tank az gelir).
      final (unitType, count) = switch (type) {
        AbilityType.summonWood => (UnitType.wood, 9),
        AbilityType.summonLeaf => (UnitType.leafcutter, 6),
        _ => (UnitType.fire, 12),
      };
      for (var i = 0; i < count; i++) {
        final angle = i * 2 * math.pi / count;
        // İki halka: kalabalık kadrolar üst üste binmesin.
        final ring = i.isEven ? 22.0 : 34.0;
        final pos = game.grid.nearestOpen(
            t + Vector2(math.cos(angle), math.sin(angle)) * ring);
        final unit = UnitComponent(
          type: unitType,
          owner: caster,
          position: pos,
          spawnDelay: i * 0.1,
        );
        game.units.add(unit);
        game.world.add(unit);
      }
      game.world.add(AreaPulseFx(
        position: t.clone(),
        maxRadius: spec.radius,
        color: caster.color,
      ));

    case AbilityType.speedPheromone:
      AudioController.abilityCast();
      _buffOwnUnits(game, caster, target!, spec.radius,
          (u) => u.applySpeedBuff(1.5, spec.duration));
      game.world.add(AreaPulseFx(
        position: target.clone(),
        maxRadius: spec.radius,
        color: const Color(0xFF6FD6C0),
      ));

    case AbilityType.battleFrenzy:
      AudioController.abilityCast();
      _buffOwnUnits(game, caster, target!, spec.radius,
          (u) => u.applyDamageBuff(1.4, spec.duration));
      game.world.add(AreaPulseFx(
        position: target.clone(),
        maxRadius: spec.radius,
        color: const Color(0xFFE8683C),
      ));

    case AbilityType.heal:
      AudioController.abilityCast();
      _buffOwnUnits(game, caster, target!, spec.radius, (u) => u.healBy(40));
      game.world.add(AreaPulseFx(
        position: target.clone(),
        maxRadius: spec.radius,
        color: const Color(0xFF8BC34A),
      ));

    case AbilityType.rain:
      AudioController.startRain();
      for (final u in game.units) {
        if (!u.dead) u.applySpeedBuff(0.6, spec.duration);
      }
      game.world.add(RainFx(duration: spec.duration));

    case AbilityType.poisonCloud:
      AudioController.abilityCast();
      game.world.add(PoisonCloudFx(
        position: target!.clone(),
        radius: spec.radius,
        duration: spec.duration,
        casterTeam: caster.team,
      ));

    case AbilityType.fearScream:
      AudioController.abilityCast();
      final t = target!;
      final rSq = spec.radius * spec.radius;
      for (final u in List.of(game.units)) {
        if (!u.dead &&
            u.combatTeam != caster.team &&
            u.position.distanceToSquared(t) <= rSq) {
          u.applyFear(t, spec.duration);
        }
      }
      game.world.add(AreaPulseFx(
        position: t.clone(),
        maxRadius: spec.radius,
        color: const Color(0xFFB07CC6),
      ));

    case AbilityType.armorPheromone:
      AudioController.abilityCast();
      _buffOwnUnits(game, caster, target!, spec.radius,
          (u) => u.applyArmorBuff(0.6, spec.duration));
      game.world.add(AreaPulseFx(
        position: target.clone(),
        maxRadius: spec.radius,
        color: const Color(0xFF9BB8C9),
      ));

    case AbilityType.fireRing:
      AudioController.abilityCast();
      game.world.add(FireRingFx(
        position: target!.clone(),
        radius: spec.radius,
        duration: spec.duration,
        casterTeam: caster.team,
      ));

    case AbilityType.freeze:
      AudioController.abilityCast();
      game.world.add(FrostFieldFx(
        position: target!.clone(),
        radius: spec.radius,
        duration: spec.duration,
        casterTeam: caster.team,
      ));
  }
}

/// LAN İSTEMCİSİ: yeteneğin YALNIZ görsel/işitsel karşılığını basar —
/// hasar, buff, birim doğurma gibi oyun etkileri host'ta işler ve durum
/// yayınıyla gelir (alan efektlerinin hasar tikleri istemcide kapalıdır).
void spawnAbilityFxVisual(
  AntsWarsGame game,
  AbilityType type,
  Vector2? target,
  int casterTeam,
) {
  final spec = abilitySpecs[type]!;
  final t = target;
  if (!spec.global && t == null) return;
  switch (type) {
    case AbilityType.lightning:
      AudioController.lightning();
      game.world.add(LightningFx(position: t!.clone()));
    case AbilityType.reinforce:
    case AbilityType.summonWood:
    case AbilityType.summonLeaf:
      AudioController.abilityCast();
      // Askerler durum yayınıyla belirir; burada yalnız dalga görseli.
      final color = game.gameState.players
          .firstWhere((p) => p.team == casterTeam,
              orElse: () => game.gameState.players.first)
          .color;
      game.world.add(AreaPulseFx(
          position: t!.clone(), maxRadius: spec.radius, color: color));
    case AbilityType.speedPheromone:
      AudioController.abilityCast();
      game.world.add(AreaPulseFx(
          position: t!.clone(),
          maxRadius: spec.radius,
          color: const Color(0xFF6FD6C0)));
    case AbilityType.battleFrenzy:
      AudioController.abilityCast();
      game.world.add(AreaPulseFx(
          position: t!.clone(),
          maxRadius: spec.radius,
          color: const Color(0xFFE8683C)));
    case AbilityType.heal:
      AudioController.abilityCast();
      game.world.add(AreaPulseFx(
          position: t!.clone(),
          maxRadius: spec.radius,
          color: const Color(0xFF8BC34A)));
    case AbilityType.rain:
      AudioController.startRain();
      game.world.add(RainFx(duration: spec.duration));
    case AbilityType.poisonCloud:
      AudioController.abilityCast();
      game.world.add(PoisonCloudFx(
          position: t!.clone(),
          radius: spec.radius,
          duration: spec.duration,
          casterTeam: casterTeam));
    case AbilityType.fearScream:
      AudioController.abilityCast();
      game.world.add(AreaPulseFx(
          position: t!.clone(),
          maxRadius: spec.radius,
          color: const Color(0xFFB07CC6)));
    case AbilityType.armorPheromone:
      AudioController.abilityCast();
      game.world.add(AreaPulseFx(
          position: t!.clone(),
          maxRadius: spec.radius,
          color: const Color(0xFF9BB8C9)));
    case AbilityType.fireRing:
      AudioController.abilityCast();
      game.world.add(FireRingFx(
          position: t!.clone(),
          radius: spec.radius,
          duration: spec.duration,
          casterTeam: casterTeam));
    case AbilityType.freeze:
      AudioController.abilityCast();
      game.world.add(FrostFieldFx(
          position: t!.clone(),
          radius: spec.radius,
          duration: spec.duration,
          casterTeam: casterTeam));
  }
}

/// ATEŞ ÇEMBERİ (yenilendi): işaretlenen alan BAŞTAN BAŞA ALEV —
/// içinde kalan düşmanlar sürekli yanar. Kenarlar kıvrımlıdır
/// (tam daire yok); zemin kavrulur, alevler titreşir, korlar yükselir.
class FireRingFx extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  FireRingFx({
    required Vector2 position,
    required this.radius,
    required this.duration,
    required this.casterTeam,
  }) : super(position: position, anchor: Anchor.center, priority: 54);

  final double radius;
  final double duration;
  final int casterTeam;

  static const _dps = 12.0;
  static const _tickEvery = 0.4;
  double _t = 0;
  double _tick = 0;
  late final int _seed = (position.x + position.y).toInt() % 23;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
      return;
    }
    _tick -= dt;
    if (_tick > 0) return;
    _tick = _tickEvery;
    if (game.isNetClient) return; // hasar host'ta işler
    final rSq = radius * radius;
    for (final u in List.of(game.units)) {
      if (u.dead || u.combatTeam == casterTeam) continue;
      if (u.position.distanceToSquared(position) <= rSq) {
        u.takeDamage(_dps * _tickEvery);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_t / 0.35).clamp(0.0, 1.0);
    final fadeOut = ((duration - _t) / 0.6).clamp(0.0, 1.0);
    final alpha = math.min(fadeIn, fadeOut);

    // Kavrulan zemin (alanın tamamı) + kor tabanı — kıvrımlı kenarlar.
    canvas.drawPath(wavyCircle(radius + 4, _seed, t: _t),
        Paint()..color = const Color(0xFF2A1810).withValues(alpha: 0.45 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.94, _seed + 3, t: _t),
        Paint()..color = const Color(0xFF8A2E12).withValues(alpha: 0.40 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.72, _seed + 7, t: _t * 1.3),
        Paint()..color = const Color(0xFFC94A1C).withValues(alpha: 0.38 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.45, _seed + 11, t: _t * 1.7),
        Paint()..color = const Color(0xFFE8683C).withValues(alpha: 0.34 * alpha));

    // Alanın İÇİNE dağılmış titreşen alevler (halka değil — her yer yanıyor).
    for (var i = 0; i < 30; i++) {
      final a = i * 2.399963 + _seed; // altın açı: doğal dağılım
      final d = radius * 0.92 * math.sqrt((i + 0.5) / 30);
      final flick = math.sin(_t * 9 + i * 2.3);
      final h = (7 + flick * 3.5) * (0.7 + d / radius * 0.5);
      final bx = math.cos(a) * d;
      final by = math.sin(a) * d;
      final flame = Path()
        ..moveTo(bx - 3.6, by + 2)
        ..lineTo(bx + math.sin(_t * 5 + i) * 2.5, by - h)
        ..lineTo(bx + 3.6, by + 2)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..color = Color.lerp(const Color(0xFFE8683C),
                  const Color(0xFFF6C044), (flick + 1) / 2)!
              .withValues(alpha: 0.85 * alpha),
      );
    }
    // Yükselen korlar.
    for (var i = 0; i < 10; i++) {
      final p = ((_t * (0.5 + (i % 3) * 0.2) + i / 10) % 1.0);
      final a = i * 1.9 + _seed;
      canvas.drawCircle(
        Offset(math.cos(a) * radius * 0.6 + math.sin(_t * 2 + i) * 6,
            math.sin(a) * radius * 0.5 - p * 26),
        1.6 * (1 - p) + 0.4,
        Paint()
          ..color = const Color(0xFFF6C044).withValues(alpha: 0.7 * (1 - p) * alpha),
      );
    }
  }
}

/// DONDURMA (yenilendi): işaretlenen zemin süre boyunca BUZ KESER —
/// üstünde kalan ve İÇİNE GİREN düşmanlar donar (alandan çıkan ~2 sn'de
/// çözülür). Kenarlar kıvrımlı buz tabakası; çatlaklar ve kristaller parlar.
class FrostFieldFx extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  FrostFieldFx({
    required Vector2 position,
    required this.radius,
    required this.duration,
    required this.casterTeam,
  }) : super(position: position, anchor: Anchor.center, priority: 54);

  final double radius;
  final double duration;
  final int casterTeam;

  /// Alan içindeki düşmana her tikte tazelenen donma süresi:
  /// alandayken hep donuk kalır, alan bitince en geç ~2 sn'de çözülür.
  static const _freezeHold = 2.0;
  static const _tickEvery = 0.3;
  double _t = 0;
  double _tick = 0;
  late final int _seed = (position.x * 3 + position.y).toInt() % 19;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
      return;
    }
    _tick -= dt;
    if (_tick > 0) return;
    _tick = _tickEvery;
    if (game.isNetClient) return; // donma host'ta işler
    final rSq = radius * radius;
    for (final u in List.of(game.units)) {
      if (u.dead || u.combatTeam == casterTeam) continue;
      if (u.position.distanceToSquared(position) <= rSq) {
        u.applyFreeze(_freezeHold);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_t / 0.35).clamp(0.0, 1.0);
    final fadeOut = ((duration - _t) / 0.7).clamp(0.0, 1.0);
    final alpha = math.min(fadeIn, fadeOut);

    // Buz tabakası katmanları — kıvrımlı kenarlar, merkeze doğru açılan ton.
    canvas.drawPath(wavyCircle(radius + 3, _seed, t: _t * 0.4),
        Paint()..color = const Color(0xFF7FA6BC).withValues(alpha: 0.35 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.93, _seed + 4, t: _t * 0.4),
        Paint()..color = const Color(0xFFA9C8D8).withValues(alpha: 0.45 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.62, _seed + 8, t: _t * 0.5),
        Paint()..color = const Color(0xFFD5E8F2).withValues(alpha: 0.40 * alpha));
    canvas.drawPath(
      wavyCircle(radius * 0.97, _seed + 2, t: _t * 0.4),
      Paint()
        ..color = const Color(0xFFEFF6FA).withValues(alpha: 0.55 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Buz çatlakları: merkezden kenara kırık çizgiler.
    final crack = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5 * alpha)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a0 = i * 1.047 + _seed * 0.7;
      var px = math.cos(a0) * radius * 0.15;
      var py = math.sin(a0) * radius * 0.15;
      for (var sgm = 1; sgm <= 3; sgm++) {
        final a = a0 + math.sin(i * 2.4 + sgm * 1.9 + _seed) * 0.35;
        final nx = math.cos(a) * radius * (0.15 + sgm * 0.26);
        final ny = math.sin(a) * radius * (0.15 + sgm * 0.26);
        canvas.drawLine(Offset(px, py), Offset(nx, ny), crack);
        px = nx;
        py = ny;
      }
    }
    // Parıldayan buz kristalleri.
    for (var i = 0; i < 8; i++) {
      final a = i * 2.399963 + _seed;
      final d = radius * 0.8 * math.sqrt((i + 0.5) / 8);
      final tw = (math.sin(_t * 4 + i * 2.1) * 0.5 + 0.5);
      final cx = math.cos(a) * d;
      final cy = math.sin(a) * d;
      final sz = 2.5 + tw * 2;
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy - sz)
          ..lineTo(cx + sz * 0.6, cy)
          ..lineTo(cx, cy + sz)
          ..lineTo(cx - sz * 0.6, cy)
          ..close(),
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: (0.3 + 0.5 * tw) * alpha),
      );
    }
  }
}

/// Zehir Bulutu: alanda süre boyunca DÜŞMANLARA saniyelik hasar (DoT alanı).
class PoisonCloudFx extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  PoisonCloudFx({
    required Vector2 position,
    required this.radius,
    required this.duration,
    required this.casterTeam,
  }) : super(position: position, anchor: Anchor.center, priority: 54);

  final double radius;
  final double duration;
  final int casterTeam;

  static const _dps = 10.0;
  static const _tickEvery = 0.5;
  double _t = 0;
  double _tick = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
      return;
    }
    _tick -= dt;
    if (_tick > 0) return;
    _tick = _tickEvery;
    if (game.isNetClient) return; // hasar host'ta işler
    final rSq = radius * radius;
    for (final u in List.of(game.units)) {
      if (!u.dead &&
          u.combatTeam != casterTeam &&
          u.position.distanceToSquared(position) <= rSq) {
        u.takeDamage(_dps * _tickEvery);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Giriş/çıkışta yumuşayan hastalıklı yeşil bulut + yüzen kabarcıklar.
    final fadeIn = (_t / 0.4).clamp(0.0, 1.0);
    final fadeOut = ((duration - _t) / 0.6).clamp(0.0, 1.0);
    final alpha = math.min(fadeIn, fadeOut);

    final seed = (position.x + position.y * 2).toInt() % 17;
    canvas.drawPath(wavyCircle(radius, seed, t: _t * 0.5),
        Paint()..color = const Color(0xFF86A34A).withValues(alpha: 0.18 * alpha));
    canvas.drawPath(wavyCircle(radius * 0.7, seed + 5, t: _t * 0.7),
        Paint()..color = const Color(0xFF77953C).withValues(alpha: 0.16 * alpha));
    canvas.drawPath(
      wavyCircle(radius, seed, t: _t * 0.5),
      Paint()
        ..color = const Color(0xFF6B8A32).withValues(alpha: 0.45 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 9; i++) {
      final a = i * 0.7 + _t * (0.4 + (i % 3) * 0.2);
      final d = radius * (0.25 + (i % 4) * 0.18);
      final bob = math.sin(_t * 2 + i * 1.7) * 6;
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d * 0.8 + bob),
        5 + (i % 3) * 3.0,
        Paint()
          ..color = const Color(0xFF9CBB5A).withValues(alpha: 0.22 * alpha),
      );
    }
  }
}

void _buffOwnUnits(
  AntsWarsGame game,
  Player caster,
  Vector2 center,
  double radius,
  void Function(UnitComponent) apply,
) {
  final rSq = radius * radius;
  for (final u in game.units) {
    if (!u.dead &&
        u.owner.id == caster.id &&
        u.position.distanceToSquared(center) <= rSq) {
      apply(u);
    }
  }
}

// --------------------------------------------------------------- efektler

/// KIVRIMLI DAİRE: yetenek alanları tam daire ÇİZİLMEZ — kenarları
/// zamanla hafifçe dalgalanan organik kapalı yol kullanılır
/// (oynanış menzili yine gerçek dairedir; sapma ±%8 görseldir).
Path wavyCircle(double radius, int seed,
    {double t = 0, int points = 22, double jitter = 0.08}) {
  final path = Path();
  for (var i = 0; i <= points; i++) {
    final a = i / points * 2 * math.pi;
    final wob = math.sin(a * 3 + seed + t * 0.9) * jitter +
        math.sin(a * 5 + seed * 1.7 - t * 0.6) * jitter * 0.6;
    final r = radius * (1 + wob);
    final x = math.cos(a) * r;
    final y = math.sin(a) * r;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// Yıldırım: çatallı ana şimşek + dallar, beyaz flaş ve yerde kalan yanık izi.
class LightningFx extends PositionComponent {
  LightningFx({required Vector2 position})
      : super(position: position, anchor: Anchor.center, priority: 55);

  static const _boltLife = 0.45;
  static const _scorchLife = 3.2;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _scorchLife) removeFromParent();
  }

  void _drawBolt(Canvas canvas, double fade, double startX, double topY,
      int seed, double width, double alpha) {
    final path = Path()..moveTo(startX, topY);
    var x = startX;
    for (var y = topY; y < 0; y += 34) {
      x = startX + ((seed + y.toInt() * 13) % 41 - 20) * 0.75;
      path.lineTo(x, y + 34);
    }
    path.lineTo(0, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF9E3).withValues(alpha: alpha * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void render(Canvas canvas) {
    // Yanık izi: uzun süre kalır, yavaşça solar.
    final scorchFade = (1 - _t / _scorchLife).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 46, height: 26),
      Paint()..color = const Color(0xFF1C140A).withValues(alpha: 0.5 * scorchFade),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 30, height: 16),
      Paint()..color = const Color(0xFF120C05).withValues(alpha: 0.6 * scorchFade),
    );

    if (_t >= _boltLife) return;
    final fade = (1 - _t / _boltLife).clamp(0.0, 1.0);
    final seed = (position.x * 7 + position.y * 13).toInt();

    // Beyaz flaş + parlama halkası.
    canvas.drawCircle(
      Offset.zero,
      140 * (_t / _boltLife) + 30,
      Paint()..color = const Color(0xFFFFFDF0).withValues(alpha: 0.22 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      20 + 70 * (_t / _boltLife),
      Paint()..color = const Color(0xFFFFF3C0).withValues(alpha: 0.5 * fade),
    );

    // Ana şimşek (kalın) + halo.
    _drawBolt(canvas, fade, 0, -270, seed, 7, 0.35); // dış halo
    _drawBolt(canvas, fade, 0, -270, seed, 3.2, 1.0);
    // Çatallar: kısa yan dallar.
    _drawBolt(canvas, fade, -26, -150, seed + 91, 1.8, 0.8);
    _drawBolt(canvas, fade, 30, -110, seed + 47, 1.5, 0.7);

    // Çarpma noktası: kıvılcım saçılması.
    for (var i = 0; i < 7; i++) {
      final a = i * 0.9 + seed;
      final d = 10 + (_t / _boltLife) * 26;
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d * 0.6),
        2 * fade,
        Paint()..color = const Color(0xFFFFE9A0).withValues(alpha: fade),
      );
    }
    canvas.drawCircle(
        Offset.zero, 10 * fade, Paint()..color = const Color(0xFFFFFDF0));
  }
}

/// Genişleyip sönen çift halka + dışa saçılan parçacıklar
/// (feromon dalgası, iyileştirme, takviye).
class AreaPulseFx extends PositionComponent {
  AreaPulseFx({
    required Vector2 position,
    required this.maxRadius,
    required this.color,
  }) : super(position: position, anchor: Anchor.center, priority: 55);

  final double maxRadius;
  final Color color;
  static const _life = 0.9;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _life).clamp(0.0, 1.0);
    final fade = 1 - p;

    // Çift KIVRIMLI halka (ikincisi gecikmeli) — tam daire yok.
    final seed = (position.x + position.y).toInt() % 13;
    for (final (delay, w, sd) in const [(0.0, 4.0, 0), (0.22, 2.2, 6)]) {
      final q = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (q <= 0) continue;
      canvas.drawPath(
        wavyCircle(maxRadius * (0.25 + 0.75 * q), seed + sd, t: p * 2),
        Paint()
          ..color = color.withValues(alpha: 0.6 * (1 - q))
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * (1 - q) + 1,
      );
    }
    // İç dolgu parlaması.
    canvas.drawPath(
      wavyCircle(maxRadius * (0.25 + 0.75 * p) * 0.7, seed + 3, t: p * 2),
      Paint()..color = color.withValues(alpha: 0.14 * fade),
    );
    // Dışa uçan parçacıklar.
    for (var i = 0; i < 10; i++) {
      final a = i * 0.628 + seed;
      final d = maxRadius * (0.3 + 0.7 * p) * (0.85 + (i % 3) * 0.08);
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        2.2 * fade + 0.6,
        Paint()..color = color.withValues(alpha: 0.8 * fade),
      );
    }
  }
}

/// Yağmur: tüm ekranda eğik damla çizgileri + hafif karartı.
class RainFx extends Component {
  RainFx({required this.duration}) : super(priority: 56);

  final double duration;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void onRemove() {
    AudioController.stopRain();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // Giriş/çıkışta yumuşak geçiş.
    final fadeIn = (_t / 0.5).clamp(0.0, 1.0);
    final fadeOut = ((duration - _t) / 0.5).clamp(0.0, 1.0);
    final alpha = math.min(fadeIn, fadeOut);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kGameWidth, kGameHeight),
      Paint()..color = const Color(0xFF23303A).withValues(alpha: 0.18 * alpha),
    );
    final drop = Paint()
      ..color = const Color(0xFFBDD5E2).withValues(alpha: 0.35 * alpha)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Deterministik damlalar: sütun başına faz kaydırmalı akış.
    for (var i = 0; i < 90; i++) {
      final x = (i * 137.5) % kGameWidth;
      final speed = 500 + (i % 5) * 60;
      final y = ((_t * speed + i * 83) % (kGameHeight + 40)) - 20;
      canvas.drawLine(Offset(x, y), Offset(x - 6, y + 16), drop);
    }
  }
}
