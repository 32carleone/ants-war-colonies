import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama ayarları — kalıcı (shared_preferences).
/// Ses/müzik değerleri PART-12'de ses sistemine bağlanacak.
class AppSettings extends ChangeNotifier {
  bool soundOn = true;
  double soundVolume = 0.8;
  bool musicOn = true;
  double musicVolume = 0.6;
  bool vibration = true;

  /// Düşük cihazlar için (sis blur'u vb. kapatılır — PART-12).
  bool highQuality = true;

  /// 'tr' | 'en' (ayarlardan anında değişir).
  String language = 'tr';

  /// YARALI GERİ ÇEKİLME: canı %20 altına düşen askerin otomatik yuvaya
  /// kaçması (yuvaya giren asker tam canla garnizona katılır).
  bool autoRetreat = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      soundOn = p.getBool('set_soundOn') ?? soundOn;
      soundVolume = p.getDouble('set_soundVolume') ?? soundVolume;
      musicOn = p.getBool('set_musicOn') ?? musicOn;
      musicVolume = p.getDouble('set_musicVolume') ?? musicVolume;
      vibration = p.getBool('set_vibration') ?? vibration;
      highQuality = p.getBool('set_highQuality') ?? highQuality;
      language = p.getString('set_language') ?? language;
      autoRetreat = p.getBool('set_autoRetreat') ?? autoRetreat;
      notifyListeners();
    } catch (_) {
      // Test ortamında eklenti yoksa varsayılanlarla devam.
    }
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('set_soundOn', soundOn);
      await p.setDouble('set_soundVolume', soundVolume);
      await p.setBool('set_musicOn', musicOn);
      await p.setDouble('set_musicVolume', musicVolume);
      await p.setBool('set_vibration', vibration);
      await p.setBool('set_highQuality', highQuality);
      await p.setString('set_language', language);
      await p.setBool('set_autoRetreat', autoRetreat);
    } catch (_) {}
  }
}

/// Uygulama geneli tek ayar nesnesi (main'de yüklenir).
final AppSettings appSettings = AppSettings();
