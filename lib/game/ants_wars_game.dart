import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/settings.dart';
import '../data/units.dart';
import '../models/building.dart';
import '../models/game_map.dart';
import '../models/nest.dart';
import '../models/player.dart';
import '../net/net_client_bridge.dart';
import '../net/net_host_bridge.dart';
import 'ability_effects.dart';
import 'ant_sprite_cache.dart';
import 'army_layer.dart';
import 'audio_controller.dart';
import 'bot_controller.dart';
import 'building_component.dart';
import 'fog_of_war.dart';
import 'game_state.dart';
import 'input_controller.dart';
import 'map_component.dart';
import 'map_elements.dart';
import 'territory_component.dart';
import 'nest_component.dart';
import 'pathfinding.dart';
import 'raider_camp_component.dart';
import 'scorpion_component.dart';
import 'spatial_grid.dart';
import 'unit_component.dart';

/// Oyunun Flame tarafındaki kökü.
///
/// Kamera sabittir: harita her zaman ekrana tam sığar (kaydırma yok).
/// Dünya koordinatları sol üst köşe (0,0) → sağ alt (kGameWidth, kGameHeight).
class AntsWarsGame extends FlameGame {
  AntsWarsGame({required this.gameState, math.Random? rng})
      : _rng = rng ?? math.Random(),
        super(
          camera: CameraComponent.withFixedResolution(
            width: kGameWidth,
            height: kGameHeight,
          ),
        );

  /// KARŞILAŞMA EKRANI bu maçta gösterilsin mi? (Eğitim/sefer/horde'un
  /// kendi giriş akışları var; onlar atlar.)
  bool get wantsIntro =>
      gameState.mission == null && !gameState.tutorial && !gameState.horde;

  @override
  void onRemove() {
    // GameWidget sökülünce Flame ÇOCUKLARIN onRemove'unu çağırmaz (yalnız
    // removed bayrağı basılır) — Picture/Image tutan bileşenlerin (harita
    // sahnesi, bölge boyası, sis dokusu) NATIVE belleği maçtan maça
    // birikir ve menü dahil tüm uygulamayı kasardı. Ağacı gezip temizliği
    // elle tetikliyoruz (ağaçtan zaten çıkmış bileşenler burada değildir,
    // bu yüzden kimse iki kez temizlenmez).
    for (final c in descendants()) {
      c.onRemove();
    }
    super.onRemove();
  }

  final GameState gameState;
  final math.Random _rng;

  /// Deterministik testler için paylaşılan rastgelelik (botlar da kullanır).
  math.Random get rng => _rng;

  /// Bot oyuncuların beyinleri.
  final List<BotController> bots = [];

  /// KİŞİLİK DESTESİ: maç başında karıştırılır, her bot sıradakini alır —
  /// aynı maçta iki bot aynı karakteri oynamaz (10 bota kadar).
  late final List<BotPersona> _personaDeck =
      List.of(botPersonas)..shuffle(_rng);
  int _personaIdx = 0;

  BotPersona nextBotPersona() =>
      _personaDeck[_personaIdx++ % _personaDeck.length];

  // ---- LAN maçı köprüleri (GameScreen kurar; null = yerel maç) ----

  /// HOST tarafı: emirleri uygular, 10 Hz durum yayınlar.
  NetHostBridge? netHost;

  /// İSTEMCİ tarafı: simülasyon YOK — durum yayını uygulanır, emir gönderilir.
  NetClientBridge? netClient;

  bool get isNetHost => netHost != null;
  bool get isNetClient => netClient != null;

  /// İSTEMCİ: ağ kimliği → birim bileşeni (durum uygulamada eşleşme).
  final Map<int, UnitComponent> netUnits = {};

  /// Haritadaki arı kovanı bileşenleri (LAN durum senkronu için kayıtlı).
  final List<WaspNestComponent> waspNests = [];

  /// Haritadaki yağmacı akrepler (nötr canavar; LAN senkronu için kayıtlı).
  final List<ScorpionComponent> scorpions = [];

  /// Haritadaki yağmacı kampları (nötr paralı asker kampı; LAN senkronlu).
  final List<RaiderCampComponent> raiderCamps = [];

  late final MapDefinition map;
  late final MapComponent mapComponent;
  late final PassabilityGrid grid;
  late final Pathfinder pathfinder;

  /// Oyuncu id → ana yuva.
  final Map<int, Nest> nests = {};

  /// Haritadaki tüm binalar.
  final List<Building> buildings = [];

  /// Kazılabilir kaya geçitleri (haritada varsa).
  final List<DigSite> digSites = [];

  /// Maç içinde KALICI olarak açılan engeller: kazılan tıkaçlar +
  /// yıkılan arı kovanları. Grid bu küme yok sayılarak yeniden hesaplanır.
  final Set<TerrainFeature> clearedFeatures = {};

  /// [f] engelini kalıcı olarak kaldırır (yollar anında açılır).
  void clearFeature(TerrainFeature f) {
    clearedFeatures.add(f);
    grid.openDug(clearedFeatures);
  }


