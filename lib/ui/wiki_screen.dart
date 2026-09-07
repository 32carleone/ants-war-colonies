import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/abilities.dart';
import '../data/counters.dart';
import '../data/i18n.dart';
import '../data/units.dart';
import '../game/ant_painter.dart';
import '../game/building_painter.dart';
import '../models/building.dart';
import 'ability_art.dart';
import 'game_back_button.dart';

/// Gerçek tür bilgileri (wiki metinleri) — iki dilli.
String _lore(UnitType t) => switch (t) {
      UnitType.fire => loc(
          'Solenopsis invicta — dünyanın en istilacı türlerinden. '
          'Yakıcı zehirli iğnesiyle sürü halinde saldırır; tek başına zayıf, '
          'kalabalıkken kabus.',
          "Solenopsis invicta — one of the world's most invasive species. "
          'Attacks in swarms with a burning venomous sting; weak alone, '
          'a nightmare in numbers.'),
      UnitType.leafcutter => loc(
          'Atta cephalotes askeri — dev çeneleri deri bile '
          'kesebilir. Kolonileri yaprak taşıyıp mantar çiftlikleri kurar; '
          'askerleri yürüyen birer kalkandır.',
          'An Atta cephalotes soldier — its giant jaws can cut through '
          'leather. Their colonies haul leaves to farm fungus; the '
          'soldiers are walking shields.'),
      UnitType.trapjaw => loc(
          'Odontomachus — çenesini hayvanlar alemindeki en hızlı '
          'hareketlerden biriyle (~60 m/s) kapatır. Çenesini yere çarpıp '
          'kendini geriye fırlatarak kaçabilir.',
          'Odontomachus — snaps its jaws shut with one of the fastest '
          'movements in the animal kingdom (~60 m/s). It can slam its jaw '
          'into the ground to fling itself backwards to safety.'),
      UnitType.wood => loc(
          'Formica rufa — kızıl orman karıncası. Düşmanlarına '
          'formik asit püskürtür; devasa tepe yuvalar kurar.',
          'Formica rufa — the red wood ant. Sprays formic acid at its '
          'enemies and builds enormous mound nests.'),
    };

String _roleName(UnitType t) => switch (t) {
      UnitType.fire => loc('Sürü / ucuz piyade', 'Swarm / cheap infantry'),
      UnitType.leafcutter => 'Tank',
      UnitType.trapjaw => loc('Suikastçı', 'Assassin'),
      UnitType.wood => loc('Menzilli', 'Ranged'),
    };

/// Bir wiki girdisi: karınca (unit), bina (building/art — OYUNDAKİ çizimle
/// gösterilir) veya ikonlu metin sayfası.
class _Entry {
  const _Entry({
    required this.title,
    this.unit,
    this.icon,
    this.building,
    this.art,
    this.ability,
    this.body = '',
  });

  final String title;
  final UnitType? unit;
  final IconData? icon;

  /// Oyundaki bina çizimiyle gösterilecek tür.
  final BuildingType? building;

  /// Özel çizimler: 'nest' (ana yuva) / 'capture' (ele geçirme halkası).
  final String? art;

  /// Güç girdisi: özel yetenek çizimiyle gösterilir.
  final AbilityType? ability;

  final String body;

  bool get hasArt => building != null || art != null;
}

