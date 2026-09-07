import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/maps.dart';
import '../models/game_map.dart';
import '../models/player.dart';
import '../data/match_history.dart';
import '../net/lan_client.dart';
import '../net/lan_host.dart';
import '../net/lan_protocol.dart';

/// Bot zorluk seviyeleri. Normal/Zor/Kâbus AYNI tam programı oynar; fark
/// botların başlangıç parasında (normal ×1, zor ×1.5, kâbus ×5 — açık
/// kural). Kolay ayrı: yavaş düşünen, plansız bot.
enum Difficulty { easy, normal, hard, nightmare }

/// SEFER görevi kurulumu: sabit yetenekler, başlangıç desteği (altın /
/// binalar), zorluk ve düşman güçlendirmesi. Tüm düşman botlar TEK takımdır
/// (2v1 / 3v1 mümkün); oyuncu yuvası HARİTANIN İLK yuva noktasıdır.
class MissionSetup {
  const MissionSetup({
    required this.campaignKey,
    required this.level,
    required this.difficulty,
    required this.loadout,
    this.gold = kStartingResources,
    this.ownedBuildings = const [],
    this.enemyGold,
  });

  final String campaignKey; // 'fire' | 'ice' | 'islands'
  final int level; // 1..5
  final Difficulty difficulty;
  final List<AbilityType> loadout; // 1-3 sabit yetenek
  final int gold; // oyuncu başlangıç altını
  final List<int> ownedBuildings; // maç başında oyuncuya verilen binalar
  final int? enemyGold; // düşman botların başlangıç altını (zorlaştırıcı)
}

/// LAN maçı bağlamı: kim host, hangi slot bizim, ağ servisleri.
/// GameState.lan != null ise maç HOST-OTORİTER ağ maçıdır.
class LanMatchConfig {
  LanMatchConfig({
    required this.seed,
    required this.localSlot,
    required this.mode,
    required this.players,
    this.host,
    this.client,
  });

  /// Yuva karıştırması iki tarafta da aynı çıksın diye paylaşılan tohum.
  final int seed;

  /// Bu cihazın oyuncu slotu (host = 0).
  final int localSlot;

  final LanMode mode;
  final List<LanPlayerMeta> players;

  /// Yalnız biri doludur: kuran cihazda [host], katılanda [client].
  final LanHostService? host;
  final LanClientService? client;

  bool get isHost => host != null;

  String nameOf(int slot) => players
      .firstWhere((p) => p.slot == slot,
          orElse: () => LanPlayerMeta(
              slot: slot, name: 'Oyuncu', team: slot, isBot: true))
      .name;
}

/// Maç sonunda HER OYUNCU için karne (sonuç ekranı çizelgeleri).
class PlayerMatchStats {
  const PlayerMatchStats({
    required this.color,
    required this.isHuman,
    required this.ally,
    required this.eliminated,
    required this.produced,
    required this.goldEarned,
    required this.buildings,
    required this.unitsLost,
    this.name,
  });

  final Color color;
  final bool isHuman;
  final bool ally;
  final bool eliminated;
  final int produced;
  final int goldEarned;
  final int buildings;
  final int unitsLost;

  /// LAN maçında oyuncu adı (yerel maçta null — SEN/RAKİP etiketi yeter).
  final String? name;
}

/// Maç sonu istatistikleri (sonuç ekranında gösterilir).
class MatchStats {
  const MatchStats({
    required this.duration,
    required this.unitsProduced,
    required this.buildingsCaptured,
  });

  final double duration;
  final int unitsProduced;
  final int buildingsCaptured;
}

/// Oyunun üst düzey akış evreleri.
enum GamePhase {
  /// Ana menüde / oyun henüz kurulmadı.
  menu,

  /// Maç oynanıyor.
  playing,

  /// İnsan oyuncu kazandı.
  victory,

  /// İnsan oyuncu elendi.
  defeat,
}

/// Maç kurulumu ve akış durumu. UI bu sınıfı dinler (ChangeNotifier).
///
/// Oyun mantığının kendisi Flame tarafında (AntsWarsGame) yaşar; burası
/// yalnızca "hangi ekrandayız, kimler oynuyor" bilgisini tutar.
class GameState extends ChangeNotifier {
  GamePhase _phase = GamePhase.menu;
  GamePhase get phase => _phase;

  final List<Player> players = [];

  /// Oynanacak harita (startMatch'te oyuncu sayısına göre seçilir).
  MapDefinition? map;

  /// Kraliçenin 3 yetenek slotu (ana menüdeki Yetenekler ekranından değişir;
  /// kalıcı kayıt shared_preferences ile).
  List<AbilityType> abilityLoadout = List.of(defaultLoadout);

  /// Bot zorluğu (menüden seçilir).
  Difficulty difficulty = Difficulty.normal;

  /// Yeni maç kimliği: GameScreen'in taze kurulmasını sağlar (yeniden başlat).
  int matchId = 0;

