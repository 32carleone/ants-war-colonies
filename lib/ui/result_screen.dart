import 'package:flutter/material.dart';

import '../data/campaigns.dart';
import '../data/i18n.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import 'campaign_map_screen.dart';

/// Zafer / Yenilgi ekranı: sonuç + HERKESİN karnesi (çizelgeli).
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  GameState get gameState => widget.gameState;

  @override
  void initState() {
    super.initState();
    // MAÇ GERÇEKTEN BİTER: oyun sesleri (ambiyans + oyun müziği + davullar)
    // durup menü müziğine dönülür; üstüne sonuç borusu çalar.
    AudioController.playMenuMusic();
    if (gameState.phase == GamePhase.victory) {
      AudioController.victory();
    } else {
      AudioController.defeat();
    }
  }

  /// Sefer maçından sonra ana menüye DEĞİL, sefer haritasına dönülür.
  void _backToCampaign(CampaignDef campaign) {
    AudioController.uiClick();
    gameState.backToMenu();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          CampaignMapScreen(campaign: campaign, gameState: gameState),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final won = gameState.phase == GamePhase.victory;
    final mission = gameState.mission;
    final campaign = mission == null
        ? null
        : campaigns.firstWhere((c) => c.id.name == mission.campaignKey);
    final stats = gameState.lastStats;
    final minutes = stats == null ? 0 : stats.duration ~/ 60;
    final seconds = stats == null ? 0 : (stats.duration % 60).round();

    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.heart_broken,
                size: 44,
                color:
                    won ? const Color(0xFFE8B33C) : const Color(0xFFB0553A),
              ),
              const SizedBox(height: 4),
              Text(
                won
                    ? loc('ZAFER!', 'VICTORY!')
                    : loc('KOLONİ DÜŞTÜ', 'COLONY FALLEN'),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color:
                      won ? const Color(0xFF8BC34A) : const Color(0xFFE08A5A),
                ),
              ),
              Text(
                gameState.lastHorde
                    ? loc(
                        '${gameState.lastHordeWave}. dalgada düştün — '
                            'sürü sonunda yuvayı aştı.',
                        'You fell on wave ${gameState.lastHordeWave} — '
                            'the swarm finally broke through.')
                    : won
                        ? loc('Rakip kraliçelerin hepsi düştü.',
                            'Every rival queen has fallen.')
                        : loc('Kraliçen öldü — yuva sessizliğe gömüldü.',
                            'Your queen is dead — the nest fell silent.'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (stats != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${loc('Süre', 'Time')} '
                    '$minutes:${seconds.toString().padLeft(2, "0")}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 14),
              _scoreboard(),
              _strengthChart(),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: campaign != null
                    // SEFER maçı: menüye değil SEFERE dönülür.
                    ? [
                        if (won) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7A2E)),
                            onPressed: () => _backToCampaign(campaign),
                            icon: const Icon(Icons.map),
                            label: Text(loc('Sefere Dön', 'Back to Campaign')),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: gameState.restartLastMatch,
                            icon: const Icon(Icons.replay),
                            label: Text(loc('Tekrar Oyna', 'Play Again')),
                          ),
                        ] else ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7A2E)),
                            onPressed: gameState.restartLastMatch,
                            icon: const Icon(Icons.replay),
                            label: Text(loc('Tekrar Dene', 'Try Again')),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _backToCampaign(campaign),
                            icon: const Icon(Icons.map),
                            label: Text(loc('Sefere Dön', 'Back to Campaign')),
                          ),
                        ],
                      ]
                    : [
                        // LAN maçında tek yol menüye dönmek (lobi kapanır).
                        if (gameState.lan == null) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7A2E)),
                            onPressed: gameState.restartLastMatch,
                            icon: const Icon(Icons.replay),
                            label: Text(loc('Tekrar Oyna', 'Play Again')),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: gameState.backToMenu,
                            icon: const Icon(Icons.home),
                            label: Text(loc('Ana Menü', 'Main Menu')),
                          ),
                        ] else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7A2E)),
                            onPressed: gameState.backToMenu,
                            icon: const Icon(Icons.home),
                            label: Text(loc('Ana Menü', 'Main Menu')),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// MAÇ KARNESİ: her oyuncu için üretilen asker, kazanılan altın,
  /// harita hakimiyeti ve kayıplar — renkli karşılaştırma barlarıyla.
  Widget _scoreboard() {
    final rows = gameState.lastPlayerStats;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final total = gameState.totalBuildings;

    int maxOf(int Function(PlayerMatchStats) f) =>
        rows.fold(1, (m, r) => f(r) > m ? f(r) : m);
    final maxProduced = maxOf((r) => r.produced);
    final maxGold = maxOf((r) => r.goldEarned);
    final maxLost = maxOf((r) => r.unitsLost);

    Widget header(String t) => Expanded(
          child: Text(t,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2)),
        );

    return Container(
      width: 620,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF223019),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A6130)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 96),
              header(loc('ÜRETİLEN', 'PRODUCED')),
              header(loc('ALTIN', 'GOLD')),
              header(loc('HAKİMİYET', 'CONTROL')),
              header(loc('KAYIP', 'LOSSES')),
            ],
          ),
          const SizedBox(height: 6),
          for (final r in rows) ...[
            _playerRow(r, total, maxProduced, maxGold, maxLost),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _playerRow(PlayerMatchStats r, int totalBuildings, int maxProduced,
      int maxGold, int maxLost) {
    // LAN maçında gerçek oyuncu adları gösterilir.
    final label = r.name ??
        (r.isHuman
            ? loc('SEN', 'YOU')
            : r.ally
                ? loc('MÜTTEFİK', 'ALLY')
                : loc('RAKİP', 'RIVAL'));
    return Opacity(
      opacity: r.eliminated && !r.isHuman ? 0.55 : 1,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration:
                      BoxDecoration(color: r.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: r.isHuman
                          ? const Color(0xFFF2E8D5)
                          : Colors.white70,
                      fontWeight:
                          r.isHuman ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (r.eliminated)
                  const Icon(Icons.close,
                      size: 12, color: Color(0xFFB0553A)),
              ],
            ),
          ),
          _barCell(r.produced, maxProduced, r.color),
          _barCell(r.goldEarned, maxGold, r.color),
          _barCell(r.buildings, totalBuildings == 0 ? 1 : totalBuildings,
              r.color,
              label: totalBuildings == 0
                  ? '0'
                  : '%${(r.buildings * 100 / totalBuildings).round()}'),
          _barCell(r.unitsLost, maxLost, r.color),
        ],
      ),
    );
  }

  /// GÜÇ GRAFİĞİ: maç boyunca oyuncu başına savaş gücü çizgileri —
  /// kim ne zaman öne geçti, tek bakışta.
  Widget _strengthChart() {
    final hist = gameState.lastStrengthHistory;
    final rows = gameState.lastPlayerStats;
    if (hist == null || hist.length < 3 || rows == null) {
      return const SizedBox.shrink();
    }
    final colors = [for (final r in rows) r.color];
    return Container(
      width: 620,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF223019),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A6130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc('GÜÇ GRAFİĞİ — maç boyunca ordu gücü',
                'POWER GRAPH — army strength over the match'),
            style: const TextStyle(
                color: Color(0xFF8BC34A),
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _StrengthChartPainter(hist, colors),
            ),
          ),
        ],
      ),
    );
  }

  /// Değer + oyuncu renginde oransal yatay bar (çizelge hücresi).
  Widget _barCell(int value, int max, Color color, {String? label}) {
    final frac = (max <= 0 ? 0.0 : value / max).clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label ?? '$value',
                style: const TextStyle(
                    color: Color(0xFFF2E8D5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: Colors.white10,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Güç geçmişi çizgi grafiği: oyuncu renklerinde yumuşak çizgiler,
/// silik yatay kılavuzlar. Kenarlar sade — oyun dili, web grafiği değil.
class _StrengthChartPainter extends CustomPainter {
  _StrengthChartPainter(this.history, this.colors);

  final List<List<int>> history;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    var maxV = 1;
    for (final row in history) {
      for (final v in row) {
        if (v > maxV) maxV = v;
      }
    }

    // Silik kılavuz çizgileri.
    final guide = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    final n = history.length;
    for (var p = 0; p < colors.length; p++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final v = p < history[i].length ? history[i][p] : 0;
        final x = size.width * i / (n - 1);
        final y = size.height * (1 - v / maxV);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // Alan dolgusu (çok silik) + çizgi.
      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
          fill, Paint()..color = colors[p].withValues(alpha: 0.07));
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[p].withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrengthChartPainter old) =>
      old.history != history;
}
