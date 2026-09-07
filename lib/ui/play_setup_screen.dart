import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../data/maps.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import '../models/game_map.dart';
import 'game_back_button.dart';
import 'mode_toggle.dart';
import 'crossed_swords.dart';

/// Harita modu etiketi: 1v1, 1v1v1, 1v1v1v1 veya (eşlide) 2v2.
String modeLabel(MapDefinition map, bool teamMode) =>
    teamMode ? '2v2' : List.filled(map.playerCount, '1').join('v');

/// Oyna ekranı: harita seçimi (kartlar GERÇEK oyun görüntüleri) + zorluk.
/// [teamMode] (Eşli 2v2): yalnız 4 kişilik haritalar listelenir;
/// yapay zeka müttefikle 2v2 oynanır.
class PlaySetupScreen extends StatefulWidget {
  const PlaySetupScreen(
      {super.key, required this.gameState, this.teamMode = false});

  final GameState gameState;
  final bool teamMode;

  @override
  State<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends State<PlaySetupScreen> {
  /// Mod bu ekranda da değiştirilebilir (menüden gelen değer başlangıçtır).
  late bool _teamMode = widget.teamMode;

  /// SEKME FİLTRESİ: varsayılan HARİTALAR (yalnız haritalar);
  /// TÜMÜ sekmesi Eğitim + Hayatta Kalma kartlarını da gösterir.
  bool _showAll = false;

  /// DÜŞMAN İTTİFAKI (tekli, 3+ oyunculu haritalarda): açıkken tüm düşman
  /// botlar tek takım olur (2v1 / 3v1).
  bool _enemyAlliance = false;

  /// TÜMÜ sekmesinde EĞİTİM kartı listeye girer (yeniden oynanabilir).
  List<MapDefinition> get _maps => _teamMode
      ? mapsForPlayers(4)
      : [if (_showAll) tutorialMap, ...allMaps];
  late MapDefinition _selected = allMaps.first; // varsayılan: gerçek maç

  void _setMode(bool v) {
    AudioController.uiClick();
    setState(() {
      _teamMode = v;
      if (!_maps.contains(_selected)) _selected = _maps.first;
    });
  }

  /// HAYATTA KALMA: Amazon Savunması'nda (tek köprülü varyant) büyüyen
  /// yabani dalgalarına karşı tek başına dayan — süre skorundur.
  void _startHorde() {
    AudioController.uiClick();
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.gameState.startMatch(
      playerCount: 2,
      map: hordeCrossing,
      horde: true,
    );
  }

  void _start() {
    // Kök ekrana dön (phase değişince GameScreen'e geçilecek).
    Navigator.of(context).popUntil((r) => r.isFirst);
    final isTutorial = _selected.id == tutorialMap.id;
    widget.gameState.startMatch(
      playerCount: _selected.playerCount,
      map: _selected,
      teamMode: !isTutorial && _teamMode,
      enemyAlliance: !isTutorial &&
          !_teamMode &&
          _selected.playerCount > 2 &&
          _enemyAlliance,
      tutorial: isTutorial,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title: Row(
          children: [
            Text(loc('Savaş Kur', 'Battle Setup'),
                style: const TextStyle(color: Color(0xFFD8C9A3))),
            const SizedBox(width: 16),
            _tab(loc('HARİTALAR', 'MAPS'), !_showAll,
                () => setState(() => _showAll = false)),
            const SizedBox(width: 6),
            _tab(loc('TÜMÜ', 'ALL'), _showAll,
                () => setState(() => _showAll = true)),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      // Dar telefonlarda dikey sıkışma TAŞMA üretmesin: içerik gerekirse
      // kayar (normalde ortalanmış durur).
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Harita kartları (yatay kaydırmalı).
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // HAYATTA KALMA: özel mod kartı (TÜMÜ sekmesinde).
                if (!_teamMode && _showAll) ...[
                  _HordeCard(onTap: _startHorde),
                  const SizedBox(width: 12),
                ],
                for (final map in _maps) ...[
                  _MapCard(
                    map: map,
                    selected: _selected.id == map.id,
                    teamMode: _teamMode,
                    onTap: () => setState(() => _selected = map),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Alt satır: SOLDA kontroller (sığmazsa SARAR — taşma yok),
          // SAĞDA SAVAŞA BAŞLA.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 22,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _group(loc('BOT ZORLUĞU', 'BOT DIFFICULTY'), Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in Difficulty.values) ...[
                            _diffChip(d),
                            const SizedBox(width: 6),
                          ],
                        ],
                      )),
                      _group(loc('MOD', 'MODE'),
                          ModeToggle(
                              teamMode: _teamMode, onChanged: _setMode)),
                      // DÜŞMAN İTTİFAKI: teklide, 3+ oyunculu haritada.
                      if (!_teamMode &&
                          _selected.playerCount > 2 &&
                          _selected.id != tutorialMap.id)
                        _group(loc('DÜŞMANLAR', 'ENEMIES'),
                            _allianceChip()),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _StartButton(onTap: _start),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  /// Etiketli kontrol grubu (alt satır düzeni).
  Widget _group(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          child,
        ],
      );

  /// Başlık sekmesi (HARİTALAR / TÜMÜ).
  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3E5527) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xFF8BC34A) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF2E8D5) : Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  /// İttifak tiki: oyun stilinde kutucuk + etiket (checkbox widget'ı yok).
  Widget _allianceChip() {
    final on = _enemyAlliance;
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        setState(() => _enemyAlliance = !_enemyAlliance);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF6B4A26) : const Color(0xFF223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? const Color(0xFFE8B33C) : const Color(0xFF4A6130),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: on ? const Color(0xFFE8B33C) : Colors.transparent,
                border: Border.all(
                    color: on
                        ? const Color(0xFFE8B33C)
                        : Colors.white38),
              ),
              child: on
                  ? const Icon(Icons.check,
                      size: 11, color: Color(0xFF1B1208))
                  : null,
            ),
            const SizedBox(width: 7),
            Text(
              loc('İttifak', 'Alliance'),
              style: TextStyle(
                color: on ? const Color(0xFFF2E8D5) : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diffChip(Difficulty d) {
    final gameState = widget.gameState;
    final selected = gameState.difficulty == d;
    final label = switch (d) {
      Difficulty.easy => loc('Kolay', 'Easy'),
      Difficulty.normal => 'Normal',
      Difficulty.hard => loc('Zor', 'Hard'),
      Difficulty.nightmare => loc('Kâbus', 'Nightmare'),
    };
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        setState(() => gameState.difficulty = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5C7A2E) : const Color(0xFF223019),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xFF9CCC65) : const Color(0xFF4A6130),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

/// SAVAŞA BAŞLA: çapraz kılıçlı büyük yeşil buton.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF74A038), Color(0xFF4E6B26)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF9CCC65), width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrossedSwordsIcon(size: 24),
            const SizedBox(width: 10),
            Text(loc('SAVAŞA BAŞLA', 'START BATTLE'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.map,
    required this.selected,
    required this.onTap,
    this.teamMode = false,
  });

  final MapDefinition map;
  final bool selected;
  final VoidCallback onTap;
  final bool teamMode;

  bool get _isTutorial => map.id == 'egitim';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF223019),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // Eğitim kartı ALTIN çerçeveli: öğretici olduğu bir bakışta belli.
            color: _isTutorial
                ? (selected
                    ? const Color(0xFFE8B33C)
                    : const Color(0xFFB27F19))
                : selected
                    ? const Color(0xFF8BC34A)
                    : const Color(0xFF4A6130),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // GERÇEK oyun görüntüsü + sol üstte mod rozeti (1v1, 1v1v1...).
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/map_${map.id}.png',
                    width: 216,
                    height: 121,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      width: 216,
                      height: 121,
                      color: const Color(0xFF2E3A22),
                      alignment: Alignment.center,
                      child: const Icon(Icons.map, color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isTutorial
                            ? const Color(0xFFE8B33C)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _isTutorial ? loc('EĞİTİM', 'TRAINING') : modeLabel(map, teamMode),
                        style: TextStyle(
                            color: _isTutorial
                                ? const Color(0xFF3A2A10)
                                : const Color(0xFFF2E8D5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              map.name,
              style: const TextStyle(
                  color: Color(0xFFF2E8D5), fontWeight: FontWeight.bold),
            ),
            Text(
              _isTutorial
                  ? loc('öğretici · özellikleri öğren',
                      'tutorial · learn the ropes')
                  : teamMode
                      ? loc('2v2 · müttefikli', '2v2 · with an ally')
                      : loc(
                          '${modeLabel(map, false)} · ${map.playerCount} koloni',
                          '${modeLabel(map, false)} · ${map.playerCount} colonies'),
              style: TextStyle(
                  color: _isTutorial
                      ? const Color(0xFFE8B33C)
                      : Colors.white54,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


/// HAYATTA KALMA kartı: kor kırmızısı çerçeve, alev ikonu — harita kartı
/// boyutlarında özel mod kapısı.
class _HordeCard extends StatelessWidget {
  const _HordeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1A12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB0553A), width: 1.4),
        ),
        child: Column(
          children: [
            Container(
              width: 216,
              height: 121,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3A2018), Color(0xFF1E120C)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 40, color: Color(0xFFE8683C)),
                  const SizedBox(height: 6),
                  Text(
                    loc('SONSUZ DALGA', 'ENDLESS WAVES'),
                    style: const TextStyle(
                        color: Color(0xFFE8B33C),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc('Hayatta Kalma', 'Survival'),
              style: const TextStyle(
                  color: Color(0xFFF2E8D5), fontWeight: FontWeight.bold),
            ),
            Text(
              loc('yabani sürülere karşı dayan', 'outlast the feral swarms'),
              style:
                  const TextStyle(color: Color(0xFFE08A5A), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
