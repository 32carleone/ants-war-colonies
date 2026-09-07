import 'dart:math' as math;

import 'package:flame/components.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/counters.dart';
import '../data/units.dart';
import '../models/building.dart';
import '../models/nest.dart';
import '../models/player.dart';
import 'ability_effects.dart';
import 'ants_wars_game.dart';
import '../data/i18n.dart';
import 'game_state.dart';
import 'unit_component.dart';

/// Zorluk parametreleri: kaynak hilesi YOK — fark tepki hızı ve akılda.
class BotParams {
  const BotParams({
    required this.decisionInterval,
    required this.reserve,
    required this.attackThreshold,
    required this.squadSize,
    required this.upgrades,
    required this.abilityChance,
    required this.counterSmart,
    required this.strategic,
    required this.wingSize,
    required this.maxBuildLevel,
    required this.homeGuard,
    this.openingSecs = 80,
    this.tier = 1,
  });

  /// İki karar arasındaki süre (sn) — kolay bot yavaş düşünür.
  final double decisionInterval;

  /// Harcamadan elde tutulan kaynak (kolay bot para israf eder).
  final int reserve;

  /// Saldırıya çıkmak için gereken garnizon.
  final int attackThreshold;

  /// Genişleme kolu büyüklüğü (bundan az garnizonla kol çıkarmaz).
  final int squadSize;

  /// Bina yükseltmesi yapar mı.
  final bool upgrades;

  /// Koşulları oluşan yeteneği kullanma olasılığı.
  final double abilityChance;

  /// Gördüğü düşman ordusuna counter üretir mi.
  final bool counterSmart;

  /// Plan katmanı: toplanma noktası, çift kanat, art arda dalga,
  /// stratejik nöbet. Kolay bot düz oynar (false).
  final bool strategic;

  /// Çift kanat için kanat başına asgari asker.
  final int wingSize;

  /// GELİŞME ODAĞI: botun binaları çıkarabileceği en yüksek seviye
  /// (normal bot son seviyeye ÇEKMEZ, zor bot sonuna kadar gider).
  final int maxBuildLevel;

  /// ANA ÜS KORUMASI: hücum/keşif çıkarımlarında garnizonda her zaman
  /// bırakılan muhafız sayısı (yuva düşerse maç biter!). Savunma bunun
  /// dışındadır — tehditte garnizon tam boşalır.
  final int homeGuard;

  /// AÇILIŞ EVRESİ (sn): maçın başında botun İLK hedefi haritaya
  /// yayılmak ve gelişmektir — bu süre (ve 5'ten az binası) boyunca
  /// taarruz planı/ilerleme kurmaz, düşman tarafına kol sürmez
  /// (savunma her zaman serbest). Erken intihar hücumlarının kapanışı.
  final double openingSecs;

  /// ZORLUK BASAMAĞI (0 kolay, 1 normal, 2 zor, 3 kâbus): davranış
  /// kapıları (bölge/çekişme cezaları, çift kol genişleme, yükseltme
  /// turu sayısı, nöbet dozu, stratejik vuruş oranı) bu basamağa bakar —
  /// kâbus ayrıcalıkları zora da iner, kâbus bir kademe daha sivrilir.
  final int tier;

}

BotParams botParamsFor(Difficulty d) => switch (d) {
      Difficulty.easy => const BotParams(
          decisionInterval: 4.0,
          reserve: 60,
          attackThreshold: 20,
          squadSize: 8,
          upgrades: false,
          abilityChance: 0.3,
          counterSmart: false,
          strategic: false,
          wingSize: 6,
          maxBuildLevel: 1,
          homeGuard: 0,
          openingSecs: 100,
          tier: 0,
        ),
      // NORMAL/ZOR/KÂBUS: davranış BİREBİR aynı tam programdır (açılış
      // yayılması, yükseltme birikimi, kişilik kültürü, stratejik vuruş).
      // Fark yalnız botların BAŞLANGIÇ PARASINDA: normal ×1, zor ×1.5,
      // kâbus ×3 (startMatch'te uygulanır; açık kural, gelir hilesi yok).
      Difficulty.normal ||
      Difficulty.hard ||
      Difficulty.nightmare =>
        const BotParams(
          decisionInterval: 1.25,
          reserve: 0,
          attackThreshold: 9,
          squadSize: 5,
          upgrades: true,
          abilityChance: 1.0,
          counterSmart: true,
          strategic: true,
          wingSize: 5,
          maxBuildLevel: 4,
          homeGuard: 8,
          openingSecs: 65,
          tier: 2,
        ),
    };

/// BOT KİŞİLİĞİ: her maçta her bota RASTGELE bir karakter verilir —
/// maçlar tekdüzeleşmez, botlar "aynı bot" gibi oynamaz. Kişilik zorluk
/// parametrelerinin ÜSTÜNE çarpan/önyargı bindirir (kaynak hilesi yok).
class BotPersona {
  const BotPersona({
    required this.name,
    this.nameEn = '',
    this.econW = 1, // yayılma/yükseltmede çiftlik iştahı
    this.towerW = 1, // kule iştahı
    this.powerW = 1, // güç binası iştahı
    this.aggression = 1, // saldırı eşiği çarpanı (küçük = erken saldırır)
    this.expandCooldown = 6, // iki genişleme kolu arası (sn)
    this.expandNeed = 1, // genişleme için garnizon şartı çarpanı
    this.expandFrac = 0.55, // genişleme koluna ayrılan garnizon oranı
    this.extraGuard = 0, // homeGuard'a eklenen muhafız
    this.defRadius = 170, // yuva savunma alarmı yarıçapı
    this.upgradeReserve = 40, // yükseltme sonrası elde kalması gereken para
    this.extraWaves = 0, // taarruz sonrası ek dalga sayısı
    this.abilityMul = 1, // yetenek kullanma isteği çarpanı
    this.fireW = 1, // üretim karışımı ağırlıkları
    this.woodW = 1,
    this.trapW = 1,
    this.leafW = 1,
    this.raidsEconomy = false, // ilerleme düşman EKONOMİSİNİ hedefler
    this.bravado = false, // düşman bölgesindeki binalardan çekinmez
  });

  final String name;
  final String nameEn;

  /// Aktif dile göre görünen ad (rozet/karşılaşma bilgisi).
  String get label => isEnglish && nameEn.isNotEmpty ? nameEn : name;

  final double econW, towerW, powerW;
  final double aggression;
  final double expandCooldown, expandNeed, expandFrac;
  final int extraGuard;
  final double defRadius;
  final int upgradeReserve;
  final int extraWaves;
  final double abilityMul;
  final double fireW, woodW, trapW, leafW;
  final bool raidsEconomy;
  final bool bravado;
}

/// SEFER görevlerinde kullanılan dengeli karakter (görevler buna göre
/// ayarlandı — rastgelelik görev zorluğunu bozmasın).
const BotPersona kBalancedPersona =
    BotPersona(name: 'Komutan', nameEn: 'Commander');

