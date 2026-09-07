import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../game/ants_wars_game.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import '../net/net_client_bridge.dart';
import '../net/net_host_bridge.dart';
import 'ability_hud.dart';
import 'debug_overlay.dart';
import 'game_hud.dart';
import 'match_intro_overlay.dart';
import 'tutorial_overlay.dart';

/// Maç ekranı: Flame sahnesini ve üzerindeki Flutter overlay'lerini barındırır.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final AntsWarsGame _game;
  bool _paused = false;

  /// KARŞILAŞMA EKRANI açık mı? Açıkken oyun duraklıdır; tekli/kurucu
  /// BAŞLA'ya basınca (LAN katılanında ilk anlık görüntü gelince) kapanır.
  bool _intro = false;

  NetHostBridge? _hostBridge;
  NetClientBridge? _clientBridge;

  @override
  void initState() {
    super.initState();
    final lan = widget.gameState.lan;
    // LAN maçı: paylaşılan tohum → yuva dağılımı iki cihazda da aynı.
    _game = AntsWarsGame(
      gameState: widget.gameState,
      rng: lan != null ? math.Random(lan.seed) : null,
    );
    if (lan != null) {
      if (lan.isHost) {
        _hostBridge = NetHostBridge(game: _game, host: lan.host!);
        _game.netHost = _hostBridge;
      } else {
        _clientBridge = NetClientBridge(game: _game, client: lan.client!);
        _game.netClient = _clientBridge;
        // Host maç ortasında giderse: bilgilendir ve menüye dön.
        lan.client!.onClosed = (reason) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${loc('Bağlantı sona erdi', 'Connection ended')}: $reason'),
            backgroundColor: const Color(0xFF5C2E2E),
          ));
          widget.gameState.backToMenu();
        };
      }
    }
    AudioController.playGameAmbience();
    // Karşılaşma ekranı: savaş, oyuncu BAŞLA diyene dek bekler.
    if (_game.wantsIntro) {
      _intro = true;
      _game.paused = true;
    }
  }

  void _dismissIntro() {
    if (!mounted || !_intro) return;
    setState(() => _intro = false);
    _game.paused = _paused; // (duraklat butonuna basılmadıysa akar)
  }

  @override
  void dispose() {
    _hostBridge?.dispose();
    _clientBridge?.dispose();
    super.dispose();
  }

  /// Sadece duraklat/devam — menü açılmaz (ufak ikon yeterli).
  void _togglePause() {
    AudioController.uiClick();
    setState(() {
      _paused = !_paused;
      _game.paused = _paused;
    });
  }

  void _openGameMenu() {
    AudioController.uiClick();
    _game.paused = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF223019),
        title: Text(loc('Duraklatıldı', 'Paused'),
            style: const TextStyle(color: Color(0xFFF2E8D5))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5C7A2E)),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _paused = false;
                  _game.paused = false;
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(loc('Devam Et', 'Resume')),
            ),
            // LAN maçında yeniden başlatma yok (host-otoriter tek oturum).
            if (widget.gameState.lan == null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.gameState.restartLastMatch();
                },
                icon: const Icon(Icons.replay),
                label: Text(loc('Yeniden Başlat', 'Restart')),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.gameState.backToMenu();
              },
              icon: const Icon(Icons.home),
              label: Text(loc('Ana Menü', 'Main Menu')),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDebug() {
    if (_game.overlays.isActive(DebugOverlay.overlayKey)) {
      _game.overlays.remove(DebugOverlay.overlayKey);
      _game.debugTerrain = false;
    } else {
      _game.overlays.add(DebugOverlay.overlayKey);
      _game.debugTerrain = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        // Sabit 16:9 oyun alanı kenarlarda boşluk bırakırsa (letterbox),
        // düz siyah şerit yerine girintili çıkıntılı kayalık kenar çiz.
        final scale = (constraints.maxWidth / 1280)
            .clamp(0.0, constraints.maxHeight / 720);
        final sideBar =
            ((constraints.maxWidth - 1280 * scale) / 2).clamp(0.0, 999.0);
        return Stack(
        children: [
          GameWidget(
            game: _game,
            // Yükleme sırasında SİYAH ekran yerine temaya uygun bekleme.
            loadingBuilder: (context) => Container(
              color: const Color(0xFF16200F),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Color(0xFF8BC34A)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      loc('Savaş alanı hazırlanıyor...',
                          'Preparing the battlefield...'),
                      style: const TextStyle(
                          color: Color(0xFFD8C9A3), fontSize: 13)),
                ],
              ),
            ),
            overlayBuilderMap: {
              DebugOverlay.overlayKey: (context, AntsWarsGame game) =>
                  DebugOverlay(game: game),
            },
          ),
          // Geçici geliştirme butonu: debug overlay aç/kapa
          // (sağ üst köşe MAÇ SAATİNİN — buton onun soluna alındı).
          Positioned(
            right: 78,
            top: 2,
            child: IconButton(
              onPressed: _toggleDebug,
              icon: const Icon(Icons.bug_report, color: Colors.white38),
            ),
          ),
          // Letterbox kenarları: kayalık dağ silüeti (düz kesik yok).
          if (sideBar > 2) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: sideBar + 16,
              child: const CustomPaint(
                  painter: _CliffEdgePainter(leftSide: true)),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sideBar + 16,
              child: const CustomPaint(
                  painter: _CliffEdgePainter(leftSide: false)),
            ),
          ],
          // Kenar HUD'u: üst bilgi barı + sol üretim + sağ oran kaydırıcısı.
          TopStatusBar(game: _game),
          MatchClock(game: _game),
          ProductionColumn(game: _game),
          DeploySlider(game: _game),
          ArmyCounter(game: _game),
          // Yetenek slotları.
          AbilityHud(game: _game),
          // Duraklat (sadece durdurur) + menü (ayrı buton).
          Positioned(
            left: 8,
            top: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePause,
                  icon: Icon(
                    _paused
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    color: Colors.white54,
                    size: 28,
                  ),
                ),
                IconButton(
                  onPressed: _openGameMenu,
                  icon: const Icon(Icons.menu,
                      color: Colors.white54, size: 26),
                ),
              ],
            ),
          ),
          // Duraklatıldı göstergesi (ufak).
          if (_paused)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause,
                          size: 14, color: Color(0xFFF2E8D5)),
                      const SizedBox(width: 5),
                      Text(loc('Duraklatıldı', 'Paused'),
                          style: const TextStyle(
                              color: Color(0xFFF2E8D5), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          // EĞİTİM maçında adım paneli.
          if (widget.gameState.tutorial) TutorialOverlay(game: _game),
          // HAYATTA KALMA: dalga sayacı.
          if (widget.gameState.horde) _HordeHud(game: _game),
          // Maç başı geri sayımı (3→1 → SAVAŞ!).
          _CountdownOverlay(game: _game),
          // KARŞILAŞMA EKRANI en üstte: kapanana dek savaş bekler.
          if (_intro)
            MatchIntroOverlay(game: _game, onStart: _dismissIntro),
        ],
        );
      }),
    );
  }
}

