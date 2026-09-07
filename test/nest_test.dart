import 'package:ants_wars/data/constants.dart';
import 'package:ants_wars/data/units.dart';
import 'package:ants_wars/models/nest.dart';
import 'package:ants_wars/models/player.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Player makePlayer({int resources = 200}) => Player(
        id: 0,
        color: const Color(0xFFE05A33),
        isBot: false,
        resources: resources,
      );

  Nest makeNest(Player owner) =>
      Nest(owner: owner, position: Vector2(100, 100));

  group('Üretim', () {
    test('başlangıç garnizonu ateş karıncalarından oluşur', () {
      final nest = makeNest(makePlayer());
      expect(nest.garrison[UnitType.fire], kStartingGarrison);
      expect(nest.population, kStartingGarrison);
    });

    test('enqueue kaynak düşer ve kuyruğa ekler', () {
      final player = makePlayer(resources: 50);
      final nest = makeNest(player);
      expect(nest.enqueue(UnitType.fire), isTrue);
      expect(player.resources, 50 - unitSpecs[UnitType.fire]!.cost);
      expect(nest.productionQueue, [UnitType.fire]);
    });

    test('kaynak yetmezse sipariş reddedilir', () {
      final player = makePlayer(resources: 5);
      final nest = makeNest(player);
      expect(nest.enqueue(UnitType.leafcutter), isFalse);
      expect(player.resources, 5);
      expect(nest.productionQueue, isEmpty);
    });

    test('üretim süresi dolunca birim garnizona katılır', () {
      final nest = makeNest(makePlayer());
      nest.enqueue(UnitType.fire);
      final t = unitSpecs[UnitType.fire]!.productionTime;
      nest.updateProduction(t / 2);
      expect(nest.garrison[UnitType.fire], kStartingGarrison);
      expect(nest.productionProgress, closeTo(0.5, 0.01));
      nest.updateProduction(t / 2);
      expect(nest.garrison[UnitType.fire], kStartingGarrison + 1);
      expect(nest.productionQueue, isEmpty);
    });

    test('kuyruk sırayla işlenir, artan süre sonrakine devreder', () {
      final nest = makeNest(makePlayer());
      nest.enqueue(UnitType.fire); // 1.5 sn
      nest.enqueue(UnitType.fire);
      nest.updateProduction(3.0); // ikisine de yeter
      expect(nest.garrison[UnitType.fire], kStartingGarrison + 2);
    });
  });

  group('Çıkarma ve geri sokma', () {
    test('yüzde oranları doğru asker çıkarır', () {
      final nest = makeNest(makePlayer());
      // Başlangıç: 10 ateş. %25 → 3 (round), kalan 7.
      final out = nest.takeOut(0.25);
      expect(out[UnitType.fire], 3);
      expect(nest.garrison[UnitType.fire], 7);
    });

    test('%100 hepsini çıkarır', () {
      final nest = makeNest(makePlayer());
      final out = nest.takeOut(1.0);
      expect(out[UnitType.fire], kStartingGarrison);
      expect(nest.population, 0);
    });

    test('tip filtresi sadece o tipi çıkarır', () {
      final nest = makeNest(makePlayer());
      nest.garrison[UnitType.leafcutter] = 4;
      final out = nest.takeOut(1.0, only: UnitType.leafcutter);
      expect(out, {UnitType.leafcutter: 4});
      expect(nest.garrison[UnitType.fire], kStartingGarrison);
    });

    test('geri sokulan askerler garnizona ve savunmaya eklenir', () {
      final nest = makeNest(makePlayer());
      final before = nest.defensePower;
      nest.returnUnits({UnitType.leafcutter: 2});
      expect(nest.garrison[UnitType.leafcutter], 2);
      expect(nest.defensePower,
          before + 2 * unitSpecs[UnitType.leafcutter]!.defensePower);
    });
  });

  group('Savunma ve kraliçe', () {
    test('hasar önce garnizonu eritir, kraliçeye dokunmaz', () {
      final nest = makeNest(makePlayer());
      // 10 ateş * (1 * 10) = 100 emilim. 50 hasar → 5 ateş ölür.
      nest.receiveAttack(50);
      expect(nest.garrison[UnitType.fire], 5);
      expect(nest.queenHp, kQueenMaxHp);
    });

    test('garnizon zayıftan güçlüye ölür', () {
      final nest = makeNest(makePlayer());
      nest.garrison[UnitType.leafcutter] = 2;
      nest.receiveAttack(100); // tam 10 ateşlik hasar
      expect(nest.garrison[UnitType.fire], 0);
      expect(nest.garrison[UnitType.leafcutter], 2);
    });

    test('garnizon bitince artan hasar kraliçeye işler', () {
      final nest = makeNest(makePlayer());
      nest.receiveAttack(100 + 120); // 100 garnizon + 120 kraliçe
      expect(nest.population, 0);
      expect(nest.queenHp, kQueenMaxHp - 120);
      expect(nest.destroyed, isFalse);
    });

    test('kraliçe ölünce yuva yıkılır ve işlem kabul etmez', () {
      final nest = makeNest(makePlayer());
      nest.receiveAttack(100 + kQueenMaxHp);
      expect(nest.destroyed, isTrue);
      expect(nest.enqueue(UnitType.fire), isFalse);
      nest.returnUnits({UnitType.fire: 5});
      expect(nest.population, 0);
    });
  });
}
