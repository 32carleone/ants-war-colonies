import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Haritaların GERÇEK oyun görüntüleri: `--update-goldens` ile
/// test/goldens/map_[id].png üretir. Bu PNG'ler assets/images/ altına
/// kopyalanıp Savaş Kur ekranındaki kartlarda birebir kullanılır
/// (tool/update_map_previews.sh). Normal koşuda görsel gerileme testidir.
void main() {
  for (final map in [...allMaps, tutorialMap]) {
    testWidgets('harita görseli — ${map.id}', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState()
        ..startMatch(playerCount: map.playerCount, map: map);
      // Sabit tohum: yuva dağılımı deterministik olsun ki golden stabil kalsın.
      final game = AntsWarsGame(gameState: state, rng: math.Random(42))
        ..countdown = 0
        ..fogEnabled = false; // ön izleme sissiz
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(GameWidget<AntsWarsGame>),
        matchesGoldenFile('goldens/map_${map.id}.png'),
      );
    });
  }
}
