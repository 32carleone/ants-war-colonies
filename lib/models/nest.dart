import 'package:flame/components.dart';

import '../data/constants.dart';
import '../data/units.dart';
import 'player.dart';

/// Ana yuvanın oyun mantığı: kraliçe, garnizon, üretim kuyruğu, savunma.
///
/// Kurallar:
/// - Asker üretimi ve çıkarımı SADECE buradan yapılır.
/// - Kraliçe asla dışarı çıkamaz (taşıma API'si yok).
/// - Dışarıdaki askerler geri sokulup savunmayı güçlendirebilir.
/// - Saldırı hasarı önce garnizonu eritir, sonra kraliçeye işler.
class Nest {
  Nest({required this.owner, required this.position}) {
    garrison[UnitType.fire] = kStartingGarrison;
  }

  final Player owner;
  final Vector2 position;

  /// Yuva seviyesi: ordu tavanını belirler (yükseltilebilir).

  double queenHp = kQueenMaxHp;

  /// Yuva içindeki askerler (tip → adet).
  final Map<UnitType, int> garrison = {};

  /// Üretim kuyruğu (sıradaki tipler).
  final List<UnitType> productionQueue = [];

  /// Bu yuvanın maç boyunca ürettiği toplam asker (istatistik).
  int producedCount = 0;
  double _productionElapsed = 0;

  bool get destroyed => queenHp <= 0;

  /// Ordu tavanı SABİTTİR (yuva yükseltme sistemi kaldırıldı).
  int get armyCap => kArmyCap;

  int get population =>
      garrison.values.fold(0, (sum, count) => sum + count);

  /// LAN İSTEMCİSİ: üretim ilerlemesi host'tan gelir; bu alan doluysa
  /// yerel sayaç yerine o gösterilir (istemci üretimi simüle etmez).
  double? netProgressOverride;

  /// Sıradaki üretimin ilerlemesi (0..1) — arayüzdeki doluş halkası için.
  double get productionProgress {
    final net = netProgressOverride;
    if (net != null) return net.clamp(0.0, 1.0);
    if (productionQueue.isEmpty) return 0;
    return (_productionElapsed / unitSpecs[productionQueue.first]!.productionTime)
        .clamp(0.0, 1.0);
  }

  /// Garnizonun toplam savunma gücü.
  double get defensePower => garrison.entries.fold(
      0, (sum, e) => sum + unitSpecs[e.key]!.defensePower * e.value);

  /// Üretim siparişi: kaynak yeterse düşüp kuyruğa ekler.
  bool enqueue(UnitType type) {
    if (destroyed) return false;
    final cost = unitSpecs[type]!.cost;
    if (owner.resources < cost) return false;
    owner.resources -= cost;
    productionQueue.add(type);
    return true;
  }

  /// Üretimi ilerletir; tamamlanan birimler garnizona katılır.
  /// ANA YUVA YÜKSELTMESİ (2 kademe):
  /// 1. kademe (500 altın): üretim hızı 2 KAT.
  /// 2. kademe (1000 altın): üretim ANINDA — basınca asker hazır.
  int upgradeLevel = 0;
  bool get upgraded => upgradeLevel >= 1;
  bool get instantProduction => upgradeLevel >= 2;

  void updateProduction(double dt) {
    if (destroyed || productionQueue.isEmpty) return;
    if (instantProduction) {
      // ANINDA ÜRETİM: kuyrukta ne varsa bu tikte garnizona iner.
      for (final t in productionQueue) {
        final spec = unitSpecs[t]!;
        garrison.update(spec.type, (c) => c + 1, ifAbsent: () => 1);
        producedCount++;
      }
      productionQueue.clear();
      _productionElapsed = 0;
      return;
    }
    _productionElapsed += dt * (upgraded ? 2 : 1);
    while (productionQueue.isNotEmpty) {
      final spec = unitSpecs[productionQueue.first]!;
      if (_productionElapsed < spec.productionTime) break;
      _productionElapsed -= spec.productionTime;
      garrison.update(spec.type, (c) => c + 1, ifAbsent: () => 1);
      producedCount++;
      productionQueue.removeAt(0);
    }
    if (productionQueue.isEmpty) _productionElapsed = 0;
  }

  /// Garnizondan asker çıkarır (yüzde bar: 0.25 / 0.5 / 0.75 / 1.0).
  /// [only] verilirse sadece o tipten alır. Çıkarılanları döndürür;
  /// haritaya salma işi çağıranın (PART-04/05) sorumluluğudur.
  Map<UnitType, int> takeOut(double fraction, {UnitType? only}) {
    final taken = <UnitType, int>{};
    for (final type in List.of(garrison.keys)) {
      if (only != null && type != only) continue;
      final count = garrison[type]!;
      if (count == 0) continue;
      final take =
          fraction >= 0.999 ? count : (count * fraction).round();
      if (take == 0) continue;
      garrison[type] = count - take;
      taken[type] = take;
    }
    return taken;
  }

  /// Haritadaki askerleri yuvaya geri sokar → savunma güçlenir.
  void returnUnits(Map<UnitType, int> units) {
    if (destroyed) return;
    units.forEach((type, count) {
      garrison.update(type, (c) => c + count, ifAbsent: () => count);
    });
  }

  /// Yuvaya saldırı: hasar önce garnizonu (zayıftan güçlüye) eritir,
  /// artan kısım kraliçeye işler.
  void receiveAttack(double damage) {
    if (destroyed) return;
    final types = garrison.keys
        .where((t) => garrison[t]! > 0)
        .toList()
      ..sort((a, b) => unitSpecs[a]!
          .defensePower
          .compareTo(unitSpecs[b]!.defensePower));
    for (final type in types) {
      final perUnitHp = unitSpecs[type]!.defensePower * kDefenseHpPerPower;
      while (garrison[type]! > 0 && damage >= perUnitHp) {
        garrison[type] = garrison[type]! - 1;
        damage -= perUnitHp;
      }
      if (damage < perUnitHp) break;
    }
    if (population == 0 && damage > 0) {
      queenHp = (queenHp - damage).clamp(0, kQueenMaxHp);
    }
  }
}
