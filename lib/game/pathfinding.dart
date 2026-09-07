import 'dart:math' as math;

import 'package:flame/components.dart';

import '../data/constants.dart';
import '../models/game_map.dart';

/// Haritadan üretilen geçilebilirlik ızgarası.
/// Hücre merkezi bir engelin (birim yarıçapı kadar genişletilmiş) içindeyse
/// hücre kapalıdır.
class PassabilityGrid {
  PassabilityGrid._(this.cols, this.rows, this.cellSize, this._map,
      this._unitRadius, this._blocked, this._slow);

  factory PassabilityGrid.fromMap(
    MapDefinition map, {
    double cellSize = 16,
    double unitRadius = 6,
  }) {
    final cols = (kGameWidth / cellSize).ceil();
    final rows = (kGameHeight / cellSize).ceil();
    final blocked = List<bool>.filled(cols * rows, false);
    final slow = List<bool>.filled(cols * rows, false);
    final swamps =
        map.features.where((f) => f.kind == TerrainKind.swamp).toList();
    final p = Vector2.zero();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        p.setValues((c + 0.5) * cellSize, (r + 0.5) * cellSize);
        final i = r * cols + c;
        blocked[i] = map.isBlocked(p, inflate: unitRadius);
        for (final f in swamps) {
          if (f.contains(p)) {
            slow[i] = true;
            break;
          }
        }
      }
    }
    return PassabilityGrid._(
        cols, rows, cellSize, map, unitRadius, blocked, slow);
  }

  final int cols;
  final int rows;
  final double cellSize;
  final MapDefinition _map;
  final double _unitRadius;
  final List<bool> _blocked;
  final List<bool> _slow;

  bool isBlockedCell(int c, int r) {
    if (c < 0 || r < 0 || c >= cols || r >= rows) return true;
    return _blocked[r * cols + c];
  }

  /// Bu dünya noktası bataklıkta mı? (Birim hızı düşürülür.)
  bool isSlowAt(Vector2 world) {
    if (!world.x.isFinite || !world.y.isFinite) return false;
    final c = world.x ~/ cellSize, r = world.y ~/ cellSize;
    if (c < 0 || r < 0 || c >= cols || r >= rows) return false;
    return _slow[r * cols + c];
  }

  /// Kazılıp AÇILAN geçitler: [dug] öğeleri yok sayılarak engel haritası
  /// yeniden hesaplanır (kalıcı değişim — yollar anında açılır).
  void openDug(Set<TerrainFeature> dug) {
    final p = Vector2.zero();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        p.setValues((c + 0.5) * cellSize, (r + 0.5) * cellSize);
        _blocked[r * cols + c] =
            _map.isBlocked(p, inflate: _unitRadius, ignore: dug);
      }
    }
  }

  /// NaN/sonsuz koordinatta `~/` ÇÖKER (UnsupportedError) — engelli sayılır.
  bool isBlockedAt(Vector2 world) {
    if (!world.x.isFinite || !world.y.isFinite) return true;
    return isBlockedCell(world.x ~/ cellSize, world.y ~/ cellSize);
  }

  Vector2 cellCenter(int c, int r) =>
      Vector2((c + 0.5) * cellSize, (r + 0.5) * cellSize);

  (int, int) worldToCell(Vector2 world) {
    // NaN/sonsuz koordinat güvenli hücreye indirgenir (çökme koruması).
    final x = world.x.isFinite ? world.x : 0.0;
    final y = world.y.isFinite ? world.y : 0.0;
    return (x ~/ cellSize, y ~/ cellSize);
  }

  /// Verilen noktaya en yakın açık hücrenin merkezini döndürür
  /// (nokta kapalı bölgedeyse veya harita dışındaysa içeri taşımak için).
  Vector2 nearestOpen(Vector2 world) {
    final (rawC, rawR) = worldToCell(world);
    final c = rawC.clamp(0, cols - 1);
    final r = rawR.clamp(0, rows - 1);
    if (!isBlockedCell(c, r)) {
      // Nokta harita içindeyse aynen koru; dışındaysa hücre merkezine çek.
      return (c == rawC && r == rawR) ? world.clone() : cellCenter(c, r);
    }
    for (var radius = 1; radius < math.max(cols, rows); radius++) {
      Vector2? best;
      var bestDist = double.infinity;
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          if (dr.abs() != radius && dc.abs() != radius) continue; // sadece halka
          final cc = c + dc, rr = r + dr;
          if (isBlockedCell(cc, rr)) continue;
          final center = cellCenter(cc, rr);
          final d = center.distanceToSquared(world);
          if (d < bestDist) {
            bestDist = d;
            best = center;
          }
        }
      }
      if (best != null) return best;
    }
    return world.clone(); // tamamen kapalı harita — olmamalı
  }

  /// İki nokta arasında düz görüş hattı açık mı? (yol yumuşatma için)
  bool lineOfSight(Vector2 a, Vector2 b) {
    final dist = a.distanceTo(b);
    if (dist < 0.001) return true;
    final steps = (dist / (cellSize / 2)).ceil();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final p = Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
      if (isBlockedAt(p)) return false;
    }
    return true;
  }
}