/// Bölümler: (başlık, girdiler) — her build'de aktif dile göre kurulur.
List<(String, List<_Entry>)> _buildSections() => [
  (
    loc('ASKERLER', 'SOLDIERS'),
    [for (final t in UnitType.values) _Entry(title: unitSpecs[t]!.name, unit: t)]
  ),
  (
    loc('BİNALAR', 'BUILDINGS'),
    [
      _Entry(
        title: loc('Ana Yuva', 'Main Nest'),
        art: 'nest',
        body: loc(
            'Koloninin kalbi: kraliçe burada yaşar ve asla dışarı çıkmaz. '
            'Asker üretimi ve çıkarımı yalnızca yuvadan yapılır. Dışarıdaki '
            'askerleri yuvaya geri sokarsan savunması güçlenir — yuvaya '
            'gelen hasar önce içerideki garnizonu eritir, sonra kraliçeye '
            'işler. Kraliçesi ölen koloni oyundan elenir; son kalan kazanır.'
            '\n\nYIKILAN KOLONİ: kraliçesi ölen oyuncunun binaları NÖTRE '
            'döner, sahadaki askerleri YABANİLEŞİR — eski müttefikleri '
            'dahil herkesi düşman beller, bina ele geçiremez.'
            '\n\nOrdu tavanı 200 askerdir (yuva + saha toplamı) — tavana '
            'dayandıysan üretim bekler, orduyu cephede erit ya da büyüt.',
            'The heart of the colony: the queen lives here and never '
            'leaves. Soldiers are produced and deployed only from the '
            'nest. Sending field soldiers back inside strengthens its '
            'defense — incoming damage melts the garrison first, then '
            'reaches the queen. A colony whose queen dies is eliminated; '
            'the last one standing wins.'
            '\n\nFALLEN COLONY: when a queen dies her buildings turn '
            'NEUTRAL and her field soldiers go FERAL — hostile to '
            'everyone, unable to capture buildings.'
            '\n\nThe army cap is 200 soldiers (nest + field). At the cap '
            'production waits — spend the army at the front or grow it.'),
      ),
      _Entry(
        title: loc('Kule', 'Tower'),
        building: BuildingType.tower,
        body: loc(
            'Menzilindeki düşmanlara otomatik çakıl fırlatır ve uzağı '
            'görür. NÖTR kule bile herkese ateş eder ve ele geçirmesi diğer '
            'binalardan 2 KAT uzun sürer — kule almak ciddi bir yatırımdır. '
            'Seviye başına (MAKS 4): menzil +15, hasar +5, DAHA HIZLI atış '
            've fazladan MERMİ (sv4 dört hedefi birden vurur), görüş +20.',
            'Automatically hurls pebbles at enemies in range and sees far. '
            'Even a NEUTRAL tower fires at everyone, and capturing one '
            'takes 2× longer than other buildings — a serious '
            'investment. Per level (MAX 4): +15 range, +5 damage, FASTER '
            'shots and an extra PROJECTILE (lv4 hits four targets at '
            'once), +20 vision.'),
      ),
      _Entry(
        title: loc('Mantar Çiftliği', 'Mushroom Farm'),
        building: BuildingType.resource,
        body: loc(
            'Yaprak kesici karıncaların gerçek hayattaki mantar '
            'tarımından: sahibine seviye başına +2 kaynak/sn ek gelir sağlar '
            '(MAKS 4 seviye — tam gelişmiş çiftlik +8/sn). Ekonominin '
            'belkemiği.',
            'Straight from real leafcutter fungus farming: pays its owner '
            '+2 resources/s per level (MAX level 4 — a fully grown farm '
            'pays +8/s). The backbone of your economy.'),
      ),
      _Entry(
        title: loc('Feromon Merkezi', 'Pheromone Hub'),
        building: BuildingType.power,
        body: loc(
            'Koloninin savaş feromonları burada yoğunlaşır: sahibinin TÜM '
            'askerlerine seviye başına +%10 HASAR ve +%6 ZIRH (alınan '
            'hasar azalır; zırh tavanı %25). Az sayıda seçkin orduyla '
            'oynayanların dostu.',
            "The colony's war pheromones concentrate here: +10% DAMAGE "
            "and +6% ARMOR per level for ALL of the owner's soldiers "
            '(damage taken is reduced; armor caps at 25%). A friend to '
            'those who fight with a small elite army.'),
      ),
      _Entry(
        title: loc('Kuluçka İstasyonu', 'Hatchery'),
        building: BuildingType.hatchery,
        body: loc(
            'İKİNCİ ÇIKIŞ: bu istasyon senin olduğunda, yuvadan çıkardığın '
            'askerler — hedef istasyona daha yakınsa — kuluçkanın tünelinden '
            'sahaya iner. Üretim yine yuvada yapılır; istasyon gelir ya da '
            'güç vermez, yükseltilemez ve başka türe çevrilemez. Cepheye '
            'yürüme süresini kısaltan saf LOJİSTİK avantajı: kaybedersen '
            'çıkış kapanır, savunmaya değer.',
            'SECOND EXIT: while this station is yours, soldiers you deploy '
            'from the nest — if the target is closer to the station — '
            'enter the field through its tunnel. Production still happens '
            'at the nest; the station gives no income or power, cannot be '
            'upgraded or converted. A pure LOGISTICS edge that cuts '
            'marching time: lose it and the exit closes, so defend it.'),
      ),
      _Entry(
        title: loc('Ele Geçirme', 'Capturing'),
        art: 'capture',
        body: loc(
            'Binalara asker SOKULMAZ. Askerlerin binanın çevresinde '
            'çoğunluktaysa dairesel halka senin renginde dolar — KALABALIK '
            'HIZLANDIRIR: 1 net asker ~10 sn, 4 asker ~5 sn, 9 asker ~3.3 '
            'sn. SEVİYE DİRENÇ KATAR: her yükseltme ele geçirmeyi %25 '
            '(kulede %12) uzatır. '
            'Tam dolunca bina el değiştirir ve 1 SEVİYE GERİLER '
            '(en az 1; nötr binayı ilk almak yıpratmaz). '
            'Üstünlük kaybolursa halka çözülür; kendi binanın '
            'çevresinde durmak onu savunur. Kendi binana dokununca '
            'çevresinde beliren butonlarla yükseltebilir (50×seviye; kule ve '
            'çiftlik maks 4, güç maks 3) '
            'veya ⇄ ile yıkıp başka türe çevirebilirsin (40⦿, seviye 1 e '
            'döner).',
            'Soldiers are NOT put inside buildings. When your soldiers '
            'outnumber others around a building, the ring fills in your '
            'color — CROWDS SPEED IT UP: 1 net soldier ~10s, 4 ~5s, 9 '
            '~3.3s. LEVELS ADD RESISTANCE: each upgrade makes capture 25% '
            '(towers 12%) longer. When the ring completes the building '
            'changes hands '
            'and DROPS ONE LEVEL (min 1; first capture of a neutral '
            'building does not). Lose the majority and the ring decays; '
            'standing near your own building defends it. Tap your own '
            'building to reveal buttons: upgrade (50×level; tower and '
            'farm max 4, power max 3) or ⇄ to tear down and convert '
            '(40⦿, back to level 1).'),
      ),
    ]
  ),
  (
    loc('HARİTA ÖĞELERİ', 'MAP FEATURES'),
    [
      _Entry(
        title: loc('Bataklık', 'Swamp'),
        art: 'swamp',
        body: loc(
            'Çamurlu zemin GEÇİLEBİLİR ama içindeki HERKES belirgin '
            'yavaşlar (dost-düşman fark etmez). Hücum yolları bataklıktan '
            'geçen ordular hedefe yorgun ve geç varır — savunan taraf '
            'nefes alır. Temaya göre kılık değiştirir: çorak topraklarda '
            'kül çamuru, karlı diyarlarda sulu kar.',
            'Muddy ground is PASSABLE, but EVERYONE inside slows down '
            'noticeably (friend or foe). Armies that march through swamp '
            'arrive late and tired — the defender breathes. It changes '
            'costume with the theme: ash mud on scorched lands, slush on '
            'snowy ones.'),
      ),
      _Entry(
        title: loc('Yağmacı Kampı', 'Raider Camp'),
        icon: Icons.local_fire_department,
        body: loc(
            'NÖTR paralı asker kampı: çevresinde (70px) asker çoğunluğu '
            'kuran taraf doluş halkasını doldurur — dolunca kampın 5 '
            'yağmacısı (2 Ateş, 1 Orman, 1 Kapan, 1 Kesici) SENİN ordunda '
            'savaşmaya başlar. Kamp ~75 sn söner, sonra yeniden açılır; '
            'tekrar tekrar alınabilir. Erken oyunda kamp kontrolü ciddi '
            'ordu avantajıdır (Tuna Kıyıları, Kilimanjaro Yaylaları).',
            'A NEUTRAL mercenary camp: the side holding the majority '
            'around it (70px) fills the ring — when it completes, the '
            "camp's 5 raiders (2 Fire, 1 Wood, 1 Trapjaw, 1 Leafcutter) "
            'join YOUR army. The camp goes dormant for ~75s, then reopens; '
            'it can be taken again and again. Early camp control is a '
            'serious army advantage (Danube Banks, Kilimanjaro Highlands).'),
      ),
      _Entry(
        title: loc('Kazı Geçidi', 'Dig Passage'),
        art: 'digsite',
        body: loc(
            'Çatlaklı kaya tıkacı kapalı bir geçidi tıkar. Çevresinde '
            'asker çoğunluğu kuran taraf tıkacı kazar — kalabalık '
            'hızlandırır ama taş ÇETİNDİR: 10 asker ~15 sn, tek asker '
            'pratikte kazamaz. Kazı KALICIDIR: '
            'rakip çoğunluğu ilerlemeyi yalnız duraklatır, geri saramaz. '
            'Açılan geçit HERKESE açıktır ve maç boyunca açık kalır — '
            'haritayı kalıcı olarak değiştirirsin.',
            'A cracked rock plug blocks a closed pass. The side with the '
            'soldier majority around it digs — crowds speed it up, but '
            'the rock is TOUGH: 10 soldiers ~15s, one soldier practically '
            'never. Digging is PERMANENT: an enemy majority only pauses '
            'progress, never reverses it. An opened pass is open to '
            'EVERYONE for the rest of the match — you permanently reshape '
            'the map.'),
      ),
      _Entry(
        title: loc('Yağmacı Akrep', 'Raider Scorpion'),
        art: 'scorpion',
        body: loc(
            'Bazı haritalarda devriye gezen NÖTR canavar: menziline giren '
            'HER askere kıskaç atar, takım ayırmaz. Canı yüksektir ama '
            'dibine yığılan ordu onu kemirir — SON DARBEYİ vuran oyuncu '
            '150 ALTIN ödül alır. Ölen akrep GERİ GELMEZ — avlanan bölge '
            'maç sonuna dek güvene düşer. '
            'Küçük kollarla sataşma; ya uzak dur ya orduyla avla.',
            'A NEUTRAL monster patrolling some maps: it claws EVERY '
            'soldier in range, no teams. It has plenty of health, but an '
            'army massed at its feet chews it down — the player landing '
            'the FINAL BLOW earns a 150 GOLD bounty. After a while a new '
            'scorpion settles in the same area: a repeating hunt '
            "objective. Don't poke it with small squads; keep away or "
            'hunt it with an army.'),
      ),
      _Entry(
        title: loc('Yaban Arısı Yuvası', 'Wasp Nest'),
        art: 'wasp',
        body: loc(
            'Nötr kâğıt kovan kimseye boyun eğmez: devriye arıları '
            'menziline giren HER askeri sokar — takım ayırmaz, ele '
            'geçirilemez. Ama YIKILABİLİR: dibine yığılan ordu kovanı '
            'kemirir (canı yüksektir ve kemirenler sokulmaya devam eder); '
            'çöken kovan bir daha geri gelmez, yeri yol olur. Küçük '
            'gruplarla girme; ya hızlı geç ya da orduyla yerle bir et.',
            'The neutral paper hive bows to no one: patrol wasps sting '
            'EVERY soldier in range — no teams, no capturing. But it CAN '
            'BE DESTROYED: an army massed at its base chews it down (it '
            'has lots of health and the chewers keep getting stung); a '
            'collapsed hive never returns and its spot becomes a road. '
            "Don't wander in with small groups; either rush past or "
            'level it with an army.'),
      ),
    ]
  ),
  (
    loc('GÜÇLER', 'POWERS'),
    [
      _Entry(
        title: loc('Güç Kullanımı', 'Using Powers'),
        icon: Icons.touch_app,
        body: loc(
            'Kraliçenin 3 güç slotu vardır (her güçten en fazla BİR tane); '
            'ana menüde kraliçenin altındaki slotlardan takarsın. Maç '
            'başında tüm güçler dolumdadır — barı dolan güç aktifleşir.\n\n'
            'Kullanım: butona BAS, haritada hedefe SÜRÜKLE, BIRAK — sisli '
            'alanlara da kör atış yapabilirsin.',
            'The queen has 3 power slots (at most ONE of each power); '
            'equip them under the queen in the main menu. All powers '
            'start the match on cooldown — a filled bar means ready.'
            '\n\nTo use: PRESS the button, DRAG to a target on the map, '
            'RELEASE — blind casts into the fog are allowed.'),
      ),
      for (final spec in abilitySpecs.values)
        _Entry(
          title: spec.name,
          ability: spec.type,
          body: '${spec.description}\n\n'
              '${loc('Dolum', 'Cooldown')}: ${spec.cooldown.round()} '
              '${loc('sn', 's')}'
              "${spec.radius > 0 ? ' · ${loc('Yarıçap', 'Radius')}: ${spec.radius.round()}' : ''}"
              "${spec.duration > 0 ? ' · ${loc('Süre', 'Duration')}: ${spec.duration.round()} ${loc('sn', 's')}' : ''}",
        ),
    ]
  ),
];

