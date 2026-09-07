import 'dart:math' as math;

import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AntsWarsGame> pumpGame(WidgetTester tester) async {
    final state = GameState()..startMatch(playerCount: 2);
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0; // testler geri sayımı atlar
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.bots.clear(); // sistem testleri sessiz ortam ister (bot müdahalesi yok)
    // %100: sol kama artık kümeyi BÖLER — bu testler tam grup davranışını
    // ölçer (bölme raider_camp_wheel_test'te ayrıca doğrulanır).
    game.deployFraction.value = 1.0;
    return game;
  }

  testWidgets('yuvaya dokununca yuva seçilir, boş zemine dokununca bırakılır',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;

    game.inputController.handleTap(nest.position.clone());
    expect(game.inputController.selectedNest, nest);

    game.inputController
        .handleTap(game.grid.nearestOpen(nest.position + Vector2(200, 0)));
    expect(game.inputController.selectedNest, isNull);
  });

  testWidgets('sürükleme kendi askerinin üstünde başlarsa küme otomatik seçilir',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    final target = game.grid.nearestOpen(nest.position + Vector2(120, 0));
    game.deployFromNest(nest, 1.0, target);
    for (var i = 0; i < 200; i++) {
      game.update(0.05);
    }

    final ic = game.inputController;
    expect(ic.selection, isEmpty);
    // Önce dokunmadan doğrudan sürükle: küme kendiliğinden seçilmeli.
    ic.beginDrag(game.units.first.position.clone());
    expect(ic.selection.length, 10);
    ic.updateDrag(Vector2(0, 90));
    ic.endDrag();
    expect(game.units.every((u) => u.isMoving), isTrue);
  });

  testWidgets('yuvadan sürükle-bırak seçili oran/tiple asker çıkarır',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    game.deployFraction.value = 0.5;

    final ic = game.inputController;
    ic.beginDrag(nest.position.clone());
    ic.updateDrag(Vector2(120, 20)); // hedefe doğru sürükle
    ic.endDrag();

    expect(game.unitCount, 5); // 10 ateşin %50'si
    expect(nest.population, 5);
  });

  testWidgets('zincirleme küme seçimi: uzak grup seçime dahil olmaz',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    nest.returnUnits({UnitType.fire: 10}); // toplam 20

    final targetA = game.grid.nearestOpen(nest.position + Vector2(150, -60));
    final targetB = game.grid.nearestOpen(nest.position + Vector2(150, 120));
    game.deployFromNest(nest, 0.5, targetA); // 10 asker A'ya
    game.deployFromNest(nest, 1.0, targetB); // 10 asker B'ye

    // Varsınlar ve ayrışsınlar.
    for (var i = 0; i < 240; i++) {
      game.update(0.05);
    }

    // A grubundan bir askere dokun.
    final unitInA = game.units.reduce((a, b) =>
        a.position.distanceToSquared(targetA) <
                b.position.distanceToSquared(targetA)
            ? a
            : b);
    game.inputController.handleTap(unitInA.position.clone());

    final sel = game.inputController.selection;
    expect(sel, isNotEmpty);
    expect(sel.length, lessThan(game.units.length),
        reason: 'İki ayrı grubun tamamı seçilmemeli');
    // Seçilenler A hedefine yakın olmalı.
    for (final u in sel) {
      expect(u.position.distanceTo(targetA), lessThan(120));
      expect(u.selected, isTrue);
    }
  });

  testWidgets('seçili küme sürüklenince yeni hedefe yürür', (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    final targetA = game.grid.nearestOpen(nest.position + Vector2(120, 0));
    game.deployFromNest(nest, 1.0, targetA);
    for (var i = 0; i < 200; i++) {
      game.update(0.05);
    }

    final ic = game.inputController;
    ic.handleTap(game.units.first.position.clone());
    expect(ic.selection.length, 10);

    final start = game.units.first.position.clone();
    ic.beginDrag(start);
    ic.updateDrag(Vector2(0, 100));
    ic.endDrag();

    expect(game.units.every((u) => u.isMoving), isTrue);
  });

  testWidgets('seçili küme yuvaya bırakılınca içeri girer', (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    final targetA = game.grid.nearestOpen(nest.position + Vector2(100, 0));
    game.deployFromNest(nest, 1.0, targetA);
    for (var i = 0; i < 160; i++) {
      game.update(0.05);
    }

    final ic = game.inputController;
    ic.handleTap(game.units.first.position.clone());
    final start = game.units.first.position.clone();
    ic.beginDrag(start);
    // Yuvanın üstüne sürükle.
    ic.updateDrag(nest.position - start);
    ic.endDrag();

    for (var i = 0; i < 240; i++) {
      game.update(0.05);
    }
    await tester.pump();
    expect(game.unitCount, 0);
    expect(nest.population, 10);
  });

  testWidgets('sürükleyerek çıkarma TÜM tiplerden orantılı alır',
      (tester) async {
    final game = await pumpGame(tester);
    final nest = game.nests[0]!;
    nest.returnUnits({UnitType.leafcutter: 4}); // 10 ateş + 4 kesici
    game.deployFraction.value = 0.5;

    final ic = game.inputController;
    ic.beginDrag(nest.position.clone());
    ic.updateDrag(Vector2(150, 0));
    ic.endDrag();

    // %50: 5 ateş + 2 kesici sahada, kalanlar yuvada.
    expect(game.unitCount, 7);
    expect(game.units.where((u) => u.type == UnitType.fire).length, 5);
    expect(
        game.units.where((u) => u.type == UnitType.leafcutter).length, 2);
    expect(nest.garrison[UnitType.fire], 5);
    expect(nest.garrison[UnitType.leafcutter], 2);
  });
}