/// 10 kişilik havuzu — maç başında karıştırılır, botlara sırayla dağıtılır
/// (aynı maçta iki bot aynı karakteri almaz; 10 bota kadar benzersiz).
const List<BotPersona> botPersonas = [
  kBalancedPersona, // 1 — Komutan: dengeli okul kitabı oyunu
  BotPersona( // 2 — Vali: ekonomi kurar, geç ama zengin vurur
    name: 'Vali', nameEn: 'Governor',
    econW: 1.7, towerW: 0.8, powerW: 0.7,
    aggression: 1.4, expandCooldown: 4.5, expandFrac: 0.6,
    upgradeReserve: 10, fireW: 1.4, woodW: 1, trapW: 0.6, leafW: 0.8,
  ),
  BotPersona( // 3 — Kale: evini korur, kulelere yatırır, taş gibi bekler
    name: 'Kale', nameEn: 'Bastion',
    towerW: 1.7, econW: 1.2, aggression: 1.5,
    extraGuard: 6, defRadius: 280, expandNeed: 1.2, upgradeReserve: 25,
    woodW: 1.4, leafW: 1.3, trapW: 0.6,
  ),
  BotPersona( // 4 — Cengaver: erken ve sürekli saldırır, gelişimi umursamaz
    name: 'Cengaver', nameEn: 'Berserker',
    aggression: 0.6, upgradeReserve: 70, expandFrac: 0.4,
    extraWaves: 1, abilityMul: 1.2, fireW: 1.5, trapW: 1.4, leafW: 0.6,
  ),
  BotPersona( // 5 — Kolonici: haritayı hızla kaplar, her binayı ister
    name: 'Kolonici', nameEn: 'Colonizer',
    expandCooldown: 3.5, expandNeed: 0.6, expandFrac: 0.7,
    econW: 1.35, aggression: 1.2,
  ),
  BotPersona( // 6 — Kuşatmacı: kuleleri kapar ve boğazları tutar
    name: 'Kuşatmacı', nameEn: 'Besieger',
    towerW: 1.9, defRadius: 220, aggression: 1.15,
    woodW: 1.5, leafW: 1.2,
  ),
  BotPersona( // 7 — Komando: kapan çene baskınlarıyla ekonomi avlar
    name: 'Komando', nameEn: 'Commando',
    raidsEconomy: true, bravado: true, aggression: 0.85,
    expandFrac: 0.4, trapW: 2, woodW: 1.2, leafW: 0.5,
  ),
  BotPersona( // 8 — Sürü Lordu: ucuz kalabalık + bitmeyen dalgalar
    name: 'Sürü Lordu', nameEn: 'Swarm Lord',
    fireW: 2.4, trapW: 0.7, woodW: 0.6, leafW: 0.4,
    aggression: 0.8, extraWaves: 1, econW: 1.3, upgradeReserve: 25,
  ),
  BotPersona( // 9 — Teknolojist: güç binaları + seçkin ordu
    name: 'Teknolojist', nameEn: 'Technologist',
    powerW: 1.9, econW: 1.1, aggression: 1.25, upgradeReserve: 15,
    leafW: 1.7, woodW: 1.5, fireW: 0.6, trapW: 0.8,
  ),
  BotPersona( // 10 — Fırsatçı: yetenek düşkünü, cüretkâr sızmalar
    name: 'Fırsatçı', nameEn: 'Opportunist',
    abilityMul: 1.6, bravado: true, raidsEconomy: true,
    aggression: 0.95, expandCooldown: 5,
  ),
];

/// Tek bir bot oyuncunun beyni. Periyodik karar verir:
/// üret → (savun | saldır | genişle). Sise saygılıdır: yalnızca kendi
/// görüş alanındaki bilgiyi kullanır (bina yerleri harita bilgisidir,
/// sahiplikleri ancak görünce öğrenilir).
class BotController {
  BotController(this.game, this.player)
      : nest = game.nests[player.id]!,
        params = botParamsFor(
            game.gameState.mission?.difficulty ?? game.gameState.difficulty),
        // KİŞİLİK: seferde sabit dengeli; normal maçta desteden rastgele
        // (aynı maçtaki botlar FARKLI karakterler alır).
        persona = game.gameState.mission != null
            ? kBalancedPersona
            : game.nextBotPersona() {
    // Botlar aynı karede karar vermesin.
    _decisionTimer = player.id * 0.7;
    // Her botun KENDİ yetenek seti (rastgele 3 farklı güç) —
    // düşman yuvasının yanındaki mini ikonlarda gösterilir.
    // GARANTİ: setin birinde mutlaka bir ÇAĞRI yeteneği (takviye/orman/
    // kesici) olur — bot orduyu anında büyütebilsin.
    final summons = [
      AbilityType.reinforce,
      AbilityType.summonWood,
      AbilityType.summonLeaf,
    ]..shuffle(game.rng);
    final guaranteed = summons.first;
    abilities = [
      guaranteed,
      ...(List.of(AbilityType.values)
            ..remove(guaranteed)
            ..shuffle(game.rng))
          .take(2),
    ]..shuffle(game.rng);
    abilityCooldowns = [
      for (final t in abilities) abilitySpecs[t]!.cooldown,
    ];
  }

  final AntsWarsGame game;
  final Player player;
  final Nest nest;
  final BotParams params;
  final BotPersona persona;

  /// Kişilik bindirilmiş etkin değerler.
  int get _homeGuard => params.homeGuard + persona.extraGuard;

  /// KÂBUS mu? Aynı tier-2 programı oynar ama ×5 parayla ÇOK daha hızlı
  /// asker basar ve açılışta nötr KULELERİ de erkenden söker.
  bool get _nightmare =>
      game.gameState.difficulty == Difficulty.nightmare;
  int get _attackThreshold {
    // ZOR+ basamakta KİŞİLİK kültürü keskinleşir: saldırganlar daha
    // erken, temkinliler daha geç vurur.
    final aggr = params.tier >= 2
        ? math.pow(persona.aggression, 1.35).toDouble()
        : persona.aggression;
    return (params.attackThreshold * aggr).round();
  }
  double get _abilityChance =>
      (params.abilityChance * persona.abilityMul).clamp(0.0, 1.0);

  /// Görülerek öğrenilen düşman yuvaları (oyuncu id'leri).
  final Set<int> knownEnemyNests = {};

  late final List<AbilityType> abilities;
  late final List<double> abilityCooldowns;

  double _decisionTimer = 0;
  double _expandCooldown = 0;
  double _advanceCooldown = 0;

  // ---- SALDIRI PLANI (normal/zor botlar) ----
  /// Toplanma noktası: ordu burada birikir, sonra TOPLUCA vurur.
  Vector2? _stagePoint;

  /// Yürüyen taarruzun hedefi (dalga takibi için).
  Vector2? _strikeTarget;

