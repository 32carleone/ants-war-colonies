import 'dart:math' as math;

import 'package:flame/components.dart';

import '../models/building.dart';
import '../models/game_map.dart';

/// Tüm haritalar (Savaş Kur ekranı bu listeyi gösterir).
final List<MapDefinition> allMaps = [
  riverCrossing,
  himalayaPasses,
  redSeaShallows,
  saltLakeFlats,
  marmaraIsles,
  incaTrail,
  rootTriangle,
  threeIslands,
  nileDelta,
  cappadociaCorridors,
  fourCorners,
  fourIslands,
  panamaPass,
  grandCanyon,
  okavangoDelta,
  kilimanjaroHighlands,
  halongBays,
];

/// Oyuncu sayısına uyan haritalar.
List<MapDefinition> mapsForPlayers(int playerCount) =>
    allMaps.where((m) => m.playerCount == playerCount).toList();

/// Oyuncu sayısı için varsayılan harita (geriye dönük uyumluluk).
MapDefinition mapForPlayers(int playerCount) {
  final list = mapsForPlayers(playerCount);
  if (list.isEmpty) {
    throw ArgumentError('Desteklenmeyen oyuncu sayısı: $playerCount');
  }
  return list.first;
}

/// 2 KİŞİLİK (1v1) — "Amazon Geçidi"
/// Ortadan kıvrılarak akan nehir, biri kuzeyde biri güneyde iki köprü.
/// Stratejik yerleşim: kuleler KÖPRÜ ÇIKIŞLARINI tutar, kaynaklar yuvalara
/// yakın (ekonomi), güç binaları nehir kıyısında çekişmeli.
final MapDefinition riverCrossing = MapDefinition(
  id: 'river_crossing',
  name: 'Amazon Geçidi',
  nameEn: 'Amazon Crossing',
  playerCount: 2,
  features: [
    // Nehir: kuzeyden güneye S kıvrımı.
    TerrainFeature(TerrainKind.water, [
      Vector2(660, -30),
      Vector2(610, 170),
      Vector2(680, 400),
      Vector2(620, 750),
    ], 70),
    // Köprüler.
    TerrainFeature(
        TerrainKind.bridge, [Vector2(560, 150), Vector2(700, 170)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(575, 560), Vector2(725, 545)], 46),
    // Dağ sıraları (köşelerde, nokta simetrik).
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 90), Vector2(230, 150)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(1290, 630), Vector2(1050, 570)], 26),
    // Karlı tepeler (nokta simetrik).
    TerrainFeature(TerrainKind.rock, [Vector2(430, 590)], 52),
    TerrainFeature(TerrainKind.rock, [Vector2(850, 130)], 52),
    // BATAKLIK: nehir kıyısındaki güç binalarına yaklaşan yavaşlar
    // (nokta simetrik iki çamur şeridi).
    TerrainFeature(TerrainKind.swamp,
        [Vector2(370, 440), Vector2(500, 430)], 60),
    TerrainFeature(TerrainKind.swamp,
        [Vector2(780, 290), Vector2(910, 280)], 60),
  ],
  nestSpots: [Vector2(140, 360), Vector2(1140, 360)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(500, 150), // kuzey köprübaşı (batı yakası)
    Vector2(780, 570), // güney köprübaşı (doğu yakası)
    Vector2(300, 300), // batı yuvasına yakın ekonomi
    Vector2(980, 420), // doğu yuvasına yakın ekonomi
    Vector2(450, 500), // nehir kıyısı çekişme
    Vector2(830, 220), // nehir kıyısı çekişme
    Vector2(200, 550), // batı İKİNCİ ekonomi (nokta simetrik çift)
    Vector2(1080, 170), // doğu İKİNCİ ekonomi
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// HAYATTA KALMA (sonsuz dalga) — "Amazon Savunması"
/// Amazon Geçidi'nin TEK KÖPRÜLÜ varyantı: nehri yalnız MERKEZDEKİ köprü
/// aşar — doğudan gelen dalgalar tek dar geçide huniye girer, kuleler
/// köprübaşını tutar. Savaş Kur listesinde YOKTUR; yalnız sonsuz dalga
/// bu haritayı açar. Oyuncu HEP BATI yuvasında doğar (fixedNests).
final MapDefinition hordeCrossing = MapDefinition(
  id: 'horde_crossing',
  name: 'Amazon Savunması',
  nameEn: 'Amazon Defense',
  playerCount: 2,
  fixedNests: true,
  features: [
    // Nehir: kuzeyden güneye S kıvrımı (Amazon Geçidi ile aynı).
    TerrainFeature(TerrainKind.water, [
      Vector2(660, -30),
      Vector2(610, 170),
      Vector2(680, 400),
      Vector2(620, 750),
    ], 70),
    // TEK köprü: nehrin ortasında (kıvrımın en geniş yerinde).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(590, 395), Vector2(760, 390)], 46),
    // Dağ sıraları (köşelerde, nokta simetrik).
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 90), Vector2(230, 150)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(1290, 630), Vector2(1050, 570)], 26),
    // Karlı tepeler.
    TerrainFeature(TerrainKind.rock, [Vector2(430, 590)], 52),
    TerrainFeature(TerrainKind.rock, [Vector2(850, 130)], 52),
    // Bataklıklar: köprüye koşan dalgayı yavaşlatır.
    TerrainFeature(TerrainKind.swamp,
        [Vector2(370, 440), Vector2(500, 430)], 60),
    TerrainFeature(TerrainKind.swamp,
        [Vector2(780, 290), Vector2(910, 280)], 60),
  ],
  // İLK yuva OYUNCUNUN (batı); ikincisi yabani sürünün sembolik yuvası.
  nestSpots: [Vector2(140, 360), Vector2(1140, 360)],
  buildingSpots: [
    Vector2(520, 430), // köprübaşı kulesi (batı yakası)
    Vector2(830, 370), // köprübaşı kulesi (doğu yakası)
    Vector2(300, 300), // batı ekonomi
    Vector2(980, 420), // doğu ekonomi
    Vector2(450, 500), // nehir kıyısı güç
    Vector2(830, 220), // nehir kıyısı güç
    Vector2(200, 550), // batı ikinci ekonomi
    Vector2(1080, 170), // doğu ikinci ekonomi
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// 2 KİŞİLİK (1v1) — "Himalaya Geçitleri"
/// FARKLI KONSEPT: hiç su yok — karlı dağ sıraları haritayı ÜÇ ŞERİDE böler,
/// şeritler yalnız iki dar GEÇİTTEN birbirine bağlanır. Geçitleri tutan
/// kazanır; kaynaklar uzak yan şeritlerde, güç merkezi ortada çekişmelidir.
final MapDefinition himalayaPasses = MapDefinition(
  id: 'himalaya_passes',
  name: 'Himalaya Geçitleri',
  nameEn: 'Himalayan Passes',
  playerCount: 2,
  features: [
    // Üst ayraç: batıdan gelir, KUZEY GEÇİDİ (x 680-900) açık kalır.
    // Batı kolunun ortasında KAZILABİLİR kaya tıkacı: kazılırsa
    // kuzeybatıya ÜÇÜNCÜ bir geçit açılır (harita maç içinde değişir).
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 245), Vector2(300, 247)], 26),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(300, 247), Vector2(420, 248)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(420, 248), Vector2(680, 250)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(900, 235), Vector2(1290, 230)], 26),
    // Alt ayraç: doğudan gelir, GÜNEY GEÇİDİ (x 380-600) açık kalır.
    // Doğu kolunda simetrik kazı tıkacı (güneydoğu geçidi).
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 475), Vector2(380, 480)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(600, 470), Vector2(860, 472)], 26),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(860, 472), Vector2(980, 473)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(980, 473), Vector2(1290, 475)], 26),
    // Yaban arısı yuvaları: kuzey ve güney şeritlerin ortası —
    // kestirmeleri pahalılaştırır (nokta simetrik çift).
    TerrainFeature(TerrainKind.waspNest, [Vector2(640, 150)], 34),
    TerrainFeature(TerrainKind.waspNest, [Vector2(640, 570)], 34),
    // GEÇİT ÖNÜ BATAKLIKLARI: geçide dalan ordu çamurda yavaşlar,
    // geçidi tutan kule nefes alır (nokta simetrik).
    TerrainFeature(TerrainKind.swamp, [Vector2(790, 320)], 84),
    TerrainFeature(TerrainKind.swamp, [Vector2(490, 400)], 84),
    // Karlı tepeler (Himalaya dokusu).
    TerrainFeature(TerrainKind.rock, [Vector2(640, 90)], 50),
    TerrainFeature(TerrainKind.rock, [Vector2(640, 640)], 50),
    TerrainFeature(TerrainKind.rock, [Vector2(180, 640)], 38),
    TerrainFeature(TerrainKind.rock, [Vector2(1100, 90)], 38),
  ],
  nestSpots: [Vector2(150, 360), Vector2(1130, 360)],
  // YAĞMACI AKREPLER: orta şeridin iki kanadı (nokta simetrik).
  scorpionSpots: [Vector2(400, 300), Vector2(880, 420)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(790, 240), // kuzey geçidi bekçisi
    Vector2(490, 480), // güney geçidi bekçisi
    Vector2(320, 150), // NW ekonomi (üst şerit)
    Vector2(960, 570), // SE ekonomi (alt şerit)
    Vector2(320, 570), // SW ekonomi
    Vector2(960, 150), // NE ekonomi
    Vector2(640, 360), // merkez güç — orta şeridin kalbi
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
  ],
);

