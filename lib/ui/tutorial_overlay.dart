import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../game/ants_wars_game.dart';
import '../game/game_state.dart';
import '../models/building.dart';
import 'tutorial_keys.dart';

/// EĞİTİM koçu: yalnız metin DEĞİL — ekranın ilgili yeri SPOT IŞIĞIYLA
/// odaklanır, üzerinde NE YAPILACAĞI animasyonla gösterilir:
/// - DOKUN: hedefte nabız atan dokunma halkası,
/// - SÜRÜKLE: A'dan B'ye tekrar tekrar kayan parmak noktası + ok.
/// Görev YAPILINCA sonraki adıma kendiliğinden geçilir; overlay dokunuşları
/// asla engellemez (IgnorePointer).
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

/// Bir adımın gösterimi: kısa emir cümlesi + odak delikleri + jest.
class _StepView {
  const _StepView({
    required this.text,
    this.sub,
    this.holes = const [],
    this.tapAt,
    this.dragFrom,
    this.dragTo,
    this.scrim = 0.45,
  });

  final String text;

  /// İkincil, DETAYLI açıklama satırı (küçük yazı).
  final String? sub;
  final List<Rect> holes; // spot ışığı delikleri (ekran uzayı)
  final Offset? tapAt; // DOKUN jesti
  final Offset? dragFrom; // SÜRÜKLE jesti
  final Offset? dragTo;
  final double scrim; // karartma şiddeti (savaş adımında hafif)
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  Timer? _timer;
  double _t = 0;

  /// ADIM TEMPOSU: bir adım tamamlanınca hemen sıradakine ATLANMAZ —
  /// kısa bir "✓ Harika!" onayı gösterilir, öğrenci nefes alır.
  int _shownIndex = -1;
  double _praiseLeft = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      _t += 0.066;
      if (_praiseLeft > 0) _praiseLeft -= 0.066;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Offset _world(Vector2 p) {
    final s = widget.game.camera.localToGlobal(p);
    return Offset(s.x, s.y);
  }

  /// HUD öğesinin GERÇEK ekran dikdörtgeni (GlobalKey ile) —
  /// sabit piksel tahmini yok, hedefler hiçbir ekranda kaymaz.
  Rect? _rectOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Rect _holeAt(Offset c, double r) =>
      Rect.fromCircle(center: c, radius: r);

