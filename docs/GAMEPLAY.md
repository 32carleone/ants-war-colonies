# Ants War: Colonies — Oyun Rehberi

Bu belge oyunun tüm kurallarını, birim/bina/yetenek detaylarını ve
modlarını içerir. Genel tanıtım için [README](../README.md), teknik
mimari için [TECHNICAL.md](TECHNICAL.md) okunmalıdır.

## Temel Kurallar

- **Üretim ve çıkarma yalnız ana yuvadan** yapılır; kraliçe yuvadan asla çıkmaz.
- **Binalara asker sokulmaz.** Binanın 70px çevresinde asker üstünlüğü kuran
  taraf doluş halkasını doldurur — kalabalık hızlandırır (1 net asker ~10 sn,
  9 asker ~3.3 sn); SAHİPLİ bina tam el değiştirince **1 SEVİYE geriler**
  (en az 1 — nötr binayı ilk almak yıpratmaz). Kuleler 2× uzun
  sürer ve **nötrken bile herkese ateş eder**. SEVİYE DİRENÇ KATAR: her
  yükseltme ele geçirmeyi %25 (kulede %12) uzatır.
- Yuvaya geri sokulan askerler garnizona katılır; yuvaya gelen hasar önce
  garnizonu eritir, sonra kraliçeye (750 can) işler.
- **Yıkılan koloni:** kraliçesi ölen oyuncunun binaları NÖTRE döner,
  sahadaki askerleri YABANİLEŞİR — herkesi düşman beller (eski
  müttefikleri dahil), bina ele geçiremez.
- **Otomatik savunma:** düşman yuvanın dibine (170px) gelirse garnizon
  kendiliğinden dışarı fırlar ve savaşır; tehdit sürerken yeni üretilenler de
  otomatik çıkar.
- **Ordu tavanı SABİTTİR: 200 asker** (yuva + saha toplamı).
- **Ana yuva yükseltmeleri (2 kademe):** yuvana dokununca çıkan butonla
  **1. kademe 500 altın → üretim hızı ×2**, **2. kademe 1000 altın →
  ANINDA üretim** (basınca asker hazır). Botlar da alır.
- Maç **3 saniyelik geri sayımla** başlar (harita görünür, %/inceleme serbest,
  emirler kilitli), ardından "SAVAŞ!".

## Askerler (4 tip, taş-kağıt-makas)

| Tip | Rol | Maliyet | Üretim | Özel |
|---|---|---|---|---|
| Ateş Karıncası | Sürü / ucuz piyade | 10 | 0.7 sn | Kalabalıkken kabus |
| Orman Karıncası | Menzilli | 30 | 1.4 sn | Asit püskürtür, vur-kaç (kite) |
| Kapan Çene | Suikastçı | 30 | 1.4 sn | İlk vuruş 3× kritik; düşük canda geri sıçrar |
| Kesici Asker | Tank | 50 | 2.1 sn | 120 can, yürüyen kalkan |

Counter zinciri: **Orman → Kesici (1.5×)**, **Kapan → Orman (1.5×)**,
**Ateş → Kapan (1.3×)**, **Kesici → Ateş (1.5×)**.

## Binalar

- **Kule** — otomatik çakıl fırlatır; seviye menzil, hasar (+5/sv), atış
  hızı ve MERMİ SAYISI (sv4: 4 hedefe birden) getirir. Ele geçirmesi diğer
  binalardan 2 KAT uzun sürer.
- **Mantar Çiftliği** — sv. başına +2 kaynak/sn (maks 4 seviye; ekonominin belkemiği).
- **Feromon Merkezi** — sahibinin TÜM askerlerine sv. başına **+%10 hasar
  ve +%6 zırh** (alınan hasar azalır; zırh tavanı %25).
- **Kuluçka İstasyonu** — İKİNCİ ÇIKIŞ: senin olduğunda, yuvadan çıkan
  askerler hedefe daha yakınsa buradan sahaya iner; ayrıca kuluçkanın
  ÜSTÜNDEN tut-sürükle yaparak çıkışı açıkça buradan başlatabilirsin
  (yükseltilemez/dönüştürülemez).
