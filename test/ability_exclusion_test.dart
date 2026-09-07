import 'dart:math' as math;

import 'package:ants_wars/data/abilities.dart';
import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// YETENEK YASAK BÖLGESİ: hedefli yetenek RAKİP yuvasının dibine atılamaz
/// ("takviyeyle oto-savunmayı boşalt, ateş çemberiyle sil" açığı).
/// Kendi yuvanın dibi serbesttir (savunma yetenekleri).
void main() {
  Future<AntsWarsGame> pump(WidgetTester tester) async {
    final state = GameState()
      ..abilityLoadout = [
        AbilityType.reinforce,
        AbilityType.lightning,
        AbilityType.rain,
      ]
      ..startMatch(playerCount: 2, map: riverCrossing);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    for (var i = 0; i < game.abilityCooldowns.length; i++) {
      game.abilityCooldowns[i] = 0; // açılış cooldown'unu atla
    }
    return game;
  }

  testWidgets('rakip yuvanın dibine hedefli yetenek atılamaz',
      (tester) async {
    final game = await pump(tester);
    final human = game.gameState.humanPlayer!;
    final enemyNest = game.nests[game.gameState.players[1].id]!;

    final near = enemyNest.position + Vector2(60, 0);
    expect(game.abilityAllowedAt(human, near), isFalse);
    final unitsBefore = game.units.length;
    expect(game.useHumanAbility(0, near), isFalse,
        reason: 'Takviye rakip yuva dibine atılAMAmalı');
    expect(game.units.length, unitsBefore,
        reason: 'Asker doğmamalı, cooldown yanmamalı');
    expect(game.abilityCooldowns[0], 0);
  });

  testWidgets('sınırın dışına ve KENDİ yuvanın dibine atılabilir',
      (tester) async {
    final game = await pump(tester);
    final human = game.gameState.humanPlayer!;
    final myNest = game.nests[human.id]!;
    final enemyNest = game.nests[game.gameState.players[1].id]!;

    // Kendi yuvanın dibi serbest (savunma).
    final ownSide = myNest.position + Vector2(40, 0);
    expect(game.abilityAllowedAt(human, ownSide), isTrue);
    expect(game.useHumanAbility(0, ownSide), isTrue);

    // Yasak yarıçapın hemen dışı serbest.
    final outside = enemyNest.position +
        Vector2(kAbilityNestExclusion + 30, 0);
    expect(game.abilityAllowedAt(human, outside), isTrue);

    // Bot da insan yuvasının dibine atamaz (adil oyun).
    final bot = game.gameState.players[1];
    expect(
        game.abilityAllowedAt(bot, myNest.position + Vector2(50, 0)),
        isFalse);
  });
}