  /// Haritadaki tüm birimler (bileşenler kendilerini kaydeder/siler).
  final List<UnitComponent> units = [];

  /// "Yakınımdaki birimler" sorguları için ayrık ızgara (her karede yenilenir).
  final SpatialGrid spatialGrid = SpatialGrid();

  /// Tüm dokunma/sürükleme kontrolleri (onLoad'da eklenir).
  late final InputController inputController;

  /// Yuva panelinde seçili çıkarma oranı (%25/%50/%75/%100).
  final ValueNotifier<double> deployFraction = ValueNotifier(0.5);

  /// Yuva panelinde seçili asker tipi (null = tümü).
  final ValueNotifier<UnitType?> deployType = ValueNotifier(null);

  /// İnsan oyuncunun yetenek slotları (1-3). Sefer görevinde SABİTTİR;
  /// normal maçta menüdeki loadout kopyalanır.
  late final List<AbilityType> humanAbilities =
      List.of(gameState.mission?.loadout ?? gameState.abilityLoadout);

  /// Slot başına kalan dolum süresi (0 = hazır).
  /// Maç başında DOLU başlar: yetenekler süreleri dolunca açılır.
  late final List<double> abilityCooldowns = [
    for (final t in humanAbilities) abilitySpecs[t]!.cooldown,
  ];

  /// Maç başı geri sayımı (5→0): sırasında simülasyon donuk, emir verilemez.
  double countdown = 3.0;

  final FpsComponent _fpsCounter = FpsComponent();

  /// Oyuncu başına kesirli gelir birikimi (pasif + kaynak binaları).
  final Map<int, double> _incomeAccumulators = {};

  /// Kare sayacı — birim ayrışması dönüşümlü (yarı yarıya) çalışır.
  int frameNo = 0;

  /// Maç süresi ve insan oyuncunun ele geçirme sayacı (istatistik).
  double matchDuration = 0;
  int _humanCaptures = 0;

  /// Oyuncu başına bina ele geçirme sayısı (LAN karneleri için).
  final Map<int, int> captureCounts = {};

  /// GÜÇ GRAFİĞİ: her 5 sn'de oyuncu başına savaş gücü örneği —
  /// maç sonunda "kim ne zaman öne geçti" çizgisi çizilir.
  final List<List<int>> strengthHistory = [];
  double _historyTimer = 0;

  void _sampleStrength(double dt) {
    _historyTimer -= dt;
    if (_historyTimer > 0) return;
    _historyTimer = 5;
    if (strengthHistory.length >= 240) return; // ~20 dk tavan
    strengthHistory.add([
      for (final p in gameState.players) battleStrength(p).round(),
    ]);
  }

  /// HUD'daki uçan "-maliyet" yazıları için son harcamalar.
  final List<(int, DateTime)> recentSpends = [];

  void registerSpend(int amount) {
    recentSpends.add((amount, DateTime.now()));
    if (recentSpends.length > 6) recentSpends.removeAt(0);
  }

  /// HUD'daki uçan "+ödül" yazıları (akrep ödülü vb.).
  final List<(int, DateTime)> recentGains = [];

  void registerGain(int amount) {
    recentGains.add((amount, DateTime.now()));
    if (recentGains.length > 4) recentGains.removeAt(0);
  }

  /// [player]ın ordu tavanı (yuva seviyesine bağlı).
  int armyCap(Player player) =>
      nests[player.id]?.armyCap ?? kArmyCap;

  /// [player]ın toplam ordusu: yuva garnizonu + sahadaki birimler.
  int armySize(Player player) {
    var n = nests[player.id]?.population ?? 0;
    for (final u in units) {
      if (!u.dead && u.owner.id == player.id) n++;
    }
    return n;
  }

  /// [player]ın toplam SAVAŞ GÜCÜ: saha + garnizon (defensePower toplamı).
  /// Üstteki güç dağılım barı bunu kullanır.
  double battleStrength(Player player) {
    var s = 0.0;
    for (final u in units) {
      if (!u.dead && u.owner.id == player.id) s += u.spec.defensePower;
    }
    final nest = nests[player.id];
    if (nest != null && !nest.destroyed) s += nest.defensePower;
    return s;
  }

  /// [player]ın saniyelik toplam geliri (pasif + kaynak binaları).
  double incomeRate(Player player) {
    var rate = kPassiveIncomePerSec;
    for (final b in buildings) {
      if (b.owner == player) rate += b.incomePerSec;
    }
    return rate;
  }

  double get fps => _fpsCounter.fps;

  /// Haritadaki toplam birim sayısı (debug overlay için).
  int get unitCount => units.length;

  /// Açıkken geçilemez hücreler kırmızıyla gösterilir (debug butonuna bağlı).
  bool debugTerrain = false;

  /// Sis (fog of war). Harita ön izlemeleri/testler için kapatılabilir.
  bool fogEnabled = true;
  late final FogOfWar fog;

