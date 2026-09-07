import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:ants_wars/models/building.dart';
import 'package:ants_wars/models/game_map.dart';
import 'package:ants_wars/models/player.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yeni harita öğeleri: bataklık, kazı geçidi,
/// yaban arısı yuvası ve kuluçka istasyonu (ikinci çıkış).
void main() {
  Future<AntsWarsGame> pumpGame(
    WidgetTester tester, {
    required MapDefinition map,
    int? playerCount,
  }) async {
    final state = GameState()
      ..startMatch(playerCount: playerCount ?? map.playerCount, map: map);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  void simulate(AntsWarsGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      game.update(0.05);
    }
  }

  testWidgets('bataklık içindeki asker yavaşlar (herkes)', (tester) async {
    final game = await pumpGame(tester, map: riverCrossing);
    final human = game.gameState.humanPlayer!;
    // Amazon Geçidi'nin batı bataklığının göbeği.
    final inSwamp = Vector2(435, 435);
    expect(game.grid.isSlowAt(inSwamp), isTrue);
    expect(game.grid.isSlowAt(Vector2(200, 100)), isFalse);

    final unit = UnitComponent(
        type: UnitType.fire, owner: human, position: inSwamp.clone());
    game.world.add(unit);
    await tester.pump();
    final spec = unitSpecs[UnitType.fire]!;
    expect(unit.moveSpeedNow,
        closeTo(spec.moveSpeed * kSwampSlowFactor, 0.01));
  });

  testWidgets('kazı geçidi: kalabalık kazar, geçit kalıcı açılır',
      (tester) async {
    final game = await pumpGame(tester, map: himalayaPasses);
    final human = game.gameState.humanPlayer!;
    final site = game.digSites.first; // kuzeybatı tıkacı (300-420, ~247)
    final plugPoint = Vector2(360, 248);
    expect(game.grid.isBlockedAt(plugPoint), isTrue);

    // 12 asker tıkacın dibinde beklesin: 47/√12 → ~13.6 sn'de açılmalı
    // (taş çetin: 10 asker ~15 sn hedefi). Ayrışma kuvveti birkaçını
    // halkanın kıyısına itebilir — pay bırakılır.
    for (var i = 0; i < 12; i++) {
      game.world.add(UnitComponent(
        type: UnitType.fire,
        owner: human,
        position: Vector2(330 + (i % 6) * 12.0, 290 + (i ~/ 6) * 18.0),
      ));
    }
    await tester.pump();
    simulate(game, 22);
    expect(site.open, isTrue);
    expect(game.grid.isBlockedAt(plugPoint), isFalse,
        reason: 'Kazılan geçit yürünebilir olmalı');
  });

  testWidgets('yaban arısı yuvası menzile giren askeri sokar',
      (tester) async {
    final game = await pumpGame(tester, map: rootTriangle);
    final human = game.gameState.humanPlayer!;
    final unit = UnitComponent(
        type: UnitType.leafcutter, owner: human, position: Vector2(300, 330));
    game.world.add(unit);
    await tester.pump();
    expect(unit.hp, unit.spec.maxHp);
    simulate(game, 3);
    expect(unit.hp, lessThan(unit.spec.maxHp),
        reason: 'Arı yuvasının dibinde bekleyen asker sokulmalı');
  });

  testWidgets('arı kovanı KEMİRİLEREK yıkılır ve engel kalıcı açılır',
      (tester) async {
    final game = await pumpGame(tester, map: rootTriangle);
    final human = game.gameState.humanPlayer!;
    final hive = Vector2(300, 390); // Serengeti batı kovanı
    expect(game.grid.isBlockedAt(hive), isTrue);
    for (var i = 0; i < 12; i++) {
      game.world.add(UnitComponent(
        type: UnitType.leafcutter,
        owner: human,
        position: Vector2(268 + (i % 6) * 13.0, 350 + (i ~/ 6) * 16.0),
      ));
    }
    await tester.pump();
    simulate(game, 10);
    expect(game.grid.isBlockedAt(hive), isFalse,
        reason: 'Yıkılan kovanın yeri yürünebilir olmalı');
    expect(game.clearedFeatures, isNotEmpty);
  });

  testWidgets('kuluçka istasyonu: askerler hedefe yakın çıkıştan iner',
      (tester) async {
    final game = await pumpGame(tester, map: fourCorners);
    final human = game.gameState.humanPlayer!;
    final hatchery = game.buildings
        .firstWhere((b) => b.type == BuildingType.hatchery);
    hatchery.owner = human;

    final nest = game.nests[human.id]!;
    nest.garrison
      ..clear()
      ..[UnitType.fire] = 4;
    final unitsBefore = List.of(game.units);
    game.deployFromNest(nest, 1.0, hatchery.position.clone());
    final spawned =
        game.units.where((u) => !unitsBefore.contains(u)).toList();
    expect(spawned, hasLength(4));
    for (final u in spawned) {
      expect(u.position.distanceTo(hatchery.position), lessThan(70),
          reason: 'Asker kuluçkadan inmeliydi: ${u.position}');
    }
  });

  test('kuluçka yükseltilemez ve dönüştürülemez', () {
    final p = Player(id: 0, color: const Color(0xFFE05A33), isBot: false)
      ..resources = 999;
    final hatchery =
        Building(position: Vector2.zero(), type: BuildingType.hatchery)
          ..owner = p;
    expect(hatchery.canUpgrade(p), isFalse);
    expect(hatchery.convertTo(p, BuildingType.resource), isFalse);

    final farm =
        Building(position: Vector2.zero(), type: BuildingType.resource)
          ..owner = p;
    expect(farm.convertTo(p, BuildingType.hatchery), isFalse);
    expect(farm.incomePerSec, greaterThan(0));
    expect(hatchery.incomePerSec, 0);
    expect(hatchery.powerBonus, 0);
  });
}
