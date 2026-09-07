import 'dart:math' as math;

import 'package:ants_wars/data/counters.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Birim verileri', () {
    test('6 tipin tamamının eksiksiz istatistikleri var', () {
      expect(unitSpecs.length, UnitType.values.length);
      for (final spec in unitSpecs.values) {
        expect(spec.maxHp, greaterThan(0));
        expect(spec.damage, greaterThan(0));
        expect(spec.moveSpeed, greaterThan(0));
        expect(spec.attackRange, greaterThan(0));
        expect(spec.attackCooldown, greaterThan(0));
      }
    });

    test('tür özellikleri doğru tiplere atanmış', () {
      expect(unitSpecs[UnitType.wood]!.ranged, isTrue);
      expect(unitSpecs[UnitType.trapjaw]!.firstStrike, isTrue);
      expect(unitSpecs[UnitType.wood]!.attackRange, greaterThan(50));
    });

    test('counter çemberi tasarıma uygun', () {
      expect(counterMultiplier(UnitType.wood, UnitType.leafcutter),
          greaterThan(1)); // menzilli > tank
      expect(counterMultiplier(UnitType.trapjaw, UnitType.wood),
          greaterThan(1)); // suikastçı > menzilli
      expect(counterMultiplier(UnitType.fire, UnitType.trapjaw),
          greaterThan(1)); // sürü > suikastçı
      expect(counterMultiplier(UnitType.leafcutter, UnitType.fire),
          greaterThan(1)); // tank > sürü
      expect(counterMultiplier(UnitType.fire, UnitType.leafcutter), 1.0);
    });
  });

  group('Birim hareketi (oyun içi)', () {
    Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
      final state = GameState()..startMatch(playerCount: 2);
      final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      game.bots.clear(); // sistem testleri sessiz ortam ister
      return game;
    }

    testWidgets('yuvadan çıkan birimler hedefe yürür', (tester) async {
      final game = await pumpGame(tester);
      final nest = game.nests[0]!;
      final target =
          game.grid.nearestOpen(nest.position + Vector2(150, 40));

      game.deployFromNest(nest, 1.0, target);
      expect(game.unitCount, 10);
      expect(nest.population, 0);

      // ~12 saniye simüle et (spawn gecikmeleri + yürüyüş).
      for (var i = 0; i < 240; i++) {
        game.update(0.05);
      }

      for (final unit in game.units) {
        expect(unit.position.distanceTo(target), lessThan(80),
            reason: 'Birim hedefe varamadı: ${unit.position}');
      }
    });

    testWidgets('%50 çıkarma garnizonun yarısını sahaya sürer',
        (tester) async {
      final game = await pumpGame(tester);
      final nest = game.nests[0]!;
      game.deployFromNest(
          nest, 0.5, game.grid.nearestOpen(nest.position + Vector2(100, 0)));
      expect(game.unitCount, 5);
      expect(nest.population, 5);
    });

    testWidgets('yuvaya dönen birim garnizona katılır', (tester) async {
      final game = await pumpGame(tester);
      final nest = game.nests[0]!;
      game.deployFromNest(
          nest, 1.0, game.grid.nearestOpen(nest.position + Vector2(80, 0)));

      // Önce hedefe varsınlar.
      for (var i = 0; i < 160; i++) {
        game.update(0.05);
      }
      // Sonra hepsini yuvaya geri çağır.
      for (final unit in List.of(game.units)) {
        unit.orderReturnToNest();
      }
      for (var i = 0; i < 200; i++) {
        game.update(0.05);
      }
      await tester.pump();

      expect(game.unitCount, 0);
      expect(nest.population, 10);
    });

    testWidgets('ölen birim ceset süresinden sonra kaybolur', (tester) async {
      final game = await pumpGame(tester);
      final nest = game.nests[0]!;
      game.deployFromNest(
          nest, 1.0, game.grid.nearestOpen(nest.position + Vector2(60, 0)));
      final unit = game.units.first;
      unit.takeDamage(9999);
      expect(unit.dead, isTrue);

      for (var i = 0; i < 100; i++) {
        game.update(0.05); // 5 sn > 4 sn ceset süresi
      }
      await tester.pump();
      expect(game.units.contains(unit), isFalse);
    });
  });
}
