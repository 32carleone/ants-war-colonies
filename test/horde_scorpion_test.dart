import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/scorpion_component.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yağmacı akrep + Hayatta Kalma modu davranış testleri.
void main() {
  Future<AntsWarsGame> pump(WidgetTester tester, GameState state) async {
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    return game;
  }

  void simulate(AntsWarsGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      game.update(0.05);
    }
  }

  testWidgets('akrep: kemiren orduya ölür, ödül verir ve GERİ GELMEZ',
      (tester) async {
    final state = GameState()
      ..startMatch(playerCount: 2, map: himalayaPasses);
    final game = await pump(tester, state);

    expect(game.scorpions, hasLength(2),
        reason: 'Himalaya iki akrep taşımalı');
    final sc = game.scorpions.first;
    final human = state.humanPlayer!;
    final goldBefore = human.resources;

    // Akrebin dibine güçlü bir av ekibi kur (kemirme menzilinde).
    for (var i = 0; i < 12; i++) {
      final u = UnitComponent(
        type: UnitType.leafcutter,
        owner: human,
        position: sc.position + Vector2(((i % 4) - 1.5) * 14, (i ~/ 4) * 14 - 14),
      );
      game.units.add(u);
      game.world.add(u);
    }
    await tester.pump();

    simulate(game, 30);
    expect(sc.alive, isFalse, reason: '12 kesici 30 sn içinde avlamalı');
    expect(human.resources, greaterThan(goldBefore + 100),
        reason: 'Son darbeyi vuran 150 altın ödül almalı');

    // DİRİLME YOK: ölen akrep süre geçse de geri gelmez — bölge
    // maç sonuna dek güvene düşer.
    for (final u in List.of(game.units)) {
      u.removeFromParent();
    }
    await tester.pump();
    simulate(game, ScorpionComponent.respawnAfter + 30);
    expect(sc.alive, isFalse,
        reason: 'Akrep öldüyse ÖLÜ kalmalı (dirilme kaldırıldı)');
  });

  testWidgets('akrep menzilindeki askeri sokar (takım ayırmaz)',
      (tester) async {
    final state = GameState()
      ..startMatch(playerCount: 2, map: himalayaPasses);
    final game = await pump(tester, state);
    final sc = game.scorpions.first;

    final victim = UnitComponent(
      type: UnitType.fire,
      owner: state.players[1], // bot askeri de sokulur
      position: sc.position + Vector2(60, 0),
    );
    game.units.add(victim);
    game.world.add(victim);
    await tester.pump();

    simulate(game, 6);
    expect(victim.hp, lessThan(victim.spec.maxHp),
        reason: 'Akrep menzilindeki askeri kovalayıp sokmalı');
  });

  testWidgets('horde: dalgalar doğar, hepsi yabani, kraliçe düşünce skor',
      (tester) async {
    final state = GameState()
      ..startMatch(playerCount: 2, map: hordeCrossing, horde: true);
    final game = await pump(tester, state);

    expect(state.horde, isTrue);
    expect(state.players[1].eliminated, isTrue,
        reason: 'Yabani kaynak oyuncusu baştan elenmiş olmalı');
    expect(game.nests[1]!.destroyed, isTrue,
        reason: 'Yabani yuva baştan yıkık olmalı');

    simulate(game, 40);
    expect(game.hordeWave, greaterThanOrEqualTo(2),
        reason: '40 sn içinde en az 2 dalga gelmiş olmalı '
            '(ilk dalga 12. sn, aralık 24-dalga)');
    final ferals =
        game.units.where((u) => !u.dead && u.owner.eliminated).toList();
    expect(ferals, isNotEmpty);
    expect(ferals.first.combatTeam, isNegative,
        reason: 'Dalga askerleri yabani (herkese düşman) olmalı');
    expect(state.phase, GamePhase.playing,
        reason: 'Yabaniler elendi diye zafer İLAN EDİLMEMELİ');

    // Kraliçe düşer → yenilgi + dalga kaydı + karne.
    game.nests[0]!.receiveAttack(999999);
    simulate(game, 0.3);
    expect(state.phase, GamePhase.defeat);
    expect(state.lastHordeWave, game.hordeWave);
    expect(state.lastStats, isNotNull);
  });
}