- Kendi binana dokununca çevresinde **ikon butonlar** belirir: yükselt
  (50×seviye; kule ve çiftlik maks 4, güç maks 3) ve ⇄ dönüştür
  (40 altın, sv. 1'e döner).

## Harita Öğeleri

- **Bataklık** — geçilebilir çamur: içindeki HERKES yavaşlar (×0.55).
- **Kazı Geçidi** — çatlaklı kaya tıkacı: çevresinde çoğunluk kuran taraf
  kazar. Taş ÇETİNDİR: 10 asker ~15 sn, tek asker pratikte kazamaz; açılan
  geçit HERKESE, KALICI olarak açıktır.
- **Yağmacı Kampı** — NÖTR paralı asker kampı: çevresinde çoğunluk kuran
  taraf halkayı doldurur; dolunca 5 yağmacı (2 Ateş, 1 Orman, 1 Kapan,
  1 Kesici) dolduranın ordusuna katılır. ~75 sn sönüp yeniden açılır
  (Tuna Kıyıları, Kilimanjaro Yaylaları).
- **Yağmacı Akrep** — bazı haritalarda devriye gezen NÖTR canavar: menzile
  gireni kıskaçlar (takım ayırmaz), canı 500'dür; dibine yığılan ordu
  kemirir, SON DARBEYİ vuran 150 altın ödül alır. Ölen akrep GERİ
  GELMEZ — bölge kalıcı güvene düşer (Himalaya, Serengeti, Panama,
  Büyük Kanyon, Halong).
- **Yaban Arısı Yuvası** — nötr kovan; menzile giren her askeri sokar
  (takım ayırmaz). Dibine yığılan ordu KEMİREREK YIKABİLİR (can 400,
  kemirenler sokulmaya devam eder); yıkılan kovanın yeri kalıcı yol olur.

## Kraliçe Yetenekleri (11 güç, 3 slot)

Ana menüde kraliçenin altındaki slotlardan seçilir (her güçten en fazla bir).
Kullanımı: butona **bas, hedefe sürükle, bırak** (sise kör atış serbest).
Maç başında tüm güçler dolumda başlar; barı dolan aktifleşir.
**DOLUM DENGESİ:** ordu silen hasar ultileri (Yıldırım 110 sn, Ateş
Çemberi 130, Dondurma 120, Zehir 100) ~2 dakikada bir döner; destekler
(Hız 60, İyileştirme 70, Zırh 75...) daha sık.
**YASAK BÖLGE:** hedefli yetenekler RAKİP ana yuvasının 210px yakınına
atılamaz (önizleme kırmızıya döner, bırakınca dolum yanmaz) — kendi
yuvanın dibi serbesttir; botlar da aynı kurala uyar.

Yıldırım · Takviye · Orman Çağrısı · Kesici Çağrısı · Hız Feromonu · Savaş Çılgınlığı · İyileştirme · Yağmur
(global) · Zehir Bulutu (alan DoT) · Korku Çığlığı (düşman kaçırtma) ·
Zırh Feromonu (hasar azaltma) · **Ateş Çemberi** (alan baştan başa alev:
içinde kalan yanar) · **Dondurma** (zemin buz keser: üstündeki ve içine
giren donar).

Botlar her maçta rastgele 3 farklı güç kuşanır ve setleri düşman yuvasının
altındaki mini rozette görünür — rakibin elini bilmek taktik verir.

**Bot kişilikleri:** her maçta her bot 10 karakterlik havuzdan FARKLI bir
kişilik alır (Komutan, Vali, Kale, Cengaver, Kolonici, Kuşatmacı, Komando,
Sürü Lordu, Teknolojist, Fırsatçı). Kimi erken saldırır, kimi kule diker,
kimi ekonomini basar — maçlar tekdüzeleşmez. Seferde denge bozulmasın diye
kişilik sabittir.

## Modlar ve Haritalar

- **Tekli:** 1v1 / 1v1v1 / 1v1v1v1 (haritaya göre), 4 bot zorluğu
  (Kolay/Normal/Zor/KÂBUS). NORMAL ve üstü botlar tam programı oynar:
  önce kendi bölgesine yayılır, hafif yükseltme + yalın ordu; sonra
  yakın feromon merkezleri/kuleleri alır, karakterine göre bina
  dönüştürür, ordusunu büyütüp stratejik noktalara konuşlanır ve fırsat
  kollayıp vurur. ZOR ve KÂBUS davranışça birebir aynıdır — fark
  botların başlangıç parası: **zor ×1.5, kâbus ×5** (açık kural, gelir
  hilesi yok). Kolay: yavaş düşünen, plansız bot.
  3+ oyunculu haritalarda **DÜŞMAN İTTİFAKI** tiki: açıkken tüm düşman
  botlar tek takım olur (2v1/3v1) — sisi paylaşır, birlikte kuşatır.
- **Eşli 2v2:** yapay zeka müttefikle iki bota karşı — müttefikler aynı tarafta
  doğar, sisi paylaşır, ele geçirmede güçleri birleşir; zafer takımcadır.
- **MULTIPLAYER (yerel ağ):** sunucusuz, tamamen LAN — aynı Wi-Fi'daki
  cihazlar birbirini otomatik bulur. Menüdeki MULTIPLAYER butonundan
  solda **Oyun Kur** (harita + format: 1v1 / 1v1v1 / 1v1v1v1 / 2v2 eşli),
  sağda **Oyuna Katıl** ("X'in oyunu" listesi, dokun-katıl). Boş slotlar
  botla dolar (zorluklarını kurucu seçer); LOBİDE boş bir slota dokunarak
  yerini/takımını değiştirebilirsin — 2v2'de 4 slotun dördü de insan
  olabilir, 3 kişiyseniz karşıya bot verilebilir. Bağlantısı kopan
  oyuncunun kolonisini bot devralır. Herkese
  ilk girişte `Player#####` biçiminde rastgele bir ad verilir (menüdeki
  kalemle değiştirilir); lobide çakışan adlar "(2)" ekiyle ayrışır.
- **Eğitim Kampı:** ilk açılışta önerilir; spot ışıklı, jest animasyonlu
  koç adım adım tüm özellikleri YAPTIRARAK öğretir (Savaş Kur'daki altın
  EĞİTİM kartından tekrar oynanabilir).
- **HAYATTA KALMA (Horde):** Savaş Kur'daki kor kırmızısı karttan —
  Amazon Savunması'nda (Amazon Geçidi'nin TEK KÖPRÜLÜ varyantı) tek
  başına, gittikçe sıklaşan ve sertleşen YABANİ
  dalgalarına karşı dayan. Zafer yok; süre skorundur (rekor istatistik
  sayfasında). Dalga sayacı ekranın üstündedir.
