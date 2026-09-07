import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/settings.dart';

/// Tüm ses/müzik tek yerden: ayarlara bağlı, test ortamında sessiz,
/// savaş sesleri sınırlandırılmış (ses bombardımanı yok).
class AudioController {
  AudioController._();

  /// İlk erişimde hesaplanır — testler init() çağırmasa da sessiz kalır.
  /// WEB'de Platform.environment YOKTUR (UnsupportedError): catch'e düşüp
  /// "test ortamı" sanılırsa web sürümü TAMAMEN SESSİZ kalır — kIsWeb önce.
  static final bool _testEnv = () {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return true;
    }
  }();
  static bool _initialized = false;

  static AudioPlayer? _music;
  static AudioPlayer? _ambient;
  static AudioPlayer? _rain;

  /// Sık çalınan efektler için havuzlar: her seferinde yeni oynatıcı
  /// açmak yerine önceden yüklenmiş oynatıcılar tekrar kullanılır
  /// (Android'de zamanla kasmanın büyük sebebi).
  ///
  /// DİKKAT — ÇÖKME KORUMASI: FlameAudio.createPool KULLANMA! O havuz
  /// Android'de MediaPlayer(ReleaseMode.stop) kurar; her efekt bitiminde
  /// native stop()→prepareAsync() çalışır ve MediaPlayer kötü anda
  /// yakalanınca IllegalStateException UYGULAMAYI ÖLDÜRÜR (telefon logcat
  /// kayıtlarındaki maç ortası çökmeler). [_SfxPool] lowLatency =
  /// SoundPool arka ucunu kullanır: prepareAsync yolu hiç yoktur.
  static final Map<String, _SfxPool> _pools = {};

  static final Map<String, DateTime> _lastPlayed = {};
  static final math.Random _rng = math.Random();

  static Future<void> init() async {
    if (_testEnv || _initialized) return;
    _initialized = true;
    // ÇÖKME DEĞİL ama SUSMA KORUMASI: audioplayers'ın varsayılan ses
    // bağlamı her yeni oynatıcı için Android SES ODAĞI (focus GAIN)
    // ister — bir SES EFEKTİ çalınca sistem odağı ona verir ve MÜZİK
    // OYNATICISINI DURAKLATIR ("efekt girince müzik kesiliyor" hatası).
    // mixWithOthers: odak hiç istenmez; oyun tüm seslerini KENDİ İÇİNDE
    // karıştırır, müzik + ambiyans + efektler birlikte çalar.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (_) {}
    try {
      await FlameAudio.audioCache.loadAll([
        'ui_click.ogg',
        'ui_open.ogg',
        'produce.ogg',
        'deploy.wav',
        'bite1.wav',
        'bite2.wav',
        'bite3.wav',
        'acid_spit.wav',
        'tower_shot.wav',
        'capture.ogg',
        'ability_cast.wav',
        'lightning.wav',
        'move_order.wav',
        'battle_drums.wav',
        'count_tick.wav',
        'count_go.wav',
      ]);
    } catch (_) {}
    // Sık efektler havuzdan çalınır.
    // WEB'de AudioPool KURULMAZ: createPool web'de hiç tamamlanmayabiliyor
    // (audioplayers web sınırı) — init asılı kalır, oyun hiç açılmazdı.
    // Havuz yoksa sfx() zaten FlameAudio.play ile çalar.
    if (kIsWeb) {
      appSettings.addListener(_applySettings);
      return;
    }
    for (final f in const [
      'bite1.wav',
      'bite2.wav',
      'bite3.wav',
      'acid_spit.wav',
      'tower_shot.wav',
      'deploy.wav',
      'produce.ogg',
      'ui_click.ogg',
      'capture.ogg',
      'move_order.wav',
      'count_tick.wav',
      'count_go.wav',
      'ability_cast.wav',
      'lightning.wav',
      'ui_open.ogg',
    ]) {
      try {
        _pools[f] = await _SfxPool.create(f);
      } catch (_) {}
    }
    // Ayar değişince loop sesleri güncelle.
    appSettings.addListener(_applySettings);
  }

  static void _applySettings() {
    final mv = appSettings.musicOn ? appSettings.musicVolume : 0.0;
    _music?.setVolume(mv * 0.55);
    _ambient?.setVolume(mv * 0.8);
    _gameMusic?.setVolume(mv * 0.35);
    _rain?.setVolume(appSettings.soundOn ? appSettings.soundVolume * 0.6 : 0);
  }

  // ------------------------------------------------------------ efektler

  /// [throttleMs]: aynı ses için iki çalma arasındaki en kısa süre.
  static void sfx(String file, {double volume = 1, int throttleMs = 90}) {
    if (_testEnv || !appSettings.soundOn) return;
    final now = DateTime.now();
    final last = _lastPlayed[file];
    if (last != null &&
        now.difference(last).inMilliseconds < throttleMs) {
      return;
    }
    _lastPlayed[file] = now;
    final v = volume * appSettings.soundVolume;
    final pool = _pools[file];
    if (pool != null) {
      pool.play(v);
    } else {
      FlameAudio.play(file, volume: v).ignore();
    }
  }

  static void uiClick() => sfx('ui_click.ogg', volume: 0.7);
  static void uiOpen() => sfx('ui_open.ogg', volume: 0.7);
  static void produce() => sfx('produce.ogg', volume: 0.8);
  static void deploy() => sfx('deploy.wav', volume: 0.7, throttleMs: 300);

  /// Orduya hareket emri: kısa yaprak hışırtısı + çıtırtı (canlılık).
  static void moveOrder() =>
      sfx('move_order.wav', volume: 0.65, throttleMs: 250);

  /// Maç başı geri sayımı: her rakamda tahta tik, "SAVAŞ!"ta boru+davul.
  static void countTick() =>
      sfx('count_tick.wav', volume: 0.8, throttleMs: 300);
  static void countGo() => sfx('count_go.wav', volume: 0.95, throttleMs: 0);
  static void capture() => sfx('capture.ogg', volume: 0.9, throttleMs: 400);
  static void towerShot() =>
      sfx('tower_shot.wav', volume: 0.4, throttleMs: 250);
  static void acidSpit() =>
      sfx('acid_spit.wav', volume: 0.35, throttleMs: 220);
  static void abilityCast() => sfx('ability_cast.wav', volume: 0.8);
  static void lightning() => sfx('lightning.wav', volume: 0.9);

  /// Yakın dövüş ısırıkları: 3 varyanttan rastgele, sıkı sınırlı.
  static void bite() {
    sfx('bite${1 + _rng.nextInt(3)}.wav', volume: 0.45, throttleMs: 160);
  }

  static void victory() => sfx('victory.ogg', volume: 1, throttleMs: 0);
  static void defeat() => sfx('defeat.ogg', volume: 1, throttleMs: 0);

  // ------------------------------------------------------------ döngüler

  /// DÖNGÜ BEKÇİSİ: Android'de uzun ses döngüleri bazen sessizce durur
  /// (odak kaybı / MediaPlayer loop hatası). Çare iki katlı:
  /// 1) tamamlanma olayı gelirse baştan çal (loop kırıldıysa yakalar),
  /// 2) tekrar çalınmak istendiğinde oynatıcı durmuşsa resume et.
  /// [stillCurrent]: DURDURULMUŞ döngüyü hortlatma koruması — bazı
  /// platformlarda stop() da "tamamlandı" olayı tetikler; bekçi bunu
  /// "döngü kırıldı" sanıp SESİ GERİ BAŞLATIYORDU (menüde oyun
  /// ambiyansı/davulun devam etmesinin sebebi). Yalnız hâlâ aktif
  /// döngüyse baştan çalınır.
  static void _guardLoop(AudioPlayer p, bool Function() stillCurrent) {
    p.onPlayerComplete.listen((_) {
      if (!stillCurrent()) return;
      try {
        p.seek(Duration.zero);
        p.resume();
      } catch (_) {}
    }, onError: (_) {});
  }

  static Future<void> _resumeIfStalled(AudioPlayer? p) async {
    if (p == null) return;
    try {
      if (p.state != PlayerState.playing) await p.resume();
    } catch (_) {}
  }

  // ------------------------------------------------------ müzik rotasyonu

  /// Menü müzik havuzu: her parça bitince FARKLI rastgele biri çalar.
  static const List<String> _menuTracks = [
    'music_forest.ogg', // HorrorPen — House In a Forest
    'music_woodland.mp3', // Matthew Pablo — Woodland Fantasy
    'music_festival.mp3', // Matthew Pablo — Enchanted Festival
    'music_town.mp3', // cynicmusic — Town Theme
  ];

  /// Oyun içi hafif müzik havuzu (ambiyansın ALTINDA, kısık çalar).
  static const List<String> _gameTracks = [
    'music_crystal.mp3', // cynicmusic — Crystal Cave
    'music_battle_a.mp3', // cynicmusic — Battle Theme A
  ];

  static String? _curMenuTrack;
  static String? _curGameTrack;
  static AudioPlayer? _gameMusic;

  /// SAHNE SAYACI — "menüde oyun sesi" yarış koruması: döngü/parça
  /// başlatmaları asenkrondur (await loopLongAudio/play); kullanıcı tam o
  /// sırada maçtan çıkarsa başlatma ÇIKIŞTAN SONRA tamamlanır ve ses
  /// menüde sahipsiz çalmaya devam ederdi. Her sahne geçişi sayacı
  /// artırır; await sonrası sayaç değiştiyse yeni oynatıcı anında kapatılır.
  static int _sceneSeq = 0;
  static bool _inGame = false;

  /// await sonrası sahne değiştiyse oynatıcıyı sessizce kapatır.
  static bool _staleAfter(int seq, AudioPlayer? p) {
    if (seq == _sceneSeq) return false;
    try {
      p?.stop();
      p?.dispose();
    } catch (_) {}
    return true;
  }

  static String _pickNext(List<String> pool, String? last) {
    final options =
        pool.length > 1 ? pool.where((t) => t != last).toList() : pool;
    return options[_rng.nextInt(options.length)];
  }

  /// Parçayı BİR KEZ çalar; bitince [onDone] tetiklenir (rotasyon).
  ///
  /// DİKKAT — ÇÖKME KORUMASI: ReleaseMode.stop KULLANMA! Android'de
  /// audioplayers, parça bitince native tarafta stop() → prepareAsync()
  /// çağırır ve MediaPlayer yanlış durumdaysa IllegalStateException ile
  /// UYGULAMAYI ÖLDÜRÜR (Dart try/catch yakalayamaz; logcat'te
  /// WrappedPlayer.onCompletion izi). ReleaseMode.release bitişte
  /// oynatıcıyı serbest bırakır — prepareAsync yoluna hiç girilmez.
  /// Rotasyon zaten her parça için YENİ AudioPlayer açar.
  static Future<AudioPlayer?> _playTrack(
      String file, double volume, void Function() onDone) async {
    try {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.release);
      await p.play(AssetSource('audio/$file'), volume: volume);
      p.onPlayerComplete.listen((_) => onDone(), onError: (_) {});
      return p;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _startMenuTrack() async {
    if (!appSettings.musicOn || _inGame) return;
    final seq = _sceneSeq;
    _curMenuTrack = _pickNext(_menuTracks, _curMenuTrack);
    final p = await _playTrack(
      _curMenuTrack!,
      appSettings.musicVolume * 0.55,
      () {
        // Sıradaki rastgele parça (aynısı üst üste gelmez). SAHNEYE göre
        // sürer: seq karşılaştırması menüde kalınan uzun oturumda
        // rotasyonu yanlışlıkla ÖLDÜRÜYORDU (her playMenuMusic çağrısı
        // sayacı artırır; parça bitince "bayat" sanılıp susuluyordu).
        _music?.dispose();
        _music = null;
        if (!_inGame) _startMenuTrack();
      },
    );
    if (_staleAfter(seq, p)) return;
    _music = p;
  }

  static Future<void> _startGameTrack() async {
    if (!appSettings.musicOn || !_inGame) return;
    final seq = _sceneSeq;
    _curGameTrack = _pickNext(_gameTracks, _curGameTrack);
    final p = await _playTrack(
      _curGameTrack!,
      appSettings.musicVolume * 0.35,
      () {
        _gameMusic?.dispose();
        _gameMusic = null;
        if (_inGame) _startGameTrack();
      },
    );
    if (_staleAfter(seq, p)) return;
    _gameMusic = p;
  }

  /// Ana menü: rastgele menü müziği çalar, oyun ambiyansı durur.
  static Future<void> playMenuMusic() async {
    if (_testEnv) return;
    _inGame = false;
    _sceneSeq++;
    await _stopAmbient();
    if (_music != null) {
      await _resumeIfStalled(_music); // aynı parça sürsün, baştan sarmasın
      return;
    }
    await _startMenuTrack();
  }

  /// Oyun içi: orman ambiyansı + kısık rastgele müzik (menü müziği durur).
  static Future<void> playGameAmbience() async {
    if (_testEnv) return;
    _inGame = true;
    final seq = ++_sceneSeq;
    await _stopMusic();
    if (_ambient != null) {
      await _resumeIfStalled(_ambient);
      await _resumeIfStalled(_gameMusic);
      return;
    }
    if (!appSettings.musicOn) return;
    try {
      final a = await FlameAudio.loopLongAudio('ambient_forest.mp3',
          volume: appSettings.musicVolume * 0.8);
      if (!_staleAfter(seq, a)) {
        _ambient = a;
        _guardLoop(a, () => _ambient == a);
      }
    } catch (_) {}
    await _startGameTrack();
  }

  // ------------------------------------------------------- savaş gerilimi

  static AudioPlayer? _battle;
  static double _battleVol = 0;
  static double _battleSetThrottle = 0;

  /// Çatışma gerilim müziği: oyun döngüsü her karede çağırır.
  /// [active] iken davul döngüsü yumuşakça girer, savaş bitince söner.
  static void updateBattle(double dt, bool active) {
    if (_testEnv || !_inGame) return;
    final target = active && appSettings.musicOn
        ? appSettings.musicVolume * 0.5
        : 0.0;
    final speed = active ? 0.5 : 0.35; // giriş biraz daha hızlı
    if (_battleVol < target) {
      _battleVol = math.min(target, _battleVol + speed * dt);
    } else {
      _battleVol = math.max(target, _battleVol - speed * dt);
    }

    if (_battleVol > 0.005 && _battle == null) {
      _startBattleLoop();
    } else if (_battleVol <= 0.005 && !active && _battle != null) {
      final p = _battle;
      _battle = null;
      try {
        p?.stop();
        p?.dispose();
      } catch (_) {}
    }
    // setVolume çağrısı seyrekleştirilir (kanal trafiği).
    _battleSetThrottle -= dt;
    if (_battle != null && _battleSetThrottle <= 0) {
      _battleSetThrottle = 0.15;
      try {
        _battle!.setVolume(_battleVol.clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  static bool _battleStarting = false;

  static Future<void> _startBattleLoop() async {
    if (_battleStarting || _battle != null) return;
    _battleStarting = true;
    final seq = _sceneSeq;
    try {
      final p = await FlameAudio.loopLongAudio('battle_drums.wav',
          volume: _battleVol);
      if (!_staleAfter(seq, p)) {
        _battle = p;
        _guardLoop(p, () => _battle == p);
      }
    } catch (_) {}
    _battleStarting = false;
  }

  static Future<void> _stopBattle() async {
    final p = _battle;
    _battle = null;
    _battleVol = 0;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }

  /// Yağmur yeteneği: süresince yağmur döngüsü.
  static Future<void> startRain() async {
    if (_testEnv || _rain != null || !appSettings.soundOn) return;
    final seq = _sceneSeq;
    try {
      final p = await FlameAudio.loopLongAudio('rain_loop.ogg',
          volume: appSettings.soundVolume * 0.6);
      if (!_staleAfter(seq, p)) _rain = p;
    } catch (_) {}
  }

  static Future<void> stopRain() async {
    final p = _rain;
    _rain = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }

  static Future<void> _stopMusic() async {
    final p = _music;
    _music = null;
    _curMenuTrack = null; // bir sonraki menüde yine rastgele başlasın
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }

  static Future<void> _stopAmbient() async {
    final p = _ambient;
    _ambient = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
    await stopRain();
    await _stopBattle();
    final gm = _gameMusic;
    _gameMusic = null;
    _curGameTrack = null;
    try {
      await gm?.stop();
      await gm?.dispose();
    } catch (_) {}
  }
}

/// KISA EFEKT HAVUZU — SoundPool tabanlı (PlayerMode.lowLatency).
/// Her dosya için birkaç hazır oynatıcı sırayla kullanılır; çalmak
/// stop+resume ile baştan başlatılır (SoundPool'da seek yoktur).
/// MediaPlayer'ın prepareAsync çökme yoluna hiç girilmez.
class _SfxPool {
  _SfxPool(this._players);

  final List<AudioPlayer> _players;
  int _next = 0;

  static Future<_SfxPool> create(String file, {int size = 2}) async {
    final players = <AudioPlayer>[];
    for (var i = 0; i < size; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource('audio/$file'));
      players.add(p);
    }
    return _SfxPool(players);
  }

  void play(double volume) {
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    () async {
      try {
        await p.stop();
        await p.setVolume(volume.clamp(0.0, 1.0));
        await p.resume();
      } catch (_) {}
    }();
  }
}
