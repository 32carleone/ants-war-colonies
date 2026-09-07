import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../data/units.dart';
import 'ant_painter.dart';

/// Performans: karıncalar her karede ~40 canvas komutuyla çizilmek yerine,
/// tip başına [frames] yürüyüş karesi bir kez TEK GPU dokusuna (atlas)
/// alınır. ArmyLayer tüm orduyu bu atlastan TEK drawRawAtlas çağrısıyla
/// basar (600 birim ≈ 3000 çizim komutu → 1 native çağrı); gölge ve takım
/// yaması da atlasın ek hücreleridir.
class AntSpriteCache {
  AntSpriteCache._();

  static final AntSpriteCache instance = AntSpriteCache._();

  /// Yürüyüş döngüsü kare sayısı.
  static const int frames = 10;

  /// Karınca-uzayı görüş alanı: gövde x∈[-16,18], y∈[-11,11] içinde kalır.
  static const double halfExtent = 20;

  /// Kalite için büyütülmüş çizim (ekranda küçültülerek basılır).
  static const double renderScale = 3;

  /// Atlas hücre kenarı (px).
  static const double cell = halfExtent * 2 * renderScale;

  /// TEK sprite sayfası: satır = birim tipi (frames sütun), son satırda
  /// gölge (0) ve takım yaması (1) hücreleri.
  ui.Image? atlas;

  bool get ready => atlas != null;

  /// [type] + yürüyüş fazı için atlas kaynak dikdörtgeni.
  ui.Rect frameRect(UnitType type, double walkPhase) {
    final idx =
        ((walkPhase / (2 * 3.14159265)) * frames).floor() % frames;
    final f = idx < 0 ? idx + frames : idx;
    return ui.Rect.fromLTWH(f * cell, type.index * cell, cell, cell);
  }

  /// Gölge hücresi (dönmeden basılır).
  ui.Rect get shadowRect => ui.Rect.fromLTWH(
      0, UnitType.values.length * cell, cell, cell);

  /// Takım yaması hücresi (BEYAZ çizilir; modulate ile takım rengine
  /// boyanır) — gövdeyle aynı dönüşle basılır.
  ui.Rect get dotRect => ui.Rect.fromLTWH(
      cell, UnitType.values.length * cell, cell, cell);

  Future<void> ensureLoaded() async {
    if (ready) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final type in UnitType.values) {
      for (var f = 0; f < frames; f++) {
        canvas.save();
        canvas.translate(f * cell, type.index * cell);
        canvas.scale(renderScale);
        canvas.translate(halfExtent, halfExtent);
        paintAnt(
          canvas,
          type,
          walkPhase: f / frames * 2 * 3.14159265,
          idleTime: f * 0.37, // anten salınımı kare bazında bakılı
          teamColor: const Color(0x00000000), // takım yaması ayrı hücre
        );
        canvas.restore();
      }
    }
    // Son satır: gölge + takım yaması hücreleri.
    final extraY = UnitType.values.length * cell;
    canvas.save();
    canvas.translate(cell / 2, extraY + cell / 2);
    canvas.scale(renderScale);
    // Gölge: birim-uzayında (0, 1.5) merkezli 20×9 oval.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1.5), width: 20, height: 9),
      Paint()..color = const Color(0x33000000),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(cell + cell / 2, extraY + cell / 2);
    canvas.scale(renderScale);
    // Takım yaması: abdomen ovali + doğal parlama (BEYAZ; modulate boyar).
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(-6.5, 0), width: 9.4, height: 6.4),
      Paint()..color = const Color(0xD9FFFFFF),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-7, -1.2), width: 5, height: 2),
      Paint()..color = const Color(0x59FFFFFF),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    atlas = await picture.toImage(
      (frames * cell).round(),
      ((UnitType.values.length + 1) * cell).round(),
    );
    picture.dispose();
  }
}