- **SEFER (hikâye modu):** 3 kampanya × 5 görev — aşağıda.

| Harita | Mod | Konsept |
|---|---|---|
| Amazon Geçidi | 1v1 | S kıvrımlı nehir, iki köprü, bataklıklar |
| Himalaya Geçitleri | 1v1 | SUSUZ: dağ sıraları 3 şerit, 2 geçit + 2 kazı tıkacı |
| Kızıldeniz Sığlıkları | 1v1 | Geniş deniz: TEK merkezi köprü — bütün savaş o boğazda |
| Tuz Gölü Düzlüğü | 1v1 | AÇIK ARENA: çapraz yuvalar, merkez göl, 2 akrep + 2 kuluçka |
| Marmara Adaları | 1v1 | DÖRT ADA: 4 köprü halkası — köprübaşlarını tutan yönetir |
| İnka Yolu | 1v1 | Z KORİDOR: sen sağ üst, düşman sol alt — merkez kule kilidi, 2 kazı |
| Serengeti Üçgeni | 1v1v1 | Merkez gölet, şerit boğazları, arı yuvaları |
| Ege Adaları | 1v1v1 | Merkez HUB + dış halka: 6 köprü, iki katmanlı savaş |
| Nil Deltası | 1v1v1 | ÇATALLANAN nehir: delta adası + 3 köprü + çamur |
| Kapadokya Koridorları | 1v1v1 | Susuz labirent: 3 dilim, merkez arena, 3 kazı tıkacı |
| Tuna Kıyıları | 4p / 2v2 | Yatay nehir, üç köprü, 2 kuluçka istasyonu |
| Pasifik Atolü | 4p / 2v2 | Halka su + merkez ada: hub'a 4, yanlara 2 köprü |
| Panama Geçidi | 4p / 2v2 | TEK merkezi köprü — bütün savaş o boğazda |
| Büyük Kanyon | 4p / 2v2 | ÇAPRAZ kanyon nehri: 2 asma köprü + akrepler |
| Okavango Deltası | 4p / 2v2 | BATAKLIK savaşı: dev çamur kompleksi + kuluçkalar |
| Kilimanjaro Yaylaları | 4p / 2v2 | SUSUZ dört yayla: artı sırtlar, 2 kazı tıkacı, arılı plato |
| Halong Koyları | 4p / 2v2 | ATOL: 4 köprü yalnız MERKEZE — akrep + arılı acımasız kalp |

