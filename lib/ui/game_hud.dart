import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/units.dart';
import '../game/ants_wars_game.dart';
import 'tutorial_keys.dart';
import '../game/audio_controller.dart';
import '../models/nest.dart';
import '../models/player.dart';
import 'ant_portrait.dart';

/// Oyun HUD'u — oyun alanını KAPATMADAN tam kontrol:
///
/// - Üstte ince bilgi barı: altın + yeşil gelir + yuvadaki askerler + üretim.
/// - Solda ikon üretim butonları (basınca tepki verir, "-maliyet" uçar).
/// - Sağda kama biçimli % göstergesi (üst geniş %100 → alt dar %10).

Nest? _humanNest(AntsWarsGame game) {
  if (!game.isLoaded) return null;
  final human = game.gameState.humanPlayer;
  if (human == null || human.eliminated) return null;
  final nest = game.nests[human.id];
  if (nest == null || nest.destroyed) return null;
  return nest;
}

/// Altın para ikonu.
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CoinPainter(), size: Size.square(size));
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: const [Color(0xFFF6D879), Color(0xFFDCA936), Color(0xFFA9761E)],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..color = const Color(0xFF7A5312)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..color = const Color(0xFFB98A24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Üst bilgi barı: altın · +gelir · tip başına yuva mevcudu · üretim durumu.
class TopStatusBar extends StatefulWidget {
  const TopStatusBar({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<TopStatusBar> createState() => _TopStatusBarState();
}

class _TopStatusBarState extends State<TopStatusBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 90), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final nest = _humanNest(game);
    final human = game.gameState.humanPlayer;
    if (nest == null || human == null) return const SizedBox.shrink();

    const label = TextStyle(
        color: Color(0xFFF2E8D5), fontSize: 12, fontWeight: FontWeight.bold);
    final income = game.incomeRate(human);
    final incomeText =
        income % 1 == 0 ? income.toInt().toString() : income.toStringAsFixed(1);
    final powerPct = ((game.powerMultiplier(human) - 1) * 100).round();
    final now = DateTime.now();

    return Positioned(
      top: 4,
      left: 100,
      right: 46,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Güç dağılımı: oyuncu renkleriyle bölünmüş ince bar.
                _PowerDistributionBar(game: game),
                const SizedBox(height: 3),
                _statusRow(game, nest, human, label, incomeText, powerPct),
              ],
            ),
            // Uçan "-maliyet" yazıları (paranın üstünden yükselip söner).
            for (final (amount, t) in widget.game.recentSpends)
              if (now.difference(t).inMilliseconds < 900)
                _floatingSpend(
                    amount, now.difference(t).inMilliseconds / 900),
            // Uçan "+ödül" yazıları (akrep avı vb. — yeşil).
            for (final (amount, t) in widget.game.recentGains)
              if (now.difference(t).inMilliseconds < 1200)
                _floatingGain(
                    amount, now.difference(t).inMilliseconds / 1200),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(AntsWarsGame game, Nest nest, Player human,
      TextStyle label, String incomeText, int powerPct) {
    return Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xCC16200F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Altın + yeşil gelir.
                    const GoldCoin(size: 14),
                    const SizedBox(width: 4),
                    Text('${human.resources}', style: label),
                    const SizedBox(width: 4),
                    Text('(+$incomeText)',
                        style: const TextStyle(
                          color: Color(0xFF8BC34A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        )),
                    _sep(),
                    // Yuvadaki askerler (sadece ana binadakiler).
                    for (final t in UnitType.values) ...[
                      AntPortrait(type: t, size: 22),
                      const SizedBox(width: 3),
                      Text('${nest.garrison[t] ?? 0}',
                          style: label.copyWith(
                            color: (nest.garrison[t] ?? 0) > 0
                                ? const Color(0xFFF2E8D5)
                                : Colors.white30,
                          )),
                      const SizedBox(width: 8),
                    ],
                    _sep(),
                    // Üretim durumu (metin yok — simge yeterli).
                    if (nest.productionQueue.isEmpty)
                      const Icon(Icons.hourglass_empty,
                          size: 14, color: Colors.white24)
                    else ...[
                      AntPortrait(type: nest.productionQueue.first, size: 22),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 42,
                        height: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2.5),
                          child: LinearProgressIndicator(
                            value: nest.productionProgress,
                            backgroundColor: Colors.white12,
                            color: human.color,
                          ),
                        ),
                      ),
                      if (nest.productionQueue.length > 1) ...[
                        const SizedBox(width: 4),
                        Text('+${nest.productionQueue.length - 1}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ],
                    _sep(),
                    // Savaş gücü bonusu (feromon merkezlerinden).
                    Icon(Icons.flash_on,
                        size: 13,
                        color: powerPct > 0
                            ? const Color(0xFFE8B33C)
                            : Colors.white30),
                    Text(
                      '+%$powerPct',
                      style: TextStyle(
                        color: powerPct > 0
                            ? const Color(0xFFE8B33C)
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
  }

  Widget _floatingSpend(int amount, double f) {
    return Positioned(
      left: 8,
      top: 4 - f * 26,
      child: Opacity(
        opacity: (1 - f).clamp(0.0, 1.0),
        child: Text(
          '-$amount',
          style: const TextStyle(
            color: Color(0xFFE8683C),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  Widget _floatingGain(int amount, double f) {
    return Positioned(
      left: 8,
      top: 4 - f * 30,
      child: Opacity(
        opacity: (1 - f).clamp(0.0, 1.0),
        child: Text(
          '+$amount',
          style: const TextStyle(
            color: Color(0xFF8BC34A),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.white12,
      );
}

/// Güç dağılımı barı: tüm oyuncuların anlık savaş gücü (saha + garnizon)
/// tek ince barda, oyuncu renkleriyle oransal bölünmüş — loading bar gibi.
class _PowerDistributionBar extends StatelessWidget {
  const _PowerDistributionBar({required this.game});

  final AntsWarsGame game;

  @override
  Widget build(BuildContext context) {
    final players =
        game.gameState.players.where((p) => !p.eliminated).toList();
    var total = 0.0;
    final strengths = <double>[
      for (final p in players) game.battleStrength(p),
    ];
    for (final s in strengths) {
      total += s;
    }
    if (players.length < 2 || total <= 0) return const SizedBox(height: 12);

    return CustomPaint(
      size: const Size(280, 12),
      painter: _PowerBarPainter(
        [for (final p in players) p.color],
        [for (final s in strengths) s / total],
      ),
    );
  }
}

/// Güç barı ressamı: kenarları HER YERDE hafif girintili çıkıntılı ORGANİK
/// bant (haritadaki kıyı/mantar dili) — düz border radius değil. Renklerin
/// buluştuğu yerlerde iki rengin karışımına akan YUMUŞAK gradyan geçişi.
class _PowerBarPainter extends CustomPainter {
  _PowerBarPainter(this.colors, this.fractions);

  final List<Color> colors;
  final List<double> fractions;

  /// Kapsül çevresi boyunca örneklenmiş, her noktası dışa/içe hafif
  /// dalgalanan kapalı organik yol.
  Path _organicBand(Size size) {
    const amp = 1.4; // girinti-çıkıntı genliği (hafif)
    final r = size.height / 2 - amp;
    final cy = size.height / 2;
    final left = amp + r;
    final right = size.width - amp - r;

    double wob(double phase) =>
        math.sin(phase * 0.9 + 1.7) * amp +
        math.sin(phase * 2.3 + 4.1) * amp * 0.5;

    final path = Path();
    var first = true;
    void add(double x, double y, double nx, double ny, double phase) {
      final j = wob(phase);
      final px = x + nx * j;
      final py = y + ny * j;
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }

    var arc = 0.0; // çevre boyu (dalga fazı)
    // Üst kenar (soldan sağa), normal yukarı.
    for (var x = left; x <= right; x += 7) {
      add(x, cy - r, 0, -1, arc += 7);
    }
    // Sağ uç (yarım tur).
    for (var a = -math.pi / 2; a <= math.pi / 2; a += math.pi / 7) {
      add(right + math.cos(a) * r, cy + math.sin(a) * r, math.cos(a),
          math.sin(a), arc += 4);
    }
    // Alt kenar (sağdan sola), normal aşağı.
    for (var x = right; x >= left; x -= 7) {
      add(x, cy + r, 0, 1, arc += 7);
    }
    // Sol uç.
    for (var a = math.pi / 2; a <= math.pi * 1.5; a += math.pi / 7) {
      add(left + math.cos(a) * r, cy + math.sin(a) * r, math.cos(a),
          math.sin(a), arc += 4);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final band = _organicBand(size);
    final rect = Offset.zero & size;

    // Yumuşak geçişli gradyan: her bölüt kendi renginde düz kalır,
    // sınırın iki yanındaki ince bantta komşu renge akar.
    const blend = 0.035;
    final cols = <Color>[];
    final stops = <double>[];
    var acc = 0.0;
    for (var i = 0; i < colors.length; i++) {
      final start = acc;
      final end = acc + fractions[i];
      acc = end;
      final b = math.min(blend, fractions[i] / 2);
      cols.add(colors[i]);
      stops.add(i == 0 ? 0.0 : (start + b).clamp(0.0, 1.0));
      cols.add(colors[i]);
      stops.add(i == colors.length - 1 ? 1.0 : (end - b).clamp(0.0, 1.0));
    }

    canvas.save();
    canvas.clipPath(band);
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: cols, stops: stops)
          .createShader(rect),
    );
    // Üstte ince cam parlaklığı (bant içinde kalır).
    canvas.drawLine(
      Offset(8, 2.6),
      Offset(size.width - 8, 2.6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Organik çerçeve.
    canvas.drawPath(
      band,
      Paint()
        ..color = Colors.black45
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerBarPainter old) => true;
}

/// SAĞ kenar: sade ikon üretim butonları (basınca küçülüp parlar).
class ProductionColumn extends StatefulWidget {
  const ProductionColumn({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<ProductionColumn> createState() => _ProductionColumnState();
}

class _ProductionColumnState extends State<ProductionColumn> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 300), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final nest = _humanNest(game);
    final human = game.gameState.humanPlayer;
    if (nest == null || human == null) return const SizedBox.shrink();

    return Positioned(
      right: 6,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in UnitType.values) ...[
              KeyedSubtree(
                key: t == UnitType.fire ? TutorialKeys.produceFire : null,
                child: _ProduceButton(game: game, type: t),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProduceButton extends StatefulWidget {
  const _ProduceButton({required this.game, required this.type});

  final AntsWarsGame game;
  final UnitType type;

  @override
  State<_ProduceButton> createState() => _ProduceButtonState();
}

class _ProduceButtonState extends State<_ProduceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final nest = _humanNest(game);
    final human = game.gameState.humanPlayer;
    if (nest == null || human == null) return const SizedBox.shrink();
    final spec = unitSpecs[widget.type]!;
    final atCap = game.armySize(human) + nest.productionQueue.length >=
        game.armyCap(human);
    final canAfford = human.resources >= spec.cost && !atCap;

    return GestureDetector(
      onTapDown: canAfford ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: canAfford
          ? (_) {
              setState(() => _pressed = false);
              // LAN istemcisinde emir host'a gider; yerelde kuyruğa girer.
              if (game.requestProduce(widget.type)) {
                AudioController.produce();
                game.registerSpend(spec.cost);
              }
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.82 : 1,
        duration: const Duration(milliseconds: 80),
        child: Opacity(
          opacity: canAfford ? 1 : 0.4,
          child: Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: _pressed
                  ? human.color.withValues(alpha: 0.45)
                  : const Color(0xCC16200F),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _pressed ? human.color : Colors.white12,
                width: _pressed ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AntPortrait(type: widget.type, size: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoldCoin(size: 8),
                    const SizedBox(width: 2),
                    Text(
                      '${spec.cost}',
                      style: const TextStyle(
                        color: Color(0xFFD8C9A3),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SOL kenar: kama biçimli % göstergesi — üstte geniş (%100), altta dar (%10).
/// Ne kadar genişse o kadar çok asker: bir bakışta okunur.
class DeploySlider extends StatefulWidget {
  const DeploySlider({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<DeploySlider> createState() => _DeploySliderState();
}

class _DeploySliderState extends State<DeploySlider> {
  Timer? _timer;

  static const double _height = 160;
  static const double _width = 34;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 300), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setFromY(double localY) {
    // Üst = %100, alt = %10; %5 adımlara yuvarla.
    final t = (1 - (localY / _height)).clamp(0.0, 1.0);
    final v = 0.1 + t * 0.9;
    setState(() =>
        widget.game.deployFraction.value = ((v * 20).round() / 20).clamp(0.1, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (_humanNest(game) == null) return const SizedBox.shrink();
    final human = game.gameState.humanPlayer!;
    final fraction = game.deployFraction.value;

    return Positioned(
      left: 6,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          key: TutorialKeys.deploySlider,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '%${(fraction * 100).round()}',
              style: const TextStyle(
                color: Color(0xFFF2E8D5),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTapDown: (d) => _setFromY(d.localPosition.dy),
              onVerticalDragUpdate: (d) => _setFromY(d.localPosition.dy),
              child: CustomPaint(
                painter: _WedgePainter(fraction, human.color),
                size: const Size(_width, _height),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  _WedgePainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const topHalf = 13.0; // üst yarı genişlik
    const botHalf = 3.0; // alt yarı genişlik
    final cx = w / 2;

    Path wedge = Path()
      ..moveTo(cx - topHalf, 0)
      ..lineTo(cx + topHalf, 0)
      ..lineTo(cx + botHalf, h)
      ..lineTo(cx - botHalf, h)
      ..close();

    // Zemin.
    canvas.drawPath(wedge, Paint()..color = const Color(0xAA16200F));
    // Dolgu: alttan seçili seviyeye kadar.
    final t = ((fraction - 0.1) / 0.9).clamp(0.0, 1.0);
    final levelY = h * (1 - t);
    canvas.save();
    canvas.clipPath(wedge);
    canvas.drawRect(
      Rect.fromLTWH(0, levelY, w, h - levelY),
      Paint()..color = color.withValues(alpha: 0.85),
    );
    canvas.restore();
    // Çerçeve + seviye çizgisi.
    canvas.drawPath(
      wedge,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final halfAtLevel = botHalf + (topHalf - botHalf) * t;
    canvas.drawLine(
      Offset(cx - halfAtLevel - 3, levelY),
      Offset(cx + halfAtLevel + 3, levelY),
      Paint()
        ..color = const Color(0xFFF2E8D5)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WedgePainter old) =>
      old.fraction != fraction || old.color != color;
}


/// Sol altta UFAK ordu sayacı: mevcut ordu / tavan ve maç boyunca
/// üretilen toplam asker.
class ArmyCounter extends StatefulWidget {
  const ArmyCounter({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<ArmyCounter> createState() => _ArmyCounterState();
}

class _ArmyCounterState extends State<ArmyCounter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 400), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final nest = _humanNest(game);
    final human = game.gameState.humanPlayer;
    if (nest == null || human == null) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xCC16200F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups,
                    size: 13, color: Color(0xFFD8C9A3)),
                const SizedBox(width: 5),
                Text(
                  '${game.armySize(human)}/${game.armyCap(human)}',
                  style: const TextStyle(
                    color: Color(0xFFF2E8D5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.egg_alt, size: 12, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  '${nest.producedCount}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// MAÇ SAATİ: sağ üst köşede geçen süre (mm:ss) — üretim sütununun üstü.
/// "Savaş ne kadardır sürüyor?" bir bakışta görünür.
class MatchClock extends StatefulWidget {
  const MatchClock({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<MatchClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.game.matchDuration.floor();
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return Positioned(
      right: 8,
      top: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB3182312),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined,
                size: 13, color: Color(0xFFD8C9A3)),
            const SizedBox(width: 5),
            Text(
              '$mm:$ss',
              style: const TextStyle(
                color: Color(0xFFF2E8D5),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
