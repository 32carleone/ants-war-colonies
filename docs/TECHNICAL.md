# Ants War: Colonies — Teknik Belge

Bu belge projenin **kalıcı referansıdır**: mimari, sistemler, tema ve tasarım
dili burada. Yeni harita/yetenek/özellik eklerken **buradaki konsepte uygun**
ekleyin. (Oyun kuralları için: [GAMEPLAY.md](GAMEPLAY.md))

## 1. Mimari Genel Bakış

- **Flutter 3.38 + Flame 1.35.** `FlameGame` +
  `CameraComponent.withFixedResolution(1280×720)` — kaydırma yok, her ekran
  letterbox ile ölçeklenir (kenarlara kayalık uçurum silüeti çizilir).
- **Durum:** `GameState` (ChangeNotifier; evre: menu/playing/victory/defeat),
  `AntsWarsGame` (Flame sahnesi + oyun döngüsü). Maç yeniden başlatmada
  `matchId` anahtarıyla GameWidget tazelenir.
- **UI:** Flame sahnesinin ÜSTÜNE Flutter widget'ları (Stack) — üst bilgi barı,
  sol % kaması, sağ üretim butonları, sağ alt yetenek kartları. Oyun içi bina
  butonları ise Flame tarafında `InputController` çizer/işler.
- **Test:** 234 test; golden testler hem regresyon hem **varlık üretim hattı**
  (bkz. §7).

### Dosya Haritası (özet)

```
lib/
  data/        constants.dart (TÜM denge/renk sabitleri), units, counters,
               maps (7 normal + tutorialMap), campaigns (3 sefer × 5 görev
               + görev haritaları + ilerleme IO), abilities (11 güç),
               settings
  models/      player (team!), nest (sabit armyCap 200), building, game_map
               (MapTheme: grass/scorched/snow)
  game/        ants_wars_game (döngü, ekonomi, oto-savunma, sefer kurulumu,
               gerilim müziği tetikleyici, zafer), game_state (MissionSetup)
               unit_component (tasma, freeze/fear/armor buffları),
               nest_component, building_component (çok mermili kule),
               building_painter (bina çizimi — OYUN + WIKI ortak)
               map_component (temalı zemin/su[lav-buz]/dağ/köprü + waterMask
               + tema ortam parçacıkları)
               territory_component (bölge sınırları, Picture önbellekli)
               fog_of_war, pathfinding (A* + PassabilityGrid, NaN korumalı),
               spatial_grid, input_controller (bina/yuva butonları),
               bot_controller, ability_effects (+PoisonCloud/FireRing Fx),
               projectile, ant_painter, ant_sprite_cache,
               audio_controller (müzik rotasyonu + gerilim + bekçi)
  data/i18n    ÇOK DİL: `loc(tr, en)` yardımcı + isEnglish; veri sınıfları
               TR/EN alan çifti tutar, name/description getter'ları aktif
               dile döner (bkz. §10 Dil Desteği)
  net/         lan_protocol (portlar, mesaj tipleri, çerçeveleme),
               lan_discovery (UDP beacon + dinleyici), lan_host, lan_client,
               net_host_bridge, net_client_bridge (bkz. §9 LAN Multiplayer)
  ui/          main_menu, play_setup_screen, game_screen, game_hud
               (+ArmyCounter, güç barı), ability_hud, ability_art (11 özel
               çizim), wiki_screen, settings_screen, game_back_button,
               crossed_swords, mode_toggle, tutorial_overlay (koç sistemi),
               campaign_select/map/mission_brief ekranları, campaign_art,
               result_screen (sefer dönüş akışı), ant_portrait,
               multiplayer_screen (kur/katıl), lobby_screen
tool/update_map_previews.sh   test/goldens → assets/images kopyalar
```

## 2. Tema Renkleri (ANA PALET)

Yeni her UI/çizim bu paletten seçmeli:

| Rol | Hex |
|---|---|
| Ekran arka planı (en koyu yeşil) | `0xFF16200F` |
| Panel/kutu zemini | `0xE6223019` (opak: `0xFF223019`) |
| Panel içi/ikincil zemin | `0xFF2C3A20` |
| Kutu kenarlığı | `0xFF4A6130` |
| Vurgu yeşili (seçili/başlık) | `0xFF8BC34A` |
| Buton yeşili / parlak kenarı | `0xFF5C7A2E` / `0xFF9CCC65` |
| SAVAŞ gradyanı | `0xFF74A038 → 0xFF4E6B26` |
| Ana metin (krem) | `0xFFF2E8D5` |
| İkincil metin/ikon | `0xFFD8C9A3` |
| ALTIN (taç, maliyet, vurgu) | `0xFFE8B33C` (koyusu `0xFFB27F19`, parıltı `0xFFF6D879`) |
| Harcama/uyarı turuncusu | `0xFFE8683C` |
| Takım renkleri (`kTeamColors`) | turuncu `0xFFE05A33`, mavi `0xFF3A7BD5`, yeşil `0xFF7CB342`, mor `0xFFAB47BC` |
| Nötr | `0xFF9E9E8F` |
| Çimen zemini | `0xFF5E7C3E` (lekeler `0xFF557239/0xFF67854A/0xFF4F6B34`, ot `0xFF7A9A4C→0xFF96B565`) |
| Su katmanları (kıyı→açık) | `0xFF39472A, 0xFF2E5D74, 0xFF376C86, 0xFF4A7D96` (parıltı `0xFFBFE3F2`) |
| Toprak/ahşap | `0xFF5C4326, 0xFF7E613A, 0xFF6B5A38, 0xFF7A6540, 0xFF4A3A20` |
| Kaya/kar | `0xFF6E685C, 0xFF7A7468, 0xFF847E70` / `0xFFF3F3EA` |

