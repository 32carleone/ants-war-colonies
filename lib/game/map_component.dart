import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../models/game_map.dart';
import 'ants_wars_game.dart';
import 'pathfinding.dart';

/// Haritanın statik görselini çizer: zemin, nehir, köprüler, kökler, taşlar,
/// bina noktaları. Tamamı onLoad'da tek bir [ui.Picture]'a kaydedilir;
/// her karede sadece o resim çizilir (ucuz).
class MapComponent extends Component with HasGameReference<AntsWarsGame> {
  MapComponent({required this.map, required this.grid});

  final MapDefinition map;
  final PassabilityGrid grid;

  late final ui.Picture _picture;
  double _time = 0;

  /// Çimen temasında rüzgârla SALINAN ot kümeleri. Performans: saplar
  /// onLoad'da bir kez üretilir; karede yalnız uç noktasına sin() kayması
  /// eklenir (küme başına 3 drawLine, ~60 küme ≈ 180 çizgi/kare).
  final List<_SwayTuft> _tufts = [];

  /// Su parıltıları için: her su hattının ara noktalı örneklenmiş yolu.
  final List<List<Vector2>> _waterPaths = [];
  final List<Vector2> _ponds = [];

  /// TÜM su alanlarının birleşimi — kıyı katmanıyla (bank) birebir aynı
  /// dalgalı geometri. Bölge sınırları (TerritoryComponent) sudan bununla
  /// kırpılır; böylece sınır çizgisi kıvrımlı kıyıyı izler.
  late final Path waterMask = _buildWaterMask();

  Path _buildWaterMask() {
    var mask = Path();
    for (final f in map.features.where((f) => f.kind == TerrainKind.water)) {
      final Path piece;
      if (f.points.length == 1) {
        final center = Offset(f.points.first.x, f.points.first.y);
        final seed = (center.dx + center.dy).toInt() % 17;
        piece = _organicBlob(center, f.width / 2 + 8, seed, jitter: 0.10);
      } else {
        piece = _waterBand(f, 8, 7, 0); // kıyı katmanıyla aynı parametreler
      }
      mask = Path.combine(PathOperation.union, mask, piece);
    }
    return mask;
  }

  @override
  Future<void> onLoad() async {
    final recorder = ui.PictureRecorder();
    _drawMap(Canvas(recorder));
    _picture = recorder.endRecording();

    if (map.theme == MapTheme.grass) {
      final r = math.Random(map.id.hashCode ^ 0x5EED);
      for (var i = 0; i < 60; i++) {
        final base = Offset(
            r.nextDouble() * kGameWidth, r.nextDouble() * kGameHeight);
        _tufts.add(_SwayTuft(
          base: base,
          color: Color.lerp(
            const Color(0xFF7A9A4C),
            const Color(0xFF96B565),
            r.nextDouble(),
          )!
              .withValues(alpha: 0.9),
          phase: r.nextDouble() * math.pi * 2,
          speed: 1.1 + r.nextDouble() * 0.9,
          blades: [
            for (var b = 0; b < 3; b++)
              Offset((r.nextDouble() - 0.5) * 8,
                  -5 - r.nextDouble() * 6), // (kök dx, sap yüksekliği)
          ],
        ));
      }
    }

    for (final f in map.features.where((f) => f.kind == TerrainKind.water)) {
      if (f.points.length == 1) {
        _ponds.add(f.points.first);
        continue;
      }
      // Hattı ~18px adımlarla örnekle (parıltılar bu yol üstünde akar).
      final sampled = <Vector2>[];
      for (var i = 0; i < f.points.length - 1; i++) {
        final a = f.points[i];
        final b = f.points[i + 1];
        final segLen = a.distanceTo(b);
        final steps = (segLen / 18).ceil();
        for (var s = 0; s < steps; s++) {
          sampled.add(a + (b - a) * (s / steps));
        }
      }
      sampled.add(f.points.last);
      _waterPaths.add(sampled);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void onRemove() {
    // Maç yeniden kurulunca eski sahne resmi native belleği bırakır.
    _picture.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_picture);
    _renderWaterLife(canvas);
    _renderAmbient(canvas);
    if (game.debugTerrain) _drawDebugGrid(canvas);
  }

  /// Tema ortam parçacıkları: çorakta yükselen KORLAR, karda süzülen TİPİ.
  void _renderAmbient(Canvas canvas) {
    switch (map.theme) {
      case MapTheme.grass:
        // Hafif rüzgâr salınımı: yalnız sapların UCU yatayda kayar.
        final p = Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (final tuft in _tufts) {
          p.color = tuft.color;
          final sway =
              math.sin(_time * tuft.speed + tuft.phase) * 2.4;
          for (final blade in tuft.blades) {
            final root = tuft.base.translate(blade.dx, 0);
            canvas.drawLine(
              root,
              root.translate(sway + blade.dx * 0.3, blade.dy),
              p,
            );
          }
        }
      case MapTheme.scorched:
        for (var i = 0; i < 14; i++) {
          final t = ((_time * (0.12 + (i % 4) * 0.04) + i * 0.13) % 1.0);
          final x = (i * 173.0) % kGameWidth +
              math.sin(_time * 1.3 + i) * 14;
          final y = kGameHeight * (1 - t);
          canvas.drawCircle(
            Offset(x, y),
            1.4 + (i % 3) * 0.8,
            Paint()
              ..color = const Color(0xFFF6C044)
                  .withValues(alpha: 0.4 * (1 - t) + 0.05),
          );
        }
      case MapTheme.snow:
        for (var i = 0; i < 20; i++) {
          final t = ((_time * (0.08 + (i % 5) * 0.03) + i * 0.11) % 1.0);
          final x = ((i * 137.0) % kGameWidth +
                  math.sin(_time * 0.9 + i) * 22 +
                  _time * 12) %
              kGameWidth;
          final y = kGameHeight * t;
          canvas.drawCircle(
            Offset(x, y),
            1.2 + (i % 2) * 0.8,
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5 * (1 - t * 0.4)),
          );
        }
    }
  }

