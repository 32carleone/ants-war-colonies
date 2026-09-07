import 'dart:async';

import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../data/maps.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import '../models/game_map.dart';
import '../net/lan_client.dart';
import '../net/lan_discovery.dart';
import '../net/lan_host.dart';
import '../net/lan_protocol.dart';
import 'game_back_button.dart';
import 'lobby_screen.dart';

/// MULTIPLAYER (yerel ağ) ekranı — sunucusuz, tamamen LAN:
/// SOLDA geniş "Oyun Kur": seçili haritanın büyük önizlemesi + format ve
/// bot zorluğu, lobiyi aç. ORTADA dar "Oyuna Katıl": ağda bulunan oyunlar
/// canlı listelenir, dokununca katılır. EN SAĞDA dikey kaydırmalı
/// harita seçici sütunu.
class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({
    super.key,
    required this.gameState,
    required this.playerName,
  });

  final GameState gameState;
  final String playerName;

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final LanDiscovery _discovery = LanDiscovery();
  bool _busy = false;

  /// Kurulacak oyunun haritası, formatı ve bot zorluğu.
  late MapDefinition _map = allMaps.first;
  LanMode _mode = LanMode.ffa;
  late Difficulty _difficulty = widget.gameState.difficulty;

  List<int> get _loadout =>
      [for (final t in widget.gameState.abilityLoadout) t.index];

  @override
  void initState() {
    super.initState();
    _discovery.start().catchError((_) {});
  }

  @override
  void dispose() {
    _discovery.stop();
    _mapScroll.dispose();
    super.dispose();
  }

  /// Bu harita için oynanabilir formatlar (2p: 1v1; 3p: 1v1v1;
  /// 4p: 1v1v1v1 veya 2v2 eşli).
  List<LanMode> _modesFor(MapDefinition map) =>
      map.playerCount == 4 ? [LanMode.ffa, LanMode.teams2v2] : [LanMode.ffa];

  String _modeLabel(LanMode mode, int playerCount) =>
      mode == LanMode.teams2v2
          ? loc('2v2 EŞLİ', '2v2 TEAMS')
          : List.filled(playerCount, '1').join('v');

  Future<void> _hostGame() async {
    if (_busy) return;
    AudioController.uiClick();
    setState(() => _busy = true);
    // Botları yalnız host simüle eder: seçilen zorluk oyun durumuna işlenir.
    widget.gameState.difficulty = _difficulty;
    final host = LanHostService(
      hostName: widget.playerName,
      mapId: _map.id,
      mapName: _map.name,
      mode: _mode,
      playerCount: _map.playerCount,
      localLoadout: _loadout,
    )..difficultyIndex = _difficulty.index;
    try {
      await host.start();
    } catch (_) {
      await host.dispose();
      if (mounted) {
        setState(() => _busy = false);
        _showError(loc('Lobi açılamadı — ağ bağlantını kontrol et.',
            'Could not open the lobby — check your network.'));
      }
      return;
    }
    if (!mounted) {
      await host.dispose();
      return;
    }
    setState(() => _busy = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LobbyScreen.host(
        gameState: widget.gameState,
        host: host,
        map: _map,
      ),
    ));
  }

  Future<void> _joinGame(LanGameInfo info) async {
    if (_busy) return;
    AudioController.uiClick();
    setState(() => _busy = true);
    final client = LanClientService(
      playerName: widget.playerName,
      loadout: _loadout,
    );
    try {
      await client.connect(info.address, info.port);
    } catch (_) {
      await client.dispose();
      if (mounted) {
        setState(() => _busy = false);
        _showError(loc('Oyuna bağlanılamadı — kurucu kapatmış olabilir.',
            'Could not join — the host may have closed the game.'));
      }
      return;
    }
    if (!mounted) {
      await client.dispose();
      return;
    }
    setState(() => _busy = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LobbyScreen.join(
        gameState: widget.gameState,
        client: client,
      ),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF5C2E2E),
    ));
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
            const Text('Multiplayer',
                style: TextStyle(color: Color(0xFFD8C9A3))),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x33E8B33C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFB27F19)),
              ),
              child: Text(loc('YEREL AĞ', 'LOCAL NETWORK'),
                  style: const TextStyle(
                      color: Color(0xFFE8B33C),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
            ),
            const Spacer(),
            Text(widget.playerName,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.person, size: 16, color: Colors.white38),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _hostPanel()),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _joinPanel()),
            const SizedBox(width: 10),
            SizedBox(width: 152, child: _mapPicker()),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: child,
      );

  Widget _title(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF8BC34A)),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2)),
        ],
      );

  // -------------------------------------------------------------- OYUN KUR

  Widget _hostPanel() {
    final modes = _modesFor(_map);
    if (!modes.contains(_mode)) _mode = modes.first;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.castle, loc('OYUN KUR', 'HOST GAME')),
          const SizedBox(height: 8),
          // Seçili haritanın BÜYÜK önizlemesi (seçim sağdaki sütundan).
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/map_${_map.id}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      color: const Color(0xFF2E3A22),
                      alignment: Alignment.center,
                      child: const Icon(Icons.map, color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_map.playerCount}P',
                        style: const TextStyle(
                            color: Color(0xFFF2E8D5),
                            fontSize: 11,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_map.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFF2E8D5),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(loc('${_map.playerCount} koloni',
                            '${_map.playerCount} colonies'),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              // Format çipleri (haritanın oyuncu sayısına göre).
              for (final m in modes) ...[
                _modeChip(m),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Bot zorluğu: boş slotlara girecek botların seviyesi.
          Row(
            children: [
              const Icon(Icons.smart_toy,
                  size: 14, color: Color(0xFFE8B33C)),
              const SizedBox(width: 6),
              const Text('BOT',
                  style: TextStyle(
                      color: Color(0xFF8BC34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.5)),
              const SizedBox(width: 10),
              // Dar panelde çipler taşmak yerine hafifçe ölçeklenir.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      for (final d in Difficulty.values) ...[
                        _difficultyChip(d),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // LOBİYİ AÇ.
          GestureDetector(
            onTap: _hostGame,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF74A038), Color(0xFF4E6B26)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF9CCC65), width: 1.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _busy
                        ? loc('AÇILIYOR...', 'OPENING...')
                        : loc('LOBİYİ AÇ', 'OPEN LOBBY'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc('Boş kalan slotlara bot girer.',
                'Empty slots are filled with bots.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- SAĞ: HARİTA SEÇİCİ

  final ScrollController _mapScroll = ScrollController();

  /// EN SAĞDA dikey kaydırmalı harita sütunu: tüm haritalar alt alta,
  /// kaydırma çubuğu hep görünür (listenin devamı olduğu belli olsun).
  Widget _mapPicker() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.map, loc('HARİTA', 'MAP')),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _mapScroll,
              thumbVisibility: true,
              child: ListView(
                controller: _mapScroll,
                padding: const EdgeInsets.only(right: 7),
                children: [
                  for (final map in allMaps) ...[
                    SizedBox(height: 92, child: _miniMapCard(map)),
                    const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMapCard(MapDefinition map) {
    final selected = _map.id == map.id;
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        setState(() => _map = map);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2513),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? const Color(0xFF8BC34A) : const Color(0xFF4A6130),
            width: selected ? 2.2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/map_${map.id}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        color: const Color(0xFF2E3A22),
                        alignment: Alignment.center,
                        child:
                            const Icon(Icons.map, color: Colors.white24),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${map.playerCount}P',
                          style: const TextStyle(
                              color: Color(0xFFF2E8D5),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              map.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected
                      ? const Color(0xFFF2E8D5)
                      : Colors.white60,
                  fontSize: 9.5,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChip(Difficulty d) {
    final selected = _difficulty == d;
    final label = switch (d) {
      Difficulty.easy => loc('Kolay', 'Easy'),
      Difficulty.normal => 'Normal',
      Difficulty.hard => loc('Zor', 'Hard'),
      Difficulty.nightmare => loc('Kâbus', 'Nightmare'),
    };
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        setState(() => _difficulty = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFF5C7A2E) : const Color(0xFF223019),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color:
                selected ? const Color(0xFF9CCC65) : const Color(0xFF4A6130),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  Widget _modeChip(LanMode m) {
    final selected = _mode == m;
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        setState(() => _mode = m);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFF5C7A2E) : const Color(0xFF223019),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color:
                selected ? const Color(0xFF9CCC65) : const Color(0xFF4A6130),
          ),
        ),
        child: Text(
          _modeLabel(m, _map.playerCount),
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- OYUNA KATIL

  Widget _joinPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dar panelde başlık satırı taşmak yerine hafifçe ölçeklenir.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _title(
                    Icons.travel_explore, loc('OYUNA KATIL', 'JOIN GAME')),
                const SizedBox(width: 14),
                // Canlı tarama göstergesi.
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: Color(0xFF8BC34A)),
                ),
                const SizedBox(width: 6),
                Text(loc('ağ taranıyor', 'scanning network'),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List<LanGameInfo>>(
              valueListenable: _discovery.games,
              builder: (context, games, _) {
                if (games.isEmpty) return _emptyGames();
                return ListView(
                  children: [
                    for (final g in games) ...[
                      _gameTile(g),
                      const SizedBox(height: 7),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc('Aynı Wi-Fi / yerel ağdaki oyunlar burada görünür.',
                'Games on the same Wi-Fi / local network appear here.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyGames() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_find,
              size: 40, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 10),
          Text(loc('Henüz açık oyun yok', 'No open games yet'),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 3),
          Text(
              loc('Bir arkadaşın lobi açınca burada belirecek.',
                  'When a friend opens a lobby it will show up here.'),
              style: const TextStyle(
                  color: Colors.white30, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _gameTile(LanGameInfo g) {
    final full = g.joined >= g.playerCount;
    return GestureDetector(
      onTap: full ? null : () => unawaited(_joinGame(g)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: full ? Colors.white12 : const Color(0xFF8BC34A)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x338BC34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_kabaddi,
                  size: 19, color: Color(0xFF8BC34A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc("${g.hostName}'in oyunu", "${g.hostName}'s game"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFF2E8D5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '${g.mapName} · ${_modeLabel(g.mode, g.playerCount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${g.joined}/${g.playerCount}',
                  style: TextStyle(
                      color: full
                          ? const Color(0xFFB0553A)
                          : const Color(0xFF8BC34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13),
                ),
                Text(full ? loc('dolu', 'full') : loc('katıl', 'join'),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 9.5)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: full ? Colors.white24 : Colors.white54),
          ],
        ),
      ),
    );
  }
}