/// Izgara üzerinde A* yol bulucu (8 yönlü, köşe kesme yok) + görüş hattı
/// yumuşatması.
class Pathfinder {
  Pathfinder(this.grid);

  final PassabilityGrid grid;

  static const _sqrt2 = 1.41421356;

  // PERFORMANS: A* çalışma alanları YENİDEN KULLANILIR — her çağrıda
  // 3 tam-ızgara listesi tahsis etmek (toplu emirlerde onlarca çağrı)
  // hem CPU hem GC takılması üretiyordu. Damga (stamp) tekniğiyle diziler
  // sıfırlanmadan geçerlilik kontrol edilir.
  List<double>? _gScore;
  List<int>? _cameFrom;
  List<int>? _closedStamp;
  List<int>? _openStamp;
  int _stamp = 0;

  /// [start] → [goal] yolu (dünya koordinatlarında ara noktalar).
  /// Hedef kapalıysa en yakın açık hücreye gider. Yol yoksa boş liste döner.
  List<Vector2> findPath(Vector2 start, Vector2 goal) {
    final s = grid.nearestOpen(start);
    final g = grid.nearestOpen(goal);

    // KESTİRME: araya engel girmiyorsa A* kurmaya gerek yok — açık
    // arazideki emirlerin büyük çoğunluğu buradan ucuza döner.
    if (grid.lineOfSight(s, g)) return [g];

    // nearestOpen sınır içi garanti eder; yine de indeks sarmasına karşı kelepçele.
    final (rawSc, rawSr) = grid.worldToCell(s);
    final (rawGc, rawGr) = grid.worldToCell(g);
    final sc = rawSc.clamp(0, grid.cols - 1);
    final sr = rawSr.clamp(0, grid.rows - 1);
    final gc = rawGc.clamp(0, grid.cols - 1);
    final gr = rawGr.clamp(0, grid.rows - 1);
    if (sc == gc && sr == gr) return [g];

    final cols = grid.cols, rows = grid.rows;
    final n = cols * rows;
    _stamp++;
    final stamp = _stamp;
    final gScoreBuf = _gScore ??= List<double>.filled(n, 0);
    final cameFrom = _cameFrom ??= List<int>.filled(n, -1);
    final closedStamp = _closedStamp ??= List<int>.filled(n, 0);
    final openStamp = _openStamp ??= List<int>.filled(n, 0);

    double gAt(int i) =>
        openStamp[i] == stamp ? gScoreBuf[i] : double.infinity;
    bool isClosed(int i) => closedStamp[i] == stamp;

    double heuristic(int c, int r) {
      final dc = (c - gc).abs(), dr = (r - gr).abs();
      final lo = math.min(dc, dr), hi = math.max(dc, dr);
      // %25 AÇGÖZLÜ ağırlık: gezilen düğüm sayısını kat kat düşürür;
      // yol en fazla ~%25 uzayabilir (karınca yürüyüşünde fark edilmez,
      // görüş hattı yumuşatması çoğunu zaten geri kazanır).
      return (lo * _sqrt2 + (hi - lo)) * 1.25;
    }

    final startIdx = sr * cols + sc;
    final goalIdx = gr * cols + gc;
    gScoreBuf[startIdx] = 0;
    openStamp[startIdx] = stamp;
    final open = _BinaryHeap();
    open.push(startIdx, heuristic(sc, sr));

    const dirs = [
      (1, 0), (-1, 0), (0, 1), (0, -1),
      (1, 1), (1, -1), (-1, 1), (-1, -1),
    ];

    var found = false;
    while (open.isNotEmpty) {
      final current = open.pop();
      if (current == goalIdx) {
        found = true;
        break;
      }
      if (isClosed(current)) continue;
      closedStamp[current] = stamp;
      final c = current % cols, r = current ~/ cols;

      for (final (dc, dr) in dirs) {
        final nc = c + dc, nr = r + dr;
        if (grid.isBlockedCell(nc, nr)) continue;
        // Çapraz geçişte köşe kesmeyi engelle.
        if (dc != 0 &&
            dr != 0 &&
            (grid.isBlockedCell(c + dc, r) || grid.isBlockedCell(c, r + dr))) {
          continue;
        }
        final ni = nr * cols + nc;
        if (isClosed(ni)) continue;
        final cost = (dc != 0 && dr != 0) ? _sqrt2 : 1.0;
        final tentative = gScoreBuf[current] + cost;
        if (tentative < gAt(ni)) {
          gScoreBuf[ni] = tentative;
          openStamp[ni] = stamp;
          cameFrom[ni] = current;
          open.push(ni, tentative + heuristic(nc, nr));
        }
      }
    }

    if (!found) return const [];

    // Yolu geri sar (cameFrom yalnız bu damgada dokunulan hücrelerde
    // geçerlidir — open/closed damgası olmayan hücreye zaten inilmez).
    final cells = <int>[];
    var cur = goalIdx;
    while (cur != -1 && cells.length <= n) {
      cells.add(cur);
      cur = openStamp[cur] == stamp ? cameFrom[cur] : -1;
    }
    final raw = <Vector2>[
      s,
      for (final i in cells.reversed) grid.cellCenter(i % cols, i ~/ cols),
      g,
    ];

    return _smooth(raw);
  }

