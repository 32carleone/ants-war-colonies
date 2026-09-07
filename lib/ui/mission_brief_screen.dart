import 'package:flutter/material.dart';

import '../data/abilities.dart';
import '../data/campaigns.dart';
import '../data/i18n.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import 'ability_art.dart';
import 'campaign_art.dart';
import 'crossed_swords.dart';
import 'game_back_button.dart';
import 'game_hud.dart' show GoldCoin;

/// GÖREV BRİFİNGİ — popup değil, SAĞLI SOLLU tam sayfa:
/// SOLDA temalı sahne + görev adı + ANA AMAÇ + kısa hikâye;
/// SAĞDA ikonlu bilgi grupları (düşman, yetenekler, destek) ve SAVAŞ.
class MissionBriefScreen extends StatelessWidget {
  const MissionBriefScreen({
    super.key,
    required this.campaign,
    required this.missionIndex,
    required this.gameState,
  });

  final CampaignDef campaign;
  final int missionIndex;
  final GameState gameState;

  CampaignMission get mission => campaign.missions[missionIndex];

  @override
  Widget build(BuildContext context) {
    final enemyCount = mission.map!.playerCount - 1;
    final diffLabel = switch (mission.difficulty) {
      Difficulty.easy => loc('Kolay', 'Easy'),
      Difficulty.normal => 'Normal',
      Difficulty.hard => loc('ZOR', 'HARD'),
      Difficulty.nightmare => loc('KÂBUS', 'NIGHTMARE'),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─────────── SOL: temalı sahne + ad + ANA AMAÇ ───────────
          Expanded(
            flex: 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter:
                      CampaignPagePainter(id: campaign.id, nodes: const []),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1.0],
                      colors: [Color(0x00000000), Color(0xCC120E08)],
                    ),
                  ),
                ),
                // GERİ: tüm ekranlarla aynı sol üst nokta.
                const Positioned(
                    left: 0, top: 10, child: GameBackButton()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: campaign.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              loc('GÖREV ${missionIndex + 1}',
                                  'MISSION ${missionIndex + 1}'),
                              style: const TextStyle(
                                  color: Color(0xFF1B1208),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            campaign.name.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mission.title,
                        style: TextStyle(
                          color: const Color(0xFFF2E8D5),
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(color: campaign.accent, blurRadius: 14),
                            const Shadow(
                                color: Colors.black87, blurRadius: 5),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ANA AMAÇ.
                      Row(
                        children: [
                          const CrossedSwordsIcon(
                              size: 20, color: Color(0xFFE8B33C)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enemyCount == 1
                                  ? loc('ANA AMAÇ: Düşman kraliçesini yok et',
                                      'MAIN GOAL: Destroy the enemy queen')
                                  : loc(
                                      'ANA AMAÇ: $enemyCount düşman '
                                      'kraliçesinin TAMAMINI yok et',
                                      'MAIN GOAL: Destroy ALL $enemyCount '
                                      'enemy queens'),
                              style: const TextStyle(
                                  color: Color(0xFFE8B33C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mission.brief,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ─────────── SAĞ: ikonlu bilgi grupları + SAVAŞ ───────────
          Expanded(
            flex: 8,
            child: Container(
              color: const Color(0xFF1B2513),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _groupTitle(loc('DÜŞMAN', 'ENEMY')),
                  _iconRow(
                    Icon(Icons.flag,
                        size: 18, color: campaign.accent),
                    loc('$enemyCount düşman kolonisi · $diffLabel',
                        '$enemyCount enemy colonies · $diffLabel'),
                    sub: enemyCount > 1
                        ? loc('Hepsi TEK takım — birlikte saldırırlar',
                            'All on ONE team — they attack together')
                        : null,
                  ),
                  if (mission.enemyGold != null)
                    _iconRow(
                      const GoldCoin(size: 15),
                      loc('Dolu kasayla başlarlar (${mission.enemyGold} altın)',
                          'They start rich (${mission.enemyGold} gold)'),
                    ),
                  const SizedBox(height: 14),
                  _groupTitle(loc('YETENEKLERİN (sabit)',
                      'YOUR ABILITIES (fixed)')),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        for (final t in mission.loadout)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Column(
                              children: [
                                AbilityArt(type: t, size: 34),
                                const SizedBox(height: 3),
                                SizedBox(
                                  width: 58,
                                  child: Text(
                                    abilitySpecs[t]!.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _groupTitle(loc('DESTEĞİN', 'YOUR SUPPORT')),
                  _iconRow(
                    const GoldCoin(size: 15),
                    loc('${mission.gold} altınla başlarsın',
                        'You start with ${mission.gold} gold'),
                  ),
                  if (mission.ownedBuildings.isNotEmpty)
                    _iconRow(
                      const Icon(Icons.castle,
                          size: 17, color: Color(0xFFD8C9A3)),
                      loc(
                          '${mission.ownedBuildings.length} kule maç başında '
                          'SENİN',
                          '${mission.ownedBuildings.length} tower(s) are '
                          'YOURS at match start'),
                    ),
                  const Spacer(),
                  // SAVAŞ.
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc('Vazgeç', 'Cancel'),
                            style: const TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            AudioController.uiClick();
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                            gameState.startMatch(
                              playerCount: mission.map!.playerCount,
                              map: mission.map,
                              mission: mission.setup(
                                  campaign.id, missionIndex + 1),
                            );
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF74A038),
                                  Color(0xFF4E6B26)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF9CCC65),
                                  width: 1.4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CrossedSwordsIcon(size: 20),
                                const SizedBox(width: 8),
                                Text(loc('SAVAŞ', 'BATTLE'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(String t) => Text(
        t,
        style: const TextStyle(
            color: Color(0xFF8BC34A),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 2),
      );

  Widget _iconRow(Widget icon, String text, {String? sub}) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 22, child: Center(child: icon)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: const TextStyle(
                          color: Color(0xFFF2E8D5), fontSize: 13)),
                  if (sub != null)
                    Text(sub,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