  /// Plan bütçesi: toplanma/taarruz çok uzarsa plan tazelenir.
  double _planTimer = 0;

  /// Art arda dalga: taarruzdan sonra biriken garnizon da gönderilir.
  int _wavesLeft = 0;
  double _waveTimer = 0;

  /// Stratejik nöbet emirleri arası soğuma.
  double _garrisonCooldown = 0;

  math.Random get _rng => game.rng;

  /// KOL EMRİ: [units] için hedefe TEK rota hesaplanır (kol merkezi →
  /// hedef), herkes onu paylaşır — birim başına A* patlaması yaşanmaz.
  void _marchShared(List<UnitComponent> units, Vector2 target,
      {double scatter = 60}) {
    if (units.isEmpty) return;
    final centroid = Vector2.zero();
    for (final u in units) {
      centroid.add(u.position);
    }
    centroid.scale(1 / units.length);
    final route =
        game.pathfinder.findPath(game.grid.nearestOpen(centroid), target);
    for (final u in units) {
      final dest = game.grid.nearestOpen(target +
          Vector2(_rng.nextDouble() * scatter - scatter / 2,
              _rng.nextDouble() * scatter - scatter / 2));
      u.orderMoveShared(route, dest);
    }
  }

  /// ANA ÜS KORUMALI çıkarım: garnizonda [BotParams.homeGuard] kadar
  /// muhafız bırakır (yuva hiç savunmasız kalmasın). [fraction] kalan
  /// kısmın oranıdır.
  void _deployGuarded(double fraction, Vector2 target, {int? guard}) {
    final pop = nest.population;
    final spare = pop - (guard ?? _homeGuard);
    if (spare <= 0) return;
    game.deployFromNest(nest, fraction * spare / pop, target);
  }

  void update(double dt) {
    if (player.eliminated || nest.destroyed) return;
    for (var i = 0; i < abilityCooldowns.length; i++) {
      if (abilityCooldowns[i] > 0) abilityCooldowns[i] -= dt;
    }
    _expandCooldown -= dt;
    _advanceCooldown -= dt;
    _planTimer -= dt;
    _waveTimer -= dt;
    _garrisonCooldown -= dt;
    _protectCooldown -= dt;
    _convertCooldown -= dt;
    _decisionTimer -= dt;
    if (_decisionTimer > 0) return;
    // KÂBUS AÇILIŞI: ilk 45 sn'de kararlar %40 daha sık — bölge yıldırım
    // hızında kapılır, oyuncu nefes alamadan rakip kurulmuş olur.
    _decisionTimer = params.decisionInterval;
    _tick();
  }

  /// AÇILIŞ EVRESİ: ilk hedef yayılmak/gelişmek — süre dolana (ya da bot
  /// 5 binaya ulaşana) dek taarruz planı ve ilerleme kurulmaz; erken
  /// intihar hücumu yok. Savunma her zaman serbesttir.
  bool get _opening {
    if (game.matchDuration >= params.openingSecs) return false;
    var owned = 0;
    for (final b in game.buildings) {
      if (b.owner?.id == player.id) owned++;
    }
    return owned < 5;
  }

  void _tick() {
    _capturableCache = null; // sahiplikler değişmiş olabilir
    _refreshCaches();
    _updateKnowledge();
    _produce();
    if (_defend()) {
      // Savunma her şeyi böler: toplanma iptal, yürüyen taarruz sürer.
      _stagePoint = null;
      return;
    }
    if (_opening) {
      // Açılış: koru + nöbet tut + yayıl (nöbet küçük kol ister; önce
      // konuşlanır, kalan garnizon yayılmaya akar).
      if (params.strategic) {
        if (params.tier >= 2) _protectAssets();
        _holdStrategicPoints();
      }
      // YELPAZE: garnizon bölünüp birden çok nötr binaya AYNI ANDA kol
      // çıkar (teker teker yayılma bitti); yelpaze çıkmazsa klasik tek
      // hedefli genişleme dener.
      if (params.tier >= 2 && _openingFanOut()) return;
      _expand();
      return;
    }
    if (params.strategic) {
      if (params.tier >= 2) {
        _protectAssets();
        _convertByPersona();
      }
      _holdStrategicPoints();
      // GENİŞLEME ÖNCE: toplanma her tik garnizonu cepheye süpürüyordu,
      // genişleme kolları sıraya hiç giremiyordu (bot maç boyu tek bina
      // almadan savaşıyordu). Önce yayılma payını alır, kalan toplanır.
      _expand();
      _updatePlan();
      if (_stagePoint == null && _strikeTarget == null) _advance();
      return;
    }
    if (_attack()) return;
    _expand();
    _advance();
  }

  // ------------------------------------------------------- saldırı planı

