import 'package:ants_wars/data/campaigns.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/pathfinding.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final maps = [
    ...allMaps,
    tutorialMap,
    ...fireMissionMaps,
    ...iceMissionMaps,
    ...islandMissionMaps,
  ];

  for (final map in maps) {
    group('Harita: ${map.name}', () {
      final grid = PassabilityGrid.fromMap(map);
      final pathfinder = Pathfinder(grid);

      test('yuva sayısı oyuncu sayısına eşit', () {
        expect(map.nestSpots.length, map.playerCount);
      });

      test('tüm yuva noktaları açık zeminde', () {
        for (final nest in map.nestSpots) {
          expect(grid.isBlockedAt(nest), isFalse,
              reason: 'Yuva engel üstünde: $nest');
        }
      });

      test('tüm bina noktaları açık zeminde', () {
        for (final spot in map.buildingSpots) {
          expect(grid.isBlockedAt(spot), isFalse,
              reason: 'Bina noktası engel üstünde: $spot');
        }
      });

      test('her yuvadan diğer tüm yuvalara yol var', () {
        for (var i = 0; i < map.nestSpots.length; i++) {
          for (var j = i + 1; j < map.nestSpots.length; j++) {
            final path =
                pathfinder.findPath(map.nestSpots[i], map.nestSpots[j]);
            expect(path, isNotEmpty,
                reason: 'Yol yok: yuva $i → yuva $j');
          }
        }
      });

      test('her yuvadan tüm bina noktalarına yol var', () {
        for (var i = 0; i < map.nestSpots.length; i++) {
          for (final spot in map.buildingSpots) {
            final path = pathfinder.findPath(map.nestSpots[i], spot);
            expect(path, isNotEmpty,
                reason: 'Yol yok: yuva $i → bina $spot');
          }
        }
      });
    });
  }

  group('Yol bulma', () {
    final map = mapForPlayers(2);
    final grid = PassabilityGrid.fromMap(map);
    final pathfinder = Pathfinder(grid);

    test('nehrin karşısına yol köprüden geçer (su üstünden geçmez)', () {
      final path =
          pathfinder.findPath(map.nestSpots.first, map.nestSpots.last);
      expect(path, isNotEmpty);
      // Yol boyunca örneklenen hiçbir nokta kapalı hücreye düşmemeli.
      for (var i = 0; i < path.length - 1; i++) {
        expect(grid.lineOfSight(path[i], path[i + 1]), isTrue,
            reason: 'Yol parçası engelden geçiyor: ${path[i]} → ${path[i + 1]}');
      }
    });

    test('hedef engel içindeyse en yakın açık noktaya yol bulunur', () {
      // Gölete (su içine) yol iste — 3 kişilik haritanın merkezi.
      final map3 = mapForPlayers(3);
      final grid3 = PassabilityGrid.fromMap(map3);
      final pf3 = Pathfinder(grid3);
      final path = pf3.findPath(map3.nestSpots.first, Vector2(640, 340));
      expect(path, isNotEmpty);
      expect(grid3.isBlockedAt(path.last), isFalse);
    });

    test('aynı noktaya yol tek adımdır', () {
      final start = map.nestSpots.first;
      final path = pathfinder.findPath(start, start + Vector2(2, 2));
      expect(path.length, 1);
    });
  });
}