  /// Su canlılığı: nehirde akan parıltı çizgileri, göletlerde halka dalgalar.
  void _renderWaterLife(Canvas canvas) {
    final glint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final path in _waterPaths) {
      final n = path.length;
      for (var k = 0; k < 9; k++) {
        // Akış: parıltılar hat boyunca kayar (index uzayında).
        final pos = (_time * 6 + k * n / 9) % (n - 1);
        final i = pos.floor();
        final frac = pos - i;
        final p = path[i] + (path[i + 1] - path[i]) * frac;
        final dir = (path[i + 1] - path[i]).normalized();
        final wob = math.sin(_time * 2.4 + k * 1.9) * 8;
        final a = 0.10 + 0.10 * math.sin(_time * 3 + k * 2.3);
        final glintColor = switch (map.theme) {
          MapTheme.grass => const Color(0xFFBFE3F2),
          MapTheme.scorched => const Color(0xFFF6C044),
          MapTheme.snow => const Color(0xFFFFFFFF),
        };
        glint.color = glintColor.withValues(alpha: a.clamp(0.03, 0.25));
        canvas.drawLine(
          Offset(p.x - dir.y * wob - dir.x * 7, p.y + dir.x * wob - dir.y * 7),
          Offset(p.x - dir.y * wob + dir.x * 7, p.y + dir.x * wob + dir.y * 7),
          glint,
        );
      }
    }
    // Göletler: periyodik genişleyen halkalar.
    for (final pond in _ponds) {
      for (var k = 0; k < 3; k++) {
        final t = ((_time * 0.35 + k / 3) % 1.0);
        canvas.drawCircle(
          Offset(pond.x, pond.y),
          12 + t * 55,
          Paint()
            ..color = const Color(0xFFBFE3F2)
                .withValues(alpha: 0.14 * (1 - t))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  // ---------------------------------------------------------------- çizim

  void _drawMap(Canvas c) {
    // Aynı harita her açılışta aynı görünsün diye sabit tohum.
    final rng = math.Random(map.id.hashCode);

    _drawGround(c, rng);
    for (final f in map.features.where((f) => f.kind == TerrainKind.swamp)) {
      _drawSwamp(c, f);
    }
    _drawWaters(
        c, map.features.where((f) => f.kind == TerrainKind.water).toList());
    for (final f in map.features.where((f) => f.kind == TerrainKind.bridge)) {
      _drawBridge(c, f);
    }
    for (final f in map.features.where((f) => f.kind == TerrainKind.root)) {
      _drawRoot(c, f);
    }
    for (final f in map.features.where((f) => f.kind == TerrainKind.rock)) {
      _drawRock(c, f);
    }
    // Binalar BuildingComponent tarafından çizilir (canlı durum: sahip/seviye).
  }

  void _drawGround(Canvas c, math.Random rng) {
    const bounds = Rect.fromLTWH(0, 0, kGameWidth, kGameHeight);
    // Tema zemini: çimen / çorak yanık toprak / karlı toprak.
    final base = switch (map.theme) {
      MapTheme.grass => const Color(0xFF5E7C3E),
      MapTheme.scorched => const Color(0xFF4A3428),
      MapTheme.snow => const Color(0xFFDCE6EC),
    };
    c.drawRect(bounds, Paint()..color = base);

    // Ton lekeleri + seyrek açıklıklar: doğal doku.
    final tones = switch (map.theme) {
      MapTheme.grass => const [
          Color(0xFF557239),
          Color(0xFF67854A),
          Color(0xFF4F6B34)
        ],
      MapTheme.scorched => const [
          Color(0xFF3E2B20),
          Color(0xFF564036),
          Color(0xFF2E211A)
        ],
      MapTheme.snow => const [
          Color(0xFFEFF4F7),
          Color(0xFFC9D8E2),
          Color(0xFFE4ECF1)
        ],
    };
    for (var i = 0; i < 130; i++) {
      final p = Paint()
        ..color = tones[rng.nextInt(tones.length)]
            .withValues(alpha: 0.25 + rng.nextDouble() * 0.3);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(
            rng.nextDouble() * kGameWidth,
            rng.nextDouble() * kGameHeight,
          ),
          width: 30 + rng.nextDouble() * 90,
          height: 20 + rng.nextDouble() * 60,
        ),
        p,
      );
    }

    // Seyrek açıklıklar (patika / kül yaması / buz aynası).
    final patch = switch (map.theme) {
      MapTheme.grass => const Color(0xFF6B5A38),
      MapTheme.scorched => const Color(0xFF241611),
      MapTheme.snow => const Color(0xFFB9CEDA),
    };
    for (var i = 0; i < 26; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(
            rng.nextDouble() * kGameWidth,
            rng.nextDouble() * kGameHeight,
          ),
          width: 26 + rng.nextDouble() * 60,
          height: 16 + rng.nextDouble() * 34,
        ),
        Paint()..color = patch.withValues(alpha: 0.18 + rng.nextDouble() * 0.2),
      );
    }