/// Wiki — SOL panel: bölümlü konu listesi; SAĞ panel: seçili konunun detayı.
class WikiScreen extends StatefulWidget {
  const WikiScreen({super.key});

  @override
  State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  /// Seçim İNDEKSLE tutulur: dil değişince bölümler yeniden kurulur,
  /// kimlik (identical) karşılaştırması artık güvenilir olmazdı.
  int _selSection = 0;
  int _selIndex = 0;

  late List<(String, List<_Entry>)> _sections;

  _Entry get _selected => _sections[_selSection].$2[_selIndex];

  @override
  Widget build(BuildContext context) {
    _sections = _buildSections();
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title: const Text('Wiki', style: TextStyle(color: Color(0xFFD8C9A3))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOL: konu listesi.
            SizedBox(width: 250, child: _panel(child: _topicList())),
            const SizedBox(width: 10),
            // SAĞ: seçili konunun detayı.
            Expanded(child: _panel(child: _detail())),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: child,
      );

  Widget _topicList() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (var si = 0; si < _sections.length; si++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Text(_sections[si].$1,
                style: const TextStyle(
                    color: Color(0xFF8BC34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 2)),
          ),
          for (var ei = 0; ei < _sections[si].$2.length; ei++)
            _topicTile(_sections[si].$2[ei], si, ei),
        ],
      ],
    );
  }

  Widget _topicTile(_Entry e, int si, int ei) {
    final selected = si == _selSection && ei == _selIndex;
    return GestureDetector(
      onTap: () => setState(() {
        _selSection = si;
        _selIndex = ei;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3E5527) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF8BC34A) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            if (e.unit != null)
              CustomPaint(
                  painter: _AntPortraitPainter(e.unit!),
                  size: const Size(26, 26))
            else if (e.hasArt)
              CustomPaint(
                  painter: _BuildingArtPainter(type: e.building, art: e.art),
                  size: const Size(26, 26))
            else if (e.ability != null)
              AbilityArt(type: e.ability!, size: 24)
            else
              Icon(e.icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFFF2E8D5)
                      : const Color(0xFFD8C9A3)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                e.title,
                style: TextStyle(
                  color:
                      selected ? const Color(0xFFF2E8D5) : Colors.white70,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail() {
    final e = _selected;
    if (e.unit != null) return _unitDetail(e.unit!);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (e.hasArt)
                // OYUNDAKİ bina çizimi (birebir aynı ressam).
                CustomPaint(
                    painter:
                        _BuildingArtPainter(type: e.building, art: e.art),
                    size: const Size(104, 104))
              else if (e.ability != null)
                AbilityArt(type: e.ability!, size: 72)
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF57472E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(e.icon, size: 28, color: const Color(0xFFD8C9A3)),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(e.title,
                    style: const TextStyle(
                        color: Color(0xFFF2E8D5),
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(e.body,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.55)),
        ],
      ),
    );
  }

  Widget _unitDetail(UnitType type) {
    final spec = unitSpecs[type]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(
                  painter: _AntPortraitPainter(type),
                  size: const Size(104, 104)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.name,
                        style: const TextStyle(
                            color: Color(0xFFF2E8D5),
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                    Text(_roleName(type),
                        style: const TextStyle(
                            color: Color(0xFF8BC34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(_lore(type),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statBox(loc('Can', 'HP'), spec.maxHp.round().toString()),
              _statBox(
                  loc('Hasar', 'Damage'), spec.damage.round().toString()),
              _statBox(
                  loc('Hız', 'Speed'), spec.moveSpeed.round().toString()),
              _statBox(
                  loc('Menzil', 'Range'),
                  spec.ranged
                      ? '${spec.attackRange.round()} ${loc('(asit)', '(acid)')}'
                      : loc('Yakın', 'Melee')),
              _statBox(loc('Maliyet', 'Cost'), '${spec.cost}⦿'),
              _statBox(loc('Üretim', 'Production'),
                  '${spec.productionTime} ${loc('sn', 's')}'),
            ],
          ),
          const SizedBox(height: 16),
          // EŞLEŞMELER: taş-kağıt-makas zinciri asker asker, nedeniyle.
          Text(loc('EŞLEŞMELER', 'MATCHUPS'),
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          for (final t in UnitType.values)
            if (t != type) _matchupRow(type, t),
          if (spec.firstStrike)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  loc('Özel: İlk vuruş 3× kritik; düşük canda geri sıçrar.',
                      'Special: first strike crits 3×; leaps back at low HP.'),
                  style: const TextStyle(
                      color: Color(0xFFD8C9A3), fontSize: 12.5)),
            ),
          if (spec.ranged)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  loc('Özel: Vur-kaç — düşman sokulunca geri açılır.',
                      'Special: hit-and-run — backs off when enemies close in.'),
                  style: const TextStyle(
                      color: Color(0xFFD8C9A3), fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  /// Bir eşleşme satırı: rakip portresi + adı + ÜSTÜN/SAKIN/DENK rozeti
  /// ve tek cümlelik NEDEN (taş-kağıt-makas mantığı öğrensin).
  Widget _matchupRow(UnitType self, UnitType other) {
    final my = counterMultiplier(self, other); // benim vuruşum
    final his = counterMultiplier(other, self); // onun vuruşu
    final String label;
    final Color color;
    final double mult;
    if (my > 1 && his <= 1) {
      label = loc('ÜSTÜN', 'FAVORED');
      color = const Color(0xFF8BC34A);
      mult = my;
    } else if (his > 1 && my <= 1) {
      label = loc('SAKIN', 'BEWARE');
      color = const Color(0xFFE08A5A);
      mult = his;
    } else {
      label = loc('DENK', 'EVEN');
      color = const Color(0xFF9E9E8F);
      mult = 1;
    }
    final reason = _matchupReason(self, other);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3A20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CustomPaint(
              painter: _AntPortraitPainter(other),
              size: const Size(34, 34)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unitSpecs[other]!.name,
                    style: const TextStyle(
                        color: Color(0xFFF2E8D5),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5)),
                if (reason.isNotEmpty)
                  Text(reason,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              mult > 1
                  ? '$label  ×${mult.toStringAsFixed(1)}'
                  : label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Eşleşmenin NEDENİ — counter zincirinin hikâyesi (iki yönlü).
  String _matchupReason(UnitType self, UnitType other) {
    String forPair(UnitType a, UnitType b) => switch ((a, b)) {
          (UnitType.wood, UnitType.leafcutter) => loc(
              'Asit kalın zırhı deler; menzil sayesinde çeneye hiç girmez.',
              'Acid melts thick armor; range keeps it clear of the jaws.'),
          (UnitType.trapjaw, UnitType.wood) => loc(
              'Kritik ilk vuruş menzilliyi tek lokmada indirir.',
              'The critical first strike drops the ranged ant in one bite.'),
          (UnitType.fire, UnitType.trapjaw) => loc(
              'Sürü kalabalığı kritik vuruş avantajını boğar.',
              'Swarm numbers smother the crit advantage.'),
          (UnitType.leafcutter, UnitType.fire) => loc(
              'Kalın zırh iğne yağmurunu umursamaz, çene sürüyü biçer.',
              'Thick armor shrugs off the stings; the jaws mow the swarm.'),
          _ => '',
        };
    final a = forPair(self, other);
    if (a.isNotEmpty) return a;
    return forPair(other, self);
  }

  Widget _statBox(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFFF2E8D5),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _AntPortraitPainter extends CustomPainter {
  _AntPortraitPainter(this.type);

  final UnitType type;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFF57472E),
    );
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-1.5708);
    canvas.scale(size.width / 32 * unitSpecs[type]!.scale);
    paintAnt(canvas, type,
        walkPhase: 0.9,
        idleTime: 0.4,
        teamColor: const Color(0xFF9163BC));
  }

  @override
  bool shouldRepaint(covariant _AntPortraitPainter old) => old.type != type;
}

/// Wiki bina görseli — OYUNDAKİ ressamla (building_painter) birebir çizim.
/// 'nest': ana yuva tümseği; 'capture': ele geçirme halkalı nötr bina.
class _BuildingArtPainter extends CustomPainter {
  _BuildingArtPainter({this.type, this.art});

  final BuildingType? type;
  final String? art;

  static const _team = Color(0xFFDB6C22);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFF57472E),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(8)));
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 118);
    if (type != null) {
      final dy = type == BuildingType.tower ? 14.0 : 4.0;
      paintBuilding(canvas, type!,
          center: Offset(0, dy), level: 2, tint: _team, time: 0.8, seed: 7);
    } else {
      switch (art) {
        case 'nest':
          _nest(canvas);
        case 'swamp':
          _swamp(canvas);
        case 'digsite':
          _digsite(canvas);
        case 'wasp':
          _wasp(canvas);
        case 'scorpion':
          _scorpion(canvas);
        default:
          _capture(canvas);
      }
    }
    canvas.restore();
  }

  /// Pürüzlü organik kapalı şekil (mini sahneler için).
  Path _blob(Offset center, double radius, int seed,
      {int points = 12, double jitter = 0.2, double squishY = 1}) {
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * math.pi;
      final wob = math.sin(a * 3 + seed) * jitter +
          math.sin(a * 5 + seed * 1.7) * jitter * 0.5;
      final r = radius * (1 + wob);
      final x = center.dx + math.cos(a) * r;
      final y = center.dy + math.sin(a) * r * squishY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  /// Bataklık: çamur yatağı + ıslak benekler + sazlar + batmış karınca.
  void _swamp(Canvas c) {
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: 118, height: 118),
        Paint()..color = const Color(0xFF5E7C3E));
    c.drawPath(_blob(const Offset(0, 4), 46, 3, squishY: 0.72),
        Paint()..color = const Color(0xFF46482A));
    c.drawPath(_blob(const Offset(0, 2), 38, 6, squishY: 0.7),
        Paint()..color = const Color(0xFF565436));
    for (var i = 0; i < 5; i++) {
      final a = i * 1.3 + 0.6;
      c.drawPath(
        _blob(Offset(math.cos(a) * 20, math.sin(a) * 13), 6 + (i % 3) * 2,
            i * 3,
            points: 8, jitter: 0.3),
        Paint()..color = const Color(0xFF3A3E24),
      );
    }
    // Kabarcıklar + sazlar.
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        Offset(-14 + i * 13.0, -6 + (i % 2) * 9),
        1.6,
        Paint()
          ..color = const Color(0x59DDDCC2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final reed = Paint()
      ..color = const Color(0xFF6E8A44)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final rx in const [-34.0, 30.0]) {
      c.drawLine(Offset(rx, 18), Offset(rx + 3, 4), reed);
      c.drawLine(Offset(rx + 4, 18), Offset(rx + 9, 8), reed);
    }
    // Çamurda ağır ilerleyen karınca.
    c.save();
    c.translate(4, 6);
    c.rotate(-0.4);
    c.scale(1.5);
    paintAnt(c, UnitType.leafcutter,
        walkPhase: 0.3, idleTime: 0.4, teamColor: _team);
    c.restore();
  }



  /// Kazı geçidi: çatlaklı kaya tıkacı + kazı halkası + kazıcı karıncalar.
  void _digsite(Canvas c) {
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: 118, height: 118),
        Paint()..color = const Color(0xFF5E7C3E));
    // İki yanda dağ etekleri.
    c.drawPath(_blob(const Offset(-46, 0), 26, 5, squishY: 1.6),
        Paint()..color = const Color(0xFF6E685C));
    c.drawPath(_blob(const Offset(46, 0), 26, 9, squishY: 1.6),
        Paint()..color = const Color(0xFF6E685C));
    // Ortada koyu tıkaç.
    c.drawPath(_blob(const Offset(0, 0), 22, 7, squishY: 1.1),
        Paint()..color = const Color(0xFF5C554A));
    c.drawPath(_blob(const Offset(-3, -3), 13, 11),
        Paint()..color = const Color(0xFF6E675A));
    // Çatlaklar.
    final crack = Paint()
      ..color = const Color(0xFF2E2820)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(-6, -14), const Offset(2, -2), crack);
    c.drawLine(const Offset(2, -2), const Offset(-4, 10), crack);
    c.drawLine(const Offset(2, -2), const Offset(12, 6), crack);
    // Kazı halkası (%60).
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 34),
      -math.pi / 2,
      2 * math.pi * 0.6,
      false,
      Paint()
        ..color = _team
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    // Kazıcılar.
    for (var i = 0; i < 3; i++) {
      final a = 1.2 + i * 1.6;
      c.save();
      c.translate(math.cos(a) * 40, math.sin(a) * 40);
      c.rotate(a + math.pi);
      c.scale(1.25);
      paintAnt(c, UnitType.wood,
          walkPhase: i * 0.6, idleTime: 0.4, teamColor: _team);
      c.restore();
    }
  }

  /// Yaban arısı yuvası: katmanlı kâğıt kovan + devriye arıları.
  void _wasp(Canvas c) {
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: 118, height: 118),
        Paint()..color = const Color(0xFF5E7C3E));
    c.drawPath(_blob(const Offset(2, 12), 30, 5, squishY: 0.5),
        Paint()..color = const Color(0x552E2214));
    for (final (r, color, s) in [
      (30.0, const Color(0xFF9C8E76), 3),
      (24.0, const Color(0xFFB0A288), 6),
      (18.0, const Color(0xFFC2B396), 9),
      (12.0, const Color(0xFFB0A288), 12),
    ]) {
      c.drawPath(_blob(const Offset(0, -4), r, s, points: 11, jitter: 0.14),
          Paint()..color = color);
    }
    c.drawOval(Rect.fromCenter(center: const Offset(0, 8), width: 12, height: 10),
        Paint()..color = const Color(0xFF241A0E));
    // Arılar.
    for (var i = 0; i < 3; i++) {
      final a = i * 2.1 + 0.8;
      final wx = math.cos(a) * 42;
      final wy = -6 + math.sin(a) * 30;
      c.save();
      c.translate(wx, wy);
      c.rotate(a + 1.57);
      c.scale(1.6);
      for (final side in const [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(center: Offset(-0.5, side * 2.8), width: 4.6, height: 2.2),
          Paint()..color = const Color(0x66FFFFFF),
        );
      }
      c.drawCircle(const Offset(2.4, 0), 1.3,
          Paint()..color = const Color(0xFF2E2418));
      c.drawOval(Rect.fromCenter(center: const Offset(-1, 0), width: 5.4, height: 3),
          Paint()..color = const Color(0xFFE8B33C));
      final stripe = Paint()
        ..color = const Color(0xFF2E2418)
        ..strokeWidth = 1;
      c.drawLine(const Offset(-0.6, -1.4), const Offset(-0.6, 1.4), stripe);
      c.drawLine(const Offset(-2.2, -1.2), const Offset(-2.2, 1.2), stripe);
      c.restore();
    }
  }

  /// Yağmacı akrep: kıskaçlı gövde + kıvrık iğneli kuyruk + av halkası.
  void _scorpion(Canvas c) {
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: 118, height: 118),
        Paint()..color = const Color(0xFF5E7C3E));
    // Tehlike halesi.
    c.drawCircle(Offset.zero, 52,
        Paint()..color = const Color(0xFFB0553A).withValues(alpha: 0.08));
    c.save();
    c.translate(-2, 2);
    const body = Color(0xFF7A4A30);
    const dark = Color(0xFF5C3622);
    const lite = Color(0xFF96613E);
    final leg = Paint()
      ..color = dark
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final ax = 10.0 - i * 8.0;
        c.drawLine(Offset(ax, side * 7), Offset(ax + 3, side * 18), leg);
      }
      c.drawLine(Offset(15, side * 6), Offset(25, side * 15), leg);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(27, side * 17), width: 13, height: 8),
          Paint()..color = body);
    }
    for (var i = 0; i < 4; i++) {
      final w = 27.0 - i * 4;
      c.drawOval(
        Rect.fromCenter(
            center: Offset(5.0 - i * 8, 0), width: w, height: w * 0.62),
        Paint()..color = i.isEven ? body : lite,
      );
    }
    var tx = -22.0;
    var ty = 0.0;
    for (var i = 0; i < 4; i++) {
      tx -= 6.5;
      ty -= 4.5;
      c.drawCircle(Offset(tx, ty), 5.0 - i * 0.6, Paint()..color = dark);
    }
    c.drawPath(
      Path()
        ..moveTo(tx - 2, ty - 2)
        ..lineTo(tx - 10, ty - 10)
        ..lineTo(tx + 2, ty - 5)
        ..close(),
      Paint()..color = const Color(0xFFB0553A),
    );
    c.restore();
    // Avcı karınca (ödül peşinde).
    c.save();
    c.translate(38, -36);
    c.rotate(2.4);
    c.scale(1.3);
    paintAnt(c, UnitType.trapjaw,
        walkPhase: 0.5, idleTime: 0.4, teamColor: _team);
    c.restore();
  }

  /// Ana yuva: organik toprak tümsek + giriş + bayrak + devriye karınca.
  void _nest(Canvas c) {
    c.drawPath(buildingBlob(const Offset(2, 10), 40, 5, squishY: 0.72),
        Paint()..color = const Color(0x552E2214));
    c.drawPath(buildingBlob(const Offset(0, 6), 36, 5, squishY: 0.8),
        Paint()..color = const Color(0xFF6B4A2B));
    c.drawPath(buildingBlob(const Offset(0, 1), 27, 9, squishY: 0.78),
        Paint()..color = const Color(0xFF8A6437));
    c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 16, height: 11),
        Paint()..color = const Color(0xFF241A0E));
    drawBuildingFlag(c, const Offset(22, -10), tint: _team, time: 0.8);
    c.save();
    c.translate(-18, -12);
    c.rotate(-0.6);
    c.scale(1.5);
    paintAnt(c, UnitType.fire, walkPhase: 0.5, idleTime: 0.4, teamColor: _team);
    c.restore();
  }

  /// Ele geçirme: nötr mantar çiftliği + %65 dolmuş turuncu halka + kuşatanlar.
  void _capture(Canvas c) {
    paintBuilding(c, BuildingType.resource,
        center: const Offset(0, 2), level: 1, tint: null, time: 0.8, seed: 4);
    c.drawCircle(
      Offset.zero,
      44,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 44),
      -math.pi / 2,
      2 * math.pi * 0.65,
      false,
      Paint()
        ..color = _team
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    // Halkayı dolduran kuşatmacı karıncalar.
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * 1.1 + 0.4;
      c.save();
      c.translate(math.cos(a) * 52, math.sin(a) * 52);
      c.rotate(a + math.pi); // yüzü binaya dönük
      c.scale(1.25);
      paintAnt(c, UnitType.fire,
          walkPhase: i * 0.7, idleTime: 0.4, teamColor: _team);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BuildingArtPainter old) =>
      old.type != type || old.art != art;
}
