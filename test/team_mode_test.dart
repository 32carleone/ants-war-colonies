import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AntsWarsGame> pumpTeamGame(WidgetTester tester) async {
    final state = GameState()
      ..startMatch(playerCount: 4, teamMode: true);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  test('2v2 kurulum: takımlar ve renkler doğru', () {
    final state = GameState()..startMatch(playerCount: 4, teamMode: true);
    expect(state.players.length, 4);
    expect(state.players[0].team, 0); // insan
    expect(state.players[1].team, 0); // müttefik bot
    expect(state.players[2].team, 1);
    expect(state.players[3].team, 1);
    expect(state.players[0].isBot, isFalse);
    expect(state.players.skip(1).every((p) => p.isBot), isTrue);
  });

  testWidgets('müttefikler aynı tarafta doğar', (tester) async {
    final game = await pumpTeamGame(tester);
    final n0 = game.nests[0]!.position;
    final n1 = game.nests[1]!.position;
    final sameSide = (n0.x < kGameWidth / 2) == (n1.x < kGameWidth / 2);
    expect(sameSide, isTrue, reason: 'Takım 0 aynı yarıda olmalı');
  });

  testWidgets('müttefik askerler birbirine saldırmaz', (tester) async {
    final game = await pumpTeamGame(tester);
    final human = game.gameState.players[0];
    final ally = game.gameState.players[1];
    // Nötr kulelerin menzilinden uzak, harita merkezine yakın güvenli nokta.
    final a = UnitComponent(
        type: UnitType.fire,
        owner: human,
        position: game.grid.nearestOpen(Vector2(640, 235)));
    final b = UnitComponent(
        type: UnitType.fire,
        owner: ally,
        position: game.grid.nearestOpen(Vector2(640, 252)));
    for (final u in [a, b]) {
      game.units.add(u);
      game.world.add(u);
    }
    for (var i = 0; i < 100; i++) {
      game.update(0.05);
    }
    expect(a.dead, isFalse);
    expect(b.dead, isFalse);
    expect(a.target, isNull);
  });

  testWidgets('sis müttefik görüşünü paylaşır', (tester) async {
    final game = await pumpTeamGame(tester);
    game.update(0.05);
    final allyNest = game.nests[1]!.position;
    expect(game.fog.isVisible(allyNest), isTrue,
        reason: 'Müttefik yuvasının çevresi görünür olmalı');
    final enemyNest = game.nests[2]!.position;
    expect(game.fog.isVisible(enemyNest), isFalse);
  });

  testWidgets('zafer: düşman TAKIMIN ikisi de elenince', (tester) async {
    final game = await pumpTeamGame(tester);
    game.nests[2]!.receiveAttack(9999);
    game.update(0.05);
    expect(game.gameState.phase, GamePhase.playing,
        reason: 'Tek düşman elendi — maç sürmeli');
    game.nests[3]!.receiveAttack(9999);
    game.update(0.05);
    expect(game.gameState.phase, GamePhase.victory);
  });

  testWidgets('geri sayım: süre boyunca emir/simülasyon yok', (tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7));
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    expect(game.countdown, greaterThan(0));
    game.deployFromNest(game.nests[0]!, 1.0, Vector2(400, 300));
    expect(game.unitCount, 0, reason: 'Geri sayımda asker çıkarılamaz');

    for (var i = 0; i < 110; i++) {
      game.update(0.05); // 5.5 sn
    }
    expect(game.countdown, lessThanOrEqualTo(0));
    game.deployFromNest(game.nests[0]!, 1.0,
        game.grid.nearestOpen(game.nests[0]!.position + Vector2(120, 0)));
    expect(game.unitCount, 10);
  });

  testWidgets('müttefik bot yığılmaz: boştaki ordusu düşman yakasına ilerler',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 4, teamMode: true);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Yalnız MÜTTEFİK bot (id 1) aktif kalsın — davranış izole edilsin.
    game.bots.removeWhere((b) => b.player.id != 1);

    final ally = state.players[1];
    final allyNest = game.nests[1]!;
    allyNest.garrison.clear(); // garnizon boş: yalnız saha ordusu test edilir
    // AÇILIŞ EVRESİNİ ATLA (5 bina = gelişmiş): ilerleme serbest kalsın.
    final near = List.of(game.buildings)
      ..sort((a, b) => a.position
          .distanceToSquared(allyNest.position)
          .compareTo(b.position.distanceToSquared(allyNest.position)));
    for (final b in near.take(5)) {
      b.owner = ally;
    }

    // Müttefik yuvasının yakınına (binalardan/kulelerden uzağa) 8 asker koy.
    final units = <UnitComponent>[];
    for (var i = 0; i < 8; i++) {
      final u = UnitComponent(
        type: UnitType.wood,
        owner: ally,
        position: game.grid.nearestOpen(allyNest.position +
            Vector2(20.0 + (i % 4) * 20, 120.0 + (i ~/ 4) * 24)),
      );
      units.add(u);
      game.units.add(u);
      game.world.add(u);
    }
    await tester.pump();

    // Hedef: haritanın karşı yakası (yuvanın aynası).
    final mirror = Vector2(
        kGameWidth - allyNest.position.x, kGameHeight - allyNest.position.y);
    double meanDist() {
      var sum = 0.0;
      var n = 0;
      for (final u in units) {
        if (u.dead) continue;
        sum += u.position.distanceTo(mirror);
        n++;
      }
      return n == 0 ? 0 : sum / n;
    }

    final before = meanDist();
    for (var i = 0; i < 280; i++) {
      game.update(0.05); // 14 sn
    }
    expect(meanDist(), lessThan(before - 200),
        reason: 'Boştaki müttefik ordusu köşede yığılmak yerine '
            'düşman yakasına doğru ilerlemeliydi');
  });
}
