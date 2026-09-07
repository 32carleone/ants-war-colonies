import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
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
    await tester.pump(const Duration(milliseconds: 100));
    game.bots.clear(); // sistem testleri sessiz ortam ister
    game.update(0.05); // sis ızgarası dolsun
    return game;
  }

  testWidgets('başlangıçta kendi yuva çevresi görünür, düşman tarafı karanlık',
      (tester) async {
    final game = await pumpGame(tester);
    final own = game.nests[0]!.position;
    final enemy = game.nests[1]!.position;

    expect(game.fog.isVisible(own), isTrue);
    expect(game.fog.isVisible(enemy), isFalse);
    expect(game.fog.isExplored(enemy), isFalse);
  });

  testWidgets('yürüyen askerler yol boyunca keşfeder; düşman yuvası görünür olur',
      (tester) async {
    final game = await pumpGame(tester);
    final own = game.nests[0]!;
    final enemy = game.nests[1]!;

    game.deployFromNest(own, 1.0, enemy.position + Vector2(0, 40));
    for (var i = 0; i < 500; i++) {
      game.update(0.05); // 25 sn: haritayı geç
    }

    expect(game.fog.isExplored(enemy.position), isTrue);
    // Ordu nehri iki köprüden birinden aştı — en az biri keşfedilmiş olmalı.
    final northBridge = Vector2(630, 160);
    final southBridge = Vector2(650, 552);
    expect(
        game.fog.isExplored(northBridge) || game.fog.isExplored(southBridge),
        isTrue,
        reason: 'Yol üzerindeki köprü keşfedilmiş olmalı');
  });

  testWidgets('keşfedilen alan, asker ayrılınca görünür olmaktan çıkar ama '
      'keşfedilmiş kalır', (tester) async {
    final game = await pumpGame(tester);
    final own = game.nests[0]!;
    // Harita merkezine doğru, yuva görüşünün (190) kesin dışında bir nokta.
    final toCenter =
        (Vector2(kGameWidth / 2, kGameHeight / 2) - own.position).normalized();
    final scout = game.grid.nearestOpen(own.position + toCenter * 280);

    game.deployFromNest(own, 1.0, scout);
    for (var i = 0; i < 200; i++) {
      game.update(0.05);
    }
    expect(game.fog.isVisible(scout), isTrue);

    // Hepsini eve çağır.
    for (final u in List.of(game.units)) {
      u.orderReturnToNest();
    }
    for (var i = 0; i < 300; i++) {
      game.update(0.05);
    }

    expect(game.fog.isVisible(scout), isFalse,
        reason: 'Asker ayrıldı — canlı görüş kalkmalı');
    expect(game.fog.isExplored(scout), isTrue,
        reason: 'Arazi hafızada kalmalı');
  });

  testWidgets('sis kapatılınca her yer görünür', (tester) async {
    final game = await pumpGame(tester);
    game.fogEnabled = false;
    expect(game.fog.isVisible(game.nests[1]!.position), isTrue);
  });

  testWidgets('insan elenince seyirci modu: her yer görünür', (tester) async {
    final game = await pumpGame(tester);
    game.gameState.players[0].eliminated = true;
    game.update(0.05);
    expect(game.fog.isVisible(game.nests[1]!.position), isTrue);
  });

  testWidgets('harita dışı noktalar görünmez sayılır', (tester) async {
    final game = await pumpGame(tester);
    expect(game.fog.isVisible(Vector2(-50, -50)), isFalse);
    expect(game.fog.isVisible(Vector2(5000, 100)), isFalse);
  });
}
