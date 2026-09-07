import 'package:flutter/widgets.dart';

/// Eğitim koçunun HUD öğelerini GERÇEK konumlarından bulması için
/// paylaşılan anahtarlar — sabit piksel tahmini yapılmaz, ekran/çentik
/// farklarında hedefler asla kaymaz.
class TutorialKeys {
  TutorialKeys._();

  /// Soldaki İLK üretim butonu (Ateş Karıncası).
  static final produceFire = GlobalKey(debugLabel: 'tut-produce');

  /// Sağdaki çıkarma oranı kaması.
  static final deploySlider = GlobalKey(debugLabel: 'tut-slider');

  /// Sağ alttaki İLK yetenek kartı.
  static final abilitySlot0 = GlobalKey(debugLabel: 'tut-ability');
}
