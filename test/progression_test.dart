import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:ants_wars/models/building.dart';
import 'package:ants_wars/models/player.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tur 27 ilerleme sistemleri: yuva seviyesi/ordu tavanı, kalabalıkla
/// hızlanan ele geçirme, çok mermili kule.
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

  testWidgets('ordu tavanı sabittir; yuva yükseltmesi HIZI alır, tavanı değil',
      (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    expect(game.armyCap(human), kArmyCap);
    // Yuva yükseltme butonu: 500 altına üretim hızı ×2 — tavan DEĞİŞMEZ.
    final nest = game.nests[0]!;
    human.resources = 500;
    game.inputController.handleTap(nest.position.clone());
    game.inputController.handleTap(nest.position + Vector2(0, -76));
    expect(human.resources, 0);
    expect(nest.upgraded, isTrue);
    expect(game.armyCap(human), kArmyCap);
  });

  test('ele geçirme kalabalıkla hızlanır (1 asker ~10 sn, 9 asker ~3.3 sn)',
      () {
    double captureTime(int net) {
      final b =
          Building(position: Vector2(0, 0), type: BuildingType.resource);
      final attacker =
          Player(id: 0, color: const Color(0xFFE05A33), isBot: false);
      var t = 0.0;
      while (b.owner == null && t < 30) {
        b.updateCapture(0.1, {attacker: net});
        t += 0.1;
      }
      return t;
    }

    expect(captureTime(1), closeTo(10, 0.5));
    expect(captureTime(4), closeTo(5, 0.5));
    expect(captureTime(9), closeTo(3.3, 0.5));
  });

  testWidgets('sv3 kule birden çok hedefe aynı anda atış yapar',
      (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    final tower =
        game.buildings.firstWhere((b) => b.type == BuildingType.tower)
          ..owner = human
          ..level = 3;
    final enemy = game.gameState.players[1];
    final targets = <UnitComponent>[];
    for (var i = 0; i < 3; i++) {
      final u = UnitComponent(
        type: UnitType.leafcutter,
        owner: enemy,
        position: game.grid
            .nearestOpen(tower.position + Vector2(60, -30.0 + i * 30)),
      );
      targets.add(u);
      game.units.add(u);
      game.world.add(u);
    }
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      game.update(0.05); // 3 sn: birkaç yaylım
    }
    final damaged =
        targets.where((u) => u.dead || u.hp < u.spec.maxHp).length;
    expect(damaged, greaterThanOrEqualTo(2),
        reason: 'Sv3 kule tek hedef değil, birden çok hedef vurmalı');
  });
}