  /// Altın açı: çıkarılan askerleri hedef etrafına doğal biçimde saçar.
  static const _goldenAngle = 2.399963;

  @override
  Color backgroundColor() => const Color(0xFF141C0E); // letterbox rengi

  @override
  Future<void> onLoad() async {
    // (0,0) sol üst köşe olacak şekilde kamerayı hizala.
    camera.viewfinder.position = Vector2(kGameWidth / 2, kGameHeight / 2);

    add(_fpsCounter);

    // Performans: karınca kareleri GPU dokusuna alınır.
    await AntSpriteCache.instance.ensureLoaded();

    map = gameState.map!;
    grid = PassabilityGrid.fromMap(map);
    pathfinder = Pathfinder(grid);

    mapComponent = MapComponent(map: map, grid: grid)..priority = -10;
    world.add(mapComponent);
    world.add(TerritoryComponent()); // bölge sınırları (priority -8)
    fog = FogOfWar();
    world.add(fog);
    inputController = InputController();
    world.add(inputController);

    // Harita öğeleri: kazı geçitleri + yaban arısı yuvaları.
    for (final f in map.features) {
      switch (f.kind) {
        case TerrainKind.digsite:
          final site = DigSite(f);
          digSites.add(site);
          world.add(DigSiteComponent(site: site));
        case TerrainKind.waspNest:
          final wasp = WaspNestComponent(
              feature: f, position: f.points.first, radius: f.width / 2);
          waspNests.add(wasp);
          world.add(wasp);
        default:
          break;
      }
    }

    // YAĞMACI AKREPLER: haritanın nötr canavarları.
    for (final spot in map.scorpionSpots) {
      final sc = ScorpionComponent(home: spot);
      scorpions.add(sc);
      world.add(sc);
    }
    for (final spot in map.raiderCampSpots) {
      final camp = RaiderCampComponent(position: spot.clone());
      raiderCamps.add(camp);
      world.add(camp);
    }

    // Nötr binalar.
    for (var i = 0; i < map.buildingSpots.length; i++) {
      final building = Building(
        position: map.buildingSpots[i],
        type: map.buildingTypes[i],
      );
      buildings.add(building);
      world.add(BuildingComponent(building: building));
    }
    // ORDU KATMANI: tüm karıncalar tek drawRawAtlas ile (binaların üstü,
    // birim ekstralarının/yuvaların altı).
    world.add(ArmyLayer());

    // Oyuncuları yuva noktalarına dağıt.
    // 2v2: müttefikler AYNI TARAFTA doğar (sol/sağ yarı rastgele seçilir).
    List<Vector2> spots;
    if (gameState.mission != null) {
      // SEFER: karıştırma yok — İLK yuva noktası OYUNCUNUNDUR
      // (görev haritaları buna göre tasarlanır).
      spots = List.of(map.nestSpots);
    } else if (gameState.teamMode) {
      final left = map.nestSpots.where((s) => s.x < kGameWidth / 2).toList()
        ..shuffle(_rng);
      final right = map.nestSpots.where((s) => s.x >= kGameWidth / 2).toList()
        ..shuffle(_rng);
      final teamZeroLeft = _rng.nextBool();
      final t0 = teamZeroLeft ? left : right;
      final t1 = teamZeroLeft ? right : left;
      // Oyuncu sırası: [t0, t0, t1, t1] (takım 0 = ilk iki oyuncu).
      spots = [t0[0], t0[1], t1[0], t1[1]];
    } else if (map.fixedNests) {
      // Sabit senaryo (İnka Yolu): İLK yuva noktası insanındır.
      spots = List.of(map.nestSpots);
    } else {
      spots = List.of(map.nestSpots)..shuffle(_rng);
    }
    for (var i = 0; i < gameState.players.length; i++) {
      final player = gameState.players[i];
      final nest = Nest(owner: player, position: spots[i]);
      nests[player.id] = nest;
      // Karıncaların ALTINDA kalır (askerler tümseğin önünden geçer;
      // eskiden 10'du ve ordu ana yuvanın arkasında kayboluyordu).
      world.add(NestComponent(nest: nest)..priority = -1);
    }

    // HAYATTA KALMA: yabani kaynak kolonisinin yuvası baştan yıkıktır
    // (dalgalar haritanın kenarlarından gelir, yuvadan değil).
    if (gameState.horde) {
      for (final p in gameState.players) {
        if (p.eliminated) nests[p.id]?.queenHp = 0;
      }
    }

    // Bot beyinleri (yuvalar kurulduktan sonra).
    // EĞİTİMDE rakip beyinsizdir: oyuncu rahatça öğrenir.
    // LAN İSTEMCİSİNDE bot beyni kurulmaz — botları yalnız HOST simüle eder.
    if (!gameState.tutorial && !gameState.horde && !isNetClient) {
      for (final player in gameState.players) {
        if (player.isBot) bots.add(BotController(this, player));
      }
    }

    // SEFER destekleri: başlangıç altını, hediye binalar, düşman altını.
    final mission = gameState.mission;
    if (mission != null) {
      gameState.humanPlayer?.resources = mission.gold;
      for (final bi in mission.ownedBuildings) {
        if (bi >= 0 && bi < buildings.length) {
          buildings[bi].owner = gameState.humanPlayer;
        }
      }
      if (mission.enemyGold != null) {
        for (final p in gameState.players) {
          if (p.isBot) p.resources = mission.enemyGold!;
        }
      }
    }

    if (gameState.tutorial) {
      // Öğretici kolaylıkları: bol kaynak, zayıf rakip, ilk güç HAZIR.
      gameState.humanPlayer?.resources = 350;
      for (final nest in nests.values) {
        if (nest.owner.isBot) {
          nest.garrison
            ..clear()
            ..[UnitType.fire] = 4;
        }
      }
      abilityCooldowns[0] = 0;
    }
  }

