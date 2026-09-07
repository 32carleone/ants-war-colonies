import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AÇILIŞ EVRESİ: botun ilk hedefi yayılmak/gelişmektir — Kâbus bile
/// açılışta (55 sn) rakip yuvaya intihar hücumu YAPMAZ; kollarını kendi
/// yakasında tutar ve bina toplar.
void main() {
  testWidgets('Kâbus botu açılışta üsse saldırmaz, yayılır',
      (tester) async {
    final state = GameState()
      ..difficulty = Difficulty.nightmare
      ..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(9))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final bot = state.players[1];
    final humanNest = game.nests[0]!;

    for (var t = 0.0; t < 45; t += 0.05) {
      humanNest.queenHp = 750; // insan kuklası ölmesin
      game.update(0.05);
      // Açılış boyunca hiçbir bot askeri insan yuvasının dibine inmemeli.
      if ((t * 20).round() % 40 == 0) {
        for (final u in game.units) {
          if (u.dead || u.owner.id != bot.id) continue;
          expect(u.position.distanceTo(humanNest.position),
              greaterThan(300),
              reason: 'Açılışta (t=${t.toStringAsFixed(0)}) bot kolu '
                  'insan üssüne yürümemeli');
        }
      }
    }
    // Açılış verimli geçmeli: en az 2 bina alınmış olmalı.
    final owned =
        game.buildings.where((b) => b.owner?.id == bot.id).length;
    expect(owned, greaterThanOrEqualTo(2),
        reason: 'Açılış yayılma/gelişme evresidir');
  });

  testWidgets('Kâbus botu yükseltme ÇEKER (birikim regresyonu)',
      (tester) async {
    final state = GameState()
      ..difficulty = Difficulty.nightmare
      ..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(9))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final bot = state.players[1];
    bool upgraded() => game.buildings
        .any((b) => b.owner?.id == bot.id && b.level >= 2);
    for (var t = 0.0; t < 120 && !upgraded(); t += 0.05) {
      game.nests[0]!.queenHp = 750;
      game.update(0.05);
    }
    expect(upgraded(), isTrue,
        reason: 'Kâbus 120 sn içinde en az bir yükseltme çekmeli');
  });

  testWidgets('tam program: 150 sn içinde yayılmış ve gelişmiş olmalı',
      (tester) async {
    final state = GameState()
      ..difficulty = Difficulty.nightmare
      ..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(21))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final bot = state.players[1];
    for (var t = 0.0; t < 150; t += 0.05) {
      game.nests[0]!.queenHp = 750;
      game.update(0.05);
    }
    final owned =
        game.buildings.where((b) => b.owner?.id == bot.id).toList();
    expect(owned.length, greaterThanOrEqualTo(3),
        reason: 'Bot haritaya yayılmalı (ele geçirme felci regresyonu)');
    expect(owned.any((b) => b.level >= 3), isTrue,
        reason: 'Gelişme evresi yükseltme çekmeli');
  });
}