## SEFER — 3 Kampanya × 5 Görev

Menüdeki SEFER kutusundan girilir; seçim ekranı tek parça panoramadır
(üstte Ateş ve Buz ülkeleri, altta Ada denizi). Görevler kolaydan zora
kilitlidir: öncekini bitirmeden sonraki açılmaz, bitenler tekrar oynanır;
ilerleme cihazda saklanır. Görev öncesi sağlı-sollu BRİFİNG sayfası ana
amacı, düşmanları, sabit yetenekleri ve destekleri gösterir. Zaferden
sonra menüye değil SEFERE dönülür.

Görev kuralları: yetenekler görevde SABİT (1-3), tüm düşman botlar TEK
takım (2v1/3v1 kıskaçlar), denge için oyuncuya kule/çiftlik/altın desteği
verilir; final görevlerde düşmanlar zor zekâlı ve dolu kasalıdır.

- **Ateş Seferi** 🔥 (çorak tema: yanık toprak, LAV nehirleri, alevler,
  korlar): Kıvılcım → Kül Vadisi → Lav Nehri (2v1) → Kor Kuşatması (3v1)
  → Volkanın Kalbi (3v1 zor).
- **Buz Seferi** ❄️ (kar tema: karlı zemin, BUZ gölleri, tipi): Buz
  Çatlağı → Donmuş Göl (buz köprüsü) → Tipi (2v1) → Buzul Boğazı
  (3v1, kazılabilir buz duvarları) → Kutup Tahtı (3v1 zor).
- **Ada Seferi** 🏝️ (köprü savaşları): Sığ Sular → Mercan Yolu → Orta Köprü
  (2v1) → Fırtına Takımadaları (3v1, hub adasında düşman!) → Büyük Atol
  (3v1 zor).

## Diğer Özellikler

- **Kişilik gösterimi:** rakip bot yuvasının rozetinde karakter adı yazar
  ("Kale", "Cengaver"...) — rakibini tanı, planını kur.
- **Yaralı geri çekilme (ayar):** açıksa canı %20 altına düşen askerin
  yuvaya kaçar, içeri girince tam canla garnizona katılır.
- **Maç geçmişi & istatistik:** menü sağ üstündeki grafik butonu — kazanma
  oranı, üretilen asker, favori harita, hayatta kalma rekoru + son 40 maç.
- **Güç grafiği:** maç sonunda oyuncu başına ordu gücünün zaman çizgisi.
- **Lobi sohbeti (LAN):** hazır mesaj çipleriyle takımına sinyal ver.
- **Titreşim:** yuvan saldırı altındayken kısa uyarı (ayara bağlı).

- **Dil:** Ayarlar → Dil'den Türkçe/English anında değiştirilir (tüm
  arayüz, yetenek açıklamaları, wiki ve sefer brifingleri dahil).

- **Sis:** harita ve sahiplik (bayraklar, bölge sınırları) her zaman görünür;
  sis yalnız **canlı bilgiyi** gizler (düşman askerleri, doluş halkaları,
  nüfus/can). Takım görüşü paylaşılır.
- **Bölge sınırları:** ana yuvaya bağlı, bina aldıkça genişleyen soluk organik
  sınır — su alanlarından kırpılır, kıvrımlı kıyıyı izler.
- **Güç dağılım barı:** ekranın üstünde, tüm oyuncuların anlık savaş gücünü
  renkleriyle oransal gösteren organik kenarlı bar.
- **Ses:** menü ve oyun içi müzik havuzları RASTGELE ROTASYONLU (parça
  bitince farklısı çalar); çatışmada gerilim davulları katmanı, geri sayım
  tikleri + "SAVAŞ!" borusu, hareket emri hışırtısı; döngü bekçisi müzik
  takılmalarını onarır.
- **İlerleme:** kuleler ve çiftlikler seviye 4'e dek büyür (kule:
  menzil+hasar+atış hızı+MERMİ), kalabalık ele geçirmeyi hızlandırır,
  bölge sınırı bina seviyesiyle genişler; ordu tavanı sabit 200'dür.
- **Maç karnesi:** zafer/yenilgi ekranında herkes için çizelge — üretilen
  asker, kazanılan altın, harita hakimiyeti (%) ve kayıplar, renkli
  karşılaştırma barlarıyla.
- Kullanıcı adı (kraliçe panelinden ✎), gerçek oyun görüntülü harita
  kartları, wiki (oyundaki gerçek çizimlerle), oyun stilinde ayarlar.
