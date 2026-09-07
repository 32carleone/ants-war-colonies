import 'dart:math' as math;

import 'package:ants_wars/data/abilities.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ability_effects.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();
    for (final n in game.nests.values) {
      n.garrison.clear(); // otomatik savunma karışmasın
    }
    return game;
  }

  UnitComponent spawn(
      AntsWarsGame game, UnitType type, int playerIdx, Vector2 pos) {
    final u = UnitComponent(
      type: type,
      owner: game.gameState.players[playerIdx],
      position: game.grid.nearestOpen(pos),
    );
    game.units.add(u);
    game.world.add(u);
    return u;
  }

  void simulate(AntsWarsGame game, double seconds) {
    for (var i = 0; i < (seconds / 0.05).round(); i++) {
      game.update(0.05);
    }
  }

  testWidgets('Zırh Feromonu: alınan hasar %40 azalır', (tester) async {
    final game = await pumpGame(tester);
    final u = spawn(game, UnitType.leafcutter, 0, Vector2(400, 300));
    await tester.pump();
    u.applyArmorBuff(0.6, 5);
    u.takeDamage(50);
    expect(u.hp, closeTo(u.spec.maxHp - 30, 0.01));
    // Süre bitince zırh düşer.
    simulate(game, 6);
    u.takeDamage(50);
    expect(u.hp, closeTo(u.spec.maxHp - 30 - 50, 0.01));
  });

  testWidgets('Korku Çığlığı: düşmanlar kaçışır ve savaşamaz',
      (tester) async {
    final game = await pumpGame(tester);
    final enemy = spawn(game, UnitType.fire, 1, Vector2(500, 300));
    await tester.pump();
    castAbility(game, game.gameState.players[0], AbilityType.fearScream,
        Vector2(500, 300));
    expect(enemy.isMoving, isTrue,
        reason: 'Korkan asker kaçış emri almalı');
  });

  testWidgets('Zehir Bulutu: içindeki düşman sürekli hasar alır',
      (tester) async {
    final game = await pumpGame(tester);
    // Düşman bulutun içinde; dost UZAK bir buluta ayrı test edilir ki
    // ikisi birbirine savaş hasarı vermesin.
    final enemy = spawn(game, UnitType.leafcutter, 1, Vector2(500, 300));
    final friend = spawn(game, UnitType.leafcutter, 0, Vector2(300, 550));
    await tester.pump();
    castAbility(game, game.gameState.players[0], AbilityType.poisonCloud,
        Vector2(500, 300));
    castAbility(game, game.gameState.players[0], AbilityType.poisonCloud,
        Vector2(300, 550)); // dostun üstüne kendi bulutu
    simulate(game, 4);
    expect(enemy.hp, lessThan(enemy.spec.maxHp),
        reason: 'Düşman zehirden hasar almalı');
    expect(friend.hp, friend.spec.maxHp,
        reason: 'Dost askerler kendi zehrinden etkilenmez');
  });

  testWidgets('botların yetenek seti rastgele ve 3 FARKLI güçten oluşur',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 4, teamMode: true);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    for (final bot in game.bots) {
      expect(bot.abilities.length, 3);
      expect(bot.abilities.toSet().length, 3,
          reason: 'Aynı güçten iki tane olamaz');
    }
  });

  testWidgets('Dondurma: buz zemini üstündeki donar, alan bitince çözülür',
      (tester) async {
    final game = await pumpGame(tester);
    final enemy = spawn(game, UnitType.fire, 1, Vector2(500, 300));
    await tester.pump();
    enemy.orderMove(game.grid.nearestOpen(Vector2(800, 300)));
    castAbility(game, game.gameState.players[0], AbilityType.freeze,
        Vector2(500, 300));
    final before = enemy.position.clone();
    // Alan 6 sn yaşar; üstündeki asker ALAN BOYUNCA donuk kalır.
    simulate(game, 5.0);
    expect(enemy.position.distanceTo(before), lessThan(1),
        reason: 'Buz zeminindeki asker alan boyunca donuk kalmalı');
    // Alan söner (+ ~2 sn çözülme payı) → yürüyüş kaldığı yerden sürer.
    simulate(game, 4.5);
    expect(enemy.position.distanceTo(before), greaterThan(40),
        reason: 'Buz çözülünce hareket geri gelir');
  });

  testWidgets('Dondurma: buz zeminine SONRADAN giren de donar',
      (tester) async {
    final game = await pumpGame(tester);
    // Alan (300,500) r90 — asker dışarıda başlar, içinden geçmeye çalışır.
    final enemy = spawn(game, UnitType.fire, 1, Vector2(470, 500));
    await tester.pump();
    castAbility(game, game.gameState.players[0], AbilityType.freeze,
        Vector2(300, 500));
    enemy.orderMove(game.grid.nearestOpen(Vector2(140, 500)));
    simulate(game, 3.0); // alana girdi ve donmuş olmalı
    final frozenAt = enemy.position.clone();
    expect(frozenAt.distanceTo(Vector2(300, 500)), lessThan(95),
        reason: 'Asker buz alanına girmiş olmalı');
    simulate(game, 1.5);
    expect(enemy.position.distanceTo(frozenAt), lessThan(1),
        reason: 'Buz zeminine giren asker donmalı');
  });

  testWidgets('Ateş Çemberi: alanın TAMAMI yakar, dışarısı güvenli',
      (tester) async {
    final game = await pumpGame(tester);
    final center = Vector2(500, 300);
    final inside = spawn(game, UnitType.leafcutter, 1, center); // merkez
    final onEdge = spawn(game, UnitType.leafcutter, 1,
        center + Vector2(80, 0)); // kenara yakın
    final outside = spawn(game, UnitType.leafcutter, 1,
        center + Vector2(140, 0)); // alan dışı
    inside.applyFreeze(10);
    onEdge.applyFreeze(10);
    outside.applyFreeze(10);
    await tester.pump();
    castAbility(game, game.gameState.players[0], AbilityType.fireRing,
        center);
    simulate(game, 3);
    expect(inside.hp, lessThan(inside.spec.maxHp),
        reason: 'Alevlerin ortasındaki düşman yanmalı');
    expect(onEdge.hp, lessThan(onEdge.spec.maxHp),
        reason: 'Alan kenarındaki düşman da yanmalı');
    expect(outside.hp, outside.spec.maxHp,
        reason: 'Alan dışı güvenlidir');
  });
}
