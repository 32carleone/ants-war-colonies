import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yıkılan koloni: binaları nötrleşir, askerleri YABANİLEŞİR
/// (herkesi düşman beller) + harita sınırı ve maç karnesi testleri.
void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester,
      {bool alliance = false}) async {
    final state = GameState()
      ..startMatch(
          playerCount: 3, map: rootTriangle, enemyAlliance: alliance);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  void simulate(AntsWarsGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      game.update(0.05);
    }
  }

  testWidgets('yuvası düşen botun binaları nötr, askerleri yabani olur',
      (tester) async {
    final game = await pumpGame(tester, alliance: true); // bot1+bot2 takım 1
    final bot1 = game.gameState.players[1];
    final bot2 = game.gameState.players[2];

    // Bot1'e bir bina ve sahada bir asker ver.
    game.buildings.first.owner = bot1;
    final feral = UnitComponent(
        type: UnitType.fire, owner: bot1, position: Vector2(640, 640));
    game.world.add(feral);
    await tester.pump();
    expect(feral.combatTeam, bot2.team); // henüz müttefikler

    // Bot1'in kraliçesi düşer.
    game.nests[bot1.id]!.receiveAttack(99999);
    simulate(game, 0.2);

    expect(bot1.eliminated, isTrue);
    expect(game.buildings.first.owner, isNull,
        reason: 'Düşen koloninin binası NÖTRE dönmeli');
    expect(feral.combatTeam, isNot(bot2.team),
        reason: 'Yabani asker eski müttefikini de düşman bellemeli');
    expect(feral.combatTeam, isNegative);
  });

  testWidgets('asker harita dışına çıkamaz — anında içeri sabitlenir',
      (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    final unit = UnitComponent(
        type: UnitType.fire, owner: human, position: Vector2(640, 400));
    game.world.add(unit);
    await tester.pump();
    unit.position.setValues(-60, 900); // dışarı itilmiş gibi
    simulate(game, 0.1);
    expect(unit.position.x, greaterThanOrEqualTo(8));
    expect(unit.position.y, lessThanOrEqualTo(712));
  });

  testWidgets('maç sonunda herkes için karne dolar', (tester) async {
    final game = await pumpGame(tester);
    // İnsan dışındaki iki yuvayı düşür → zafer.
    for (final p in game.gameState.players) {
      if (p.isBot) game.nests[p.id]!.receiveAttack(99999);
    }
    simulate(game, 0.2);
    expect(game.gameState.phase, GamePhase.victory);
    final rows = game.gameState.lastPlayerStats;
    expect(rows, isNotNull);
    expect(rows!.length, 3);
    expect(rows.where((r) => r.isHuman).length, 1);
    expect(rows.where((r) => r.eliminated).length, 2);
    expect(game.gameState.totalBuildings, game.buildings.length);
  });
}
