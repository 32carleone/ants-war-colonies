import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/i18n.dart';
import '../data/maps.dart';
import '../game/audio_controller.dart';
import '../game/game_state.dart';
import '../models/game_map.dart';
import '../net/lan_client.dart';
import '../net/lan_host.dart';
import '../net/lan_protocol.dart';
import 'crossed_swords.dart';
import 'game_back_button.dart';

/// LAN LOBİSİ: solda harita kartı + başlat butonu, ortada oyuncu kadrosu
/// (2v2'de takım sütunları + VS), sağda dikey sohbet paneli. Kurucu maçı
/// başlatır, katılanlar bekler; boş slotlar botla dolar. 2v2'de 4 slotun
/// DÖRDÜ DE gerçek oyuncu olabilir.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen.host({
    super.key,
    required this.gameState,
    required LanHostService this.host,
    required this.map,
  }) : client = null;

  const LobbyScreen.join({
    super.key,
    required this.gameState,
    required LanClientService this.client,
  })  : host = null,
        map = null;

  final GameState gameState;
  final LanHostService? host;
  final LanClientService? client;
  final MapDefinition? map;

  bool get isHost => host != null;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _starting = false;

  ValueNotifier<List<LanPlayerMeta>> get _lobby =>
      widget.isHost ? widget.host!.lobby : widget.client!.lobby;

  LanMode get _mode =>
      widget.isHost ? widget.host!.mode : widget.client!.mode;

  int get _playerCount => widget.isHost
      ? widget.map!.playerCount
      : _lobby.value.isEmpty
          ? 4
          : _lobby.value.length;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      widget.host!.onStarted = (seed, players) =>
          _enterMatch(seed, widget.host!.hostSlot, widget.map!, players);
    } else {
      final client = widget.client!;
      client.onStart = (seed, slot, players) {
        final map = _mapById(client.mapId);
        if (map == null) return;
        _enterMatch(seed, slot, map, players);
      };
      client.onClosed = (reason) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reason),
          backgroundColor: const Color(0xFF5C2E2E),
        ));
        Navigator.of(context).pop();
        client.dispose();
      };
    }
  }

  MapDefinition? _mapById(String id) {
    for (final m in allMaps) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Maça geçiş: kök ekrana dönülür, GameState LAN maçını kurar
  /// (phase değişince kök GameScreen'i gösterir).
  void _enterMatch(
      int seed, int slot, MapDefinition map, List<LanPlayerMeta> players) {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.gameState.startLanMatch(
      map: map,
      seed: seed,
      localSlot: slot,
      mode: _mode,
      lanPlayers: players,
      host: widget.host,
      client: widget.client,
    );
  }

  /// Geri çıkış: kurucuysa lobi kapanır (herkes düşer), katılansa ayrılır.
  void _leave() {
    AudioController.uiClick();
    if (widget.isHost) {
      widget.host!.dispose();
    } else {
      widget.client!.onClosed = null; // kendi isteğiyle çıkıyor
      widget.client!.dispose();
    }
    Navigator.of(context).pop();
  }

  void _start() {
    if (_starting) return;
    AudioController.uiClick();
    setState(() => _starting = true);
    widget.host!.startGame();
  }

  bool _isMe(LanPlayerMeta p) {
    if (p.isBot) return false;
    if (widget.isHost) return p.slot == widget.host!.hostSlot;
    final my = widget.client!.mySlot;
    if (my != null) return p.slot == my;
    return p.name == widget.client!.playerName; // eski host yedeği
  }

  /// Boş (bot) slota dokununca oraya geç — takım/yer seçimi buradan.
  void _moveTo(int slot) {
    AudioController.uiClick();
    if (widget.isHost) {
      widget.host!.moveSelf(slot);
      setState(() {}); // host tarafında lobby notifier'ı da tetiklenir
    } else {
      widget.client!.sendSlot(slot);
    }
  }

  int get _difficultyIndex => widget.isHost
      ? widget.host!.difficultyIndex
      : widget.client!.difficultyIndex;

  int get _hostSlot => widget.isHost
      ? widget.host!.hostSlot
      : widget.client!.hostSlotIndex;

  String get _difficultyLabel => switch (_difficultyIndex) {
        0 => loc('Kolay', 'Easy'),
        2 => loc('Zor', 'Hard'),
        3 => loc('Kâbus', 'Nightmare'),
        _ => 'Normal',
      };

  /// HAZIR MESAJLAR: klavye yok — tek dokunuş sinyaller.
  List<String> get _chatPresets => [
        loc('Selam! 👋', 'Hi! 👋'),
        loc('Hazırım ✔', 'Ready ✔'),
        loc('Takım değişelim', 'Swap teams'),
        loc('Başlat!', 'Start!'),
        loc('Bekle ✋', 'Wait ✋'),
        loc('İyi oyunlar 🐜', 'Good luck 🐜'),
      ];

  ValueNotifier<List<(int, int)>> get _chats =>
      widget.isHost ? widget.host!.chats : widget.client!.chats;

  void _sendChat(int i) {
    AudioController.uiClick();
    if (widget.isHost) {
      widget.host!.sendChat(i);
    } else {
      widget.client!.sendChat(i);
    }
  }

  String _nameOf(int slot, List<LanPlayerMeta> players) {
    for (final p in players) {
      if (p.slot == slot && !p.isBot) return p.name;
    }
    return '?';
  }

  String _modeLabel(int count) => _mode == LanMode.teams2v2
      ? loc('2v2 EŞLİ', '2v2 TEAMS')
      : List.filled(count, '1').join('v');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF16200F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16200F),
          leading: GameBackButton(onTap: _leave),
          leadingWidth: 52,
          title: Text(
            widget.isHost
                ? loc('Lobi — Oyun Kuruldu', 'Lobby — Game Hosted')
                : loc('Lobi', 'Lobby'),
            style: const TextStyle(color: Color(0xFFD8C9A3)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ValueListenableBuilder<List<LanPlayerMeta>>(
            valueListenable: _lobby,
            builder: (context, players, _) {
              final rows = players.isEmpty
                  ? [
                      for (var i = 0; i < _playerCount; i++)
                        LanPlayerMeta(
                            slot: i, name: 'Bot', team: i, isBot: true)
                    ]
                  : players;
              final map = widget.isHost
                  ? widget.map
                  : _mapById(widget.client!.mapId);
              // Sol: harita + BAŞLAT · orta: oyuncular · sağ: sohbet.
              return LayoutBuilder(builder: (context, cons) {
                final wide = cons.maxWidth >= 1000;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: wide ? 280 : 236,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _mapPanel(map, rows)),
                          const SizedBox(height: 8),
                          _bottomBar(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _playersPanel(rows)),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: wide ? 224 : 186,
                        child: _chatPanel(rows)),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: child,
      );

  // ------------------------------------------------------------ SOL: harita

  Widget _mapPanel(MapDefinition? map, List<LanPlayerMeta> rows) {
    final humans = rows.where((p) => !p.isBot).length;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Görsel ESNEKTİR: panel daralınca küçülür (dar ekranlarda
          // alttan taşma olmaz), bilgi satırları sabit kalır.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (map != null)
                    Image.asset(
                      'assets/images/map_${map.id}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        color: const Color(0xFF2E3A22),
                        alignment: Alignment.center,
                        child:
                            const Icon(Icons.map, color: Colors.white24),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF2E3A22),
                      alignment: Alignment.center,
                      child: const Icon(Icons.map, color: Colors.white24),
                    ),
                  // Format rozeti.
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
                        _modeLabel(rows.length),
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
          const SizedBox(height: 10),
          Text(
            map?.name ?? '...',
            style: const TextStyle(
                color: Color(0xFFF2E8D5),
                fontWeight: FontWeight.w900,
                fontSize: 16),
          ),
          Text(
            loc('${rows.length} koloni · yerel ağ',
                '${rows.length} colonies · local network'),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          // Bot zorluğu (kurucu Oyun Kur'da seçer).
          Row(
            children: [
              const Icon(Icons.smart_toy,
                  size: 14, color: Color(0xFFE8B33C)),
              const SizedBox(width: 6),
              Text(
                loc('Bot zorluğu: $_difficultyLabel',
                    'Bot difficulty: $_difficultyLabel'),
                style: const TextStyle(
                    color: Color(0xFFD8C9A3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İnsan doluluk göstergesi.
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF8BC34A)),
              const SizedBox(width: 6),
              Text(
                '$humans/${rows.length}',
                style: const TextStyle(
                    color: Color(0xFF8BC34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  loc('insan oyuncu — kalan slotlara bot girer',
                      'human players — bots fill the rest'),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Doluluk barı (insan / bot oransal).
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(
                    flex: humans,
                    child: Container(color: const Color(0xFF8BC34A)),
                  ),
                  Expanded(
                    flex: (rows.length - humans).clamp(0, 4),
                    child: Container(color: Colors.white12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ SAĞ: oyuncular

  Widget _playersPanel(List<LanPlayerMeta> rows) {
    if (_mode == LanMode.teams2v2) {
      final t0 = rows.where((p) => p.team == 0).toList();
      final t1 = rows.where((p) => p.team == 1).toList();
      return _panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _teamColumn(loc('TAKIM 1', 'TEAM 1'), t0)),
            // Ortada VS arması.
            SizedBox(
              width: 46,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CrossedSwordsIcon(
                      size: 26, color: Color(0xFFE8B33C)),
                  const SizedBox(height: 4),
                  Text(
                    'VS',
                    style: TextStyle(
                      color: const Color(0xFFE8B33C)
                          .withValues(alpha: 0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _teamColumn(loc('TAKIM 2', 'TEAM 2'), t1)),
          ],
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              loc('OYUNCULAR — herkes tek başına',
                  'PLAYERS — everyone for themselves'),
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5),
            ),
          ),
          // Dar ekranlarda TAŞMAZ: liste gerekirse kayar.
          Expanded(
            child: ListView(
              children: [
                for (final p in rows) ...[
                  _playerCard(p),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamColumn(String title, List<LanPlayerMeta> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            title,
            style: const TextStyle(
                color: Color(0xFF8BC34A),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5),
          ),
        ),
        // Dar ekranlarda TAŞMAZ: takım listesi gerekirse kayar.
        Expanded(
          child: ListView(
            children: [
              for (final p in members) ...[
                _playerCard(p),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Oyuncu kartı: renk şeridi + renkli rozet + ad; SEN/KURUCU çipleri.
  /// BOT (boş) slotlara DOKUNARAK oraya geçilir — 2v2'de takımını,
  /// teklide rengini/yerini böyle seçersin.
  Widget _playerCard(LanPlayerMeta p) {
    final color = p.slot < kTeamColors.length
        ? kTeamColors[p.slot]
        : Colors.white54;
    final me = _isMe(p);
    final card = Container(
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.isBot
            ? const Color(0xFF1D2715)
            : Color.alphaBlend(
                color.withValues(alpha: 0.10), const Color(0xFF2C3A20)),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: me ? const Color(0xFF9CCC65) : Colors.white12,
          width: me ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          // Sol renk şeridi.
          Container(
              width: 5, color: color.withValues(alpha: p.isBot ? 0.35 : 1)),
          const SizedBox(width: 10),
          // Renkli rozet.
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: p.isBot ? 0.18 : 0.85),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.black26, width: 1),
            ),
            child: Icon(
              p.isBot ? Icons.smart_toy : Icons.person,
              size: 16,
              color: p.isBot ? Colors.white38 : Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.isBot ? 'Bot' : p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.isBot
                        ? Colors.white38
                        : const Color(0xFFF2E8D5),
                    fontWeight:
                        p.isBot ? FontWeight.normal : FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.isBot
                      ? loc('boş slot — dokun, buraya geç',
                          'empty slot — tap to move here')
                      : p.slot == _hostSlot
                          ? loc('kurucu', 'host')
                          : loc('hazır', 'ready'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.isBot ? Colors.white30 : Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (me)
            Container(
              margin: const EdgeInsets.only(right: 9),
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x338BC34A),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(loc('SEN', 'YOU'),
                  style: const TextStyle(
                      color: Color(0xFF8BC34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 10)),
            )
          else if (!p.isBot && p.slot == _hostSlot)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.workspace_premium,
                  size: 17, color: Color(0xFFE8B33C)),
            )
          else if (p.isBot)
            // Boş slota geçilebilir işareti.
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.swap_horiz,
                  size: 17, color: Colors.white30),
            ),
        ],
      ),
    );
    // Bot (boş) slot: dokununca oraya geçilir.
    if (p.isBot) {
      return GestureDetector(onTap: () => _moveTo(p.slot), child: card);
    }
    return card;
  }

  // -------------------------------------------------------- SOHBET

  /// SOHBET: oyuncuların YANINDA dikey panel — üstte mesaj akışı (en
  /// yenisi altta, gerekirse kayar), altta hazır mesaj çipleri sarmalı
  /// dizilir. Klavye yok, tek dokunuş sinyaller.
  Widget _chatPanel(List<LanPlayerMeta> players) {
    return _panel(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, size: 13, color: Color(0xFF8BC34A)),
              const SizedBox(width: 6),
              Text(
                loc('SOHBET', 'CHAT'),
                style: const TextStyle(
                    color: Color(0xFF8BC34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Mesaj akışı: en yeni altta; taşarsa yukarı doğru kayar.
          Expanded(
            child: ValueListenableBuilder<List<(int, int)>>(
              valueListenable: _chats,
              builder: (context, msgs, _) {
                if (msgs.isEmpty) {
                  return Text(
                    loc('Alttaki hazır mesajlarla rakiplerine ve takımına '
                            'sinyal ver.',
                        'Signal your team and rivals with the quick '
                            'messages below.'),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10.5, height: 1.3),
                  );
                }
                return ListView(
                  reverse: true,
                  children: [
                    for (final (slot, mi) in msgs.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${_nameOf(slot, players)}  ',
                              style: TextStyle(
                                color: slot < kTeamColors.length
                                    ? kTeamColors[slot]
                                    : Colors.white70,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: mi >= 0 && mi < _chatPresets.length
                                  ? _chatPresets[mi]
                                  : '…',
                              style:
                                  const TextStyle(color: Color(0xFFF2E8D5)),
                            ),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11, height: 1.25),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 7),
          // Hazır mesaj çipleri (dar panelde alt satırlara sarar).
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < _chatPresets.length; i++)
                GestureDetector(
                  onTap: () => _sendChat(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E5527),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF5C7A2E)),
                    ),
                    child: Text(
                      _chatPresets[i],
                      style: const TextStyle(
                          color: Color(0xFFF2E8D5),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- ALT: başlat

  Widget _bottomBar() {
    if (widget.isHost) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _start,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF74A038), Color(0xFF4E6B26)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF9CCC65), width: 1.4),
              ),
              // Dar sol sütuna sığar (gerekirse yazı ölçeklenir).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CrossedSwordsIcon(size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _starting
                          ? loc('BAŞLIYOR...', 'STARTING...')
                          : loc('SAVAŞI BAŞLAT', 'START BATTLE'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          letterSpacing: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            loc(
                'Boş slotlar botla dolar · yerini değiştirmek için '
                'boş bir slota dokun.',
                'Empty slots are filled with bots · tap an empty slot '
                'to move there.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF223019),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A6130)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF8BC34A)),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                    loc('Kurucunun başlatması bekleniyor...',
                        'Waiting for the host to start...'),
                    maxLines: 2,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          loc(
              'Yerini değiştirmek için boş bir slota dokun · '
              'ayrılmak için geri tuşu.',
              'Tap an empty slot to move there · back button to leave.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 9.5),
        ),
      ],
    );
  }
}
