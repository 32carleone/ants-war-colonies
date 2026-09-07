import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kuluçkadan TUT-SÜRÜKLE çıkarma: exitOverride verilirse askerler
/// (yalnız kendi kuluçkasıysa) o noktadan sahaya iner; düşman/başıboş
/// kuluçka üstü reddedilip normal çıkışa dönülür.
void main() {
  Future<AntsWarsGame> pump(WidgetTester tester) async {
    final state = GameState()
      ..startMatch(playerCount: 4, map: fourCorners);
    final game = AntsWarsGame(gameState: state, rng: math.Random(3))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  Building hatcheryOf(AntsWarsGame game) => game.buildings
      .firstWhere((b) => b.type == BuildingType.hatchery);

  testWidgets('kendi kuluçkasından çıkarma o noktadan iner',
      (tester) async {
    final game = await pump(tester);
    final human = game.gameState.humanPlayer!;
    final nest = game.nests[human.id]!;
    final hat = hatcheryOf(game)..owner = human;

    game.deployFromNest(nest, 1.0, nest.position + Vector2(120, 0),
        exitOverride: hat.position.clone());
    final mine =
        game.units.where((u) => u.owner.id == human.id).toList();
    expect(mine, isNotEmpty);
    for (final u in mine) {
      expect(u.position.distanceTo(hat.position), lessThan(70),
          reason: 'Asker kuluçkanın dibinden sahaya inmeli');
    }
  });

  testWidgets('sahipsiz kuluçka üstü REDDEDİLİR — normal çıkış',
      (tester) async {
    final game = await pump(tester);
    final human = game.gameState.humanPlayer!;
    final nest = game.nests[human.id]!;
    final hat = hatcheryOf(game); // owner: null (başıboş)

    game.deployFromNest(nest, 1.0, nest.position + Vector2(60, 0),
        exitOverride: hat.position.clone());
    final mine =
        game.units.where((u) => u.owner.id == human.id).toList();
    expect(mine, isNotEmpty);
    for (final u in mine) {
      expect(u.position.distanceTo(nest.position), lessThan(70),
          reason: 'Sahip olmadığın kuluçkadan çıkarma yapılamaz');
    }
  });
}