  /// Görüş hattı yumuşatması: gereksiz ara noktaları atar, yol doğallaşır.
  List<Vector2> _smooth(List<Vector2> raw) {
    if (raw.length <= 2) return raw;
    final out = <Vector2>[raw.first];
    var anchor = 0;
    for (var i = 2; i < raw.length; i++) {
      if (!grid.lineOfSight(raw[anchor], raw[i])) {
        out.add(raw[i - 1]);
        anchor = i - 1;
      }
    }
    out.add(raw.last);
    return out;
  }
}

/// A* için basit ikili min-heap (öncelik = f skoru).
class _BinaryHeap {
  final List<int> _items = [];
  final List<double> _priorities = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(int item, double priority) {
    _items.add(item);
    _priorities.add(priority);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_priorities[parent] <= _priorities[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _items.first;
    final lastItem = _items.removeLast();
    final lastPri = _priorities.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = lastItem;
      _priorities[0] = lastPri;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var smallest = i;
        if (l < _items.length && _priorities[l] < _priorities[smallest]) {
          smallest = l;
        }
        if (r < _items.length && _priorities[r] < _priorities[smallest]) {
          smallest = r;
        }
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final ti = _items[a];
    _items[a] = _items[b];
    _items[b] = ti;
    final tp = _priorities[a];
    _priorities[a] = _priorities[b];
    _priorities[b] = tp;
  }
}
