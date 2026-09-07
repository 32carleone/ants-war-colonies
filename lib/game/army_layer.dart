import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'ant_sprite_cache.dart';
import 'ants_wars_game.dart';

/// ORDU KATMANI: tüm karıncaların gölgesi, gövdesi, takım yaması ve
/// cesetleri TEK drawRawAtlas çağrısıyla basılır. Eski yol birim başına
/// save/transform + 5-6 çizim komutuydu (600 birim ≈ 3000+ komut) —
/// büyük ordulu geç oyunun "gittikçe kasıyor" hissinin ana raster maliyeti.
/// Nadir ekstralar (seçim halkası, buz, can barı) birimlerin kendi
/// render'ında kalır; SEÇİLİ birimler eski tam yoldan çizilir (halka
/// gövdenin ALTINDA kalmalı).
class ArmyLayer extends Component with HasGameReference<AntsWarsGame> {
  // Yeniden kullanılan tamponlar (allokasyonsuz kare).
  Float32List _xform = Float32List(256 * 4);
  Float32List _rects = Float32List(256 * 4);
  Int32List _colors = Int32List(256);
  int _n = 0;

  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  void _ensure(int extra) {
    final need = _n + extra;
    if (need * 4 <= _xform.length) return;
    var cap = _xform.length ~/ 4;
    while (cap < need) {
      cap *= 2;
    }
    _xform = Float32List(cap * 4)..setAll(0, _xform);
    _rects = Float32List(cap * 4)..setAll(0, _rects);
    _colors = Int32List(cap)..setAll(0, _colors);
  }

  void _add(double rot, double scale, double x, double y, ui.Rect src,
      int color) {
    const a = AntSpriteCache.cell / 2; // hücre merkezi çapa
    final scos = math.cos(rot) * scale;
    final ssin = math.sin(rot) * scale;
    final i4 = _n * 4;
    _xform[i4] = scos;
    _xform[i4 + 1] = ssin;
    _xform[i4 + 2] = x - (scos * a - ssin * a);
    _xform[i4 + 3] = y - (ssin * a + scos * a);
    _rects[i4] = src.left;
    _rects[i4 + 1] = src.top;
    _rects[i4 + 2] = src.right;
    _rects[i4 + 3] = src.bottom;
    _colors[_n] = color;
    _n++;
  }

  @override
  void render(ui.Canvas canvas) {
    final cache = AntSpriteCache.instance;
    final atlas = cache.atlas;
    if (atlas == null) return; // hazır değilken birimler kendini çizer
    _n = 0;
    final human = game.gameState.humanPlayer;
    final units = game.units;
    _ensure(units.length * 3);

    const white = 0xFFFFFFFF;
    final shadow = cache.shadowRect;
    final dot = cache.dotRect;

    // 1) Gölgeler (canlılar; dönmeden) — hepsi gövdelerin altında kalır.
    for (final u in units) {
      if (u.dead || u.spawnDelay > 0 || u.selected) continue;
      if (human != null &&
          u.owner.id != human.id &&
          !game.fog.isVisible(u.position)) {
        continue;
      }
      final s = u.spec.scale / AntSpriteCache.renderScale;
      _add(0, s, u.position.x, u.position.y, shadow, white);
    }
    // 2) Cesetler (soluk, dönük) — gövdelerin altında.
    for (final u in units) {
      if (!u.dead || u.spawnDelay > 0) continue;
      if (human != null &&
          u.owner.id != human.id &&
          !game.fog.isVisible(u.position)) {
        continue;
      }
      _ensure(1);
      final s = u.spec.scale / AntSpriteCache.renderScale;
      final a = (u.corpseAlpha * 255).round().clamp(0, 255);
      _add(u.facing + 2.6, s, u.position.x, u.position.y,
          cache.frameRect(u.type, 0), (a << 24) | 0xFFFFFF);
    }
    // 3) Canlı gövdeler + takım yamaları.
    for (final u in units) {
      if (u.dead || u.spawnDelay > 0 || u.selected) continue;
      if (human != null &&
          u.owner.id != human.id &&
          !game.fog.isVisible(u.position)) {
        continue;
      }
      _ensure(2);
      final s = u.spec.scale / AntSpriteCache.renderScale;
      final src = cache.frameRect(u.type, u.renderWalkPhase);
      _add(u.facing, s, u.position.x, u.position.y, src, white);
      _add(u.facing, s, u.position.x, u.position.y, dot,
          u.owner.color.toARGB32());
    }
    if (_n != 0) {
      canvas.drawRawAtlas(
        atlas,
        Float32List.sublistView(_xform, 0, _n * 4),
        Float32List.sublistView(_rects, 0, _n * 4),
        Int32List.sublistView(_colors, 0, _n),
        BlendMode.modulate,
        null,
        _paint,
      );
    }

    // 4) Can barları (yalnız hasarlılar) — bileşen ağacına girmeden,
    // save/transform'suz düz dikdörtgenler.
    for (final u in units) {
      if (u.dead || u.spawnDelay > 0 || u.selected) continue;
      if (u.hp >= u.spec.maxHp) continue;
      if (human != null &&
          u.owner.id != human.id &&
          !game.fog.isVisible(u.position)) {
        continue;
      }
      final ratio = (u.hp / u.spec.maxHp).clamp(0.0, 1.0);
      final w = u.size.x * 0.7;
      final left = u.position.x - w / 2;
      final top = u.position.y - u.size.y / 2 - 3;
      canvas.drawRect(ui.Rect.fromLTWH(left, top, w, 2.5), _barBg);
      _barFg.color = Color.lerp(
          const Color(0xFFD32F2F), const Color(0xFF7CB342), ratio)!;
      canvas.drawRect(
          ui.Rect.fromLTWH(left, top, w * ratio, 2.5), _barFg);
    }
  }

  final Paint _barBg = Paint()..color = const Color(0x99000000);
  final Paint _barFg = Paint();
}