  /// Son maçın oyuncu sayısı ve haritası ("Tekrar Oyna" için).
  int lastPlayerCount = 2;
  MapDefinition? lastMap;
  bool lastTeamMode = false;
  bool lastEnemyAlliance = false;

  /// Bu maç 2v2 takım modu mu?
  bool teamMode = false;

  /// Eğitim maçı: rakip beyinsiz, adım adım öğretici gösterilir.
  bool tutorial = false;
  bool lastTutorial = false;

  /// HAYATTA KALMA (Horde): tek başına, büyüyen yabani dalgalarına karşı.
  bool horde = false;
  bool lastHorde = false;

  /// Horde: düşülen dalga (sonuç ekranı gösterir).
  int lastHordeWave = 0;

  /// Aktif sefer görevi (null = normal maç). "Tekrar Oyna" için son görev.
  MissionSetup? mission;
  MissionSetup? lastMission;

  /// Aktif LAN maçı bağlamı (null = yerel maç).
  LanMatchConfig? lan;

  /// Son biten maçın istatistikleri.
  MatchStats? lastStats;

  /// Son maçta oyuncu başına karneler + haritadaki toplam bina sayısı
  /// (hakimiyet yüzdesi için).
  List<PlayerMatchStats>? lastPlayerStats;
  int totalBuildings = 0;

  /// GÜÇ GRAFİĞİ: 5 sn aralıklı, oyuncu sırasına göre güç örnekleri.
  List<List<int>>? lastStrengthHistory;

  /// BU CİHAZIN insan oyuncusu (LAN'da uzak insanlar `remote`dur).
  Player? get humanPlayer {
    for (final p in players) {
      if (!p.isBot && !p.remote) return p;
    }
    return null;
  }

  /// Yeni bir maç kurar.
  /// Tekli: 1 insan + (playerCount-1) bot, herkes kendi takımı.
  /// [teamMode] (2v2): insan + bot müttefik vs 2 bot — 4 oyuncu zorunlu.
  /// [enemyAlliance] (tekli, 3-4 oyunculu): TÜM düşman botlar tek takım
  /// olur (2v1/3v1) — sisi paylaşır, birlikte kuşatır, zafer için hepsi
  /// yenilmelidir.
  void startMatch({
    required int playerCount,
    MapDefinition? map,
    bool teamMode = false,
    bool tutorial = false,
    bool enemyAlliance = false,
    bool horde = false,
    MissionSetup? mission,
  }) {
    assert(playerCount >= 2 && playerCount <= 4);
    assert(!teamMode || playerCount == 4);
    assert(map == null || map.playerCount == playerCount);
    matchId++;
    lastPlayerCount = playerCount;
    lastMap = map;
    lastTeamMode = teamMode;
    lastEnemyAlliance = enemyAlliance;
    this.tutorial = tutorial;
    lastTutorial = tutorial;
    this.horde = horde;
    lastHorde = horde;
    this.mission = mission;
    lastMission = mission;
    this.teamMode = teamMode;
    this.map = map ?? mapForPlayers(playerCount);
    players.clear();
    if (horde) {
      // HAYATTA KALMA: oyuncu + baştan YIKIK yabani kaynak kolonisi.
      // Dalgalar bu "sahipsiz" oyuncunun askerleri olarak doğar —
      // yabani (combatTeam) kuralları sayesinde herkese düşmandırlar.
      players.addAll([
        // HAYATTA KALMA AÇILIŞI: normalden zengin başlangıç (250) —
        // ilk dalgalardan önce savunma kurmaya yetecek sermaye.
        Player(id: 0, team: 0, color: kTeamColors[0], isBot: false,
            resources: 250),
        Player(id: 1, team: 1, color: kTeamColors[1], isBot: true,
            resources: 0)
          ..eliminated = true,
      ]);
      _phase = GamePhase.playing;
      notifyListeners();
      return;
    }
    if (mission != null) {
      // SEFER: oyuncu takım 0, TÜM düşman botlar takım 1 (müttefik).
      players.addAll(List.generate(
        playerCount,
        (i) => Player(
          id: i,
          team: i == 0 ? 0 : 1,
          color: kTeamColors[i],
          isBot: i != 0,
          resources: kStartingResources,
        ),
      ));
    } else if (teamMode) {
      // Takım 0: insan (turuncu) + müttefik bot (yeşil).
      // Takım 1: iki düşman bot (mavi + mor).
      players.addAll([
        Player(id: 0, team: 0, color: kTeamColors[0], isBot: false,
            resources: kStartingResources),
        Player(id: 1, team: 0, color: kTeamColors[2], isBot: true,
            resources: kStartingResources),
        Player(id: 2, team: 1, color: kTeamColors[1], isBot: true,
            resources: kStartingResources),
        Player(id: 3, team: 1, color: kTeamColors[3], isBot: true,
            resources: kStartingResources),
      ]);
    } else {
      // Tekli: herkes kendi takımı; DÜŞMAN İTTİFAKI açıksa tüm botlar
      // takım 1'de birleşir (sefer kurallarıyla aynı sözleşme).
      players.addAll(List.generate(
        playerCount,
        (i) => Player(
          id: i,
          team: enemyAlliance ? (i == 0 ? 0 : 1) : i,
          color: kTeamColors[i],
          isBot: i != 0,
          resources: kStartingResources,
        ),
      ));
    }
    // ZORLUK = BAŞLANGIÇ SERMAYESİ: bot davranışı normal/zor/kâbusta
    // birebir aynıdır; fark botların açılış parasında (zor ×1.5,
    // kâbus ×3 — açık kural, gelir hilesi yok). Kolay ayrı (yavaş bot).
    final goldMul = switch (difficulty) {
      Difficulty.hard => 1.5,
      Difficulty.nightmare => 5.0,
      _ => 1.0,
    };
    if (goldMul > 1) {
      for (final p in players) {
        if (p.isBot) p.resources = (p.resources * goldMul).round();
      }
    }
    _phase = GamePhase.playing;
    notifyListeners();
  }