## 3. Tasarım Dili (KIRMIZI ÇİZGİLER)

1. **Organik kenarlar, her yerde.** Daire/dikdörtgen yasak değil ama görünür
   doğa/dünya öğeleri (göletler, yuvalar, mantar yatakları, kıyılar, bölge
   sınırları, güç barı, uçurum kenarları) girintili çıkıntılı çizilir.
   Hazır yardımcılar: `buildingBlob()` (building_painter), `_organicBlob`
   (map_component), `_waterBand` (su bantları). Jitter deterministik (seed
   konumdan türetilir) — golden'lar stabil kalır.
2. **"Oyun bu, web sitesi değil."** Dropdown/checkbox gibi web bileşenleri
   yok; seçim kutuları, oyunvari anahtarlar (yeşil hap + altın topuz),
   dokun-sürükle-bırak etkileşimleri. Köşe yarıçapı UI kutularında **8px**.
3. **Simge > metin.** HUD'da açıklayıcı kelime kullanma; ikon + sayı yeter.
4. **Takım rengi varlığın İÇİNE işlenir** (abdomen yaması, bayrak, gövde
   tonu) — halka/çember gösterge kullanılmaz. Sahiplik (bayrak/ton/bölge
   sınırı) SİSTEN ETKİLENMEZ; sis yalnız canlı bilgiyi gizler.
5. **Tek jest:** önce seç sonra tıkla akışları yerine sürükleme otomatik
   seçer; bas-sürükle-bırak her yerde geçerli.