  /// Sahne gerçekten çizilmeye başladı mı? (Yükleme sırasında siyah ekranda
  /// geri sayım BAŞLAMAZ — harita tam görününce 3-2-1 başlar.)
  bool _sceneReady = false;

  @override
  void update(double dt) {
    if (gameState.phase == GamePhase.playing && countdown > 0) {
      // Bileşenler monte olsun ve HARİTA GÖRÜNSÜN diye super.update çalışır;
      // oyun MANTIĞI (ekonomi/üretim/botlar/ele geçirme — aşağısı) donuktur,
      // emir/yetenek girişleri de countdown korumasıyla kilitlidir.
      super.update(dt);
      if (!_sceneReady) {
        // İlk update turunda dünya çocukları monte olur; sayım bir sonraki
        // kareden (harita ekrandayken) itibaren işler.
        _sceneReady = world.children.isNotEmpty;
        if (_sceneReady) AudioController.countTick(); // ilk rakam: 3
        return;
      }
      final before = countdown;
      countdown -= dt;
      // Her yeni rakamda tik; sıfıra inince SAVAŞ! borusu.
      if (countdown > 0 && countdown.ceil() != before.ceil()) {
        AudioController.countTick();
      } else if (before > 0 && countdown <= 0) {
        AudioController.countGo();
      }
      return;
    }
    super.update(dt);
    if (gameState.phase != GamePhase.playing) {
      // Maç bitti: gerilim davulları yumuşakça sussun.
      AudioController.updateBattle(dt, false);
      return;
    }

    matchDuration += dt;
    frameNo++;
    if (_hapticCooldown > 0) _hapticCooldown -= dt;
    spatialGrid.rebuild(units.where((u) => !u.dead));
    for (var i = 0; i < abilityCooldowns.length; i++) {
      if (abilityCooldowns[i] > 0) abilityCooldowns[i] -= dt;
    }

    // LAN İSTEMCİSİ: simülasyon YOK — host'un durum yayını uygulanır,
    // geri kalan her şey (ekonomi/savaş/botlar) host'ta döner.
    if (isNetClient) {
      netClient!.applyPending();
      _tickBattleMusic(dt);
      return;
    }

    _tickEconomy(dt);
    _tickCapture(dt);
    _tickDigSites(dt);
    for (final nest in nests.values) {
      nest.updateProduction(dt);
    }
    _tickAutoDefense(dt);
    for (final bot in bots) {
      bot.update(dt);
    }
    _tickBattleMusic(dt);
    _sampleStrength(dt);
    if (gameState.horde) _tickHorde(dt);
    _checkElimination();
    netHost?.tick(dt); // LAN HOST: 10 Hz durum yayını
  }

  double _combatScanTimer = 0;
  double _lastCombatAgo = 99;

  /// Çatışma gerilim müziği: sahada süren bir savaş varsa davullar girer,
  /// savaş bitince ~2.5 sn içinde yumuşakça söner.
  void _tickBattleMusic(double dt) {
    _combatScanTimer -= dt;
    _lastCombatAgo += dt;
    if (_combatScanTimer <= 0) {
      _combatScanTimer = 0.4;
      var engaged = 0;
      for (final u in units) {
        if (!u.dead && u.inCombat && ++engaged >= 2) break;
      }
      if (engaged >= 2) _lastCombatAgo = 0;
    }
    AudioController.updateBattle(dt, _lastCombatAgo < 2.5);
  }

  double _autoDefTimer = 0;

  /// TİTREŞİM: yuva saldırı uyarısı arası en az 4 sn (spam olmasın).
  double _hapticCooldown = 0;

  void _nestThreatHaptic() {
    if (!appSettings.vibration || _hapticCooldown > 0) return;
    _hapticCooldown = 4;
    HapticFeedback.heavyImpact();
  }