/// 3 KİŞİLİK (1v1v1) — "Serengeti Üçgeni"
/// Merkezde gölet; şeritler dağ sıralarıyla ayrılır.
/// Stratejik: her oyuncunun yakınında 1 kaynak; şerit boğazlarında kuleler;
/// güneyde herkese eşit uzak bir güç binası.
final MapDefinition rootTriangle = MapDefinition(
  id: 'root_triangle',
  name: 'Serengeti Üçgeni',
  nameEn: 'Serengeti Triangle',
  playerCount: 3,
  features: [
    // Merkez gölet.
    TerrainFeature(TerrainKind.water, [Vector2(640, 340)], 150),
    // Üstten inen dağ sıraları (kuzey oyuncuları ayırır).
    TerrainFeature(
        TerrainKind.root, [Vector2(340, -10), Vector2(410, 180)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(940, -10), Vector2(870, 180)], 26),
    // Alt köşelerden içeri uzanan sıralar (güney kanatları).
    TerrainFeature(
        TerrainKind.root, [Vector2(150, 730), Vector2(280, 560)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(1130, 730), Vector2(1000, 560)], 26),
    // Karlı tepeler.
    TerrainFeature(TerrainKind.rock, [Vector2(640, 706)], 44),
    TerrainFeature(TerrainKind.rock, [Vector2(240, 250)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(1040, 250)], 40),
    // BATAKLIK: göletin güneyindeki çekişmeli güç binasının önü çamur —
    // güce koşan herkes yavaşlar, savunan kazanır.
    TerrainFeature(TerrainKind.swamp,
        [Vector2(550, 482), Vector2(730, 482)], 58),
    // Yaban arısı yuvaları: yan şerit kestirmelerinde eşit caydırıcılık.
    TerrainFeature(TerrainKind.waspNest, [Vector2(300, 390)], 34),
    TerrainFeature(TerrainKind.waspNest, [Vector2(980, 390)], 34),
  ],
  nestSpots: [Vector2(180, 140), Vector2(1100, 140), Vector2(640, 590)],
  // YAĞMACI AKREP: gölet üstü — kuzey boğazının etrafında devriye gezer.
  scorpionSpots: [Vector2(640, 240)],
  buildingSpots: [
    Vector2(640, 140), // kuzey boğazı — iki kuzeyli için kilit
    Vector2(420, 500), // batı şeridi boğazı
    Vector2(860, 500), // doğu şeridi boğazı
    Vector2(330, 230), // NW ekonomi
    Vector2(950, 230), // NE ekonomi
    Vector2(500, 645), // güney ekonomi
    Vector2(640, 470), // gölet altı çekişmeli güç
    Vector2(170, 640), // GÜNEYBATI köşe ekonomisi
    Vector2(1110, 640), // GÜNEYDOĞU köşe ekonomisi
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// Ada haritaları için ortak su halkası (merkez hub'ı çevreler).
List<Vector2> _ringPoints(double cx, double cy, double r, int n) => [
      for (var i = 0; i <= n; i++)
        Vector2(
          cx + r * math.cos(i / n * 2 * math.pi),
          cy + r * math.sin(i / n * 2 * math.pi),
        ),
    ];

/// 3 KİŞİLİK (1v1v1) — "Ege Adaları"
/// Merkezde HUB adası (değerli binalar), çevresinde su halkası; üç oyuncu
/// adası dış moatlarla birbirinden ayrı. Hub'a yalnız 3 köprüden ulaşılır.
final MapDefinition threeIslands = MapDefinition(
  id: 'three_islands',
  name: 'Ege Adaları',
  nameEn: 'Aegean Isles',
  playerCount: 3,
  features: [
    // Hub çevresi su halkası.
    TerrainFeature(TerrainKind.water, _ringPoints(640, 360, 200, 20), 100),
    // Dış moatlar: adaları birbirinden ayırır (K, B, D) — kıvrımlı akar.
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
    // Hub köprüleri (NW, NE, G adalarına).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(548, 268), Vector2(449, 169)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(732, 268), Vector2(831, 169)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(640, 490), Vector2(640, 615)], 46),
    // Kıyı kayalıkları (adaların kenarları taşlı).
    TerrainFeature(TerrainKind.rock, [Vector2(300, 480)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(980, 480)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(200, 620)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(1080, 620)], 30),
    // MOAT KÖPRÜLERİ: adalar hub'a uğramadan da komşusuna bağlanır —
    // dış halka yolları (eski gelgit sığlıklarının yerinde, kalıcı).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(240, 280), Vector2(225, 440)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(1040, 280), Vector2(1055, 440)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(555, 80), Vector2(725, 80)], 46),
    // KÖPRÜBAŞI BATAKLIKLARI: dış halkadan gelen baskıncı çamura basar —
    // savunan tarafın tepki verecek vakti olur.
    TerrainFeature(TerrainKind.swamp, [Vector2(235, 510)], 90),
    TerrainFeature(TerrainKind.swamp, [Vector2(1045, 510)], 90),
    TerrainFeature(TerrainKind.swamp, [Vector2(485, 85)], 76),
    TerrainFeature(TerrainKind.swamp, [Vector2(795, 85)], 76),
  ],
  nestSpots: [Vector2(220, 170), Vector2(1060, 170), Vector2(745, 655)],
  // Her adada aynı set: 1 ekonomi + 1 köprü bekçisi kule; hub'da ödül.
  buildingSpots: [
    Vector2(600, 360), // HUB: güç (ödül)
    Vector2(690, 360), // HUB: kule (savunulabilir)
    Vector2(300, 95), // NW ekonomi
    Vector2(980, 95), // NE ekonomi
    Vector2(330, 650), // G ekonomi
    Vector2(450, 120), // NW köprü bekçisi
    Vector2(830, 120), // NE köprü bekçisi
    Vector2(585, 645), // G köprü bekçisi
    Vector2(150, 255), // ada İKİNCİ ekonomileri (her oyuncuya bir)
    Vector2(1130, 255),
    Vector2(950, 640),
  ],
  buildingTypes: [
    BuildingType.power,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Tuna Kıyıları"
/// Ortadan yatay akan nehir ve üç köprü; kuleler köprübaşlarını tutar.
final MapDefinition fourCorners = MapDefinition(
  id: 'four_corners',
  name: 'Tuna Kıyıları',
  nameEn: 'Danube Banks',
  playerCount: 4,
  features: [
    // Nehir: yatay ama kıvrıla kıvrıla akar.
    TerrainFeature(TerrainKind.water, [
      Vector2(-30, 360),
      Vector2(200, 330),
      Vector2(430, 395),
      Vector2(640, 350),
      Vector2(860, 395),
      Vector2(1080, 330),
      Vector2(1310, 360),
    ], 62),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(300, 270), Vector2(300, 410)], 54),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(640, 315), Vector2(640, 455)], 54),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(980, 270), Vector2(980, 410)], 54),
    TerrainFeature(TerrainKind.rock, [Vector2(640, 170)], 52),
    TerrainFeature(TerrainKind.rock, [Vector2(640, 550)], 52),
    TerrainFeature(
        TerrainKind.root, [Vector2(350, -10), Vector2(300, 130)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(930, -10), Vector2(980, 130)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(350, 730), Vector2(300, 590)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(930, 730), Vector2(980, 590)], 24),
  ],
  nestSpots: [
    Vector2(150, 140),
    Vector2(1130, 140),
    Vector2(150, 580),
    Vector2(1130, 580),
  ],
  // YAĞMACI KAMPLARI: nehir kıyısının iki yakası (nokta simetrik) —
  // dolduran 5 paralı yağmacıyı ordusuna katar.
  raiderCampSpots: [Vector2(330, 470), Vector2(950, 250)],
  buildingSpots: [
    Vector2(470, 170),
    Vector2(810, 170),
    Vector2(470, 550),
    Vector2(810, 550),
    Vector2(640, 235), // kuzey güç — üst HUD barının ALTINDA görünür
    Vector2(640, 485), // güney güç (nokta simetrik eş)
    Vector2(300, 190),
    Vector2(980, 190),
    Vector2(300, 530),
    Vector2(980, 530),
    // KULUÇKA İSTASYONLARI (nokta simetrik): nehir kıyısında ikinci
    // çıkış — tutan taraf cepheye ışınlanmış gibi asker indirir.
    Vector2(500, 265),
    Vector2(780, 455),
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.hatchery,
    BuildingType.hatchery,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Pasifik Atolü"
/// Dört köşe adası + merkez HUB adası; hub'a 4 çapraz köprü. Adalar dış
/// moatlarla ayrık — komşuna ulaşmanın tek yolu hub'dan geçer.
final MapDefinition fourIslands = MapDefinition(
  id: 'four_islands',
  name: 'Pasifik Atolü',
  nameEn: 'Pacific Atoll',
  playerCount: 4,
  features: [
    // Hub su halkası.
    TerrainFeature(TerrainKind.water, _ringPoints(640, 360, 200, 20), 100),
    // Dış moatlar (K, G, B, D): köşe adalarını ayırır — kıvrımlı akar.
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
    // Çapraz köprüler (NW, NE, SW, SE).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(548, 268), Vector2(449, 169)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(732, 268), Vector2(831, 169)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(548, 452), Vector2(449, 551)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(732, 452), Vector2(831, 551)], 46),
    // Kıyı kayalıkları.
    TerrainFeature(TerrainKind.rock, [Vector2(250, 260)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(1030, 260)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(250, 460)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(1030, 460)], 30),
    // YAN KÖPRÜLER: batı ve doğu moatlarında — komşuna hub'a uğramadan
    // baskın yapabilirsin (eski gelgit sığlıklarının yerinde, kalıcı).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(310, 290), Vector2(310, 430)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(970, 290), Vector2(970, 430)], 46),
    // Yaban arısı yuvaları: hub ödülünün DÖRT yaklaşımı da arılı —
    // merkeze dalmanın bedeli var (4 oyuncuya da eşit).
    TerrainFeature(TerrainKind.waspNest, [Vector2(640, 238)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(640, 482)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(518, 360)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(762, 360)], 32),
  ],
  nestSpots: [
    Vector2(170, 130),
    Vector2(1110, 130),
    Vector2(170, 590),
    Vector2(1110, 590),
  ],
  buildingSpots: [
    Vector2(640, 360), // HUB: güç (büyük ödül)
    Vector2(350, 160), // ada ekonomileri
    Vector2(930, 160),
    Vector2(350, 560),
    Vector2(930, 560),
    Vector2(410, 120), // köprü bekçisi kuleler (ada tarafı)
    Vector2(870, 120),
    Vector2(410, 600),
    Vector2(870, 600),
    Vector2(215, 215), // ada İKİNCİ ekonomileri (köşe tarafı)
    Vector2(1065, 215),
    Vector2(215, 505),
    Vector2(1065, 505),
    Vector2(365, 270), // ada güç merkezleri (moat kıyısı)
    Vector2(915, 270),
    Vector2(365, 450),
    Vector2(915, 450),
  ],
  buildingTypes: [
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Panama Geçidi"
/// TEK KÖPRÜ: kuzeyden güneye kıvrılan kanalı geçmenin TEK yolu ortadaki
/// köprüdür — bütün savaş o dar geçitte döner. Kuleler köprübaşlarını
/// tutar, güç binaları kanal kıyısında çekişmelidir.
final MapDefinition panamaPass = MapDefinition(
  id: 'panama_pass',
  name: 'Panama Geçidi',
  nameEn: 'Panama Passage',
  playerCount: 4,
  features: [
    // Kanal: dikey, kıvrımlı.
    TerrainFeature(TerrainKind.water, [
      Vector2(620, -30),
      Vector2(662, 140),
      Vector2(608, 360),
      Vector2(668, 560),
      Vector2(628, 750),
    ], 70),
    // TEK köprü (harita merkezi) — dar boğaz.
    TerrainFeature(
        TerrainKind.bridge, [Vector2(545, 360), Vector2(730, 360)], 54),
    // Köşe dağ sıraları (şeritleri şekillendirir).
    TerrainFeature(
        TerrainKind.root, [Vector2(320, -10), Vector2(280, 140)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(960, -10), Vector2(1000, 140)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(320, 730), Vector2(280, 580)], 24),
    TerrainFeature(
        TerrainKind.root, [Vector2(960, 730), Vector2(1000, 580)], 24),
    // Karlı tepeler.
    TerrainFeature(TerrainKind.rock, [Vector2(430, 220)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(850, 500)], 40),
    // BATAKLIK: tek köprünün yaklaşma koridorları çamur (nokta simetrik) —
    // köprü hücumu yavaşlar, savunma nefes alır.
    TerrainFeature(TerrainKind.swamp,
        [Vector2(440, 270), Vector2(540, 250)], 58),
    TerrainFeature(TerrainKind.swamp,
        [Vector2(740, 470), Vector2(840, 450)], 58),
    // Yaban arısı yuvaları: yan şerit kestirmeleri arılı (nokta simetrik).
    TerrainFeature(TerrainKind.waspNest, [Vector2(330, 360)], 34),
    TerrainFeature(TerrainKind.waspNest, [Vector2(950, 360)], 34),
  ],
  nestSpots: [
    Vector2(150, 140),
    Vector2(1130, 140),
    Vector2(150, 580),
    Vector2(1130, 580),
  ],
  // YAĞMACI AKREPLER: kıyı güçlerinin yanı (nokta simetrik çift).
  scorpionSpots: [Vector2(420, 120), Vector2(860, 600)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(460, 360), // batı köprübaşı bekçisi
    Vector2(820, 360), // doğu köprübaşı bekçisi
    Vector2(300, 170), // NW ekonomi
    Vector2(980, 550), // SE ekonomi
    Vector2(300, 550), // SW ekonomi
    Vector2(980, 170), // NE ekonomi
    Vector2(500, 120), // batı kıyısı güç (çekişmeli)
    Vector2(780, 600), // doğu kıyısı güç (çekişmeli)
    Vector2(150, 360), // BATI kenar kulesi: yan şeridin ortası
    Vector2(1130, 360), // DOĞU kenar kulesi (nokta simetrik)
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.tower,
    BuildingType.tower,
  ],
);


/// EĞİTİM KAMPI — allMaps DIŞINDADIR (Savaş Kur listesine elle eklenir).
/// Açık ve sade alan: 1 çiftlik, 1 kule, 1 güç binası, küçük gölet.
/// Rakip beyinsizdir; oyuncu tüm özellikleri adım adım öğrenir.
final MapDefinition tutorialMap = MapDefinition(
  id: 'egitim',
  name: 'Eğitim Kampı',
  nameEn: 'Boot Camp',
  playerCount: 2,
  features: [
    TerrainFeature(TerrainKind.water, [Vector2(880, 170)], 110),
    TerrainFeature(TerrainKind.rock, [Vector2(340, 150)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(950, 560)], 40),
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 600) , Vector2(180, 660)], 24),
  ],
  nestSpots: [Vector2(170, 360), Vector2(1110, 360)],
  buildingSpots: [
    Vector2(420, 360), // İLK HEDEF: yakın çiftlik
    Vector2(640, 210), // kule (öğretici: nötr kule ateş eder)
    Vector2(640, 520), // güç binası
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.power,
  ],
);

