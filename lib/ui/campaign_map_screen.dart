import 'package:flutter/material.dart';

import '../data/i18n.dart';

import '../data/campaigns.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import 'campaign_art.dart';
import 'game_back_button.dart';
import 'mission_brief_screen.dart';

/// Bir seferin GÖREV HARİTASI: temalı arka plan üzerinde kıvrılan rota ve
/// 5 görev durağı (kolay → zor). Kilitli / açık / tamamlandı durumları:
/// - kilitli: soluk + kilit,
/// - açık: nabız atan altın halka (sıradaki görev),
/// - tamamlandı: altın bayrak — tekrar oynanabilir.
class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({
    super.key,
    required this.campaign,
    required this.gameState,
  });

  final CampaignDef campaign;
  final GameState gameState;

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  int _done = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await loadCampaignProgress(widget.campaign.id);
    if (mounted) setState(() => _done = p);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Rota durakları: sol alttan sağ üste kıvrılan S yolu.
  List<Offset> _nodes(Size s) => [
        Offset(s.width * 0.14, s.height * 0.74),
        Offset(s.width * 0.34, s.height * 0.50),
        Offset(s.width * 0.52, s.height * 0.72),
        Offset(s.width * 0.70, s.height * 0.44),
        Offset(s.width * 0.86, s.height * 0.62),
      ];

  void _tapMission(int index) {
    final unlocked = index <= _done;
    if (!unlocked) return;
    AudioController.uiClick();
    final mission = widget.campaign.missions[index];
    if (mission.map == null) {
      // Görev henüz tasarlanmadı: temalı bilgi penceresi.
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF223019),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: widget.campaign.accent),
          ),
          title: Text(mission.title,
              style: const TextStyle(color: Color(0xFFF2E8D5), fontSize: 17)),
          content: Text(loc('Bu görev hazırlanıyor — çok yakında!',
            'This mission is in the works — coming soon!'),
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text(loc('Tamam', 'OK'),
                      style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
      return;
    }
    // BRİFİNG: sağlı sollu tam sayfa (popup değil).
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => MissionBriefScreen(
            campaign: widget.campaign,
            missionIndex: index,
            gameState: widget.gameState,
          ),
        ))
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final nodes = _nodes(size);
        return Stack(
          children: [
            // Temalı fon + rota.
            CustomPaint(
              size: size,
              painter: CampaignPagePainter(id: c.id, nodes: nodes),
            ),
            // Görev durakları.
            for (var i = 0; i < c.missions.length; i++)
              _missionNode(nodes[i], i),
            // Üst bar: sefer adı (geri butonu ayrı, standart konumda).
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 62),
                    Text(
                      c.name.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFF2E8D5),
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: c.accent, blurRadius: 10),
                          const Shadow(
                              color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Text(
                        loc('$_done/5 görev', '$_done/5 missions'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // GERİ: tüm ekranlarla aynı sol üst nokta.
            const Positioned(left: 0, top: 10, child: GameBackButton()),
          ],
        );
      }),
    );
  }

  Widget _missionNode(Offset at, int index) {
    final mission = widget.campaign.missions[index];
    final completed = index < _done;
    final unlocked = index <= _done;
    final isNext = index == _done;

    return Positioned(
      left: at.dx - 46,
      top: at.dy - 46,
      width: 92,
      height: 108,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // CustomPaint tek başına vuruş almaz
        onTap: () => _tapMission(index),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final pulse = isNext
                    ? 1 + 0.06 * (0.5 - (0.5 - _anim.value).abs()) * 2
                    : 1.0;
                return Transform.scale(
                  scale: pulse,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _NodePainter(
                        completed: completed,
                        unlocked: unlocked,
                        isNext: isNext,
                        number: index + 1,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              mission.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: unlocked ? const Color(0xFFF2E8D5) : Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  _NodePainter({
    required this.completed,
    required this.unlocked,
    required this.isNext,
    required this.number,
  });

  final bool completed;
  final bool unlocked;
  final bool isNext;
  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    // Platform FONDA çizilir (lav kürsüsü / buz kütlesi / ada) —
    // burada yalnız DURUM katmanı vardır: kilit, halka, numara, bayrak.

    if (!unlocked) {
      // Kilit: karart + asma kilit.
      canvas.drawCircle(Offset.zero, 24,
          Paint()..color = Colors.black.withValues(alpha: 0.55));
      final lock = Paint()..color = Colors.white60;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, 3), width: 14, height: 11),
            const Radius.circular(2)),
        lock,
      );
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -3), width: 10, height: 12),
        3.14,
        3.14,
        false,
        Paint()
          ..color = Colors.white60
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      return;
    }

    if (isNext) {
      canvas.drawCircle(
        Offset.zero,
        29,
        Paint()
          ..color = const Color(0xFFE8B33C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    // Görev numarası.
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: completed ? const Color(0xFFE8B33C) : const Color(0xFFF2E8D5),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    if (completed) {
      // Altın zafer bayrağı (tekrar oynanabilir).
      final base = const Offset(14, -26);
      canvas.drawLine(
        base,
        base.translate(0, 14),
        Paint()
          ..color = const Color(0xFFB27F19)
          ..strokeWidth = 2,
      );
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..lineTo(base.dx + 10, base.dy + 3.5)
          ..lineTo(base.dx, base.dy + 7)
          ..close(),
        Paint()..color = const Color(0xFFE8B33C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NodePainter old) =>
      old.completed != completed ||
      old.unlocked != unlocked ||
      old.isNext != isNext;
}
