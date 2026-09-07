import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../data/settings.dart';
import '../models/building.dart';
import 'ants_wars_game.dart';

/// Sis (fog of war) — insan oyuncunun bakış açısından:
///
/// - Harita HER ZAMAN açık (arazi tamamen görünür).
/// - Şu an görmediğin alanlar HAFİF kararır; oradaki düşman askerleri ve
///   bina sahiplik bilgisi gizlidir.
/// - Görüş kaynakları: kendi yuvan, binaların, askerlerin; delikler yumuşak
///   kenarlı ve hafifçe "nefes alır".
///
/// Diğer bileşenler [isVisible] ile düşman varlıkları gizler.
class FogOfWar extends Component with HasGameReference<AntsWarsGame> {
  FogOfWar() : super(priority: 50);

  static const double cellSize = 32;
  final int cols = (kGameWidth / cellSize).ceil();
  final int rows = (kGameHeight / cellSize).ceil();

  late final List<bool> _visible = List.filled(cols * rows, false);
  late final List<bool> _explored = List.filled(cols * rows, false);

  /// Bu karedeki görüş kaynakları: (konum, yarıçap).
  final List<(Vector2, double)> _sources = [];
  double _time = 0;

  /// Performans: yumuşak kenarlı delik dokusu bir kez üretilir,
  /// kaynak başına shader kurmak yerine ölçekli drawImageRect basılır.
  ui.Image? _holeTexture;

  /// İnsan oyuncu yoksa/elendiyse seyirci modu: her şey görünür.
  bool _spectator = false;

  @override
  void onRemove() {
    // Maç yeniden kurulunca doku native belleği bırakır (şişme önlemi).
    _holeTexture?.dispose();
    _holeTexture = null;
    super.onRemove();
  }

  bool get _active => game.fogEnabled && !_spectator;

  /// Bu nokta insan oyuncu için şu an görünür mü?
  bool isVisible(Vector2 p) {
    if (!_active) return true;
    final c = p.x ~/ cellSize;
    final r = p.y ~/ cellSize;
    if (c < 0 || r < 0 || c >= cols || r >= rows) return false;
    return _visible[r * cols + c];
  }

  /// Bu nokta daha önce keşfedildi mi?
  bool isExplored(Vector2 p) {
    if (!_active) return true;
    final c = p.x ~/ cellSize;
    final r = p.y ~/ cellSize;
    if (c < 0 || r < 0 || c >= cols || r >= rows) return false;
    return _explored[r * cols + c];
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final human = game.gameState.humanPlayer;
    _spectator = human == null || human.eliminated;
    if (!_active) return;

    _sources.clear();
    final team = human!.team; // 2v2'de müttefik görüşü paylaşılır
    // Yuvalar.
    for (final nest in game.nests.values) {
      if (nest.destroyed || nest.owner.team != team) continue;
      _sources.add((nest.position, kNestVision));
    }
    // Binalar (kule seviyeyle daha uzağı görür).
    for (final b in game.buildings) {
      if (b.owner?.team != team) continue;
      final r = b.type == BuildingType.tower
          ? towerVision(b.level)
          : buildingVision(b.level);
      _sources.add((b.position, r));
    }
    // Askerler.
    for (final u in game.units) {
      if (u.dead || u.combatTeam != team || u.spawnDelay > 0) continue;
      _sources.add((u.position, kUnitVision));
    }

    // Görünürlük ızgarasını yeniden kur.
    for (var i = 0; i < _visible.length; i++) {
      _visible[i] = false;
    }
    for (final (pos, radius) in _sources) {
      final rSq = radius * radius;
      final minC = math.max(0, ((pos.x - radius) / cellSize).floor());
      final maxC = math.min(cols - 1, ((pos.x + radius) / cellSize).floor());
      final minR = math.max(0, ((pos.y - radius) / cellSize).floor());
      final maxR = math.min(rows - 1, ((pos.y + radius) / cellSize).floor());
      for (var r = minR; r <= maxR; r++) {
        for (var c = minC; c <= maxC; c++) {
          final cx = (c + 0.5) * cellSize;
          final cy = (r + 0.5) * cellSize;
          final dx = cx - pos.x;
          final dy = cy - pos.y;
          if (dx * dx + dy * dy <= rSq) {
            final idx = r * cols + c;
            _visible[idx] = true;
            _explored[idx] = true;
          }
        }
      }
    }
  }

