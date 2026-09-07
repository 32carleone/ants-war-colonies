import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ÇÖKME REGRESYONU: iki birim TAM üst üste gelince vur-kaç/kaçış yönü
/// sıfır vektör normalize edip NaN konum üretiyordu; NaN konum grid
/// indeksinde (~/) UnsupportedError fırlatıp OYUNU KAPATIYORDU.
void main() {
  testWidgets('üst üste binen birimler NaN üretmez, oyun çökmez',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    // Menzilli + kapan çene, düşmanla AYNI noktada (kite ve kaçış tetiklenir).
    final spot = game.grid.nearestOpen(Vector2(640, 300));
    final units = <UnitComponent>[];
    for (final (type, owner) in [
      (UnitType.wood, 0),
      (UnitType.trapjaw, 0),
      (UnitType.leafcutter, 1),
      (UnitType.leafcutter, 1),
    ]) {
      final u = UnitComponent(
        type: type,
        owner: state.players[owner],
        position: spot.clone(),
      );
      units.add(u);
      game.units.add(u);
      game.world.add(u);
    }
    await tester.pump();

    // 10 sn simülasyon: eskiden burada UnsupportedError ile çökerdi.
    for (var i = 0; i < 200; i++) {
      game.update(0.05);
    }
    for (final u in units) {
      expect(u.position.x.isFinite && u.position.y.isFinite, isTrue,
          reason: 'Birim konumu her zaman sonlu kalmalı');
    }
  });
}
