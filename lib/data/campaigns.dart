import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_state.dart';
import '../models/building.dart';
import '../models/game_map.dart';
import 'abilities.dart';
import 'i18n.dart';

/// SEFER (hikâye modu) tanımları.
///
/// Üç sefer vardır: ATEŞ, BUZ ve ADALAR — her biri kolaydan zora 5 görev.
/// Bir görev, öncekisi tamamlanmadan AÇILMAZ; tamamlananlar istenildiği
/// zaman tekrar oynanabilir. İlerleme cihazda saklanır.
enum CampaignId { fire, ice, islands }

/// Bir sefer görevi. [map] null ise görev henüz tasarlanmamıştır
/// (sayfada yeri hazırdır, "yakında" der).
///
/// Kurallar: oyuncu yuvası haritanın İLK yuva noktasıdır; tüm düşman
/// botlar TEK takımdır (2v1/3v1); yetenekler görevde SABİTTİR.
class CampaignMission {
  const CampaignMission({
    required String title,
    this.titleEn = '',
    this.map,
    String brief = '',
    this.briefEn = '',
    this.loadout = const [AbilityType.lightning],
    this.difficulty = Difficulty.normal,
    this.gold = 100,
    this.ownedBuildings = const [],
    this.enemyGold,
  })  : titleTr = title,
        briefTr = brief;

  // İKİ DİL: TR alanları `title:`/`brief:` adıyla girilir; EN eklenir.
  final String titleTr;
  final String titleEn;
  final String briefTr;
  final String briefEn;
  String get title =>
      isEnglish && titleEn.isNotEmpty ? titleEn : titleTr;
  String get brief =>
      isEnglish && briefEn.isNotEmpty ? briefEn : briefTr;

  final MapDefinition? map;
  final List<AbilityType> loadout;
  final Difficulty difficulty;
  final int gold;
  final List<int> ownedBuildings;
  final int? enemyGold;

  MissionSetup setup(CampaignId id, int level) => MissionSetup(
        campaignKey: id.name,
        level: level,
        difficulty: difficulty,
        loadout: loadout,
        gold: gold,
        ownedBuildings: ownedBuildings,
        enemyGold: enemyGold,
      );
}

class CampaignDef {
  const CampaignDef({
    required this.id,
    required String name,
    this.nameEn = '',
    required String tagline,
    this.taglineEn = '',
    required this.accent,
    required this.missions,
  })  : nameTr = name,
        taglineTr = tagline;

  final CampaignId id;

  // İKİ DİL: TR alanları `name:`/`tagline:` adıyla girilir; EN eklenir.
  final String nameTr;
  final String nameEn;
  final String taglineTr;
  final String taglineEn;
  String get name => isEnglish && nameEn.isNotEmpty ? nameEn : nameTr;
  String get tagline =>
      isEnglish && taglineEn.isNotEmpty ? taglineEn : taglineTr;

  /// Seferin kimlik rengi (kart/rota vurguları).
  final Color accent;

  final List<CampaignMission> missions; // 5 görev, kolay → zor
}