  /// OTOMATİK YUVA SAVUNMASI: düşman ana yuvanın dibine gelirse garnizon
  /// kendiliğinden dışarı fırlar ve savaşır. Tehdit sürdükçe YENİ üretilen
  /// askerler de (garnizona girer girmez) otomatik çıkar. Tüm oyuncular
  /// için geçerlidir.
  void _tickAutoDefense(double dt) {
    _autoDefTimer -= dt;
    if (_autoDefTimer > 0) return;
    _autoDefTimer = 0.5;

    for (final nest in nests.values) {
      if (nest.destroyed || nest.population <= 0) continue;
      // Yuva çevresindeki düşmanların ağırlık merkezi.
      final centroid = Vector2.zero();
      var threats = 0;
      spatialGrid.forEachNear(nest.position, 170, (u) {
        if (u.dead || u.combatTeam == nest.owner.team || u.spawnDelay > 0) {
          return;
        }
        centroid.add(u.position);
        threats++;
      });
      if (threats == 0) continue;
      centroid.scale(1 / threats);
      // Kendi yuvan tehdit altında: kısa titreşim uyarısı (ayara bağlı).
      if (nest.owner.id == gameState.humanPlayer?.id) _nestThreatHaptic();
      deployFromNest(nest, 1.0, centroid);
    }
  }

  double _digScanTimer = 0;

  /// KAZI GEÇİTLERİ: çevresindeki asker çoğunluğu tıkacı kazar (√kalabalık
  /// hızlandırır, ilerleme KALICI). Tam dolunca geçit sonsuza dek açılır.
  void _tickDigSites(double dt) {
    if (digSites.isEmpty) return;
    _digScanTimer -= dt;
    if (_digScanTimer > 0) return;
    final tick = 0.25 - _digScanTimer; // atlanan süre kadar ilerle
    _digScanTimer = 0.25;

    for (final site in digSites) {
      if (site.open) continue;
      final teamCounts = <int, int>{};
      final teamLeader = <int, Player>{};
      var total = 0;
      spatialGrid.forEachNear(site.center, kDigRadius, (u) {
        if (u.dead || u.spawnDelay > 0 || u.owner.eliminated) return;
        total++;
        teamCounts.update(u.owner.team, (c) => c + 1, ifAbsent: () => 1);
        teamLeader.putIfAbsent(u.owner.team, () => u.owner);
      });
      if (teamCounts.isEmpty) continue;
      int? topTeam;
      var topCount = 0;
      teamCounts.forEach((team, count) {
        if (count > topCount) {
          topCount = count;
          topTeam = team;
        }
      });
      final net = topCount - (total - topCount);
      if (net <= 0) continue; // çekişme: kazı duraklar (erimez)
      site.digger = teamLeader[topTeam];
      site.progress += math.sqrt(net.clamp(1, 25).toDouble()) /
          kDigBaseTime *
          tick;
      if (site.progress >= 1) {
        site.progress = 1;
        site.open = true;
        clearFeature(site.feature);
        if (fog.isVisible(site.center)) AudioController.capture();
      }
    }
  }

  /// Bina ele geçirme: yarıçap içindeki asker sayılarına göre halkalar dolar.
  /// PERFORMANS: sayım her karede değil ~0.12 sn'de bir yapılır (dt
  /// birikir, doluş hızı DEĞİŞMEZ) — kalabalık maçta bina×komşu taraması
  /// kare bütçesini yemesin.
  double _captureAcc = 0;

  void _tickCapture(double dt) {
    _captureAcc += dt;
    if (_captureAcc < 0.12) return;
    dt = _captureAcc;
    _captureAcc = 0;
    for (final building in buildings) {
      final counts = <Player, int>{};
      spatialGrid.forEachNear(building.position, kCaptureRadius, (u) {
        // Yabani (elenmiş kolonilerin) askerleri bina ELE GEÇİRMEZ.
        if (u.dead || u.owner.eliminated) return;
        counts.update(u.owner, (c) => c + 1, ifAbsent: () => 1);
      });
      final changed = building.updateCapture(dt, counts);
      if (changed) {
        if (building.owner == gameState.humanPlayer) _humanCaptures++;
        final ownerId = building.owner?.id;
        if (ownerId != null) {
          captureCounts.update(ownerId, (c) => c + 1, ifAbsent: () => 1);
        }
        if (fog.isVisible(building.position)) AudioController.capture();
      }
    }
  }

  /// İnsan oyuncunun slot yeteneğini kullanır.
  /// Sisli alanlara da atılabilir (kör atış serbest).
  /// LAN İSTEMCİSİ: yetenek EMİR olarak host'a gider; host uygular ve
  /// fx yayını herkese görselini bastırır.
  bool useHumanAbility(int slot, Vector2? target) {
    if (gameState.phase != GamePhase.playing || countdown > 0) return false;
    final human = gameState.humanPlayer;
    if (human == null || human.eliminated) return false;
    if (abilityCooldowns[slot] > 0) return false;

    final type = humanAbilities[slot];
    final spec = abilitySpecs[type]!;
    if (!spec.global && target == null) return false;
    if (!spec.global && !abilityAllowedAt(human, target)) return false;
    if (isNetClient) {
      netClient!.sendAbility(slot, target);
      abilityCooldowns[slot] = spec.cooldown; // host yayını tazeler
      return true;
    }
    castAbility(this, human, type, target);
    abilityCooldowns[slot] = spec.cooldown;
    return true;
  }

