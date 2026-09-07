/// ÇOK DİL ALTYAPISI — hafif ve anahtar dosyasız:
///
/// - UI metinleri kullanım yerinde ÇİFT dille yazılır: `loc('Savaş', 'Battle')`
///   (çeviri her zaman metnin yanında durur, ayrı anahtar dosyası yok).
/// - Veri sınıfları (yetenek/harita/sefer...) TR+EN alan çifti tutar,
///   `name`/`description` getter'ları aktif dile göre döner — çağıran
///   kodun haberi olmaz.
/// - Dil `appSettings.language` ('tr' | 'en') ile seçilir; değişince
///   appSettings notifyListeners → kök AnimatedBuilder tüm ekranı tazeler.
library;

import 'settings.dart';

/// Aktif dil İngilizce mi?
bool get isEnglish => appSettings.language == 'en';

/// Aktif dile göre metin seçer: Türkçe varsayılandır.
String loc(String tr, String en) => isEnglish ? en : tr;
