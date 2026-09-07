import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:ants_wars/models/building.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // sistem testleri sessiz ortam ister (bot müdahalesi yok)
    return game;
  }

  UnitComponent spawn(
      AntsWarsGame game, UnitType type, int playerIdx, Vector2 pos) {
    final u = UnitComponent(
      type: type,
      owner: game.gameState.players[playerIdx],
      position: game.grid.nearestOpen(pos),
    );
    game.units.add(u);
    game.world.add(u);
    return u;
  }

  void simulate(AntsWarsGame game, double seconds) {
    final steps = (seconds / 0.05).round();
    for (var i = 0; i < steps; i++) {
      game.update(0.05);
    }
  }

  testWidgets('karşılaşan iki ordu emir olmadan savaşır', (tester) async {
    final game = await pumpGame(tester);
    for (var i = 0; i < 3; i++) {
      spawn(game, UnitType.fire, 0, Vector2(380, 280 + i * 20));
      spawn(game, UnitType.fire, 1, Vector2(450, 280 + i * 20));
    }
    simulate(game, 30);
    final alive = game.units.where((u) => !u.dead).length;
    expect(alive, lessThan(6), reason: 'Hiç kayıp yok — savaş başlamamış');
  });

  testWidgets('counter: menzilli Orman Karıncası tankı yener (eşit maliyet)',
      (tester) async {
    final game = await pumpGame(tester);
    // İzole düello: yuva garnizonları boşaltılır ki kite ile yuva savunma
    // alanına sürüklenen savaşa OTOMATİK SAVUNMA karışmasın.
    for (final n in game.nests.values) {
      n.garrison.clear();
    }
    // 3 Orman (90) vs 2 Kesici (100). Ormanlar düşmana doğru yürütülür,
    // menzile girince otomatik savaş başlar.
    final woods = [
      for (var i = 0; i < 3; i++)
        spawn(game, UnitType.wood, 0, Vector2(350, 280 + i * 25)),
    ];
    for (var i = 0; i < 2; i++) {
      spawn(game, UnitType.leafcutter, 1, Vector2(480, 290 + i * 25));
    }
    for (final w in woods) {
      w.orderMove(game.grid.nearestOpen(Vector2(480, 300)));
    }
    simulate(game, 40);
    final woodAlive =
        game.units.where((u) => !u.dead && u.type == UnitType.wood).length;
    final leafAlive = game.units
        .where((u) => !u.dead && u.type == UnitType.leafcutter)
        .length;
    expect(leafAlive, 0, reason: 'Tanklar menzilliye karşı ölmeliydi');
    expect(woodAlive, greaterThan(0));
  });

  testWidgets('Kapan Çene ilk vuruşta kritik vurur (tek vuruşta Orman düşer)',
      (tester) async {
    final game = await pumpGame(tester);
    final tj = spawn(game, UnitType.trapjaw, 0, Vector2(400, 300));
    final wood = spawn(game, UnitType.wood, 1, Vector2(412, 300));
    simulate(game, 1.5);
    expect(wood.dead, isTrue,
        reason: 'Kritik ilk vuruş (14×1.5×3=63) 35 canlı Ormanı düşürmeli');
    expect(tj.dead, isFalse);
  });

  testWidgets('güç binası sahibinin hasarını artırır', (tester) async {
    final game = await pumpGame(tester);
    final u = spawn(game, UnitType.wood, 0, Vector2(300, 200));
    final dummy = spawn(game, UnitType.fire, 1, Vector2(900, 620));
    game.update(0.05);

    final before = u.computeAttackDamage(dummy);
    final power = game.buildings
        .firstWhere((b) => b.type == BuildingType.power)
      ..owner = game.gameState.players[0];
    final after = u.computeAttackDamage(dummy);
    expect(after, closeTo(before * (1 + power.powerBonus), 0.01));
  });

  testWidgets('yuva kuşatması: garnizon erir, kraliçe ölür, oyun biter',
      (tester) async {
    final game = await pumpGame(tester);
    final enemyNest = game.nests[1]!;
    for (var i = 0; i < 10; i++) {
      spawn(game, UnitType.leafcutter, 0,
          enemyNest.position + Vector2(60, -55 + i * 12));
    }
    simulate(game, 25);
    expect(enemyNest.destroyed, isTrue);
    expect(game.gameState.players[1].eliminated, isTrue);
    expect(game.gameState.phase, GamePhase.victory);
  });

  testWidgets('hareket emri savaşı böler (geri çekilme mümkün)',
      (tester) async {
    final game = await pumpGame(tester);
    final u0 = spawn(game, UnitType.leafcutter, 0, Vector2(400, 300));
    spawn(game, UnitType.leafcutter, 1, Vector2(415, 300));
    simulate(game, 2);
    expect(u0.target, isNotNull, reason: 'Savaş kilidi kurulmalıydı');

    u0.orderMove(game.grid.nearestOpen(Vector2(200, 200)));
    expect(u0.target, isNull);
    expect(u0.isMoving, isTrue);
  });
}
