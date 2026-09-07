import 'package:flame/components.dart';

import 'unit_component.dart';

/// Birimler için ayrık uzamsal ızgara: "yakınımdaki birimler" sorgusunu
/// tüm listeyi taramadan cevaplar (ayrışma, savaş hedefleme, küme seçimi).
/// Her karede [rebuild] ile güncellenir — birkaç yüz birim için ucuzdur.
class SpatialGrid {
  SpatialGrid({this.cellSize = 40});

  final double cellSize;
  final Map<int, List<UnitComponent>> _cells = {};

  int _key(double x, double y) =>
      (x / cellSize).floor() * 100000 + (y / cellSize).floor();

  void rebuild(Iterable<UnitComponent> units) {
    _cells.clear();
    for (final u in units) {
      final key = _key(u.position.x, u.position.y);
      (_cells[key] ??= []).add(u);
    }
  }

  /// [center] etrafında [radius] içindekiler için [visit] çağrılır —
  /// liste TAHSİS ETMEZ (her karede çalışan sıcak yollar için).
  void forEachNear(
      Vector2 center, double radius, void Function(UnitComponent) visit) {
    final minCx = ((center.x - radius) / cellSize).floor();
    final maxCx = ((center.x + radius) / cellSize).floor();
    final minCy = ((center.y - radius) / cellSize).floor();
    final maxCy = ((center.y + radius) / cellSize).floor();
    final rSq = radius * radius;
    for (var cx = minCx; cx <= maxCx; cx++) {
      for (var cy = minCy; cy <= maxCy; cy++) {
        final cell = _cells[cx * 100000 + cy];
        if (cell == null) continue;
        for (final u in cell) {
          if (u.position.distanceToSquared(center) <= rSq) visit(u);
        }
      }
    }
  }

  /// [center] etrafında [radius] içindeki birimler.
  List<UnitComponent> near(Vector2 center, double radius) {
    final result = <UnitComponent>[];
    final minCx = ((center.x - radius) / cellSize).floor();
    final maxCx = ((center.x + radius) / cellSize).floor();
    final minCy = ((center.y - radius) / cellSize).floor();
    final maxCy = ((center.y + radius) / cellSize).floor();
    final rSq = radius * radius;
    for (var cx = minCx; cx <= maxCx; cx++) {
      for (var cy = minCy; cy <= maxCy; cy++) {
        final cell = _cells[cx * 100000 + cy];
        if (cell == null) continue;
        for (final u in cell) {
          if (u.position.distanceToSquared(center) <= rSq) result.add(u);
        }
      }
    }
    return result;
  }
}
