import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stratejik bot katmanı: toplanıp TOPLUCA vurma + stratejik nöbet.
void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
    final state = GameState()
      ..difficulty = Difficulty.normal
      ..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return game;
  }

  testWidgets('stratejik bot toplanıp orduyla TOPLUCA saldırır',
      (tester) async {
    final game = await pumpGame(tester);
    final bot = game.bots.first;
    final humanNest = game.nests[0]!;
    // Bot düşman yuvasını biliyor ve büyük garnizonu var.
    bot.knownEnemyNests.add(0);
    game.nests[1]!.garrison[UnitType.fire] = 22;
    // AÇILIŞ EVRESİNİ ATLA: 5 bina = gelişmiş sayılır, taarruz serbest
    // (açılışta bot bilerek saldırmaz — bot_opening_test bunu doğrular).
    final own = List.of(game.buildings)
      ..sort((a, b) => a.position
          .distanceToSquared(game.nests[1]!.position)
          .compareTo(b.position.distanceToSquared(game.nests[1]!.position)));
    for (final b in own.take(5)) {
      b.owner = bot.player;
    }

    var massAssault = false;
    for (var i = 0; i < 900; i++) {
      game.update(0.05); // 45 sn
      var near = 0;
      for (final u in game.units) {
        if (u.dead || u.owner.id != 1) continue;
        if (u.position.distanceToSquared(humanNest.position) < 220 * 220) {
          near++;
        }
      }
      if (near >= 6) {
        massAssault = true;
        break;
      }
    }
    expect(massAssault, isTrue,
        reason: 'Bot ordusunu toplayıp kalabalık halde yuvaya varmalıydı');
  });

  testWidgets('stratejik nöbet: cephedeki kulesinde nöbetçi tutar',
      (tester) async {
    final game = await pumpGame(tester);
    final bot = game.bots.first;
    final botPlayer = game.gameState.players[1];
    bot.knownEnemyNests.add(0);
    // Bota cepheye yakın bir kule ver + garnizon.
    final tower = game.buildings
        .where((b) => b.type == BuildingType.tower)
        .reduce((a, b) => a.position
                    .distanceToSquared(game.nests[1]!.position) <
                b.position.distanceToSquared(game.nests[1]!.position)
            ? a
            : b)
      ..owner = botPlayer;
    // Bol garnizon + para: açılış yalın-üretim/birikim kuralları testi
    // etkilemesin — yalnız NÖBET davranışı ölçülür.
    game.nests[1]!.garrison[UnitType.fire] = 30;
    botPlayer.resources = 400;

    var maxGuards = 0;
    for (var i = 0; i < 500; i++) {
      game.update(0.05); // 25 sn
      var guards = 0;
      for (final u in game.units) {
        if (u.dead || u.owner.id != 1) continue;
        if (u.position.distanceToSquared(tower.position) < 95 * 95) guards++;
      }
      if (guards > maxGuards) maxGuards = guards;
    }
    expect(maxGuards, greaterThanOrEqualTo(2),
        reason: 'Kulede en az bir nöbet kolu konuşlanmalıydı '
            '(gözlenen: $maxGuards)');
  });
}
