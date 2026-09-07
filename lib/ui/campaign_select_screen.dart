import 'package:flutter/material.dart';

import '../data/i18n.dart';

import '../data/campaigns.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import 'campaign_art.dart';
import 'campaign_map_screen.dart';
import 'game_back_button.dart';

/// SEFER seçim ekranı: üç sefer YAN YANA, her biri kendi temalı
/// sahnesiyle (ateş/buz/adalar) ve ilerleme rozetiyle.
class CampaignSelectScreen extends StatefulWidget {
  const CampaignSelectScreen({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<CampaignSelectScreen> createState() => _CampaignSelectScreenState();
}

class _CampaignSelectScreenState extends State<CampaignSelectScreen> {
  final Map<CampaignId, int> _progress = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    for (final c in campaigns) {
      final p = await loadCampaignProgress(c.id);
      if (mounted) setState(() => _progress[c.id] = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title: Text(loc('Sefer', 'Campaign'),
            style: const TextStyle(color: Color(0xFFD8C9A3))),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // TEK KESİNTİSİZ PANORAMA: volkan → buzul → takımadalar.
          CustomPaint(painter: CampaignTriptychPainter()),
          // Alt bilgi bandı (tüm genişlikte tek yumuşak karartı).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.62, 1.0],
                colors: [Color(0x00000000), Color(0xB3120E08)],
              ),
            ),
          ),
          // GRID: üstte solda ATEŞ, sağda BUZ; altta boydan boya ADA.
          Column(
            children: [
              Expanded(
                flex: 60,
                child: Row(
                  children: [
                    Expanded(child: _campaignZone(campaigns[0])),
                    Expanded(child: _campaignZone(campaigns[1])),
                  ],
                ),
              ),
              Expanded(
                flex: 40,
                child: _campaignZone(campaigns[2]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Panoramanın bir bölgesi: dokunulur alan + altta ad/slogan/ilerleme.
  Widget _campaignZone(CampaignDef c) {
    final done = _progress[c.id] ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        AudioController.uiClick();
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CampaignMapScreen(
            campaign: c,
            gameState: widget.gameState,
          ),
        ));
        _reload();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            c.name.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFFF2E8D5),
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 2.5,
              shadows: [
                Shadow(color: c.accent, blurRadius: 12),
                const Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)]),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < c.missions.length; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        i < done ? const Color(0xFFE8B33C) : Colors.white24,
                    border: Border.all(
                        color: i < done
                            ? const Color(0xFFB27F19)
                            : Colors.white38),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

}
