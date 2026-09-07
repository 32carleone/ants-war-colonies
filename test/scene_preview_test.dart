import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tek seferlik sahne ön izlemesi (dokümantasyon amaçlı).
void main() {
  testWidgets('sahne: yürüyen ordu', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(42))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // deterministik sahne için botlar sessiz

    final nest = game.nests[0]!;
    // Çeşitlilik için garnizona her tipten asker ekle.
    nest.returnUnits({
      UnitType.leafcutter: 4,
      UnitType.trapjaw: 4,
      UnitType.wood: 4,
    });
    game.deployFromNest(nest, 1.0, Vector2(640, 360));

    for (var i = 0; i < 80; i++) {
      game.update(0.05); // 4 sn yürüyüş
    }
    await tester.pump();

    await expectLater(
      find.byType(GameWidget<AntsWarsGame>),
      matchesGoldenFile('goldens/scene_walk.png'),
    );
  });

  testWidgets('sahne: orta köprüde savaş', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(42))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // deterministik sahne için botlar sessiz

    // İki ordu da merkezde karşılaşsın.
    final n0 = game.nests[0]!;
    final n1 = game.nests[1]!;
    n0.returnUnits({UnitType.leafcutter: 3, UnitType.wood: 3});
    n1.returnUnits({UnitType.trapjaw: 3, UnitType.fire: 3});
    game.deployFromNest(n0, 1.0, Vector2(620, 340));
    game.deployFromNest(n1, 1.0, Vector2(660, 380));

    for (var i = 0; i < 130; i++) {
      game.update(0.05); // 6.5 sn: temas + çatışma anı
    }
    await tester.pump();

    await expectLater(
      find.byType(GameWidget<AntsWarsGame>),
      matchesGoldenFile('goldens/scene_battle.png'),
    );
  });

  testWidgets('sahne: takım renkleri (sissiz demo)', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(42))
      ..countdown = 0
      ..fogEnabled = false;
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    // Binaları iki tarafa paylaştır (renk tonlaması görünsün).
    for (var i = 0; i < game.buildings.length; i++) {
      game.buildings[i].owner = game.gameState.players[i % 2];
    }
    final n0 = game.nests[0]!;
    final n1 = game.nests[1]!;
    n0.returnUnits({UnitType.leafcutter: 3, UnitType.wood: 3});
    n1.returnUnits({UnitType.trapjaw: 3, UnitType.fire: 3});
    game.deployFromNest(n0, 1.0, Vector2(500, 300));
    game.deployFromNest(n1, 1.0, Vector2(800, 420));
    for (var i = 0; i < 90; i++) {
      game.update(0.05);
    }
    await tester.pump();

    await expectLater(
      find.byType(GameWidget<AntsWarsGame>),
      matchesGoldenFile('goldens/scene_colors.png'),
    );
  });

  testWidgets('sahne: sürükleme ön izleme (panel + ok + yerleşim)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(42))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // deterministik sahne için botlar sessiz

    final nest = game.nests[0]!;
    final ic = game.inputController;
    ic.handleTap(nest.position.clone()); // yuva vurgulanır
    ic.beginDrag(nest.position.clone());
    ic.updateDrag(Vector2(700, -150)); // nehrin karşısına sürükle
    game.update(0.016);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(GameWidget<AntsWarsGame>),
      matchesGoldenFile('goldens/scene_drag.png'),
    );
  });
}
