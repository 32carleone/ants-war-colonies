import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';

/// Kraliçe yetenekleri (3 slota takılabilir havuz).
enum AbilityType {
  /// İşaretlenen alana yıldırım düşer: alandaki TÜM birimlere hasar
  /// (dost dahil — dikkatli nişan al).
  lightning,

  /// Seçilen bölgede anında Ateş Karıncası takviyesi belirir.
  reinforce,

  /// Bölgedeki dost askerlerin hızı kısa süre artar.
  speedPheromone,

  /// Bölgedeki dost askerlerin saldırı gücü kısa süre artar.
  battleFrenzy,

  /// Bölgedeki dost askerlerin canı yenilenir.
  heal,

  /// Kısa süre yağmur: HERKESİN askerleri yavaşlar (taktiksel).
  rain,

  /// İşaretlenen alanda zehirli bulut: içindeki DÜŞMANLAR sürekli hasar alır.
  poisonCloud,

  /// Bölgedeki düşman askerleri panikle kaçışır, kısa süre savaşamaz.
  fearScream,

  /// Bölgedeki dost askerlerin aldığı hasar kısa süre azalır.
  armorPheromone,

  /// İşaretlenen alan baştan başa ALEV olur: içinde kalan DÜŞMANLAR yanar.
  fireRing,

  /// İşaretlenen zemin BUZ KESER: üstünde kalan ve içine giren
  /// DÜŞMANLAR donar (alan süresi boyunca).
  freeze,

  // NOT: yeni değerler SONA eklenir — LAN mesajları enum İNDEKSİ taşır.

  /// Seçilen bölgede anında Orman Karıncası (menzilli) takviyesi belirir.
  summonWood,

  /// Seçilen bölgede anında Kesici Karınca (tank) takviyesi belirir.
  summonLeaf,
}

/// DENGE NOTU: hasar ULTİLERİ (yıldırım, ateş çemberi, dondurma, zehir)
/// orduyu silebilir — dolumları ~2 dakikadır; destekler daha sık döner.
class AbilitySpec {
  const AbilitySpec({
    required this.type,
    required String name,
    required String description,
    required this.nameEn,
    required this.descriptionEn,
    required this.cooldown,
    this.radius = 0,
    this.duration = 0,
    this.global = false,
  })  : nameTr = name,
        descriptionTr = description;

  final AbilityType type;

  // İKİ DİL: TR alanları `name:`/`description:` adıyla girilir (mevcut
  // tanımlar bozulmaz), EN karşılıkları ek alandır; getter aktif dile döner.
  final String nameTr;
  final String nameEn;
  final String descriptionTr;
  final String descriptionEn;

  String get name => isEnglish ? nameEn : nameTr;
  String get description => isEnglish ? descriptionEn : descriptionTr;

  /// Dolum süresi (saniye) — yeteneğe göre farklı.
  final double cooldown;

  /// Etki yarıçapı (global yetenekte kullanılmaz).
  final double radius;

  /// Buff süresi (anlık etkilerde 0).
  final double duration;

  /// true → hedef seçilmez, tüm haritaya etki eder.
  final bool global;
}

