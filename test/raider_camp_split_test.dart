import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/models/game_map.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yağmacı kampı + komutan çarkı + ordu bölme davranış testleri.
void main() {
  Future<AntsWarsGame> pump(WidgetTester tester,
      {MapDefinition? map, int players = 4}) async {
    final state = GameState()
      ..startMatch(playerCount: players, map: map ?? fourCorners);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  void spawn(AntsWarsGame game, int playerId, Vector2 at, int n) {
    final p = game.gameState.players[playerId];
    for (var i = 0; i < n; i++) {
      final u = UnitComponent(
        type: UnitType.fire,
        owner: p,
        position: game.grid.nearestOpen(
            at + Vector2(math.cos(i * 2.1), math.sin(i * 2.1)) * (8 + i * 3.0)),
      );
      game.units.add(u);
      game.world.add(u);
    }
  }

  void simulate(AntsWarsGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      game.update(0.05);
    }
  }

  testWidgets('yağmacı kampı: dolduran 5 yağmacı kazanır, kamp söner',
      (tester) async {
    final game = await pump(tester);
    expect(game.raiderCamps, hasLength(2),
        reason: 'Tuna Kıyıları iki kamp taşımalı');
    final camp = game.raiderCamps.first;
    final human = game.gameState.humanPlayer!;
    final before =
        game.units.where((u) => !u.dead && u.owner.id == human.id).length;

    spawn(game, 0, camp.position, 6);
    await tester.pump();
    simulate(game, 8);
    // Yakındaki NÖTR kule ekipten vurabilir — ödülü aralıkla doğrula.
    final after =
        game.units.where((u) => !u.dead && u.owner.id == human.id).length;
    expect(after, greaterThanOrEqualTo(before + 6 + 5 - 2),
        reason: '5 yağmacı ödülü orduya katılmalı');
    expect(camp.cooldown, greaterThan(0), reason: 'Kamp sönmeli');

    // Sönükken tekrar doldurulamaz (sayı ancak azalabilir).
    simulate(game, 8);
    final again =
        game.units.where((u) => !u.dead && u.owner.id == human.id).length;
    expect(again, lessThanOrEqualTo(after),
        reason: 'Sönük kamp ödül vermez');
  });

  testWidgets('ordu bölme: %50 seçiliyken kümenin yarısı yürür',
      (tester) async {
    final game = await pump(tester, map: riverCrossing, players: 2);
    final human = game.gameState.humanPlayer!;
    spawn(game, 0, game.nests[human.id]!.position + Vector2(90, 0), 8);
    await tester.pump();
    game.update(0.05);

    final input = game.inputController;
    final seed =
        game.units.firstWhere((u) => u.owner.id == human.id && !u.dead);
    input.selectClusterFrom(seed);
    expect(input.selection.length, 8);

    game.deployFraction.value = 0.5;
    input.beginDrag(seed.position.clone());
    input.updateDrag(Vector2(120, 40));
    input.endDrag();
    game.update(0.05);

    expect(input.selection.length, 4,
        reason: 'Seçim yürüyen yarıda kalmalı');
    final moving = game.units
        .where((u) => u.owner.id == human.id && !u.dead && u.isMoving)
        .length;
    expect(moving, 4, reason: 'Kümenin yalnız yarısı yürümeli');
  });

}