6. **Determinizm:** her prosedürel çizim sabit tohum kullanır
   (`Random(map.id.hashCode)`, konum tabanlı seed'ler). Oyun `rng` alanı
   testlerde `math.Random(7|42)` ile sabitlenir.

## 4. Çekirdek Sistemler

- **Geçilebilirlik + A\*:** `PassabilityGrid` (16px hücre) TerrainFeature
  geometrisinden; su/dağ blokajı, köprüler açar. A* octile + köşe kesme
  engeli + görüş hattı düzleştirme. `isBlockedAt/worldToCell` NaN korumalı
  (NaN'da `~/` UnsupportedError fırlatır — geçmişte çökme sebebiydi).
- **SpatialGrid:** ayırma/aggro/kule hedefi/ele geçirme sayımı için
  allokasyonsuz `forEachNear`. Her karede yeniden kurulur.
- **Savaş:** otomatik aggro (boşta ~8 karede bir taranır, fazlı); counter
  çarpanları `counters.dart`; menzilli kite, kapan çene kritik+kaçış;
  TASMA: nöbet noktasından 110px'ten fazla kovalayan asker bırakıp yerine
  döner; sıfır vektör normalize edilmez (`_safeAway`) — NaN üretimi yasak.
- **Ele geçirme:** `Building.updateCapture` sayımları **takım bazında**
  toplar (2v2'de müttefik güçler birleşir); hız √net ile ölçeklenir. Kule ×0.5.
- **Oto-savunma:** `_tickAutoDefense` 0.5 sn'de bir; 170px içinde düşman →
  garnizon tehdit merkezine tam boşalır (tüm oyuncular).
- **Yabani koloniler:** yuvası düşen oyuncunun binaları NÖTRE döner,
  askerleri `UnitComponent.combatTeam` ile benzersiz negatif takıma geçer —
  HERKESİ düşman beller, herkes onları vurur; bina ele geçiremez, kazı
  yapamaz, görüş vermez. Takım karşılaştırmaları combatTeam üzerindendir.
- **Harita sınırı:** birim update'i konumu [8, W-8]×[8, H-8] içine sabitler
  (itilme/kaçış dışarı taşıramaz; bloklu hücreye düşerse nearestOpen).
- **Maç karnesi:** Player.goldEarned/unitsLost sayaçları + nest.producedCount
  → maç sonunda GameState.lastPlayerStats (PlayerMatchStats listesi) ve
  totalBuildings doldurulur; ResultScreen çizelgeli karne çizer ve
  playMenuMusic ile oyun seslerini KESER (maç gerçekten biter).
- **Botlar:** `BotController` — karar aralığı/rezerv/eşikler zorluğa göre
  (`botParamsFor`) + **10 KİŞİLİK** (`botPersonas`): her maçta karıştırılan
  desteden dağıtılır (aynı maçta iki bot aynı karakteri almaz; seferde
  sabit `kBalancedPersona`). Kişilik çarpan bindirir: bina iştahları
  (econ/tower/power), saldırı eşiği, genişleme temposu/oranı, ek muhafız,
  savunma yarıçapı, yükseltme rezervi, dalga sayısı, üretim karışımı,
  ekonomi baskını (Komando/Fırsatçı). YAYILMA SKORLUDUR: tip iştahı ×
  bölge (bana düşmandan yakın ×1.4, düşman tarafı ×0.6) × mesafe — erken
  oyunda (bina<2) nüfus şartı gevşer, bot önce KENDİ bölgesini kapar;
  zengin bot turda iki yükseltme çeker. Temel akış: bilgi → üret
  (counter-akıllı) → savun
  (müttefik yuvaları dahil) → GELİŞ (öncelik: düşük seviyeli çiftlik →
  kule → güç; tavan normalde 3, zorda 4 — params.maxBuildLevel) →
  genişle (takım binaları HEDEF DEĞİL) →
  ilerle/keşif. NORMAL/ZOR botlarda PLAN KATMANI (params.strategic):
  (1) STRATEJİK NÖBET — cepheye en yakın 1-2 binada (önce kuleler) küçük
  garnizon tutulur; (2) TOPLANMA → TAARRUZ durum makinesi — ordu ileri
  karakolda (hedefe en yakın kendi binası, yoksa hattın %35'i) birikir,
  eşik dolunca TOPLUCA vurur; 12+ askerde ÇİFT KANAT (hedefe dik ±90px iki
  koridor); taarruzdan ~6 sn sonra biriken garnizon İKİNCİ DALGA olarak
  gönderilir. Savunma tetiklenirse toplanma iptal, yürüyen taarruz sürer.
  ANA ÜS KORUMASI: hücum/keşif çıkarımlarında garnizonda homeGuard
  muhafız kalır (normal 6, zor 8) — savunmada tam boşalır.
  Kolay bot düz oynar. Hedefin dibindekilere yeniden yol hesaplatılmaz
  (A* seli = kasma). Sise saygılıdır; yetenek setleri rastgele 3 farklı güç.
- **Eğitim koçu:** HUD hedefleri `TutorialKeys` (GlobalKey) ile GERÇEK
  konumlarından okunur (sabit piksel tahmini yok); adımlar arasında 1.3 sn
  "Harika!" kutlaması gösterilir (hızlı geçiş yok); her adımda başlık +
  detaylı alt açıklama (sub). İlk adım 3 asker ister.
- **Sürüm:** `kAppVersion` (constants) pubspec `version` ile elle senkron —
  menü Ayarlar kutusu, Ayarlar ekranı ve Geliştirici sayfasında gösterilir.
  Menü sağ üstünde buton seti (`_TopIconButton`) → DeveloperScreen.
  Menü arka planı iki katmandır: statik zemin + RepaintBoundary'li karınca
  geçidi (animasyon menünün geri kalanını yeniden boyatmaz).
- **Sis:** tek hafif karartma katmanı (alpha 0.38, önbellekli yumuşak delik
  dokusu, dstOut). Kaynaklar: takımın yuva/bina/birimleri.
- **Ses:** menü/oyun müzik HAVUZLARI rastgele rotasyonlu (parça bitince
  farklısı; `_playTrack` + onPlayerComplete); uzun döngülerde bekçi
  (tamamlanınca yeniden başlat + resume-if-stalled). Çatışma algılanınca
  (2+ birim inCombat) gerilim davulları fade-in/out; geri sayım tik +
  SAVAŞ! borusu; sentez SFX'ler prosedürel üretilir (CREDITS).
  SES ODAĞI KURALI: init `AudioPlayer.global.setAudioContext(mixWithOthers)`
  ayarlar — varsayılan focus GAIN'de her efekt Android ses odağını kapıp
  MÜZİĞİ DURAKLATIR; mixWithOthers ile oyun tüm sesleri kendi içinde
  karıştırır. Sık efektlerin tamamı SoundPool havuzundadır.
  ÇÖKME KURALI: rotasyon oynatıcılarında ASLA `ReleaseMode.stop` kullanma —
  Android'de audioplayers parça bitiminde native stop()→prepareAsync()
  çağırır ve IllegalStateException UYGULAMAYI ÖLDÜRÜR (Dart yakalayamaz).
  `_playTrack` bu yüzden `ReleaseMode.release` kullanır (bitişte oynatıcı
  bırakılır, rotasyon her parça için yeni AudioPlayer açar).
- **Sefer (kampanya) maçı:** `GameState.mission` (MissionSetup) doluysa —
  doğuş KARIŞTIRILMAZ (nestSpots[0]=oyuncu), tüm botlar takım 1, sabit
  loadout (1-3 slot), oyuncuya altın/bina desteği, botlara enemyGold,
  görev zorluğu bot paramlarını belirler; zaferde ilerleme kaydedilir ve
  sonuç ekranı SEFERE döndürür.
- **Bölge sınırları:** `TerritoryComponent` — yuva(160+10×sv)+bina(110+20×sv) organik
  blob'larının birleşimi − `MapComponent.waterMask`; sahiplik imzası
  değişince `Picture`'a bir kez kaydedilir.
- **Harita öğeleri (tur 29):** 5 yeni öğe — hepsi TerrainFeature/bina
  olarak haritaya gömülür, motor `map_elements.dart` + grid bayraklarıyla işler:
  - `swamp` (BATAKLIK): geçilebilir; `PassabilityGrid.isSlowAt` → birim hızı
    ×`kSwampSlowFactor` (0.55, herkese). Temalı çizim (çamur/kül/sulu kar).
  - `digsite` (KAZI GEÇİDİ): kapalı kaya tıkacı; çevresinde (`kDigRadius` 80)
    asker çoğunluğu kazar (√net / `kDigBaseTime` 47 sn — 10 asker ~15 sn), ilerleme KALICI
    (çekişme yalnız duraklatır). Açılınca `grid.openDug` engel haritasını
    kazılan öğeleri yok sayarak yeniden hesaplar — geçit HERKESE açık ve
    kalıcıdır. Çizim `DigSiteComponent` (tıkaç/halka/kazılmış patika).
  - `waspNest` (YABAN ARISI YUVASI): nötr, geçilmez, ele geçirilemez;
    `WaspNestComponent` 0.9 sn'de bir menzildeki (120) EN YAKIN askeri sokar
    (6 hasar, takım ayırmaz). YIKILABİLİR: dibindeki (r+32) askerlerin
    toplam DPS'i kovan canını (400) kemirir; yıkılınca `clearFeature` ile
    engel kalıcı açılır ve enkaz izi kalır. Alan baskısı öğesidir.
  - `BuildingType.hatchery` (KULUÇKA İSTASYONU / İKİNCİ ÇIKIŞ): normal ele
    geçirilebilir bina; `deployFromNest` hedefe yuvadan daha yakın sahip
    kuluçka varsa askerleri ORADAN doğurur (botlar da otomatik yararlanır).
    İnsan ayrıca kuluçkanın üstünden TUT-SÜRÜKLE ile çıkışı açıkça seçer:
    InputController `_dragHatchery` → `requestDeploy(exit:)` →
    `deployFromNest(exitOverride:)`; LAN'da `dep` mesajı `ex/ey` taşır ve
    host yalnız oyuncunun KENDİ kuluçkasıysa kabul eder.
    Gelir/güç yok; yükseltilemez ve dönüştürülemez (canUpgrade/convertTo +
    input_controller butonları kilitli). Botlar kazı yapmayı BİLMEZ (bilinçli
    kazı yalnız oyuncu avantajı — sefer dengesi buna göre kurulmuştur).
- **Su çizimi:** TÜM sular katman katman birlikte (önce hepsinin kıyısı,
  sonra koyu/orta/açık) → kesişimler tek kütle gibi kaynaşır. Kenarlar
  `_waterBand` ile dalgalı; `waterMask` aynı geometriyi kullanır.
- **Performans kuralları:** statik görseller `Picture`'a kaydedilir;
  karınca kareleri `AntSpriteCache` GPU dokusunda; birim repath 1.4 sn
  soğumalı; ses `AudioPool`; ordu tavanı yuva seviyesine bağlı (maks 165); boştaki birim aggro taraması ~8 karede bir (fazlı).

## 5. Denge Sabitleri (constants.dart)

Pasif gelir 2.5/sn · çiftlik +2/sn/sv · güç +%15/sv · bina yükseltme 50×sv
(maks 3) · dönüştürme 40 · başlangıç 100 altın + 10 ateş garnizonu ·
kraliçe 300 can · ele geçirme: yarıçap 70, süre ≈ 10/√net sn (kule ×2) ·
ordu tavanı SABİT 200 (yuva yükseltme sistemi KALDIRILDI) ·
kule: hasar 14+5L, cooldown 1.2−0.12(L−1), mermi = L, ele geçirme ×2 yavaş · seviye ele geçirme direnci ×(1+0.25(L−1)) · seviye tavanı: kule/çiftlik 4, güç 3, kuluçka 1 (Building.maxLevel) · geri sayım 3 sn. Birim tablosu GAMEPLAY.md'de.
Harita öğeleri: bataklık hız ×0.55 ·
kazı ≈ 47/√net sn (kalıcı, 10 asker ~15 sn) · arı: menzil 120, 6 hasar / 0.9 sn.
Denge mantığı: altın başına HP/DPS oranları counter zinciriyle dengelenir;
sürekli ateş üretimi ~11 altın/sn yakar → ekonomi binaları kilit roldedir.

## 6. Yeni İçerik Ekleme Rehberleri

### Yeni Harita Eklerken
1. `lib/data/maps.dart`'a `MapDefinition` yaz, `allMaps`'e ekle. Kurallar:
   - **Gerçek dünya esinli Türkçe ad** (Amazon Geçidi, Pasifik Atolü…).
   - Alan 1280×720; nokta simetrisi (640,360) veya oyuncu sayısına adil
     yerleşim. Yuvalar kenarlardan ≥130px içeride.
   - TerrainFeature türleri: `water` (nehir/moat çoklu nokta — HAFİF
     KIVRIMLI çiz; gölet tek nokta), `bridge` (suyu tamamen aşan uçlar),
     `root` (dağ sırası ayraç), `rock` (karlı tepe süsü), `swamp`
     (yavaşlatan çamur bandı), `digsite` (root
     sırasının ortasına eklenen kazılabilir tıkaç — root'u ikiye bölüp
     araya koy), `waspNest` (tek nokta, width ~32; binalardan ≥120px uzak
     tut ki ele geçirme alanları arı menziline girmesin).
   - HARİTA ÖĞESİ DOZU: normal haritada 1-3 öğe türü (en az 1); sefer
     haritasında konsepte uygun olanı seç (çorakta bataklık=kül çamuru). Kuluçka istasyonu buildingTypes'a
     `BuildingType.hatchery` olarak eklenir (mevcut ownedBuildings
     indekslerini bozmamak için LİSTE SONUNA ekle).
   - `theme:` MapTheme.grass (varsayılan) / **scorched** (çorak toprak,
     sular LAV, alev öbekleri + yükselen korlar) / **snow** (karlı zemin,
     sular BUZ, kuru çalılar + tipi). Sefer haritaları konsept temasını
     KULLANMALIDIR; normal haritalar grass kalır.
   - Strateji yerleşimi: kuleler köprübaşı/geçit bekçisi, çiftlikler
     yuvalara yakın, güç binaları çekişmeli orta alanlarda.
   - 4 kişilik haritalar otomatik olarak 2v2 havuzuna girer.
2. Testler kendiliğinden kapsar (map_test: açık zemin + tam bağlantı).
3. Görselleri üret: `flutter test --update-goldens test/golden_maps_test.dart`
   sonra `sh tool/update_map_previews.sh` (kartlardaki gerçek görüntüler).

### Yeni Yetenek Eklerken
1. `abilities.dart`: enum değeri + `AbilitySpec` (ad/açıklama/cooldown/
   radius/duration/global). Açıklamada sayıları yaz.
2. `ability_hud.dart` → `abilityIcon` switch'ine Material ikonu ekle.
3. `ability_effects.dart` → `castAbility` case'i (+ gerekiyorsa Fx bileşeni;
   pulse için `AreaPulseFx` hazır).
4. `bot_controller.dart` → `_tryAbilities` switch'ine hedefleme mantığı ekle
   (exhaustive switch — eklemeden derlenmez).
5. Buff gerekiyorsa `UnitComponent`'a alan+apply metodu (örnekler:
   speed/damage/armor/fear). Wiki ve seçici otomatik listeler.
6. `test/new_abilities_test.dart` desenine test ekle.

### Sefer (Kampanya) Görevleri
`lib/data/campaigns.dart`: 3 sefer (ateş/buz/adalar) × 5 görev; ilerleme
SharedPreferences'ta (`campaign_<id>_progress`, tamamlanan görev sayısı).
Görev eklemek = `CampaignMission.map`'e MapDefinition bağlamak (görev
haritaları allMaps DIŞINDA tutulur). Sayfa/kart çizimleri
`ui/campaign_art.dart`; ekranlar `campaign_select_screen` /
`campaign_map_screen`. Görev bitince `saveCampaignProgress(id, level)`.
Yetenek görsel dili: alan yetenekleri TAM DAİRE ÇİZMEZ — `wavyCircle`
(ability_effects.dart) ile kıvrımlı kenarlı alan; oynanış menzili gerçek
dairedir. Ateş Çemberi = ALAN etkisi (içi tamamen alev, 12 dps, 8 sn);
Dondurma = BUZ ZEMİNİ (6 sn alan; içindeki/giren düşmana 0.3 sn'de bir
2 sn'lik donma tazelenir — FrostFieldFx). Süre artışları cooldown
artışıyla dengelenmiştir; Takviye 7 karınca doğurur.

Savaş Kur'daki DÜŞMAN İTTİFAKI tiki (tekli, 3+ oyuncu):
`startMatch(enemyAlliance: true)` → botlar takım 1'de birleşir (sefer
takım sözleşmesiyle aynı; yuva dağılımı yine karışık).

Sefer maçlarında yetenekler sabitlenebilir, düşman sayısı 2v1..4v1
olabilir; denge için oyuncuya kule/altın verilebilir.

### Yeni UI Ekranı/Bileşeni
§2 paleti + §3 dili: koyu yeşil panel, 8px köşe, `GameBackButton`,
`AudioController.uiClick()`, metin yerine ikon, dropdown yok.

## 7. Test ve Varlık Hattı

- Oyun testi kalıbı: `AntsWarsGame(gameState: state, rng: math.Random(7))
  ..countdown = 0;` + `game.bots.clear();` (izolasyon gerekirse
  `nest.garrison.clear()`). Simülasyon: `game.update(0.05)` döngüsü.
- Golden'lar = varlık kaynağı: harita kartları (`golden_maps_test` →
  `tool/update_map_previews.sh`) ve uygulama ikonu (`app_icon_test` →
  `assets/icon.png` → `dart run flutter_launcher_icons`).
