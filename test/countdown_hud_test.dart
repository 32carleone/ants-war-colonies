import 'dart:math' as math;

import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/ui/game_hud.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geri sayım sırasında: HARİTA görünür (bileşenler monte olur) ve
/// % (gönderme oranı) barı ayarlanabilir; oyun mantığı yine donuktur.
void main() {
  testWidgets('geri sayımda sahne monte olur ve % barı değiştirilebilir',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7));
    // countdown SIFIRLANMAZ — sayım aktifken test edilir.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          GameWidget(game: game),
          DeploySlider(game: game),
        ]),
      ),
    ));
    await tester.pump();
    // Kaydırıcı 300 ms'lik tazeleme zamanlayıcısıyla görünür olur.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    game.bots.clear();

    expect(game.countdown, greaterThan(0));
    // Harita/bileşenler monte: dünya boş değil.
    expect(game.world.children.isNotEmpty, isTrue,
        reason: 'Geri sayımda da sahne monte olmalı (harita görünmeli)');

    // % barı sayım sırasında ayarlanabilir (kamanın üst kısmına dokun).
    // Kama artık SOL kenardadır (üretim butonlarıyla yer değişti).
    final before = game.deployFraction.value;
    await tester.tapAt(const Offset(23, 300));
    await tester.pump(const Duration(milliseconds: 350));
    expect(game.countdown, greaterThan(0));
    expect(game.deployFraction.value, isNot(before));
    expect(game.deployFraction.value, greaterThan(0.8));
  });
}
