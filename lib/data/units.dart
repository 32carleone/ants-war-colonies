import 'i18n.dart';

/// Savaşçı karınca tipleri. Gerçek türlere dayanır (bkz. docs/GAME_DESIGN.md).
enum UnitType {
  /// Ateş Karıncası (Solenopsis invicta) — ucuz, hızlı, kalabalık.
  fire,

  /// Kesici Asker (Atta cephalotes) — tank, dev çeneli.
  leafcutter,

  /// Kapan Çene (Odontomachus) — suikastçı, yıldırım hızında ilk vuruş.
  trapjaw,

  /// Orman Karıncası (Formica rufa) — menzilli, formik asit püskürtür.
  wood,
}

/// Bir birim tipinin tüm oyun verileri.
class UnitSpec {
  const UnitSpec({
    required this.type,
    required String name,
    required this.nameEn,
    required this.cost,
    required this.productionTime,
    required this.defensePower,
    required this.maxHp,
    required this.damage,
    required this.attackCooldown,
    required this.moveSpeed,
    required this.attackRange,
    required this.scale,
    this.ranged = false,
    this.firstStrike = false,
  }) : nameTr = name;

  final UnitType type;

  /// İKİ DİL: `name:` TR girilir, [nameEn] eklenir; getter dile göre döner.
  final String nameTr;
  final String nameEn;
  String get name => isEnglish ? nameEn : nameTr;

  /// Üretim maliyeti (kaynak).
  final int cost;

  /// Üretim süresi (saniye).
  final double productionTime;

  /// Yuva içindeyken savunmaya katkısı (görece savaş ağırlığı).
  final double defensePower;

  /// Savaş istatistikleri.
  final double maxHp;
  final double damage;

  /// İki saldırı arası süre (saniye).
  final double attackCooldown;

  /// Hareket hızı (piksel/saniye).
  final double moveSpeed;

  /// Saldırı menzili (piksel; yakın dövüşte gövde teması civarı).
  final double attackRange;

  /// Görsel boyut çarpanı (1.0 = standart işçi boyu).
  final double scale;

  /// Tür özellikleri (PART-07'de savaş sistemine bağlanır):
  /// Orman Karıncası uzaktan asit püskürtür.
  final bool ranged;

  /// Kapan Çene'nin ilk vuruşu kritiktir (3x) ve düşük canda geri zıplar.
  final bool firstStrike;
}

const Map<UnitType, UnitSpec> unitSpecs = {
  UnitType.fire: UnitSpec(
    type: UnitType.fire,
    name: 'Ateş Karıncası',
    nameEn: 'Fire Ant',
    cost: 10,
    productionTime: 0.7,
    defensePower: 1,
    maxHp: 30,
    damage: 6,
    attackCooldown: 0.8,
    moveSpeed: 70,
    attackRange: 14,
    scale: 0.8,
  ),
  UnitType.wood: UnitSpec(
    type: UnitType.wood,
    name: 'Orman Karıncası',
    nameEn: 'Wood Ant',
    cost: 30,
    productionTime: 1.4,
    defensePower: 2,
    maxHp: 35,
    damage: 9,
    attackCooldown: 1.2,
    moveSpeed: 50,
    attackRange: 95,
    scale: 1.0,
    ranged: true,
  ),
  UnitType.trapjaw: UnitSpec(
    type: UnitType.trapjaw,
    name: 'Kapan Çene',
    nameEn: 'Trap Jaw',
    cost: 30,
    productionTime: 1.4,
    defensePower: 2.5,
    maxHp: 40,
    damage: 14,
    attackCooldown: 1.0,
    moveSpeed: 85,
    attackRange: 15,
    scale: 0.95,
    firstStrike: true,
  ),
  UnitType.leafcutter: UnitSpec(
    type: UnitType.leafcutter,
    name: 'Kesici Asker',
    nameEn: 'Leafcutter',
    cost: 50,
    productionTime: 2.1,
    defensePower: 4,
    maxHp: 120,
    damage: 12,
    attackCooldown: 1.3,
    moveSpeed: 38,
    attackRange: 17,
    scale: 1.25,
  ),
};