  /// YETENEK YASAK BÖLGESİ: hedefli bir yetenek, HERHANGİ BİR RAKİP ana
  /// yuvasının [kAbilityNestExclusion] yakınına atılamaz — takviyeyle
  /// oto-savunmayı dışarı çekip ateş çemberiyle silme açığını kapatır.
  /// Kendi/müttefik yuvanın dibi serbesttir (savunma yetenekleri yaşar).
  /// İnsan, bot ve LAN emri aynı kuraldan geçer.
  bool abilityAllowedAt(Player caster, Vector2? target) {
    if (target == null) return true;
    for (final nest in nests.values) {
      if (nest.destroyed || nest.owner.eliminated) continue;
      if (nest.owner.team == caster.team) continue;
      if (nest.position.distanceToSquared(target) <
          kAbilityNestExclusion * kAbilityNestExclusion) {
        return false;
      }
    }
    return true;
  }

  /// [player]ın güç binalarından gelen toplam hasar çarpanı (1.0 = bonus yok).
  double powerMultiplier(Player player) {
    var bonus = 0.0;
    for (final b in buildings) {
      if (b.owner == player) bonus += b.powerBonus;
    }
    return 1 + bonus;
  }

  /// Feromon merkezlerinin ZIRH katkısı: [player]ın askerlerinin ALDIĞI
  /// hasar bu çarpanla küçülür (azaltma tavanı %25 — yığılsa da asker
  /// ölümsüzleşmez).
  double powerArmorMultiplier(Player player) {
    var reduce = 0.0;
    for (final b in buildings) {
      if (b.owner == player) reduce += b.powerArmor;
    }
    return 1 - math.min(0.25, reduce);
  }

  /// İNSAN girişinden gelen çıkarma isteği: LAN istemcisinde emir olarak
  /// host'a gider, yoksa doğrudan uygulanır (InputController bunu çağırır;
  /// bot/otomatik savunma [deployFromNest]'i doğrudan kullanır).
  /// [exit] verilirse (kuluçkadan tut-sürükle) askerler o noktadan iner.
  void requestDeploy(Nest nest, double fraction, Vector2 target,
      {Vector2? exit}) {
    if (isNetClient) {
      if (nest.destroyed || countdown > 0) return;
      if (nest.population > 0) AudioController.deploy();
      netClient!.sendDeploy(fraction, target.x, target.y, exit: exit);
      return;
    }
    deployFromNest(nest, fraction, target, exitOverride: exit);
  }

  /// ANA YUVA YÜKSELTMESİ satın alımı (insan/bot/LAN host ortak):
  /// sıradaki kademeyi alır (1: 500 → hız ×2, 2: 1000 → anında üretim).
  bool buyNestUpgrade(Player p) {
    final nest = nests[p.id];
    if (nest == null || nest.destroyed || nest.upgradeLevel >= 2) {
      return false;
    }
    final cost =
        nest.upgradeLevel == 0 ? kNestUpgradeCost : kNestUpgrade2Cost;
    if (p.resources < cost) return false;
    p.resources -= cost;
    nest.upgradeLevel++;
    return true;
  }

  /// İNSAN girişinden gelen yuva yükseltme isteği (500 altın →
  /// üretim hızı 2 kat; tek seferlik).
  bool requestNestUpgrade() {
    final human = gameState.humanPlayer;
    final nest = human == null ? null : nests[human.id];
    if (human == null ||
        nest == null ||
        nest.destroyed ||
        nest.upgradeLevel >= 2) {
      return false;
    }
    final cost =
        nest.upgradeLevel == 0 ? kNestUpgradeCost : kNestUpgrade2Cost;
    if (isNetClient) {
      if (human.resources < cost) return false;
      netClient!.sendNestUpgrade();
      nest.upgradeLevel++; // his; kaynak host yayınından senkronlanır
      registerSpend(cost);
      AudioController.produce();
      return true;
    }
    if (!buyNestUpgrade(human)) return false;
    registerSpend(cost);
    AudioController.produce();
    return true;
  }

  /// İNSAN girişinden gelen üretim isteği (HUD üretim butonları).
  bool requestProduce(UnitType type) {
    final human = gameState.humanPlayer;
    final nest = human == null ? null : nests[human.id];
    if (human == null || nest == null || nest.destroyed) return false;
    final spec = unitSpecs[type]!;
    if (isNetClient) {
      // Kaynak/tavan görünümü host yayınından senktir; yerel ön kontrol
      // yeterli (host yine de doğrular).
      if (human.resources < spec.cost) return false;
      netClient!.sendProduce(type.index);
      return true;
    }
    return nest.enqueue(type);
  }