  /// LAN maçı kurar. Her iki cihazda da AYNI parametrelerle çağrılır:
  /// host start yayınlarken, katılan start mesajını alınca. Oyuncular slot
  /// sırasıyla kurulur; bu cihaz [localSlot], diğer insanlar `remote`,
  /// boş slotlar bottur (botları YALNIZ host simüle eder).
  void startLanMatch({
    required MapDefinition map,
    required int seed,
    required int localSlot,
    required LanMode mode,
    required List<LanPlayerMeta> lanPlayers,
    LanHostService? host,
    LanClientService? client,
  }) {
    matchId++;
    tutorial = false;
    lastTutorial = false;
    mission = null;
    teamMode = mode == LanMode.teams2v2;
    this.map = map;
    lan = LanMatchConfig(
      seed: seed,
      localSlot: localSlot,
      mode: mode,
      players: List.of(lanPlayers)..sort((a, b) => a.slot.compareTo(b.slot)),
      host: host,
      client: client,
    );
    players.clear();
    for (final meta in lan!.players) {
      players.add(Player(
        id: meta.slot,
        team: meta.team,
        color: kTeamColors[meta.slot],
        isBot: meta.isBot,
        remote: !meta.isBot && meta.slot != localSlot,
        resources: kStartingResources,
      ));
    }
    _phase = GamePhase.playing;
    notifyListeners();
  }

  /// Son maçı aynı kurulumla yeniden başlatır (sefer bağlamı korunur).
  void restartLastMatch() {
    startMatch(
      playerCount: lastPlayerCount,
      map: lastMap,
      teamMode: lastTeamMode,
      enemyAlliance: lastEnemyAlliance,
      tutorial: lastTutorial,
      horde: lastHorde,
      mission: lastMission,
    );
  }

  void endMatch({required bool humanWon}) {
    _phase = humanWon ? GamePhase.victory : GamePhase.defeat;
    _recordHistory(humanWon);
    // Sefer görevi kazanıldıysa ilerlemeyi kalıcı işaretle.
    final m = mission;
    if (humanWon && m != null) {
      SharedPreferences.getInstance().then((p) {
        final key = 'campaign_${m.campaignKey}_progress';
        if ((p.getInt(key) ?? 0) < m.level) p.setInt(key, m.level);
      }).catchError((_) {});
    }
    notifyListeners();
  }

  /// Biten maçı MAÇ GEÇMİŞİNE yazar (istatistik sayfası buradan okur).
  void _recordHistory(bool humanWon) {
    final st = lastStats;
    final me = lastPlayerStats
        ?.where((r) => r.isHuman)
        .toList();
    final mode = tutorial
        ? 'tutorial'
        : horde
            ? 'horde'
            : mission != null
                ? 'mission'
                : lan != null
                    ? 'lan'
                    : teamMode
                        ? 'team'
                        : lastEnemyAlliance
                            ? 'alliance'
                            : 'solo';
    saveMatchRecord(MatchRecord(
      dateMs: DateTime.now().millisecondsSinceEpoch,
      mapId: map?.id ?? lastMap?.id ?? '?',
      mode: mode,
      won: humanWon,
      durationSec: (st?.duration ?? 0).round(),
      produced: st?.unitsProduced ??
          (me != null && me.isNotEmpty ? me.first.produced : 0),
      goldEarned: me != null && me.isNotEmpty ? me.first.goldEarned : 0,
      difficultyIndex: (mission?.difficulty ?? difficulty).index,
      score: horde ? (st?.duration ?? 0).round() : 0,
    ));
  }

  void backToMenu() {
    _phase = GamePhase.menu;
    players.clear();
    map = null;
    // LAN maçından çıkış: ağ servisleri kapanır (soketler serbest kalır).
    final l = lan;
    lan = null;
    l?.host?.dispose();
    l?.client?.dispose();
    notifyListeners();
  }
}
