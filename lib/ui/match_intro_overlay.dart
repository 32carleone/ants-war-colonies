import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/abilities.dart';
import '../data/i18n.dart';
import '../data/units.dart';
import '../game/ant_painter.dart';
import '../game/ants_wars_game.dart';
import '../game/audio_controller.dart';
import '../models/player.dart';
import 'ability_art.dart';
import 'crossed_swords.dart';
import 'game_back_button.dart';

/// KARŞILAŞMA EKRANI: maç yüklenince, savaş başlamadan önce tüm
/// savaşçıları yan yana gösterir — her kartta portre, ad, bot ise
/// kişilik + zorluk, altta 3 yetenek. Kartlar arasında ilişki ikonu:
/// MÜTTEFİK = el sıkışma, DÜŞMAN = çapraz kılıçlar. Tekli/kurucu BAŞLA'ya
/// basınca savaş başlar; LAN'da katılanlar kurucuyu bekler (ilk anlık
/// görüntü gelince kendiliğinden kapanır).
class MatchIntroOverlay extends StatefulWidget {
  const MatchIntroOverlay({
    super.key,
    required this.game,
    required this.onStart,
  });

  final AntsWarsGame game;
  final VoidCallback onStart;

  @override
  State<MatchIntroOverlay> createState() => _MatchIntroOverlayState();
}

class _MatchIntroOverlayState extends State<MatchIntroOverlay> {
  Timer? _poll;

  bool get _isClient => widget.game.isNetClient;

