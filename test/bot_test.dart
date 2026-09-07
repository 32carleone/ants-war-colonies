import 'dart:math' as math;

import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/bot_controller.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:ants_wars/data/units.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AntsWarsGame> pumpGame(
    WidgetTester tester, {
    Difficulty difficulty = Difficulty.normal,
    int players = 2,
  }) async {
    final state = GameState()
      ..difficulty = difficulty
      ..startMatch(playerCount: players);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return game;
  }

  void simulate(AntsWarsGame game, double seconds) {
    final steps = (seconds / 0.05).round();
    for (var i = 0; i < steps; i++) {
      game.update(0.05);
    }
  }

  test('zorluk parametreleri: zor bot daha hızlı düşünür ve az israf eder', () {
    final easy = botParamsFor(Difficulty.easy);
    final hard = botParamsFor(Difficulty.hard);
    expect(hard.decisionInterval, lessThan(easy.decisionInterval));
    expect(hard.reserve, lessThan(easy.reserve));
    expect(hard.attackThreshold, lessThan(easy.attackThreshold));
    expect(hard.abilityChance, greaterThan(easy.abilityChance));
  });

  testWidgets('bot üretir ve kaynak harcar', (tester) async {
    final game = await pumpGame(tester);
    final bot = game.gameState.players[1];
    simulate(game, 20);
    // 20 sn'de pasif gelir ~40; bot harcamış olmalı (üretim/kuyruk/birim).
    final botNest = game.nests[1]!;
    final produced = botNest.population +
        botNest.productionQueue.length +
        game.units.where((u) => u.owner.id == 1).length;
    expect(produced, greaterThan(10),
        reason: 'Bot başlangıç garnizonunun üstüne üretim yapmalı');
    expect(bot.resources, lessThan(100 + 40),
        reason: 'Bot kaynakları biriktirip oturmamalı');
  });

  testWidgets('bot genişler: zamanla bina ele geçirir', (tester) async {
    final game = await pumpGame(tester);
    simulate(game, 90);
    final botBuildings =
        game.buildings.where((b) => b.owner?.id == 1).length;
    expect(botBuildings, greaterThan(0),
        reason: 'Bot 90 saniyede en az bir bina almalıydı');
  });

  testWidgets('sise saygı: görmediği düşman yuvasını bilmez', (tester) async {
    final game = await pumpGame(tester);
    final bot = game.bots.first;
    simulate(game, 3); // birkaç karar turu
    expect(bot.knownEnemyNests, isEmpty,
        reason: 'Bot maç başında insan yuvasının yerini bilemez');
    expect(bot.canSee(game.nests[0]!.position), isFalse);
  });

  testWidgets('yuvası tehdit edilen bot savunmaya çıkar', (tester) async {
    final game = await pumpGame(tester);
    final botNest = game.nests[1]!;
    // İnsan askerlerini bot yuvasının dibine ışınla (tehdit).
    for (var i = 0; i < 4; i++) {
      final u = UnitComponent(
        type: UnitType.leafcutter,
        owner: game.gameState.players[0],
        position: game.grid
            .nearestOpen(botNest.position + Vector2(80, -30.0 + i * 20)),
      );
      game.units.add(u);
      game.world.add(u);
    }
    final beforeField =
        game.units.where((u) => u.owner.id == 1).length;
    simulate(game, 6);
    final afterField = game.units.where((u) => u.owner.id == 1).length;
    expect(afterField, greaterThan(beforeField),
        reason: 'Bot garnizonunu savunmaya sürmeliydi');
  });

  testWidgets('düşman yuvasını görünce saldırıya çıkar', (tester) async {
    final game = await pumpGame(tester);
    final bot = game.bots.first;
    final humanNest = game.nests[0]!;
    // Botun bir gözcüsü insan yuvasını görsün.
    final scout = UnitComponent(
      type: UnitType.fire,
      owner: game.gameState.players[1],
      position: game.grid.nearestOpen(humanNest.position + Vector2(90, 0)),
    );
    game.units.add(scout);
    game.world.add(scout);
    // Saldırı eşiğini aşan garnizon ver.
    game.nests[1]!.returnUnits({UnitType.leafcutter: 20});

    simulate(game, 30);
    expect(bot.knownEnemyNests, contains(0));
    // Saldırı düzenlendi: insan yuvası hasar almış olmalı
    // (garnizon eridi veya kraliçe yaralandı).
    final damaged = humanNest.population < 10 || humanNest.queenHp < 300;
    expect(damaged, isTrue,
        reason: 'Bot bilinen düşman yuvasına saldırmalıydı');
  });

  testWidgets('3 kişilik oyunda botlar birbirine karşı da oynar',
      (tester) async {
    final game = await pumpGame(tester, players: 3);
    expect(game.bots.length, 2);
    simulate(game, 60);
    // İki bot da eylemde: sahada birim ya da alınmış bina.
    for (final id in [1, 2]) {
      final active = game.units.any((u) => u.owner.id == id) ||
          game.buildings.any((b) => b.owner?.id == id) ||
          game.nests[id]!.productionQueue.isNotEmpty ||
          game.nests[id]!.population > 10;
      expect(active, isTrue, reason: 'Bot $id hiçbir şey yapmamış');
    }
  });
}
