import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:ants_wars/models/player.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Player makePlayer(int id, {int resources = 500}) => Player(
        id: id,
        color: kTeamColors[id],
        isBot: id != 0,
        resources: resources,
      );

  group('Ele geçirme mantığı', () {
    test('çoğunluk halkayı doldurur ve bina el değiştirir', () {
      final b =
          Building(position: Vector2(100, 100), type: BuildingType.resource);
      final p = makePlayer(0);
      // 3 net asker → kCaptureBaseTime sonunda dolmalı.
      var elapsed = 0.0;
      var changed = false;
      while (!changed && elapsed < kCaptureBaseTime + 1) {
        changed = b.updateCapture(0.1, {p: 3});
        elapsed += 0.1;
      }
      expect(changed, isTrue);
      expect(b.owner, p);
      expect(b.captureProgress, 0);
    });

    test('TAM el değiştirme 1 seviye geriletir (nötr ilk alım geriletmez)',
        () {
      final b =
          Building(position: Vector2(100, 100), type: BuildingType.resource);
      final p0 = makePlayer(0);
      final p1 = makePlayer(1);
      void flipTo(Player p) {
        var changed = false;
        var guard = 0;
        while (!changed && guard++ < 500) {
          changed = b.updateCapture(0.1, {p: 9});
        }
        expect(changed, isTrue);
        expect(b.owner, p);
      }

      // Nötrden ilk alım: seviye düşmez.
      flipTo(p0);
      expect(b.level, 1);
      // Sahip yükseltir, düşman söker → 1 seviye geriler.
      b.upgrade(p0);
      b.upgrade(p0);
      expect(b.level, 3);
      flipTo(p1);
      expect(b.level, 2, reason: 'Tam el değiştirme 1 seviye geriletir');
      // Seviye 1'in altına inilmez.
      flipTo(p0);
      flipTo(p1);
      expect(b.level, 1);
      flipTo(p0);
      expect(b.level, 1, reason: '1 seviyenin altı geçersiz');
    });

    test('kule ele geçirmesi 2 kat uzun sürer', () {
      final tower =
          Building(position: Vector2(100, 100), type: BuildingType.tower);
      final res =
          Building(position: Vector2(200, 100), type: BuildingType.resource);
      final p = makePlayer(0);
      for (var i = 0; i < 20; i++) {
        tower.updateCapture(0.1, {p: 3});
        res.updateCapture(0.1, {p: 3});
      }
      expect(tower.captureProgress,
          closeTo(res.captureProgress * 0.5, 0.01));
    });

    test('yüksek seviyeli bina daha zor ele geçirilir (%25/sv)', () {
      final lo =
          Building(position: Vector2.zero(), type: BuildingType.resource);
      final hi =
          Building(position: Vector2.zero(), type: BuildingType.resource)
            ..level = 3;
      final p = makePlayer(0);
      for (var i = 0; i < 20; i++) {
        lo.updateCapture(0.1, {p: 3});
        hi.updateCapture(0.1, {p: 3});
      }
      expect(hi.captureProgress,
          closeTo(lo.captureProgress / 1.5, 0.01));
    });

    test('seviye tavanları: kule/çiftlik 4, güç 3, kuluçka 1', () {
      final p = makePlayer(0)..resources = 9999;
      Building maxed(BuildingType t) {
        final b = Building(position: Vector2.zero(), type: t)..owner = p;
        while (b.canUpgrade(p)) {
          b.upgrade(p);
        }
        return b;
      }

      expect(maxed(BuildingType.tower).level, 4);
      expect(maxed(BuildingType.tower).towerShots, 4);
      expect(maxed(BuildingType.resource).level, 4);
      expect(maxed(BuildingType.power).level, 3);
      expect(maxed(BuildingType.hatchery).level, 1);
    });

    test('eşit güçler halkayı doldurmaz', () {
      final b =
          Building(position: Vector2(100, 100), type: BuildingType.resource);
      final p0 = makePlayer(0);
      final p1 = makePlayer(1);
      for (var i = 0; i < 100; i++) {
        b.updateCapture(0.1, {p0: 4, p1: 4});
      }
      expect(b.captureProgress, 0);
      expect(b.owner, isNull);
    });

    test('kuşatan çekilince ilerleme çözülür', () {
      final b = Building(position: Vector2(100, 100), type: BuildingType.power);
      final p = makePlayer(0);
      for (var i = 0; i < 20; i++) {
        b.updateCapture(0.1, {p: 3});
      }
      expect(b.captureProgress, greaterThan(0));
      for (var i = 0; i < 60; i++) {
        b.updateCapture(0.1, {});
      }
      expect(b.captureProgress, 0);
      expect(b.capturingPlayer, isNull);
    });

    test('rakip kuşatan önce mevcut ilerlemeyi eritir', () {
      final b = Building(position: Vector2(100, 100), type: BuildingType.tower);
      final p0 = makePlayer(0);
      final p1 = makePlayer(1);
      for (var i = 0; i < 20; i++) {
        b.updateCapture(0.1, {p0: 3});
      }
      final before = b.captureProgress;
      b.updateCapture(0.1, {p1: 5});
      expect(b.captureProgress, lessThan(before));
      expect(b.capturingPlayer, p0); // halka sıfırlanana dek eski kuşatan
    });

    test('sahibin kendi çoğunluğu halkayı doldurmaz (savunma)', () {
      final b = Building(position: Vector2(100, 100), type: BuildingType.tower);
      final p = makePlayer(0);
      b.owner = p;
      for (var i = 0; i < 50; i++) {
        b.updateCapture(0.1, {p: 6});
      }
      expect(b.captureProgress, 0);
    });
  });

  group('Yönetim', () {
    test('yükseltme kaynak düşer, seviye artar, 3 ile sınırlıdır', () {
      final b = Building(position: Vector2(0, 0), type: BuildingType.resource);
      final p = makePlayer(0, resources: 200);
      b.owner = p;
      expect(b.upgrade(p), isTrue); // 50
      expect(b.level, 2);
      expect(p.resources, 200 - kUpgradeCostPerLevel);
      expect(b.upgrade(p), isTrue); // 100
      expect(b.level, 3);
      expect(p.resources, 200 - 3 * kUpgradeCostPerLevel);
      expect(b.upgrade(p), isFalse); // maks seviye
    });

    test('dönüştürme türü değiştirir ve seviyeyi sıfırlar', () {
      final b = Building(position: Vector2(0, 0), type: BuildingType.tower);
      final p = makePlayer(0, resources: 300);
      b.owner = p;
      b.upgrade(p);
      expect(b.level, 2);
      expect(b.convertTo(p, BuildingType.power), isTrue);
      expect(b.type, BuildingType.power);
      expect(b.level, 1);
      expect(p.resources, 300 - kUpgradeCostPerLevel - kConvertCost);
      expect(b.convertTo(p, BuildingType.power), isFalse); // aynı tür
    });

    test('sahip olmayan yükseltemez/dönüştüremez', () {
      final b = Building(position: Vector2(0, 0), type: BuildingType.tower);
      final p = makePlayer(0);
      expect(b.upgrade(p), isFalse);
      expect(b.convertTo(p, BuildingType.power), isFalse);
    });
  });

  group('Etkiler', () {
    test('haritalarda tür listeleri nokta listeleriyle eşleşir', () {
      for (final count in [2, 3, 4]) {
        final map = mapForPlayers(count);
        expect(map.buildingTypes.length, map.buildingSpots.length);
      }
    });

    test('güç çarpanı sahip olunan güç binalarıyla artar', () {
      final b1 = Building(position: Vector2(0, 0), type: BuildingType.power);
      final b2 = Building(position: Vector2(50, 0), type: BuildingType.power);
      expect(b1.powerBonus, kPowerBonusPerLevel);
      b1.level = 3;
      expect(b1.powerBonus, closeTo(3 * kPowerBonusPerLevel, 0.001));
      expect(b2.incomePerSec, 0); // güç binası gelir üretmez
    });
  });

  group('Oyun içi (kule ve ele geçirme)', () {
    Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
      final state = GameState()..startMatch(playerCount: 2);
      final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      game.bots.clear(); // sistem testleri sessiz ortam ister
      return game;
    }

    testWidgets('askerler nötr binayı çevresinde durarak ele geçirir',
        (tester) async {
      final game = await pumpGame(tester);
      final nest = game.nests[0]!;
      // Yuvaya en yakın binayı hedefle.
      final building = game.buildings.reduce((a, b) =>
          a.position.distanceToSquared(nest.position) <
                  b.position.distanceToSquared(nest.position)
              ? a
              : b);
      game.deployFromNest(nest, 1.0, building.position);

      // Yürüyüş + ele geçirme süresi.
      for (var i = 0; i < 500; i++) {
        game.update(0.05); // 25 sn
      }
      expect(building.owner, game.gameState.players[0]);
    });

    testWidgets('sahipli kule menzildeki düşmana hasar verir', (tester) async {
      final game = await pumpGame(tester);
      final human = game.gameState.players[0];
      final enemyNest = game.nests[1]!;
      // İnsana bir kule ver ve düşman askerini menzile getir.
      final tower = game.buildings
          .firstWhere((b) => b.type == BuildingType.tower);
      tower.owner = human;
      game.deployFromNest(
          enemyNest, 0.5, game.grid.nearestOpen(tower.position));

      for (var i = 0; i < 400; i++) {
        game.update(0.05); // 20 sn: yürü + ateş altında kal
      }
      // En az bir düşman hasar almış ya da ölmüş olmalı.
      final enemies =
          game.units.where((u) => u.owner.id == 1).toList();
      final damaged = enemies.any((u) => u.hp < u.spec.maxHp);
      final killed = enemies.length < 5;
      expect(damaged || killed, isTrue,
          reason: 'Kule menzildeki düşmana hiç hasar vermedi');
    });

    testWidgets('kaynak binası sahibine ek gelir sağlar', (tester) async {
      final game = await pumpGame(tester);
      final p0 = game.gameState.players[0];
      final p1 = game.gameState.players[1];
      final resource = game.buildings
          .firstWhere((b) => b.type == BuildingType.resource);
      resource.owner = p0;

      final start0 = p0.resources;
      final start1 = p1.resources;
      for (var i = 0; i < 200; i++) {
        game.update(0.05); // 10 sn
      }
      final gain0 = p0.resources - start0;
      final gain1 = p1.resources - start1;
      expect(gain0, greaterThan(gain1));
      expect(gain0 - gain1, closeTo(10 * kResourceIncomePerLevel, 3));
    });
  });
}