/// 3 KİŞİLİK (1v1v1) — "Nil Deltası"
/// FARKLI KONSEPT: güneyden gelen büyük nehir ortada ÇATALLANIR ve iki kol
/// kuzeye açılır — haritayı üç bölgeye böler (batı, doğu, kollar arasındaki
/// DELTA ADASI). Üç köprü + adanın kalbinde çamurlu çekişme alanı.
final MapDefinition nileDelta = MapDefinition(
  id: 'nile_delta',
  name: 'Nil Deltası',
  nameEn: 'Nile Delta',
  playerCount: 3,
  features: [
    // Ana gövde (güney) ve çatallanan iki kol.
    TerrainFeature(TerrainKind.water, [
      Vector2(640, 750),
      Vector2(632, 600),
      Vector2(640, 500),
    ], 66),
    TerrainFeature(TerrainKind.water, [
      Vector2(640, 500),
      Vector2(560, 400),
      Vector2(480, 290),
      Vector2(445, 150),
      Vector2(455, -30),
    ], 62),
    TerrainFeature(TerrainKind.water, [
      Vector2(640, 500),
      Vector2(720, 400),
      Vector2(800, 290),
      Vector2(835, 150),
      Vector2(825, -30),
    ], 62),
    // Köprüler: ana gövde + iki kol.
    TerrainFeature(
        TerrainKind.bridge, [Vector2(550, 640), Vector2(730, 640)], 54),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(360, 200), Vector2(540, 180)], 50),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(740, 180), Vector2(920, 200)], 50),
    // DELTA ÇAMURU: adanın kalbi bataklık — güce koşan yavaşlar.
    TerrainFeature(TerrainKind.swamp, [Vector2(640, 330)], 120),
    // Kayalıklar.
    TerrainFeature(TerrainKind.rock, [Vector2(200, 120)], 36),
    TerrainFeature(TerrainKind.rock, [Vector2(1080, 120)], 36),
    TerrainFeature(TerrainKind.rock, [Vector2(430, 690)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(850, 690)], 34),
    // DENGE: kuzey (ada) oyuncusunun kıyı boyu baskın yolu arılı —
    // batı/doğu oyuncularının yeni köprübaşı üsleri bedavaya kuşatılamaz.
    TerrainFeature(TerrainKind.waspNest, [Vector2(340, 70)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(940, 70)], 32),
  ],
  nestSpots: [Vector2(640, 140), Vector2(180, 520), Vector2(1100, 520)],
  buildingSpots: [
    Vector2(560, 240), // NW köprübaşı (ada tarafı)
    Vector2(720, 240), // NE köprübaşı (ada tarafı)
    Vector2(770, 600), // ana köprü doğu yakası
    Vector2(300, 560), // batı ekonomi
    Vector2(980, 560), // doğu ekonomi
    Vector2(530, 120), // ada (kuzey) ekonomi
    Vector2(640, 410), // ADANIN KALBİ: çekişmeli güç (çamurun dibinde)
    // DENGE: batı/doğu oyuncularına köprübaşı üsleri — ada oyuncusunun
    // iki bekçi kulesine karşılık kıyıda kule + çiftlik.
    Vector2(330, 260), // batı köprübaşı kulesi (kıyı tarafı)
    Vector2(950, 260), // doğu köprübaşı kulesi
    Vector2(210, 300), // batı köprübaşı çiftliği
    Vector2(1070, 300), // doğu köprübaşı çiftliği
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// 3 KİŞİLİK (1v1v1) — "Kapadokya Koridorları"
/// FARKLI KONSEPT: susuz PERİBACASI LABİRENTİ — merkez arenadan üç yöne
/// uzanan dağ kolları haritayı üç dilime böler; her kolun ortasında
/// KAZILABİLİR tıkaç var: kazan, komşuna arkadan dolan.
final MapDefinition cappadociaCorridors = MapDefinition(
  id: 'cappadocia',
  name: 'Kapadokya Koridorları',
  nameEn: 'Cappadocia Corridors',
  playerCount: 3,
  features: [
    // KUZEY kolu (ortasında kazı tıkacı).
    TerrainFeature(
        TerrainKind.root, [Vector2(640, 60), Vector2(640, 150)], 28),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(640, 150), Vector2(640, 215)], 28),
    TerrainFeature(
        TerrainKind.root, [Vector2(640, 215), Vector2(640, 265)], 28),
    // GÜNEYBATI kolu.
    TerrainFeature(
        TerrainKind.root, [Vector2(146, 645), Vector2(300, 556)], 28),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(300, 556), Vector2(356, 524)], 28),
    TerrainFeature(
        TerrainKind.root, [Vector2(356, 524), Vector2(470, 458)], 28),
    // GÜNEYDOĞU kolu.
    TerrainFeature(
        TerrainKind.root, [Vector2(1134, 645), Vector2(980, 556)], 28),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(980, 556), Vector2(924, 524)], 28),
    TerrainFeature(
        TerrainKind.root, [Vector2(924, 524), Vector2(810, 458)], 28),
    // Güney girişinde çamur (arena kapısı yavaş).
    TerrainFeature(TerrainKind.swamp, [Vector2(640, 520)], 90),
    // Peribacası kayalıkları.
    TerrainFeature(TerrainKind.rock, [Vector2(640, 672)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(200, 200)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(1080, 200)], 40),
    // GÜNEY GEÇİŞLERİ ARILI: dağ kollarının altından komşuya dolanan
    // koridorlar (batı-güney ve doğu-güney) ikişer arı yuvasıyla korunur.
    TerrainFeature(TerrainKind.waspNest, [Vector2(420, 540)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(300, 645)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(860, 540)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(980, 645)], 32),
  ],
  nestSpots: [Vector2(200, 250), Vector2(1080, 250), Vector2(640, 585)],
  buildingSpots: [
    Vector2(640, 360), // ARENA KALBİ: güç
    Vector2(270, 380), // batı ekonomi
    Vector2(1010, 380), // doğu ekonomi
    Vector2(520, 640), // güney ekonomi
    Vector2(480, 330), // batı-arena giriş bekçisi
    Vector2(800, 330), // doğu-arena giriş bekçisi
    Vector2(640, 480), // güney giriş bekçisi (çamurun içinde!)
    Vector2(160, 470), // yuva yanı İKİNCİ ekonomiler (her oyuncuya bir)
    Vector2(1120, 470),
    Vector2(760, 645),
  ],
  buildingTypes: [
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Büyük Kanyon"
/// FARKLI KONSEPT: haritayı ÇAPRAZ kesen kanyon nehri (SW→NE) — iki asma
/// köprü; merkez hat arı yuvalarıyla korunur. Takımlar kanyonun
/// iki yakasında doğar; bütün maç o çapraz hattı geçme savaşıdır.
final MapDefinition grandCanyon = MapDefinition(
  id: 'grand_canyon',
  name: 'Büyük Kanyon',
  nameEn: 'Grand Canyon',
  playerCount: 4,
  features: [
    // Kanyon nehri: köşeden köşeye çapraz.
    TerrainFeature(TerrainKind.water, [
      Vector2(-30, 690),
      Vector2(300, 560),
      Vector2(640, 360),
      Vector2(980, 160),
      Vector2(1310, 30),
    ], 72),
    // İki asma köprü (nehre dik, nokta simetrik).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(418, 396), Vector2(502, 544)], 52),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(778, 176), Vector2(862, 324)], 52),
    // Yaban arısı yuvaları (nokta simetrik): iki yakada birer + MERKEZ
    // hattın üst ve altında birer — kanyonun ortası arı bölgesidir.
    TerrainFeature(TerrainKind.waspNest, [Vector2(250, 430)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(1030, 290)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(575, 250)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(705, 470)], 32),
    // Kayalıklar.
    TerrainFeature(TerrainKind.rock, [Vector2(170, 360)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(1110, 360)], 40),
  ],
  // Nokta simetrik yuvalar: ÜST yaka (NW+SW) vs ALT yaka (NE+SE) —
  // 2v2'de takımlar kanyonun iki yakasında doğar.
  nestSpots: [
    Vector2(150, 140),
    Vector2(1130, 190),
    Vector2(150, 530),
    Vector2(1130, 580),
  ],
  // YAĞMACI AKREPLER: iki yakada birer (nokta simetrik).
  scorpionSpots: [Vector2(450, 200), Vector2(830, 520)],
  buildingSpots: [
    Vector2(370, 340), // batı köprü üst-yaka bekçisi
    Vector2(550, 600), // batı köprü alt-yaka bekçisi
    Vector2(910, 380), // doğu köprü alt-yaka bekçisi
    Vector2(730, 120), // doğu köprü üst-yaka bekçisi
    Vector2(330, 150), // ekonomiler (nokta simetrik çiftler)
    Vector2(950, 570),
    Vector2(180, 300),
    Vector2(1100, 420),
    Vector2(520, 300), // kanyon kıyısı çekişmeli güçler
    Vector2(760, 420),
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Okavango Deltası"
/// FARKLI KONSEPT: BATAKLIK SAVAŞI — merkezdeki dev çamur kompleksi
/// haritanın kalbini yavaşlatır (güç binası tam ortasında), köşelerde dört
/// gölet yolları şekillendirir; kuzey/güney kıyılarında KULUÇKA istasyonları
/// cepheye ikinci çıkış verir.
final MapDefinition okavangoDelta = MapDefinition(
  id: 'okavango',
  name: 'Okavango Deltası',
  nameEn: 'Okavango Delta',
  playerCount: 4,
  features: [
    // Dört köşe göleti.
    TerrainFeature(TerrainKind.water, [Vector2(300, 190)], 95),
    TerrainFeature(TerrainKind.water, [Vector2(980, 190)], 95),
    TerrainFeature(TerrainKind.water, [Vector2(300, 530)], 95),
    TerrainFeature(TerrainKind.water, [Vector2(980, 530)], 95),
    // MERKEZ ÇAMUR KOMPLEKSİ: dikey gövde + yatay kollar.
    TerrainFeature(TerrainKind.swamp,
        [Vector2(640, 270), Vector2(640, 450)], 150),
    TerrainFeature(TerrainKind.swamp,
        [Vector2(520, 360), Vector2(760, 360)], 130),
    // Kayalıklar.
    TerrainFeature(TerrainKind.rock, [Vector2(120, 360)], 36),
    TerrainFeature(TerrainKind.rock, [Vector2(1160, 360)], 36),
    // Merkez KULUÇKANIN muhafızları: iki arı yuvası (nokta simetrik) —
    // ikinci çıkışı almak bedava değil.
    TerrainFeature(TerrainKind.waspNest, [Vector2(520, 285)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(760, 435)], 32),
  ],
  nestSpots: [
    Vector2(150, 130),
    Vector2(1130, 130),
    Vector2(150, 590),
    Vector2(1130, 590),
  ],
  buildingSpots: [
    Vector2(640, 360), // BATAKLIĞIN KALBİ: KULUÇKA — tutan cepheye iner
    Vector2(450, 250), // çamur kenarı bekçileri (nokta simetrik)
    Vector2(830, 470),
    Vector2(430, 130), // yuva yanı ekonomiler
    Vector2(850, 590),
    Vector2(430, 590),
    Vector2(850, 130),
    Vector2(640, 110), // kuzey GÜÇ (nokta simetrik çift)
    Vector2(640, 610), // güney GÜÇ
  ],
  buildingTypes: [
    BuildingType.hatchery,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 2 KİŞİLİK (1v1) — "Kızıldeniz Sığlıkları"
/// FARKLI KONSEPT: geniş deniz bandını TEK merkezi köprü aşar — bütün
/// savaş o boğazda döner (1v1'in Panama'sı). Kıyı bataklıkları köprü
/// kanatlarındaki güç binalarına yaklaşanı yavaşlatır.
final MapDefinition redSeaShallows = MapDefinition(
  id: 'red_sea_shallows',
  name: 'Kızıldeniz Sığlıkları',
  nameEn: 'Red Sea Shallows',
  playerCount: 2,
  features: [
    // Deniz: kuzeyden güneye hafif kıvrımlı geniş bant.
    TerrainFeature(TerrainKind.water, [
      Vector2(640, -30),
      Vector2(600, 180),
      Vector2(680, 540),
      Vector2(640, 750),
    ], 86),
    // TEK köprü: merkezde — kuleler iki başını tutar.
    TerrainFeature(
        TerrainKind.bridge, [Vector2(560, 355), Vector2(720, 365)], 46),
    // KIYI BATAKLIKLARI: kanatlardaki güç binalarının önü çamur
    // (nokta simetrik — herkes kendi kanadında pay alır).
    TerrainFeature(TerrainKind.swamp, [Vector2(790, 140)], 70),
    TerrainFeature(TerrainKind.swamp, [Vector2(490, 580)], 70),
    // Kıyı kayalıkları (nokta simetrik süs).
    TerrainFeature(TerrainKind.rock, [Vector2(250, 120)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(1030, 600)], 40),
    TerrainFeature(TerrainKind.rock, [Vector2(350, 640)], 32),
    TerrainFeature(TerrainKind.rock, [Vector2(930, 80)], 32),
  ],
  nestSpots: [Vector2(150, 360), Vector2(1130, 360)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(495, 330), // köprübaşı bekçileri
    Vector2(785, 390),
    Vector2(290, 240), // yuva yanı ekonomiler
    Vector2(990, 480),
    Vector2(230, 500), // ikinci ekonomiler (nokta simetrik çift)
    Vector2(1050, 220),
    Vector2(450, 140), // kanat GÜÇLERİ — çekişmeli kıyılar
    Vector2(830, 580),
  ],
  buildingTypes: [
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 2 KİŞİLİK (1v1) — "Tuz Gölü Düzlüğü"
/// FARKLI KONSEPT: duvarsız AÇIK ARENA — tek engel ortadaki tuz gölü.
/// Yuvalar çaprazda; iki akrep açık düzlükte devriyede, iki kuluçka
/// çekişmeli köşelerde hızlı cephe açar. Boğaz yok: kanat manevrası ve
/// açık alan savaşı haritası.
final MapDefinition saltLakeFlats = MapDefinition(
  id: 'salt_lake',
  name: 'Tuz Gölü Düzlüğü',
  nameEn: 'Salt Lake Flats',
  playerCount: 2,
  features: [
    // Merkez tuz gölü (tek engel).
    TerrainFeature(TerrainKind.water, [Vector2(640, 360)], 78),
    // Göl kıyısı çamurları: gölü yalayan kestirme yavaşlar
    // (nokta simetrik çift).
    TerrainFeature(TerrainKind.swamp, [Vector2(430, 430)], 80),
    TerrainFeature(TerrainKind.swamp, [Vector2(850, 290)], 80),
    // Kayalıklar (nokta simetrik süsler).
    TerrainFeature(TerrainKind.rock, [Vector2(170, 100)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(1110, 620)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(1140, 180)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(140, 540)], 30),
  ],
  nestSpots: [Vector2(220, 150), Vector2(1060, 570)],
  // YAĞMACI AKREPLER: açık düzlüğün iki kanadı (nokta simetrik).
  scorpionSpots: [Vector2(460, 240), Vector2(820, 480)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(390, 190), // yuva yanı ekonomiler
    Vector2(890, 530),
    Vector2(160, 340), // kenar ekonomileri (nokta simetrik çift)
    Vector2(1120, 380),
    Vector2(640, 170), // göl kanadı bekçileri
    Vector2(640, 550),
    Vector2(430, 560), // çekişmeli çapraz GÜÇLER
    Vector2(850, 160),
    // KULUÇKALAR (liste sonu): boş çapraz köşeler — tutan cephe açar.
    Vector2(300, 600),
    Vector2(980, 120),
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.power,
    BuildingType.power,
    BuildingType.hatchery,
    BuildingType.hatchery,
  ],
);

/// 2 KİŞİLİK (1v1) — "Marmara Adaları"
/// DÖRT ADA (2×2): çapraz kanal suları haritayı dört adaya böler.
/// HER ADADAN KOMŞUSUNA GEÇİŞ VAR: dört köprü adaları halka gibi bağlar;
/// çapraz adaya iki köprülük yol vardır — köprübaşlarını tutan yönetir.
/// Yuvalar çaprazda (NW/SE); nötr NE/SW adaları güç + ekonomi ödülü taşır.
final MapDefinition marmaraIsles = MapDefinition(
  id: 'marmara_isles',
  name: 'Marmara Adaları',
  nameEn: 'Marmara Isles',
  playerCount: 2,
  features: [
    // DİKEY kanal (kıvrımlı) — batı/doğu adalarını ayırır.
    TerrainFeature(TerrainKind.water, [
      Vector2(640, -30),
      Vector2(620, 200),
      Vector2(660, 520),
      Vector2(640, 750),
    ], 90),
    // YATAY kanal (kıvrımlı) — kuzey/güney adalarını ayırır.
    TerrainFeature(TerrainKind.water, [
      Vector2(-30, 360),
      Vector2(300, 340),
      Vector2(700, 385),
      Vector2(1310, 360),
    ], 90),
    // KÖPRÜLER: komşu adalar arası 4 geçiş (nokta simetrik çiftler).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(560, 170), Vector2(720, 170)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(560, 550), Vector2(720, 550)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(320, 280), Vector2(320, 440)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(960, 280), Vector2(960, 440)], 46),
    // Kıyı kayalıkları (nokta simetrik süsler).
    TerrainFeature(TerrainKind.rock, [Vector2(120, 110)], 36),
    TerrainFeature(TerrainKind.rock, [Vector2(1160, 610)], 36),
    TerrainFeature(TerrainKind.rock, [Vector2(1120, 90)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(160, 630)], 30),
  ],
  nestSpots: [Vector2(240, 180), Vector2(1040, 540)],
  // Nokta simetrik (640,360 merkezli).
  buildingSpots: [
    Vector2(390, 120), // ana ada ekonomileri (yuva yanı)
    Vector2(890, 600),
    Vector2(150, 240), // ana ada ikinci ekonomiler
    Vector2(1130, 480),
    Vector2(820, 180), // NÖTR ada GÜÇLERİ (çekişmeli ödül)
    Vector2(460, 540),
    Vector2(1080, 220), // nötr ada ekonomileri
    Vector2(200, 500),
    Vector2(760, 140), // nötr ada köprübaşı bekçileri
    Vector2(520, 580),
    Vector2(980, 230), // nötr ada batı/doğu köprü bekçileri
    Vector2(300, 490),
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.power,
    BuildingType.power,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Kilimanjaro Yaylaları"
/// SUSUZ dört bölge: artı biçimli dağ sırtları haritayı dört yaylaya
/// böler — HERKESİN KENDİ BÖLGESİ vardır (Pasifik Atolü dengesi). Bölgeler
/// merkez platoda buluşur; iki sırtta KAZILABİLİR tıkaç (harita maç içinde
/// açılır), platonun kalbini arı kovanları bekler. Dengeli 2v2/FFA savaşı.
final MapDefinition kilimanjaroHighlands = MapDefinition(
  id: 'kilimanjaro',
  name: 'Kilimanjaro Yaylaları',
  nameEn: 'Kilimanjaro Highlands',
  playerCount: 4,
  features: [
    // KUZEY sırtı: üst kenardan iner, ucunda kazı tıkacı.
    TerrainFeature(
        TerrainKind.root, [Vector2(640, -10), Vector2(640, 150)], 26),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(640, 150), Vector2(640, 240)], 26),
    // GÜNEY sırtı (nokta simetrik): altta kazı tıkacı üstte.
    TerrainFeature(
        TerrainKind.digsite, [Vector2(640, 480), Vector2(640, 570)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(640, 570), Vector2(640, 730)], 26),
    // BATI ve DOĞU sırtları: kenarlardan içeri (geçit merkezde kalır).
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 360), Vector2(330, 360)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(950, 360), Vector2(1290, 360)], 26),
    // Plato bekçileri: merkeze sarkan her ordu sokulur (nokta simetrik).
    TerrainFeature(TerrainKind.waspNest, [Vector2(560, 320)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(720, 400)], 32),
    // Karlı tepeler (Kilimanjaro dokusu, 4 köşe simetrik).
    TerrainFeature(TerrainKind.rock, [Vector2(200, 70)], 38),
    TerrainFeature(TerrainKind.rock, [Vector2(1080, 650)], 38),
    TerrainFeature(TerrainKind.rock, [Vector2(1080, 70)], 38),
    TerrainFeature(TerrainKind.rock, [Vector2(200, 650)], 38),
  ],
  nestSpots: [
    Vector2(150, 140),
    Vector2(1130, 140),
    Vector2(150, 580),
    Vector2(1130, 580),
  ],
  // YAĞMACI KAMPLARI: doğu-batı koridorları (nokta simetrik).
  raiderCampSpots: [Vector2(410, 360), Vector2(870, 360)],
  // 4 yayla simetrisi: her bölgede 2 çiftlik + geçit ağzında 1 kule;
  // merkez platoda 2 çekişmeli GÜÇ.
  buildingSpots: [
    Vector2(340, 130), // yayla ekonomileri (yuva yanı)
    Vector2(940, 130),
    Vector2(340, 590),
    Vector2(940, 590),
    Vector2(150, 300), // ikinci ekonomiler (sırt dibi)
    Vector2(1130, 300),
    Vector2(150, 420),
    Vector2(1130, 420),
    Vector2(480, 240), // geçit ağzı bekçileri (her bölgenin plato kapısı)
    Vector2(800, 240),
    Vector2(480, 480),
    Vector2(800, 480),
    Vector2(600, 360), // PLATONUN KALBİ: çekişmeli güçler
    Vector2(680, 360),
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 4 KİŞİLİK (1v1v1v1 / 2v2) — "Halong Koyları"
/// ATOL DÜZENİ (Pasifik dengesi): dört kenar koyu + merkez su halkası
/// dört yarımadayı TAMAMEN ayırır — komşuna gitmenin tek yolu MERKEZ.
/// Merkez ada yalnız 4 çapraz köprüyle bağlıdır ve ÇOK GÜÇLÜDÜR: iki
/// feromon merkezini bir YAĞMACI AKREP ve iki ARI KOVANI bekler
/// (bilinçli olarak ele geçirme alanının dibinde — kalbi almak bedel
/// ister; akrep öldürülürse GERİ GELMEZ, kalp kalıcı yumuşar).
final MapDefinition halongBays = MapDefinition(
  id: 'halong_bays',
  name: 'Halong Koyları',
  nameEn: 'Ha Long Bays',
  playerCount: 4,
  features: [
    // MERKEZ SU HALKASI: adayı çevreler (köprüsüz geçilmez).
    TerrainFeature(TerrainKind.water, _ringPoints(640, 360, 150, 18), 90),
    // Dört kenar koyu: halkaya KAVUŞUR — yarımadalar birbirinden kopar.
    TerrainFeature(TerrainKind.water, [
      Vector2(640, -30),
      Vector2(620, 100),
      Vector2(640, 225),
    ], 86),
    TerrainFeature(TerrainKind.water, [
      Vector2(640, 750),
      Vector2(660, 620),
      Vector2(640, 495),
    ], 86),
    TerrainFeature(TerrainKind.water, [
      Vector2(-30, 360),
      Vector2(200, 340),
      Vector2(432, 360),
    ], 86),
    TerrainFeature(TerrainKind.water, [
      Vector2(1310, 360),
      Vector2(1080, 380),
      Vector2(848, 360),
    ], 86),
    // MERKEZE GİDEN 4 ÇAPRAZ KÖPRÜ (her yarımadanın tek yolu).
    TerrainFeature(
        TerrainKind.bridge, [Vector2(488, 208), Vector2(580, 300)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(792, 208), Vector2(700, 300)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(488, 512), Vector2(580, 420)], 46),
    TerrainFeature(
        TerrainKind.bridge, [Vector2(792, 512), Vector2(700, 420)], 46),
    // MERKEZİN BEKÇİLERİ: iki arı kovanı — kalbe dalan sokulur.
    TerrainFeature(TerrainKind.waspNest, [Vector2(596, 398)], 32),
    TerrainFeature(TerrainKind.waspNest, [Vector2(684, 322)], 32),
    // Kıyı kayalıkları (Halong'un karst kuleleri).
    TerrainFeature(TerrainKind.rock, [Vector2(540, 70)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(740, 650)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(190, 260)], 30),
    TerrainFeature(TerrainKind.rock, [Vector2(1090, 460)], 30),
  ],
  nestSpots: [
    Vector2(150, 140),
    Vector2(1130, 140),
    Vector2(150, 580),
    Vector2(1130, 580),
  ],
  // MERKEZİN EFENDİSİ: tek güçlü akrep — ölürse geri gelmez.
  scorpionSpots: [Vector2(640, 360)],
  buildingSpots: [
    Vector2(330, 140), // yarımada ekonomileri (yuva yanı)
    Vector2(950, 140),
    Vector2(330, 580),
    Vector2(950, 580),
    Vector2(135, 250), // koy kıyısı ikinci ekonomiler
    Vector2(1145, 250),
    Vector2(135, 470),
    Vector2(1145, 470),
    Vector2(452, 176), // köprübaşı bekçileri (her yarımadanın kapısı)
    Vector2(828, 176),
    Vector2(452, 544),
    Vector2(828, 544),
    Vector2(604, 336), // KALP: çekişmeli güçler (akrep + arı gölgesinde)
    Vector2(676, 384),
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.power,
    BuildingType.power,
  ],
);

/// 2 KİŞİLİK (1v1) — "İnka Yolu"
/// TEK ZİKZAK PATİKA: sen SAĞ ÜSTTE, düşman SOL ALTTA. Dağ duvarları
/// haritayı Z biçimli tek bir koridora indirir — üst bant → çapraz geçit
/// → alt bant. Merkezde bir KULE koridoru kilitler: bina bina ele
/// geçire geçire ilerlenir, ortada buluşulur. Duvarlarda birer KAZI
/// TIKACI geç oyunda gizli kanat yolu açar.
final MapDefinition incaTrail = MapDefinition(
  id: 'inca_trail',
  name: 'İnka Yolu',
  nameEn: 'Inca Trail',
  playerCount: 2,
  features: [
    // ÜST BANDIN BATI DUVARI + çapraz geçidin sol-alt siperi.
    TerrainFeature(
        TerrainKind.root, [Vector2(420, -10), Vector2(420, 230)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(420, 230), Vector2(680, 490)], 26),
    // ALT BANDIN DOĞU DUVARI + çapraz geçidin sağ-üst siperi
    // (nokta simetrik eşler).
    TerrainFeature(
        TerrainKind.root, [Vector2(860, 730), Vector2(860, 490)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(860, 490), Vector2(600, 230)], 26),
    // ÜST BANDIN ALT DUVARI: doğudan gelir; ortasında KAZI TIKACI.
    TerrainFeature(
        TerrainKind.root, [Vector2(1290, 240), Vector2(1020, 240)], 26),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(1020, 240), Vector2(900, 240)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(900, 240), Vector2(620, 240)], 26),
    // ALT BANDIN ÜST DUVARI (nokta simetrik): batıdan gelir, kazılı.
    TerrainFeature(
        TerrainKind.root, [Vector2(-10, 480), Vector2(260, 480)], 26),
    TerrainFeature(
        TerrainKind.digsite, [Vector2(260, 480), Vector2(380, 480)], 26),
    TerrainFeature(
        TerrainKind.root, [Vector2(380, 480), Vector2(660, 480)], 26),
    // And dokusu: erişilmez ceplerde karlı tepeler (süs).
    TerrainFeature(TerrainKind.rock, [Vector2(190, 240)], 44),
    TerrainFeature(TerrainKind.rock, [Vector2(1090, 480)], 44),
    TerrainFeature(TerrainKind.rock, [Vector2(150, 120)], 34),
    TerrainFeature(TerrainKind.rock, [Vector2(1130, 600)], 34),
  ],
  // SEN sağ üstte, DÜŞMAN sol altta (karıştırma yok: fixedNests).
  fixedNests: true,
  nestSpots: [Vector2(1130, 130), Vector2(150, 590)],
  // Nokta simetrik (640,360 merkezli) — yol boyu dizilim.
  buildingSpots: [
    Vector2(950, 120), // yuva yanı ekonomiler
    Vector2(330, 600),
    Vector2(740, 150), // bant ortası ikinci ekonomiler
    Vector2(540, 570),
    Vector2(590, 130), // viraj bekçisi kuleler (çapraz geçit ağzı)
    Vector2(690, 590),
    Vector2(553, 273), // çapraz geçit GÜÇLERİ (merkez kuleden önce)
    Vector2(727, 447),
    Vector2(640, 360), // MERKEZ KULE: koridorun kilidi — burada buluşulur
  ],
  buildingTypes: [
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.resource,
    BuildingType.tower,
    BuildingType.tower,
    BuildingType.power,
    BuildingType.power,
    BuildingType.tower,
  ],
);
