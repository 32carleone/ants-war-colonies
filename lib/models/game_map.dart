import 'package:flame/components.dart';

import '../data/i18n.dart';
import 'building.dart';

/// Arazi öğesi türleri.
enum TerrainKind {
  /// Nehir / gölet — geçilemez (köprü hariç).
  water,

  /// Ağaç kökü — geçilemez.
  root,

  /// Taş — geçilemez.
  rock,

  /// Köprü — üzerinden geçtiği suyu geçilebilir yapar.
  bridge,

  /// Bataklık / çamur — GEÇİLEBİLİR ama içindeki askerler yavaşlar.
  swamp,

  /// Kazılabilir kaya tıkacı — kapalı başlar; çevresinde bekleyen asker
  /// çoğunluğu kazıp KALICI olarak açar (harita maç içinde değişir).
  digsite,

  /// Nötr yaban arısı yuvası — kimseye ait değildir; menziline giren HER
  /// takımın askerini sokar. Yuvanın kendisi geçilmezdir.
  waspNest,
}

/// Tek bir arazi öğesi: tek nokta = daire, çok nokta = kalın çizgi (kapsül zinciri).
/// Hem çizimde hem geçilebilirlik testinde aynı geometri kullanılır.
class TerrainFeature {
  TerrainFeature(this.kind, this.points, this.width)
      : assert(points.isNotEmpty);

  final TerrainKind kind;
  final List<Vector2> points;

  /// Çizgi kalınlığı / daire çapı (dünya birimi = piksel).
  final double width;

  bool contains(Vector2 p, {double inflate = 0}) {
    final r = width / 2 + inflate;
    final rSq = r * r;
    if (points.length == 1) {
      return points.first.distanceToSquared(p) <= rSq;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (_distToSegmentSq(p, points[i], points[i + 1]) <= rSq) return true;
    }
    return false;
  }

  static double _distToSegmentSq(Vector2 p, Vector2 a, Vector2 b) {
    final ab = b - a;
    final lenSq = ab.length2;
    if (lenSq == 0) return p.distanceToSquared(a);
    var t = (p - a).dot(ab) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = a + ab * t;
    return p.distanceToSquared(proj);
  }
}

/// Bir haritanın tam tanımı: engeller, köprüler, yuva ve bina noktaları.
/// Harita zemin teması: sefer haritaları konseptine uygun boyanır.
/// - [grass]: yemyeşil çimen (varsayılan, tüm normal haritalar)
/// - [scorched]: ÇORAK yanık toprak; sular LAV olur, etrafta alevler/korlar
/// - [snow]: KARLI toprak; sular BUZ olur, tipi taneleri süzülür
enum MapTheme { grass, scorched, snow }

class MapDefinition {
  MapDefinition({
    required this.id,
    required String name,
    this.nameEn = '',
    required this.playerCount,
    required this.features,
    required this.nestSpots,
    required this.buildingSpots,
    required this.buildingTypes,
    this.scorpionSpots = const [],
    this.raiderCampSpots = const [],
    this.fixedNests = false,
    this.theme = MapTheme.grass,
  })  : nameTr = name,
        assert(nestSpots.length == playerCount),
        assert(buildingSpots.length == buildingTypes.length);

  final MapTheme theme;

  final String id;

  /// İKİ DİL: `name:` TR girilir, [nameEn] eklenir; boşsa TR'ye düşülür.
  final String nameTr;
  final String nameEn;
  String get name =>
      isEnglish && nameEn.isNotEmpty ? nameEn : nameTr;

  final int playerCount;

  /// Tüm arazi öğeleri (engeller + köprüler), çizim sırasına göre.
  final List<TerrainFeature> features;

  /// Oyuncu ana yuvalarının olası konumları (oyuncular rastgele dağıtılır).
  final List<Vector2> nestSpots;

  /// Nötr binaların konumları.
  final List<Vector2> buildingSpots;

  /// Her bina noktasının başlangıç türü (buildingSpots ile aynı sırada).
  final List<BuildingType> buildingTypes;

  /// YAĞMACI AKREP devriye merkezleri (nötr canavar; öldürene altın).
  final List<Vector2> scorpionSpots;

  /// YAĞMACI KAMPI noktaları (nötr paralı asker kampı; dolduran taraf
  /// 5 yağmacıyı ordusuna katar, kamp ~75 sn sonra yeniden açılır).
  final List<Vector2> raiderCampSpots;

  /// true: yuva noktaları KARIŞTIRILMAZ — ilk nokta insanındır
  /// (asimetrik senaryo haritaları: İnka Yolu).
  final bool fixedNests;

  /// Statik geçilmezlik testine giren öğeler (köprü ve bataklık hariç —
  /// köprü açar, bataklık zaten geçilebilirdir).
  Iterable<TerrainFeature> get obstacles => features.where((f) =>
      f.kind != TerrainKind.bridge && f.kind != TerrainKind.swamp);

  Iterable<TerrainFeature> get bridges =>
      features.where((f) => f.kind == TerrainKind.bridge);

  /// Bu nokta yürünemez mi? Köprü, altındaki suyu geçilebilir yapar.
  /// [inflate] engelleri birim yarıçapı kadar genişletir (kenara sıkışmayı
  /// önler). [ignore]: bu öğeler yok sayılır (kazıyla
  /// kazılıp açılan geçitler için).
  bool isBlocked(Vector2 p,
      {double inflate = 0, Set<TerrainFeature>? ignore}) {
    var inWater = false;
    for (final f in obstacles) {
      if (ignore != null && ignore.contains(f)) continue;
      if (f.contains(p, inflate: inflate)) {
        // Su köprüyle açılabilir; kök/taş/kazı/arı yuvası açılmaz.
        if (f.kind != TerrainKind.water) {
          return true;
        }
        inWater = true;
      }
    }
    if (!inWater) return false;
    for (final b in bridges) {
      if (b.contains(p)) return false;
    }
    return true;
  }
}
