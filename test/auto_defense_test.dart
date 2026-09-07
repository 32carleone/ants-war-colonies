import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Otomatik yuva savunması: düşman ana yuvanın dibine gelince garnizon
/// kendiliğinden çıkar; tehdit sürerken yeni üretilenler de çıkar.
void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  void simulate(AntsWarsGame game, double seconds) {
    final steps = (seconds / 0.05).round();
    for (var i = 0; i < steps; i++) {
      game.update(0.05);
    }
  }

  testWidgets('düşman yaklaşınca garnizon otomatik çıkar ve savaşır',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    final enemy = game.gameState.players[1];
    expect(nest.population, greaterThan(0));

    // 3 düşman askeri yuvanın dibine gelir.
    for (var i = 0; i < 3; i++) {
      final u = UnitComponent(
        type: UnitType.leafcutter,
        owner: enemy,
        position:
            game.grid.nearestOpen(nest.position + Vector2(110, -20.0 + i * 20)),
      );
      game.units.add(u);
      game.world.add(u);
    }
    await tester.pump();

    simulate(game, 2);
    expect(nest.population, 0,
        reason: 'Garnizon otomatik dışarı çıkmalıydı');
    final defenders =
        game.units.where((u) => !u.dead && u.owner.id == 0).length;
    expect(defenders, greaterThan(0));

    // Tehdit sürerken yeni üretilen asker de otomatik çıkar.
    game.gameState.humanPlayer!.resources = 50;
    nest.enqueue(UnitType.fire);
    simulate(game, 3); // üretim (0.9 sn) + savunma kontrolü (0.5 sn aralık)
    expect(nest.population, 0,
        reason: 'Yeni üretilen asker de garnizonda beklememeliydi');
  });

  testWidgets('tehdit yokken garnizon yerinde durur', (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    final before = nest.population;
    simulate(game, 3);
    expect(nest.population, before);
  });
}
