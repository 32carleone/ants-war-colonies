import 'dart:math' as math;

import 'package:flame/components.dart';

import '../data/constants.dart';
import 'player.dart';

/// Bina türleri.
enum BuildingType {
  /// Kule: menzilindeki düşman askerlere otomatik saldırır.
  tower,

  /// Kaynak binası (mantar çiftliği): sahibine ek gelir.
  resource,

  /// Güç binası (feromon merkezi): sahibinin askerlerine hasar bonusu.
  power,

  /// Kuluçka istasyonu (İKİNCİ ÇIKIŞ): sahibi yuvadan asker çıkarırken
  /// hedefe daha yakınsa askerler BURADAN sahaya iner. Üretim yine yuvada;
  /// güç/gelir vermez, yükseltilemez ve başka türe çevrilemez.
  hatchery,
}

/// Haritadaki bir binanın oyun mantığı.
///
/// Binalara asker SOKULMAZ; çevresindeki asker çoğunluğuyla ele geçirilir:
/// dairesel doluş halkası yavaşça dolar, tam dolunca bina el değiştirir.
class Building {
  Building({required this.position, required this.type});

  final Vector2 position;
  BuildingType type;

  /// null = nötr.
  Player? owner;

  int level = 1;

  /// Ele geçirme ilerlemesi (0..1) ve halkayı dolduran oyuncu.
  double captureProgress = 0;
  Player? capturingPlayer;

  // ------------------------------------------------------------ ele geçirme

  /// Her tikte çağrılır. [countsByPlayer]: yarıçap içindeki asker sayıları.
  /// Üstünlük TAKIM bazında hesaplanır (2v2'de müttefikler birlikte kuşatır).
  /// Dönen değer: sahibi bu tikte değiştiyse true.
  bool updateCapture(double dt, Map<Player, int> countsByPlayer) {
    // Takım toplamları + takımın en kalabalık üyesi (bayrağı o taşır).
    final teamTotals = <int, int>{};
    final teamLeader = <int, Player>{};
    var total = 0;
    countsByPlayer.forEach((player, count) {
      total += count;
      teamTotals.update(player.team, (c) => c + count, ifAbsent: () => count);
      final lead = teamLeader[player.team];
      if (lead == null || (countsByPlayer[lead] ?? 0) < count) {
        teamLeader[player.team] = player;
      }
    });
    int? dominantTeam;
    var dominantCount = 0;
    teamTotals.forEach((team, count) {
      if (count > dominantCount) {
        dominantCount = count;
        dominantTeam = team;
      }
    });
    final net = dominantCount - (total - dominantCount);
    final dominant =
        dominantTeam == null ? null : teamLeader[dominantTeam];

    // Üstünlük yoksa ya da sahibin TAKIMI çoğunluktaysa halka çözülür.
    if (dominant == null || net <= 0 || dominant.team == owner?.team) {
      _decay(dt);
      return false;
    }

    if (capturingPlayer?.team != dominant.team) {
      // Farklı bir kuşatan: önce mevcut ilerleme erisin.
      _decay(dt);
      if (captureProgress == 0) capturingPlayer = dominant;
      return false;
    }

    // KALABALIK HIZLANDIRIR: süre ≈ taban / √net.
    // 1 net asker ~10 sn, 4 asker ~5 sn, 9 asker ~3.3 sn.
    // Kuleler stratejik: ele geçirmesi 2 KAT uzun sürer.
    // SEVİYE DİRENÇ KATAR: her yükseltme diğer binalarda %25, KULEDE
    // %12 uzatır (sv4 kule zaten ateşiyle caydırıcı — eski 2.5×+%25/sv
    // birleşimi son seviye kuleyi fiilen alınamaz yapıyordu).
    var rate =
        math.sqrt(net.clamp(1, 25).toDouble()) / kCaptureBaseTime;
    if (type == BuildingType.tower) rate *= 0.5;
    rate /= 1 +
        (type == BuildingType.tower ? 0.12 : 0.25) * (level - 1);
    captureProgress += rate * dt;
    if (captureProgress >= 1) {
      // TAM EL DEĞİŞTİRME YIPRATIR: sahipli bir bina düşman ele
      // geçirince 1 SEVİYE geriler (en az 1) — yatırım el değiştirse
      // de bir kısmı enkazda kalır. Nötr binayı ilk almak yıpratmaz.
      if (owner != null && level > 1) level -= 1;
      owner = capturingPlayer;
      capturingPlayer = null;
      captureProgress = 0;
      return true;
    }
    return false;
  }

  void _decay(double dt) {
    captureProgress =
        (captureProgress - 2.5 * dt / kCaptureBaseTime).clamp(0.0, 1.0);
    if (captureProgress == 0) capturingPlayer = null;
  }

  // ------------------------------------------------------------ etkiler

  /// Kaynak binası geliri (kaynak/sn).
  double get incomePerSec =>
      type == BuildingType.resource ? kResourceIncomePerLevel * level : 0;

  /// Güç binası hasar bonusu (0.10 → %10/sv).
  double get powerBonus =>
      type == BuildingType.power ? kPowerBonusPerLevel * level : 0;

  /// Güç binası ZIRH bonusu (alınan hasarı azaltır, 0.06 → %6/sv).
  double get powerArmor =>
      type == BuildingType.power ? kPowerArmorPerLevel * level : 0;

  /// Kule istatistikleri: seviye menzil + hasar + ATIŞ HIZI + MERMİ SAYISI
  /// getirir (sv2: 2 hedef … sv4: 4 hedef birden vurulur).
  /// DENGE: eski 14+8L hasar + 0.45 sn tempo, sv4'te ~%400 DPS demekti —
  /// ordular kuleye VARAMADAN eriyordu. Hasar +5/sv, tempo daha ılımlı.
  double get towerRange => 110 + 15.0 * level;
  double get towerDamage => 14 + 5.0 * level;
  double get towerCooldown => 1.2 - 0.12 * (level - 1);
  int get towerShots => level;

  // ------------------------------------------------------------ yönetim

  /// Tür başına seviye tavanı: kule ve çiftlik 4'e kadar büyür,
  /// güç binası 3'te kalır, kuluçkanın seviyesi yoktur.
  int get maxLevel => switch (type) {
        BuildingType.tower || BuildingType.resource => 4,
        BuildingType.power => kMaxBuildingLevel,
        BuildingType.hatchery => 1,
      };

  int get upgradeCost => kUpgradeCostPerLevel * level;

  bool canUpgrade(Player player) =>
      owner == player &&
      level < maxLevel &&
      player.resources >= upgradeCost;

  bool upgrade(Player player) {
    if (!canUpgrade(player)) return false;
    player.resources -= upgradeCost;
    level++;
    return true;
  }

  /// Yık & başka türe çevir: seviye 1'e döner.
  /// Kuluçka istasyonu haritaya özeldir: NE çevrilebilir NE de kurulabilir.
  bool convertTo(Player player, BuildingType newType) {
    if (type == BuildingType.hatchery ||
        newType == BuildingType.hatchery) {
      return false;
    }
    if (owner != player || newType == type) return false;
    if (player.resources < kConvertCost) return false;
    player.resources -= kConvertCost;
    type = newType;
    level = 1;
    return true;
  }
}