  /// Yuvadan asker çıkarır ve hedefe yürütür.
  /// Askerler sırayla çıkar (spawnDelay) ve hedef etrafına doğal saçılır.
  void deployFromNest(
    Nest nest,
    double fraction,
    Vector2 target, {
    UnitType? only,
    Vector2? exitOverride,
  }) {
    if (nest.destroyed || countdown > 0) return;
    final taken = nest.takeOut(fraction, only: only);
    if (taken.isNotEmpty && nest.owner == gameState.humanPlayer) {
      AudioController.deploy();
    }
    // İKİNCİ ÇIKIŞ: kuluçkadan tut-sürükle ise O kuluçka; yoksa hedefe
    // yuvadan daha yakın kuluçka seçilir (üretim yine yuvadadır).
    var exit = nest.position;
    if (exitOverride != null) {
      // Güvenlik (LAN emri de buradan geçer): yalnız SAHİP OLUNAN bir
      // kuluçkanın üstü kabul edilir; değilse normal seçim sürer.
      for (final b in buildings) {
        if (b.type == BuildingType.hatchery &&
            b.owner?.id == nest.owner.id &&
            b.position.distanceToSquared(exitOverride) < 48 * 48) {
          exit = b.position;
          break;
        }
      }
    }
    if (exit == nest.position) {
      var exitD = exit.distanceToSquared(target);
      for (final b in buildings) {
        if (b.type != BuildingType.hatchery ||
            b.owner?.id != nest.owner.id) {
          continue;
        }
        final d = b.position.distanceToSquared(target);
        if (d < exitD) {
          exitD = d;
          exit = b.position;
        }
      }
    }
    // PERFORMANS: rota ÇIKIŞ→HEDEF için BİR kez hesaplanır, çıkan her
    // asker onu paylaşır — eskiden 100 askerlik çıkarma 100 özdeş A*
    // koşturuyordu (büyük çıkarmalardaki takılmanın ana kaynağı).
    final route = pathfinder.findPath(exit, grid.nearestOpen(target));
    var i = 0;
    taken.forEach((type, count) {
      for (var n = 0; n < count; n++) {
        final exitAngle = _rng.nextDouble() * 2 * math.pi;
        final spawnPos = exit +
            Vector2(math.cos(exitAngle), math.sin(exitAngle)) * 18;
        final scatter = Vector2(
          math.cos(_goldenAngle * i),
          math.sin(_goldenAngle * i),
        )..scale(9 * math.sqrt(i.toDouble()));
        final unit = UnitComponent(
          type: type,
          owner: nest.owner,
          position: grid.nearestOpen(spawnPos),
          spawnDelay: i * 0.12,
        );
        units.add(unit); // anında say (onMount bir kare sonra gelir)
        world.add(unit);
        unit.orderMoveShared(route, target + scatter);
        i++;
      }
    });
  }

  /// Gelir: herkese eşit pasif akış + sahip olunan kaynak binaları.
  void _tickEconomy(double dt) {
    for (final player in gameState.players) {
      if (player.eliminated) continue;
      var rate = kPassiveIncomePerSec;
      for (final b in buildings) {
        if (b.owner == player) rate += b.incomePerSec;
      }
      final acc = (_incomeAccumulators[player.id] ?? 0) + dt * rate;
      final whole = acc.floor();
      _incomeAccumulators[player.id] = acc - whole;
      player.resources += whole;
      player.goldEarned += whole; // maç sonu çizelgesi
    }
  }

  // ------------------------------------------------ HAYATTA KALMA (Horde)

  /// Mevcut dalga numarası (1'den başlar; HUD gösterir).
  int hordeWave = 0;

  /// Sonraki dalgaya kalan süre.
  double hordeNextIn = 12; // ilk dalga: hazırlık payı

  /// Son gelen dalganın kadro sayısı (HUD gösterir).
  int hordeLastCount = 0;