  Nest? _nearestKnownEnemyNest() {
    Nest? best;
    double bestD = double.infinity;
    for (final id in knownEnemyNests) {
      final n = game.nests[id];
      if (n == null || n.destroyed) continue;
      final d = n.position.distanceToSquared(nest.position);
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    return best;
  }

  /// DÜŞMAN STRATEJİK NOKTASI: görünen en değerli rakip binası —
  /// yüksek seviyeli çiftlik/güç önce (taarruz bunu da hedefleyebilir;
  /// düşman yuvası bilinmiyorken plan bununla kurulur).
  Vector2? _strategicEnemyPoint() {
    Building? best;
    var bestScore = 0.0;
    for (final b in game.buildings) {
      if (b.owner == null || b.owner!.team == player.team) continue;
      if (!canSee(b.position)) continue;
      final w = switch (b.type) {
        BuildingType.resource => 1.3,
        BuildingType.power => 1.2,
        BuildingType.hatchery => 1.0,
        BuildingType.tower => 0.7,
      };
      final score = w * (1 + b.level * 0.4);
      if (score > bestScore) {
        bestScore = score;
        best = b;
      }
    }
    return best?.position;
  }

  /// Plan durum makinesi: (yok) → TOPLANMA → TAARRUZ (+dalgalar) → yok.
  void _updatePlan() {
    // TAARRUZ sürüyor: art arda dalga gönder, süre dolunca planı kapat
    // (hedef yuva olmayabilir — stratejik bina vuruşları da plandır).
    final strike = _strikeTarget;
    if (strike != null) {
      if (_planTimer <= 0) {
        _strikeTarget = null;
        return;
      }
      if (_wavesLeft > 0 &&
          _waveTimer <= 0 &&
          nest.population >= params.squadSize) {
        // İKİNCİ DALGA: taze üretim doğrudan hedefe akar.
        _deployGuarded(1.0, strike);
        _wavesLeft--;
        _waveTimer = 7;
      }
      return;
    }

    // TOPLANMA sürüyor: kuvvet biriktir; yeter (ya da süre dolar) → vur.
    final stage = _stagePoint;
    if (stage != null) {
      final massed = _fieldUnits
          .where((u) =>
              !u.inCombat &&
              u.position.distanceToSquared(stage) < 150 * 150)
          .length;
      if (massed >= _attackThreshold || _planTimer <= 0) {
        _launchStrike(stage);
        return;
      }
      // Birikime devam: garnizon + boştaki uzak birimler toplanmaya.
      if (nest.population >= params.squadSize) {
        _deployGuarded(1.0, stage);
      }
      final gatherers = [
        for (final u in _fieldUnits)
          if (!u.inCombat &&
              !u.isMoving &&
              !_isCapturing(u) &&
              u.position.distanceToSquared(stage) >= 150 * 150)
            u,
      ];
      _marchShared(gatherers, stage, scatter: 80);
      return;
    }

    // YENİ PLAN: hedef biliniyorsa ve çekirdek kuvvet varsa toplanmaya
    // geç. Düşman yuvası henüz görülmediyse görünür stratejik binası da
    // plan çapası olur (eskiden bot yuvayı görene dek plansız bekliyordu).
    final anchor =
        _nearestKnownEnemyNest()?.position ?? _strategicEnemyPoint();
    if (anchor == null) return;
    final idle = _fieldUnits.where((u) => !u.inCombat).length;
    if (nest.population + idle < _attackThreshold ~/ 2 + 4) return;
    // FIRSAT PENCERESİ (zor/kâbus): düşman evi zayıf korunuyorsa
    // (ordusu seferde) toplanmayı beklemeden DOĞRUDAN bas — insan
    // "ordumla gezerken üssüm güvende" diyemez.
    if (params.tier >= 2 &&
        nest.population + idle >= _attackThreshold) {
      var guards = 0;
      for (final e in _visibleEnemies) {
        if (e.position.distanceToSquared(anchor) < 260 * 260) guards++;
      }
      if (guards <= 3) {
        _launchStrike(nest.position);
        return;
      }
    }
    _stagePoint = _pickStagePoint(anchor);
    _planTimer = 14; // toplanma bütçesi
  }

  /// Toplanma noktası: hedefe en yakın KENDİ binası (ileri karakol) —
  /// yoksa yuva→hedef hattının kendi tarafındaki %35'i.
  Vector2 _pickStagePoint(Vector2 target) {
    Building? forward;
    var bestD = double.infinity;
    for (final b in game.buildings) {
      if (b.owner?.team != player.team) continue;
      final d = b.position.distanceToSquared(target);
      if (d < bestD) {
        bestD = d;
        forward = b;
      }
    }
    final base = forward?.position ??
        (nest.position + (target - nest.position) * 0.35);
    return game.grid.nearestOpen(base + Vector2(0, -30));
  }

  /// TAARRUZ: toplanan ordu yeterince büyükse ÇİFT KANATTAN, değilse tek
  /// koldan hedefe sürülür; garnizon da katılır, ikinci dalga kurulur.
  void _launchStrike(Vector2 stage) {
    final targetNest = _nearestKnownEnemyNest();
    _stagePoint = null;
    // Hedef seçimi: yuva bilinmiyorsa stratejik bina; KÂBUS ve ekonomi
    // avcıları bazen yuva yerine BİLE BİLE düşman ekonomisini vurur
    // (savunmayı yarmak yerine gelirini keser).
    var target = targetNest?.position;
    if (target == null ||
        ((params.tier >= 2 || persona.raidsEconomy) &&
            _rng.nextDouble() < (persona.raidsEconomy ? 0.55 : 0.3))) {
      target = _strategicEnemyPoint() ?? target;
    }
    if (target == null) return;
    _strikeTarget = target.clone();
    _planTimer = 25;
    // Art arda dalgalar — dalga kültürü KİŞİLİĞİN işidir.
    _wavesLeft = 1 + persona.extraWaves;
    _waveTimer = 6;

    final attackers = _fieldUnits
        .where((u) =>
            !u.inCombat &&
            !_isCapturing(u) &&
            u.position.distanceToSquared(stage) < 170 * 170)
        .toList();
    _deployGuarded(1.0, target);

    if (attackers.length >= params.wingSize * 2) {
      // ÇİFT KANAT: hedefe dik eksende ±90px iki yaklaşım koridoru —
      // kanat başına TEK ortak rota (A* bütçesi: 2 çağrı).
      final dir = target - stage;
      final len = dir.length;
      final u = len < 1 ? Vector2(1, 0) : dir / len;
      final n = Vector2(-u.y, u.x);
      final left = <UnitComponent>[];
      final right = <UnitComponent>[];
      for (var i = 0; i < attackers.length; i++) {
        (i.isEven ? left : right).add(attackers[i]);
      }
      _marchShared(left, game.grid.nearestOpen(target + n * 90),
          scatter: 40);
      _marchShared(right, game.grid.nearestOpen(target - n * 90),
          scatter: 40);
    } else {
      _marchShared(attackers, target);
    }
    _tryAbilities(attackPoint: target);
  }

  double _protectCooldown = 0;
  double _convertCooldown = 0;

  /// KİŞİLİĞE GÖRE DÖNÜŞÜM (zor+): yükseltmeler ilerleyip para artınca
  /// bot, karakterinin İŞTAHINA uymayan bir binasını sevdiği türe çevirir
  /// (Kale kule diker, Vali çiftliğe döner, Teknolojist güce yatırır).
  /// Yalnız seviye-1 binalar çevrilir (yatırım yakılmaz); belirgin bir
  /// karakteri olmayan botlar dönüşüm yapmaz.
  void _convertByPersona() {
    if (_convertCooldown > 0) return;
    if (player.resources < kConvertCost + 140) return;
    // En yüksek iştah hangi türde?
    final wants = [
      (persona.econW, BuildingType.resource),
      (persona.towerW, BuildingType.tower),
      (persona.powerW, BuildingType.power),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final (topW, topType) = wants.first;
    if (topW < 1.3) return; // dengeli karakter: dokunma
    final own = game.buildings
        .where((b) =>
            b.owner == player && b.type != BuildingType.hatchery)
        .toList();
    if (own.length < 4) return; // önce yayıl
    // Sevilen türden zaten çoğunluk varsa gerek yok.
    final ofTop = own.where((b) => b.type == topType).length;
    if (ofTop * 2 >= own.length) return;
    // En düşük iştahlı türden, seviye-1 bir bina seç.
    final (_, lowType) = wants.last;
    for (final b in own) {
      if (b.type == lowType && b.level == 1) {
        if (b.convertTo(player, topType)) _convertCooldown = 30;
        return;
      }
    }
  }

  /// VARLIK KORUMA (zor/kâbus): ele geçirilmekte olan kendi binasına
  /// tepki kolu gönderir — bot binaları elinden sessizce alınamaz.
  void _protectAssets() {
    if (_protectCooldown > 0) return;
    for (final b in game.buildings) {
      if (b.owner?.id != player.id) continue;
      var foes = 0;
      game.spatialGrid.forEachNear(b.position, kCaptureRadius, (u) {
        if (!u.dead && u.combatTeam != player.team) foes++;
      });
      if (foes >= 2) {
        _protectCooldown = 6;
        _deployGuarded(0.5, b.position);
        return; // tick başına tek tepki
      }
    }
  }

  /// STRATEJİK NÖBET: cepheye en yakın 1-2 kendi binasında (önce kuleler)
  /// küçük garnizonlar tutulur — köprübaşı/boğaz elde kalır.
  void _holdStrategicPoints() {
    if (_garrisonCooldown > 0) return;
    if (nest.population < params.squadSize + 4) return;
    final anchor =
        _nearestKnownEnemyNest()?.position ?? Vector2(kGameWidth / 2, kGameHeight / 2);
    final own = game.buildings
        .where((b) => b.owner?.id == player.id)
        .toList()
      ..sort((a, b) {
        // Kuleler öncelikli, sonra cepheye yakınlık.
        final ta = a.type == BuildingType.tower ? 0 : 1;
        final tb = b.type == BuildingType.tower ? 0 : 1;
        if (ta != tb) return ta - tb;
        return a.position
            .distanceToSquared(anchor)
            .compareTo(b.position.distanceToSquared(anchor));
      });
    // KÂBUS daha çok noktayı daha kalabalık ve daha sık tutar.
    final slots = params.tier >= 2 ? 3 : 2;
    final wantGuards = params.tier >= 2 ? 4 : 3;
    for (final b in own.take(slots)) {
      var guards = 0;
      for (final u in game.spatialGrid.near(b.position, 90)) {
        if (!u.dead && u.owner.id == player.id) guards++;
      }
      if (guards >= wantGuards) continue;
      _garrisonCooldown = params.tier >= 2 ? 5 : 8;
      _deployGuarded(0.2, b.position); // küçük nöbet kolu
      return; // tick başına tek nöbet emri
    }
  }

  // ------------------------------------------------------------ görüş (sis)

  /// Bot bu noktayı kendi varlıklarıyla görüyor mu?
  /// PERFORMANS: asker taraması TÜM orduyu gezmez — spatialGrid ile yalnız
  /// noktanın çevresine bakılır (eski hali karar anında birim² maliyetle
  /// takılmalara yol açıyordu).
  bool canSee(Vector2 pos) {
    if (nest.position.distanceToSquared(pos) < kNestVision * kNestVision) {
      return true;
    }
    for (final b in game.buildings) {
      if (b.owner != player) continue;
      final r = b.type == BuildingType.tower
          ? towerVision(b.level)
          : buildingVision(b.level);
      if (b.position.distanceToSquared(pos) < r * r) return true;
    }
    var seen = false;
    game.spatialGrid.forEachNear(pos, kUnitVision, (u) {
      if (seen || u.dead || u.owner.id != player.id || u.spawnDelay > 0) {
        return;
      }
      if (u.position.distanceToSquared(pos) <
          kUnitVision * kUnitVision) {
        seen = true;
      }
    });
    return seen;
  }

  void _updateKnowledge() {
    for (final entry in game.nests.entries) {
      if (entry.value.owner.team == player.team ||
          entry.value.destroyed) {
        continue;
      }
      if (canSee(entry.value.position)) knownEnemyNests.add(entry.key);
    }
    knownEnemyNests
        .removeWhere((id) => game.nests[id]!.destroyed);
  }

  // PERFORMANS ÖNBELLEKLERİ: karar tikinde BİR KEZ hesaplanır — üretim
  // döngüsü/yetenekler/plan aynı listeleri defalarca kurmaz.
  List<UnitComponent> _enemiesCache = const [];
  List<UnitComponent> _fieldCache = const [];

  List<UnitComponent> get _visibleEnemies => _enemiesCache;
  List<UnitComponent> get _fieldUnits => _fieldCache;

  void _refreshCaches() {
    _fieldCache = [
      for (final u in game.units)
        if (!u.dead && u.owner.id == player.id) u,
    ];
    _enemiesCache = [
      for (final u in game.units)
        if (!u.dead && u.combatTeam != player.team && canSee(u.position)) u,
    ];
  }

  // ------------------------------------------------------------ üretim

  void _produce() {
    // YÜKSELTME ÖNCE: üretim tüm parayı yerse bot 150 sn'de bile tek
    // seviye çekemiyordu (para hep 20-45 bandında dolaşıyordu) —
    // "botlar upgrade çekmiyor" şikayetinin kökü. Yükseltme payını
    // ayırdıktan sonra kalan orduya akar.
    if (params.upgrades) _developBuildings();
    // ANA YUVA YÜKSELTMESİ: açılış bitti ve para bolsa üretim hızını
    // 2 katına çıkar (insanla aynı kural, aynı fiyat).
    if (params.upgrades && !_opening && nest.upgradeLevel < 2) {
      final cost = nest.upgradeLevel == 0
          ? kNestUpgradeCost
          : kNestUpgrade2Cost;
      if (player.resources >= cost + persona.upgradeReserve) {
        game.buyNestUpgrade(player);
      }
    }
    // YÜKSELTME BİRİKİMİ: sırada uygun bir yükseltme varsa üretim o
    // parayı YEMEZ — hızlı tempolu botlarda (kâbus 0.85 sn'de bir
    // üretiyor) kasa iki karar arasında eşiğe hiç ulaşamıyordu ve bot
    // "asker basıp gönderen" seviye-1 ekonomiye saplanıyordu.
    final upgradeSave =
        params.upgrades ? math.min(_pendingUpgradeCost(), 130) : 0;
    if (game.armySize(player) + nest.productionQueue.length >=
        game.armyCap(player)) {
      return; // ordu tavanı: önce eldekini kullan
    }
    // AÇILIŞTA YALIN ORDU (zor+): ufak asker basımları — para yayılmaya
    // ve hafif yükseltmelere aksın; ordu büyütme açılıştan SONRA gelir.
    // TAVAN = muhafız + 2×kol: başlangıç garnizonuna eşit çıkıp üretimi
    // TAMAMEN kilitliyordu (bot açılışta tek asker basamıyordu).
    final openingLean = params.tier >= 2 && _opening;
    // KÂBUS: ×5 açılış parası orduya da aksın — yalın tavan 2 katıdır
    // (yelpaze kolları + erken kule sökümü garnizon ister).
    final leanCap =
        (_homeGuard + params.squadSize * 2) * (_nightmare ? 2 : 1);
    if (openingLean && nest.population >= leanCap) return;
    // Tavana yaklaşan bot yuvasını yükseltir (ordusunu büyütür).
    var guard = 0;
    // Tip kararı tur başına BİR kez verilir (counter analizi ucuz değil);
    // parti aynı tipten basılır — davranış olarak da daha tutarlı.
    final type = _chooseUnitType();
    final reserve = math.max(params.reserve, upgradeSave);
    final queueCap = openingLean ? (_nightmare ? 4 : 2) : 6;
    while (guard++ < 8 && nest.productionQueue.length < queueCap) {
      if (player.resources - unitSpecs[type]!.cost < reserve) break;
      if (!nest.enqueue(type)) break;
    }
  }

  /// Sıradaki EN UCUZ uygun yükseltmenin toplam ihtiyacı (maliyet +
  /// kişilik tamponu); uygun yükseltme yoksa 0.
  int _pendingUpgradeCost() {
    var best = 0;
    for (final b in game.buildings) {
      if (b.owner != player) continue;
      final cap = math.min(b.maxLevel, params.maxBuildLevel);
      if (b.level >= cap) continue;
      final need = b.upgradeCost + persona.upgradeReserve;
      if (best == 0 || need < best) best = need;
    }
    return best;
  }

  /// GELİŞME ODAĞI: bot her kararda en değerli yükseltmeyi arar —
  /// önce EN DÜŞÜK seviyeli çiftlik (ekonomi), sonra kule, sonra güç.
  /// Zorluk tavanı: normal bot 3'e kadar, zor bot 4'e kadar çıkar.
  void _developBuildings() {
    // Zengin bot tek turda İKİ yükseltme çekebilir (parayı yatırmayan
    // bot 2. dakikada hâlâ 1. seviyede kalıyordu). KÂBUS üç tura kadar
    // çıkar ve daha erken "zengin" sayılır.
    final rounds = params.tier >= 2 ? 3 : 2;
    final richFloor = params.tier >= 2 ? 90 : 130;
    for (var round = 0; round < rounds; round++) {
      Building? best;
      var bestScore = -1.0;
      for (final b in game.buildings) {
        if (b.owner != player) continue;
        // AÇILIŞTA HAFİF YÜKSELTME: seviye 2 tavanı — bot çiftliği
        // maksa çekip yayılmayı geciktirmesin; tam gelişme açılış sonrası.
        var cap = math.min(b.maxLevel, params.maxBuildLevel);
        if (_opening) cap = math.min(cap, 2);
        if (b.level >= cap) continue;
        if (player.resources < b.upgradeCost + persona.upgradeReserve) {
          continue;
        }
        final typeScore = switch (b.type) {
          BuildingType.resource => 30 * persona.econW,
          BuildingType.tower => 20 * persona.towerW,
          BuildingType.power => 12 * persona.powerW,
          BuildingType.hatchery => 0.0,
        };
        final score = typeScore + (4 - b.level) * 3; // düşük seviye önce
        if (score > bestScore) {
          bestScore = score;
          best = b;
        }
      }
      if (best == null || !best.upgrade(player)) return;
      if (player.resources < richFloor) return; // ek tur yalnız zenginken
    }
  }

  UnitType _chooseUnitType() {
    if (params.counterSmart) {
      final enemies = _visibleEnemies;
      // ZOR+ nadiren "dalgın" üretir (%80 counter isabeti).
      if (enemies.isNotEmpty &&
          _rng.nextDouble() > (params.tier >= 2 ? 0.2 : 0.3)) {
        // En kalabalık düşman tipine en iyi counter'ı üret.
        final countByType = <UnitType, int>{};
        for (final e in enemies) {
          countByType.update(e.type, (c) => c + 1, ifAbsent: () => 1);
        }
        final common = countByType.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
        UnitType best = UnitType.fire;
        var bestMul = 0.0;
        for (final t in UnitType.values) {
          final mul = counterMultiplier(t, common);
          if (mul > bestMul && unitSpecs[t]!.cost <= player.resources) {
            bestMul = mul;
            best = t;
          }
        }
        return best;
      }
      // Görüş yoksa KİŞİLİK karışımı (Sürü Lordu ateşe, Teknolojist
      // seçkine ağırlık verir).
      return _weightedUnit(1, 1, 1, 1);
    }
    // Kolay bot: ucuz kalabalık (kişilik yine tonu belirler).
    return _weightedUnit(2.4, 1, 0.35, 0.25);
  }

  /// Taban ağırlık × kişilik ağırlığı ile rastgele birim seçer.
  UnitType _weightedUnit(
      double fire, double wood, double trap, double leaf) {
    final w = [
      fire * persona.fireW,
      wood * persona.woodW,
      trap * persona.trapW,
      leaf * persona.leafW,
    ];
    const types = [
      UnitType.fire,
      UnitType.wood,
      UnitType.trapjaw,
      UnitType.leafcutter,
    ];
    var roll = _rng.nextDouble() * (w[0] + w[1] + w[2] + w[3]);
    for (var i = 0; i < 4; i++) {
      roll -= w[i];
      if (roll <= 0) return types[i];
    }
    return UnitType.fire;
  }

  // ------------------------------------------------------------ savunma

  /// Kendi yuvası VE (2v2'de) müttefik yuvaları savunulur — müttefik
  /// sıkışınca bot yardıma koşar.
  bool _defend() {
    for (final n in game.nests.values) {
      if (n.destroyed || n.owner.team != player.team) continue;
      final own = n.owner.id == player.id;

      final threats = game.spatialGrid
          .near(n.position, persona.defRadius)
          .where((u) => !u.dead && u.combatTeam != player.team)
          .toList();
      if (threats.length < 2) continue;

      final centroid = Vector2.zero();
      for (final t in threats) {
        centroid.add(t.position);
      }
      centroid.scale(1 / threats.length);

      // Garnizonu sahaya sür: kendi yuvası için büyük, müttefik için
      // yardım kolu (kendi savunmasını tamamen boşaltmaz).
      if (own && nest.population >= 3) {
        game.deployFromNest(nest, 0.75, centroid);
      } else if (!own && nest.population >= 8) {
        game.deployFromNest(nest, 0.4, centroid);
      }
      // Yakın saha birimlerini çağır.
      for (final u in _fieldUnits) {
        if (!u.inCombat &&
            u.position.distanceToSquared(n.position) < 450 * 450) {
          u.orderMove(centroid +
              Vector2(
                  _rng.nextDouble() * 30 - 15, _rng.nextDouble() * 30 - 15));
        }
      }
      _tryAbilities(defendPoint: centroid);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------ saldırı

  /// Toplam güç (garnizon + boştaki saha ordusu) eşiği aşınca bilinen en
  /// yakın düşman yuvasına yüklenir — saha ordusu da dalgaya katılır.
  bool _attack() {
    final idle = _fieldUnits.where((u) => !u.inCombat).toList();
    if (nest.population + idle.length < _attackThreshold ||
        knownEnemyNests.isEmpty) {
      return false;
    }
    final targetNest = knownEnemyNests
        .map((id) => game.nests[id]!)
        .reduce((a, b) => a.position.distanceToSquared(nest.position) <
                b.position.distanceToSquared(nest.position)
            ? a
            : b);

    if (nest.population >= 3) {
      _deployGuarded(1.0, targetNest.position);
    }
    for (final u in idle) {
      // PERFORMANS: hedefin dibindekilere yeniden yol hesaplatma —
      // her karar turunda tüm ordu için A* koşturmak kasmaya yol açar.
      if (u.position.distanceToSquared(targetNest.position) < 180 * 180) {
        continue;
      }
      u.orderMove(targetNest.position +
          Vector2(_rng.nextDouble() * 60 - 30, _rng.nextDouble() * 60 - 30));
    }
    _tryAbilities(attackPoint: targetNest.position);
    return true;
  }

  // ------------------------------------------------------------ genişleme

  /// AÇILIŞ YELPAZESİ (zor+): nötr (görünürde sahipsiz) binalara aynı
  /// tikte 2-3 AYRI kol çıkarır — bina başına 2-3 asker yeter, harita
  /// paralel kapanır. KULELER yelpazeye girmez; KÂBUS bunun istisnasıdır:
  /// garnizon yetiyorsa nötr kuleye 6 kişilik kol da çıkar (bol parayla
  /// asker zaten hızla yerine basılır). Kol çıktıysa true döner.
  bool _openingFanOut() {
    if (_expandCooldown > 0) return false;
    final enemyAnchor = _nearestKnownEnemyNest()?.position;
    // Adaylar: nötr görünen (ya da hiç görülmemiş) binalar, kendi yakada.
    final entries = <(Building, double, bool)>[]; // (bina, skor, kule mi)
    for (final b in game.buildings) {
      final seen = canSee(b.position);
      if (seen && b.owner != null) continue;
      final dMe = b.position.distanceTo(nest.position);
      if (enemyAnchor != null &&
          dMe > b.position.distanceTo(enemyAnchor)) {
        continue; // düşman yakası açılış yelpazesine girmez
      }
      // Üstünde/dibinde zaten adamım varsa kol tekrarlanmaz.
      var busy = false;
      for (final u in _fieldUnits) {
        if (u.position.distanceToSquared(b.position) < 90 * 90) {
          busy = true;
          break;
        }
      }
      if (busy) continue;
      final isTower = seen && b.type == BuildingType.tower;
      if (isTower && !_nightmare) continue;
      // Kuleler pahalı koldur: mesafe cezasıyla sıranın sonuna gider.
      entries.add((b, dMe + (isTower ? 250 : 0), isTower));
    }
    if (entries.isEmpty) return false;
    entries.sort((a, b) => a.$2.compareTo(b.$2));

    final guard = math.min(_homeGuard, 4);
    var spare = nest.population - guard;
    if (spare < 4) return false;
    var lanes = 0;
    var sent = false;
    for (final (b, _, isTower) in entries) {
      if (lanes >= 3 || spare < 2) break;
      // Nötr kule yarım güçle ateş eder — yine de 6 kişilik kol ister.
      final squad = isTower ? 6 : (spare >= 8 ? 3 : 2);
      if (spare < squad) continue;
      game.deployFromNest(
          nest, squad / math.max(1, nest.population), b.position);
      spare -= squad;
      lanes++;
      sent = true;
    }
    if (sent) _expandCooldown = persona.expandCooldown * 0.5;
    return sent;
  }

  void _expand() {
    if (_expandCooldown > 0) return;

    // ERKEN OYUN AÇILIŞI: kendi bölgesindeki ilk binalar alınana dek
    // nüfus şartı GEVŞEKTİR — bot çiftliksiz oturup kalmaz (eski davranış:
    // squadSize dolana kadar hiç genişlemiyordu ve tek en-yakın binayı
    // kovalıyordu).
    final ownedCount =
        game.buildings.where((b) => b.owner?.id == player.id).length;
    final minPop = ownedCount < 2
        ? 3
        : math.max(3, (params.squadSize * persona.expandNeed).round());
    if (nest.population < minPop) return;

    final enemyAnchor = _nearestKnownEnemyNest()?.position;
    Building? target;
    Building? second; // KÂBUS: aynı tikte ikinci hedef de alınabilir
    var bestScore = 0.0;
    var secondScore = 0.0;
    for (final b in game.buildings) {
      // Sahiplik ancak görünce bilinir; görünmeyen bina "gidilmeye değer".
      // TAKIM binaları hedef DEĞİLDİR — müttefikin üssüne asker yığılmaz.
      final seen = canSee(b.position);
      if (seen && b.owner != null && b.owner!.team == player.team) continue;

      final dMe = b.position.distanceTo(nest.position);
      // BÖLGE BİLİNCİ: bana düşmandan daha yakın binalar ÖNCE alınır;
      // düşman tarafındakiler (Fırsatçı/Komando/KÂBUS hariç) sonraya kalır.
      var zone = 1.0;
      if (enemyAnchor != null) {
        final dEnemy = b.position.distanceTo(enemyAnchor);
        // AÇILIŞTA düşman tarafına kol sürülmez (yayılma kendi yakasında
        // kalır — "önce geliş, sonra savaş").
        zone = dMe < dEnemy
            ? 1.4
            : (_opening
                ? 0.3
                : (persona.bravado || params.tier >= 2
                    ? 1.0
                    : (params.tier >= 1 ? 0.75 : 0.6)));
      }
      // Tip iştahı (görünmeyen binanın tipi bilinmez → nötr).
      var typeW = !seen
          ? 1.0
          : switch (b.type) {
              BuildingType.resource => 1.35 * persona.econW,
              BuildingType.tower => 1.0 * persona.towerW,
              BuildingType.power => 0.9 * persona.powerW,
              BuildingType.hatchery => 0.95,
            };
      // ERKEN/ORTA EVRE (zor+): FEROMON merkezi AÇILIŞTAN itibaren
      // caziptir (yakınsa başta alınır — mesafe skoru zaten yakını
      // seçer); KULELER açılış sonrası öncelik kazanır.
      if (seen &&
          params.tier >= 2 &&
          game.matchDuration < params.openingSecs + 90) {
        if (b.type == BuildingType.power) typeW *= 1.5;
        if (!_opening && b.type == BuildingType.tower) typeW *= 1.25;
      }
      // KULE KOLU AKLI: kule ateş eder — 1-2 askerle gidilmez. Seviyeye
      // göre yeterli kol çıkaramayacaksak o kule bu tik HEDEF DEĞİLDİR.
      if (seen && b.type == BuildingType.tower && b.owner != null) {
        final needed = 4 + 2 * b.level;
        if (nest.population - _homeGuard < needed) continue;
      }
      // Düşman eline geçmiş bina: almak savaş ister, biraz sona kalsın —
      // KÂBUS çekinmez (sökmek de büyümektir).
      final contested = seen && b.owner != null
          ? (params.tier >= 2 ? 1.0 : 0.75)
          : 1.0;
      final score = typeW * zone * contested * 1000 / (250 + dMe);
      if (score > bestScore) {
        secondScore = bestScore;
        second = target;
        bestScore = score;
        target = b;
      } else if (score > secondScore) {
        secondScore = score;
        second = b;
      }
    }
    if (target == null) return;

    // ZOR+ daha sık genişler.
    _expandCooldown =
        persona.expandCooldown * (params.tier >= 2 ? 0.7 : 1.0);
    // Kule hedefi: TOPLU TAARRUZ — garnizondan gereken kesir çıkar VE
    // hedef çevresindeki boştaki saha askerleri de aynı noktaya sürülür
    // (2-3 askerle sv4 kuleye sataşma dönemi bitti).
    var frac = persona.expandFrac;
    if (target.type == BuildingType.tower && canSee(target.position)) {
      final needed = 6 + 3 * target.level;
      final spare = math.max(1, nest.population - _homeGuard);
      frac = math.max(frac, (needed / spare).clamp(0.0, 1.0));
      final helpers = [
        for (final u in _fieldUnits)
          if (!u.inCombat &&
              !_isCapturing(u) &&
              u.position.distanceToSquared(target.position) <
                  450 * 450)
            u,
      ];
      _marchShared(helpers, target.position, scatter: 40);
    }
    // AÇILIŞTA muhafız payı gevşer (4): asıl iş yayılmaktır — tam
    // muhafız kesintisi kolları 1-2 karıncaya düşürüyordu.
    final guard = _opening ? math.min(_homeGuard, 4) : null;
    _deployGuarded(frac, target.position, guard: guard);
    // ÇİFT KOL (zor+): nüfus boldaysa ikinci hedefe de aynı tikte kol
    // çıkar — harita iki koldan birden kapanır.
    if (params.tier >= 2 &&
        second != null &&
        nest.population >= minPop + 6) {
      _deployGuarded(persona.expandFrac * 0.6, second.position,
          guard: guard);
    }
  }

  /// İLERLEME: boşta bekleyen saha ordusu yeterince büyüdüyse cepheye sür —
  /// önce görünen düşman binası kuşatılır; düşman izi yoksa haritanın
  /// karşı yakasına (kendi yuvasının aynası) keşif kolu gider. Böylece
  /// ordu bir köşede yığılıp kalmaz, savaşır ve harita açılır.
  void _advance() {
    // PERFORMANS: ilerleme emri seyrek verilir (toplu A* maliyeti).
    if (_advanceCooldown > 0) return;
    final idle = _fieldUnits
        .where((u) =>
            !u.inCombat &&
            !u.isMoving &&
            u.spawnDelay <= 0 &&
            !_isCapturing(u))
        .toList();
    // Küçük kollar da ilerler (cephede birleşirler) — yığılma olmasın.
    if (idle.length < 4) return;
    _advanceCooldown = 5;

    // Görünen en yakın düşman binası (nötr değil, düşman takımın).
    // EKONOMİ AVCILARI (Komando/Fırsatçı) düşman çiftliklerine öncelik verir.
    Building? enemyB;
    var bestD = double.infinity;
    for (final b in game.buildings) {
      if (b.owner == null || b.owner!.team == player.team) continue;
      if (!canSee(b.position)) continue;
      var d = b.position.distanceToSquared(nest.position);
      if (persona.raidsEconomy && b.type == BuildingType.resource) {
        d *= 0.35; // çiftlikler "daha yakın" sayılır
      }
      if (d < bestD) {
        bestD = d;
        enemyB = b;
      }
    }
    final target = enemyB?.position ??
        // Keşif: haritanın karşı yakası (düşman oralarda bir yerde).
        Vector2(kGameWidth - nest.position.x, kGameHeight - nest.position.y);

    // ORTAK ROTA: kol için tek A*, herkes paylaşır.
    final marchers = [
      for (final u in idle)
        if (u.position.distanceToSquared(target) >= 150 * 150) u,
    ];
    _marchShared(marchers, game.grid.nearestOpen(target));
  }

  /// Birim, takımın olmayan bir binayı ele geçirmekle meşgul mü?
  /// (Meşgulse ilerleme kolu onu yerinden çekmez.)
  List<Building>? _capturableCache;

  bool _isCapturing(UnitComponent u) {
    final targets = _capturableCache ??= [
      for (final b in game.buildings)
        if (b.owner == null || b.owner!.team != player.team) b,
    ];
    for (final b in targets) {
      if (u.position.distanceToSquared(b.position) <
          kCaptureRadius * kCaptureRadius) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ yetenekler

  void _tryAbilities({Vector2? defendPoint, Vector2? attackPoint}) {
    for (var i = 0; i < abilities.length; i++) {
      if (abilityCooldowns[i] > 0) continue;
      if (_rng.nextDouble() > _abilityChance) continue;

      final type = abilities[i];
      Vector2? target;
      switch (type) {
        case AbilityType.lightning:
        case AbilityType.poisonCloud:
        case AbilityType.fireRing:
          target = _findEnemyCluster();
        case AbilityType.fearScream:
        case AbilityType.freeze:
          target = defendPoint ?? _findEnemyCluster();
        case AbilityType.reinforce:
        case AbilityType.summonWood:
        case AbilityType.summonLeaf:
          target = defendPoint ?? attackPoint;
        case AbilityType.speedPheromone:
        case AbilityType.battleFrenzy:
        case AbilityType.heal:
        case AbilityType.armorPheromone:
          if (attackPoint == null && defendPoint == null) break;
          final own = _fieldUnits;
          if (own.length >= 4) {
            final c = Vector2.zero();
            for (final u in own) {
              c.add(u.position);
            }
            c.scale(1 / own.length);
            target = c;
          }
        case AbilityType.rain:
          // Savunmadayken yağmur herkes için taktik kazanç.
          if (defendPoint != null) {
            castAbility(game, player, type, null);
            abilityCooldowns[i] = abilitySpecs[type]!.cooldown;
          }
          continue;
      }
      if (target == null || !canSee(target)) continue;
      // Botlar da yasak bölgeye (rakip yuva dibi) atamaz — adil oyun.
      if (!game.abilityAllowedAt(player, target)) continue;
      castAbility(game, player, type, target);
      abilityCooldowns[i] = abilitySpecs[type]!.cooldown;
    }
  }

  /// Yıldırım hedefi: en az 4 düşmanın toplandığı, kendi askerinin az olduğu
  /// GÖRÜNÜR bir nokta.
  Vector2? _findEnemyCluster() {
    final enemies = _visibleEnemies;
    for (final e in enemies) {
      var enemyCount = 0;
      var ownCount = 0;
      for (final u in game.spatialGrid.near(e.position, 70)) {
        if (u.dead) continue;
        if (u.combatTeam == player.team) {
          ownCount++;
        } else {
          enemyCount++;
        }
      }
      if (enemyCount >= 4 && ownCount <= 1) return e.position.clone();
    }
    return null;
  }
}
