import 'dart:math' as math;

import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bina çevresi ikon butonları: panel yerine binaya dokununca çevresinde
/// yükselt / değiştir butonları belirir; değiştir → dönüşüm seçenekleri.
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

  /// İnsana bir bina verir ve seçer.
  Building capture(AntsWarsGame game) {
    final human = game.gameState.humanPlayer!;
    final b = game.buildings.first..owner = human;
    game.inputController.handleTap(b.position.clone());
    return b;
  }

  testWidgets('binaya dokununca seçilir, boş zemine dokununca bırakılır',
      (tester) async {
    final game = await pumpGame(tester);
    final b = capture(game);
    expect(game.inputController.selectedBuilding, b);
    expect(game.inputController.convertOpen, isFalse);

    game.inputController.handleTap(Vector2(640, 620));
    expect(game.inputController.selectedBuilding, isNull);
  });

  testWidgets('yükselt butonu parası yetiyorsa seviye atlatır',
      (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    final b = capture(game);
    human.resources = 500;
    final cost = b.upgradeCost;

    // Üst bara yakın binalarda butonlar ALTA iner (y<190 eşiği).
    final vy = b.position.y < 190 ? 47.0 : -47.0;
    game.inputController.handleTap(b.position + Vector2(-47, vy));
    expect(b.level, 2);
    expect(human.resources, 500 - cost);
  });

  testWidgets('değiştir butonu dönüşüm seçeneklerini açar ve dönüştürür',
      (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    final b = capture(game);
    final oldType = b.type;
    human.resources = 500;

    // Değiştir → seçenekler açılır (buton üst bara yakınsa altta).
    final vy = b.position.y < 190 ? 47.0 : -47.0;
    game.inputController.handleTap(b.position + Vector2(47, vy));
    expect(game.inputController.convertOpen, isTrue);

    // İlk seçenek: farklı bir tipe dönüştürür ve maliyeti düşer
    // (optA = değiştir butonu + (15, 50)).
    game.inputController.handleTap(b.position + Vector2(62, vy + 50));
    expect(b.type, isNot(oldType));
    expect(human.resources, 500 - kConvertCost);
    expect(game.inputController.convertOpen, isFalse);
  });

  testWidgets('parası yetmeyince dönüşüm gerçekleşmez', (tester) async {
    final game = await pumpGame(tester);
    final human = game.gameState.humanPlayer!;
    final b = capture(game);
    final oldType = b.type;
    human.resources = 0;

    final vy = b.position.y < 190 ? 47.0 : -47.0;
    game.inputController.handleTap(b.position + Vector2(47, vy));
    game.inputController.handleTap(b.position + Vector2(62, vy + 50));
    expect(b.type, oldType);
  });

  testWidgets('üst kenardaki binada butonlar ALTA iner (bar altında kalmaz)',
      (tester) async {
    // Ege Adaları: (300,95) teki ekonomi binası üst kenara çok yakındır.
    final state = GameState()
      ..startMatch(playerCount: 3, map: threeIslands);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    final human = game.gameState.humanPlayer!;
    final b = game.buildings.firstWhere((b) => b.position.y < 135)
      ..owner = human;
    game.inputController.handleTap(b.position.clone());
    expect(game.inputController.selectedBuilding, b);
    human.resources = 500;

    // ÜSTTEKİ eski konum artık buton değildir...
    game.inputController.handleTap(b.position + Vector2(-47, -47));
    expect(b.level, 1);
    // ...butonlar ALTTADIR ve tıklanabilir.
    game.inputController.handleTap(b.position.clone());
    game.inputController.handleTap(b.position + Vector2(-47, 47));
    expect(b.level, 2);
  });
}
