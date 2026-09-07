import 'dart:ui';

/// Oyunun sabit mantıksal çözünürlüğü (yatay).
/// Harita her zaman bu alana sığar; farklı ekranlarda letterbox ile ölçeklenir.
/// Kaydırma (pan/scroll) yoktur — kamera sabittir.
const double kGameWidth = 1280;
const double kGameHeight = 720;

/// Takım renkleri: karınca çizimlerinin gövdesini bozmadan
/// halkalar, doluş göstergeleri ve UI vurgularında kullanılır.
/// Takım paleti — CANLI, hafif koyu tonlar: oyuncu TURUNCU, ana düşman
/// MOR, müttefik YEŞİL, dördüncü TURKUAZ.
const List<Color> kTeamColors = [
  Color(0xFFDB6C22), // canlı koyu turuncu
  Color(0xFF9163BC), // canlı koyu mor
  Color(0xFF6CA53A), // canlı yeşil
  Color(0xFF2FA394), // canlı koyu turkuaz
];

/// Nötr (sahipsiz) varlıkların rengi.
const Color kNeutralColor = Color(0xFF9E9E8F);

/// Uygulama sürümü (pubspec.yaml `version` ile senkron tutulur).
const String kAppVersion = '1.0.0';

/// Oyuncu başına başlangıç kaynağı.
const int kStartingResources = 100;

/// Kraliçenin toplam canı. Yuva garnizonu eridikten sonra hasar buna işler.
/// (300 → 750: ana üsler baskınla ANINDA düşmesin, savunmaya dönüş şansı olsun.)
const double kQueenMaxHp = 750;

/// Tüm oyunculara saniye başına akan pasif kaynak geliri.
const double kPassiveIncomePerSec = 2.5;

/// Garnizondaki bir birimin, yuva savunurken emebileceği hasar:
/// spec.defensePower * bu katsayı.
const double kDefenseHpPerPower = 10;

/// Maç başında yuvada hazır bekleyen Ateş Karıncası sayısı.
const int kStartingGarrison = 10;

/// Ordu tavanı (yuva + saha toplamı) — SABİTTİR (yuva yükseltmesi TAVANI değil ÜRETİM HIZINI etkiler).
const int kArmyCap = 200;

/// Zincirleme küme seçimi: bir askerin "yakınındaki" sayılan dostların yarıçapı.
const double kClusterRadius = 45;

/// Yuvaya dokunma/sürükleme başlangıcı için yakalama yarıçapı.
const double kNestTapRadius = 55;

/// YETENEK YASAK BÖLGESİ: hedefli yetenekler RAKİP ana yuvalarının bu
/// yarıçapı içine atılamaz (takviyeyle oto-savunmayı boşaltıp ateş
/// çemberiyle orduyu silme açığının kapanışı). Kendi yuvana serbest.
/// Yetenek sürüklerken sınır PÜRÜZLÜ (wavyCircle) çizilir.
const double kAbilityNestExclusion = 210;

// ------------------------------------------------------------- binalar

/// Bina ele geçirme: çevresindeki askerlerin sayıldığı yarıçap.
const double kCaptureRadius = 70;

/// Ele geçirme TABAN süresi: 1 net askerle bu kadar sürer; kalabalık
/// hızlandırır (süre ≈ taban / √net → 4 asker ~5 sn, 9 asker ~3.3 sn).
const double kCaptureBaseTime = 10;

/// Kaynak binasının seviye başına saniyelik geliri.
const double kResourceIncomePerLevel = 2.0;

// FEROMON MERKEZİ: seviye başına hem SALDIRI hem ZIRH verir (eskiden
// yalnız +%15 hasardı; ikiye bölününce dozlar düşürüldü).
const double kPowerBonusPerLevel = 0.10; // hasar +%10/sv
const double kPowerArmorPerLevel = 0.06; // alınan hasar -%6/sv (tavan %25)

/// ANA YUVA YÜKSELTMELERİ: 1. kademe üretim hızı ×2; 2. kademe ANINDA
/// üretim (basınca asker hazır).
const int kNestUpgradeCost = 500;
const int kNestUpgrade2Cost = 1000;

/// Bina yükseltme maliyeti: seviye × bu değer (1→2: 50, 2→3: 100).
/// Denge: hızlanan üretimle yükseltmeler cazip kalsın (çiftlik geri
/// ödemesi ~33 sn).
const int kUpgradeCostPerLevel = 50;

/// Binayı yıkıp başka türe çevirme maliyeti (seviye 1'e döner).
const int kConvertCost = 40;

const int kMaxBuildingLevel = 3;

// ------------------------------------------------------------- sis (görüş)

/// Bir askerin görüş yarıçapı.
const double kUnitVision = 110;

/// Ana yuvanın görüş yarıçapı (geniş).
const double kNestVision = 190;

/// Kule dışı binaların görüş yarıçapı: seviyeyle bir tık büyür.
double buildingVision(int level) => 105 + 15.0 * level;

/// Kulenin görüş yarıçapı: taban + seviye başına ek (uzağı görür).
double towerVision(int level) => 150 + 20.0 * level;

// ---------------------------------------------------- harita öğeleri (yeni)

/// Bataklık içindeki askerin hız çarpanı (yavaşlar ama geçer).
const double kSwampSlowFactor = 0.55;

/// Kazı geçidi: süre ≈ taban / √net — TAŞ ÇETİN: 10 asker ~15 sn,
/// 25 asker ~9.5 sn; tek asker pratikte kazamaz (~48 sn).
/// İlerleme KALICIDIR (çözülmez); rakip çoğunluğu kazıyı yalnız duraklatır.
const double kDigBaseTime = 47;

/// Kazı sayılan yarıçap (tıkaç merkezinden).
const double kDigRadius = 80;

/// Yaban arısı yuvası: menzil, sokma hasarı ve sokma aralığı (sn).
/// Arılar TAKIM AYIRMAZ — menzile giren herkesi sokarlar.
const double kWaspRange = 120;
const double kWaspDamage = 6;
const double kWaspCooldown = 0.9;

/// Yaban arısı KOVANININ canı: dibine yığılan ordu kemirerek yıkabilir
/// (yıkım sırasında sokulmayı göze alırsın). Yıkılan kovan geri gelmez.
const double kWaspNestHp = 400;
