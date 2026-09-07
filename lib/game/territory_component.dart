import 'dart:ui';

import 'package:flame/components.dart';

import 'ants_wars_game.dart';
import 'building_painter.dart' show buildingBlob;

/// BÖLGE SINIRLARI: her oyuncunun ana yuvasına bağlı yumuşak etki alanı.
/// Bina aldıkça alan o binaya doğru genişler. Kenarlar ORGANİKTİR (daire
/// gibi durmaz) ve SU alanlarından kırpılır — sınır çizgisi kıvrımlı kıyıyı
/// birebir izler, kara sınırlarının diliyle uyumludur.
/// Çok belirgin değildir: çok soluk dolgu + ince kenar çizgisi.
/// Sahiplik harita bilgisidir (bayraklar gibi) — sisten etkilenmez.
class TerritoryComponent extends Component
    with HasGameReference<AntsWarsGame> {
  TerritoryComponent() {
    priority = -8; // haritanın hemen üstü, diğer her şeyin altı
  }

  /// Sahiplik durumunun imzası: değişmedikçe yollar yeniden hesaplanmaz.
  int _stamp = -1;

  /// PERFORMANS: karmaşık bölge yolları her karede çizilmez — sahiplik
  /// değişince bir kez Picture'a kaydedilir, her karede o resim basılır.
  Picture? _picture;

  @override
  void update(double dt) {
    super.update(dt);
    var s = 7;
    for (final b in game.buildings) {
      s = (s * 31 + (b.owner?.id ?? -1) + 2) & 0x3FFFFFFF;
      s = (s * 31 + b.level) & 0x3FFFFFFF; // seviye sınırı genişletir
    }
    for (final n in game.nests.values) {
      s = (s * 31 + (n.destroyed ? 0 : (n.owner.id + 1) * 4)) &
          0x3FFFFFFF;
    }
    if (s != _stamp) {
      _stamp = s;
      _rebuild();
    }
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _rebuild() {
    // ESKİ resim serbest bırakılır: Picture NATIVE bellek tutar; dispose
    // edilmezse her sahiplik değişiminde birikir (uzun maçta ŞİŞME).
    _picture?.dispose();
    _picture = null;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final water = game.mapComponent.waterMask;
    for (final p in game.gameState.players) {
      if (p.eliminated) continue;
      final nest = game.nests[p.id];
      if (nest == null || nest.destroyed) continue;
      // Ana yuvanın etki alanı + sahip olunan her binanın etki alanı.
      // Yuva seviyesi ve bina seviyesi etki alanını bir tık genişletir.
      var area = _blobAt(nest.position, 170);
      for (final b in game.buildings) {
        if (b.owner?.id != p.id) continue;
        area = Path.combine(PathOperation.union, area,
            _blobAt(b.position, 110 + 20.0 * b.level));
      }
      // Sular bölgeden çıkarılır: sınır kıyı çizgisini izler.
      area = Path.combine(PathOperation.difference, area, water);
      canvas.drawPath(
          area, Paint()..color = p.color.withValues(alpha: 0.05));
      canvas.drawPath(
        area,
        Paint()
          ..color = p.color.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round,
      );
    }
    _picture = recorder.endRecording();
  }

  /// Organik etki alanı: hafif dalgalı kenarlı kapalı şekil (daire değil).
  Path _blobAt(Vector2 c, double r) => buildingBlob(
        Offset(c.x, c.y),
        r,
        (c.x * 0.7 + c.y).toInt() % 19,
        jitter: 0.09,
        points: 24,
      );

  @override
  void render(Canvas canvas) {
    final pic = _picture;
    if (pic != null) canvas.drawPicture(pic);
  }
}
