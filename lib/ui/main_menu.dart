import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/i18n.dart';
import '../data/settings.dart';
import '../data/units.dart';
import '../game/ant_painter.dart';
import '../game/audio_controller.dart';
import '../data/maps.dart';
import '../game/game_state.dart';
import 'ability_art.dart';
import 'campaign_select_screen.dart';
import 'crossed_swords.dart';
import 'developer_screen.dart';
import 'multiplayer_screen.dart';
import 'play_setup_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'wiki_screen.dart';

/// Rastgele oyuncu adı: Player + 5 hane (çakışma olasılığı düşük;
/// LAN lobisi yine de aynı isimleri "(2)" ekiyle ayırır).
String generatePlayerName([math.Random? rng]) {
  final r = rng ?? math.Random();
  return 'Player${10000 + r.nextInt(90000)}';
}

/// Ana menü — GRID ızgara düzeni:
/// SOLDA ana karakter (kraliçe) ve altında 3 yetenek slotu; slota dokununca
/// SAĞDA panel açılır, güçler listeden seçilir.
/// SAĞDA kutular: Ayarlar, Wiki ve en altta Tekli/Eşli seçimi + SAVAŞ.
/// Tüm kutular alanı tam kaplar, köşeler az yuvarlatılmıştır.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  /// Sağda güç seçim paneli açıksa düzenlenen slot (null: kapalı).
  int? _pickingSlot;

  /// Kullanıcı adı — İLK girişte rastgele üretilir (Player#####),
  /// kalemle değiştirilebilir ve kalıcı saklanır.
  String _playerName = generatePlayerName();

  @override
  void initState() {
    super.initState();
    AudioController.playMenuMusic();
    SharedPreferences.getInstance().then((p) {
      final n = p.getString('player_name');
      if (n != null && n.trim().isNotEmpty) {
        if (mounted) setState(() => _playerName = n);
      } else {
        // İlk giriş: üretilen adı kalıcılaştır (bir daha değişmez).
        p.setString('player_name', _playerName);
      }
      // İLK GİRİŞ: eğitime katılmak ister mi? (Yalnız bir kez sorulur.)
      if (!(p.getBool('tutorial_prompted') ?? false)) {
        p.setBool('tutorial_prompted', true);
        if (mounted) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _offerTutorial());
        }
      }
    }).catchError((_) {}); // eklenti yoksa (test) varsayılan kalır
  }

  /// İlk açılışta eğitim önerisi.
  Future<void> _offerTutorial() async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF223019),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFB27F19)),
        ),
        title: Text(loc('Eğitim Kampı 🐜', 'Boot Camp 🐜'),
            style: const TextStyle(color: Color(0xFFF2E8D5), fontSize: 18)),
        content: Text(
          loc(
              'İlk kez oynuyorsun! Kısa bir eğitim savaşında tüm özellikleri '
              'adım adım öğrenmek ister misin?\n\n(İstediğin zaman Savaş Kur '
              'ekranındaki EĞİTİM kartından tekrar oynayabilirsin.)',
              'First time playing! Want to learn every feature step by step '
              'in a short training battle?\n\n(You can replay it anytime from '
              'the TRAINING card on the Battle Setup screen.)'),
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc('Şimdi Değil', 'Not Now'),
                style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5C7A2E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc('Eğitime Başla', 'Start Training')),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      AudioController.uiClick();
      widget.gameState.startMatch(
        playerCount: 2,
        map: tutorialMap,
        tutorial: true,
      );
    }
  }

  /// Kullanıcı adı düzenleme penceresi: kaydet → SharedPreferences.
  Future<void> _editPlayerName() async {
    AudioController.uiClick();
    final controller = TextEditingController(text: _playerName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Klavye açılınca yatay ekranda alan daralır: içerik kaydırılabilir
        // olmazsa "bottom overflow" verir.
        scrollable: true,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        backgroundColor: const Color(0xFF223019),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF4A6130)),
        ),
        title: Text(loc('Kullanıcı Adı', 'Player Name'),
            style: const TextStyle(color: Color(0xFFF2E8D5), fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 14,
          style: const TextStyle(color: Color(0xFFF2E8D5)),
          cursorColor: const Color(0xFF8BC34A),
          decoration: const InputDecoration(
            counterStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4A6130))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8BC34A))),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(loc('Vazgeç', 'Cancel'),
                    style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFF5C7A2E)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(loc('Kaydet', 'Save')),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _playerName = name.trim());
    SharedPreferences.getInstance()
        .then((p) => p.setString('player_name', name.trim()))
        .catchError((_) => Future<bool>.value(false));
  }

  @override
  void dispose() {
    _bg.dispose();
    super.dispose();
  }

  void _push(Widget screen) {
    AudioController.uiClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Multiplayer yalnız gerçek cihazlarda (LAN soketleri webde yok).
  void _openMultiplayer() {
    if (kIsWeb) {
      AudioController.uiClick();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc(
            'Multiplayer web sürümünde desteklenmiyor — Android/masaüstü '
            'sürümünde aynı Wi-Fi üzerinden oynayabilirsin.',
            'Multiplayer is not supported on the web build — play over the '
            'same Wi-Fi on the Android/desktop version.')),
        backgroundColor: Color(0xFF3E5527),
      ));
      return;
    }
    _push(MultiplayerScreen(
      gameState: widget.gameState,
      playerName: _playerName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gameState = widget.gameState;
    return Scaffold(
      backgroundColor: const Color(0xFF31431F),
      // Klavye (isim düzenleme) açılınca menü SIKIŞMASIN — sıkışınca
      // kutu içerikleri alttan taşıyordu. Pencere kendi boşluğunu ayarlar.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Statik zemin ayrı katman: her karede yeniden ÇİZİLMEZ.
          const RepaintBoundary(
            child: CustomPaint(
                painter: _ParadeGroundPainter(), size: Size.infinite),
          ),
          // Yürüyen karıncalar kendi katmanında: animasyon menünün geri
          // kalanını yeniden boyatmaz (maç sonrası menü kasması düzeltmesi).
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bg,
              builder: (context, _) => CustomPaint(
                  painter: _AntParadePainter(_menuAnimT(_bg.value * 30)),
                  size: Size.infinite),
            ),
          ),
          // SAĞ ÜST BUTON SETİ (logo hizası): geliştirici detayları.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                // SEFER kutusunun sağ kenarıyla aynı hizada (içerik
                // yatay padding'i 36) — köşede yalnız durmaz.
                padding: const EdgeInsets.only(top: 10, right: 36),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopIconButton(
                      icon: Icons.query_stats,
                      tooltip: loc('İstatistikler', 'Statistics'),
                      onTap: () => _push(const StatsScreen()),
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                      icon: Icons.code,
                      tooltip: loc('Geliştirici', 'Developer'),
                      onTap: () => _push(const DeveloperScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // OYUN ADI: büyük "ANTS WAR", hemen altında ufak "COLONIES".
                const Text(
                  'ANTS WAR',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFFF2E8D5),
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8)],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8), // harf aralığını dengele
                  child: Text(
                    'COLONIES',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 11,
                      color: Color(0xFFE8B33C),
                      shadows: [
                        Shadow(color: Color(0xAA000000), blurRadius: 6)
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SOL: ana karakter + yetenek slotları (tam yükseklik).
                        Expanded(
                          child: _HeroPanel(
                            gameState: gameState,
                            anim: _bg,
                            playerName: _playerName,
                            onEditName: _editPlayerName,
                            pickingSlot: _pickingSlot,
                            onSlotTap: (i) {
                              AudioController.uiClick();
                              setState(
                                () =>
                                    _pickingSlot = _pickingSlot == i ? null : i,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // SAĞ: grid kutular VEYA güç seçim paneli.
                        Expanded(
                          child: _pickingSlot != null
                              ? _abilityPickerPanel(_pickingSlot!)
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Üst blok: solda Ayarlar+Wiki, sağda
                                    // iki kutu boyunda SEFER (hikâye modu).
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: _SideBox(
                                                    icon: Icons.settings,
                                                    label: loc(
                                                        'Ayarlar', 'Settings'),
                                                    desc: loc(
                                                        'Ses, müzik, titreşim '
                                                        've grafik tercihleri',
                                                        'Sound, music, '
                                                        'vibration & graphics'),
                                                    footer: 'v$kAppVersion',
                                                    onTap: () => _push(
                                                        const SettingsScreen()),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: _SideBox(
                                                    icon: Icons.menu_book,
                                                    label: 'Wiki',
                                                    desc: loc(
                                                        'Karıncalar, binalar '
                                                        've güçler rehberi',
                                                        'Ants, buildings & '
                                                        'powers guide'),
                                                    onTap: () =>
                                                        _push(const WikiScreen()),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 128,
                                            child: _CampaignBox(
                                              onTap: () => _push(
                                                CampaignSelectScreen(
                                                  gameState: gameState,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // MULTIPLAYER (yerel ağ) + SAVAŞ.
                                    SizedBox(
                                      height: 78,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: _MultiplayerButton(
                                              onTap: _openMultiplayer,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _BattleButton(
                                              onTap: () => _push(
                                                PlaySetupScreen(
                                                  gameState: gameState,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Alt butonlar biraz yukarıda dursun.
                const SizedBox(height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sağda açılan güç seçim paneli: liste halinde tüm güçler.
  Widget _abilityPickerPanel(int slot) {
    final loadout = widget.gameState.abilityLoadout;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE6223019),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8BC34A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                loc('${slot + 1}. slot için güç seç',
                    'Pick a power for slot ${slot + 1}'),
                style: const TextStyle(
                  color: Color(0xFFF2E8D5),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  AudioController.uiClick();
                  setState(() => _pickingSlot = null);
                },
                child: const Icon(Icons.close, size: 18, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final spec in abilitySpecs.values)
                  _abilityTile(slot, spec, loadout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _abilityTile(int slot, AbilitySpec spec, List<AbilityType> loadout) {
    final current = loadout[slot] == spec.type;
    final usedElsewhere = loadout.contains(spec.type) && !current;
    return GestureDetector(
      onTap: usedElsewhere
          ? null
          : () {
              AudioController.uiClick();
              loadout[slot] = spec.type;
              saveAbilityLoadout(loadout);
              setState(() => _pickingSlot = null);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: current ? const Color(0xFF3E5527) : const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: current ? const Color(0xFF8BC34A) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: usedElsewhere ? 0.35 : 1,
              child: AbilityArt(type: spec.type, size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usedElsewhere
                        ? loc('${spec.name} (takılı)', '${spec.name} (equipped)')
                        : spec.name,
                    style: TextStyle(
                      color: usedElsewhere
                          ? Colors.white30
                          : const Color(0xFFF2E8D5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    loc('${spec.description} · Dolum ${spec.cooldown.round()} sn',
                        '${spec.description} · Cooldown ${spec.cooldown.round()}s'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (current)
              const Icon(Icons.check, size: 16, color: Color(0xFF8BC34A)),
          ],
        ),
      ),
    );
  }
}

/// Sol panel: kraliçe portresi + altında 3 yetenek slotu.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.gameState,
    required this.anim,
    required this.playerName,
    required this.onEditName,
    required this.onSlotTap,
    this.pickingSlot,
  });

  final GameState gameState;
  final Animation<double> anim;
  final String playerName;
  final VoidCallback onEditName;
  final ValueChanged<int> onSlotTap;
  final int? pickingSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE6223019),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A6130)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // Dar ekranlarda taşmasın: içerik sığmazsa oranını koruyarak küçülür.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: anim,
                builder: (context, _) => CustomPaint(
                  painter: _QueenHeroPainter(_menuAnimT(anim.value * 30)),
                  size: const Size(200, 150),
                ),
              ),
              const SizedBox(height: 4),
              // Oyuncu adı + sağında ALTIN KALEM çipi (ad değiştirme).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playerName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFF2E8D5),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEditName,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB27F19)),
                        color: const Color(0x33E8B33C),
                      ),
                      child: const Icon(Icons.edit,
                          size: 12, color: Color(0xFFE8B33C)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  loc('YETENEKLERİNİZ', 'YOUR ABILITIES'),
                  style: const TextStyle(
                    color: Color(0xFF8BC34A),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    _AbilitySlot(
                      type: gameState.abilityLoadout[i],
                      active: pickingSlot == i,
                      onTap: () => onSlotTap(i),
                    ),
                    if (i < 2)
                      Container(
                        width: 1.4,
                        height: 44,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white24,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                loc('değiştirmek için tıklayın', 'tap to change'),
                style:
                    const TextStyle(color: Colors.white38, fontSize: 8.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbilitySlot extends StatelessWidget {
  const _AbilitySlot({
    required this.type,
    required this.onTap,
    this.active = false,
  });

  final AbilityType type;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final spec = abilitySpecs[type]!;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            // Çerçevesiz özel çizim: kare boyutlu, düzenlenirken parlar.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: active
                  ? const [BoxShadow(color: Colors.white54, blurRadius: 8)]
                  : null,
            ),
            child: AbilityArt(type: type, size: 44),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 62,
            child: Text(
              spec.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sağ kutucuk (Ayarlar / Wiki): büyük soluk ikon ARKAPLANDA,
/// önde başlık + kısa açıklama.
class _SideBox extends StatelessWidget {
  const _SideBox({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  /// Açıklamanın altındaki ufak ek satır (örn. sürüm).
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: Stack(
          children: [
            // Arkaplanda büyük soluk ikon (köşeden taşar).
            Positioned(
              right: -16,
              bottom: -20,
              child: Icon(
                icon,
                size: 120,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              // Kutu daralırsa içerik oranını koruyarak küçülür (taşma yok).
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: const Color(0xFFD8C9A3)),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFFF2E8D5),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            footer!,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 9.5,
                            ),
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

/// SEFER (hikâye modu) kutusu — Ayarlar+Wiki'nin toplamı boyunda dikey
/// sancak; tıklayınca üç seferli seçim ekranı açılır.
/// Arkaplanında noktalı sefer rotası ve hedef bayrağı vardır.
class _CampaignBox extends StatelessWidget {
  const _CampaignBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE62E3E1E), Color(0xE64A3A20)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB27F19), width: 1.2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CampaignTrailPainter()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 30, color: Color(0xFFE8B33C)),
              const SizedBox(height: 8),
              Text(loc('SEFER', 'CAMPAIGN'),
                  style: const TextStyle(
                      color: Color(0xFFF2E8D5),
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 3)),
              Text(loc('hikâye modu', 'story mode'),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B33C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(loc('3 SEFER', '3 CAMPAIGNS'),
                    style: const TextStyle(
                        color: Color(0xFF3A2A10),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.5)),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// Sefer kutusu arkaplanı: kıvrılan noktalı rota, duraklar, hedef bayrağı.
class _CampaignTrailPainter extends CustomPainter {
  const _CampaignTrailPainter();

  Offset _at(Size size, double t) => Offset(
        size.width * (0.5 + math.sin(t * math.pi * 2.2 + 0.6) * 0.28),
        size.height * (0.92 - 0.84 * t),
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Noktalı rota.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var t = 0.0; t <= 1.0; t += 0.045) {
      canvas.drawCircle(_at(size, t), 2.1, dot);
    }
    // Duraklar (görev halkaları).
    final ring = Paint()
      ..color = const Color(0xFFE8B33C).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final t in const [0.16, 0.5, 0.82]) {
      canvas.drawCircle(_at(size, t), 5.5, ring);
    }
    // Hedefte bayrak.
    final top = _at(size, 1.0);
    final pole = Paint()
      ..color = const Color(0xFFE8B33C).withValues(alpha: 0.35)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(top, top.translate(0, -13), pole);
    final flag = Path()
      ..moveTo(top.dx, top.dy - 13)
      ..lineTo(top.dx + 9, top.dy - 10)
      ..lineTo(top.dx, top.dy - 7)
      ..close();
    canvas.drawPath(flag,
        Paint()..color = const Color(0xFFE8B33C).withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant _CampaignTrailPainter oldDelegate) => false;
}

/// MULTIPLAYER butonu (yerel ağ): altın tonlu, yayın dalgalı ikon.
class _MultiplayerButton extends StatelessWidget {
  const _MultiplayerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFCB9227), Color(0xFF8A5E12)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8B33C), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        // SAVAŞ butonuyla aynı dil: ikon + tek satır başlık.
        // Yazı bir tık küçük ve kenarlardan nefes payı var (uzun kelime).
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded, size: 24, color: Colors.white),
                SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlığın üstünde ufak "LOCAL" rozeti (yerel ağ vurgusu).
                    Text(
                      'LOCAL',
                      style: TextStyle(
                        color: Color(0xFFFFE3A0),
                        fontWeight: FontWeight.w800,
                        fontSize: 8.5,
                        letterSpacing: 3.2,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'MULTIPLAYER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 1.4,
                        height: 1,
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

/// Büyük SAVAŞ butonu.
class _BattleButton extends StatelessWidget {
  const _BattleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
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
              color: Color(0x88000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrossedSwordsIcon(size: 26),
            const SizedBox(width: 8),
            Text(
              loc('SAVAŞ', 'BATTLE'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MENÜ ANİMASYON FRENİ: menü boyamaları 60fps yerine 30fps'e (düşük
/// kalitede 12fps'e) yuvarlanır — painter'ların shouldRepaint'i aynı
/// adımda boyamayı atlar, telefon GPU'su menüde dinlenir (özellikle uzun
/// bir maçtan ısınmış dönünce fark eder).
double _menuAnimT(double raw) {
  final fps = appSettings.highQuality ? 30.0 : 12.0;
  return (raw * fps).floorToDouble() / fps;
}

/// Sol paneldeki kraliçe — CANLI sahne: altın hale nefes alır, kraliçe
/// tümsekte hafifçe salınır, yarı saydam kanatları titrer, tacı mücevherli,
/// çevresinde altın parıltılar süzülür. Tümsek otlu ve çiçekli.
class _QueenHeroPainter extends CustomPainter {
  _QueenHeroPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.62);
    final bob = math.sin(t * 1.6) * 2.0;

    // Altın hale (nazikçe nefes alır).
    canvas.drawCircle(
      c.translate(0, -16),
      64 + math.sin(t * 1.8) * 3,
      Paint()
        ..color = const Color(
          0xFFE8B33C,
        ).withValues(alpha: 0.10 + 0.04 * math.sin(t * 1.8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Tümsek: iki katman toprak + üst kenarda ot püskülleri + çiçekler.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 28), width: 156, height: 46),
      Paint()..color = const Color(0xFF5C4326),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 22), width: 124, height: 36),
      Paint()..color = const Color(0xFF7E613A),
    );
    final grass = Paint()
      ..color = const Color(0xFF7A9A4C)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = -math.pi * (0.15 + 0.7 * i / 8);
      final gx = c.dx + math.cos(a) * 72;
      final gy = c.dy + 26 + math.sin(a) * 18;
      final sway = math.sin(t * 2 + i) * 1.5;
      canvas.drawLine(Offset(gx, gy), Offset(gx + sway, gy - 7), grass);
      canvas.drawLine(Offset(gx + 3, gy), Offset(gx + 4 + sway, gy - 5), grass);
    }
    for (final (fx, fy) in [(-52.0, 18.0), (44.0, 26.0), (60.0, 10.0)]) {
      final f = c.translate(fx, fy);
      for (var p = 0; p < 5; p++) {
        final a = p / 5 * 2 * math.pi + t * 0.4;
        canvas.drawCircle(
          f.translate(math.cos(a) * 3, math.sin(a) * 3),
          1.7,
          Paint()..color = const Color(0xFFF2E8D5),
        );
      }
      canvas.drawCircle(f, 1.8, Paint()..color = const Color(0xFFE8B33C));
    }

    // Kanatlar (gövdenin arkasında): yarı saydam, hafif çırpınır.
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx + side * 7, c.dy - 16 + bob);
      canvas.rotate(side * (0.55 + math.sin(t * 2.3) * 0.07));
      final wing = Rect.fromCenter(
        center: const Offset(0, -27),
        width: 24,
        height: 58,
      );
      canvas.drawOval(
        wing,
        Paint()..color = const Color(0xFFDFF3FA).withValues(alpha: 0.16),
      );
      canvas.drawOval(
        wing,
        Paint()
          ..color = const Color(0xFFDFF3FA).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        const Offset(0, -2),
        const Offset(0, -50),
        Paint()
          ..color = const Color(0xFFDFF3FA).withValues(alpha: 0.22)
          ..strokeWidth = 1,
      );
      canvas.restore();
    }

    // Kraliçe: salınır, nefes alır; antenler paintAnt içinde canlıdır.
    canvas.save();
    canvas.translate(c.dx, c.dy - 6 + bob);
    canvas.rotate(-1.5708);
    canvas.scale(4.7 * (1 + 0.015 * math.sin(t * 2.1)));
    paintAnt(
      canvas,
      UnitType.leafcutter,
      walkPhase: 0.9,
      idleTime: t,
      teamColor: const Color(0xFFDB6C22),
    );
    canvas.restore();

    // Taç: altın gövde + koyu kontur + uçlarda mücevherler.
    final cy = c.dy + bob;
    final crown = Path()
      ..moveTo(c.dx - 14, cy - 62)
      ..lineTo(c.dx - 12, cy - 76)
      ..lineTo(c.dx - 5, cy - 65)
      ..lineTo(c.dx, cy - 79)
      ..lineTo(c.dx + 5, cy - 65)
      ..lineTo(c.dx + 12, cy - 76)
      ..lineTo(c.dx + 14, cy - 62)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFE8B33C));
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFFB27F19)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(c.dx - 12, cy - 76),
      2.2,
      Paint()..color = const Color(0xFFC0392B),
    );
    canvas.drawCircle(
      Offset(c.dx, cy - 79),
      2.4,
      Paint()..color = const Color(0xFF2ECC71),
    );
    canvas.drawCircle(
      Offset(c.dx + 12, cy - 76),
      2.2,
      Paint()..color = const Color(0xFF3A7BD5),
    );
    // Taçta gezen parlama.
    final shineX = c.dx - 12 + ((t * 8) % 24);
    canvas.drawCircle(
      Offset(shineX, cy - 66),
      1.6,
      Paint()..color = const Color(0xFFFFF3D0).withValues(alpha: 0.9),
    );

    // Süzülen altın parıltılar (yükselip söner).
    for (var k = 0; k < 5; k++) {
      final ph = (t * 0.45 + k * 0.2) % 1.0;
      final px = c.dx + math.sin(k * 2.4 + t * 0.5) * 52;
      final py = cy - 18 - ph * 52;
      final a = ((1 - ph) * 0.8 * (ph * 6).clamp(0.0, 1.0));
      final star = Paint()
        ..color = const Color(0xFFF6D879).withValues(alpha: a)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final r = 2.5 + math.sin(t * 5 + k) * 0.8;
      canvas.drawLine(Offset(px - r, py), Offset(px + r, py), star);
      canvas.drawLine(Offset(px, py - r), Offset(px, py + r), star);
    }
  }

  @override
  bool shouldRepaint(covariant _QueenHeroPainter old) => old.t != t;
}

/// Menü arka planı: çimen zemin + ekranı kat eden karınca kolonları.
class _AntParadePainter extends CustomPainter {
  _AntParadePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const types = [
      UnitType.fire,
      UnitType.leafcutter,
      UnitType.wood,
      UnitType.trapjaw,
    ];
    for (var i = 0; i < 14; i++) {
      final type = types[i % types.length];
      final speed = 26.0 + (i % 5) * 9;
      final span = size.width + 120;
      final x = ((t * speed + i * 173.0) % span) - 60;
      final y = size.height * ((i * 0.83) % 1.0);
      final dir = i.isEven ? 1.0 : -1.0;
      canvas.save();
      canvas.translate(dir > 0 ? x : size.width - x, y);
      canvas.scale(1.6 * unitSpecs[type]!.scale);
      if (dir < 0) canvas.scale(-1, 1);
      paintAnt(
        canvas,
        type,
        walkPhase: t * speed * 0.45 + i,
        idleTime: t + i,
        teamColor: kTeamColors[i % kTeamColors.length].withValues(alpha: 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AntParadePainter old) => old.t != t;
}

/// Menü zemini: ton lekeleri + vinyet — STATİKTİR, bir kez çizilir
/// (RepaintBoundary sayesinde animasyon bunu yeniden boyatmaz).
class _ParadeGroundPainter extends CustomPainter {
  const _ParadeGroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF3A5026),
    );
    for (var i = 0; i < 40; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            rng.nextDouble() * size.width,
            rng.nextDouble() * size.height,
          ),
          width: 60 + rng.nextDouble() * 160,
          height: 40 + rng.nextDouble() * 90,
        ),
        Paint()
          ..color = const Color(0xFF31431F)
              .withValues(alpha: 0.3 + rng.nextDouble() * 0.3),
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF120E08).withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _ParadeGroundPainter old) => false;
}

/// Menü sağ üst köşesindeki küçük kare ikon butonu (oyun stilinde).
class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xE6223019),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A6130)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFD8C9A3)),
        ),
      ),
    );
  }
}