/// ATEŞ SEFERİ görev haritaları (kolay → zor). allMaps DIŞINDADIR.
/// İLK yuva noktası OYUNCUNUNDUR; kalanlar tek takım düşman botlardır.
final List<MapDefinition> fireMissionMaps = [
  // 1 — Kıvılcım: köprüsüz açık ova, tanışma savaşı (1v1 kolay).
  MapDefinition(
    id: 'fire_m1',
    theme: MapTheme.scorched,
    name: 'Kıvılcım Ovası',
    nameEn: 'Spark Plains',
    playerCount: 2,
    features: [
      TerrainFeature(TerrainKind.rock, [Vector2(340, 210)], 40),
      TerrainFeature(TerrainKind.rock, [Vector2(930, 510)], 40),
      TerrainFeature(
          TerrainKind.root, [Vector2(-10, 640), Vector2(200, 690)], 22),
    ],
    nestSpots: [Vector2(170, 360), Vector2(1110, 360)],
    buildingSpots: [
      Vector2(400, 300),
      Vector2(880, 420),
      Vector2(640, 180),
    ],
    buildingTypes: [
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 2 — Kül Vadisi: iki kül sırtı, ortada tek geçit ve bekçi kule.
  MapDefinition(
    id: 'fire_m2',
    theme: MapTheme.scorched,
    name: 'Kül Vadisi',
    nameEn: 'Ash Valley',
    playerCount: 2,
    features: [
      TerrainFeature(
          TerrainKind.root, [Vector2(-10, 240), Vector2(520, 250)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(760, 470), Vector2(1290, 480)], 26),
      TerrainFeature(TerrainKind.rock, [Vector2(640, 110)], 46),
      TerrainFeature(TerrainKind.rock, [Vector2(640, 610)], 46),
      TerrainFeature(TerrainKind.rock, [Vector2(200, 600)], 34),
      TerrainFeature(TerrainKind.rock, [Vector2(1080, 120)], 34),
      // KÜL ÇAMURU: geçidin doğu yaklaşımı bataklık — düşman dalgası
      // kuleye yavaş girer.
      TerrainFeature(TerrainKind.swamp,
          [Vector2(700, 300), Vector2(820, 270)], 56),
    ],
    nestSpots: [Vector2(150, 360), Vector2(1130, 360)],
    buildingSpots: [
      Vector2(640, 360), // geçit bekçisi kule
      Vector2(330, 140),
      Vector2(950, 580),
      Vector2(640, 560),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 3 — Lav Nehri: tek köprü, doğuda İKİ düşman (2v1); batı kule OYUNCUNUN.
  MapDefinition(
    id: 'fire_m3',
    theme: MapTheme.scorched,
    name: 'Lav Nehri',
    nameEn: 'Lava River',
    playerCount: 3,
    features: [
      TerrainFeature(TerrainKind.water, [
        Vector2(620, -30),
        Vector2(662, 180),
        Vector2(612, 400),
        Vector2(645, 750),
      ], 66),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(540, 360), Vector2(730, 360)], 54),
      TerrainFeature(TerrainKind.rock, [Vector2(350, 120)], 36),
      TerrainFeature(TerrainKind.rock, [Vector2(880, 660)], 36),
      // Kor eşekarısı yuvası: doğu yakasında iki düşmanın buluşma
      // koridoru arılı — kim geçerse bedel öder.
      TerrainFeature(TerrainKind.waspNest, [Vector2(880, 250)], 32),
    ],
    nestSpots: [
      Vector2(150, 360),
      Vector2(1110, 170),
      Vector2(1110, 550),
    ],
    buildingSpots: [
      Vector2(490, 360), // batı köprübaşı — GÖREVDE OYUNCUNUN
      Vector2(810, 360), // doğu köprübaşı
      Vector2(300, 210),
      Vector2(960, 140),
      Vector2(960, 580),
      Vector2(450, 550),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 4 — Kor Kuşatması: kuzeyden ÜÇ düşman (3v1); iki kule OYUNCUNUN.
  MapDefinition(
    id: 'fire_m4',
    theme: MapTheme.scorched,
    name: 'Kor Kuşatması',
    nameEn: 'Ember Siege',
    playerCount: 4,
    features: [
      TerrainFeature(TerrainKind.rock, [Vector2(250, 450)], 38),
      TerrainFeature(TerrainKind.rock, [Vector2(1030, 450)], 38),
      TerrainFeature(
          TerrainKind.root, [Vector2(-10, 620), Vector2(180, 680)], 22),
      TerrainFeature(
          TerrainKind.root, [Vector2(1290, 620), Vector2(1100, 680)], 22),
      // KÜL ÇAMURU HATTI: kuzeyden inen üç ordu, kulelerin önündeki
      // bataklıkta yavaşlar — savunma hattının can simidi.
      TerrainFeature(TerrainKind.swamp,
          [Vector2(520, 395), Vector2(760, 395)], 54),
    ],
    nestSpots: [
      Vector2(640, 590),
      Vector2(160, 140),
      Vector2(1120, 140),
      Vector2(640, 110),
    ],
    buildingSpots: [
      Vector2(480, 470), // OYUNCUNUN kulesi (sol kanat)
      Vector2(800, 470), // OYUNCUNUN kulesi (sağ kanat)
      Vector2(500, 655),
      Vector2(300, 220),
      Vector2(980, 220),
      Vector2(640, 320), // çekişmeli güç
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 5 — Volkanın Kalbi: merkez volkan kütlesi, ÜÇ ZORLU düşman (3v1 hard).
  MapDefinition(
    id: 'fire_m5',
    theme: MapTheme.scorched,
    name: 'Volkanın Kalbi',
    nameEn: 'Heart of the Volcano',
    playerCount: 4,
    features: [
      TerrainFeature(TerrainKind.rock, [Vector2(640, 330)], 56),
      TerrainFeature(TerrainKind.rock, [Vector2(540, 255)], 40),
      TerrainFeature(TerrainKind.rock, [Vector2(740, 255)], 40),
      TerrainFeature(
          TerrainKind.root, [Vector2(340, -10), Vector2(430, 150)], 24),
      TerrainFeature(
          TerrainKind.root, [Vector2(940, -10), Vector2(850, 150)], 24),
      // Kor eşekarısı yuvaları: volkanın iki yanı arılı — merkeze
      // sarkan her ordu (düşman dahil) sokulur.
      TerrainFeature(TerrainKind.waspNest, [Vector2(450, 330)], 32),
      TerrainFeature(TerrainKind.waspNest, [Vector2(830, 330)], 32),
    ],
    nestSpots: [
      Vector2(640, 610),
      Vector2(150, 140),
      Vector2(1130, 140),
      Vector2(640, 130),
    ],
    buildingSpots: [
      Vector2(520, 520), // OYUNCUNUN kulesi
      Vector2(760, 520), // OYUNCUNUN kulesi
      Vector2(640, 430), // volkanın eteği: çekişmeli güç
      Vector2(250, 330),
      Vector2(1030, 330),
      Vector2(450, 660),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.power,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
    ],
  ),
];


/// BUZ SEFERİ görev haritaları (kolay → zor, tema: kar/buz).
final List<MapDefinition> iceMissionMaps = [
  // 1 — Buz Çatlağı: karlı açık ova + donmuş gölcük (1v1 kolay).
  MapDefinition(
    id: 'ice_m1',
    name: 'Buz Çatlağı',
    nameEn: 'Ice Crevasse',
    playerCount: 2,
    theme: MapTheme.snow,
    features: [
      TerrainFeature(TerrainKind.water, [Vector2(860, 200)], 110),
      TerrainFeature(TerrainKind.rock, [Vector2(350, 520)], 40),
      TerrainFeature(
          TerrainKind.root, [Vector2(-10, 640), Vector2(210, 690)], 22),
    ],
    nestSpots: [Vector2(170, 360), Vector2(1110, 360)],
    buildingSpots: [
      Vector2(410, 300),
      Vector2(880, 430),
      Vector2(640, 170),
    ],
    buildingTypes: [
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 2 — Donmuş Göl: merkezde BÜYÜK buz gölü, çevresinde dolaşarak savaş.
  MapDefinition(
    id: 'ice_m2',
    name: 'Donmuş Göl',
    nameEn: 'Frozen Lake',
    playerCount: 2,
    theme: MapTheme.snow,
    features: [
      TerrainFeature(TerrainKind.water, [Vector2(640, 360)], 300),
      TerrainFeature(TerrainKind.rock, [Vector2(300, 130)], 38),
      TerrainFeature(TerrainKind.rock, [Vector2(980, 590)], 38),
      // BUZ KÖPRÜSÜ: gölün ortasından geçen donmuş yol — gölü DÜZ
      // geçersin ama iki ucu da pusuya açıktır.
      TerrainFeature(
          TerrainKind.bridge, [Vector2(485, 360), Vector2(795, 360)], 50),
    ],
    nestSpots: [Vector2(150, 360), Vector2(1130, 360)],
    buildingSpots: [
      Vector2(640, 120),
      Vector2(300, 250),
      Vector2(980, 470),
      Vector2(640, 600),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 3 — Tipi: dağ sıraları görüşü kapatır; doğuda İKİ düşman (2v1).
  MapDefinition(
    id: 'ice_m3',
    name: 'Tipi',
    nameEn: 'Blizzard',
    playerCount: 3,
    theme: MapTheme.snow,
    features: [
      TerrainFeature(
          TerrainKind.root, [Vector2(-10, 230), Vector2(430, 260)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(850, 460), Vector2(1290, 430)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(560, -10), Vector2(590, 170)], 24),
      TerrainFeature(TerrainKind.rock, [Vector2(250, 560)], 40),
      TerrainFeature(TerrainKind.rock, [Vector2(1020, 170)], 40),
      // SULU KAR BATAKLIĞI: geçidin doğusu lapa kar — iki düşmanın
      // ortak hücum koridoru yavaşlar.
      TerrainFeature(TerrainKind.swamp,
          [Vector2(760, 300), Vector2(880, 330)], 58),
    ],
    nestSpots: [
      Vector2(150, 360),
      Vector2(1110, 170),
      Vector2(1110, 550),
    ],
    buildingSpots: [
      Vector2(620, 360), // merkez geçit — GÖREVDE OYUNCUNUN
      Vector2(300, 170),
      Vector2(300, 540),
      Vector2(960, 360),
      Vector2(760, 190),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 4 — Buzul Boğazı: iki buzul duvarı arasında dar koridor; ÜÇ düşman.
  MapDefinition(
    id: 'ice_m4',
    name: 'Buzul Boğazı',
    nameEn: 'Glacier Strait',
    playerCount: 4,
    theme: MapTheme.snow,
    features: [
      // Buzul duvarları: her ikisinin ortasında KAZILABİLİR buz tıkacı —
      // kazan taraf boğazı by-pass eden bir yan geçit açar.
      TerrainFeature(
          TerrainKind.root, [Vector2(430, -10), Vector2(443, 190)], 26),
      TerrainFeature(
          TerrainKind.digsite, [Vector2(443, 190), Vector2(450, 290)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(450, 290), Vector2(460, 470)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(830, -10), Vector2(817, 190)], 26),
      TerrainFeature(
          TerrainKind.digsite, [Vector2(817, 190), Vector2(810, 290)], 26),
      TerrainFeature(
          TerrainKind.root, [Vector2(810, 290), Vector2(800, 470)], 26),
      TerrainFeature(TerrainKind.rock, [Vector2(250, 560)], 38),
      TerrainFeature(TerrainKind.rock, [Vector2(1030, 560)], 38),
    ],
    nestSpots: [
      Vector2(640, 600),
      Vector2(170, 140),
      Vector2(640, 110),
      Vector2(1110, 140),
    ],
    buildingSpots: [
      Vector2(540, 470), // boğaz ağzı — OYUNCUNUN
      Vector2(740, 470), // boğaz ağzı — OYUNCUNUN
      Vector2(450, 640),
      Vector2(180, 320),
      Vector2(1100, 320),
      Vector2(640, 300), // boğaz içi çekişmeli güç
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 5 — Kutup Tahtı: donmuş gölün güneyindeki TAHT (güç) uğruna final.
  MapDefinition(
    id: 'ice_m5',
    name: 'Kutup Tahtı',
    nameEn: 'Polar Throne',
    playerCount: 4,
    theme: MapTheme.snow,
    features: [
      TerrainFeature(TerrainKind.water, [Vector2(640, 320)], 260),
      TerrainFeature(
          TerrainKind.root, [Vector2(340, -10), Vector2(430, 150)], 24),
      TerrainFeature(
          TerrainKind.root, [Vector2(940, -10), Vector2(850, 150)], 24),
      TerrainFeature(TerrainKind.rock, [Vector2(220, 500)], 40),
      TerrainFeature(TerrainKind.rock, [Vector2(1060, 500)], 40),
      // Kutup eşekarısı yuvaları: köşe düşmanlarının taht'a inen
      // kestirmeleri arılı — dalgalar tahta yorgun varır.
      TerrainFeature(TerrainKind.waspNest, [Vector2(250, 220)], 32),
      TerrainFeature(TerrainKind.waspNest, [Vector2(1030, 220)], 32),
    ],
    nestSpots: [
      Vector2(640, 610),
      Vector2(150, 140),
      Vector2(1130, 140),
      Vector2(640, 120),
    ],
    buildingSpots: [
      Vector2(500, 540), // OYUNCUNUN kulesi
      Vector2(780, 540), // OYUNCUNUN kulesi
      Vector2(640, 480), // KUTUP TAHTI: göl kıyısında güç
      Vector2(250, 350),
      Vector2(1030, 350),
      Vector2(450, 660),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.power,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
    ],
  ),
];


/// ADA SEFERİ görev haritaları (kolay → zor, konsept: su + köprü savaşları).
final List<MapDefinition> islandMissionMaps = [
  // 1 — Sığ Sular: iki yaka, TEK köprü (1v1 kolay).
  MapDefinition(
    id: 'isl_m1',
    name: 'Sığ Sular',
    nameEn: 'Shallow Waters',
    playerCount: 2,
    features: [
      TerrainFeature(TerrainKind.water, [
        Vector2(625, -30),
        Vector2(660, 190),
        Vector2(618, 400),
        Vector2(648, 750),
      ], 70),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(545, 360), Vector2(735, 360)], 54),
      TerrainFeature(TerrainKind.rock, [Vector2(340, 180)], 36),
      TerrainFeature(TerrainKind.rock, [Vector2(930, 540)], 36),
      // SIĞ SULAR (adı buradan!): kuzeyde sığlıkta kurulmuş İKİNCİ
      // köprü — tek boğaza mahkûm değilsin.
      TerrainFeature(
          TerrainKind.bridge, [Vector2(565, 160), Vector2(745, 170)], 46),
    ],
    nestSpots: [Vector2(170, 360), Vector2(1110, 360)],
    buildingSpots: [
      Vector2(350, 300),
      Vector2(930, 420),
      Vector2(450, 140),
    ],
    buildingTypes: [
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 2 — Mercan Yolu: İKİ kanal, çapraz köprüler — orta şerit değerli.
  MapDefinition(
    id: 'isl_m2',
    name: 'Mercan Yolu',
    nameEn: 'Coral Road',
    playerCount: 2,
    features: [
      TerrainFeature(TerrainKind.water, [
        Vector2(445, -30),
        Vector2(415, 250),
        Vector2(450, 520),
        Vector2(425, 750),
      ], 70),
      TerrainFeature(TerrainKind.water, [
        Vector2(835, -30),
        Vector2(865, 220),
        Vector2(828, 500),
        Vector2(858, 750),
      ], 70),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(340, 200), Vector2(525, 200)], 54),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(750, 520), Vector2(935, 520)], 54),
      TerrainFeature(TerrainKind.rock, [Vector2(640, 640)], 38),
      TerrainFeature(TerrainKind.rock, [Vector2(640, 80)], 38),
    ],
    nestSpots: [Vector2(150, 360), Vector2(1130, 360)],
    buildingSpots: [
      Vector2(520, 280), // batı köprü çıkışı bekçisi
      Vector2(760, 440), // doğu köprü girişi bekçisi
      Vector2(640, 360), // orta şeridin kalbi: güç
      Vector2(250, 500),
      Vector2(1030, 220),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.power,
      BuildingType.resource,
      BuildingType.resource,
    ],
  ),
  // 3 — Orta Köprü: kuzeyde İKİ düşman, üç köprü — güney kule OYUNCUNUN.
  MapDefinition(
    id: 'isl_m3',
    name: 'Orta Köprü',
    nameEn: 'The Middle Bridge',
    playerCount: 3,
    features: [
      TerrainFeature(TerrainKind.water, [
        Vector2(-30, 350),
        Vector2(320, 375),
        Vector2(640, 345),
        Vector2(960, 380),
        Vector2(1310, 355),
      ], 66),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(400, 285), Vector2(400, 445)], 54),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(880, 285), Vector2(880, 445)], 54),
      TerrainFeature(TerrainKind.rock, [Vector2(640, 540)], 40),
      TerrainFeature(TerrainKind.rock, [Vector2(150, 160)], 36),
      // ORTA KÖPRÜ (adı buradan!): boğazın tam ortasında ÜÇÜNCÜ yol —
      // üç köprüyü birden tutmak zorundasın.
      TerrainFeature(
          TerrainKind.bridge, [Vector2(640, 290), Vector2(640, 430)], 46),
    ],
    nestSpots: [
      Vector2(640, 600),
      Vector2(300, 140),
      Vector2(980, 140),
    ],
    buildingSpots: [
      Vector2(400, 490), // güney köprübaşı — GÖREVDE OYUNCUNUN
      Vector2(880, 490), // güney köprübaşı
      Vector2(500, 650),
      Vector2(300, 250),
      Vector2(980, 250),
      Vector2(640, 220), // kuzey orta: çekişmeli güç
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
    ],
  ),
  // 4 — Fırtına Takımadaları: merkez HUB adasında DÜŞMAN kolonisi (3v1).
  MapDefinition(
    id: 'isl_m4',
    name: 'Fırtına Takımadaları',
    nameEn: 'Storm Archipelago',
    playerCount: 4,
    features: [
      TerrainFeature(TerrainKind.water, _atolRing(640, 360, 200, 20), 100),
      TerrainFeature(TerrainKind.water,
          [Vector2(640, 180), Vector2(610, 60), Vector2(665, -80)], 100),
      TerrainFeature(TerrainKind.water, [
        Vector2(470, 360),
        Vector2(290, 335),
        Vector2(110, 385),
        Vector2(-80, 360),
      ], 100),
      TerrainFeature(TerrainKind.water, [
        Vector2(810, 360),
        Vector2(990, 385),
        Vector2(1170, 335),
        Vector2(1360, 360),
      ], 100),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(548, 268), Vector2(449, 169)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(732, 268), Vector2(831, 169)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(640, 490), Vector2(640, 615)], 46),
      TerrainFeature(TerrainKind.rock, [Vector2(300, 480)], 34),
      TerrainFeature(TerrainKind.rock, [Vector2(980, 480)], 34),
    ],
    nestSpots: [
      Vector2(745, 655), // OYUNCU: güney adası
      Vector2(220, 170), // NW düşman
      Vector2(1060, 170), // NE düşman
      Vector2(640, 330), // HUB DÜŞMANI: merkez adada!
    ],
    buildingSpots: [
      Vector2(585, 645), // güney köprü bekçisi — OYUNCUNUN
      Vector2(450, 120),
      Vector2(830, 120),
      Vector2(300, 95),
      Vector2(980, 95),
      Vector2(330, 650),
      Vector2(700, 410), // hub ödülü: güç (düşmanın dibinde)
      // KULUÇKA İSTASYONU: oyuncu adasının batısında ikinci çıkış —
      // hub kuşatmasına asker buradan iner.
      Vector2(460, 600),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.power,
      BuildingType.hatchery,
    ],
  ),
  // 5 — Büyük Atol: dört köşe adası + hub; ÜÇ ZORLU düşman (3v1 hard).
  MapDefinition(
    id: 'isl_m5',
    name: 'Büyük Atol',
    nameEn: 'The Great Atoll',
    playerCount: 4,
    features: [
      TerrainFeature(TerrainKind.water, _atolRing(640, 360, 200, 20), 100),
      TerrainFeature(TerrainKind.water,
          [Vector2(640, 180), Vector2(615, 40), Vector2(665, -80)], 100),
      TerrainFeature(TerrainKind.water,
          [Vector2(640, 540), Vector2(668, 660), Vector2(615, 800)], 100),
      TerrainFeature(TerrainKind.water, [
        Vector2(470, 360),
        Vector2(290, 335),
        Vector2(110, 385),
        Vector2(-80, 360),
      ], 100),
      TerrainFeature(TerrainKind.water, [
        Vector2(810, 360),
        Vector2(990, 385),
        Vector2(1170, 335),
        Vector2(1360, 360),
      ], 100),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(548, 268), Vector2(449, 169)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(732, 268), Vector2(831, 169)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(548, 452), Vector2(449, 551)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(732, 452), Vector2(831, 551)], 46),
      TerrainFeature(TerrainKind.rock, [Vector2(250, 260)], 30),
      TerrainFeature(TerrainKind.rock, [Vector2(1030, 260)], 30),
      TerrainFeature(TerrainKind.rock, [Vector2(250, 460)], 30),
      TerrainFeature(TerrainKind.rock, [Vector2(1030, 460)], 30),
      // DIŞ KÖPRÜLER: kuzey ve güney moatlarında — atolün finali her
      // yönden savunma ister.
      TerrainFeature(
          TerrainKind.bridge, [Vector2(560, 70), Vector2(720, 70)], 46),
      TerrainFeature(
          TerrainKind.bridge, [Vector2(560, 650), Vector2(720, 650)], 46),
    ],
    nestSpots: [
      Vector2(170, 590), // OYUNCU: güneybatı adası
      Vector2(170, 130),
      Vector2(1110, 130),
      Vector2(1110, 590),
    ],
    buildingSpots: [
      Vector2(410, 600), // SW köprü bekçisi — OYUNCUNUN
      Vector2(350, 560), // SW ekonomi — OYUNCUNUN
      Vector2(640, 360), // HUB: büyük ödül güç
      Vector2(350, 160),
      Vector2(930, 160),
      Vector2(930, 560),
      Vector2(410, 120),
      Vector2(870, 120),
      Vector2(870, 600),
    ],
    buildingTypes: [
      BuildingType.tower,
      BuildingType.resource,
      BuildingType.power,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.resource,
      BuildingType.tower,
      BuildingType.tower,
      BuildingType.tower,
    ],
  ),
];

/// Atol halkası noktaları (maps.dart'taki _ringPoints ile aynı mantık).
List<Vector2> _atolRing(double cx, double cy, double r, int n) => [
      for (var i = 0; i <= n; i++)
        Vector2(
          cx + r * math.cos(i / n * 2 * math.pi),
          cy + r * math.sin(i / n * 2 * math.pi),
        ),
    ];

final List<CampaignDef> campaigns = [
  CampaignDef(
    id: CampaignId.fire,
    name: 'Ateş Seferi',
    nameEn: 'Fire Campaign',
    tagline: 'Volkanın gölgesinde yak ve ilerle',
    taglineEn: "Burn and advance in the volcano's shadow",
    accent: Color(0xFFE8683C),
    missions: [
      CampaignMission(
        title: 'Kıvılcım',
        titleEn: 'Spark',
        map: fireMissionMaps[0],
        brief: 'İlk kıvılcımı çak: asker üret, yakındaki çiftliği kap ve '
            'düşman kraliçesini yak. Elinde ATEŞ ÇEMBERİ var — köprüsüz '
            'bu ovada düşman ordusunu halkaya hapset.',
        briefEn:
            'Strike the first spark: train soldiers, capture the nearby '
            'farm and burn the enemy queen. You carry RING OF FIRE — trap '
            'the enemy army in flames on this open, bridgeless plain.',
        loadout: [AbilityType.fireRing],
        difficulty: Difficulty.easy,
        gold: 150,
      ),
      CampaignMission(
        title: 'Kül Vadisi',
        titleEn: 'Ash Valley',
        map: fireMissionMaps[1],
        brief: 'Kül tepeleri vadiyi ikiye bölüyor; ortadaki NÖTR KULE tek '
            'geçidi tutuyor. Kuleyi erken kapan vadiye hükmeder. '
            'Savaş Çılgınlığı ile kuşatmayı hızlandır.',
        briefEn:
            'Ash ridges split the valley; the NEUTRAL TOWER in the middle '
            'holds the only pass. Whoever takes it early rules the valley. '
            'Speed the siege with Battle Frenzy.',
        loadout: [AbilityType.fireRing, AbilityType.battleFrenzy],
        gold: 120,
      ),
      CampaignMission(
        title: 'Lav Nehri',
        titleEn: 'Lava River',
        map: fireMissionMaps[2],
        brief: 'İKİ düşman kolonisi nehrin doğusunda! Tek köprünün BATI '
            'başındaki kule SENİN — onu tut, zehir bulutuyla köprüyü '
            'kilitle ve rakipleri tek tek yok et.',
        briefEn:
            'TWO enemy colonies sit east of the river! The tower at the '
            'WESTERN end of the only bridge is YOURS — hold it, lock the '
            'bridge with Poison Cloud and destroy the rivals one by one.',
        loadout: [AbilityType.fireRing, AbilityType.poisonCloud],
        gold: 150,
        ownedBuildings: [0],
      ),
      CampaignMission(
        title: 'Kor Kuşatması',
        titleEn: 'Ember Siege',
        map: fireMissionMaps[3],
        brief: 'ÜÇ koloni seni kuzeyden kıskaca aldı. İKİ kulen ve zırh '
            'feromonunla hattı tut; yıldırımla dalgaları kır, sonra tek '
            'tek söndür.',
        briefEn:
            'THREE colonies squeeze you from the north. Hold the line with '
            'your TWO towers and Armor Pheromone; break the waves with '
            'Lightning, then snuff them out one by one.',
        loadout: [
          AbilityType.fireRing,
          AbilityType.armorPheromone,
          AbilityType.lightning,
        ],
        gold: 250,
        ownedBuildings: [0, 1],
      ),
      CampaignMission(
        title: 'Volkanın Kalbi',
        titleEn: 'Heart of the Volcano',
        map: fireMissionMaps[4],
        brief: 'Son sınav: volkanın kalbinde ÜÇ ZORLU koloni ve dolu '
            'kasaları. Kulelerin ardında güçlen, DONDUR, yak ve '
            'yıldırımla bitir. Ateş Seferi burada taçlanır.',
        briefEn:
            'The final test: THREE HARD colonies with full coffers at the '
            'volcano\'s heart. Grow strong behind your towers, FREEZE, burn, '
            'and finish with Lightning. The Fire Campaign is crowned here.',
        loadout: [
          AbilityType.fireRing,
          AbilityType.freeze,
          AbilityType.lightning,
        ],
        difficulty: Difficulty.hard,
        gold: 300,
        ownedBuildings: [0, 1],
        enemyGold: 220,
      ),
    ],
  ),
  CampaignDef(
    id: CampaignId.ice,
    name: 'Buz Seferi',
    nameEn: 'Ice Campaign',
    tagline: 'Donmuş vadilerde soğukkanlı savaş',
    taglineEn: 'Cold-blooded war in frozen valleys',
    accent: const Color(0xFF8FCBE8),
    missions: [
      CampaignMission(
        title: 'Buz Çatlağı',
        titleEn: 'Ice Crevasse',
        map: iceMissionMaps[0],
        brief: 'Karlı ovada ilk sınav: çiftlikleri kap, orduyu büyüt. '
            'DONDURMA elinde — düşman dalgasını buz tutup tek tek kır.',
        briefEn:
            'First trial on the snowy plain: capture the farms, grow your '
            'army. FREEZE is in your hands — ice the enemy wave and break '
            'it piece by piece.',
        loadout: const [AbilityType.freeze],
        difficulty: Difficulty.easy,
        gold: 150,
      ),
      CampaignMission(
        title: 'Donmuş Göl',
        titleEn: 'Frozen Lake',
        map: iceMissionMaps[1],
        brief: 'Devasa donmuş göl haritayı ikiye böler — ama gölün ortası '
            'ara ara BUZ TUTAR: yol açılınca düz geç, kapanmadan kıyıya '
            'çık! Orduları DONDUR, yaralıları İYİLEŞTİR.',
        briefEn:
            'A giant frozen lake splits the map — but its center FREEZES '
            'OVER now and then: cross when the path opens, reach the shore '
            'before it closes! FREEZE armies, HEAL the wounded.',
        loadout: const [AbilityType.freeze, AbilityType.heal],
        gold: 120,
      ),
      CampaignMission(
        title: 'Tipi',
        titleEn: 'Blizzard',
        map: iceMissionMaps[2],
        brief: 'Tipi görüşü kapatıyor, dağ sıraları yolu bölüyor — ve '
            'doğuda İKİ düşman var. Merkez geçidin kulesi SENİN: Zırh '
            'Feromonu ile hattı tut, donan düşmanı geçit önünde ez.',
        briefEn:
            'The blizzard blinds, mountain ridges split the roads — and TWO '
            'enemies wait in the east. The pass tower is YOURS: hold the '
            'line with Armor Pheromone and crush frozen foes at the gate.',
        loadout: const [AbilityType.freeze, AbilityType.armorPheromone],
        gold: 150,
        ownedBuildings: const [0],
      ),
      CampaignMission(
        title: 'Buzul Boğazı',
        titleEn: 'Glacier Strait',
        map: iceMissionMaps[3],
        brief: 'İki buzul duvarı arasındaki dar boğaz — kuzeyde ÜÇ koloni. '
            'Boğaz ağzındaki İKİ kulen var: dalgaları DONDUR, Korku '
            'Çığlığıyla dağıt, yıldırımla bitir.',
        briefEn:
            'A narrow strait between two glacier walls — THREE colonies to '
            'the north. Your TWO towers guard its mouth: FREEZE the waves, '
            'scatter them with Fear Scream, finish with Lightning.',
        loadout: const [
          AbilityType.freeze,
          AbilityType.fearScream,
          AbilityType.lightning,
        ],
        gold: 250,
        ownedBuildings: const [0, 1],
      ),
      CampaignMission(
        title: 'Kutup Tahtı',
        titleEn: 'Polar Throne',
        map: iceMissionMaps[4],
        brief: 'Son durak: donmuş gölün kıyısındaki KUTUP TAHTI. Üç zorlu '
            'koloni dolu kasalarla taht için geliyor. Kulelerinin ardında '
            'güçlen — tahtı al, buz hükümdarı ol.',
        briefEn:
            'The last stop: the POLAR THRONE on the frozen lake\'s shore. '
            'Three hard colonies march on it with full coffers. Grow strong '
            'behind your towers — take the throne, become the monarch of '
            'ice.',
        loadout: const [
          AbilityType.freeze,
          AbilityType.armorPheromone,
          AbilityType.lightning,
        ],
        difficulty: Difficulty.hard,
        gold: 300,
        ownedBuildings: const [0, 1],
        enemyGold: 220,
      ),
    ],
  ),
  CampaignDef(
    id: CampaignId.islands,
    name: 'Ada Seferi',
    nameEn: 'Island Campaign',
    tagline: 'Küçük adalarda köprü savaşları',
    taglineEn: 'Bridge wars across tiny islands',
    accent: const Color(0xFF4FB6A5),
    missions: [
      CampaignMission(
        title: 'Sığ Sular',
        titleEn: 'Shallow Waters',
        map: islandMissionMaps[0],
        brief: 'İki yakayı iki köprü bağlıyor: güneyde ana boğaz, kuzeyde '
            'sığlıkta kurulmuş İNCE köprü. Rakip ikisini birden tutamaz — '
            'TAKVİYE gücünle köprübaşına asker indir, karşı yakayı söndür.',
        briefEn:
            'Two bridges link the shores: the main strait in the south and '
            'a slim one built on the northern shallows. Your rival cannot '
            'hold both. Land soldiers at the bridgehead with REINFORCE '
            'and snuff out the far shore.',
        loadout: const [AbilityType.reinforce],
        difficulty: Difficulty.easy,
        gold: 150,
      ),
      CampaignMission(
        title: 'Mercan Yolu',
        titleEn: 'Coral Road',
        map: islandMissionMaps[1],
        brief: 'İki kanal, çapraz iki köprü — ortadaki mercan şeridi kim '
            'tutarsa oyunu o yönetir. Hız Feromonuyla köprüden köprüye '
            'koş, takviyeyle boşlukları kapat.',
        briefEn:
            'Two channels, two crossing bridges — whoever holds the coral '
            'strip in the middle runs the game. Dash bridge to bridge with '
            'Speed Pheromone, plug the gaps with Reinforce.',
        loadout: const [AbilityType.reinforce, AbilityType.speedPheromone],
        gold: 120,
      ),
      CampaignMission(
        title: 'Orta Köprü',
        titleEn: 'The Tide',
        map: islandMissionMaps[2],
        brief: 'Kuzey kıyıda İKİ düşman; boğazda ÜÇ köprü — ortadaki en '
            'kısa yol ama iki ateş arasında. Yağmurla savun, takviyeyle '
            'çıkarma yap, köprüleri tek tek kopar.',
        briefEn:
            'TWO enemies on the northern shore; THREE bridges over the '
            'strait — the middle one is the shortest road but sits between '
            'two fires. Defend with Rain, land with Reinforce, and cut the '
            'bridges one by one.',
        loadout: const [AbilityType.reinforce, AbilityType.rain],
        gold: 150,
        ownedBuildings: const [0],
      ),
      CampaignMission(
        title: 'Fırtına Takımadaları',
        titleEn: 'Storm Archipelago',
        map: islandMissionMaps[3],
        brief: 'Merkez adaya bir koloni YERLEŞMİŞ; iki müttefiki kuzeyden '
            'destek veriyor. Bekçi kulen ve adandaki KULUÇKA İSTASYONU '
            'senin olursa askerler cepheye oradan iner. Korku Çığlığıyla '
            'hub çıkarmasını dağıt.',
        briefEn:
            'A colony has SETTLED on the central island; two allies support '
            'it from the north. Take the guard tower and the island\'s '
            'HATCHERY and your soldiers deploy straight to the front. '
            'Scatter the hub landing with Fear Scream.',
        loadout: const [
          AbilityType.reinforce,
          AbilityType.rain,
          AbilityType.fearScream,
        ],
        gold: 250,
        ownedBuildings: const [0],
      ),
      CampaignMission(
        title: 'Büyük Atol',
        titleEn: 'The Great Atoll',
        map: islandMissionMaps[4],
        brief: 'Ada Seferi\'nin tacı: dört köşe adası, ortada BÜYÜK ATOL. '
            'Üç zorlu koloni dolu kasalarla hub için yarışıyor. Kulen ve '
            'çiftliğin hazır — DONDUR, yak ve atolü fethet.',
        briefEn:
            'The crown of the Island Campaign: four corner islands, the '
            'GREAT ATOLL in the middle. Three hard colonies race for the '
            'hub with full coffers. Your tower and farm stand ready — '
            'FREEZE, burn, conquer the atoll.',
        loadout: const [
          AbilityType.reinforce,
          AbilityType.freeze,
          AbilityType.lightning,
        ],
        difficulty: Difficulty.hard,
        gold: 300,
        ownedBuildings: const [0, 1],
        enemyGold: 220,
      ),
    ],
  ),
];

String _progressKey(CampaignId id) => 'campaign_${id.name}_progress';

/// Tamamlanan görev sayısı (0..5). N tamamlandıysa N+1. görev açıktır.
Future<int> loadCampaignProgress(CampaignId id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_progressKey(id)) ?? 0).clamp(0, 5);
  } catch (_) {
    return 0;
  }
}

/// [completedLevel] (1..5) tamamlandı olarak işaretlenir (geri gitmez).
Future<void> saveCampaignProgress(CampaignId id, int completedLevel) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getInt(_progressKey(id)) ?? 0;
    if (completedLevel > cur) {
      await prefs.setInt(_progressKey(id), completedLevel.clamp(0, 5));
    }
  } catch (_) {}
}