const Map<AbilityType, AbilitySpec> abilitySpecs = {
  AbilityType.lightning: AbilitySpec(
    type: AbilityType.lightning,
    name: 'Yıldırım',
    description:
        'İşaretlenen alana yıldırım düşürür: alandaki TÜM askerlere 40 hasar '
        '(dostlar dahil). Ucuz askerleri siler, tankları yaralar; yakındaki '
        'yuvalara da hasar verir.',
    nameEn: 'Lightning',
    descriptionEn:
        'Calls a lightning strike on the marked area: 40 damage to ALL '
        'soldiers inside (allies included). Wipes cheap units, wounds '
        'tanks; nearby nests take damage too.',
    cooldown: 110,
    radius: 70,
  ),
  AbilityType.reinforce: AbilitySpec(
    type: AbilityType.reinforce,
    name: 'Takviye',
    description:
        'Seçilen bölgede anında 12 Ateş Karıncası belirir ve emrini bekler.',
    nameEn: 'Reinforce',
    descriptionEn:
        '12 Fire Ants instantly appear in the chosen area, awaiting your '
        'orders.',
    cooldown: 110,
    radius: 60,
  ),
  AbilityType.speedPheromone: AbilitySpec(
    type: AbilityType.speedPheromone,
    name: 'Hız Feromonu',
    description:
        'Bölgedeki dost askerlerin hızı 12 saniye boyunca %50 artar.',
    nameEn: 'Speed Pheromone',
    descriptionEn:
        'Friendly soldiers in the area move 50% faster for 12 seconds.',
    cooldown: 60,
    radius: 110,
    duration: 12,
  ),
  AbilityType.battleFrenzy: AbilitySpec(
    type: AbilityType.battleFrenzy,
    name: 'Savaş Çılgınlığı',
    description:
        'Bölgedeki dost askerlerin saldırı gücü 12 saniye boyunca %40 artar.',
    nameEn: 'Battle Frenzy',
    descriptionEn:
        'Friendly soldiers in the area deal 40% more damage for 12 seconds.',
    cooldown: 80,
    radius: 110,
    duration: 12,
  ),
  AbilityType.heal: AbilitySpec(
    type: AbilityType.heal,
    name: 'İyileştirme',
    description: 'Bölgedeki dost askerlerin canını 40 puan yeniler.',
    nameEn: 'Heal',
    descriptionEn:
        'Restores 40 HP to friendly soldiers in the area.',
    cooldown: 70,
    radius: 110,
  ),
  AbilityType.rain: AbilitySpec(
    type: AbilityType.rain,
    name: 'Yağmur',
    description:
        'Tüm haritada 9 saniye yağmur yağar: HERKESİN askerleri %40 yavaşlar. '
        'Doğru anda taktiksel üstünlük sağlar.',
    nameEn: 'Rain',
    descriptionEn:
        "Rain falls across the whole map for 9 seconds: EVERYONE's "
        'soldiers slow by 40%. Perfect timing wins battles.',
    cooldown: 90,
    duration: 9,
    global: true,
  ),
  AbilityType.poisonCloud: AbilitySpec(
    type: AbilityType.poisonCloud,
    name: 'Zehir Bulutu',
    description:
        'İşaretlenen alanda 9 saniye zehirli bulut oluşur: içinde kalan '
        'DÜŞMAN askerleri saniyede 10 hasar alır. Boğazları kilitler.',
    nameEn: 'Poison Cloud',
    descriptionEn:
        'A toxic cloud covers the marked area for 9 seconds: ENEMY soldiers '
        'inside take 10 damage per second. Locks down chokepoints.',
    cooldown: 100,
    radius: 90,
    duration: 9,
  ),
  AbilityType.fearScream: AbilitySpec(
    type: AbilityType.fearScream,
    name: 'Korku Çığlığı',
    description:
        'Bölgedeki düşman askerleri panikle kaçışır ve 4.5 saniye boyunca '
        'savaşamaz. Kuşatmayı dağıtmanın en hızlı yolu.',
    nameEn: 'Fear Scream',
    descriptionEn:
        'Enemy soldiers in the area flee in panic and cannot fight for 4.5 '
        'seconds. The fastest way to break a siege.',
    cooldown: 90,
    radius: 110,
    duration: 4.5,
  ),
  AbilityType.armorPheromone: AbilitySpec(
    type: AbilityType.armorPheromone,
    name: 'Zırh Feromonu',
    description:
        'Bölgedeki dost askerlerin aldığı hasar 12 saniye boyunca %40 azalır. '
        'Cepheyi tutarken can simidi.',
    nameEn: 'Armor Pheromone',
    descriptionEn:
        'Friendly soldiers in the area take 40% less damage for 12 seconds. '
        'A lifesaver while holding the line.',
    cooldown: 75,
    radius: 110,
    duration: 12,
  ),
  AbilityType.fireRing: AbilitySpec(
    type: AbilityType.fireRing,
    name: 'Ateş Çemberi',
    description:
        'İşaretlenen alan 8 saniye BAŞTAN BAŞA ALEV olur: içinde kalan '
        'DÜŞMANLAR saniyede 12 hasar alır. Alevlerin ortasında hayat yok — '
        'kaç ya da yan.',
    nameEn: 'Ring of Fire',
    descriptionEn:
        'The marked area BURSTS INTO FLAME for 8 seconds: ENEMIES inside '
        'take 12 damage per second. Nothing lives in the fire — run or '
        'burn.',
    cooldown: 130,
    radius: 85,
    duration: 8,
  ),
  AbilityType.summonWood: AbilitySpec(
    type: AbilityType.summonWood,
    name: 'Orman Çağrısı',
    description:
        'Seçilen bölgede anında 9 Orman Karıncası (menzilli) belirir ve '
        'emrini bekler.',
    nameEn: 'Forest Call',
    descriptionEn:
        '9 Wood Ants (ranged) instantly appear in the chosen area, awaiting '
        'your orders.',
    cooldown: 120,
    radius: 60,
  ),
  AbilityType.summonLeaf: AbilitySpec(
    type: AbilityType.summonLeaf,
    name: 'Kesici Çağrısı',
    description:
        'Seçilen bölgede anında 6 Kesici Karınca (tank) belirir ve emrini '
        'bekler.',
    nameEn: 'Leafcutter Call',
    descriptionEn:
        '6 Leafcutter Ants (tank) instantly appear in the chosen area, '
        'awaiting your orders.',
    cooldown: 110,
    radius: 60,
  ),
  AbilityType.freeze: AbilitySpec(
    type: AbilityType.freeze,
    name: 'Dondurma',
    description:
        'İşaretlenen zemin 6 saniye BUZ KESER: üstündeki ve sonradan giren '
        'DÜŞMAN askerleri donar (çıkınca ~2 sn içinde çözülür). Kaçış '
        'yollarını buzla, kuşatmayı kilitle.',
    nameEn: 'Freeze',
    descriptionEn:
        'The marked ground TURNS TO ICE for 6 seconds: enemy soldiers on it '
        '(and any that enter) freeze solid, thawing ~2s after leaving. Ice '
        'the escape routes, lock the siege.',
    cooldown: 120,
    radius: 90,
    duration: 6,
  ),
};

/// Varsayılan slot dizilimi.
const List<AbilityType> defaultLoadout = [
  AbilityType.lightning,
  AbilityType.reinforce,
  AbilityType.speedPheromone,
];

const _prefsKey = 'ability_loadout';

Future<List<AbilityType>> loadAbilityLoadout() async {
  final prefs = await SharedPreferences.getInstance();
  final names = prefs.getStringList(_prefsKey);
  if (names == null || names.length != 3) return List.of(defaultLoadout);
  final loadout = names
      .map((n) => AbilityType.values.firstWhere(
            (t) => t.name == n,
            orElse: () => AbilityType.lightning,
          ))
      .toList();
  // Aynı yetenekten birden fazla slot olamaz: tekrarları boşta kalan
  // yeteneklerle doldur.
  final seen = <AbilityType>{};
  for (var i = 0; i < loadout.length; i++) {
    if (!seen.add(loadout[i])) {
      loadout[i] = AbilityType.values
          .firstWhere((t) => !seen.contains(t) && !loadout.contains(t));
      seen.add(loadout[i]);
    }
  }
  return loadout;
}

Future<void> saveAbilityLoadout(List<AbilityType> loadout) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_prefsKey, loadout.map((t) => t.name).toList());
}