  /// Adımları sırayla dener: ilk TAMAMLANMAMIŞ adım gösterilir.
  (_StepView, int, int)? _current(Size size) {
    final game = widget.game;
    final human = game.gameState.humanPlayer;
    final nest = human == null ? null : game.nests[human.id];
    if (human == null || nest == null || nest.destroyed) return null;

    final w = size.width;
    final h = size.height;
    final nestS = _world(nest.position);
    final farm = game.buildings
        .firstWhere((b) => b.type == BuildingType.resource);
    final farmS = _world(farm.position);
    final owned =
        game.buildings.where((b) => b.owner?.id == human.id).toList();

    // HUD hedefleri GERÇEK yerlerinden okunur (kayma olmaz);
    // widget henüz kurulmadıysa eski kaba tahminlere düşülür.
    final produceRect = _rectOf(TutorialKeys.produceFire) ??
        Rect.fromCenter(
            center: Offset(30, h / 2 - 78), width: 60, height: 70);
    final produceBtn = produceRect.center;
    final sliderRect = _rectOf(TutorialKeys.deploySlider) ??
        Rect.fromCenter(
            center: Offset(w - 25, h / 2 + 4), width: 50, height: 200);
    final abilityRect = _rectOf(TutorialKeys.abilitySlot0) ??
        Rect.fromCenter(
            center: Offset(w - 146, h - 34), width: 60, height: 60);

    final totalArmy = nest.producedCount;

    final steps = <(bool, _StepView Function())>[
      (
        totalArmy + nest.productionQueue.length >= 3,
        () => _StepView(
              text: loc('3 Ateş Karıncası üret', 'Train 3 Fire Ants'),
              sub: loc(
                  'Sağdaki karınca kartına arka arkaya 3 kez dokun. '
                  'Her asker 10 altına mal olur ve yuva garnizonuna katılır.',
                  'Tap the ant card on the right 3 times in a row. Each '
                  'soldier costs 10 gold and joins the nest garrison.'),
              holes: [produceRect.inflate(6)],
              tapAt: produceBtn,
            )
      ),
      (
        game.deployFraction.value != 0.5,
        () => _StepView(
              text: loc('Çıkarma oranını ayarla', 'Set the deploy ratio'),
              sub: loc(
                  'Soldaki kama, yuvadan TEK SEFERDE çıkacak ordu '
                  'yüzdesidir. Kamayı yukarı sürükleyip oranı büyüt.',
                  'The wedge on the left is the share of your army that '
                  'deploys AT ONCE. Drag it up to raise the ratio.'),
              holes: [sliderRect.inflate(8)],
              dragFrom: sliderRect.bottomCenter - const Offset(0, 26),
              dragTo: sliderRect.topCenter + const Offset(0, 26),
            )
      ),
      (
        owned.isNotEmpty,
        () => _StepView(
              text: loc('Mantar çiftliğini ele geçir',
                  'Capture the mushroom farm'),
              sub: loc(
                  'Yuvana bas, parmağını çiftliğe sürükleyip bırak. '
                  'Çevresinde bekleyen askerlerin doluş halkasını doldurur '
                  '— halka dolunca çiftlik senindir (+2 altın/sn).',
                  'Press your nest, drag your finger to the farm and let '
                  'go. Soldiers waiting around it fill the capture ring — '
                  'when it completes, the farm is yours (+2 gold/s).'),
              holes: [_holeAt(nestS, 66), _holeAt(farmS, 56)],
              dragFrom: nestS,
              dragTo: farmS,
            )
      ),
      (
        owned.any((b) => b.level >= 2),
        () {
          final selected = game.inputController.selectedBuilding == farm &&
              farm.owner?.id == human.id;
          if (!selected) {
            return _StepView(
              text: loc('Çiftliğine dokun', 'Tap your farm'),
              sub: loc(
                  'Kendi binana dokununca çevresinde yönetim '
                  'butonları belirir.',
                  'Tapping your own building reveals management buttons '
                  'around it.'),
              holes: [_holeAt(farmS, 56)],
              tapAt: farmS,
            );
          }
          final up = farmS + const Offset(-47, -47);
          return _StepView(
            text: loc('Altın ok ile yükselt', 'Upgrade with the gold arrow'),
            sub: loc(
                'Yükseltme geliri artırır (50 altın); ⇄ butonu ise '
                'binayı yıkıp başka türe çevirir.',
                'Upgrading boosts income (50 gold); the ⇄ button tears the '
                'building down and converts it to another type.'),
            holes: [_holeAt(up, 40)],
            tapAt: up,
          );
        }
      ),
      (
        game.abilityCooldowns[0] > 0,
        () => _StepView(
              text: loc('Kraliçe gücünü kullan', 'Use a queen power'),
              sub: loc(
                  'Sağ alttaki karta BAS, haritada hedefe SÜRÜKLE ve '
                  'bırak. Her gücün kendi dolum süresi vardır — barı '
                  'dolan kart yeniden hazırdır.',
                  'PRESS the card at bottom right, DRAG onto the map and '
                  'release. Each power has its own cooldown — a refilled '
                  'card is ready again.'),
              holes: [abilityRect.inflate(8)],
              dragFrom: abilityRect.center,
              dragTo: _world(Vector2(640, 380)),
            )
      ),
      (
        false,
        () {
          final enemyNest = widget.game.nests.values
              .where((n) => n.owner.id != human.id && !n.destroyed)
              .firstOrNull;
          final enemyS =
              enemyNest == null ? Offset(w / 2, h / 2) : _world(enemyNest.position);
          // ORDU NEREDE? Garnizon doluysa yuvadan çıkarma öğretilir;
          // askerler zaten SAHADAYSA (önceki adımlarda çıkarıldıysa)
          // sahadaki kümeyi seçip sürüklemesi gösterilir — yuvası boş
          // oyuncuya "yuvadan gönder" demek yanlıştı.
          final field = [
            for (final u in game.units)
              if (!u.dead && u.spawnDelay <= 0 && u.owner.id == human.id)
                u.position
          ];
          if (nest.population == 0 && field.isNotEmpty) {
            final c = Vector2.zero();
            for (final p in field) {
              c.add(p);
            }
            c.scale(1 / field.length);
            final armyS = _world(c);
            return _StepView(
              text: loc('Ordunu düşman yuvasına sür — kraliçeyi bitir!',
                  'March on the enemy nest — finish the queen!'),
              sub: loc(
                  'Askerlerin sahada: birine dokun (küme seçilir) ve '
                  'düşman yuvasının ÜSTÜNE sürükle. Önce garnizon erir, '
                  'sonra kraliçe düşer. Zafer senindir!',
                  'Your soldiers are in the field: tap one (the cluster is '
                  'selected) and drag ONTO the enemy nest. The garrison '
                  'melts first, then the queen falls. Victory is yours!'),
              holes: [_holeAt(armyS, 60), _holeAt(enemyS, 78)],
              dragFrom: armyS,
              dragTo: enemyS,
              scrim: 0.18,
            );
          }
          return _StepView(
            text: loc('Ordunu düşman yuvasına sür — kraliçeyi bitir!',
                'March on the enemy nest — finish the queen!'),
            sub: loc(
                'Yuvana bas ve orduyu düşman yuvasının ÜSTÜNE sürükle. '
                'Önce garnizonu erir, sonra kraliçe düşer. Zafer senindir!',
                'Press your nest and drag the army ONTO the enemy nest. '
                'The garrison melts first, then the queen falls. Victory '
                'is yours!'),
            holes: [_holeAt(enemyS, 78)],
            dragFrom: nestS,
            dragTo: enemyS,
            scrim: 0.18, // savaş adımında ekran karartılmaz
          );
        }
      ),
    ];

    for (var i = 0; i < steps.length; i++) {
      if (!steps[i].$1) return (steps[i].$2(), i, steps.length);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (!game.isLoaded ||
        game.gameState.phase != GamePhase.playing ||
        game.countdown > 0) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.sizeOf(context);
    final cur = _current(size);
    if (cur == null) return const SizedBox.shrink();
    final (step, index, total) = cur;

    // ADIM GEÇİŞİ: yeni adıma geçildiyse önce kısa bir kutlama göster —
    // eğitim nefes nefese ilerlemez, öğrenci ne başardığını görür.
    if (index != _shownIndex) {
      if (index > _shownIndex && _shownIndex >= 0) _praiseLeft = 1.3;
      _shownIndex = index;
    }
    if (_praiseLeft > 0) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xF0223019),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8BC34A), width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF8BC34A), size: 22),
                  const SizedBox(width: 8),
                  Text(loc('Harika! Sıradaki adım…', 'Great! Next step…'),
                      style: const TextStyle(
                          color: Color(0xFFF2E8D5),
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Spot ışığı + jest animasyonu.
            CustomPaint(
              size: size,
              painter: _CoachPainter(step: step, t: _t),
            ),
            // Kısa emir cümlesi (altın rozetli).
            Positioned(
              top: 46,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xF0223019),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFB27F19), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8B33C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}/$total',
                          style: const TextStyle(
                              color: Color(0xFF3A2A10),
                              fontWeight: FontWeight.w900,
                              fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.text,
                              style: const TextStyle(
                                  color: Color(0xFFF2E8D5),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (step.sub != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  step.sub!,
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10.5,
                                      height: 1.3),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spot ışığı (delikli karartma) + jest çizimi.
class _CoachPainter extends CustomPainter {
  _CoachPainter({required this.step, required this.t});

  final _StepView step;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Karartma: odak delikleri hariç.
    final scrim = Path()..addRect(Offset.zero & size);
    for (final hole in step.holes) {
      scrim.addRRect(RRect.fromRectAndRadius(
          hole.inflate(6), const Radius.circular(14)));
    }
    scrim.fillType = PathFillType.evenOdd;
    canvas.drawPath(
        scrim, Paint()..color = Colors.black.withValues(alpha: step.scrim));

    // Odak çerçevesi: nabız atan altın halka.
    final pulse = 1 + math.sin(t * 4) * 0.04;
    for (final hole in step.holes) {
      final r = RRect.fromRectAndRadius(
          hole.inflate(6 * pulse), const Radius.circular(14));
      canvas.drawRRect(
        r,
        Paint()
          ..color = const Color(0xFFE8B33C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    // DOKUN jesti: hedefte iki halkalı dokunma nabzı + parmak noktası.
    final tap = step.tapAt;
    if (tap != null) {
      final ph = (t * 1.1) % 1.0;
      for (final d in [0.0, 0.35]) {
        final q = ((ph - d) % 1.0);
        if (q < 0) continue;
        canvas.drawCircle(
          tap,
          8 + q * 26,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * (1 - q))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - q) + 1,
        );
      }
      _finger(canvas, tap, press: math.sin(ph * math.pi));
    }

    // SÜRÜKLE jesti: rota çizgisi + ok + hattı kayan parmak.
    final a = step.dragFrom;
    final b = step.dragTo;
    if (a != null && b != null) {
      final dir = (b - a);
      final len = dir.distance;
      if (len > 1) {
        final u = dir / len;
        final dash = Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        // Kesikli rota.
        for (var d = 0.0; d < len - 14; d += 22) {
          canvas.drawLine(a + u * d, a + u * (d + 11), dash);
        }
        // Ok başı.
        final n = Offset(-u.dy, u.dx);
        final tip = b - u * 4;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - u.dx * 14 + n.dx * 8,
                tip.dy - u.dy * 14 + n.dy * 8)
            ..lineTo(tip.dx - u.dx * 14 - n.dx * 8,
                tip.dy - u.dy * 14 - n.dy * 8)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        // Kayan parmak: bas → sürükle → bırak döngüsü.
        final ph = (t / 1.6) % 1.0;
        final move = ((ph - 0.15) / 0.6).clamp(0.0, 1.0); // ortada kayar
        final eased = Curves.easeInOut.transform(move);
        final p = a + u * (len * eased);
        final press = ph < 0.8 ? 1.0 : (1 - (ph - 0.8) / 0.2); // sonda bırakır
        _finger(canvas, p, press: press);
      }
    }
  }

  /// Stilize parmak imleci: dolu beyaz nokta + yarı saydam avuç halkası.
  void _finger(Canvas canvas, Offset at, {double press = 1}) {
    canvas.drawCircle(
      at,
      13,
      Paint()..color = Colors.white.withValues(alpha: 0.22 * press),
    );
    canvas.drawCircle(
      at,
      6 + 2 * press,
      Paint()..color = Colors.white.withValues(alpha: 0.55 + 0.4 * press),
    );
    canvas.drawCircle(
      at,
      6 + 2 * press,
      Paint()
        ..color = const Color(0xFF3A2A10).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _CoachPainter old) => true;
}
