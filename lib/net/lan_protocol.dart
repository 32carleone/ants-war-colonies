/// LAN MULTIPLAYER PROTOKOLÜ — sunucusuz, tamamen yerel ağ:
///
/// - KEŞİF: kuran cihaz UDP yayınıyla (broadcast) kendini duyurur;
///   katılmak isteyenler aynı portu dinleyip listeyi kurar.
/// - OTURUM: TCP üzerinden uzunluk-önekli JSON mesajları
///   (4 bayt big-endian uzunluk + UTF-8 gövde).
/// - MODEL: HOST-OTORİTER — oyunu yalnız kuran cihaz simüle eder;
///   katılanlar EMİR gönderir, 10 Hz DURUM yayınını çizer.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Keşif yayınının UDP portu.
const int kLanDiscoveryPort = 47311;

/// Oyun oturumunun TCP portu.
const int kLanGamePort = 47312;

/// Yayın (beacon) aralığı ve listeden düşme eşiği.
const Duration kBeaconInterval = Duration(seconds: 1);
const Duration kBeaconTimeout = Duration(seconds: 4);

/// Saniyedeki durum (snapshot) yayını sayısı.
const double kSnapshotHz = 10;

/// Maç formatları.
enum LanMode { ffa, teams2v2 }

/// Mesaj tipleri (t alanı).
class MsgType {
  MsgType._();

  // client → host
  static const join = 'join'; // {name, loadout:[i,i,i]}
  static const slot = 'slt'; // {s: istenen slot} (lobide yer değiştirme)
  static const chat = 'cht'; // {m: hazır mesaj indexi} (lobi sohbeti)
  static const nestUp = 'nup'; // {} ana yuva yükseltmesi (host doğrular)
  static const deploy = 'dep'; // {f, x, y, o?, ex?, ey?}  (o: UnitType
  // index; ex/ey: kuluçkadan tut-sürükle çıkış noktası — host doğrular)
  static const move = 'mov'; // {ids:[...], x, y, ret? (yuvaya sok)}
  static const ability = 'abl'; // {s, x?, y?}
  static const produce = 'prd'; // {u: UnitType index}
  static const upgrade = 'upg'; // {i: building index}
  static const convert = 'cnv'; // {i, u: BuildingType index}

  // host → client
  static const lobby = 'lby'; // {players:[{slot,name,team,bot,me?}], ...}
  static const start = 'srt'; // {seed, mapId, mode, slot, players:[...]}
  static const state = 'st'; // oyun durumu (LanSnapshot)
  static const fx = 'fx'; // {a: abilityIndex, x, y, tm: casterTeam}
  static const end = 'end'; // {w: winnerTeam}
  static const closed = 'cls'; // host lobiyi kapattı
  static const kick = 'kck'; // yer yok / oyun başladı
}

/// Keşif yayını içeriği.
class LanGameInfo {
  const LanGameInfo({
    required this.hostName,
    required this.mapId,
    required this.mapName,
    required this.mode,
    required this.playerCount,
    required this.joined,
    required this.port,
    required this.address,
  });

  final String hostName;
  final String mapId;
  final String mapName;
  final LanMode mode;
  final int playerCount; // haritanın slot sayısı
  final int joined; // şu an lobide kaç insan var
  final int port;
  final String address; // beacon'ın geldiği IP

  Map<String, dynamic> toJson() => {
        'h': hostName,
        'm': mapId,
        'mn': mapName,
        'md': mode.index,
        'pc': playerCount,
        'j': joined,
        'p': port,
      };

  static LanGameInfo? fromJson(Map<String, dynamic> j, String address) {
    try {
      return LanGameInfo(
        hostName: j['h'] as String,
        mapId: j['m'] as String,
        mapName: j['mn'] as String,
        mode: LanMode.values[(j['md'] as num).toInt()],
        playerCount: (j['pc'] as num).toInt(),
        joined: (j['j'] as num).toInt(),
        port: (j['p'] as num).toInt(),
        address: address,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lobi/başlangıçtaki oyuncu tanımı.
class LanPlayerMeta {
  const LanPlayerMeta({
    required this.slot,
    required this.name,
    required this.team,
    required this.isBot,
    this.loadout = const [],
  });

  final int slot;
  final String name;
  final int team;
  final bool isBot;
  final List<int> loadout; // AbilityType indexleri (insanlar için)

  Map<String, dynamic> toJson() => {
        's': slot,
        'n': name,
        't': team,
        'b': isBot ? 1 : 0,
        if (loadout.isNotEmpty) 'l': loadout,
      };

  static LanPlayerMeta fromJson(Map<String, dynamic> j) => LanPlayerMeta(
        slot: (j['s'] as num).toInt(),
        name: j['n'] as String,
        team: (j['t'] as num).toInt(),
        isBot: (j['b'] as num) == 1,
        loadout: [
          for (final v in (j['l'] as List? ?? const [])) (v as num).toInt()
        ],
      );
}

/// TCP çerçeveleme: 4 bayt uzunluk + UTF-8 JSON.
Uint8List encodeFrame(Map<String, dynamic> msg) {
  final body = utf8.encode(jsonEncode(msg));
  final out = Uint8List(4 + body.length);
  ByteData.view(out.buffer).setUint32(0, body.length);
  out.setRange(4, out.length, body);
  return out;
}

/// Akan baytlardan çerçeve ayrıştırıcı — soket parça parça verir,
/// tamamlanan her JSON mesajını [onMessage] ile teslim eder.
class FrameDecoder {
  FrameDecoder(this.onMessage);

  final void Function(Map<String, dynamic> msg) onMessage;
  final _buf = BytesBuilder(copy: false);

  void add(List<int> chunk) {
    _buf.add(chunk);
    var bytes = _buf.toBytes();
    var offset = 0;
    while (bytes.length - offset >= 4) {
      final len = ByteData.view(bytes.buffer, bytes.offsetInBytes + offset, 4)
          .getUint32(0);
      if (bytes.length - offset - 4 < len) break;
      final body = utf8.decode(
          bytes.sublist(offset + 4, offset + 4 + len));
      offset += 4 + len;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) onMessage(decoded);
      } catch (_) {
        // bozuk çerçeve: yut (bağlantı katmanı zaten koparsa temizler)
      }
    }
    _buf.clear();
    if (offset < bytes.length) _buf.add(bytes.sublist(offset));
  }
}