  /// DALGA YÖNETİCİSİ: gittikçe sıklaşan ve güçlenen yabani dalgaları
  /// haritanın kenarlarından üretir; hedef her zaman oyuncunun yuvasıdır.
  void _tickHorde(double dt) {
    hordeNextIn -= dt;
    if (hordeNextIn > 0) return;

    hordeWave++;
    gameState.lastHordeWave = hordeWave;
    // Aralık 24 sn'den 13 sn'ye iner (nefes payı); kadro her dalgada büyür.
    hordeNextIn = math.max(13, 24 - hordeWave * 1.0);
    var count = math.min(4 + hordeWave * 2, 26);

    // Performans tavanı: sahada 130'dan fazla yabani varken dalga küçülür.
    final alive = units
        .where((u) => !u.dead && u.owner.eliminated)
        .length;
    if (alive > 130) count = math.min(count, 6);
    hordeLastCount = count;

    final feral = gameState.players.firstWhere((p) => p.eliminated);
    final target = nests[gameState.humanPlayer?.id ?? 0]!.position;
    for (var i = 0; i < count; i++) {
      // Kenardan doğuş: rastgele kenar + kenar boyunca rastgele nokta.
      final side = _rng.nextInt(4);
      final t = _rng.nextDouble();
      final edge = switch (side) {
        0 => Vector2(20 + t * (kGameWidth - 40), 16),
        1 => Vector2(20 + t * (kGameWidth - 40), kGameHeight - 16),
        2 => Vector2(16, 20 + t * (kGameHeight - 40)),
        _ => Vector2(kGameWidth - 16, 20 + t * (kGameHeight - 40)),
      };
      // Kadro dalga ilerledikçe sertleşir.
      final roll = _rng.nextDouble();
      final type = hordeWave < 3
          ? UnitType.fire
          : hordeWave < 6
              ? (roll < 0.6 ? UnitType.fire : UnitType.wood)
              : roll < 0.4
                  ? UnitType.fire
                  : roll < 0.65
                      ? UnitType.wood
                      : roll < 0.85
                          ? UnitType.trapjaw
                          : UnitType.leafcutter;
      final unit = UnitComponent(
        type: type,
        owner: feral,
        position: grid.nearestOpen(edge),
        spawnDelay: i * 0.08,
      );
      units.add(unit);
      world.add(unit);
      unit.orderMove(target +
          Vector2(_rng.nextDouble() * 80 - 40, _rng.nextDouble() * 80 - 40));
    }
    if (appSettings.vibration) HapticFeedback.mediumImpact();
    AudioController.countGo(); // dalga borusu
  }

  /// Kraliçesi ölen oyuncu elenir; insan elenirse yenilgi,
  /// tüm botlar elenirse zafer.
  void _checkElimination() {
    var changed = false;
    for (final player in gameState.players) {
      if (!player.eliminated && nests[player.id]!.destroyed) {
        player.eliminated = true;
        changed = true;
        // YIKILAN KOLONİ: binaları NÖTRE döner (bayrak solar), sahadaki
        // askerleri YABANİLEŞİR (combatTeam) — herkes onlara düşmandır.
        for (final b in buildings) {
          if (b.owner?.id == player.id) {
            b.owner = null;
            b.captureProgress = 0;
            b.capturingPlayer = null;
          }
        }
      }
    }
    if (!changed && !gameState.horde) return;

    // HAYATTA KALMA: zafer yok — kraliçe düşene dek dayan; süre = skor.
    if (gameState.horde) {
      final human = gameState.humanPlayer;
      if (human == null || !human.eliminated) return;
      gameState.lastStats = MatchStats(
        duration: matchDuration,
        unitsProduced: nests[human.id]!.producedCount,
        buildingsCaptured: _humanCaptures,
      );
      gameState.lastPlayerStats = [
        for (final p in gameState.players)
          if (!p.isBot)
            PlayerMatchStats(
              color: p.color,
              isHuman: true,
              ally: false,
              eliminated: true,
              produced: nests[p.id]?.producedCount ?? 0,
              goldEarned: p.goldEarned,
              buildings:
                  buildings.where((b) => b.owner?.id == p.id).length,
              unitsLost: p.unitsLost,
            ),
      ];
      gameState.totalBuildings = buildings.length;
      gameState.lastStrengthHistory = List.of(strengthHistory);
      gameState.endMatch(humanWon: false);
      return;
    }

    // LAN HOST: maç yalnız TEK takım kalınca biter — elenmiş host bile
    // simülasyona devam eder (seyirci). Sonu köprü ilan eder (yayın + karne).
    if (isNetHost) {
      netHost!.checkMatchEnd();
      return;
    }

    final human = gameState.humanPlayer;
    if (human == null) return;
    // Zafer: düşman TAKIM(lar)ın tamamı elendi. Yenilgi: insan elendi.
    final enemiesGone = gameState.players
        .where((p) => p.team != human.team)
        .every((p) => p.eliminated);
    if (human.eliminated || enemiesGone) {
      gameState.lastStats = MatchStats(
        duration: matchDuration,
        unitsProduced: nests[human.id]!.producedCount,
        buildingsCaptured: _humanCaptures,
      );
      // MAÇ SONU ÇİZELGESİ: her oyuncunun karnesi.
      gameState.lastPlayerStats = [
        for (final p in gameState.players)
          PlayerMatchStats(
            color: p.color,
            isHuman: !p.isBot,
            ally: p.team == human.team && p.id != human.id,
            eliminated: p.eliminated,
            produced: nests[p.id]?.producedCount ?? 0,
            goldEarned: p.goldEarned,
            buildings: buildings.where((b) => b.owner?.id == p.id).length,
            unitsLost: p.unitsLost,
          ),
      ];
      gameState.totalBuildings = buildings.length;
      gameState.lastStrengthHistory = List.of(strengthHistory);
      gameState.endMatch(humanWon: !human.eliminated && enemiesGone);
    }
  }
}
