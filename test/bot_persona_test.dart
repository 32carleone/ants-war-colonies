import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/bot_controller.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bot kişilikleri + yayılma düzeltmesi: botlar artık erken oyunda KENDİ
/// bölgelerindeki binaları alır ve yükseltir (eski davranış: 2. dakikada
/// hâlâ binasız/seviyesiz kalabiliyorlardı).
void main() {
  test('10 farklı kişilik var ve adları benzersiz', () {
    expect(botPersonas, hasLength(10));
    expect(botPersonas.map((p) => p.name).toSet(), hasLength(10));
    expect(botPersonas.first.name, 'Komutan'); // sefer dengelisi ilk sırada
  });

  testWidgets('desteden botlara FARKLI kişilikler dağıtılır',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 4, map: fourCorners);
    final game = AntsWarsGame(gameState: state, rng: math.Random(11))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(game.bots, hasLength(3));
    final names = game.bots.map((b) => b.persona.name).toSet();
    expect(names, hasLength(3),
        reason: 'Aynı maçta iki bot aynı karakteri almamalı');
  });

  testWidgets('SEFERDE kişilik sabit dengelidir', (tester) async {
    final state = GameState()
      ..startMatch(
        playerCount: 2,
        map: riverCrossing,
        mission: const MissionSetup(
          campaignKey: 'fire',
          level: 1,
          difficulty: Difficulty.normal,
          loadout: [],
        ),
      );
    final game = AntsWarsGame(gameState: state, rng: math.Random(5))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.bots.single.persona.name, 'Komutan');
  });

  testWidgets('bot erken oyunda kendi bölgesindeki binaları alır ve geliştirir',
      (tester) async {
    final state = GameState()
      ..difficulty = Difficulty.normal
      ..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final bot = game.gameState.players[1];
    int owned() =>
        game.buildings.where((b) => b.owner?.id == bot.id).length;

    // NOT: test insanı hareketsizdir; bot onu ezip maçı erken bitirmesin
    // diye insan kraliçesi her tikte tazelenir (ölümsüz kukla).
    void step(double dt) {
      game.nests[0]!.queenHp = 750;
      game.update(dt);
    }

    // 40 sn simülasyon: en az 1 bina alınmış olmalı (erken açılış).
    for (var t = 0.0; t < 40; t += 0.05) {
      step(0.05);
    }
    expect(owned(), greaterThanOrEqualTo(1),
        reason: '40 sn içinde bot kendi bölgesinden bina kapmalı');

    // 90 sn'de bölge oturmuş (2+ bina) olmalı; yükseltme için kişiliğe
    // göre pay bırakılır (Cengaver gibi savaşçılar geç yatırım yapar) —
    // 150 sn'ye KADAR en az bir yükseltme beklenir. "2. dakikada hâlâ
    // 1. seviye" şikayetinin regresyon testi.
    for (var t = 40.0; t < 90; t += 0.05) {
      step(0.05);
    }
    expect(owned(), greaterThanOrEqualTo(2),
        reason: '90 sn içinde bot bölgesini genişletmeli');
    bool upgraded() => game.buildings
        .any((b) => b.owner?.id == bot.id && b.level >= 2);
    for (var t = 90.0; t < 150 && !upgraded(); t += 0.05) {
      step(0.05);
    }
    expect(upgraded(), isTrue,
        reason: '150 sn içinde bot en az bir binayı yükseltmeli');
  });
}