/// Maç başı geri sayımı: 3'ten geriye büyük rakamlar, ardından "SAVAŞ!".
class _CountdownOverlay extends StatefulWidget {
  const _CountdownOverlay({required this.game});

  final AntsWarsGame game;

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay> {
  Timer? _timer;
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (widget.game.countdown <= 0 && _endedAt == null) {
        _endedAt = DateTime.now();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cd = widget.game.countdown;
    final showFight = _endedAt != null &&
        DateTime.now().difference(_endedAt!).inMilliseconds < 900;
    if (cd <= 0 && !showFight) return const SizedBox.shrink();

    final String text;
    if (cd > 0) {
      text = '${cd.ceil()}';
    } else {
      text = loc('SAVAŞ!', 'FIGHT!');
    }
    // Her saniyenin başında büyüyüp oturan nabız.
    final frac = cd > 0 ? cd - cd.floorToDouble() : 0.5;
    final scale = cd > 0 ? 1.0 + frac * 0.5 : 1.15;

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.transparent, // harita geri sayımda da görünür
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: Text(
              text,
              style: TextStyle(
                fontSize: cd > 0 ? 110 : 72,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: cd > 0
                    ? const Color(0xFFF2E8D5)
                    : const Color(0xFF8BC34A),
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Letterbox kenarı: koyu kayalık kütle, oyuna bakan yüzü GİRİNTİLİ ÇIKINTILI
/// pürüzlü uçurum silüeti — arada karlı çıkıntılar ve otlar.
class _CliffEdgePainter extends CustomPainter {
  const _CliffEdgePainter({required this.leftSide});

  final bool leftSide;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final w = size.width;
    final inner = leftSide ? w : 0.0; // oyuna bakan kenarın x'i
    final dirIn = leftSide ? -1.0 : 1.0; // panelin içine doğru yön

    double edgeX(double y, double phase) =>
        inner +
        dirIn *
            (6 +
                (math.sin(y * 0.045 + phase) * 7 +
                        math.sin(y * 0.11 + phase * 2.3) * 4)
                    .abs());

    // Ana kütle: dış kenardan pürüzlü iç silüete.
    final body = Path()..moveTo(leftSide ? 0 : w, 0);
    for (var y = 0.0; y <= size.height; y += 14) {
      body.lineTo(edgeX(y, 1.7), y);
    }
    body
      ..lineTo(leftSide ? 0 : w, size.height)
      ..close();
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF141C0E));
    canvas.drawPath(body, Paint()..color = const Color(0xFF20281A));

    // İç silüet kaya yüzü (daha açık şerit) + kenar çizgisi.
    final face = Path()..moveTo(edgeX(0, 1.7), 0);
    for (var y = 0.0; y <= size.height; y += 14) {
      face.lineTo(edgeX(y, 1.7), y);
    }
    for (var y = size.height; y >= 0; y -= 14) {
      face.lineTo(edgeX(y, 4.1) + dirIn * 6, y);
    }
    face.close();
    canvas.drawPath(face, Paint()..color = const Color(0xFF39412C));

    // Çıkıntılarda kar lekeleri ve ot püskülleri.
    final grass = Paint()
      ..color = const Color(0xFF7A9A4C)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var y = 20.0; y < size.height; y += 52) {
      final ex = edgeX(y, 1.7);
      if ((y ~/ 52).isEven) {
        canvas.drawCircle(Offset(ex + dirIn * 3, y),
            2.6, Paint()..color = const Color(0xFFE9EADF));
      } else {
        canvas.drawLine(Offset(ex, y), Offset(ex - dirIn * 4, y - 6), grass);
        canvas.drawLine(
            Offset(ex, y + 2), Offset(ex - dirIn * 6, y - 2), grass);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CliffEdgePainter old) =>
      old.leftSide != leftSide;
}


/// HAYATTA KALMA sayacı: mevcut dalga + sonrakine kalan süre + geçen süre.
class _HordeHud extends StatefulWidget {
  const _HordeHud({required this.game});

  final AntsWarsGame game;

  @override
  State<_HordeHud> createState() => _HordeHudState();
}

class _HordeHudState extends State<_HordeHud> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    if (!g.isLoaded) return const SizedBox.shrink();
    final mins = g.matchDuration ~/ 60;
    final secs = (g.matchDuration % 60).floor();
    final next = g.hordeNextIn.clamp(0, 99).ceil();
    var feralAlive = 0;
    for (final u in g.units) {
      if (!u.dead && u.owner.eliminated) feralAlive++;
    }
    return Positioned(
      top: 44,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC2A1A12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x99B0553A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 15, color: Color(0xFFE8683C)),
              const SizedBox(width: 6),
              Text(
                '${loc("DALGA", "WAVE")} ${g.hordeWave}'
                '${g.hordeLastCount > 0 ? "  ·  ${loc("kadro", "size")} ${g.hordeLastCount}" : ""}'
                '  ·  ${loc("sahada", "alive")} $feralAlive'
                '  ·  ${loc("sonraki", "next")} ${next}s'
                '  ·  $mins:${secs.toString().padLeft(2, "0")}',
                style: const TextStyle(
                    color: Color(0xFFF2E8D5),
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