  /// Yumuşak delik dokusunu (256px beyaz→saydam radyal daire) arka planda
  /// pişirir; hazır olana dek çağıran shader yoluna düşer.
  bool _holeBaking = false;

  void _ensureHoleTexture() {
    if (_holeTexture != null || _holeBaking) return;
    _holeBaking = true;
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(size / 2, size / 2),
          size / 2,
          const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          const [0.0, 0.7, 1.0],
        ),
    );
    recorder.endRecording().toImage(256, 256).then((img) {
      _holeTexture = img;
      _holeBaking = false;
    });
  }

  /// PERFORMANS: delikler kaynak başına DEĞİL, 48px kovalara birleştirilip
  /// çizilir — 200 askerlik bir ordu ~200 yerine ~15-25 delik üretir.
  /// (Tam ekran saveLayer + asker başına dstOut çizimi, uzun maçlarda
  /// telefonu ezen ana GPU maliyetiydi.)
  static const double _bucket = 48;
  final Map<int, (Vector2, double)> _merged = {};

  Iterable<(Vector2, double)> get _renderSources {
    _merged.clear();
    for (final (pos, radius) in _sources) {
      final key =
          (pos.x ~/ _bucket) * 1000 + (pos.y ~/ _bucket);
      final cur = _merged[key];
      if (cur == null || cur.$2 < radius) _merged[key] = (pos, radius);
    }
    return _merged.values;
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;

    // DÜŞÜK KALİTE (ayarlar): saveLayer YOK — görünmeyen hücreler satır
    // şeritleri halinde tek geçişte karartılır. Zayıf cihazlar için.
    if (!appSettings.highQuality) {
      _renderLowQuality(canvas);
      return;
    }

    const bounds = Rect.fromLTWH(0, 0, kGameWidth, kGameHeight);
    // Tek katman: görmediğin yerler HAFİF kararır; görünen alanlara
    // yumuşak delik açılır. Harita her zaman okunur kalır.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
        bounds, Paint()..color = const Color(0xFF10140A).withValues(alpha: 0.38));
    final hole = _holeTexture;
    final holePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..filterQuality = FilterQuality.low;
    var i = 0;
    for (final (pos, radius) in _renderSources) {
      // Sis hafifçe nefes alır — delik yarıçapı süzülerek oynar.
      // Kovalar birleştiği için delik bir tık cömert açılır.
      final wob =
          (radius + _bucket * 0.4) * (1 + 0.02 * math.sin(_time * 1.8 + i));
      i++;
      if (hole != null) {
        canvas.drawImageRect(
          hole,
          const Rect.fromLTWH(0, 0, 256, 256),
          Rect.fromCircle(center: Offset(pos.x, pos.y), radius: wob),
          holePaint,
        );
      } else {
        _ensureHoleTexture();
        canvas.drawCircle(
          Offset(pos.x, pos.y),
          wob,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = ui.Gradient.radial(
              Offset(pos.x, pos.y),
              wob,
              const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              const [0.0, 0.7, 1.0],
            ),
        );
      }
    }
    canvas.restore();
  }

  /// Ucuz sis: görünmeyen hücre dizileri yatay şeritlere birleştirilir,
  /// katmansız tek renkte basılır (kenarlar sert ama maliyet ~sıfır).
  void _renderLowQuality(Canvas canvas) {
    final paint =
        Paint()..color = const Color(0xFF10140A).withValues(alpha: 0.38);
    for (var r = 0; r < rows; r++) {
      var runStart = -1;
      for (var c = 0; c <= cols; c++) {
        final vis = c < cols && _visible[r * cols + c];
        if (!vis && runStart < 0) {
          runStart = c;
        } else if (vis && runStart >= 0) {
          canvas.drawRect(
            Rect.fromLTWH(runStart * cellSize, r * cellSize,
                (c - runStart) * cellSize, cellSize),
            paint,
          );
          runStart = -1;
        }
      }
      if (runStart >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(runStart * cellSize, r * cellSize,
              (cols - runStart) * cellSize, cellSize),
          paint,
        );
      }
    }
  }
}
