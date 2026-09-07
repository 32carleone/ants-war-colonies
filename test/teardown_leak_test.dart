import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/main.dart';
import 'package:ants_wars/ui/main_menu.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Maç sonrası menü kasması" regresyonu: GameWidget sökülünce Flame
/// çocukların onRemove'unu ÇAĞIRMAZ — AntsWarsGame.onRemove ağacı gezip
/// temizliği elle tetikler (Picture/Image native belleği bırakılır).
/// Ayrıca menüde fazladan canlı ticker kalmamalı.
void main() {
  testWidgets('maç sökülünce bileşen temizliği çalışır, ticker sızmaz',
      (tester) async {
    SharedPreferences.setMockInitialValues({'tutorial_prompted': true});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final gameState = GameState();
    await tester.pumpWidget(AntsWarsApp(gameState: gameState));
    await tester.pump(const Duration(milliseconds: 300));
    final fresh = SchedulerBinding.instance.transientCallbackCount;

    gameState.startMatch(playerCount: 2, map: riverCrossing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Karşılaşma ekranını geç (oyun duraklıyken birimler mount olmaz).
    await tester.tap(find.text('SAVAŞA BAŞLA'));
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<AntsWarsGame>>(
            find.byType(GameWidget<AntsWarsGame>))
        .game!;
    // Geri sayımı atla ve sahaya asker çıkar (ön koşul).
    game.countdown = 0;
    final human = gameState.humanPlayer!;
    game.deployFromNest(
        game.nests[human.id]!, 1.0, game.nests[human.id]!.position);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.units, isNotEmpty,
        reason: 'Maç akarken sahada asker olmalı (test ön koşulu)');

    gameState.endMatch(humanWon: true);
    await tester.pump(const Duration(milliseconds: 300));
    gameState.backToMenu();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MainMenu), findsOneWidget);

    // onRemove zinciri çalıştıysa birimler listeden düşmüştür
    // (UnitComponent.onRemove) — Picture/Image temizliği de aynı zincirde.
    expect(game.units, isEmpty,
        reason: 'Söküm çocukların onRemove temizliğini tetiklemeli');
    expect(SchedulerBinding.instance.transientCallbackCount, fresh,
        reason: 'Maç sonrası menüde fazladan canlı ticker kalmamalı');
  });
}
