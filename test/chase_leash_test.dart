import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASMA: nöbetteki asker kaçan düşmanı sonsuza dek kovalamaz —
/// nöbet noktasından ~110px uzaklaşınca bırakır ve yerine döner.
void main() {
  testWidgets('kaçan düşmanı fazla kovalamaz, nöbet yerine döner',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    for (final n in game.nests.values) {
      n.garrison.clear();
    }

    final guardSpot = game.grid.nearestOpen(Vector2(400, 500));
    final guard = UnitComponent(
      type: UnitType.leafcutter, // yavaş (40) — hızlı düşmana yetişemez
      owner: state.players[0],
      position: guardSpot.clone(),
    );
    final runner = UnitComponent(
      type: UnitType.fire, // hızlı (70) — sürekli kaçar
      owner: state.players[1],
      position: game.grid.nearestOpen(guardSpot + Vector2(60, 0)),
    );
    game.units.add(guard);
    game.units.add(runner);
    game.world.add(guard);
    game.world.add(runner);
    await tester.pump();

    // Düşman anında uzağa kaçar (emirli birim savaşa girmez).
    runner.orderMove(game.grid.nearestOpen(Vector2(400, 120)));
    for (var i = 0; i < 240; i++) {
      game.update(0.05); // 12 sn
      if (runner.isMoving) continue;
      runner.orderMove(game.grid.nearestOpen(Vector2(400, 120)));
    }

    expect(guard.dead, isFalse);
    expect(guard.position.distanceTo(guardSpot), lessThan(60),
        reason: 'Nöbetçi kovalamacayı bırakıp yerine dönmeliydi '
            '(mesafe: ${guard.position.distanceTo(guardSpot).round()})');
  });
}