  @override
  void initState() {
    super.initState();
    // Botların kişilik/yetenekleri oyun YÜKLENİNCE belli olur — ekran
    // ilk karede kurulduysa yükleme bitince bir kez tazelenir.
    widget.game.loaded.whenComplete(() {
      if (mounted) setState(() {});
    });
    if (_isClient) {
      // Kurucu BAŞLA'ya basınca ilk anlık görüntü akar — o an başla.
      _poll = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if ((widget.game.netClient?.snapshotsSeen ?? 0) > 0) {
          _poll?.cancel();
          widget.onStart();
        }
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String get _difficultyLabel {
    final lan = widget.game.gameState.lan;
    final index = lan != null && !lan.isHost
        ? (lan.client?.difficultyIndex ?? 1)
        : widget.game.gameState.difficulty.index;
    return switch (index) {
      0 => loc('Kolay', 'Easy'),
      2 => loc('Zor', 'Hard'),
      3 => loc('Kâbus', 'Nightmare'),
      _ => 'Normal',
    };
  }

  /// Oyuncunun görünen adı.
  String _nameOf(Player p) {
    final lan = widget.game.gameState.lan;
    if (p.isBot) {
      // Kişilik (yalnız simüle eden tarafta bilinir).
      for (final b in widget.game.bots) {
        if (b.player.id == p.id) return b.persona.label;
      }
      return 'Bot';
    }
    if (lan != null) return lan.nameOf(p.id);
    return loc('SEN', 'YOU');
  }

  bool _isMe(Player p) => !p.isBot && !p.remote;

  /// Oyuncunun 3 yetenek seti (bilinmiyorsa boş — istemcide botlar).
  List<AbilityType> _abilitiesOf(Player p) {
    final game = widget.game;
    if (_isMe(p)) return game.humanAbilities;
    if (p.isBot) {
      for (final b in game.bots) {
        if (b.player.id == p.id) return b.abilities;
      }
      return const [];
    }
    // Uzak insan: lobi meta yükünden.
    final lan = game.gameState.lan;
    if (lan == null) return const [];
    for (final m in lan.players) {
      if (m.slot == p.id) {
        return [
          for (final i in m.loadout)
            if (i >= 0 && i < AbilityType.values.length)
              AbilityType.values[i]
        ];
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final state = game.gameState;
    // Müttefikler yan yana dursun diye takıma göre sırala.
    final players = List<Player>.of(state.players)
      ..sort((a, b) =>
          a.team != b.team ? a.team - b.team : a.id - b.id);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // alttaki oyuna dokunuş sızdırma
        child: Container(
          // Sayfa fonu: altta OYUN HARİTASI soluk görünür (karartma
          // gradienti — ortada harita nefes alır, üst/alt koyulaşır).
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xF20F1608),
                Color(0xC414200C),
                Color(0xC414200C),
                Color(0xF20F1608),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // GERİ: savaş başlamadan vazgeç → ana menü (standart konum).
                Positioned(
                  left: 0,
                  top: 10,
                  child: GameBackButton(
                    onTap: () {
                      AudioController.uiClick();
                      widget.game.gameState.backToMenu();
                    },
                  ),
                ),
                Column(
              children: [
                const SizedBox(height: 14),
                // Başlık: harita + mod.
                Text(
                  state.map?.name ?? '',
                  style: const TextStyle(
                      color: Color(0xFFF2E8D5),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Color(0xCC000000), blurRadius: 8)
                      ]),
                ),
                const SizedBox(height: 3),
                Text(
                  state.teamMode
                      ? loc('2v2 EŞLİ SAVAŞ', '2v2 TEAM BATTLE')
                      : loc('${players.length} KOLONİ — KARŞILAŞMA',
                          '${players.length} COLONIES — MATCHUP'),
                  style: const TextStyle(
                      color: Color(0xFF8BC34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 3),
                ),
                const SizedBox(height: 14),
                // Savaşçı kartları — bitişik durur; ilişki rozetleri iki
                // kartın SINIRINA biner (üstlerinde yüzer).
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: LayoutBuilder(builder: (context, cons) {
                      const gap = 10.0;
                      // Kart boyu HER MODDA 4 kişilik yerleşimin kartı
                      // kadardır (1v1/1v1v1 yayılmaz, ortalanır).
                      final n = players.length;
                      final maxCardW = (cons.maxWidth - gap * 3) / 4;
                      final cardW = math.min(
                          (cons.maxWidth - gap * (n - 1)) / n, maxCardW);
                      final rowW = cardW * n + gap * (n - 1);
                      final startX = (cons.maxWidth - rowW) / 2;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: startX,
                            top: 0,
                            bottom: 0,
                            width: rowW,
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < n; i++) ...[
                                  if (i > 0) const SizedBox(width: gap),
                                  SizedBox(
                                      width: cardW,
                                      child: _playerCard(players[i])),
                                ],
                              ],
                            ),
                          ),
                          for (var i = 1; i < n; i++)
                            Positioned(
                              left: startX +
                                  cardW * i +
                                  gap * (i - 1) +
                                  gap / 2 -
                                  31,
                              top: cons.maxHeight * 0.26,
                              child: _relationBadge(
                                  players[i - 1], players[i]),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _bottomAction(),
                const SizedBox(height: 14),
              ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// İki kartın sınırına binen ilişki rozeti:
  /// MÜTTEFİK = iki farklı renkte el, BİLEKLERDEN kavrayarak sıkışır;
  /// DÜŞMAN = çapraz kılıçlar.
  Widget _relationBadge(Player a, Player b) {
    final allied = a.team == b.team;
    return Container(
      width: 62,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xF01B2513),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: allied
                ? const Color(0xFFE8B33C)
                : const Color(0xFFB0553A),
            width: 1.4),
        boxShadow: const [
          BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 10,
              offset: Offset(0, 3)),
        ],
      ),
      child: allied
          ? const CustomPaint(
              size: Size(38, 38),
              painter: _HandshakePainter(Color(0xFFE8B33C)),
            )
          : const CrossedSwordsIcon(size: 30, color: Color(0xFFB0553A)),
    );
  }

  Widget _playerCard(Player p) {
    final me = _isMe(p);
    final abilities = _abilitiesOf(p);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        // Takım rengi → şeffafa akan gradient zemin + renkli kenarlık.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.color.withValues(alpha: 0.42),
            p.color.withValues(alpha: 0.10),
            const Color(0x66101708),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: me
              ? const Color(0xFF9CCC65)
              : p.color.withValues(alpha: 0.85),
          width: me ? 2.2 : 1.6,
        ),
      ),
      // Alçak telefon ekranında içerik TAŞMAZ: sabit 160px tasarım
      // genişliğindeki blok karta sığacak şekilde ölçeklenir.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 160,
            child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Portre: dairesiz, iri, takım yamalı karınca.
          CustomPaint(
            size: const Size(84, 84),
            painter: _AntHeroPainter(
                p.isBot ? UnitType.trapjaw : UnitType.fire, p.color),
          ),
          const SizedBox(height: 9),
          Text(
            _nameOf(p),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: me ? const Color(0xFF9CCC65) : const Color(0xFFF2E8D5),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            p.isBot
                ? loc('$_difficultyLabel Bot', '$_difficultyLabel Bot')
                : (p.remote
                    ? loc('İnsan — yerel ağ', 'Human — local network')
                    : loc('İnsan', 'Human')),
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          Container(height: 1, width: 70, color: Colors.white12),
          const SizedBox(height: 10),
          // Yetenek seti (bilinmiyorsa gizli).
          if (abilities.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in abilities) ...[
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2513),
                      borderRadius: BorderRadius.circular(7),
                      border:
                          Border.all(color: const Color(0xFF4A6130)),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: AbilityArt(type: t),
                  ),
                ],
              ],
            )
          else
            Text(loc('yetenekler gizli', 'abilities hidden'),
                style:
                    const TextStyle(color: Colors.white30, fontSize: 9.5)),
        ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomAction() {
    if (_isClient) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF8BC34A)),
          ),
          const SizedBox(width: 10),
          Text(
            loc('Kurucu savaşı başlatacak...',
                'Waiting for the host to start...'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        widget.onStart();
      },
      child: Container(
        height: 48,
        width: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF74A038), Color(0xFF4E6B26)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF9CCC65), width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrossedSwordsIcon(size: 22),
            const SizedBox(width: 9),
            Text(
              loc('SAVAŞA BAŞLA', 'START BATTLE'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dairesiz iri portre: yukarı bakan karınca + gölge; takım rengi
/// abdomen yamasına işlenir (oyunun görsel dili — halka yok).
class _AntHeroPainter extends CustomPainter {
  _AntHeroPainter(this.type, this.teamColor);

  final UnitType type;
  final Color teamColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, size.height * 0.36),
          width: size.width * 0.62,
          height: size.height * 0.16),
      Paint()..color = const Color(0x4D000000),
    );
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-1.5708);
    canvas.scale(size.width / 34 * 1.1 * unitSpecs[type]!.scale);
    paintAnt(canvas, type,
        walkPhase: 0.9, idleTime: 0.4, teamColor: teamColor);
  }

  @override
  bool shouldRepaint(covariant _AntHeroPainter old) =>
      old.type != type || old.teamColor != teamColor;
}

