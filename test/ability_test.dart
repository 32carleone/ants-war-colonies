import 'dart:math' as math;

import 'package:ants_wars/data/abilities.dart';
import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ability_effects.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/game/unit_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AntsWarsGame> pumpGame(
    WidgetTester tester, {
    List<AbilityType>? loadout,
  }) async {
    final state = GameState()..startMatch(playerCount: 2);
    if (loadout != null) state.abilityLoadout = loadout;
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // sistem testleri sessiz ortam ister
    game.abilityCooldowns.setAll(0, [0, 0, 0]); // testte hazır başlasın
    game.update(0.05);
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

  testWidgets('yıldırım: alandaki herkese hasar, cooldown başlar',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!.position;
    final inside = spawn(game, UnitType.leafcutter, 1, nest + Vector2(40, 0));
    final own = spawn(game, UnitType.leafcutter, 0, nest + Vector2(-40, 0));
    final far = spawn(game, UnitType.leafcutter, 1, nest + Vector2(0, 300));
    game.update(0.05);

    expect(game.useHumanAbility(0, nest.clone()), isTrue); // lightning
    expect(inside.hp, lessThan(inside.spec.maxHp));
    expect(own.hp, lessThan(own.spec.maxHp), reason: 'Dost da yanar');
    expect(far.hp, far.spec.maxHp);
    expect(game.abilityCooldowns[0], greaterThan(0));
    expect(game.useHumanAbility(0, nest.clone()), isFalse,
        reason: 'Cooldown sürerken tekrar kullanılamaz');
  });

  testWidgets('takviye: hedefte 12 ateş karıncası belirir', (tester) async {
    final game = await pumpGame(tester);
    final target = game.grid
        .nearestOpen(game.nests[0]!.position + Vector2(60, 0));
    final before = game.unitCount;
    expect(game.useHumanAbility(1, target), isTrue); // reinforce
    expect(game.unitCount, before + 12);
    expect(
        game.units
            .where((u) => u.owner.id == 0 && u.type == UnitType.fire)
            .length,
        12);
  });

  testWidgets('çağrılar: orman 9 / kesici 6 asker doğurur', (tester) async {
    final game = await pumpGame(tester);
    final target = game.grid
        .nearestOpen(game.nests[0]!.position + Vector2(60, 0));
    castAbility(
        game, game.gameState.players[0], AbilityType.summonWood, target);
    expect(
        game.units
            .where((u) => u.owner.id == 0 && u.type == UnitType.wood)
            .length,
        9);
    castAbility(
        game, game.gameState.players[0], AbilityType.summonLeaf, target);
    expect(
        game.units
            .where((u) => u.owner.id == 0 && u.type == UnitType.leafcutter)
            .length,
        6);
  });

  testWidgets('hız feromonu: dost hızlanır ve süre sonunda normale döner',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!.position;
    final u = spawn(game, UnitType.leafcutter, 0, nest + Vector2(50, 0));
    game.update(0.05);

    expect(game.useHumanAbility(2, nest.clone()), isTrue); // speedPheromone
    expect(u.moveSpeedNow, closeTo(u.spec.moveSpeed * 1.5, 0.01));

    for (var i = 0; i < 280; i++) {
      game.update(0.05); // 14 sn > 12 sn buff
    }
    expect(u.moveSpeedNow, closeTo(u.spec.moveSpeed, 0.01));
  });

  testWidgets('savaş çılgınlığı hasarı, iyileştirme canı etkiler',
      (tester) async {
    final game = await pumpGame(tester, loadout: [
      AbilityType.battleFrenzy,
      AbilityType.heal,
      AbilityType.rain,
    ]);
    final nest = game.nests[0]!.position;
    final u = spawn(game, UnitType.leafcutter, 0, nest + Vector2(50, 0));
    final dummy = spawn(game, UnitType.fire, 1, nest + Vector2(0, 320));
    game.update(0.05);

    final base = u.computeAttackDamage(dummy);
    game.useHumanAbility(0, nest.clone()); // frenzy
    expect(u.computeAttackDamage(dummy), closeTo(base * 1.4, 0.01));

    u.takeDamage(30);
    game.useHumanAbility(1, nest.clone()); // heal 40 → tavana kadar
    expect(u.hp, u.spec.maxHp);
  });

  testWidgets('yağmur: iki tarafın da askerleri yavaşlar (global, hedefsiz)',
      (tester) async {
    final game = await pumpGame(tester, loadout: [
      AbilityType.rain,
      AbilityType.heal,
      AbilityType.lightning,
    ]);
    final own = spawn(game, UnitType.leafcutter, 0,
        game.nests[0]!.position + Vector2(50, 0));
    final enemy = spawn(game, UnitType.leafcutter, 1,
        game.nests[1]!.position + Vector2(50, 0));
    game.update(0.05);

    expect(game.useHumanAbility(0, null), isTrue);
    expect(own.moveSpeedNow, closeTo(own.spec.moveSpeed * 0.6, 0.01));
    expect(enemy.moveSpeedNow, closeTo(enemy.spec.moveSpeed * 0.6, 0.01));
  });

  testWidgets('yetenekler SİSLİ alanlara da atılabilir (kör atış)',
      (tester) async {
    final game = await pumpGame(tester);
    final enemyNest = game.nests[1]!;
    // Rakip yuva çevresi YASAK BÖLGEDİR (yetenek açığı kapatıldı) —
    // kör atış, sisli ama yasak yarıçapın DIŞINDA bir noktaya yapılır.
    final blind = enemyNest.position.clone()
      ..x -= kAbilityNestExclusion + 60;
    expect(game.fog.isVisible(blind), isFalse);
    expect(game.useHumanAbility(0, blind), isTrue);
    expect(game.abilityCooldowns[0], greaterThan(0));
    // Yuvanın dibi ise reddedilir.
    game.abilityCooldowns[0] = 0;
    expect(game.useHumanAbility(0, enemyNest.position.clone()), isFalse);
  });

  testWidgets('yetenekler maç başında DOLU başlar (bekleyince açılır)',
      (tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear();

    for (var i = 0; i < 3; i++) {
      expect(game.abilityCooldowns[i], greaterThan(0));
    }
    expect(game.useHumanAbility(0, game.nests[0]!.position.clone()), isFalse);
  });

  test('loadout kalıcı kaydedilir ve geri yüklenir', () async {
    SharedPreferences.setMockInitialValues({});
    final loadout = [
      AbilityType.rain,
      AbilityType.heal,
      AbilityType.battleFrenzy,
    ];
    await saveAbilityLoadout(loadout);
    final loaded = await loadAbilityLoadout();
    expect(loaded, loadout);
  });

  test('bozuk/eksik kayıt varsayılan loadout döndürür', () async {
    SharedPreferences.setMockInitialValues({
      'ability_loadout': ['rain'], // eksik (3 değil)
    });
    expect(await loadAbilityLoadout(), defaultLoadout);
  });
}