- Görsel değişikliklerde golden'ları `--update-goldens` ile yenilemek
  NORMALDİR; suite'i yeşil bırakmadan iş bitmiş sayılmaz.
- Test ortamında ses sessizdir (`FLUTTER_TEST` algısı); Ahem fontu metinleri
  kutu gösterir — cihazda normaldir.

## 8. Platform Notları

- **Android birincil hedef**; performans hassasiyeti yüksek (bkz. §4 sonu).
- iOS/macOS: `audioplayers_darwin` yerine Dart-stub override (eski Xcode
  uyumu). Xcode 15+ ile `dependency_overrides` kaldırılabilir.
- WEB desteği: `flutter build web --release` → `build/web/` (siteye bu
  klasörün İÇERİĞİ yüklenir). Alt klasörde barındırılacaksa
  `--base-href "/alt-yol/"` ile derle. `web/index.html`+`manifest.json`
  adları ve ikonlar markalıdır. Web'de oyun TAM EKRAN DEĞİLDİR:
  `main.dart` `_WebFrame` sayfayı koyu fonla doldurur ve oyunu ortada
  16:9 (maks 1024×576) yuvarlak köşeli çerçevede çalıştırır
  (MaterialApp.builder + kIsWeb; MediaQuery.maybeOf ile — builder
  bağlamında MediaQuery olmayabilir, .of atarsa İLK KARE HİÇ ÇİZİLMEZ).
  WEB SES KURALLARI: (1) `Platform.environment` webde yoktur —
  AudioController `kIsWeb` kontrolüyle sesi açık tutar; (2) webde
  `FlameAudio.createPool` HİÇ TAMAMLANMAYABİLİR — init web'de havuz
  kurmaz (sfx FlameAudio.play'e düşer) ve `main()` init'i `unawaited`
  başlatır; ikisi de kaldırılırsa web bomboş beyaz sayfada asılı kalır.
- Görünen ad "Ants War: Colonies" (AndroidManifest ve iOS
  CFBundleDisplayName). Dosya adlarında ":" yasak olduğundan macOS
  PRODUCT_NAME ve iOS CFBundleName "Ants War Colonies"dir — macOS derlemesi
  "Ants War Colonies.app" üretir. Menü logosu: büyük "ANTS WAR" + altında
  ufak altın "COLONIES" (main_menu.dart). İkon `assets/icon.png`
  kaynağından `flutter_launcher_icons` ile dağıtılır. İkon kaynağı: `python3
  tool/make_icon.py` (assets/assetsss.png referansından birebir işleme).

## 9. LAN Multiplayer (sunucusuz)

**Model: HOST-OTORİTER.** Oyunu yalnız kuran cihaz simüle eder; katılanlar
EMİR gönderir ve 10 Hz DURUM yayınını çizer. Sunucu/internet yoktur —
her şey yerel ağda çalışır (`lib/net/`).

- **Keşif:** host `LanBeacon` ile oyun bilgisini saniyede bir UDP broadcast
  eder (port 47311); katıl tarafı `LanDiscovery` ile listeyi kurar,
  4 sn yenilenmeyen kayıt düşer.
- **Oturum:** TCP (port 47312, meşgulse ardılları); mesajlar 4 bayt
  big-endian uzunluk + UTF-8 JSON (`encodeFrame`/`FrameDecoder`).
  İstemci→host: `slt` (lobide yer değiştirme) + `dep/mov/abl/prd/upg/cnv`;
  host→istemci: `lby/srt/st/fx/end/cls/kck` (lan_protocol.dart). Lobi
  yayını alıcıya özel `you` (kendi slotu), `hs` (kurucu slotu — kurucu da
  taşınabilir, hostSlot) ve `d` (bot zorluğu) taşır; slot değişimi yalnız
  BOŞ (bot) slotlara kabul edilir.
- **Kurulum:** lobide slotlar; start mesajı `seed + mapId + mode + slot +
  players` taşır. İKİ TARAF DA `GameState.startLanMatch` + seed'li
  `math.Random(seed)` ile AYNI yuva dağılımını üretir. Uzak insanlar
  `Player.remote` (humanPlayer = !isBot && !remote); boş slotlar bot.
- **Host:** `NetHostBridge` — emirleri sahiplik denetimiyle uygular, uzak
  yetenek bekleme sürelerini tutar, `_snapshot()` yayınlar (birimler
  netId'li, yuvalar, binalar, kaynaklar, kazı/kovan, elemeler),
  `castAbility` başında `broadcastFx`. Kopan oyuncuyu `playerLost` →
  BotController devralır. Maç sonu TEK TAKIM kalınca (`checkMatchEnd`):
  host elense de simülasyon sürer (seyirci), `end` mesajı karneleri taşır.
- **İstemci:** `AntsWarsGame.isNetClient` — update'te simülasyon atlanır,
  `NetClientBridge.applyPending()` durumu uygular (birim eşleme/lerp
  `UnitComponent.netSync`, üretim görünümü `Nest.netProgressOverride`).
  Kule/kovan/alan-hasarı tikleri istemcide kapalıdır; girişler
  `requestDeploy/requestProduce/useHumanAbility/InputController`
  intercept'leriyle EMİR olur. `spawnAbilityFxVisual` yalnız görsel basar.
- **Soket dayanıklılığı:** yazma tarafı hataları asenkron gelir —
  `socket.done.catchError` ŞART (yoksa RST uygulamayı düşürür); sunucu
  dinleyicisine de `onError` verilir.
- **İzinler:** Android INTERNET (+Wi-Fi multicast); macOS entitlements
  network.client + network.server (Debug ve Release).
- **Web'de kapalı:** dart:io soketleri webde yok — menü butonu kIsWeb'de
  bilgi mesajı gösterir.
- **Testler:** `lan_protocol_test` (çerçeveleme/json/ad üretimi),
  `lan_loopback_test` (gerçek soketle lobi akışı),
  `lan_match_sync_test` (uçtan uca: host simülasyonu ↔ istemci emri).

## 10. Dil Desteği (TR / EN)

- **Anahtar dosyasız iki dil:** UI metni kullanım yerinde çift yazılır —
  `loc('Savaş', 'Battle')` (lib/data/i18n.dart). Veri sınıfları
  (AbilitySpec, UnitSpec, MapDefinition, CampaignDef/Mission) TR alanını
  `name:`/`description:` adıyla alır, `nameEn` vb. ek alan taşır;
  `name` GETTER aktif dile göre döner — çağıran kod dilden habersizdir.
- **Seçim:** Ayarlar ekranındaki Türkçe/English çipleri
  `appSettings.language` ('tr'|'en') yazar; save() notifyListeners →
  main.dart kök `AnimatedBuilder(Listenable.merge([gameState,
  appSettings]))` TÜM arayüzü tazeler. Wiki bölümleri her build'de
  `_buildSections()` ile kurulur (seçim indeksle tutulur — kimlikle değil).
- **Kural:** yeni kullanıcı metni eklerken ya `loc(tr, en)` kullan ya da
  veri sınıfına EN alanı ekle; test `i18n_test.dart` EN alanlarının boş
  bırakılmadığını doğrular. Varsayılan dil Türkçedir; test ortamı tr'de
  kalır (golden'lar etkilenmez).

## 11. Yeni Sistemler (özet)

- **Yağmacı Akrep** (`scorpion_component.dart`): nötr canavar; kovan
  kemirme deseniyle avlanır, `_lastChewer`e 150 altın ödül,
  `respawnAfter` sonra aynı `home`a yenisi. Haritaya `MapDefinition
  .scorpionSpots` ile eklenir; LAN'da `sco` alanıyla senklenir
  (istemcide simülasyon kapalı, lerp).
- **Hayatta Kalma** (`gameState.horde`): oyuncu + BAŞTAN elenmiş yabani
  kaynak oyuncusu (yuvası yıkık); `_tickHorde` kenarlardan dalga üretir
  (aralık 22→11 sn, kadro büyür, 130 canlı tavanı). Zafer yok;
  `_checkElimination` horde dalında yalnız yenilgiyi işler,
  `lastHordeWave` sonuç ekranında.
- **Kâbus zorluğu**: `Difficulty.nightmare` + `BotParams.relentless`
  (ilk 45 sn karar temposu ×0.6, kişilik keskinleşir).
- **Yaralı geri çekilme**: `appSettings.autoRetreat` — YEREL insan
  askerleri %20 can altında `orderReturnToNest` + kalıcı aggro bastırma
  (yuva düşerse çözülür). LAN istemci oyuncularına uygulanmaz.
- **Maç geçmişi** (`data/match_history.dart`): endMatch → son 40 kayıt
  prefs'te; `stats_screen.dart` özet + liste. **Güç grafiği**:
  `strengthHistory` 5 sn örnekleme → sonuç ekranı çizgi grafiği; LAN
  end mesajı `hist` taşır.
- **Lobi sohbeti**: `cht` mesajı (hazır mesaj indexi) — host dağıtır,
  iki taraf `chats` ValueNotifier'ında son 6 mesajı tutar.
- **Titreşim**: `HapticFeedback` — yuva tehdidi (4 sn arayla) ve horde
  dalga borusu; `appSettings.vibration` bağlı.

## 12. Performans Düzeltmeleri (kasma turu)

- **Sis render'ı**: delikler artık 48px kovalarda BİRLEŞTİRİLİR (200
  asker ≈ 15-25 delik; eskiden asker başına dstOut çizimi + tam ekran
  saveLayer telefonu eziyordu). `highQuality=false` → saveLayer'sız
  satır-şeritli ucuz sis (ayarlardaki anahtar artık gerçekten çalışıyor).
- **A\***: (1) düz görüş kestirmesi — engel yoksa A* hiç kurulmaz;
  (2) çalışma dizileri damgalı (stamp) yeniden kullanılır — çağrı başına
  3 tam-ızgara tahsisi kalktı; (3) sezgisel %25 açgözlü.
- **Ortak rota yürüyüşü**: `UnitComponent.orderMoveShared` — çıkarma
  (deployFromNest), bot ilerleme/toplanma/taarruz kolları hedefe TEK rota
  hesaplar, tüm kol paylaşır (100 askerlik emir = 1 A*; eskiden 100).
- **Bot karar maliyeti**: canSee asker taraması spatialGrid'e indi;
  görünür düşman/saha listeleri tik başına önbelleklenir; üretim tip
  kararı tur başına bir kez.
- **Ele geçirme sayımı** ~0.12 sn'de bir (dt birikimli, hız aynı);
  **birim ayrışması** dönüşümlü karelerde (etki dt×2 ile korunur).

### Maç sonrası menü kasması (söküm sızıntısı)
Flame'de GameWidget sökülünce ÇOCUK bileşenlerin `onRemove`'u çağrılmaz
(yalnız removed bayrağı basılır). Harita sahnesi/bölge boyası/sis dokusu
gibi `Picture`/`Image` tutan bileşenlerin native belleği maçtan maça
birikir ve menü dahil uygulamayı kasardı. Çözüm: `AntsWarsGame.onRemove`
ağacı (`descendants()`) gezip her bileşenin `onRemove`'unu elle tetikler
— regresyon: `test/teardown_leak_test.dart`. Ayrıca menü animasyonları
`_menuAnimT` freniyle 30fps'e (düşük kalitede 12fps) yuvarlanır.

### Yetenek yasak bölgesi + Kâbus botu (denge turu)
- `kAbilityNestExclusion` (170): hedefli yetenek RAKİP yuvasının bu
  yarıçapına atılamaz — `AntsWarsGame.abilityAllowedAt` insan
  (`useHumanAbility`), bot (`_tryAbilities`) ve LAN host doğrulamasında
  ortaktır; InputController sürükleme önizlemesi yasakta KIRMIZI alan +
  çarpı çizer. Test: `ability_exclusion_test.dart`.
- KÂBUS (relentless) botu: genişlemede düşman tarafı cezası ve çekişme
  cezası kalkar, cooldown ×0.7, nüfus boldaysa aynı tikte İKİNCİ koloni
  kolu; yükseltme 3 tura kadar (zenginlik eşiği 90); nöbet 3 nokta × 4
  muhafız (5 sn); taarruz hedefi %40 ihtimalle düşman yuvası yerine
  `_strategicEnemyPoint` (en değerli görünür rakip binası) — yuva
  bilinmiyorken plan da bu çapayla kurulur.
- Ses: `_guardLoop(p, stillCurrent)` durdurulan döngünün "tamamlandı"
  olayıyla HORTLAMASINI engeller (menüde süren ambiyans/davul buydu);
  müzik rotasyonunun onDone'u sahneye (`_inGame`) bakar — seq
  karşılaştırması menüde rotasyonu yanlışlıkla öldürüyordu.

### Ordu atlası + zorluk basamakları (kasma/denge turu 2)
- **ArmyLayer (army_layer.dart)**: tüm karıncaların gölge+ceset+gövde+
  takım yaması TEK `drawRawAtlas` çağrısında (AntSpriteCache artık tek
  sprite sayfası; beyaz takım yaması hücresi modulate ile boyanır). Can
  barları da katmanda düz dikdörtgen. UnitComponent.renderTree yalnız
  seçim/buz gerektiğinde ağaca girer (SEÇİLİ birim tam yoldan çizilir —
  halka gövdenin altında). 600 birimlik komut seli → 1 native çağrı.
- **BotParams.tier** (0-3): davranış kapıları basamağa bağlandı — eski
  Kâbus paketi (bölge/çekişme cezasız genişleme, çift kol, 3 tur
  yükseltme, yoğun nöbet, %40 stratejik vuruş) artık ZOR'da; KÂBUS bir
  kademe sivri (tempo 0.95sn, eşik 8, yıldırım açılışı 75 sn, counter
  %90, zengin eşiği 60, nöbet cd 4, vuruş %45). NORMAL dirileşti
  (tempo 2.2, rezerv 12, eşik 13, bölge cezası 0.75).
- **Yükseltme önceliği**: `_produce` artık ÖNCE `_developBuildings`
  çağırır — üretim tüm parayı yiyip botu seviye 1'de bırakıyordu
  (Vali 150 sn'de 0 yükseltme → 30 sn'de ilk, 150 sn'de tümü sv.2).

### Açılış evresi + Karşılaşma ekranı
- `BotParams.openingSecs` (kolay 100 / normal 80 / zor 65 / kâbus 55):
  bot bu süre (ve <5 bina) boyunca taarruz planı/ilerleme kurmaz, düşman
  tarafına genişleme kolu sürmez (zone 0.3) — ilk hedef yayılmak/gelişmek;
  savunma her zaman serbest. Test: `bot_opening_test.dart`.
- `MatchIntroOverlay` (ui/match_intro_overlay.dart): maç yüklenince
  savaşçı kartları yan yana (portre + ad/kişilik + zorluk + 3 yetenek),
  kartlar arasında MÜTTEFİK=el sıkışma / DÜŞMAN=çapraz kılıç. Oyun
  `wantsIntro` iken (sefer/eğitim/horde hariç) GameScreen duraklatır;
  tekli/kurucu BAŞLA'ya basınca akar. LAN katılanı kurucuyu bekler —
  kurucu duraklıyken anlık görüntü akmaz, `NetClientBridge.snapshotsSeen`
  ilk görüntüde overlay'i kapatır (protokol değişmedi).

### Zorluk programı yeniden dizilimi (Kâbus = Zor + 2× para)
- KÂBUS parametreleri ZOR ile BİREBİR aynı (`tier: 2`); tek fark
  `startMatch`'te botların başlangıç parasının 2 katlanması. `relentless`
  bayrağı ve %25 gelir avantajı KALDIRILDI.
- ZOR+ program akışı: açılışta yayılma + hafif yükseltme + YALIN ordu
  (`openingLean`: pop ≥ 2×squadSize'ta üretim durur, kuyruk 2); orta
  evrede (açılış→+90 sn) feromon ×1.35 / kule ×1.25 iştah;
  `_convertByPersona` (iştahı ≥1.3 karakterler, para ≥ dönüşüm+140,
  ≥4 bina, sevilen tür azınlıktaysa en düşük iştahlı sv-1 binayı çevirir,
  cd 30); kişilik kültürü: aggression^1.35, ekonomi vuruş şansı
  kişiliğe bağlı (raidsEconomy 0.55 / diğer 0.3), dalgalar yalnız
  persona.extraWaves.
- KULE KOLU AKLI: görünen sahipli kuleye 4+2×seviye askerden az kol
  GÖNDERİLMEZ (yetmiyorsa hedef seçilmez; yetiyorsa expandFrac o sayıyı
  karşılayacak kadar büyütülür) — damla damla asker kule ateşinde
  eriyordu.
- NestComponent priority 10 → -1: karıncalar ana yuvanın ÜSTÜNDE çizilir.


### Gelgit mekaniği KALDIRILDI
`TerrainKind.tidal` ve tüm gelgit döngüsü (grid tideOpen, _tickTide,
görsel katman, LAN 'tide' alanı, wiki girdisi) oyundan söküldü. Eski
gelgit sığlıkları KALICI KÖPRÜLERE çevrildi: Ege (3 dış köprü), Pasifik
(2 yan köprü), buz seferi Donmuş Göl (buz köprüsü), ada seferi m1/m3/m5
(m3 adı 'Orta Köprü' oldu).

### Kule dengesi + Yağmacı Kampı + komuta araçları
- KULE: hasar 14+5L (eski +8L), cooldown 1.2−0.12(L−1) — sv4 DPS ~%400'den
  ~%160'a indi (ordular kuleye varamadan eriyordu).
- YAĞMACI KAMPI (`raider_camp_component.dart`): nötr kamp; 70px çevre
  çoğunluğu halkayı doldurur (√net/8sn), dolunca DOLDURANA 5 yağmacı
  (2 ateş/1 orman/1 kapan/1 kesici), 75 sn sönme, sonra sıfırlanır.
  `MapDefinition.raiderCampSpots` (Tuna Kıyıları, Kilimanjaro); LAN
  snapshot 'camp' [prog,cd,leaderId]. Test: raider_camp_wheel_test.
- ORDU BÖLME: seçili küme sürüklenince SOL % KAMASI kadar kesir yürür
  (hedefe en yakın olanlar; seçim yürüyen kola geçer). %100 = eski davranış.
- KOMUTAN ÇARKI eklendi ve KALDIRILDI (kullanıcı istemedi).
- YUVA YÜKSELTMESİ 2 KADEMELİ: Nest.upgradeLevel (1: 500→hız ×2,
  2: 1000→ANINDA üretim). Yetenek dolumları güce göre katmanlı
  (hasar ultileri 100-130 sn, destekler 60-90).
- MAÇ SAATİ: sağ üstte mm:ss (game_hud MatchClock; debug ikonu soluna
  alındı).