/// EL SIKIŞMA (müttefik rozeti): KLASİK tokalaşma ikonu — referans
/// siluetten çıkarılmış kontur (iki el kenetli, kollar manşetli; parmak
/// araları evenOdd ile delik). Renk oyunun ALTIN vurgusudur.
// Klasik tokalaşma silueti (referans ikondan çıkarılmış kontur;
// dış hat + parmak boşlukları, evenOdd ile delinir). 0..1 uzayı.
const List<List<double>> _handshakeLoops = [
  [0.1635, 0.1824, 0.2453, 0.2264, 0.2453, 0.2453, 0.1006, 0.5031, 0.0881, 0.522, 0.0692, 0.522, 0.0, 0.4717],
  [0.8302, 0.1824, 0.8428, 0.1824, 1.0, 0.4654, 1.0, 0.4843, 0.9371, 0.522, 0.9182, 0.522, 0.8994, 0.4969, 0.7925, 0.2893, 0.761, 0.2516, 0.761, 0.2264],
  [0.4654, 0.2642, 0.6101, 0.2642, 0.7044, 0.2893, 0.761, 0.2767, 0.8679, 0.4654, 0.8805, 0.5094, 0.8302, 0.5535, 0.805, 0.5535, 0.6541, 0.434, 0.4969, 0.3459, 0.4403, 0.3585, 0.4025, 0.4088, 0.3585, 0.434, 0.3082, 0.434, 0.3208, 0.3836, 0.3774, 0.3019, 0.4025, 0.2767],
  [0.239, 0.283, 0.3459, 0.3145, 0.2893, 0.4025, 0.2956, 0.4528, 0.3648, 0.4528, 0.4025, 0.434, 0.4465, 0.3774, 0.4906, 0.3648, 0.6164, 0.434, 0.7673, 0.5409, 0.8113, 0.5786, 0.8176, 0.6226, 0.7925, 0.6415, 0.7673, 0.6415, 0.5975, 0.5409, 0.5912, 0.5535, 0.6101, 0.5723, 0.7421, 0.6415, 0.7484, 0.6792, 0.7296, 0.6981, 0.6855, 0.6981, 0.5535, 0.6226, 0.5597, 0.6478, 0.6792, 0.7107, 0.6792, 0.7421, 0.6667, 0.7547, 0.6164, 0.7547, 0.5157, 0.7044, 0.5157, 0.7296, 0.6101, 0.7799, 0.5786, 0.805, 0.4717, 0.7925, 0.478, 0.7233, 0.4591, 0.6981, 0.4151, 0.6855, 0.4151, 0.6478, 0.3899, 0.6226, 0.3585, 0.6164, 0.3585, 0.5849, 0.3333, 0.5535, 0.283, 0.5472, 0.2516, 0.5786, 0.2201, 0.5409, 0.195, 0.5346, 0.1509, 0.5535, 0.1195, 0.5157, 0.1321, 0.4717],
  [0.1824, 0.5597, 0.2138, 0.5597, 0.2327, 0.5786, 0.2327, 0.6101, 0.195, 0.6541, 0.1635, 0.6478, 0.1509, 0.6289, 0.1509, 0.5975],
  [0.2893, 0.566, 0.327, 0.5723, 0.3396, 0.6164, 0.283, 0.6981, 0.2579, 0.7233, 0.2327, 0.7233, 0.2075, 0.673],
  [0.3522, 0.6352, 0.3899, 0.6478, 0.3962, 0.6918, 0.3396, 0.7673, 0.3082, 0.7736, 0.2893, 0.761, 0.283, 0.7233],
  [0.4025, 0.7107, 0.4403, 0.7107, 0.4591, 0.7296, 0.4591, 0.7547, 0.4214, 0.8113, 0.3836, 0.8176, 0.3648, 0.7987, 0.3648, 0.761],
];

class _HandshakePainter extends CustomPainter {
  const _HandshakePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final loop in _handshakeLoops) {
      path.moveTo(loop[0] * size.width, loop[1] * size.height);
      for (var i = 2; i < loop.length; i += 2) {
        path.lineTo(loop[i] * size.width, loop[i + 1] * size.height);
      }
      path.close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HandshakePainter old) =>
      old.color != color;
}