    // Zemin süsleri: ot kümeleri / ALEV öbekleri / kuru çalı + kar tümseği.
    switch (map.theme) {
      case MapTheme.grass:
        final grassPaint = Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        // 80 küme statik (resimde); ~60 küme _renderAmbient'te SALINIR.
        for (var i = 0; i < 80; i++) {
          final x = rng.nextDouble() * kGameWidth;
          final y = rng.nextDouble() * kGameHeight;
          grassPaint.color = Color.lerp(
            const Color(0xFF7A9A4C),
            const Color(0xFF96B565),
            rng.nextDouble(),
          )!
              .withValues(alpha: 0.9);
          for (var b = 0; b < 3; b++) {
            final dx = (rng.nextDouble() - 0.5) * 8;
            c.drawLine(
              Offset(x + dx, y),
              Offset(x + dx + (rng.nextDouble() - 0.5) * 6,
                  y - 5 - rng.nextDouble() * 6),
              grassPaint,
            );
          }
        }
      case MapTheme.scorched:
        // Etrafta yer yer YANGINLAR: küçük alev öbekleri + kor halkası,
        // ayrıca zeminde koyu çatlaklar.
        for (var i = 0; i < 34; i++) {
          final x = rng.nextDouble() * kGameWidth;
          final y = rng.nextDouble() * kGameHeight;
          c.drawOval(
            Rect.fromCenter(center: Offset(x, y + 2), width: 16, height: 6),
            Paint()
              ..color = const Color(0xFFE8683C)
                  .withValues(alpha: 0.25 + rng.nextDouble() * 0.15),
          );
          for (var f = 0; f < 3; f++) {
            final fx = x - 5 + f * 5.0;
            final h = 6 + rng.nextDouble() * 6;
            c.drawPath(
              Path()
                ..moveTo(fx - 2.4, y + 2)
                ..lineTo(fx + (rng.nextDouble() - 0.5) * 3, y - h)
                ..lineTo(fx + 2.4, y + 2)
                ..close(),
              Paint()
                ..color = Color.lerp(const Color(0xFFE8683C),
                        const Color(0xFFF6C044), rng.nextDouble())!
                    .withValues(alpha: 0.85),
            );
          }
        }
        final crack = Paint()
          ..color = const Color(0xFF241611)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 22; i++) {
          var px = rng.nextDouble() * kGameWidth;
          var py = rng.nextDouble() * kGameHeight;
          for (var seg = 0; seg < 3; seg++) {
            final nx = px + (rng.nextDouble() - 0.3) * 26;
            final ny = py + (rng.nextDouble() - 0.5) * 18;
            c.drawLine(Offset(px, py), Offset(nx, ny), crack);
            px = nx;
            py = ny;
          }
        }
      case MapTheme.snow:
        // Kuru çalılar + kar tümsekleri (etraf buzlu, sessiz).
        final twig = Paint()
          ..color = const Color(0xFF8A6E52)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 60; i++) {
          final x = rng.nextDouble() * kGameWidth;
          final y = rng.nextDouble() * kGameHeight;
          if (i.isEven) {
            c.drawLine(Offset(x, y), Offset(x + 3, y - 8), twig);
            c.drawLine(Offset(x + 1, y - 4), Offset(x + 5, y - 7), twig);
            c.drawLine(Offset(x + 1, y - 4), Offset(x - 2, y - 8), twig);
          } else {
            c.drawOval(
              Rect.fromCenter(center: Offset(x, y), width: 18, height: 8),
              Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75),
            );
          }
        }
    }

    // Çakıllar (temaya uygun ton).
    final pebble = switch (map.theme) {
      MapTheme.grass => const Color(0xFF8A7B62),
      MapTheme.scorched => const Color(0xFF6E5648),
      MapTheme.snow => const Color(0xFF9FB0BC),
    };
    for (var i = 0; i < 60; i++) {
      c.drawCircle(
        Offset(rng.nextDouble() * kGameWidth, rng.nextDouble() * kGameHeight),
        1 + rng.nextDouble() * 2.5,
        Paint()..color = pebble.withValues(alpha: 0.5 + rng.nextDouble() * 0.3),
      );
    }
  }

  Path _featurePath(TerrainFeature f) {
    final path = Path()..moveTo(f.points.first.x, f.points.first.y);
    for (final p in f.points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    return path;
  }

  Paint _strokePaint(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Merkez etrafında pürüzlü (organik) kapalı yol üretir.
  /// [seed] aynı kaldıkça şekil aynı kalır; oynanış dairesiyle uyumludur.
  Path _organicBlob(Offset center, double radius, int seed,
      {int points = 14, double jitter = 0.16}) {
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * math.pi;
      final wob = math.sin(a * 3 + seed) * jitter +
          math.sin(a * 5 + seed * 1.7) * jitter * 0.5;
      final r = radius * (1 + wob);
      final x = center.dx + math.cos(a) * r;
      final y = center.dy + math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  /// TÜM sular birlikte, katman katman çizilir: önce hepsinin kıyısı, sonra
  /// hepsinin koyu suyu, sonra orta ton ve açık merkez. Böylece kesişen
  /// sular (hub halkası + moatlar, nehir birleşimleri) üst üste binmiş gibi
  /// durmaz — tek bir su kütlesi gibi kaynaşır. Kenarlar da dalgalı bantla
  /// çizilir: DÜZ KIYI YOK, her kıyı kıvrımlıdır.
  void _drawWaters(Canvas c, List<TerrainFeature> waters) {
    // (dolgu payı [px] | genişlik oranı | dalga | tohum | renk) katmanları.
    // Tema paletleri: çimen=su, çorak=LAV, kar=BUZ.
    final (bank, deep, mid, light) = switch (map.theme) {
      MapTheme.grass => (
          const Color(0xFF39472A),
          const Color(0xFF2E5D74),
          const Color(0xFF376C86),
          const Color(0xFF4A7D96),
        ),
      MapTheme.scorched => (
          const Color(0xFF2E1610),
          const Color(0xFF7A2410),
          const Color(0xFFB3491C),
          const Color(0xFFE8683C),
        ),
      MapTheme.snow => (
          const Color(0xFF9FB6C4),
          const Color(0xFF7FA6BC),
          const Color(0xFFA9C8D8),
          const Color(0xFFD5E8F2),
        ),
    };
    final layers = [
      (8.0, 0.0, 7.0, 0, bank),
      (0.0, 0.0, 6.0, 0, deep),
      (0.0, -0.23, 4.5, 3, mid),
      (0.0, -0.38, 3.0, 6, light),
    ];
    for (final (inflate, widthFrac, jitter, seedAdd, color) in layers) {
      final paint = Paint()..color = color;
      for (final f in waters) {
        final grow = inflate + f.width * widthFrac;
        if (f.width / 2 + grow < 4) continue;
        if (f.points.length == 1) {
          final center = Offset(f.points.first.x, f.points.first.y);
          final seed = (center.dx + center.dy).toInt() % 17 + seedAdd;
          c.drawPath(
              _organicBlob(center, f.width / 2 + grow, seed,
                  jitter: 0.10 + seedAdd * 0.012),
              paint);
        } else {
          c.drawPath(_waterBand(f, grow, jitter, seedAdd), paint);
        }
      }
    }
    // Kıyı süsleri: göletlerde temaya göre saz / obsidyen / buz kırığı.
    for (final f in waters.where((f) => f.points.length == 1)) {
      final center = Offset(f.points.first.x, f.points.first.y);
      final r = f.width / 2;
      final seed = (center.dx + center.dy).toInt() % 17;
      for (var i = 0; i < 9; i++) {
        final a = i * 0.7 + seed;
        final px = center.dx + math.cos(a) * (r + 4);
        final py = center.dy + math.sin(a) * (r + 4);
        switch (map.theme) {
          case MapTheme.grass:
            if (i % 3 == 0) {
              c.drawCircle(Offset(px, py), 2.4,
                  Paint()..color = const Color(0xFF8D877A));
            } else {
              final reed = Paint()
                ..color = const Color(0xFF6E8A44)
                ..strokeWidth = 1.6
                ..strokeCap = StrokeCap.round;
              c.drawLine(Offset(px, py), Offset(px + 2, py - 7), reed);
              c.drawLine(Offset(px + 3, py), Offset(px + 6, py - 6), reed);
            }
          case MapTheme.scorched:
            c.drawPath(
              Path()
                ..moveTo(px - 3, py + 2)
                ..lineTo(px, py - 5 - (i % 3) * 2)
                ..lineTo(px + 3, py + 2)
                ..close(),
              Paint()..color = const Color(0xFF241611),
            );
          case MapTheme.snow:
            c.drawPath(
              Path()
                ..moveTo(px - 3, py + 2)
                ..lineTo(px + 1, py - 6)
                ..lineTo(px + 4, py + 2)
                ..close(),
              Paint()..color = const Color(0xFFEFF6FA),
            );
        }
      }
    }
  }

  /// BATAKLIK: geçilebilir ama yavaşlatan çamur — katmanlı, kıvrımlı,
  /// temaya uygun (çimen: yosunlu çamur / çorak: kül çamuru / kar: sulu kar).
  void _drawSwamp(Canvas c, TerrainFeature f) {
    final (edge, mud, wet, deco) = switch (map.theme) {
      MapTheme.grass => (
          const Color(0xFF46482A),
          const Color(0xFF565436),
          const Color(0xFF3A3E24),
          const Color(0xFF6E8A44),
        ),
      MapTheme.scorched => (
          const Color(0xFF33241B),
          const Color(0xFF413127),
          const Color(0xFF261A13),
          const Color(0xFF6E5648),
        ),
      MapTheme.snow => (
          const Color(0xFF9AACB8),
          const Color(0xFFB2C2CC),
          const Color(0xFF879AA8),
          const Color(0xFF8A6E52),
        ),
    };
    // Bant yerine ORGANİK BLOB ZİNCİRİ: hat boyunca üst üste binen
    // pürüzlü lekeler tek kütle gibi kaynaşır — uçlar ve "yan köşeler"
    // asla düz kesilmez, her kenar kıvrımlıdır.
    Path band(double inflate, double jitter, int seedAdd) {
      if (f.points.length == 1) {
        final center = Offset(f.points.first.x, f.points.first.y);
        final seed = (center.dx + center.dy).toInt() % 13 + seedAdd;
        return _organicBlob(center, f.width / 2 + inflate, seed,
            jitter: 0.14 + seedAdd * 0.01);
      }
      final chain = Path();
      final pts = _samplePolyline(f.points, f.width * 0.42);
      for (var i = 0; i < pts.length; i++) {
        final wob =
            1 + 0.16 * math.sin(i * 1.9 + f.width + seedAdd * 1.3);
        chain.addPath(
          _organicBlob(Offset(pts[i].x, pts[i].y),
              (f.width / 2 + inflate) * wob, seedAdd + i * 3,
              points: 10, jitter: 0.2),
          Offset.zero,
        );
      }
      return chain;
    }

    // Katmanlar: nemli kenar → çamur gövde → ıslak göbek benekleri.
    c.drawPath(band(6, 6, 1), Paint()..color = edge.withValues(alpha: 0.85));
    c.drawPath(band(0, 5, 4), Paint()..color = mud);
    // Islak birikinti benekleri (parlak değil, koyu ve düzensiz).
    final line = _samplePolyline(
        f.points.length == 1 ? [f.points.first, f.points.first] : f.points,
        22);
    final rng = math.Random(f.width.toInt() + f.points.first.x.toInt());
    for (final p in line) {
      for (var k = 0; k < 2; k++) {
        final off = Offset((rng.nextDouble() - 0.5) * f.width * 0.7,
            (rng.nextDouble() - 0.5) * f.width * 0.55);
        c.drawPath(
          _organicBlob(Offset(p.x, p.y) + off, 4 + rng.nextDouble() * 6,
              rng.nextInt(20),
              points: 8, jitter: 0.28),
          Paint()..color = wet.withValues(alpha: 0.5 + rng.nextDouble() * 0.3),
        );
      }
      // Kabarcıklar.
      if (rng.nextBool()) {
        c.drawCircle(
          Offset(p.x + (rng.nextDouble() - 0.5) * f.width * 0.5,
              p.y + (rng.nextDouble() - 0.5) * f.width * 0.4),
          1.2 + rng.nextDouble(),
          Paint()
            ..color = const Color(0xFFDDDCC2).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      // Kenar sazları / kuru dallar (temaya göre).
      if (rng.nextInt(3) == 0) {
        final reed = Paint()
          ..color = deco
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        final rx = p.x + (rng.nextDouble() - 0.5) * f.width;
        final ry = p.y + (rng.nextDouble() - 0.5) * f.width * 0.7;
        c.drawLine(Offset(rx, ry), Offset(rx + 2, ry - 7), reed);
        c.drawLine(Offset(rx + 3, ry), Offset(rx + 6, ry - 5), reed);
      }
    }
  }

  /// Hattı iki ucundan [by] px uzatılmış kopya döndürür (uçların kıyıya
  /// tam OTURMASI için — görsel katmanlarda kullanılır, oynanışı etkilemez).


  /// GELGİT ŞERİDİ tabanı: her zaman görünen SIĞLIK ipucu — su üzerinde
  /// açık tonlu, kum beneklerinin seçildiği dalgalı bant.


  /// Su hattı için İKİ KENARI DA DALGALI kapalı bant yolu üretir.
  /// Kapalı hatlar (halka) için dış+iç iki döngü (even-odd); açık hatlar
  /// için gidiş-dönüş tek döngü. Dalga frekansları tam sayı olduğundan
  /// halkalarda ek yeri görünmez.
  Path _waterBand(TerrainFeature f, double inflate, double jitter, int seedAdd) {
    final closed = f.points.first.distanceTo(f.points.last) < 1;
    final pts = _samplePolyline(f.points, 13);
    final half = f.width / 2 + inflate;
    final seed = ((f.points.first.x + f.points.last.y) % 23) + seedAdd;

    // Yay uzunlukları (dalga fazı hat boyunca aksın diye).
    final ds = List<double>.filled(pts.length, 0);
    for (var i = 1; i < pts.length; i++) {
      ds[i] = ds[i - 1] + pts[i].distanceTo(pts[i - 1]);
    }
    final total = math.max(ds.last, 1.0);

    Vector2 dirAt(int i) {
      final a = pts[math.max(0, i - 1)];
      final b = pts[math.min(pts.length - 1, i + 1)];
      final d = b - a;
      return d.length2 == 0 ? Vector2(1, 0) : d.normalized();
    }

    double wob(int i, int k) {
      final t = ds[i] / total * 2 * math.pi;
      return math.sin(t * 3 + seed + k) * jitter +
          math.sin(t * 7 + seed * 1.7 + k * 2) * jitter * 0.6;
    }

    void edge(Path path, double side, int k, bool reverse) {
      final order = [
        for (var i = 0; i < pts.length; i++) reverse ? pts.length - 1 - i : i
      ];
      var first = true;
      for (final i in order) {
        final dir = dirAt(i);
        final w = (half + wob(i, k)) * side;
        final x = pts[i].x - dir.y * w;
        final y = pts[i].y + dir.x * w;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    final path = Path();
    if (closed) {
      path.fillType = PathFillType.evenOdd;
      edge(path, 1, 0, false); // dış kenar
      edge(path, -1, 5, false); // iç kenar (delik)
    } else {
      // Gidiş (+kenar) ve dönüş (-kenar) tek kapalı bant.
      final up = Path();
      var first = true;
      for (var i = 0; i < pts.length; i++) {
        final dir = dirAt(i);
        final w = half + wob(i, 0);
        final x = pts[i].x - dir.y * w;
        final y = pts[i].y + dir.x * w;
        if (first) {
          up.moveTo(x, y);
          first = false;
        } else {
          up.lineTo(x, y);
        }
      }
      for (var i = pts.length - 1; i >= 0; i--) {
        final dir = dirAt(i);
        final w = half + wob(i, 5);
        up.lineTo(pts[i].x + dir.y * w, pts[i].y - dir.x * w);
      }
      up.close();
      path.addPath(up, Offset.zero);
    }
    return path;
  }

  /// Polyline'ı ~[step] px aralıklarla örnekler (uç noktalar dahil).
  List<Vector2> _samplePolyline(List<Vector2> points, double step) {
    final out = <Vector2>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final n = math.max(1, (a.distanceTo(b) / step).ceil());
      for (var s = 0; s < n; s++) {
        out.add(a + (b - a) * (s / n));
      }
    }
    out.add(points.last.clone());
    return out;
  }

  void _drawBridge(Canvas c, TerrainFeature f) {
    final a = f.points.first;
    final b = f.points.last;
    final dir = (b - a).normalized();
    final normal = Vector2(-dir.y, dir.x);
    final len = a.distanceTo(b);
    final seed = (a.x + b.y).toInt() % 31;

    // Gölge.
    c.drawPath(_featurePath(f), _strokePaint(const Color(0x66241A0E), f.width + 10));

    // İki uçta ORGANİK taş ayaklar (kıyıyla bütünleşik).
    for (final (end, es) in [(a, seed), (b, seed + 7)]) {
      final center = Offset(end.x, end.y);
      c.drawPath(_organicBlob(center, f.width / 2 + 7, es, points: 10, jitter: 0.22),
          Paint()..color = const Color(0xFF6B5A38));
      c.drawPath(_organicBlob(center, f.width / 2 + 2, es + 3, points: 9, jitter: 0.2),
          Paint()..color = const Color(0xFF7A6845));
      // Ayak dibinde taşlar.
      for (var i = 0; i < 4; i++) {
        final aa = es + i * 1.7;
        c.drawCircle(
          center.translate(
              math.cos(aa) * (f.width / 2 + 9), math.sin(aa) * (f.width / 2 + 6)),
          1.8 + (i % 2),
          Paint()..color = const Color(0xFF8D877A),
        );
      }
    }

    // Kalaslar: her biri FARKLI uzunlukta ve hafif kaymış — pürüzlü kenar.
    for (var d = 5.0; d < len; d += 8) {
      final p = a + dir * d;
      final wobble = math.sin(d * 0.9 + seed) * 2.5 +
          math.sin(d * 0.37 + seed * 1.7) * 1.5;
      final halfLen = f.width / 2 - 1 + wobble;
      final slide = math.sin(d * 1.3 + seed) * 1.2; // hafif eksen kayması
      final half = normal * halfLen;
      final off = normal * slide;
      final tone = ((d ~/ 8) % 3 == 0)
          ? const Color(0xFF5E4A2C)
          : ((d ~/ 8) % 3 == 1)
              ? const Color(0xFF6B5533)
              : const Color(0xFF77603C);
      c.drawLine(
        Offset(p.x - half.x + off.x, p.y - half.y + off.y),
        Offset(p.x + half.x + off.x, p.y + half.y + off.y),
        Paint()
          ..color = tone
          ..strokeWidth = 4.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Yan korkuluk halatları: dalgalı (gergin ip değil, örgü sarkması).
    for (final side in const [-1.0, 1.0]) {
      final rope = Path();
      for (var d = 0.0; d <= len; d += 10) {
        final sag = math.sin(d / len * math.pi * 3 + seed) * 1.6;
        final off = normal * ((f.width / 2 + 1.5 + sag) * side);
        final p = a + dir * d + off;
        if (d == 0) {
          rope.moveTo(p.x, p.y);
        } else {
          rope.lineTo(p.x, p.y);
        }
      }
      c.drawPath(
        rope,
        Paint()
          ..color = const Color(0xFF3E3018)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
      // Babalar (uçlarda + ortada).
      for (final d in [3.0, len / 2, len - 3]) {
        final p = a + dir * d + normal * ((f.width / 2 + 1.5) * side);
        c.drawCircle(Offset(p.x, p.y), 2.6,
            Paint()..color = const Color(0xFF4A3A20));
      }
    }
  }

  /// Ayraç şeritleri: ORGANİK SIRADAĞ — kalınlığı hat boyunca YER YER
  /// artan (düşük frekanslı şişkinlik), katmanlı kütle: geniş etek
  /// gölgesi → koyu taban → gövde → aydınlık sırt; şişkin bölgelerde
  /// BÜYÜK karlı zirveler, incelen bölgelerde alçak tepecikler.
  /// Görsel kalınlık oynanışı DEĞİŞTİRMEZ (geçilmez alan = width sabit);
  /// karşılıklı dağlar farklı desen alsa da genişlik ortalaması aynıdır.
  void _drawRoot(Canvas c, TerrainFeature f) {
    final a = f.points.first;
    final b = f.points.last;
    final dir = (b - a).normalized();
    final normal = Vector2(-dir.y, dir.x);
    final len = a.distanceTo(b);
    final half = f.width / 2;
    final seed = (a.x + b.y).toInt() % 29;

    // Hat boyunca YARI-GENİŞLİK: düşük frekanslı şişkinlik (dağ kütlesi
    // yer yer kabarır) + ince pürüz. 0.55×–1.6× arası salınır.
    double halfAt(double d) {
      final bulge = 0.50 * math.sin(d * 0.020 + seed) +
          0.26 * math.sin(d * 0.0085 + seed * 1.7) +
          0.10 * math.sin(d * 0.051 + seed * 3.1);
      return half * (1.10 + bulge).clamp(0.55, 1.80);
    }

    // Uçlara doğru sivrilerek biter (çizgi gibi kesilmez).
    double taper(double d) {
      const fade = 30.0;
      final fromA = ((d + 10) / fade).clamp(0.0, 1.0);
      final fromB = ((len + 10 - d) / fade).clamp(0.0, 1.0);
      return math.sqrt(math.min(fromA, fromB));
    }

    Path massif(double scale, double inflate, double jitter, int js) {
      final path = Path();
      const step = 10.0;
      var first = true;
      for (var d = -10.0; d <= len + 10; d += step) {
        final w = (halfAt(d) * scale + inflate) * taper(d) +
            math.sin(d * 0.23 + seed * 1.7 + js) * jitter;
        final p = a + dir * d + normal * math.max(w, 0.5);
        if (first) {
          path.moveTo(p.x, p.y);
          first = false;
        } else {
          path.lineTo(p.x, p.y);
        }
      }
      for (var d = len + 10; d >= -10.0; d -= step) {
        final w = (halfAt(d) * scale + inflate) * taper(d) +
            math.sin(d * 0.31 + seed * 2.3 + js) * jitter;
        final p = a + dir * d - normal * math.max(w, 0.5);
        path.lineTo(p.x, p.y);
      }
      return path..close();
    }

    // Katmanlar: etek gölgesi → koyu taban → gövde → aydınlık sırt.
    c.drawPath(massif(1.0, 7, 2.4, 0), Paint()..color = const Color(0x40241A0E));
    c.drawPath(massif(1.0, 2, 2.0, 3), Paint()..color = const Color(0xFF5E594E));
    c.drawPath(massif(0.86, 0, 1.8, 5), Paint()..color = const Color(0xFF6E685C));
    c.drawPath(massif(0.5, 0, 1.4, 8), Paint()..color = const Color(0xFF7E786A));

    // Zirveler: şişkin bölgelerde BÜYÜK, incelenlerde küçük; kar yalnız
    // yüksek zirvelerde. Aralık da kütleye uyar (büyük dağ = seyrek zirve).
    var d = 20.0;
    while (d < len - 14) {
      final hw = halfAt(d);
      final big = hw > half * 1.05;
      // İnce bölgelerde her zirve çizilmez — dişli görünüm kırılır.
      if (!big && math.sin(d * 1.31 + seed * 2.0) > 0.15) {
        d += 26;
        continue;
      }
      final base = a + dir * d;
      final jx = math.sin(d * 0.7 + seed) * hw * 0.25;
      final px = base.x + normal.x * jx;
      final py = base.y + normal.y * jx;
      final ph = hw * (big ? 2.0 : 1.35) +
          math.sin(d * 0.37 + seed) * hw * 0.25;
      final pw = hw * (big ? 1.35 : 0.95);
      final peak = Path()
        ..moveTo(px - pw, py + 4)
        ..lineTo(px - pw * 0.12, py - ph)
        ..lineTo(px + pw * 0.22, py - ph * 0.88)
        ..lineTo(px + pw, py + 4)
        ..close();
      c.drawPath(peak, Paint()..color = const Color(0xFF847E70));
      final shade = Path()
        ..moveTo(px - pw * 0.12, py - ph)
        ..lineTo(px + pw * 0.22, py - ph * 0.88)
        ..lineTo(px + pw, py + 4)
        ..lineTo(px + pw * 0.2, py + 4)
        ..close();
      c.drawPath(shade, Paint()..color = const Color(0xFF615C50));
      if (big) {
        final snow = Path()
          ..moveTo(px - pw * 0.42, py - ph * 0.62)
          ..lineTo(px - pw * 0.12, py - ph)
          ..lineTo(px + pw * 0.22, py - ph * 0.88)
          ..lineTo(px + pw * 0.5, py - ph * 0.58)
          ..lineTo(px + pw * 0.1, py - ph * 0.52)
          ..close();
        c.drawPath(snow, Paint()..color = const Color(0xFFF3F3EA));
      }
      d += big ? 40 + hw * 0.6 : 30;
    }

    // Etekler: kaya kırıntıları + yeşile karışan çalı öbekleri.
    for (var d = 12.0; d < len; d += 34) {
      final sSide = (d ~/ 34).isEven ? 1.0 : -1.0;
      final hw = halfAt(d) * taper(d);
      final p = a + dir * d + normal * (hw + 6) * sSide;
      if ((d ~/ 34) % 3 == 2) {
        c.drawOval(
          Rect.fromCenter(
              center: Offset(p.x, p.y), width: 9, height: 5),
          Paint()..color = const Color(0x66557239),
        );
      } else {
        c.drawCircle(Offset(p.x, p.y), 1.8 + (d.toInt() % 2),
            Paint()..color = const Color(0xFF7A7468));
      }
    }
  }

  /// Kayalık: tepesi hafif karlı, pürüzlü mini DAĞ — her taş farklı.
  void _drawRock(Canvas c, TerrainFeature f) {
    final center = Offset(f.points.first.x, f.points.first.y);
    final r = f.width / 2;
    final seed = (center.dx * 3 + center.dy * 7).toInt() % 23;

    // Zemin gölgesi.
    c.drawOval(
      Rect.fromCenter(
          center: center.translate(3, r * 0.35),
          width: r * 2.3,
          height: r * 1.1),
      Paint()..color = const Color(0x4D241A0E),
    );

    // Kaya kütlesi: pürüzlü organik taban.
    c.drawPath(_organicBlob(center, r, seed, points: 11, jitter: 0.2),
        Paint()..color = const Color(0xFF6E685C));
    // Aydınlık yüz (kuzeybatı).
    c.drawPath(
        _organicBlob(center.translate(-r * 0.18, -r * 0.22), r * 0.62,
            seed + 5, points: 9, jitter: 0.22),
        Paint()..color = const Color(0xFF847E70));

    // Zirveler: 2-3 sivri tepe (dağ silueti).
    final peaks = 2 + seed % 2;
    for (var i = 0; i < peaks; i++) {
      final px = center.dx + (i - (peaks - 1) / 2) * r * 0.55 +
          math.sin(seed + i * 2.4) * r * 0.12;
      final ph = r * (0.75 + (i == peaks ~/ 2 ? 0.35 : 0.05)) +
          math.sin(seed * 1.3 + i) * r * 0.08;
      final baseY = center.dy + r * 0.15;
      final peak = Path()
        ..moveTo(px - r * 0.42, baseY)
        ..lineTo(px - r * 0.05, baseY - ph)
        ..lineTo(px + r * 0.08, baseY - ph * 0.92)
        ..lineTo(px + r * 0.45, baseY)
        ..close();
      c.drawPath(peak, Paint()..color = const Color(0xFF7A7468));
      // Gölgeli doğu yamacı.
      final shade = Path()
        ..moveTo(px - r * 0.05, baseY - ph)
        ..lineTo(px + r * 0.08, baseY - ph * 0.92)
        ..lineTo(px + r * 0.45, baseY)
        ..lineTo(px + r * 0.1, baseY)
        ..close();
      c.drawPath(shade, Paint()..color = const Color(0xFF615C50));
      // Karlı tepe.
      final snow = Path()
        ..moveTo(px - r * 0.16, baseY - ph * 0.72)
        ..lineTo(px - r * 0.05, baseY - ph)
        ..lineTo(px + r * 0.08, baseY - ph * 0.92)
        ..lineTo(px + r * 0.17, baseY - ph * 0.7)
        ..lineTo(px + r * 0.06, baseY - ph * 0.62)
        ..lineTo(px - r * 0.06, baseY - ph * 0.68)
        ..close();
      c.drawPath(snow, Paint()..color = const Color(0xFFEDEfe6));
      c.drawPath(snow, Paint()..color = const Color(0xFFF7F7F0));
    }
    // Eteklerde birkaç kaya kırıntısı.
    for (var i = 0; i < 4; i++) {
      final aa = seed + i * 1.9;
      c.drawCircle(
        center.translate(math.cos(aa) * (r + 4), math.sin(aa) * (r * 0.7) + 3),
        1.6 + (i % 2),
        Paint()..color = const Color(0xFF7A7468),
      );
    }
  }

  // ---------------------------------------------------------------- debug

  void _drawDebugGrid(Canvas c) {
    final paint = Paint()..color = const Color(0x66D32F2F);
    for (var r = 0; r < grid.rows; r++) {
      for (var col = 0; col < grid.cols; col++) {
        if (grid.isBlockedCell(col, r)) {
          c.drawRect(
            Rect.fromLTWH(col * grid.cellSize, r * grid.cellSize,
                grid.cellSize - 1, grid.cellSize - 1),
            paint,
          );
        }
      }
    }
  }
}

/// Salınan ot kümesi: kök noktası + önceden üretilmiş saplar.
class _SwayTuft {
  const _SwayTuft({
    required this.base,
    required this.color,
    required this.phase,
    required this.speed,
    required this.blades,
  });

  final Offset base;
  final Color color;
  final double phase;
  final double speed;

  /// Sap başına (kök dx, yükseklik) — dx uca da kısmen taşınır (eğim).
  final List<Offset> blades;
}
