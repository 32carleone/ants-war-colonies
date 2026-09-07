import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ANA YUVA YÜKSELTMESİ (500 altın, tek seferlik): üretim hızı 2 kat.
/// Feromon merkezi zırhı: alınan hasar seviye başına %6 azalır (tavan %25).
void main() {
  testWidgets('yuva yükseltmesi: 500 altın, üretim 2 kat, tek seferlik',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    final human = state.humanPlayer!;
    final nest = game.nests[human.id]!;

    // Parası yoksa alamaz.
    human.resources = kNestUpgradeCost - 1;
    expect(game.requestNestUpgrade(), isFalse);

    human.resources = kNestUpgradeCost + 40;
    expect(game.requestNestUpgrade(), isTrue);
    expect(nest.upgraded, isTrue);
    expect(human.resources, 40);
    // 2. KADEME: 1000 altına ANINDA üretim.
    human.resources = kNestUpgrade2Cost - 1;
    expect(game.requestNestUpgrade(), isFalse);
    human.resources = kNestUpgrade2Cost;
    expect(game.requestNestUpgrade(), isTrue);
    expect(nest.instantProduction, isTrue);
    // Üçüncü kademe yok.
    human.resources = 9999;
    expect(game.requestNestUpgrade(), isFalse);

    // ANINDA ÜRETİM: basılan asker ilk tikte garnizonda.
    nest.garrison.clear();
    human.resources = 999;
    nest.enqueue(UnitType.fire);
    nest.updateProduction(0.05);
    expect(nest.garrison[UnitType.fire] ?? 0, 1,
        reason: '2. kademede üretim ANINDA bitmeli');
  });

  testWidgets('feromon zırhı: alınan hasar azalır, tavan %25',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    final human = state.humanPlayer!;
    expect(game.powerArmorMultiplier(human), 1.0);

    final power =
        game.buildings.firstWhere((b) => b.type == BuildingType.power)
          ..owner = human
          ..level = 2;
    expect(game.powerArmorMultiplier(human),
        closeTo(1 - 2 * kPowerArmorPerLevel, 1e-9));

    // Tavan: 3 + 3 seviye güç bile azaltmayı %25'te keser.
    final power2 = game.buildings
        .lastWhere((b) => b.type == BuildingType.power && b != power)
      ..owner = human
      ..level = 3;
    power.level = 3;
    expect(power2.type, BuildingType.power);
    expect(game.powerArmorMultiplier(human), 0.75);
  });
}
